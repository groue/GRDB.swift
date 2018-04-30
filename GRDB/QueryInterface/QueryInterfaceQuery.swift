struct DatabasePromise<T> {
    let resolve: (Database) throws -> T
    
    init(value: T) {
        self.resolve = { _ in value }
    }
    
    init(_ resolve: @escaping (Database) throws -> T) {
        self.resolve = resolve
    }
    
    func map(_ transform: @escaping (Database, T) throws -> T) -> DatabasePromise {
        return DatabasePromise { db in
            try transform(db, self.resolve(db))
        }
    }
}

struct QueryInterfaceQuery {
    var source: SQLSource
    var selection: [SQLSelectable]
    var isDistinct: Bool
    var filterPromise: DatabasePromise<SQLExpression?>
    var groupByExpressions: [SQLExpression]
    var ordering: QueryOrdering
    var havingExpression: SQLExpression?
    var limit: SQLLimit?
    var joins: [AssociationJoin]
    
    init(
        source: SQLSource,
        selection: [SQLSelectable] = [],
        isDistinct: Bool = false,
        filterPromise: DatabasePromise<SQLExpression?> = DatabasePromise(value: nil),
        groupByExpressions: [SQLExpression] = [],
        ordering: QueryOrdering = QueryOrdering(),
        havingExpression: SQLExpression? = nil,
        limit: SQLLimit? = nil,
        joins: [AssociationJoin] = [])
    {
        self.source = source
        self.selection = selection
        self.isDistinct = isDistinct
        self.filterPromise = filterPromise
        self.groupByExpressions = groupByExpressions
        self.ordering = ordering
        self.havingExpression = havingExpression
        self.limit = limit
        self.joins = joins
    }
    
    func sql(_ db: Database, _ arguments: inout StatementArguments?) throws -> String {
        var sql = "SELECT"
        
        if isDistinct {
            sql += " DISTINCT"
        }
        
        let selection = completeSelection
        GRDBPrecondition(!selection.isEmpty, "Can't generate SQL with empty selection")
        sql += " " + selection.map { $0.resultColumnSQL(&arguments) }.joined(separator: ", ")
        
        sql += try " FROM " + source.sourceSQL(db, &arguments)
        
        for join in joins {
            sql += try " " + join.joinSQL(db, &arguments, leftQualifier: qualifier!, isRequiredAllowed: true)
        }
        
        if let filter = try filterPromise.resolve(db) {
            sql += " WHERE " + filter.expressionSQL(&arguments)
        }
        
        if !groupByExpressions.isEmpty {
            sql += " GROUP BY " + groupByExpressions.map { $0.expressionSQL(&arguments) }.joined(separator: ", ")
        }
        
        if let havingExpression = havingExpression {
            sql += " HAVING " + havingExpression.expressionSQL(&arguments)
        }
        
        let orderings = completeOrdering.resolve()
        if !orderings.isEmpty {
            sql += " ORDER BY " + orderings.map { $0.orderingTermSQL(&arguments) }.joined(separator: ", ")
        }
        
        if let limit = limit {
            sql += " LIMIT " + limit.sql
        }
        
        return sql
    }
    
    func makeDeleteStatement(_ db: Database) throws -> UpdateStatement {
        guard groupByExpressions.isEmpty else {
            // Programmer error
            fatalError("Can't delete query with GROUP BY clause")
        }
        
        guard havingExpression == nil else {
            // Programmer error
            fatalError("Can't delete query with HAVING clause")
        }
        
        guard joins.isEmpty else {
            // Programmer error
            fatalError("Can't delete query with JOIN clause")
        }
        
        guard case .table = source else {
            // Programmer error
            fatalError("Can't delete without any database table")
        }

        var sql = "DELETE"
        var arguments: StatementArguments? = StatementArguments()
        
        sql += try " FROM " + source.sourceSQL(db, &arguments)
        
        if let filter = try filterPromise.resolve(db) {
            sql += " WHERE " + filter.expressionSQL(&arguments)
        }
        
        if let limit = limit {
            let orderings = self.completeOrdering.resolve()
            if !orderings.isEmpty {
                sql += " ORDER BY " + orderings.map { $0.orderingTermSQL(&arguments) }.joined(separator: ", ")
            }
            
            if Database.sqliteCompileOptions.contains("ENABLE_UPDATE_DELETE_LIMIT") {
                sql += " LIMIT " + limit.sql
            } else {
                fatalError("Can't delete query with limit")
            }
        }
        
        let statement = try db.makeUpdateStatement(sql)
        statement.arguments = arguments!
        return statement
    }
    
    /// Remove ordering
    var unorderedQuery: QueryInterfaceQuery {
        var query = self
        query.ordering = QueryOrdering()
        return query
    }
    
    // MARK: Join Support
    
    var completeSelection: [SQLSelectable] {
        return joins.reduce(into: selection) {
            $0.append(contentsOf: $1.query.completeSelection)
        }
    }
    
    var completeOrdering: QueryOrdering {
        return joins.reduce(ordering) {
            $0.appending($1.query.completeOrdering)
        }
    }
    
    var qualifier: SQLTableQualifier? {
        return source.qualifier
    }
    
    var allQualifiers: [SQLTableQualifier] {
        var qualifiers: [SQLTableQualifier] = []
        if let qualifier = qualifier {
            qualifiers.append(qualifier)
        }
        return joins.reduce(into: qualifiers) {
            $0.append(contentsOf: $1.query.allQualifiers)
        }
    }
}

extension QueryInterfaceQuery {
    private var qualifiedQuery: QueryInterfaceQuery {
        var query = self
        
        if !joins.isEmpty {
            var qualifier = SQLTableQualifier(tableName: query.source.tableName!)
            query.source = source.qualified(with: &qualifier)
        }
        
        if let qualifier = query.qualifier {
            query.selection = query.selection.map { $0.qualifiedSelectable(with: qualifier) }
            query.filterPromise = query.filterPromise.map { [qualifier] (_, expr) in expr?.qualifiedExpression(with: qualifier) }
            query.groupByExpressions = query.groupByExpressions.map { $0.qualifiedExpression(with: qualifier) }
            query.ordering = query.ordering.qualified(with: qualifier)
            query.havingExpression = query.havingExpression?.qualifiedExpression(with: qualifier)
        }
        
        query.joins = query.joins.map {
            var join = $0
            join.query = join.query.qualifiedQuery
            return join
        }
        
        query.allQualifiers.resolveAmbiguities()
        return query
    }
    
    /// precondition: self is the result of qualifiedQuery
    private func makeSelectStatement(_ db: Database) throws -> SelectStatement {
        var arguments: StatementArguments? = StatementArguments()
        let sql = try self.sql(db, &arguments)
        let statement = try db.makeSelectStatement(sql)
        try statement.setArgumentsWithValidation(arguments!)
        return statement
    }
    
    /// precondition: self is the result of qualifiedQuery
    private func rowAdapter(_ db: Database) throws -> RowAdapter? {
        if joins.isEmpty {
            return nil
        }
        
        let selectionWidth = try selection
            .map { try $0.columnCount(db) }
            .reduce(0, +)
        
        var endIndex = selectionWidth
        var scopes: [String: RowAdapter] = [:]
        for join in joins {
            if let (joinAdapter, joinEndIndex) = try join.query.rowAdapter(db, fromIndex: endIndex, forKeyPath: [join.key]) {
                GRDBPrecondition(scopes[join.key] == nil, "The association key \"\(join.key)\" is ambiguous. Use the Association.forKey(_:) method is order to disambiguate.")
                scopes[join.key] = joinAdapter
                endIndex = joinEndIndex
            }
        }
        
        if selectionWidth == 0 && scopes.isEmpty {
            return nil
        }
        
        let adapter = RangeRowAdapter(0 ..< (0 + selectionWidth))
        return adapter.addingScopes(scopes)
    }
    
    func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
        let query = qualifiedQuery
        return try (query.makeSelectStatement(db), query.rowAdapter(db))
    }
    
    func fetchCount(_ db: Database) throws -> Int {
        let (statement, adapter) = try countQuery.prepare(db)
        return try Int.fetchOne(statement, adapter: adapter)!
    }
    
    /// The database region that the request looks into.
    func fetchedRegion(_ db: Database) throws -> DatabaseRegion {
        let statement = try qualifiedQuery.makeSelectStatement(db)
        let region = statement.fetchedRegion
        
        // Can we intersect the region with rowIds?
        //
        // Give up unless request feeds from a single database table
        guard joins.isEmpty, case .table(tableName: let tableName, qualifier: _) = source else {
            // TODO: try harder
            return region
        }
        
        // Give up unless primary key is rowId
        let primaryKeyInfo = try db.primaryKey(tableName)
        guard primaryKeyInfo.isRowID else {
            return region
        }
        
        // Give up unless there is a where clause
        guard let filter = try filterPromise.resolve(db) else {
            return region
        }
        
        // The filter knows better
        guard let rowIds = filter.matchedRowIds(rowIdName: primaryKeyInfo.rowIDColumn) else {
            return region
        }
        
        // Database regions are case-insensitive: use the canonical table name
        let canonicalTableName = try db.canonicalName(table: tableName)
        return region.tableIntersection(canonicalTableName, rowIds: rowIds)
    }
    
    private var countQuery: QueryInterfaceQuery {
        guard groupByExpressions.isEmpty && limit == nil else {
            // SELECT ... GROUP BY ...
            // SELECT ... LIMIT ...
            return trivialCountQuery
        }
        
        guard joins.isEmpty, case .table = source else {
            // SELECT ... FROM (something which is not a plain table)
            return trivialCountQuery
        }
        
        GRDBPrecondition(!selection.isEmpty, "Can't generate SQL with empty selection")
        if selection.count == 1 {
            guard let count = self.selection[0].count(distinct: isDistinct) else {
                return trivialCountQuery
            }
            var countQuery = unorderedQuery
            countQuery.isDistinct = false
            countQuery.selection = [count.sqlSelectable]
            return countQuery
        } else {
            // SELECT [DISTINCT] expr1, expr2, ... FROM tableName ...
            
            guard !isDistinct else {
                return trivialCountQuery
            }
            
            // SELECT expr1, expr2, ... FROM tableName ...
            // ->
            // SELECT COUNT(*) FROM tableName ...
            var countQuery = unorderedQuery
            countQuery.selection = [SQLExpressionCount(AllColumns())]
            return countQuery
        }
    }
    
    // SELECT COUNT(*) FROM (self)
    private var trivialCountQuery: QueryInterfaceQuery {
        return QueryInterfaceQuery(
            source: .query(unorderedQuery),
            selection: [SQLExpressionCount(AllColumns())])
    }
}

extension QueryInterfaceQuery {
    func select(_ selection: [SQLSelectable]) -> QueryInterfaceQuery {
        var query = self
        query.selection = selection
        return query
    }
    
    func distinct() -> QueryInterfaceQuery {
        var query = self
        query.isDistinct = true
        return query
    }
    
    func filter(_ predicate: @escaping (Database) throws -> SQLExpressible) -> QueryInterfaceQuery {
        var query = self
        query.filterPromise = query.filterPromise.map { (db, filter) in
            if let filter = filter {
                return try filter && predicate(db)
            } else {
                return try predicate(db).sqlExpression
            }
        }
        return query
    }
    
    func group(_ expressions: [SQLExpressible]) -> QueryInterfaceQuery {
        var query = self
        query.groupByExpressions = expressions.map { $0.sqlExpression }
        return query
    }
    
    func having(_ predicate: SQLExpressible) -> QueryInterfaceQuery {
        var query = self
        if let havingExpression = query.havingExpression {
            query.havingExpression = (havingExpression && predicate).sqlExpression
        } else {
            query.havingExpression = predicate.sqlExpression
        }
        return query
    }

    func order(_ orderings: [SQLOrderingTerm]) -> QueryInterfaceQuery {
        return order(QueryOrdering(orderings: orderings))
    }
    
    func reversed() -> QueryInterfaceQuery {
        return order(ordering.reversed)
    }
    
    private func order(_ ordering: QueryOrdering) -> QueryInterfaceQuery {
        var query = self
        query.ordering = ordering
        return query
    }
    
    func limit(_ limit: Int, offset: Int? = nil) -> QueryInterfaceQuery {
        var query = self
        query.limit = SQLLimit(limit: limit, offset: offset)
        return query
    }
    
    func joining(_ join: AssociationJoin) -> QueryInterfaceQuery {
        var query = self
        query.joins.append(join)
        return query
    }

    func qualified(with qualifier: inout SQLTableQualifier) -> QueryInterfaceQuery {
        var query = self
        query.source = source.qualified(with: &qualifier)
        return query
    }
}

extension QueryInterfaceQuery {
    init(_ query: AssociationQuery) {
        self.init(
            source: query.source,
            selection: query.selection,
            filterPromise: query.filterPromise,
            ordering: query.ordering,
            joins: query.joins)
    }
}

// MARK: - AssociationJoin

/// Not to be mismatched with SQL join operators (inner join, left join).
///
/// AssociationJoinOperator is designed to be hierarchically nested, unlike
/// SQL join operators.
///
/// Consider the following request for (A, B, C) tuples:
///
///     let r = A.including(optional: A.b.including(required: B.c))
///
/// It chains three associations, the first optional, the second required.
///
/// It looks like it means: "Give me all As, along with their Bs, granted those
/// Bs have their Cs. For As whose B has no C, give me a nil B".
///
/// It can not be expressed as one left join, and a regular join, as below,
/// Because this would not honor the first optional:
///
///     -- dubious
///     SELECT a.*, b.*, c.*
///     FROM a
///     LEFT JOIN b ON ...
///     JOIN c ON ...
///
/// Instead, it should:
/// - allow (A + missing (B + C))
/// - prevent (A + (B + missing C)).
///
/// This can be expressed in SQL with two left joins, and an extra condition:
///
///     -- likely correct
///     SELECT a.*, b.*, c.*
///     FROM a
///     LEFT JOIN b ON ...
///     LEFT JOIN c ON ...
///     WHERE NOT((b.id IS NOT NULL) AND (c.id IS NULL)) -- no B without C
///
/// This is currently not implemented, and requires a little more thought.
/// I don't even know if inventing a whole new way to perform joins should even
/// be on the table. But we have a hierarchical way to express joined queries,
/// and they have a meaning:
///
///     // what is my meaning?
///     A.including(optional: A.b.including(required: B.c))
enum AssociationJoinOperator {
    case required, optional
}

struct AssociationJoin {
    var joinOperator: AssociationJoinOperator
    var query: AssociationQuery
    var key: String
    var joinConditionPromise: (Database) throws -> JoinCondition
    
    func joinSQL(_ db: Database,_ arguments: inout StatementArguments?, leftQualifier: SQLTableQualifier, isRequiredAllowed: Bool) throws -> String {
        var isRequiredAllowed = isRequiredAllowed
        var sql = ""
        switch joinOperator {
        case .optional:
            isRequiredAllowed = false
            sql += "LEFT JOIN"
        case .required:
            guard isRequiredAllowed else {
                // TODO: chainOptionalRequired
                fatalError("Not implemented: chaining a required association behind an optional association")
            }
            sql += "JOIN"
        }
        
        sql += try " " + query.source.sourceSQL(db, &arguments)
        
        let qualifier = query.qualifier!
        let filters = try [
            joinConditionPromise(db)(leftQualifier, qualifier),
            query.filterPromise.resolve(db)
            ].compactMap { $0 }
        if !filters.isEmpty {
            sql += " ON " + filters.joined(operator: .and).expressionSQL(&arguments)
        }
        
        for join in query.joins {
            sql += try " " + join.joinSQL(db, &arguments, leftQualifier: qualifier, isRequiredAllowed: isRequiredAllowed)
        }
        
        return sql
    }
}

// MARK: - QueryOrdering

struct QueryOrdering {
    private var elements: [Element] = []
    var isReversed: Bool
    
    private enum Element {
        case orderingTerm(SQLOrderingTerm)
        case queryOrdering(QueryOrdering)
        
        var reversed: Element {
            switch self {
            case .orderingTerm(let orderingTerm):
                return .orderingTerm(orderingTerm.reversed)
            case .queryOrdering(let queryOrdering):
                return .queryOrdering(queryOrdering.reversed)
            }
        }
        
        func qualified(with qualifier: SQLTableQualifier) -> Element {
            switch self {
            case .orderingTerm(let orderingTerm):
                return .orderingTerm(orderingTerm.qualifiedOrdering(with: qualifier))
            case .queryOrdering(let queryOrdering):
                return .queryOrdering(queryOrdering.qualified(with: qualifier))
            }
        }
        
        func resolve() -> [SQLOrderingTerm] {
            switch self {
            case .orderingTerm(let orderingTerm):
                return [orderingTerm]
            case .queryOrdering(let queryOrdering):
                return queryOrdering.resolve()
            }
        }
    }
    
    private init(elements: [Element], isReversed: Bool) {
        self.elements = elements
        self.isReversed = isReversed
    }
    
    init() {
        self.init(
            elements: [],
            isReversed: false)
    }
    
    init(orderings: [SQLOrderingTerm]) {
        self.init(
            elements: orderings.map { .orderingTerm($0) },
            isReversed: false)
    }
    
    var reversed: QueryOrdering {
        return QueryOrdering(
            elements: elements,
            isReversed: !isReversed)
    }
    
    func qualified(with qualifier: SQLTableQualifier) -> QueryOrdering {
        return QueryOrdering(
            elements: elements.map { $0.qualified(with: qualifier) },
            isReversed: isReversed)
    }
    
    func appending(_ ordering: QueryOrdering) -> QueryOrdering {
        return QueryOrdering(
            elements: elements + [.queryOrdering(ordering)],
            isReversed: isReversed)
    }
    
    func resolve() -> [SQLOrderingTerm] {
        if isReversed {
            return elements.flatMap { $0.reversed.resolve() }
        } else {
            return elements.flatMap { $0.resolve() }
        }
    }
}

// MARK: - SQLSource

enum SQLSource {
    case table(tableName: String, qualifier: SQLTableQualifier?)
    indirect case query(QueryInterfaceQuery)
    
    var qualifier: SQLTableQualifier? {
        switch self {
        case .table(_, let qualifier):
            return qualifier
        case .query(let query):
            return query.qualifier
        }
    }
    
    /// An alias or an actual table name
    var qualifiedName: String {
        switch self {
        case .table(let tableName, let qualifier):
            return qualifier?.qualifiedName ?? tableName
        case .query(let query):
            return query.source.qualifiedName
        }
    }
    
    /// An actual table name, not an alias
    var tableName: String? {
        switch self {
        case .table(let tableName, _):
            return tableName
        case .query(let query):
            return query.source.tableName
        }
    }
    
    func sourceSQL(_ db: Database,_ arguments: inout StatementArguments?) throws -> String {
        switch self {
        case .table(let tableName, let qualifier):
            if let alias = qualifier?.alias, alias != tableName {
                return "\(tableName.quotedDatabaseIdentifier) \(alias.quotedDatabaseIdentifier)"
            } else {
                return "\(tableName.quotedDatabaseIdentifier)"
            }
        case .query(let query):
            return try "(\(query.sql(db, &arguments)))"
        }
    }
    
    func qualified(with qualifier: inout SQLTableQualifier) -> SQLSource {
        switch self {
        case .table(let tableName, let oldQualifier):
            if let oldQualifier = oldQualifier {
                qualifier = oldQualifier
                return self
            } else if let qualifierTableName = qualifier.tableName {
                if qualifierTableName == tableName { // TODO: should this test be case-insensitive?
                    return .table(
                        tableName: tableName,
                        qualifier: qualifier)
                } else {
                    // TODO: how to enter this branch? Is it useful?
                    return self
                }
            } else {
                qualifier.tableName = tableName
                return .table(
                    tableName: tableName,
                    qualifier: qualifier)
            }
        case .query(let query):
            return .query(query.qualified(with: &qualifier))
        }
    }
}

struct SQLLimit {
    let limit: Int
    let offset: Int?
    
    var sql: String {
        if let offset = offset {
            return "\(limit) OFFSET \(offset)"
        } else {
            return "\(limit)"
        }
    }
}

extension SQLCount {
    var sqlSelectable: SQLSelectable {
        switch self {
        case .all:
            return SQLExpressionCount(AllColumns())
        case .distinct(let expression):
            return SQLExpressionCountDistinct(expression)
        }
    }
}

/// The SQLSelectQuery generates SQL for query interface requests.
struct SQLSelectQuery {
    var relation: SQLRelation
    var isDistinct: Bool
    var groupPromise: DatabasePromise<[SQLExpression]>?
    var havingExpression: SQLExpression?
    var limit: SQLLimit?
    
    init(
        relation: SQLRelation,
        isDistinct: Bool = false,
        groupPromise: DatabasePromise<[SQLExpression]>? = nil,
        havingExpression: SQLExpression? = nil,
        limit: SQLLimit? = nil)
    {
        self.relation = relation
        self.isDistinct = isDistinct
        self.groupPromise = groupPromise
        self.havingExpression = havingExpression
        self.limit = limit
    }
    
    var alias: TableAlias? {
        return relation.alias
    }
}

extension SQLSelectQuery: SelectionRequest, FilteredRequest, OrderedRequest {
    func select(_ selection: [SQLSelectable]) -> SQLSelectQuery {
        return mapRelation { $0.select(selection) }
    }
    
    func annotated(with selection: [SQLSelectable]) -> SQLSelectQuery {
        return mapRelation { $0.annotated(with: selection) }
    }
    
    func distinct() -> SQLSelectQuery {
        var query = self
        query.isDistinct = true
        return query
    }
    
    func filter(_ predicate: @escaping (Database) throws -> SQLExpressible) -> SQLSelectQuery {
        return mapRelation { $0.filter(predicate) }
    }
    
    func group(_ expressions: @escaping (Database) throws -> [SQLExpressible]) -> SQLSelectQuery {
        var query = self
        query.groupPromise = DatabasePromise { db in try expressions(db).map { $0.sqlExpression } }
        return query
    }
    
    func having(_ predicate: SQLExpressible) -> SQLSelectQuery {
        var query = self
        if let havingExpression = query.havingExpression {
            query.havingExpression = (havingExpression && predicate).sqlExpression
        } else {
            query.havingExpression = predicate.sqlExpression
        }
        return query
    }

    func order(_ orderings: @escaping (Database) throws -> [SQLOrderingTerm]) -> SQLSelectQuery {
        return mapRelation { $0.order(orderings) }
    }
    
    func reversed() -> SQLSelectQuery {
        return mapRelation { $0.reversed() }
    }
    
    func unordered() -> SQLSelectQuery {
        return mapRelation { $0.unordered() }
    }

    func limit(_ limit: Int, offset: Int? = nil) -> SQLSelectQuery {
        var query = self
        query.limit = SQLLimit(limit: limit, offset: offset)
        return query
    }
    
    func appendingJoin(_ join: Join, forKey key: String) -> SQLSelectQuery {
        return mapRelation { $0.appendingJoin(join, forKey: key) }
    }

    func qualified(with alias: TableAlias) -> SQLSelectQuery {
        return mapRelation { $0.qualified(with: alias) }
    }
    
    /// Returns a query whose relation is transformed by the given closure.
    func mapRelation(_ transform: (SQLRelation) -> SQLRelation) -> SQLSelectQuery {
        var query = self
        query.relation = transform(relation)
        return query
    }
}

extension SQLSelectQuery {
    /// A finalized query is ready for SQL generation
    var finalizedQuery: SQLSelectQuery {
        var query = self
        
        query.relation = query.relation.finalizedRelation
        let alias = query.relation.alias!
        query.groupPromise = query.groupPromise?.map { [alias] (_, exprs) in exprs.map { $0.qualifiedExpression(with: alias) } }
        query.havingExpression = query.havingExpression?.qualifiedExpression(with: alias)
        
        return query
    }
    
    /// - precondition: self is the result of finalizedQuery
    private func finalizedRowAdapter(_ db: Database) throws -> RowAdapter? {
        // No join => no adapter
        if relation.joins.isEmpty {
            return nil
        }
        
        guard let (adapter, _) = try relation.finalizedRowAdapter(db, fromIndex: 0, forKeyPath: []) else {
            return nil
        }
        
        return adapter
    }
}

extension SQLSelectQuery {
    /// - precondition: self is the result of finalizedQuery
    func sql(_ db: Database, _ context: inout SQLGenerationContext) throws -> String {
        var sql = "SELECT"
        
        if isDistinct {
            sql += " DISTINCT"
        }
        
        let selection = relation.finalizedSelection
        GRDBPrecondition(!selection.isEmpty, "Can't generate SQL with empty selection")
        sql += " " + selection.map { $0.resultColumnSQL(&context) }.joined(separator: ", ")
        
        sql += try " FROM " + relation.source.sourceSQL(db, &context)
        
        for (_, join) in relation.joins {
            sql += try " " + join.joinSQL(db, &context, leftAlias: alias!, isRequiredAllowed: true)
        }
        
        if let filter = try relation.filterPromise.resolve(db) {
            sql += " WHERE " + filter.expressionSQL(&context)
        }
        
        if let groupExpressions = try groupPromise?.resolve(db), !groupExpressions.isEmpty {
            sql += " GROUP BY "
            sql += groupExpressions.map { $0.expressionSQL(&context) }
                .joined(separator: ", ")
        }
        
        if let havingExpression = havingExpression {
            sql += " HAVING " + havingExpression.expressionSQL(&context)
        }
        
        let orderings = try relation.finalizedOrdering.resolve(db)
        if !orderings.isEmpty {
            sql += " ORDER BY " + orderings.map { $0.orderingTermSQL(&context) }.joined(separator: ", ")
        }
        
        if let limit = limit {
            sql += " LIMIT " + limit.sql
        }
        
        return sql
    }
    
    /// - precondition: self is the result of finalizedQuery
    private func makeSelectStatement(_ db: Database) throws -> SelectStatement {
        var context = SQLGenerationContext.queryGenerationContext(aliases: relation.finalizedAliases)
        let sql = try self.sql(db, &context)
        let statement = try db.makeSelectStatement(sql)
        statement.arguments = context.arguments!
        return statement
    }
    
    /// - precondition: self is the result of finalizedQuery
    func makeDeleteStatement(_ db: Database) throws -> UpdateStatement {
        if let groupExpressions = try groupPromise?.resolve(db), !groupExpressions.isEmpty {
            // Programmer error
            fatalError("Can't delete query with GROUP BY clause")
        }
        
        guard havingExpression == nil else {
            // Programmer error
            fatalError("Can't delete query with HAVING clause")
        }
        
        guard relation.joins.isEmpty else {
            // Programmer error
            fatalError("Can't delete query with JOIN clause")
        }
        
        guard case .table = relation.source else {
            // Programmer error
            fatalError("Can't delete without any database table")
        }
        
        var context = SQLGenerationContext.queryGenerationContext(aliases: relation.finalizedAliases)
        
        var sql = try "DELETE FROM " + relation.source.sourceSQL(db, &context)
        
        if let filter = try relation.filterPromise.resolve(db) {
            sql += " WHERE " + filter.expressionSQL(&context)
        }
        
        if let limit = limit {
            let orderings = try relation.finalizedOrdering.resolve(db)
            if !orderings.isEmpty {
                sql += " ORDER BY " + orderings.map { $0.orderingTermSQL(&context) }.joined(separator: ", ")
            }
            
            if Database.sqliteCompileOptions.contains("ENABLE_UPDATE_DELETE_LIMIT") {
                sql += " LIMIT " + limit.sql
            } else {
                fatalError("Can't delete query with limit")
            }
        }
        
        let statement = try db.makeUpdateStatement(sql)
        statement.arguments = context.arguments!
        return statement
    }
    
    /// - precondition: self is the result of finalizedQuery
    func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
        return try (makeSelectStatement(db), finalizedRowAdapter(db))
    }
    
    func fetchCount(_ db: Database) throws -> Int {
        let (statement, adapter) = try countQuery.prepare(db)
        return try Int.fetchOne(statement, adapter: adapter)!
    }
    
    /// The database region that the request looks into.
    /// - precondition: self is the result of finalizedQuery
    func databaseRegion(_ db: Database) throws -> DatabaseRegion {
        let statement = try makeSelectStatement(db)
        let databaseRegion = statement.databaseRegion
        
        // Can we intersect the region with rowIds?
        //
        // Give up unless request feeds from a single database table
        guard case .table(tableName: let tableName, alias: _) = relation.source else {
            // TODO: try harder
            return databaseRegion
        }
        
        // Give up unless primary key is rowId
        let primaryKeyInfo = try db.primaryKey(tableName)
        guard primaryKeyInfo.isRowID else {
            return databaseRegion
        }
        
        // Give up unless there is a where clause
        guard let filter = try relation.filterPromise.resolve(db) else {
            return databaseRegion
        }
        
        // The filter knows better
        guard let rowIds = filter.matchedRowIds(rowIdName: primaryKeyInfo.rowIDColumn) else {
            return databaseRegion
        }
        
        // Database regions are case-insensitive: use the canonical table name
        let canonicalTableName = try db.canonicalTableName(tableName)
        return databaseRegion.tableIntersection(canonicalTableName, rowIds: rowIds)
    }
    
    private var countQuery: SQLSelectQuery {
        guard groupPromise == nil && limit == nil else {
            // SELECT ... GROUP BY ...
            // SELECT ... LIMIT ...
            return trivialCountQuery
        }
        
        guard relation.joins.isEmpty, case .table = relation.source else {
            // SELECT ... FROM (something which is not a plain table)
            return trivialCountQuery
        }
        
        GRDBPrecondition(!relation.selection.isEmpty, "Can't generate SQL with empty selection")
        if relation.selection.count == 1 {
            guard let count = relation.selection[0].count(distinct: isDistinct) else {
                return trivialCountQuery
            }
            var countQuery = self.unordered().select(count.sqlSelectable)
            countQuery.isDistinct = false
            return countQuery
        } else {
            // SELECT [DISTINCT] expr1, expr2, ... FROM tableName ...
            
            guard !isDistinct else {
                return trivialCountQuery
            }
            
            // SELECT expr1, expr2, ... FROM tableName ...
            // ->
            // SELECT COUNT(*) FROM tableName ...
            return self.unordered().select(SQLExpressionCount(AllColumns()))
        }
    }
    
    // SELECT COUNT(*) FROM (self)
    private var trivialCountQuery: SQLSelectQuery {
        let relation = SQLRelation(
            source: .query(unordered()),
            selection: [SQLExpressionCount(AllColumns())])
        return SQLSelectQuery(relation: relation)
    }
}

// MARK: - Join

/// Not to be mismatched with SQL join operators (inner join, left join).
///
/// JoinOperator is designed to be hierarchically nested, unlike
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
///
/// :nodoc:
public /* TODO: internal */ enum JoinOperator {
    case required, optional
}

/// The condition that links two joined tables.
///
/// Currently, we only support one kind of join condition: foreign keys.
///
///     SELECT ... FROM book JOIN author ON author.id = book.authorId
///                                         <- the join condition -->
///
/// When we eventually add support for new ways to join tables, JoinCondition
/// is the type we'll need to update.
///
/// JoinCondition equality allows merging of associations:
///
///     // request1 and request2 are equivalent
///     let request1 = Book
///         .including(required: Book.author)
///     let request2 = Book
///         .including(required: Book.author)
///         .including(required: Book.author)
///
///     // request3 and request4 are equivalent
///     let request3 = Book
///         .including(required: Book.author.filter(condition1 && condition2))
///     let request4 = Book
///         .joining(required: Book.author.filter(condition1))
///         .including(optional: Book.author.filter(condition2))
///
/// :nodoc:
public /* TODO: internal */ struct JoinCondition: Equatable {
    /// Definition of a foreign key
    var foreignKeyRequest: ForeignKeyRequest
    
    /// True if the table at the origin of the foreign key is on the left of
    /// the sql JOIN operator.
    ///
    /// Let's consider the `book.authorId -> author.id` foreign key.
    /// Its origin table is `book`.
    ///
    /// The origin table `book` is on the left of the JOIN operator for
    /// the BelongsTo association:
    ///
    ///     -- Book.including(required: Book.author)
    ///     SELECT ... FROM book JOIN author ON author.id = book.authorId
    ///
    /// The origin table `book`is on the right of the JOIN operator for
    /// the HasMany and HasOne associations:
    ///
    ///     -- Author.including(required: Author.books)
    ///     SELECT ... FROM author JOIN book ON author.id = book.authorId
    var originIsLeft: Bool
    
    /// Returns an SQL expression for the join condition.
    ///
    ///     SELECT ... FROM book JOIN author ON author.id = book.authorId
    ///                                         <- the SQL expression -->
    ///
    /// - parameter db: A database connection.
    /// - parameter leftAlias: A TableAlias for the table on the left of the
    ///   JOIN operator.
    /// - parameter rightAlias: A TableAlias for the table on the right of the
    ///   JOIN operator.
    /// - Returns: An SQL expression.
    func sqlExpression(_ db: Database, leftAlias: TableAlias, rightAlias: TableAlias) throws -> SQLExpression? {
        let foreignKeyMapping = try foreignKeyRequest.fetch(db).mapping
        let columnMapping: [(left: Column, right: Column)]
        if originIsLeft {
            columnMapping = foreignKeyMapping.map { (left: Column($0.origin), right: Column($0.destination)) }
        } else {
            columnMapping = foreignKeyMapping.map { (left: Column($0.destination), right: Column($0.origin)) }
        }
        
        return columnMapping
            .map { $0.right.qualifiedExpression(with: rightAlias) == $0.left.qualifiedExpression(with: leftAlias) }
            .joined(operator: .and)
    }
}

struct Join {
    var joinOperator: JoinOperator
    var joinCondition: JoinCondition
    var relation: SQLRelation

    var finalizedJoin: Join {
        var join = self
        join.relation = relation.finalizedRelation
        return join
    }
    
    /// - precondition: relation is the result of finalizedRelation
    func joinSQL(_ db: Database,_ context: inout SQLGenerationContext, leftAlias: TableAlias, isRequiredAllowed: Bool) throws -> String {
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
        
        sql += try " " + relation.source.sourceSQL(db, &context)
        
        let rightAlias = relation.alias!
        let filters = try [
            joinCondition.sqlExpression(db, leftAlias: leftAlias, rightAlias: rightAlias),
            relation.filterPromise.resolve(db)
            ].compactMap { $0 }
        if !filters.isEmpty {
            sql += " ON " + filters.joined(operator: .and).expressionSQL(&context)
        }
        
        for (_, join) in relation.joins {
            sql += try " " + join.joinSQL(db, &context, leftAlias: rightAlias, isRequiredAllowed: isRequiredAllowed)
        }
        
        return sql
    }
    
    /// Returns nil if joins can't be merged (conflict in condition, relation...)
    func merged(with other: Join) -> Join? {
        guard joinCondition == other.joinCondition else {
            // can't merge
            return nil
        }
        
        guard let mergedRelation = relation.merged(with: other.relation) else {
            // can't merge
            return nil
        }
        
        let mergedJoinOperator: JoinOperator
        switch (joinOperator, other.joinOperator) {
        case (.required, _), (_, .required):
            mergedJoinOperator = .required
        default:
            mergedJoinOperator = .optional
        }
        
        return Join(
            joinOperator: mergedJoinOperator,
            joinCondition: joinCondition,
            relation: mergedRelation)
    }
}

// MARK: - SQLSource

enum SQLSource {
    case table(tableName: String, alias: TableAlias?)
    indirect case query(SQLSelectQuery)
    
    var alias: TableAlias? {
        switch self {
        case .table(_, let alias):
            return alias
        case .query(let query):
            return query.alias
        }
    }
    
    func sourceSQL(_ db: Database, _ context: inout SQLGenerationContext) throws -> String {
        switch self {
        case .table(let tableName, let alias):
            if let alias = alias, let aliasName = context.aliasName(for: alias) {
                return "\(tableName.quotedDatabaseIdentifier) \(aliasName.quotedDatabaseIdentifier)"
            } else {
                return "\(tableName.quotedDatabaseIdentifier)"
            }
        case .query(let query):
            return try "(\(query.sql(db, &context)))"
        }
    }
    
    func qualified(with alias: TableAlias) -> SQLSource {
        switch self {
        case .table(let tableName, let sourceAlias):
            if let sourceAlias = sourceAlias {
                alias.becomeProxy(of: sourceAlias)
                return self
            } else {
                alias.setTableName(tableName)
                return .table(tableName: tableName, alias: alias)
            }
        case .query(let query):
            return .query(query.qualified(with: alias))
        }
    }
    
    /// Returns nil if sources can't be merged (conflict in tables, aliases...)
    func merged(with other: SQLSource) -> SQLSource? {
        switch (self, other) {
        case let (.table(tableName: tableName, alias: alias), .table(tableName: otherTableName, alias: otherAlias)):
            guard tableName == otherTableName else {
                // can't merge
                return nil
            }
            switch (alias, otherAlias) {
            case (nil, nil):
                return .table(tableName: tableName, alias: nil)
            case let (alias?, nil), let (nil, alias?):
                return .table(tableName: tableName, alias: alias)
            case let (alias?, otherAlias?):
                guard let mergedAlias = alias.merge(with: otherAlias) else {
                    // can't merge
                    return nil
                }
                return .table(tableName: tableName, alias: mergedAlias)
            }
        default:
            // can't merge
            return nil
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

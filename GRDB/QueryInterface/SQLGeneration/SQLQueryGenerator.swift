/// SQLQueryGenerator is able to generate an SQL SELECT query.
struct SQLQueryGenerator: Refinable {
    fileprivate private(set) var relation: SQLQualifiedRelation
    private let isDistinct: Bool
    private let groupPromise: DatabasePromise<[SQLExpression]>?
    private let havingExpressionsPromise: DatabasePromise<[SQLExpression]>
    private let limit: SQLLimit?
    private let singleResult: Bool
    // For database region
    private let prefetchedAssociations: [_SQLAssociation]
    
    /// Creates an SQL query generator.
    ///
    /// - parameter singleResult: A hint as to whether the query should be
    ///   optimized for a single result.
    init(
        query: SQLQuery,
        forSingleResult singleResult: Bool = false)
    {
        // To generate SQL, we need a "qualified" relation, where all tables,
        // expressions, etc, are identified with table aliases.
        //
        // All those aliases let us disambiguate tables at the SQL level, and
        // prefix columns names. For example, the following request...
        //
        //      Book.filter(Column("kind") == Book.Kind.novel)
        //          .including(optional: Book.author)
        //          .including(optional: Book.translator)
        //          .annotated(with: Book.awards.count)
        //
        // ... generates the following SQL, where all identifiers are correctly
        // disambiguated and qualified:
        //
        //      SELECT book.*, person1.*, person2.*, COUNT(DISTINCT award.id)
        //      FROM book
        //      LEFT JOIN person person1 ON person1.id = book.authorId
        //      LEFT JOIN person person2 ON person2.id = book.translatorId
        //      LEFT JOIN award ON award.bookId = book.id
        //      GROUP BY book.id
        //      WHERE book.kind = 'novel'
        relation = SQLQualifiedRelation(query.relation)
        
        // Qualify group expressions and having clause with the relation alias.
        //
        // This turns `GROUP BY id` INTO `GROUP BY book.id`, and
        // `HAVING MAX(year) < 2000` INTO `HAVING MAX(book.year) < 2000`.
        if let alias = relation.source.alias {
            groupPromise = query.groupPromise?.map {
                $0.map { $0._qualifiedExpression(with: alias) }
            }
            havingExpressionsPromise = query.havingExpressionsPromise.map {
                $0.map { $0._qualifiedExpression(with: alias) }
            }
        } else {
            groupPromise = query.groupPromise
            havingExpressionsPromise = query.havingExpressionsPromise
        }
        
        limit = query.limit
        isDistinct = query.isDistinct
        self.singleResult = singleResult
        prefetchedAssociations = query.relation.prefetchedAssociations
    }
    
    func requestSQL(_ context: SQLGenerationContext) throws -> String {
        // Build an SQL generation context with all aliases found in the query,
        // so that we can disambiguate tables that are used several times with
        // SQL aliases.
        let context = SQLGenerationContext(parent: context, aliases: relation.allAliases)
        
        var sql = "SELECT"
        
        if isDistinct {
            sql += " DISTINCT"
        }
        
        let selection = try relation.selectionPromise.resolve(context.db)
        GRDBPrecondition(!selection.isEmpty, "Can't generate SQL with an empty selection")
        sql += try " " + selection.map { try $0.resultColumnSQL(context) }.joined(separator: ", ")
        
        sql += " FROM "
        sql += try relation.source.sql(context)
        
        if relation.joins.isEmpty == false {
            guard let sourceAlias = relation.source.alias else {
                // This never happens as long as we only use subqueries as sources
                // in the `SELECT COUNT(*) FROM (SELECT ...)` case: see
                // SQLQuery.trivialCountQuery.
                fatalError("Not implemented: join on a subquery")
            }
            for (_, join) in relation.joins {
                sql += " "
                sql += try join.sql(context, leftAlias: sourceAlias)
            }
        }
        
        let filters = try relation.filtersPromise.resolve(context.db)
        if filters.isEmpty == false {
            sql += " WHERE "
            sql += try filters.joined(operator: .and).expressionSQL(context, wrappedInParenthesis: false)
        }
        
        let groupExpressions = try groupPromise?.resolve(context.db) ?? []
        if !groupExpressions.isEmpty {
            sql += " GROUP BY "
            sql += try groupExpressions
                .map { try $0.expressionSQL(context, wrappedInParenthesis: false) }
                .joined(separator: ", ")
        }
        
        let havingExpressions = try havingExpressionsPromise.resolve(context.db)
        if havingExpressions.isEmpty == false {
            sql += " HAVING "
            sql += try havingExpressions.joined(operator: .and).expressionSQL(context, wrappedInParenthesis: false)
        }
        
        let orderings = try relation.ordering.resolve(context.db)
        if !orderings.isEmpty {
            sql += " ORDER BY "
            sql += try orderings
                .map { try $0.orderingTermSQL(context) }
                .joined(separator: ", ")
        }
        
        var limit = self.limit
        if try singleResult && !expectsSingleResult(
            context.db,
            selection: selection,
            filters: filters,
            groupExpressions: groupExpressions)
        {
            limit = SQLLimit(limit: 1, offset: limit?.offset)
        }
        
        if let limit = limit {
            sql += " LIMIT "
            sql += limit.sql
        }
        
        return sql
    }
    
    func makePreparedRequest(_ db: Database) throws -> PreparedRequest {
        try PreparedRequest(
            statement: makeSelectStatement(db),
            adapter: rowAdapter(db))
    }
    
    /// Returns a select statement
    func makeSelectStatement(_ db: Database) throws -> SelectStatement {
        // Build
        let context = SQLGenerationContext(db)
        let sql = try requestSQL(context)
        
        // Compile & set arguments
        let statement = try db.makeSelectStatement(sql: sql)
        statement.arguments = context.arguments
        
        // Optimize statement region. This allows us to track individual rowids,
        // and also find some provably empty requests such as `Player.none()`.
        statement.databaseRegion = try optimizedSelectedRegion(db, statement.databaseRegion)
        
        if !statement.databaseRegion.isEmpty {
            // Unless the statement region is provably empty, also append the
            // region of prefetched associations.
            //
            // This makes sure we observe the correct database region when the
            // statement is executed, even if we don't actually fetch prefetched
            // associations, due to lacking database content.
            //
            // For example, fetching `parent.including(all: children)` will
            // select parents, but won't attempt to select any children if there
            // is no parent in the database. And yet we need to observe the
            // table for children. This is why we include the prefetched region.
            //
            // Note that the request `parent.none().including(all: children)` is
            // different. Since `parent.none()` is provably empty, its region
            // is empty, and we thus avoid this code branch.
            try statement.databaseRegion.formUnion(prefetchedRegion(db, associations: prefetchedAssociations))
        }
        
        return statement
    }
    
    private func optimizedSelectedRegion(_ db: Database, _ selectedRegion: DatabaseRegion) throws -> DatabaseRegion {
        // Can we intersect the region with rowIds?
        //
        // Give up unless request feeds from a single database table
        guard
            case let .table(tableName: tableName, alias: alias) = relation.source,
            try db.tableExists(tableName) // skip views
            else {
                return selectedRegion
        }
        
        // The filter knows better
        let filter = try relation.filtersPromise.resolve(db).joined(operator: .and)
        guard let rowIDs = try filter.identifyingRowIDs(db, for: alias) else {
            return selectedRegion
        }
        
        // Database regions are case-sensitive: use the canonical table name
        let canonicalTableName = try db.canonicalTableName(tableName)
        return selectedRegion.tableIntersection(canonicalTableName, rowIds: rowIDs)
    }
    
    /// If true, executing this query yields at most one row.
    /// If false, we don't know how many rows this query returns.
    private func expectsSingleResult(
        _ db: Database,
        selection: [SQLSelectable],
        filters: [SQLExpression],
        groupExpressions: [SQLExpression])
        throws -> Bool
    {
        if relation.joins.isEmpty == false {
            // Don't expect single results as soon as there is a join
            return false
        }
        
        // Do we filter on a unique key?
        if
            case let .table(tableName: tableName, alias: sourceAlias) = relation.source,
            try db.tableExists(tableName) // skip views
        {
            let identifyingColums = try filters
                .joined(operator: .and)
                .identifyingColums(db, for: sourceAlias)
            if try db.table(tableName, hasUniqueKey: identifyingColums) {
                // Filter by unique key: guaranteed single row!
                return true
            }
        }
        
        // Do we aggregate without grouping?
        if groupExpressions.isEmpty && selection.contains(where: { $0.isAggregate() }) {
            // Selection contains an aggregate function: guaranteed single row!
            return true
        }
        
        return false
    }
    
    func makeDeleteStatement(_ db: Database) throws -> UpdateStatement {
        switch try grouping(db) {
        case .none:
            guard case .table = relation.source else {
                // Programmer error
                fatalError("Can't delete without any database table")
            }
            
            guard relation.joins.isEmpty else {
                return try makeTrivialDeleteStatement(db)
            }
            
            let context = SQLGenerationContext(db, aliases: relation.allAliases)
            
            var sql = try "DELETE FROM " + relation.source.sql(context)
            
            let filters = try relation.filtersPromise.resolve(db)
            if filters.isEmpty == false {
                sql += " WHERE "
                sql += try filters
                    .joined(operator: .and)
                    .expressionSQL(context, wrappedInParenthesis: false)
            }
            
            if let limit = limit {
                let orderings = try relation.ordering.resolve(db)
                if !orderings.isEmpty {
                    sql += try " ORDER BY " + orderings.map { try $0.orderingTermSQL(context) }.joined(separator: ", ")
                }
                sql += " LIMIT " + limit.sql
            }
            
            let statement = try db.makeUpdateStatement(sql: sql)
            statement.arguments = context.arguments
            return statement
            
        case .unique:
            return try makeTrivialDeleteStatement(db)
            
        case .nonUnique:
            // Programmer error
            fatalError("Can't delete query with GROUP BY clause")
        }
    }
    
    /// DELETE FROM table WHERE id IN (SELECT id FROM table ...)
    private func makeTrivialDeleteStatement(_ db: Database) throws -> UpdateStatement {
        guard case let .table(tableName: tableName, alias: _) = relation.source else {
            // Programmer error
            fatalError("Can't delete without any database table")
        }
        
        let alias = TableAlias(tableName: tableName)
        let context = SQLGenerationContext(db, aliases: [alias])
        let subqueryContext = SQLGenerationContext(parent: context, aliases: relation.allAliases)
        let primaryKey = _SQLExpressionFastPrimaryKey()
        
        var sql = "DELETE FROM \(tableName.quotedDatabaseIdentifier) WHERE "
        sql += try alias[primaryKey].expressionSQL(context, wrappedInParenthesis: false)
        sql += " IN ("
        sql += try map(\.relation, { $0.selectOnly([primaryKey]) }).requestSQL(subqueryContext)
        sql += ")"
        
        let statement = try db.makeUpdateStatement(sql: sql)
        statement.arguments = context.arguments
        return statement
    }
    
    /// Returns nil if assignments is empty
    func makeUpdateStatement(
        _ db: Database,
        conflictResolution: Database.ConflictResolution,
        assignments: [ColumnAssignment])
        throws -> UpdateStatement?
    {
        switch try grouping(db) {
        case .none:
            guard case .table = relation.source else {
                // Programmer error
                fatalError("Can't update without any database table")
            }
            
            guard relation.joins.isEmpty else {
                return try makeTrivialUpdateStatement(
                    db,
                    conflictResolution: conflictResolution,
                    assignments: assignments)
            }
            
            // Check for empty assignments after all programmer errors have
            // been checked.
            if assignments.isEmpty {
                return nil
            }
            
            let context = SQLGenerationContext(db, aliases: relation.allAliases)
            
            var sql = "UPDATE "
            
            if conflictResolution != .abort {
                sql += "OR \(conflictResolution.rawValue) "
            }
            
            sql += try relation.source.sql(context)
            
            let assignmentsSQL = try assignments
                .map { try $0.sql(context) }
                .joined(separator: ", ")
            sql += " SET " + assignmentsSQL
            
            let filters = try relation.filtersPromise.resolve(db)
            if filters.isEmpty == false {
                sql += " WHERE "
                sql += try filters
                    .joined(operator: .and)
                    .expressionSQL(context, wrappedInParenthesis: false)
            }
            
            if let limit = limit {
                let orderings = try relation.ordering.resolve(db)
                if !orderings.isEmpty {
                    sql += try " ORDER BY " + orderings.map { try $0.orderingTermSQL(context) }.joined(separator: ", ")
                }
                sql += " LIMIT " + limit.sql
            }
            
            let statement = try db.makeUpdateStatement(sql: sql)
            statement.arguments = context.arguments
            return statement
            
        case .unique:
            return try makeTrivialUpdateStatement(db, conflictResolution: conflictResolution, assignments: assignments)
            
        case .nonUnique:
            // Programmer error
            fatalError("Can't update query with GROUP BY clause")
        }
    }
    
    /// UPDATE table SET ... WHERE id IN (SELECT id FROM table ...)
    /// Returns nil if assignments is empty
    private func makeTrivialUpdateStatement(
        _ db: Database,
        conflictResolution: Database.ConflictResolution,
        assignments: [ColumnAssignment])
        throws -> UpdateStatement?
    {
        guard case let .table(tableName: tableName, alias: _) = relation.source else {
            // Programmer error
            fatalError("Can't delete without any database table")
        }
        
        // Check for empty assignments after all programmer errors have
        // been checked.
        if assignments.isEmpty {
            return nil
        }
        
        let alias = TableAlias(tableName: tableName)
        let context = SQLGenerationContext(db, aliases: [alias])
        let subqueryContext = SQLGenerationContext(parent: context, aliases: relation.allAliases)
        let primaryKey = _SQLExpressionFastPrimaryKey()
        
        // UPDATE table...
        var sql = "UPDATE "
        if conflictResolution != .abort {
            sql += "OR \(conflictResolution.rawValue) "
        }
        sql += tableName.quotedDatabaseIdentifier
        
        // SET column = value...
        let assignmentsSQL = try assignments
            .map { try $0.sql(context) }
            .joined(separator: ", ")
        sql += " SET " + assignmentsSQL
        
        // WHERE id IN (SELECT id FROM ...)
        sql += " WHERE "
        sql += try alias[primaryKey].expressionSQL(context, wrappedInParenthesis: false)
        sql += " IN ("
        sql += try map(\.relation, { $0.selectOnly([primaryKey]) }).requestSQL(subqueryContext)
        sql += ")"
        
        let statement = try db.makeUpdateStatement(sql: sql)
        statement.arguments = context.arguments
        return statement
    }
    
    /// Informs about the query grouping
    private enum GroupingInfo {
        /// No grouping at all: SELECT ... FROM player
        case none
        /// Grouped by unique key: SELECT ... FROM player GROUP BY id
        case unique
        /// Grouped by some non-unique columnns: SELECT ... FROM player GROUP BY teamId
        case nonUnique
    }
    
    /// Informs about the query grouping
    private func grouping(_ db: Database) throws -> GroupingInfo {
        // Empty group clause: no grouping
        // SELECT * FROM player
        guard let groupExpressions = try groupPromise?.resolve(db), groupExpressions.isEmpty == false else {
            return .none
        }
        
        // Grouping something which is not a table: assume non unique grouping.
        guard
            case let .table(tableName: tableName, alias: alias) = relation.source,
            try db.tableExists(tableName) // skip views
            else {
                return .nonUnique
        }
        
        var groupingColumns: Set<String> = []
        for expression in groupExpressions {
            guard let column = try expression.column(db, for: alias, acceptsBijection: true) else {
                // Grouping by something which is not a column: assume non
                // unique grouping.
                return .nonUnique
            }
            groupingColumns.insert(column)
        }
        
        // Grouping by some column(s) which are unique
        // SELECT * FROM player GROUP BY id
        if try db.table(tableName, hasUniqueKey: groupingColumns) {
            return .unique
        }
        
        // Grouping by some column(s) which are not unique
        // SELECT * FROM player GROUP BY score
        return .nonUnique
    }
    
    /// Returns the row adapter which presents the fetched rows according to the
    /// tree of joined relations.
    ///
    /// The adapter is nil for queries without any included relation,
    /// because the fetched rows don't need any processing:
    ///
    ///     // SELECT * FROM book
    ///     let request = Book.all()
    ///     for row in try Row.fetchAll(db, request) {
    ///         row // [id:1, title:"Moby-Dick"]
    ///         let book = Book(row: row)
    ///     }
    ///
    /// But as soon as the selection includes columns of a included relation,
    /// we need an adapter:
    ///
    ///     // SELECT book.*, author.* FROM book JOIN author ON author.id = book.authorId
    ///     let request = Book.including(required: Book.author)
    ///     for row in try Row.fetchAll(db, request) {
    ///         row // [id:1, title:"Moby-Dick"]
    ///         let book = Book(row: row)
    ///
    ///         row.scopes["author"] // [id:12, name:"Herman Melville"]
    ///         let author: Author = row["author"]
    ///     }
    private func rowAdapter(_ db: Database) throws -> RowAdapter? {
        try relation.rowAdapter(db, fromIndex: 0)?.adapter
    }
}

/// A "qualified" relation, where all tables are identified with a table alias.
///
///     SELECT ... FROM ... JOIN ... WHERE ... ORDER BY ...
///            |        |        |         |            |
///            |        |        |         |            • ordering
///            |        |        |         • filterPromise
///            |        |        • joins
///            |        • source
///            • selectionPromise
private struct SQLQualifiedRelation {
    /// All aliases, including aliases of joined relations
    var allAliases: [TableAlias] {
        joins.reduce(into: [source.alias].compactMap { $0 }) {
            $0.append(contentsOf: $1.value.relation.allAliases)
        }
    }
    
    /// The source
    ///
    ///     SELECT ... FROM ... JOIN ... WHERE ... ORDER BY ...
    ///                     |
    ///                     • source
    let source: SQLQualifiedSource
    
    /// The selection from source, not including selection of joined relations
    private var sourceSelectionPromise: DatabasePromise<[SQLSelectable]>
    
    /// The full selection, including selection of joined relations
    ///
    ///     SELECT ... FROM ... JOIN ... WHERE ... ORDER BY ...
    ///            |
    ///            • selectionPromise
    var selectionPromise: DatabasePromise<[SQLSelectable]> {
        DatabasePromise { db in
            let selection = try self.sourceSelectionPromise.resolve(db)
            return try self.joins.values.reduce(into: selection) { selection, join in
                let joinedSelection = try join.relation.selectionPromise.resolve(db)
                selection.append(contentsOf: joinedSelection)
            }
        }
    }
    
    /// The filtering clause
    ///
    ///     SELECT ... FROM ... JOIN ... WHERE ... ORDER BY ...
    ///                                        |
    ///                                        • filtersPromise
    let filtersPromise: DatabasePromise<[SQLExpression]>
    
    /// The ordering of source, not including ordering of joined relations
    private let sourceOrdering: SQLRelation.Ordering
    
    /// The full ordering, including orderings of joined relations
    ///
    ///     SELECT ... FROM ... JOIN ... WHERE ... ORDER BY ...
    ///                                                     |
    ///                                                     • ordering
    var ordering: SQLRelation.Ordering {
        joins.reduce(sourceOrdering) {
            $0.appending($1.value.relation.ordering)
        }
    }
    
    /// The joins
    ///
    ///     SELECT ... FROM ... JOIN ... WHERE ... ORDER BY ...
    ///                              |
    ///                              • joins
    private(set) var joins: OrderedDictionary<String, SQLQualifiedJoin>
    
    init(_ relation: SQLRelation) {
        // Qualify the source, so that it be disambiguated with an SQL alias
        // if needed (when a select query uses the same table several times).
        // This disambiguation job will be actually performed by
        // SQLGenerationContext, when the SQLSelectQueryGenerator which owns
        // this SQLQualifiedRelation generates SQL.
        source = SQLQualifiedSource(relation.source)
        
        // Qualify all joins, selection, filter, and ordering, so that all
        // identifiers can be correctly disambiguated and qualified.
        joins = relation.children.compactMapValues { SQLQualifiedJoin($0) }
        if let sourceAlias = source.alias {
            sourceSelectionPromise = relation.selectionPromise.map {
                $0.map { $0._qualifiedSelectable(with: sourceAlias) }
            }
            filtersPromise = relation.filtersPromise.map {
                $0.map { $0._qualifiedExpression(with: sourceAlias) }
            }
            sourceOrdering = relation.ordering.qualified(with: sourceAlias)
        } else {
            sourceSelectionPromise = relation.selectionPromise
            filtersPromise = relation.filtersPromise
            sourceOrdering = relation.ordering
        }
    }
    
    /// See SQLQueryGenerator.rowAdapter(_:)
    ///
    /// - parameter db: A database connection.
    /// - parameter startIndex: The index of the leftmost selected column of
    ///   this relation in a full SQL query. `startIndex` is 0 for the relation
    ///   at the root of a SQLQueryGenerator (as opposed to the
    ///   joined relations).
    /// - returns: An optional tuple made of a RowAdapter and the index past the
    ///   rightmost selected column of this relation. Nil is returned if this
    ///   relations does not need any row adapter.
    func rowAdapter(_ db: Database, fromIndex startIndex: Int) throws -> (adapter: RowAdapter, endIndex: Int)? {
        // Root relation && no join => no need for any adapter
        if startIndex == 0 && joins.isEmpty {
            return nil
        }
        
        // The number of columns in source selection. Columns selected by joined
        // relations are appended after.
        let sourceSelectionWidth = try sourceSelectionPromise.resolve(db).reduce(0) {
            try $0 + $1._columnCount(db)
        }
        
        // Recursively build adapters for each joined relation with a selection.
        // Name them according to the join keys.
        var endIndex = startIndex + sourceSelectionWidth
        var scopes: [String: RowAdapter] = [:]
        for (key, join) in joins {
            if let (joinAdapter, joinEndIndex) = try join.relation.rowAdapter(db, fromIndex: endIndex) {
                scopes[key] = joinAdapter
                endIndex = joinEndIndex
            }
        }
        
        // (Root relation || empty selection) && no included relation => no need for any adapter
        if (startIndex == 0 || sourceSelectionWidth == 0) && scopes.isEmpty {
            return nil
        }
        
        // Build a RangeRowAdapter extended with the adapters of joined relations.
        //
        //      // SELECT book.*, author.* FROM book JOIN author ON author.id = book.authorId
        //      let request = Book.including(required: Book.author)
        //      for row in try Row.fetchAll(db, request) {
        //
        // The RangeRowAdapter hides the columns appended by joined relations:
        //
        //          row // [id:1, title:"Moby-Dick"]
        //          let book = Book(row: row)
        //
        // Scopes give access to those joined relations:
        //
        //          row.scopes["author"] // [id:12, name:"Herman Melville"]
        //          let author: Author = row["author"]
        //      }
        let rangeAdapter = RangeRowAdapter(startIndex ..< (startIndex + sourceSelectionWidth))
        let adapter = rangeAdapter.addingScopes(scopes)
        
        return (adapter: adapter, endIndex: endIndex)
    }
    
    /// Removes all selections from joins
    func selectOnly(_ selection: [SQLSelectable]) -> Self {
        let sourceSelectionPromise: DatabasePromise<[SQLSelectable]>
        if let sourceAlias = source.alias {
            sourceSelectionPromise = DatabasePromise(value: selection.map {
                $0._qualifiedSelectable(with: sourceAlias)
            })
        } else {
            sourceSelectionPromise = DatabasePromise(value: selection)
        }
        return self
            .with(\.sourceSelectionPromise, sourceSelectionPromise)
            .map(\.joins, { $0.mapValues { $0.selectOnly([]) } })
    }
}

extension SQLQualifiedRelation: Refinable { }

/// A "qualified" source, where all tables are identified with a table alias.
private enum SQLQualifiedSource {
    case table(tableName: String, alias: TableAlias)
    indirect case subquery(SQLQueryGenerator)
    
    /// Nil for subquery sources.
    ///
    /// Maybe one day we'll support aliased subqueries, as below:
    ///
    ///     SELECT alias.* FROM (SELECT ...) alias
    ///
    /// But today we only use subqueries for SQLQuery.trivialCountQuery,
    /// which does not need any alias:
    ///
    ///     SELECT COUNT(*) FROM (SELECT ...)
    var alias: TableAlias? {
        switch self {
        case let .table(_, alias):
            return alias
        case .subquery:
            return nil
        }
    }
    
    init(_ source: SQLSource) {
        switch source {
        case let .table(tableName, alias):
            let alias = alias ?? TableAlias(tableName: tableName)
            self = .table(tableName: tableName, alias: alias)
        case let .subquery(subquery):
            self = .subquery(SQLQueryGenerator(query: subquery))
        }
    }
    
    func sql(_ context: SQLGenerationContext) throws -> String {
        switch self {
        case let .table(tableName, alias):
            if let aliasName = context.aliasName(for: alias) {
                return "\(tableName.quotedDatabaseIdentifier) \(aliasName.quotedDatabaseIdentifier)"
            } else {
                return "\(tableName.quotedDatabaseIdentifier)"
            }
        case let .subquery(generator):
            let sql = try generator.requestSQL(context)
            return "(\(sql))"
        }
    }
}

/// A "qualified" join, where all tables are identified with a table alias.
private struct SQLQualifiedJoin: Refinable {
    enum Kind: String {
        case leftJoin = "LEFT JOIN"
        case innerJoin = "JOIN"
        
        init?(_ kind: SQLRelation.Child.Kind) {
            switch kind {
            case .oneRequired:
                self = .innerJoin
            case .oneOptional:
                self = .leftJoin
            case .allPrefetched, .allNotPrefetched:
                // Eager loading of to-many associations is not implemented with joins
                return nil
            }
        }
    }
    
    var kind: Kind
    var condition: SQLAssociationCondition
    var relation: SQLQualifiedRelation
    
    init?(_ child: SQLRelation.Child) {
        guard let kind = Kind(child.kind) else {
            return nil
        }
        self.kind = kind
        self.condition = child.condition
        self.relation = SQLQualifiedRelation(child.relation)
    }
    
    func sql(_ context: SQLGenerationContext, leftAlias: TableAlias) throws -> String {
        try sql(context, leftAlias: leftAlias, allowingInnerJoin: true)
    }
    
    /// Removes all selections from joins
    func selectOnly(_ selection: [SQLSelectable]) -> SQLQualifiedJoin {
        map(\.relation) { $0.selectOnly(selection) }
    }
    
    private func sql(
        _ context: SQLGenerationContext,
        leftAlias: TableAlias,
        allowingInnerJoin allowsInnerJoin: Bool)
        throws -> String
    {
        var allowsInnerJoin = allowsInnerJoin
        
        switch self.kind {
        case .innerJoin:
            guard allowsInnerJoin else {
                // TODO: chainOptionalRequired
                //
                // When we eventually implement this, make sure we both support:
                // - joining(optional: assoc.joining(required: ...))
                // - having(assoc.joining(required: ...).isEmpty)
                fatalError("Not implemented: chaining a required association behind an optional association")
            }
        case .leftJoin:
            allowsInnerJoin = false
        }
        
        // JOIN table...
        var sql = try "\(kind.rawValue) \(relation.source.sql(context))"
        guard let rightAlias = relation.source.alias else {
            // This never happens as long as we only use subqueries as sources
            // in the `SELECT COUNT(*) FROM (SELECT ...)` case: see
            // SQLQuery.trivialCountQuery.
            fatalError("Not implemented: join on a subquery")
        }
        
        // ... ON <join conditions> AND <other filters>
        var joinExpressions: [SQLExpression]
        switch condition {
        case let .foreignKey(request: foreignKeyRequest, originIsLeft: originIsLeft):
            joinExpressions = try foreignKeyRequest
                .fetchForeignKeyMapping(context.db)
                .joinMapping(originIsLeft: originIsLeft)
                .joinExpressions(leftAlias: leftAlias)
        }
        joinExpressions += try relation.filtersPromise.resolve(context.db)
        if joinExpressions.isEmpty == false {
            let joiningSQL = try joinExpressions
                .joined(operator: .and)
                ._qualifiedExpression(with: rightAlias)
                .expressionSQL(context, wrappedInParenthesis: false)
            sql += " ON \(joiningSQL)"
        }
        
        for (_, join) in relation.joins {
            // Right becomes left as we dig further
            sql += try " \(join.sql(context, leftAlias: rightAlias, allowingInnerJoin: allowsInnerJoin))"
        }
        
        return sql
    }
}

// MARK: - SQLExpressionIsConstantInRequest

extension SQLExpression {
    /// Returns true if the expression has a unique value when SQLite runs
    /// a request.
    ///
    /// When in doubt, returns false.
    ///
    ///     1          -- true
    ///     1 + 2      -- true
    ///     score      -- false
    ///
    /// Support for `SQLExpression.identifyingColums(_:for:)`
    var isConstantInRequest: Bool {
        var visitor = SQLExpressionIsConstantInRequest()
        do {
            try _accept(&visitor)
        } catch is SQLExpressionIsConstantInRequest.BreakError {
        } catch {
            try! { throw error }()
        }
        return visitor.isConstant
    }
}

/// Support for `SQLExpression.isConstantInRequest`
private struct SQLExpressionIsConstantInRequest: _SQLExpressionVisitor {
    struct BreakError: Error { }
    var isConstant = true
    
    private mutating func setNotConstant() throws -> Never {
        isConstant = false
        // Poor man's short-circuiting
        throw BreakError()
    }
    
    mutating func visit(_ dbValue: DatabaseValue) throws { }
    
    mutating func visit<Column>(_ column: Column) throws where Column: ColumnExpression {
        try setNotConstant()
    }
    
    mutating func visit(_ column: _SQLQualifiedColumn) throws {
        try setNotConstant()
    }
    
    mutating func visit(_ expr: _SQLExpressionBetween) throws {
        try expr.expression._accept(&self)
        try expr.lowerBound._accept(&self)
        try expr.upperBound._accept(&self)
    }
    
    mutating func visit(_ expr: _SQLExpressionBinary) throws {
        try expr.lhs._accept(&self)
        try expr.rhs._accept(&self)
    }
    
    mutating func visit(_ expr: _SQLExpressionAssociativeBinary) throws {
        for expression in expr.expressions {
            try expression._accept(&self)
        }
    }
    
    mutating func visit(_ expr: _SQLExpressionCollate) throws {
        try expr.expression._accept(&self)
    }
    
    mutating func visit(_ expr: _SQLExpressionContains) throws {
        guard let expressions = expr.collection.expressions() else {
            try setNotConstant() // Don't know - assume not constant
        }
        try expr.expression._accept(&self)
        for expression in expressions {
            try expression._accept(&self)
        }
    }
    
    mutating func visit(_ expr: _SQLExpressionCount) throws {
        try setNotConstant() // Don't know - assume not constant
    }
    
    mutating func visit(_ expr: _SQLExpressionCountDistinct) throws {
        try setNotConstant() // Don't know - assume not constant
    }
    
    mutating func visit(_ expr: _SQLExpressionEqual) throws {
        try expr.lhs._accept(&self)
        try expr.rhs._accept(&self)
    }
    
    mutating func visit(_ expr: _SQLExpressionFastPrimaryKey) throws {
        try setNotConstant()
    }
    
    static let knownPureFunctions = [
        "ABS", "CHAR", "COALESCE", "GLOB", "HEX", "IFNULL",
        "IIF", "INSTR", "LENGTH", "LIKE", "LIKELIHOOD",
        "LIKELY", "LOAD_EXTENSION", "LOWER", "LTRIM",
        "NULLIF", "PRINTF", "QUOTE", "REPLACE", "ROUND",
        "RTRIM", "SOUNDEX", "SQLITE_COMPILEOPTION_GET",
        "SQLITE_COMPILEOPTION_USED", "SQLITE_SOURCE_ID",
        "SQLITE_VERSION", "SUBSTR", "TRIM", "TRIM",
        "TYPEOF", "UNICODE", "UNLIKELY", "UPPER", "ZEROBLOB",
    ]
    mutating func visit(_ expr: _SQLExpressionFunction) throws {
        let function = expr.function.uppercased()
        guard
            ((function == "MAX" || function == "MIN") && expr.arguments.count > 1)
            || Self.knownPureFunctions.contains(function)
        else {
            try setNotConstant() // Don't know - assume not constant
        }
        for expression in expr.arguments {
            try expression._accept(&self)
        }
    }
    
    mutating func visit(_ expr: _SQLExpressionIsEmpty) throws {
        try expr.countExpression._accept(&self)
    }
    
    mutating func visit(_ expr: _SQLExpressionLiteral) throws {
        try setNotConstant() // Don't know - assume not constant
    }
    
    mutating func visit(_ expr: _SQLExpressionNot) throws {
        try expr.expression._accept(&self)
    }
    
    mutating func visit(_ expr: _SQLExpressionQualifiedFastPrimaryKey) throws {
        try setNotConstant()
    }
    
    mutating func visit(_ expr: _SQLExpressionTableMatch) throws {
        try setNotConstant()
    }
    
    mutating func visit(_ expr: _SQLExpressionUnary) throws {
        try expr.expression._accept(&self)
    }
    
    // MARK: - _FetchRequestVisitor
    
    mutating func visit<Base: FetchRequest>(_ request: AdaptedFetchRequest<Base>) throws {
        try setNotConstant() // Don't know - assume not constant
    }
    
    mutating func visit<RowDecoder>(_ request: QueryInterfaceRequest<RowDecoder>) throws {
        try setNotConstant() // Don't know - assume not constant
    }
    
    mutating func visit<RowDecoder>(_ request: SQLRequest<RowDecoder>) throws {
        try setNotConstant() // Don't know - assume not constant
    }
}

// MARK: - SQLTableColumnVisitor

extension SQLExpression {
    /// If this expression is a table colum, returns the name of this column.
    ///
    /// When in doubt, returns nil.
    ///
    /// - parameter acceptsBijection: If true, expressions that define a
    ///   bijection on a column return this column. For example: `-score`
    ///   returns `score`.
    func column(_ db: Database, for alias: TableAlias, acceptsBijection: Bool = false) throws -> String? {
        var visitor = SQLTableColumnVisitor(db: db, alias: alias, acceptsBijection: acceptsBijection)
        try _accept(&visitor)
        return visitor.column
    }
}

/// Support for `SQLExpression.column(_:for:)`
private struct SQLTableColumnVisitor: _SQLExpressionVisitor {
    let db: Database
    let alias: TableAlias
    let acceptsBijection: Bool
    var column: String?
    
    mutating func visit(_ dbValue: DatabaseValue) throws { }
    
    mutating func visit<Column>(_ column: Column) throws where Column: ColumnExpression { }
    
    mutating func visit(_ column: _SQLQualifiedColumn) throws {
        if column.alias == alias {
            self.column = column.name
        }
    }
    
    mutating func visit(_ expr: _SQLExpressionBetween) throws { }
    
    mutating func visit(_ expr: _SQLExpressionBinary) throws {
        if acceptsBijection && expr.op == .subtract {
            if expr.lhs.isConstantInRequest {
                try expr.rhs._accept(&self)
            } else if expr.rhs.isConstantInRequest {
                try expr.lhs._accept(&self)
            }
        }
    }
    
    mutating func visit(_ expr: _SQLExpressionAssociativeBinary) throws {
        if acceptsBijection && (expr.op == .add || expr.op == .concat) {
            let nonConstants = expr.expressions.filter { $0.isConstantInRequest == false }
            if nonConstants.count == 1 {
                try nonConstants[0]._accept(&self)
            }
        }
    }
    
    mutating func visit(_ expr: _SQLExpressionCollate) throws {
        try expr.expression._accept(&self)
    }
    
    mutating func visit(_ expr: _SQLExpressionContains) throws { }
    
    mutating func visit(_ expr: _SQLExpressionCount) throws { }
    
    mutating func visit(_ expr: _SQLExpressionCountDistinct) throws { }
    
    mutating func visit(_ expr: _SQLExpressionEqual) throws { }
    
    mutating func visit(_ expr: _SQLExpressionFastPrimaryKey) throws { }
    
    mutating func visit(_ expr: _SQLExpressionFunction) throws {
        if acceptsBijection {
            let function = expr.function.uppercased()
            if ["HEX", "QUOTE"].contains(function) && expr.arguments.count == 1 {
                try expr.arguments[0]._accept(&self)
            } else if function == "IFNULL" && expr.arguments.count == 2 && expr.arguments[1].isConstantInRequest {
                try expr.arguments[0]._accept(&self)
            }
        }
    }
    
    mutating func visit(_ expr: _SQLExpressionIsEmpty) throws { }
    
    mutating func visit(_ expr: _SQLExpressionLiteral) throws { }
    
    mutating func visit(_ expr: _SQLExpressionNot) throws { }
    
    mutating func visit(_ expr: _SQLExpressionQualifiedFastPrimaryKey) throws {
        if expr.alias == alias {
            self.column = try expr.columnName(db)
        }
    }
    
    mutating func visit(_ expr: _SQLExpressionTableMatch) throws { }
    
    mutating func visit(_ expr: _SQLExpressionUnary) throws {
        if acceptsBijection && expr.op == .minus {
            try expr.expression._accept(&self)
        }
    }
    
    // MARK: - _FetchRequestVisitor
    
    mutating func visit<Base: FetchRequest>(_ request: AdaptedFetchRequest<Base>) throws { }
    
    mutating func visit<RowDecoder>(_ request: QueryInterfaceRequest<RowDecoder>) throws { }
    
    mutating func visit<RowDecoder>(_ request: SQLRequest<RowDecoder>) throws { }
}

// MARK: - SQLIdentifyingColumns

extension SQLExpression {
    /// Returns the columns that identify a unique row in the request
    ///
    /// When in doubt, returns an empty set.
    ///
    ///     WHERE 0                         -- []
    ///     WHERE a                         -- []
    ///     WHERE a = b                     -- []
    ///     WHERE a = 1                     -- ["a"]
    ///     WHERE a = 1 AND b = 2           -- ["a", "b"]
    ///     WHERE a = 1 AND b = 2 AND c > 0 -- ["a", "b"]
    ///     WHERE a = 1 OR a = 2            -- []
    ///     WHERE a > 1                     -- []
    ///
    /// Support for `SQLQueryGenerator.expectsSingleResult()`
    func identifyingColums(_ db: Database, for alias: TableAlias) throws -> Set<String> {
        var visitor = SQLIdentifyingColumns(db: db, alias: alias)
        do {
            try _accept(&visitor)
        } catch is SQLIdentifyingColumns.BreakError {
        } catch {
            try! { throw error }()
        }
        return visitor.columns
    }
}

/// Support for `SQLExpression.identifyingColums(_:for:)`
private struct SQLIdentifyingColumns: _SQLExpressionVisitor {
    struct BreakError: Error { }
    let db: Database
    let alias: TableAlias
    var columns: Set<String> = []
    
    mutating func visit(_ dbValue: DatabaseValue) throws { }
    
    mutating func visit<Column>(_ column: Column) throws where Column: ColumnExpression { }
    
    mutating func visit(_ column: _SQLQualifiedColumn) throws { }
    
    mutating func visit(_ expr: _SQLExpressionBetween) throws { }
    
    mutating func visit(_ expr: _SQLExpressionBinary) throws { }
    
    mutating func visit(_ expr: _SQLExpressionAssociativeBinary) throws {
        if expr.op == .and {
            for expression in expr.expressions {
                try expression._accept(&self)
            }
        } else if expr.op == .or {
            columns = []
            throw BreakError()
        }
    }
    
    mutating func visit(_ expr: _SQLExpressionCollate) throws {
        try expr.expression._accept(&self)
    }
    
    mutating func visit(_ expr: _SQLExpressionContains) throws { }
    
    mutating func visit(_ expr: _SQLExpressionCount) throws { }
    
    mutating func visit(_ expr: _SQLExpressionCountDistinct) throws { }
    
    mutating func visit(_ expr: _SQLExpressionEqual) throws {
        switch expr.op {
        case .equal, .is:
            if
                let column = try expr.lhs.column(db, for: alias),
                expr.rhs.isConstantInRequest
            {
                columns.insert(column)
            } else if
                let column = try expr.rhs.column(db, for: alias),
                expr.lhs.isConstantInRequest
            {
                columns.insert(column)
            }
            
        case .notEqual, .isNot:
            break
        }
    }
    
    mutating func visit(_ expr: _SQLExpressionFastPrimaryKey) throws { }
    
    mutating func visit(_ expr: _SQLExpressionFunction) throws { }
    
    mutating func visit(_ expr: _SQLExpressionIsEmpty) throws { }
    
    mutating func visit(_ expr: _SQLExpressionLiteral) throws { }
    
    mutating func visit(_ expr: _SQLExpressionNot) throws { }
    
    mutating func visit(_ expr: _SQLExpressionQualifiedFastPrimaryKey) throws { }
    
    mutating func visit(_ expr: _SQLExpressionTableMatch) throws { }
    
    mutating func visit(_ expr: _SQLExpressionUnary) throws { }
    
    // MARK: - _FetchRequestVisitor
    
    mutating func visit<Base: FetchRequest>(_ request: AdaptedFetchRequest<Base>) throws { }
    
    mutating func visit<RowDecoder>(_ request: QueryInterfaceRequest<RowDecoder>) throws { }
    
    mutating func visit<RowDecoder>(_ request: SQLRequest<RowDecoder>) throws { }
}

// MARK: - SQLIdentifyingRowIDs

extension SQLExpression {
    /// Returns the rowIds that identify rows in the request. A nil result means
    /// an unbounded list.
    ///
    /// When in doubt, returns nil.
    ///
    ///     WHERE 1                               -- nil
    ///     WHERE 0                               -- []
    ///     WHERE NULL                            -- []
    ///     WHERE id IS NULL                      -- []
    ///     WHERE id = 1                          -- [1]
    ///     WHERE id = 1 AND b = 2                -- [1]
    ///     WHERE id = 1 OR id = 2                -- [1, 2]
    ///     WHERE id IN (1, 2, 3)                 -- [1, 2, 3]
    ///     WHERE id IN (1, 2) OR rowid IN (2, 3) -- [1, 2, 3]
    ///     WHERE id > 1                          -- nil
    ///
    /// Support for `SQLQueryGenerator.optimizedSelectedRegion()`
    func identifyingRowIDs(_ db: Database, for alias: TableAlias) throws -> Set<Int64>? {
        var visitor = SQLIdentifyingRowIDs(db: db, alias: alias)
        try _accept(&visitor)
        return visitor.rowIDs
    }
}

/// Support for `SQLExpression.identifyingRowIDs(_:for:)`
private struct SQLIdentifyingRowIDs: _SQLExpressionVisitor {
    let db: Database
    let alias: TableAlias
    var rowIDs: Set<Int64>? = nil
    
    mutating func visit(_ dbValue: DatabaseValue) throws {
        if dbValue.isNull || dbValue == false.databaseValue {
            rowIDs = []
        }
    }
    
    mutating func visit<Column>(_ column: Column) throws where Column: ColumnExpression { }
    
    mutating func visit(_ column: _SQLQualifiedColumn) throws { }
    
    mutating func visit(_ expr: _SQLExpressionBetween) throws { }
    
    mutating func visit(_ expr: _SQLExpressionBinary) throws { }
    
    mutating func visit(_ expr: _SQLExpressionAssociativeBinary) throws {
        if expr.op == .and {
            for expression in expr.expressions {
                if let expressionRowIDs = try expression.identifyingRowIDs(db, for: alias) {
                    if var rowIDs = self.rowIDs {
                        rowIDs.formIntersection(expressionRowIDs)
                        self.rowIDs = rowIDs
                        if rowIDs.isEmpty {
                            break
                        }
                    } else {
                        self.rowIDs = expressionRowIDs
                    }
                }
            }
        } else if expr.op == .or {
            var rowIDs: Set<Int64> = []
            for expression in expr.expressions {
                if let expressionRowIDs = try expression.identifyingRowIDs(db, for: alias) {
                    rowIDs.formUnion(expressionRowIDs)
                } else {
                    self.rowIDs = nil
                    return
                }
            }
            self.rowIDs = rowIDs
        }
    }
    
    mutating func visit(_ expr: _SQLExpressionCollate) throws {
        try expr.expression._accept(&self)
    }
    
    mutating func visit(_ expr: _SQLExpressionContains) throws {
        if
            let expressions = expr.collection.expressions(),
            let column = try expr.expression.column(db, for: alias),
            try db.columnIsRowID(column, of: alias.tableName)
        {
            rowIDs = Set(expressions.compactMap {
                ($0 as? DatabaseValue).flatMap { Int64.fromDatabaseValue($0) }
            })
        }
    }
    
    mutating func visit(_ expr: _SQLExpressionCount) throws { }
    
    mutating func visit(_ expr: _SQLExpressionCountDistinct) throws { }
    
    mutating func visit(_ expr: _SQLExpressionEqual) throws {
        switch expr.op {
        case .equal, .is:
            if
                let column = try expr.lhs.column(db, for: alias),
                try db.columnIsRowID(column, of: alias.tableName),
                let dbValue = expr.rhs as? DatabaseValue
            {
                if let rowID = Int64.fromDatabaseValue(dbValue) {
                    rowIDs = [rowID]
                } else {
                    // We miss `rowid = '1'` here, because SQLite would interpret the '1' string as a number
                    rowIDs = []
                }
            } else if
                let column = try expr.rhs.column(db, for: alias),
                try db.columnIsRowID(column, of: alias.tableName),
                let dbValue = expr.lhs as? DatabaseValue
            {
                if let rowID = Int64.fromDatabaseValue(dbValue) {
                    rowIDs = [rowID]
                } else {
                    // We miss `rowid = '1'` here, because SQLite would interpret the '1' string as a number
                    rowIDs = []
                }
            }
            
        case .notEqual, .isNot:
            break
        }
    }
    
    mutating func visit(_ expr: _SQLExpressionFastPrimaryKey) throws { }
    
    mutating func visit(_ expr: _SQLExpressionFunction) throws { }
    
    mutating func visit(_ expr: _SQLExpressionIsEmpty) throws { }
    
    mutating func visit(_ expr: _SQLExpressionLiteral) throws { }
    
    mutating func visit(_ expr: _SQLExpressionNot) throws { }
    
    mutating func visit(_ expr: _SQLExpressionQualifiedFastPrimaryKey) throws { }
    
    mutating func visit(_ expr: _SQLExpressionTableMatch) throws { }
    
    mutating func visit(_ expr: _SQLExpressionUnary) throws { }
    
    // MARK: - _FetchRequestVisitor
    
    mutating func visit<Base: FetchRequest>(_ request: AdaptedFetchRequest<Base>) throws { }
    
    mutating func visit<RowDecoder>(_ request: QueryInterfaceRequest<RowDecoder>) throws { }
    
    mutating func visit<RowDecoder>(_ request: SQLRequest<RowDecoder>) throws { }
}

// MARK: - SQLSelectableIsAggregate

extension SQLSelectable {
    /// Returns true if the selectable is an aggregate.
    ///
    /// When in doubt, returns false.
    ///
    ///     SELECT *              -- false
    ///     SELECT score          -- false
    ///     SELECT COUNT(*)       -- true
    ///     SELECT MAX(score)     -- true
    ///     SELECT MAX(score) + 1 -- true
    ///
    /// Support for `SQLQueryGenerator.expectsSingleResult()`
    func isAggregate() -> Bool {
        var visitor = SQLSelectableIsAggregate()
        do {
            try _accept(&visitor)
        } catch is SQLSelectableIsAggregate.BreakError {
        } catch {
            try! { throw error }()
        }
        return visitor.isAggregate
    }
}

private struct SQLSelectableIsAggregate: _SQLSelectableVisitor {
    struct BreakError: Error { }
    var isAggregate = false
    
    private mutating func setAggregate() throws -> Never {
        isAggregate = true
        // Poor man's short-circuiting
        throw BreakError()
    }
    
    // MARK: _SQLSelectableVisitor
    
    mutating func visit(_ selectable: AllColumns) throws { }
    
    mutating func visit(_ selectable: _SQLAliasedExpression) throws {
        try selectable.expression._accept(&self)
    }
    
    mutating func visit(_ selectable: _SQLQualifiedAllColumns) throws { }
    
    mutating func visit(_ selectable: _SQLSelectionLiteral) throws {
        // Don't know - assume not an aggregate
    }

    // MARK: _SQLExpressionVisitor
    
    mutating func visit(_ dbValue: DatabaseValue) throws { }
    
    mutating func visit<Column: ColumnExpression>(_ column: Column) throws { }
    
    mutating func visit(_ column: _SQLQualifiedColumn) throws { }
    
    mutating func visit(_ expr: _SQLExpressionBetween) throws {
        try expr.expression._accept(&self)
    }
    
    mutating func visit(_ expr: _SQLExpressionBinary) throws {
        try expr.lhs._accept(&self)
        try expr.rhs._accept(&self)
    }
    
    mutating func visit(_ expr: _SQLExpressionAssociativeBinary) throws {
        for expression in expr.expressions {
            try expression._accept(&self)
        }
    }
    
    mutating func visit(_ expr: _SQLExpressionCollate) throws {
        try expr.expression._accept(&self)
    }
    
    mutating func visit(_ expr: _SQLExpressionContains) throws {
        // SELECT aggregate IN (...)
        try expr.expression._accept(&self)
        
        // SELECT expr IN (aggregate, ...)
        if
            let expressions = expr.collection.expressions(),
            expressions.contains(where: { $0.isAggregate() })
        {
            try setAggregate()
        }
    }
    
    mutating func visit(_ expr: _SQLExpressionCount) throws {
        try setAggregate()
    }
    
    mutating func visit(_ expr: _SQLExpressionCountDistinct) throws {
        try setAggregate()
    }
    
    mutating func visit(_ expr: _SQLExpressionEqual) throws {
        try expr.lhs._accept(&self)
        try expr.rhs._accept(&self)
    }
    
    mutating func visit(_ expr: _SQLExpressionFastPrimaryKey) throws { }
    
    mutating func visit(_ expr: _SQLExpressionFunction) throws {
        let function = expr.function.uppercased()
        if ["MIN", "MAX"].contains(function) && expr.arguments.count == 1 {
            try setAggregate()
        } else if ["AVG", "COUNT", "SUM", "TOTAL"].contains(function) && expr.arguments.count == 1 {
            try setAggregate()
        } else if function == "GROUP_CONCAT" && (expr.arguments.count == 1 || expr.arguments.count == 2) {
            try setAggregate()
        }
    }
    
    mutating func visit(_ expr: _SQLExpressionIsEmpty) throws {
        try expr.countExpression._accept(&self)
    }
    
    mutating func visit(_ expr: _SQLExpressionLiteral) throws {
        // Don't know - assume not an aggregate
    }
    
    mutating func visit(_ expr: _SQLExpressionNot) throws {
        try expr.expression._accept(&self)
    }
    
    mutating func visit(_ expr: _SQLExpressionQualifiedFastPrimaryKey) throws { }
    
    mutating func visit(_ expr: _SQLExpressionTableMatch) throws { }
    
    mutating func visit(_ expr: _SQLExpressionUnary) throws {
        try expr.expression._accept(&self)
    }
    
    // MARK: _FetchRequestVisitor
    
    mutating func visit<Base: FetchRequest>(_ request: AdaptedFetchRequest<Base>) throws { }
    
    mutating func visit<RowDecoder>(_ request: QueryInterfaceRequest<RowDecoder>) throws { }
    
    mutating func visit<RowDecoder>(_ request: SQLRequest<RowDecoder>) throws { }
}

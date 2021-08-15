/// SQLQueryGenerator is able to generate an SQL SELECT query.
struct SQLQueryGenerator: Refinable {
    fileprivate private(set) var relation: SQLQualifiedRelation
    private let singleResult: Bool
    // For database region
    private let prefetchedAssociations: [_SQLAssociation]
    
    /// Creates an SQL query generator.
    ///
    /// - parameter singleResult: A hint as to whether the query should be
    ///   optimized for a single result.
    init(
        relation: SQLRelation,
        forSingleResult singleResult: Bool = false)
    {
        self.relation = SQLQualifiedRelation(relation)
        self.prefetchedAssociations = relation.prefetchedAssociations
        self.singleResult = singleResult
    }
    
    func requestSQL(_ context: SQLGenerationContext) throws -> String {
        let context = context.subqueryContext(aliases: relation.allAliases, ctes: relation.ctes)
        
        var sql = try commonTableExpressionsPrefix(context)
        sql += "SELECT"
        
        if relation.isDistinct {
            sql += " DISTINCT"
        }
        
        let selection = try relation.selectionPromise.resolve(context.db)
        GRDBPrecondition(!selection.isEmpty, "Can't generate SQL with an empty selection")
        sql += " "
        sql += try selection
            .map { try $0.sql(context) }
            .joined(separator: ", ")
        
        sql += " FROM "
        sql += try relation.source.sql(context)
        
        if relation.joins.isEmpty == false {
            let sourceAlias = relation.source.alias
            for (_, join) in relation.joins {
                sql += " "
                sql += try join.sql(context, leftAlias: sourceAlias)
            }
        }
        
        let filter = try relation.filterPromise?.resolve(context.db)
        if let filter = filter {
            sql += " WHERE "
            sql += try filter.sql(context)
        }
        
        let groupExpressions = try relation.groupPromise?.resolve(context.db) ?? []
        if !groupExpressions.isEmpty {
            sql += " GROUP BY "
            sql += try groupExpressions
                .map { try $0.sql(context) }
                .joined(separator: ", ")
        }
        
        if let havingExpression = try relation.havingExpressionPromise?.resolve(context.db) {
            sql += " HAVING "
            sql += try havingExpression.sql(context)
        }
        
        let orderings = try relation.ordering.resolve(context.db)
        if !orderings.isEmpty {
            sql += " ORDER BY "
            sql += try orderings
                .map { try $0.sql(context) }
                .joined(separator: ", ")
        }
        
        var limit = relation.limit
        if try limit == nil && singleResult && !expectsSingleResult(
            context.db,
            selection: selection,
            filter: filter,
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
            statement: makeStatement(db),
            adapter: rowAdapter(SQLGenerationContext(db, ctes: relation.ctes)))
    }
    
    /// The number of fetched columns.
    func columnCount(_ db: Database) throws -> Int {
        try relation
            .selectionPromise
            .resolve(db)
            .columnCount(SQLGenerationContext(db, ctes: relation.ctes))
    }
    
    /// Returns a prepared statement
    func makeStatement(_ db: Database) throws -> Statement {
        // Build
        let context = SQLGenerationContext(db)
        let sql = try requestSQL(context)
        
        // Compile & set arguments
        let statement = try db.makeStatement(sql: sql)
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
            let region = try prefetchedRegion(
                db,
                associations: prefetchedAssociations,
                from: relation.source.tableName)
            statement.databaseRegion.formUnion(region)
        }
        
        return statement
    }
    
    private func optimizedSelectedRegion(_ db: Database, _ selectedRegion: DatabaseRegion) throws -> DatabaseRegion {
        // Can we intersect the region with rowIds?
        //
        // Give up unless request feeds from a single database table
        let tableName = relation.source.tableName
        guard try db.tableExists(tableName) else { // skip views
            return selectedRegion
        }
        
        // The filter knows better
        guard let filter = try relation.filterPromise?.resolve(db),
              let rowIDs = try filter.identifyingRowIDs(db, for: relation.source.alias)
        else {
            return selectedRegion
        }
        
        return selectedRegion.tableIntersection(tableName, rowIds: rowIDs)
    }
    
    /// If true, executing this query yields at most one row.
    /// If false, we don't know how many rows this query returns.
    private func expectsSingleResult(
        _ db: Database,
        selection: [SQLSelection],
        filter: SQLExpression?,
        groupExpressions: [SQLExpression])
    throws -> Bool
    {
        if relation.joins.isEmpty == false {
            // Don't expect single results as soon as there is a join
            return false
        }
        
        // Do we filter on a unique key?
        let tableName = relation.source.tableName
        if try db.tableExists(tableName), // skip views
           let identifyingColums = try filter?.identifyingColums(db, for: relation.source.alias),
           try db.table(tableName, hasUniqueKey: identifyingColums)
        {
            // Filter by unique key: guaranteed single row!
            return true
        }
        
        // Do we aggregate without grouping?
        if groupExpressions.isEmpty && selection.contains(where: \.isAggregate) {
            // Selection contains an aggregate function: guaranteed single row!Ë
            return true
        }
        
        return false
    }
    
    func makeDeleteStatement(_ db: Database) throws -> Statement {
        switch try grouping(db) {
        case .none:
            guard relation.joins.isEmpty else {
                return try makeTrivialDeleteStatement(db)
            }
            
            let context = SQLGenerationContext(db, aliases: relation.allAliases, ctes: relation.ctes)
            
            var sql = try commonTableExpressionsPrefix(context)
            sql += try "DELETE FROM " + relation.source.sql(context)
            
            if let filter = try relation.filterPromise?.resolve(db) {
                sql += " WHERE "
                sql += try filter.sql(context)
            }
            
            if let limit = relation.limit {
                let orderings = try relation.ordering.resolve(db)
                if !orderings.isEmpty {
                    sql += " ORDER BY "
                    sql += try orderings
                        .map { try $0.sql(context) }
                        .joined(separator: ", ")
                }
                sql += " LIMIT " + limit.sql
            }
            
            let statement = try db.makeStatement(sql: sql)
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
    private func makeTrivialDeleteStatement(_ db: Database) throws -> Statement {
        let tableName = relation.source.tableName
        let alias = TableAlias(tableName: tableName)
        let context = SQLGenerationContext(db, aliases: [alias])
        let subqueryContext = context.subqueryContext(aliases: relation.allAliases, ctes: relation.ctes)
        let primaryKey = SQLExpression.fastPrimaryKey
        let selectPrimaryKey = self.with {
            $0.relation = $0.relation.selectOnly([.expression(primaryKey)])
        }
        
        var sql = "DELETE FROM \(tableName.quotedDatabaseIdentifier) WHERE "
        sql += try alias[primaryKey].sql(context)
        sql += " IN ("
        sql += try selectPrimaryKey.requestSQL(subqueryContext)
        sql += ")"
        
        let statement = try db.makeStatement(sql: sql)
        statement.arguments = context.arguments
        return statement
    }
    
    /// Returns nil if assignments is empty
    func makeUpdateStatement(
        _ db: Database,
        conflictResolution: Database.ConflictResolution,
        assignments: [ColumnAssignment])
    throws -> Statement?
    {
        switch try grouping(db) {
        case .none:
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
            
            let context = SQLGenerationContext(db, aliases: relation.allAliases, ctes: relation.ctes)
            
            var sql = try commonTableExpressionsPrefix(context)
            sql += "UPDATE "
            
            if conflictResolution != .abort {
                sql += "OR \(conflictResolution.rawValue) "
            }
            
            sql += try relation.source.sql(context)
            
            sql += " SET "
            sql += try assignments
                .map { try $0.sql(context) }
                .joined(separator: ", ")
            
            if let filter = try relation.filterPromise?.resolve(db) {
                sql += " WHERE "
                sql += try filter.sql(context)
            }
            
            if let limit = relation.limit {
                let orderings = try relation.ordering.resolve(db)
                if !orderings.isEmpty {
                    sql += " ORDER BY "
                    sql += try orderings
                        .map { try $0.sql(context) }
                        .joined(separator: ", ")
                }
                sql += " LIMIT " + limit.sql
            }
            
            let statement = try db.makeStatement(sql: sql)
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
    throws -> Statement?
    {
        // Check for empty assignments after all programmer errors have
        // been checked.
        if assignments.isEmpty {
            return nil
        }
        
        let tableName = relation.source.tableName
        let alias = TableAlias(tableName: tableName)
        let context = SQLGenerationContext(db, aliases: [alias])
        let subqueryContext = context.subqueryContext(aliases: relation.allAliases, ctes: relation.ctes)
        let primaryKey = SQLExpression.fastPrimaryKey
        let selectPrimaryKey = self.with {
            $0.relation = $0.relation.selectOnly([.expression(primaryKey)])
        }
        
        // UPDATE table...
        var sql = "UPDATE "
        if conflictResolution != .abort {
            sql += "OR \(conflictResolution.rawValue) "
        }
        sql += tableName.quotedDatabaseIdentifier
        
        // SET column = value...
        sql += " SET "
        sql += try assignments
            .map { try $0.sql(context) }
            .joined(separator: ", ")
        
        // WHERE id IN (SELECT id FROM ...)
        sql += " WHERE "
        sql += try alias[primaryKey].sql(context)
        sql += " IN ("
        sql += try selectPrimaryKey.requestSQL(subqueryContext)
        sql += ")"
        
        let statement = try db.makeStatement(sql: sql)
        statement.arguments = context.arguments
        return statement
    }
    
    private func commonTableExpressionsPrefix(_ context: SQLGenerationContext) throws -> String {
        if relation.ctes.isEmpty {
            return ""
        }
        
        var sql = "WITH "
        if relation.ctes.values.contains(where: \.isRecursive) {
            sql += "RECURSIVE "
        }
        sql += try relation.ctes
            .map { tableName, cte in
                var columnsSQL = ""
                if let columns = cte.columns, !columns.isEmpty {
                    columnsSQL = "("
                    columnsSQL += columns
                        .map(\.quotedDatabaseIdentifier)
                        .joined(separator: ", ")
                    columnsSQL += ")"
                }
                let cteContext = context.subqueryContext()
                let subquerySQL = try cte.sqlSubquery.sql(cteContext)
                return "\(tableName.quotedDatabaseIdentifier)\(columnsSQL) AS (\(subquerySQL))"
            }
            .joined(separator: ", ")
        sql += " "
        return sql
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
        guard let groupExpressions = try relation.groupPromise?.resolve(db), groupExpressions.isEmpty == false else {
            return .none
        }
        
        // Grouping something which is not a table: assume non unique grouping.
        let tableName = relation.source.tableName
        guard try db.tableExists(tableName) else { // skip views
            return .nonUnique
        }
        
        var groupingColumns: Set<String> = []
        for expression in groupExpressions {
            guard let column = try expression.column(db, for: relation.source.alias, acceptsBijection: true) else {
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
    private func rowAdapter(_ context: SQLGenerationContext) throws -> RowAdapter? {
        try relation.rowAdapter(context, fromIndex: 0, rootRelation: true)?.adapter
    }
}

/// To generate SQL, we need a "qualified" relation, where all tables,
/// expressions, etc, are qualified with table aliases.
///
/// All those aliases let us disambiguate tables at the SQL level, and
/// prefix columns names. For example, the following request...
///
///      Book.filter(Column("kind") == Book.Kind.novel)
///          .including(optional: Book.author)
///          .including(optional: Book.translator)
///          .annotated(with: Book.awards.count)
///
/// ... generates the following SQL, where all identifiers are correctly
/// disambiguated and qualified:
///
///      SELECT book.*, person1.*, person2.*, COUNT(DISTINCT award.id)
///      FROM book
///      LEFT JOIN person person1 ON person1.id = book.authorId
///      LEFT JOIN person person2 ON person2.id = book.translatorId
///      LEFT JOIN award ON award.bookId = book.id
///      GROUP BY book.id
///      WHERE book.kind = 'novel'
///
/// `SQLQualifiedRelation` contains the following information:
///
///     WITH ...     -- ctes
///     SELECT ...   -- selectionPromise
///     FROM ...     -- source
///     JOIN ...     -- joins
///     WHERE ...    -- filterPromise
///     GROUP BY ... -- groupPromise
///     HAVING ...   -- havingExpressionPromise
///     ORDER BY ... -- ordering
///     LIMIT ...    -- limit

private struct SQLQualifiedRelation {
    /// All aliases, including aliases of joined relations
    var allAliases: [TableAlias] {
        joins.reduce(into: [source.alias].compactMap { $0 }) {
            $0.append(contentsOf: $1.value.relation.allAliases)
        }
    }
    
    /// The source
    let source: SQLQualifiedSource
    
    /// The selection from source, not including selection of joined relations
    private var sourceSelectionPromise: DatabasePromise<[SQLSelection]>
    
    var isDistinct: Bool

    /// The full selection, including selection of joined relations
    var selectionPromise: DatabasePromise<[SQLSelection]> {
        DatabasePromise { db in
            let selection = try self.sourceSelectionPromise.resolve(db)
            return try self.joins.values.reduce(into: selection) { selection, join in
                let joinedSelection = try join.relation.selectionPromise.resolve(db)
                selection.append(contentsOf: joinedSelection)
            }
        }
    }
    
    let filterPromise: DatabasePromise<SQLExpression>?
    
    /// The ordering of source, not including ordering of joined relations
    private let sourceOrdering: SQLRelation.Ordering
    
    /// The full ordering, including orderings of joined relations
    var ordering: SQLRelation.Ordering {
        joins.reduce(sourceOrdering) {
            $0.appending($1.value.relation.ordering)
        }
    }
    
    private(set) var joins: OrderedDictionary<String, SQLQualifiedJoin>
    let groupPromise: DatabasePromise<[SQLExpression]>?
    let havingExpressionPromise: DatabasePromise<SQLExpression>?
    let limit: SQLLimit?
    let ctes: OrderedDictionary<String, SQLCTE>

    init(_ relation: SQLRelation) {
        // Qualify the source, so that it be disambiguated with an SQL alias
        // if needed (when a select query uses the same table several times).
        // This disambiguation job will be actually performed by
        // SQLGenerationContext, when the SQLSelectQueryGenerator which owns
        // this SQLQualifiedRelation generates SQL.
        source = SQLQualifiedSource(relation.source)
        
        // Qualify all selection, filter, etc, so that all identifiers
        // can be correctly disambiguated and qualified.
        let sourceAlias = source.alias
        sourceSelectionPromise = relation.selectionPromise.map {
            $0.map { $0.qualified(with: sourceAlias) }
        }
        filterPromise = relation.filterPromise.map {
            $0.map { $0.qualified(with: sourceAlias) }
        }
        sourceOrdering = relation.ordering.qualified(with: sourceAlias)
        groupPromise = relation.groupPromise?.map {
            $0.map { $0.qualified(with: sourceAlias) }
        }
        havingExpressionPromise = relation.havingExpressionPromise.map {
            $0.map { $0.qualified(with: sourceAlias) }
        }
        
        // Turns relation children into joins. `including(all:)` children are
        // discarded on the way.
        joins = relation.children.compactMapValues { SQLQualifiedJoin($0) }
        
        // Copy other flags
        limit = relation.limit
        isDistinct = relation.isDistinct
        ctes = relation.allCTEs
    }
    
    /// See SQLQueryGenerator.rowAdapter(_:)
    ///
    /// - parameter startIndex: The index of the leftmost selected column of
    ///   this relation in a full SQL query.
    /// - parameter rootRelation: True iff the relation is at the root of a
    ///   SQLQueryGenerator (as opposed to the joined relations).
    /// - returns: An optional tuple made of a RowAdapter and the index past the
    ///   rightmost selected column of this relation. Nil is returned if this
    ///   relations does not need any row adapter.
    func rowAdapter(
        _ context: SQLGenerationContext,
        fromIndex startIndex: Int,
        rootRelation: Bool) throws
    -> (adapter: RowAdapter, endIndex: Int)?
    {
        // Root relation && no join => no need for any adapter
        if rootRelation && joins.isEmpty {
            return nil
        }
        
        // The number of columns in source selection. Columns selected by joined
        // relations are appended after.
        let sourceSelectionWidth = try sourceSelectionPromise.resolve(context.db).columnCount(context)
        
        // Recursively build adapters for each joined relation with a selection.
        // Name them according to the join keys.
        var endIndex = startIndex + sourceSelectionWidth
        var scopes: [String: RowAdapter] = [:]
        for (key, join) in joins {
            if let (joinAdapter, joinEndIndex) = try join
                .relation
                .rowAdapter(context, fromIndex: endIndex, rootRelation: false)
            {
                scopes[key] = joinAdapter
                endIndex = joinEndIndex
            }
        }
        
        // (Root relation || empty selection) && no included relation => no need for any adapter
        if (rootRelation || sourceSelectionWidth == 0) && scopes.isEmpty {
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
    
    /// Sets the selection, removes all selections from joins, and clears the
    /// `isDistinct` flag.
    func selectOnly(_ selection: [SQLSelection]) -> Self {
        let qualifiedSelection = selection.map {
            $0.qualified(with: source.alias)
        }
        return with {
            $0.sourceSelectionPromise = DatabasePromise(value: qualifiedSelection)
            $0.isDistinct = false
            $0.joins = $0.joins.mapValues { join in
                join.with {
                    $0.relation = $0.relation.selectOnly([])
                }
            }
        }
    }
}

extension SQLQualifiedRelation: Refinable { }

/// A "qualified" source, where all tables are identified with a table alias.
private struct SQLQualifiedSource {
    var tableName: String
    var alias: TableAlias
    
    init(_ source: SQLSource) {
        self.tableName = source.tableName
        self.alias = source.alias ?? TableAlias(tableName: source.tableName)
        assert(alias.tableName == tableName)
    }
    
    func sql(_ context: SQLGenerationContext) throws -> String {
        if let aliasName = context.aliasName(for: alias) {
            return "\(tableName.quotedDatabaseIdentifier) \(aliasName.quotedDatabaseIdentifier)"
        } else {
            return "\(tableName.quotedDatabaseIdentifier)"
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
            case .all, .bridge:
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
        
        // ... ON <join conditions> AND <other filters>
        let rightAlias = relation.source.alias
        var conditions: [SQLExpression] = []
        
        if let expression = try condition.joinExpression(context.db,
                                                         leftAlias: leftAlias,
                                                         rightAlias: rightAlias)
        {
            conditions.append(expression)
        }
        
        if let filter = try relation.filterPromise?.resolve(context.db) {
            conditions.append(filter.qualified(with: rightAlias))
        }
        
        if conditions.isEmpty == false {
            sql += " ON "
            sql += try conditions
                .joined(operator: .and)
                .sql(context)
        }
        
        for (_, join) in relation.joins {
            // Right becomes left as we dig further
            sql += try " \(join.sql(context, leftAlias: rightAlias, allowingInnerJoin: allowsInnerJoin))"
        }
        
        return sql
    }
}

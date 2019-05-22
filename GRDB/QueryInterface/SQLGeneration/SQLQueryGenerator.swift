/// SQLQueryGenerator is able to generate an SQL SELECT query.
struct SQLQueryGenerator {
    fileprivate let relation: SQLQualifiedRelation
    private let isDistinct: Bool
    private let groupPromise: DatabasePromise<[SQLExpression]>?
    private let havingExpression: SQLExpression?
    private let limit: SQLLimit?
    
    init(_ query: SQLQuery) {
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
        let alias = relation.alias
        groupPromise = query.groupPromise?.map { [alias] in $0.map { $0.qualifiedExpression(with: alias) } }
        havingExpression = query.havingExpression?.qualifiedExpression(with: alias)
        
        // Preserve other flags
        isDistinct = query.isDistinct
        limit = query.limit
    }
    
    func sql(_ db: Database, _ context: inout SQLGenerationContext) throws -> String {
        var sql = "SELECT"
        
        if isDistinct {
            sql += " DISTINCT"
        }
        
        let selection = relation.selection
        GRDBPrecondition(!selection.isEmpty, "Can't generate SQL with empty selection")
        sql += " " + selection.map { $0.resultColumnSQL(&context) }.joined(separator: ", ")
        
        sql += try " FROM " + relation.source.sql(db, &context)
        
        for (_, join) in relation.joins {
            sql += try " " + join.sql(db, &context, leftAlias: relation.alias)
        }
        
        if let filter = try relation.filterPromise.resolve(db) {
            sql += " WHERE " + filter.expressionSQL(&context)
        }
        
        if let groupExpressions = try groupPromise?.resolve(db), !groupExpressions.isEmpty {
            sql += " GROUP BY " + groupExpressions.map { $0.expressionSQL(&context) }.joined(separator: ", ")
        }
        
        if let havingExpression = havingExpression {
            sql += " HAVING " + havingExpression.expressionSQL(&context)
        }
        
        let orderings = try relation.ordering.resolve(db)
        if !orderings.isEmpty {
            sql += " ORDER BY " + orderings.map { $0.orderingTermSQL(&context) }.joined(separator: ", ")
        }
        
        if let limit = limit {
            sql += " LIMIT " + limit.sql
        }
        
        return sql
    }
    
    func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
        return try (makeSelectStatement(db), rowAdapter(db))
    }
    
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
        
        var context = SQLGenerationContext.queryGenerationContext(aliases: relation.allAliases)
        
        var sql = try "DELETE FROM " + relation.source.sql(db, &context)
        
        if let filter = try relation.filterPromise.resolve(db) {
            sql += " WHERE " + filter.expressionSQL(&context)
        }
        
        if let limit = limit {
            let orderings = try relation.ordering.resolve(db)
            if !orderings.isEmpty {
                sql += " ORDER BY " + orderings.map { $0.orderingTermSQL(&context) }.joined(separator: ", ")
            }
            
            if Database.sqliteCompileOptions.contains("ENABLE_UPDATE_DELETE_LIMIT") {
                sql += " LIMIT " + limit.sql
            } else {
                fatalError("Can't delete query with limit")
            }
        }
        
        let statement = try db.makeUpdateStatement(sql: sql)
        statement.arguments = context.arguments!
        return statement
    }
    
    /// Returns a select statement
    private func makeSelectStatement(_ db: Database) throws -> SelectStatement {
        // Build an SQK generation context with all aliases found in the query,
        // so that we can disambiguate tables that are used several times with
        // SQL aliases.
        var context = SQLGenerationContext.queryGenerationContext(aliases: relation.allAliases)
        
        // Generate SQL
        let sql = try self.sql(db, &context)
        
        // Compile & set arguments
        let statement = try db.makeSelectStatement(sql: sql)
        statement.arguments = context.arguments! // not nil for this kind of context
        return statement
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
        return try relation.rowAdapter(db, fromIndex: 0)?.adapter
    }
}

/// A "qualified" relation, where all tables are identified with a table alias.
///
///     SELECT ... FROM ... AS ... JOIN ... WHERE ... ORDER BY ...
///            |        |      |        |         |            |
///            |        |      |        |         |            • ordering
///            |        |      |        |         • filterPromise
///            |        |      |        • joins
///            |        |      • alias
///            |        • source
///            • fullSelection
private struct SQLQualifiedRelation {
    /// The alias for the relation
    ///
    ///     SELECT ... FROM ... AS ... JOIN ... WHERE ... ORDER BY ...
    ///                            |
    ///                            • alias
    let alias: TableAlias
    
    /// All aliases, including aliases of joined relations
    var allAliases: [TableAlias] {
        var aliases = [alias]
        for join in joins.values {
            aliases.append(contentsOf: join.relation.allAliases)
        }
        aliases.append(contentsOf: source.allAliases)
        return aliases
    }
    
    /// The source
    ///
    ///     SELECT ... FROM ... AS ... JOIN ... WHERE ... ORDER BY ...
    ///                     |
    ///                     • source
    let source: SQLQualifiedSource
    
    /// The selection, not including selection of joined relations
    private let ownSelection: [SQLSelectable]
    
    /// The full selection, including selection of joined relations
    ///
    ///     SELECT ... FROM ... AS ... JOIN ... WHERE ... ORDER BY ...
    ///            |
    ///            • fullSelection
    var selection: [SQLSelectable] {
        return joins.reduce(into: ownSelection) {
            $0.append(contentsOf: $1.value.relation.selection)
        }
    }
    
    /// The filtering clause
    ///
    ///     SELECT ... FROM ... AS ... JOIN ... WHERE ... ORDER BY ...
    ///                                               |
    ///                                               • filterPromise
    let filterPromise: DatabasePromise<SQLExpression?>
    
    /// The ordering, not including ordering of joined relations
    private let ownOrdering: SQLRelation.Ordering
    
    /// The full ordering, including orderings of joined relations
    ///
    ///     SELECT ... FROM ... AS ... JOIN ... WHERE ... ORDER BY ...
    ///                                                            |
    ///                                                            • ordering
    var ordering: SQLRelation.Ordering {
        return joins.reduce(ownOrdering) {
            $0.appending($1.value.relation.ordering)
        }
    }
    
    /// The joins
    ///
    ///     SELECT ... FROM ... AS ... JOIN ... WHERE ... ORDER BY ...
    ///                                     |
    ///                                     • joins
    let joins: OrderedDictionary<String, SQLQualifiedJoin>
    
    init(_ relation: SQLRelation) {
        // Qualify the source, so that it be disambiguated with an SQL alias
        // if needed (when a select query uses the same table several times).
        // This disambiguation job will be actually performed by
        // SQLGenerationContext, when the SQLSelectQueryGenerator which owns
        // this SQLQualifiedRelation generates SQL.
        source = SQLQualifiedSource(relation.source)
        let alias = source.alias
        self.alias = alias
        
        // Qualify all joins, selection, filter, and ordering, so that all
        // identifiers can be correctly disambiguated and qualified.
        joins = relation.children.compactMapValues { child -> SQLQualifiedJoin? in
            let kind: SQLQualifiedJoin.Kind
            switch child.kind {
            case .oneRequired:
                kind = .innerJoin
            case .oneOptional:
                kind = .leftJoin
            case .allPrefetched, .allNotPrefetched:
                // This relation child is not fetched with an SQL join.
                return nil
            }
            
            return SQLQualifiedJoin(
                kind: kind,
                condition: child.condition,
                relation: SQLQualifiedRelation(child.relation))
        }
        ownSelection = relation.selection.map { $0.qualifiedSelectable(with: alias) }
        filterPromise = relation.filterPromise.map { [alias] in $0?.qualifiedExpression(with: alias) }
        ownOrdering = relation.ordering.qualified(with: alias)
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
        
        // The number of columns in own selection. Columns selected by joined
        // relations are appended after.
        let selectionWidth = try ownSelection
            .map { try $0.columnCount(db) }
            .reduce(0, +)
        
        // Recursively build adapters for each joined relation with a selection.
        // Name them according to the join keys.
        var endIndex = startIndex + selectionWidth
        var scopes: [String: RowAdapter] = [:]
        for (key, join) in joins {
            if let (joinAdapter, joinEndIndex) = try join.relation.rowAdapter(db, fromIndex: endIndex) {
                scopes[key] = joinAdapter
                endIndex = joinEndIndex
            }
        }
        
        // (Root relation || empty selection) && no included relation => no need for any adapter
        if (startIndex == 0 || selectionWidth == 0) && scopes.isEmpty {
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
        let rangeAdapter = RangeRowAdapter(startIndex ..< (startIndex + selectionWidth))
        let adapter = rangeAdapter.addingScopes(scopes)
        
        return (adapter: adapter, endIndex: endIndex)
    }
}

/// A "qualified" source, where all tables are identified with a table alias.
private enum SQLQualifiedSource {
    case table(tableName: String, alias: TableAlias)
    indirect case query(SQLQueryGenerator)
    
    var alias: TableAlias {
        switch self {
        case .table(_, let alias):
            return alias
        case .query(let query):
            return query.relation.alias
        }
    }
    
    var allAliases: [TableAlias] {
        switch self {
        case .table(_, let alias):
            return [alias]
        case .query(let query):
            return query.relation.allAliases
        }
    }
    
    init(_ source: SQLSource) {
        switch source {
        case .table(let tableName, let alias):
            let alias = alias ?? TableAlias(tableName: tableName)
            self = .table(tableName: tableName, alias: alias)
        case .query(let query):
            self = .query(SQLQueryGenerator(query))
        }
    }
    
    func sql(_ db: Database, _ context: inout SQLGenerationContext) throws -> String {
        switch self {
        case .table(let tableName, let alias):
            if let aliasName = context.aliasName(for: alias) {
                return "\(tableName.quotedDatabaseIdentifier) \(aliasName.quotedDatabaseIdentifier)"
            } else {
                return "\(tableName.quotedDatabaseIdentifier)"
            }
        case .query(let query):
            return try "(\(query.sql(db, &context)))"
        }
    }
}

/// A "qualified" join, where all tables are identified with a table alias.
private struct SQLQualifiedJoin {
    enum Kind: String {
        case leftJoin = "LEFT JOIN"
        case innerJoin = "JOIN"
    }
    let kind: Kind
    let condition: SQLAssociationCondition
    let relation: SQLQualifiedRelation
    
    func sql(_ db: Database,_ context: inout SQLGenerationContext, leftAlias: TableAlias) throws -> String {
        return try sql(db, &context, leftAlias: leftAlias, allowingInnerJoin: true)
    }
    
    private func sql(_ db: Database,_ context: inout SQLGenerationContext, leftAlias: TableAlias, allowingInnerJoin allowsInnerJoin: Bool) throws -> String {
        var allowsInnerJoin = allowsInnerJoin
        var sql = ""
        
        switch self.kind {
        case .innerJoin:
            guard allowsInnerJoin else {
                // TODO: chainOptionalRequired
                fatalError("Not implemented: chaining a required association behind an optional association")
            }
        case .leftJoin:
            allowsInnerJoin = false
        }
        sql += kind.rawValue
        sql += try " " + relation.source.sql(db, &context)
        
        let rightAlias = relation.alias
        let filters = try [
            condition.joinExpression(db, leftAlias: leftAlias, rightAlias: rightAlias),
            relation.filterPromise.resolve(db)
            ].compactMap { $0 }
        if !filters.isEmpty {
            sql += " ON " + filters.joined(operator: .and).expressionSQL(&context)
        }
        
        for (_, join) in relation.joins {
            sql += try " " + join.sql(db, &context, leftAlias: rightAlias, allowingInnerJoin: allowsInnerJoin)
        }
        
        return sql
    }
}

/// SQLSelectQueryGenerator is able to generate an SQL SELECT query.
struct SQLSelectQueryGenerator {
    private let relation: SQLQualifiedRelation
    private let isDistinct: Bool
    private let groupPromise: DatabasePromise<[SQLExpression]>?
    private let havingExpression: SQLExpression?
    private let limit: SQLLimit?
    
    init(_ query: SQLSelectQuery) {
        // To generate SQL, we need a "qualified" relation, where all tables,
        // expressions, etc, are identified with table aliases.
        //
        // All those aliases let us disambiguate tables at the SQL level, and
        // prefix columns names, as in the example below:
        //
        //      // SELECT book.*, person1.*, person2.*, COUNT(DISTINCT awards.id)
        //      // FROM book
        //      // LEFT JOIN person person1 WHERE person1.id = book.authorId
        //      // LEFT JOIN person person2 WHERE person2.id = book.translatorId
        //      // LEFT JOIN award WHERE award.bookId = book.id
        //      let request = Book
        //          .including(optional: Book.author)
        //          .including(optional: Book.translator)
        //          .annotated(with: Book.awards.count)
        relation = SQLQualifiedRelation(query.relation)
        
        // Qualify group expressions and having clause with the relation alias.
        //
        // This turns `GROUP BY id` INTO `GROUP BY book.id`, and
        // `HAVING MAX(year) < 2000` INTO `HAVING MAX(book.year) < 2000`.
        let alias = relation.alias
        groupPromise = query.groupPromise?.map { [alias] (_, exprs) in exprs.map { $0.qualifiedExpression(with: alias) } }
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
        
        let selection = relation.fullSelection
        GRDBPrecondition(!selection.isEmpty, "Can't generate SQL with empty selection")
        sql += " " + selection.map { $0.resultColumnSQL(&context) }.joined(separator: ", ")
        
        sql += try " FROM " + relation.source.sql(db, &context)
        
        for (_, join) in relation.joins {
            sql += try " " + join.sql(db, &context, leftAlias: relation.alias, isRequiredAllowed: true)
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
        
        let statement = try db.makeUpdateStatement(sql)
        statement.arguments = context.arguments!
        return statement
    }
    
    private func makeSelectStatement(_ db: Database) throws -> SelectStatement {
        var context = SQLGenerationContext.queryGenerationContext(aliases: relation.allAliases)
        let statement = try db.makeSelectStatement(sql(db, &context))
        statement.arguments = context.arguments!
        return statement
    }
    
    private func rowAdapter(_ db: Database) throws -> RowAdapter? {
        return try relation.rowAdapter(db, fromIndex: 0, forKeyPath: [])?.adapter
    }
}

/// A "qualified" relation, where all tables are identified with a table alias.
private struct SQLQualifiedRelation {
    /// The alias for the source
    ///
    ///     SELECT ... FROM ... AS ... JOIN ... WHERE ... ORDER BY ...
    ///                            ^ alias
    let alias: TableAlias
    
    /// Own alias plus aliases of all joined relations
    let allAliases: [TableAlias]
    
    /// The source
    ///
    ///     SELECT ... FROM ... AS ... JOIN ... WHERE ... ORDER BY ...
    ///                     ^ source
    let source: SQLQualifiedSource
    
    /// The selection, not including selection of joined relations
    private let ownSelection: [SQLSelectable]
    
    /// The full selection, including selection of joined relations
    ///
    ///     SELECT ... FROM ... AS ... JOIN ... WHERE ... ORDER BY ...
    ///            ^ fullSelection
    let fullSelection: [SQLSelectable]
    
    /// The filtering clause
    ///
    ///     SELECT ... FROM ... AS ... JOIN ... WHERE ... ORDER BY ...
    ///                                               ^ filterPromise
    let filterPromise: DatabasePromise<SQLExpression?>
    
    /// The ordering
    ///
    ///     SELECT ... FROM ... AS ... JOIN ... WHERE ... ORDER BY ...
    ///                                                           ^ ordering
    let ordering: SQLRelation.Ordering
    
    /// The joins
    ///
    ///     SELECT ... FROM ... AS ... JOIN ... WHERE ... ORDER BY ...
    ///                                ^ joins
    let joins: OrderedDictionary<String, SQLQualifiedJoin>
    
    init(_ relation: SQLRelation) {
        let alias = TableAlias()
        self.alias = alias
        source = SQLQualifiedSource(relation.source.qualified(with: alias))
        joins = relation.joins.mapValues(SQLQualifiedJoin.init)
        ownSelection = relation.selection.map { $0.qualifiedSelectable(with: alias) }
        fullSelection = joins.reduce(into: ownSelection) {
            $0.append(contentsOf: $1.value.relation.fullSelection)
        }
        filterPromise = relation.filterPromise.map { [alias] (_, expr) in expr?.qualifiedExpression(with: alias) }
        let ownOrdering = relation.ordering.qualified(with: alias)
        ordering = joins.reduce(ownOrdering) {
            $0.appending($1.value.relation.ordering)
        }
        allAliases = joins.reduce(into: [alias]) {
            $0.append(contentsOf: $1.value.relation.allAliases)
        }
    }
    
    func rowAdapter(_ db: Database, fromIndex startIndex: Int, forKeyPath keyPath: [String]) throws -> (adapter: RowAdapter, endIndex: Int)? {
        if startIndex == 0 && joins.isEmpty {
            // Root relation + no join => no adapter
            return nil
        }
        
        let selectionWidth = try ownSelection
            .map { try $0.columnCount(db) }
            .reduce(0, +)
        
        var endIndex = startIndex + selectionWidth
        var scopes: [String: RowAdapter] = [:]
        for (key, join) in joins {
            if let (joinAdapter, joinEndIndex) = try join.relation.rowAdapter(db, fromIndex: endIndex, forKeyPath: keyPath + [key]) {
                scopes[key] = joinAdapter
                endIndex = joinEndIndex
            }
        }
        
        if selectionWidth == 0 && scopes.isEmpty {
            return nil
        }
        
        let adapter = RangeRowAdapter(startIndex ..< (startIndex + selectionWidth))
        return (adapter: adapter.addingScopes(scopes), endIndex: endIndex)
    }
}

/// A "qualified" source, where all tables are identified with a table alias.
private enum SQLQualifiedSource {
    case table(tableName: String, alias: TableAlias)
    indirect case query(SQLSelectQueryGenerator)
    
    init(_ source: SQLSource) {
        switch source {
        case .table(let tableName, let sourceAlias):
            self = .table(tableName: tableName, alias: sourceAlias ?? TableAlias())
        case .query(let query):
            self = .query(SQLSelectQueryGenerator(query))
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
    private let joinOperator: JoinOperator
    private let joinCondition: JoinCondition
    let relation: SQLQualifiedRelation
    
    init(_ join: SQLJoin) {
        self.joinOperator = join.joinOperator
        self.joinCondition = join.joinCondition
        self.relation = SQLQualifiedRelation(join.relation)
    }
    
    func sql(_ db: Database,_ context: inout SQLGenerationContext, leftAlias: TableAlias, isRequiredAllowed: Bool) throws -> String {
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
        
        sql += try " " + relation.source.sql(db, &context)
        
        let rightAlias = relation.alias
        let filters = try [
            joinCondition.sqlExpression(db, leftAlias: leftAlias, rightAlias: rightAlias),
            relation.filterPromise.resolve(db)
            ].compactMap { $0 }
        if !filters.isEmpty {
            sql += " ON " + filters.joined(operator: .and).expressionSQL(&context)
        }
        
        for (_, join) in relation.joins {
            sql += try " " + join.sql(db, &context, leftAlias: rightAlias, isRequiredAllowed: isRequiredAllowed)
        }
        
        return sql
    }
}

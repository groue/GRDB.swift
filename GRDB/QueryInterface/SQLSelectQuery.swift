/// SQLSelectQuery generates SQL for query interface requests.
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
    fileprivate var sqlSelectable: SQLSelectable {
        switch self {
        case .all:
            return SQLExpressionCount(AllColumns())
        case .distinct(let expression):
            return SQLExpressionCountDistinct(expression)
        }
    }
}

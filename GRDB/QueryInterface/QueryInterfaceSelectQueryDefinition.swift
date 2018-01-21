// MARK: - QueryInterfaceSelectQueryDefinition

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

struct QueryInterfaceSelectQueryDefinition {
    var selection: [SQLSelectable]
    var isDistinct: Bool
    var source: SQLSource?
    var wherePromise: DatabasePromise<SQLExpression?>
    var groupByExpressions: [SQLExpression]
    var orderings: [SQLOrderingTerm]
    var isReversed: Bool
    var havingExpression: SQLExpression?
    var limit: SQLLimit?
    
    init(
        select selection: [SQLSelectable],
        isDistinct: Bool = false,
        from source: SQLSource? = nil,
        filter whereExpression: SQLExpression? = nil,
        groupBy groupByExpressions: [SQLExpression] = [],
        orderBy orderings: [SQLOrderingTerm] = [],
        isReversed: Bool = false,
        having havingExpression: SQLExpression? = nil,
        limit: SQLLimit? = nil)
    {
        self.selection = selection
        self.isDistinct = isDistinct
        self.source = source
        self.wherePromise = DatabasePromise(value: whereExpression)
        self.groupByExpressions = groupByExpressions
        self.orderings = orderings
        self.isReversed = isReversed
        self.havingExpression = havingExpression
        self.limit = limit
    }
    
    func mapWhereExpression(_ transform: @escaping (Database, SQLExpression?) throws -> SQLExpression?) -> QueryInterfaceSelectQueryDefinition {
        var query = self
        query.wherePromise = query.wherePromise.map(transform)
        return query
    }
    
    func sql(_ db: Database, _ arguments: inout StatementArguments?) throws -> String {
        var sql = "SELECT"
        
        if isDistinct {
            sql += " DISTINCT"
        }
        
        assert(!selection.isEmpty)
        sql += " " + selection.map { $0.resultColumnSQL(&arguments) }.joined(separator: ", ")
        
        if let source = source {
            sql += try " FROM " + source.sourceSQL(db, &arguments)
        }
        
        if let whereExpression = try wherePromise.resolve(db) {
            sql += " WHERE " + whereExpression.expressionSQL(&arguments)
        }
        
        if !groupByExpressions.isEmpty {
            sql += " GROUP BY " + groupByExpressions.map { $0.expressionSQL(&arguments) }.joined(separator: ", ")
        }
        
        if let havingExpression = havingExpression {
            sql += " HAVING " + havingExpression.expressionSQL(&arguments)
        }
        
        let orderings = self.queryOrderings
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
            fatalError("Can't delete query with GROUP BY expression")
        }
        
        guard havingExpression == nil else {
            // Programmer error
            fatalError("Can't delete query with GROUP BY expression")
        }
        
        var sql = "DELETE"
        var arguments: StatementArguments? = StatementArguments()
        
        if let source = source {
            sql += try " FROM " + source.sourceSQL(db, &arguments)
        }
        
        if let whereExpression = try wherePromise.resolve(db) {
            sql += " WHERE " + whereExpression.expressionSQL(&arguments)
        }
        
        if let limit = limit {
            let orderings = self.queryOrderings
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
    
    private var queryOrderings: [SQLOrderingTerm] {
        if isReversed {
            if orderings.isEmpty {
                // https://www.sqlite.org/lang_createtable.html#rowid
                //
                // > The rowid value can be accessed using one of the special
                // > case-independent names "rowid", "oid", or "_rowid_" in
                // > place of a column name. If a table contains a user defined
                // > column named "rowid", "oid" or "_rowid_", then that name
                // > always refers the explicitly declared column and cannot be
                // > used to retrieve the integer rowid value.
                //
                // Here we assume that rowid is not a custom column.
                // TODO: support for user-defined rowid column.
                // TODO: support for WITHOUT ROWID tables.
                return [Column.rowID.desc]
            } else {
                return orderings.map { $0.reversed }
            }
        } else {
            return orderings
        }
    }
    
    /// Remove ordering
    var unorderedQuery: QueryInterfaceSelectQueryDefinition {
        var query = self
        query.isReversed = false
        query.orderings = []
        return query
    }
}

extension QueryInterfaceSelectQueryDefinition : Request {
    func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
        var arguments: StatementArguments? = StatementArguments()
        let sql = try self.sql(db, &arguments)
        let statement = try db.makeSelectStatement(sql)
        try statement.setArgumentsWithValidation(arguments!)
        return (statement, nil)
    }
    
    func fetchCount(_ db: Database) throws -> Int {
        return try Int.fetchOne(db, countQuery)!
    }
    
    /// The database region that the request looks into.
    func fetchedRegion(_ db: Database) throws -> DatabaseRegion {
        let (statement, _) = try prepare(db)
        let region = statement.fetchedRegion
        
        // Can we intersect the region with rowIds?
        //
        // Give up unless request feeds from a single database table
        guard let source = source else {
            return region
        }
        guard case .table(name: let tableName, alias: _) = source else {
            return region
        }
        
        // Give up unless primary key is rowId
        let primaryKeyInfo = try db.primaryKey(tableName)
        guard primaryKeyInfo.isRowID else {
            return region
        }
        
        // Give up unless there is a where clause
        guard let whereExpression = try wherePromise.resolve(db) else {
            return region
        }
        
        // The whereExpression knows better
        guard let rowIds = whereExpression.matchedRowIds(rowIdName: primaryKeyInfo.rowIDColumn) else {
            return region
        }
        
        // Database regions are case-insensitive: use the canonical table name
        let canonicalTableName = try db.canonicalName(table: tableName)
        return region.tableIntersection(canonicalTableName, rowIds: rowIds)
    }
    
    private var countQuery: QueryInterfaceSelectQueryDefinition {
        guard groupByExpressions.isEmpty && limit == nil else {
            // SELECT ... GROUP BY ...
            // SELECT ... LIMIT ...
            return trivialCountQuery
        }
        
        guard let source = source, case .table = source else {
            // SELECT ... FROM (something which is not a table)
            return trivialCountQuery
        }
        
        assert(!selection.isEmpty)
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
    private var trivialCountQuery: QueryInterfaceSelectQueryDefinition {
        return QueryInterfaceSelectQueryDefinition(
            select: [SQLExpressionCount(AllColumns())],
            from: .query(query: unorderedQuery, alias: nil))
    }
}

indirect enum SQLSource {
    case table(name: String, alias: String?)
    case query(query: QueryInterfaceSelectQueryDefinition, alias: String?)
    
    func sourceSQL(_ db: Database, _ arguments: inout StatementArguments?) throws -> String {
        switch self {
        case .table(let table, let alias):
            if let alias = alias {
                return table.quotedDatabaseIdentifier + " AS " + alias.quotedDatabaseIdentifier
            } else {
                return table.quotedDatabaseIdentifier
            }
        case .query(let query, let alias):
            if let alias = alias {
                return try "(" + query.sql(db, &arguments) + ") AS " + alias.quotedDatabaseIdentifier
            } else {
                return try "(" + query.sql(db, &arguments) + ")"
            }
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

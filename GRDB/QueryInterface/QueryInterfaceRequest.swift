/// A QueryInterfaceRequest describes an SQL query.
///
/// See https://github.com/groue/GRDB.swift#the-query-interface
public struct QueryInterfaceRequest<T> {
    let query: QueryInterfaceSelectQueryDefinition
    
    init(query: QueryInterfaceSelectQueryDefinition) {
        self.query = query
    }
}

extension QueryInterfaceRequest : TypedRequest {
    public typealias RowDecoder = T
    
    /// A tuple that contains a prepared statement that is ready to be
    /// executed, and an eventual row adapter.
    ///
    /// - parameter db: A database connection.
    public func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
        return try query.prepare(db)
    }
    
    /// The number of rows fetched by the request.
    ///
    /// - parameter db: A database connection.
    public func fetchCount(_ db: Database) throws -> Int {
        return try query.fetchCount(db)
    }
}

extension QueryInterfaceRequest {
    
    // MARK: Request Derivation
    
    /// A new QueryInterfaceRequest with a new net of selected columns.
    ///
    ///     // SELECT id, email FROM players
    ///     var request = Player.all()
    ///     request = request.select(Column("id"), Column("email"))
    ///
    /// Any previous selection is replaced:
    ///
    ///     // SELECT email FROM players
    ///     request
    ///         .select(Column("id"))
    ///         .select(Column("email"))
    public func select(_ selection: SQLSelectable...) -> QueryInterfaceRequest<T> {
        return select(selection)
    }
    
    /// A new QueryInterfaceRequest with a new net of selected columns.
    ///
    ///     // SELECT id, email FROM players
    ///     var request = Player.all()
    ///     request = request.select([Column("id"), Column("email")])
    ///
    /// Any previous selection is replaced:
    ///
    ///     // SELECT email FROM players
    ///     request
    ///         .select([Column("id")])
    ///         .select([Column("email")])
    public func select(_ selection: [SQLSelectable]) -> QueryInterfaceRequest<T> {
        var query = self.query
        query.selection = selection
        return QueryInterfaceRequest(query: query)
    }
    
    /// A new QueryInterfaceRequest with a new net of selected columns.
    ///
    ///     // SELECT id, email FROM players
    ///     var request = Player.all()
    ///     request = request.select(sql: "id, email")
    ///
    /// Any previous selection is replaced:
    ///
    ///     // SELECT email FROM players
    ///     request
    ///         .select(sql: "id")
    ///         .select(sql: "email")
    public func select(sql: String, arguments: StatementArguments? = nil) -> QueryInterfaceRequest<T> {
        return select(SQLExpressionLiteral(sql, arguments: arguments))
    }
    
    /// A new QueryInterfaceRequest which returns distinct rows.
    ///
    ///     // SELECT DISTINCT * FROM players
    ///     var request = Player.all()
    ///     request = request.distinct()
    ///
    ///     // SELECT DISTINCT name FROM players
    ///     var request = Player.select(Column("name"))
    ///     request = request.distinct()
    public func distinct() -> QueryInterfaceRequest<T> {
        var query = self.query
        query.isDistinct = true
        return QueryInterfaceRequest(query: query)
    }
    
    /// A new QueryInterfaceRequest with the provided *predicate* added to the
    /// eventual set of already applied predicates.
    ///
    ///     // SELECT * FROM players WHERE email = 'arthur@example.com'
    ///     var request = Player.all()
    ///     request = request.filter(Column("email") == "arthur@example.com")
    public func filter(_ predicate: SQLExpressible) -> QueryInterfaceRequest<T> {
        var query = self.query
        if let whereExpression = query.whereExpression {
            query.whereExpression = whereExpression && predicate.sqlExpression
        } else {
            query.whereExpression = predicate.sqlExpression
        }
        return QueryInterfaceRequest(query: query)
    }
    
    /// A new QueryInterfaceRequest with the provided *predicate* added to the
    /// eventual set of already applied predicates.
    ///
    ///     // SELECT * FROM players WHERE email = 'arthur@example.com'
    ///     var request = Player.all()
    ///     request = request.filter(sql: "email = ?", arguments: ["arthur@example.com"])
    public func filter(sql: String, arguments: StatementArguments? = nil) -> QueryInterfaceRequest<T> {
        return filter(SQLExpressionLiteral(sql, arguments: arguments))
    }
    
    /// A new QueryInterfaceRequest grouped according to *expressions*.
    public func group(_ expressions: SQLExpressible...) -> QueryInterfaceRequest<T> {
        return group(expressions)
    }
    
    /// A new QueryInterfaceRequest grouped according to *expressions*.
    public func group(_ expressions: [SQLExpressible]) -> QueryInterfaceRequest<T> {
        var query = self.query
        query.groupByExpressions = expressions.map { $0.sqlExpression }
        return QueryInterfaceRequest(query: query)
    }
    
    /// A new QueryInterfaceRequest with a new grouping.
    public func group(sql: String, arguments: StatementArguments? = nil) -> QueryInterfaceRequest<T> {
        return group(SQLExpressionLiteral(sql, arguments: arguments))
    }
    
    /// A new QueryInterfaceRequest with the provided *predicate* added to the
    /// eventual set of already applied predicates.
    public func having(_ predicate: SQLExpressible) -> QueryInterfaceRequest<T> {
        var query = self.query
        if let havingExpression = query.havingExpression {
            query.havingExpression = (havingExpression && predicate).sqlExpression
        } else {
            query.havingExpression = predicate.sqlExpression
        }
        return QueryInterfaceRequest(query: query)
    }
    
    /// A new QueryInterfaceRequest with the provided *sql* added to the
    /// eventual set of already applied predicates.
    public func having(sql: String, arguments: StatementArguments? = nil) -> QueryInterfaceRequest<T> {
        return having(SQLExpressionLiteral(sql, arguments: arguments))
    }
    
    /// A new QueryInterfaceRequest with the provided *orderings*.
    ///
    ///     // SELECT * FROM players ORDER BY name
    ///     var request = Player.all()
    ///     request = request.order(Column("name"))
    ///
    /// Any previous ordering is replaced:
    ///
    ///     // SELECT * FROM players ORDER BY name
    ///     request
    ///         .order(Column("email"))
    ///         .reversed()
    ///         .order(Column("name"))
    public func order(_ orderings: SQLOrderingTerm...) -> QueryInterfaceRequest<T> {
        return order(orderings)
    }
    
    /// A new QueryInterfaceRequest with the provided *orderings*.
    ///
    ///     // SELECT * FROM players ORDER BY name
    ///     var request = Player.all()
    ///     request = request.order([Column("name")])
    ///
    /// Any previous ordering is replaced:
    ///
    ///     // SELECT * FROM players ORDER BY name
    ///     request
    ///         .order([Column("email")])
    ///         .reversed()
    ///         .order([Column("name")])
    public func order(_ orderings: [SQLOrderingTerm]) -> QueryInterfaceRequest<T> {
        var query = self.query
        query.orderings = orderings
        query.isReversed = false
        return QueryInterfaceRequest(query: query)
    }
    
    /// A new QueryInterfaceRequest with the provided *sql* used for sorting.
    ///
    ///     // SELECT * FROM players ORDER BY name
    ///     var request = Player.all()
    ///     request = request.order(sql: "name")
    ///
    /// Any previous ordering is replaced:
    ///
    ///     // SELECT * FROM players ORDER BY name
    ///     request
    ///         .order(sql: "email")
    ///         .order(sql: "name")
    public func order(sql: String, arguments: StatementArguments? = nil) -> QueryInterfaceRequest<T> {
        return order([SQLExpressionLiteral(sql, arguments: arguments)])
    }
    
    /// A new QueryInterfaceRequest sorted in reversed order.
    ///
    ///     // SELECT * FROM players ORDER BY name DESC
    ///     var request = Player.all().order(Column("name"))
    ///     request = request.reversed()
    public func reversed() -> QueryInterfaceRequest<T> {
        var query = self.query
        query.isReversed = !query.isReversed
        return QueryInterfaceRequest(query: query)
    }
    
    /// A QueryInterfaceRequest which fetches *limit* rows, starting
    /// at *offset*.
    ///
    ///     // SELECT * FROM players LIMIT 1
    ///     var request = Player.all()
    ///     request = request.limit(1)
    public func limit(_ limit: Int, offset: Int? = nil) -> QueryInterfaceRequest<T> {
        var query = self.query
        query.limit = SQLLimit(limit: limit, offset: offset)
        return QueryInterfaceRequest(query: query)
    }
}

extension QueryInterfaceRequest where RowDecoder: MutablePersistable {
    
    // MARK: Deleting
    
    /// Deletes matching rows; returns the number of deleted rows.
    ///
    /// - parameter db: A database connection.
    /// - returns: The number of deleted rows
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    @discardableResult
    public func deleteAll(_ db: Database) throws -> Int {
        try query.makeDeleteStatement(db).execute()
        return db.changesCount
    }
}

extension TableMapping {
    
    // MARK: Request Derivation
    
    /// Creates a QueryInterfaceRequest which fetches all records.
    ///
    ///     // SELECT * FROM players
    ///     let request = Player.all()
    ///
    /// The selection defaults to all columns. This default can be changed for
    /// all requests by the `TableMapping.databaseSelection` property, or
    /// for individual requests with the `TableMapping.select` method.
    public static func all() -> QueryInterfaceRequest<Self> {
        return QueryInterfaceRequest(query: QueryInterfaceSelectQueryDefinition(select: databaseSelection, from: .table(name: databaseTableName, alias: nil)))
    }
    
    /// Creates a QueryInterfaceRequest which fetches no record.
    public static func none() -> QueryInterfaceRequest<Self> {
        return filter(false)
    }
    
    /// Creates a QueryInterfaceRequest which selects *selection*.
    ///
    ///     // SELECT id, email FROM players
    ///     let request = Player.select(Column("id"), Column("email"))
    public static func select(_ selection: SQLSelectable...) -> QueryInterfaceRequest<Self> {
        return all().select(selection)
    }
    
    /// Creates a QueryInterfaceRequest which selects *selection*.
    ///
    ///     // SELECT id, email FROM players
    ///     let request = Player.select([Column("id"), Column("email")])
    public static func select(_ selection: [SQLSelectable]) -> QueryInterfaceRequest<Self> {
        return all().select(selection)
    }
    
    /// Creates a QueryInterfaceRequest which selects *sql*.
    ///
    ///     // SELECT id, email FROM players
    ///     let request = Player.select(sql: "id, email")
    public static func select(sql: String, arguments: StatementArguments? = nil) -> QueryInterfaceRequest<Self> {
        return all().select(sql: sql, arguments: arguments)
    }
    
    /// Creates a QueryInterfaceRequest with the provided *predicate*.
    ///
    ///     // SELECT * FROM players WHERE email = 'arthur@example.com'
    ///     let request = Player.filter(Column("email") == "arthur@example.com")
    ///
    /// The selection defaults to all columns. This default can be changed for
    /// all requests by the `TableMapping.databaseSelection` property, or
    /// for individual requests with the `TableMapping.select` method.
    public static func filter(_ predicate: SQLExpressible) -> QueryInterfaceRequest<Self> {
        return all().filter(predicate)
    }
    
    /// Creates a QueryInterfaceRequest with the provided *predicate*.
    ///
    ///     // SELECT * FROM players WHERE email = 'arthur@example.com'
    ///     let request = Player.filter(sql: "email = ?", arguments: ["arthur@example.com"])
    ///
    /// The selection defaults to all columns. This default can be changed for
    /// all requests by the `TableMapping.databaseSelection` property, or
    /// for individual requests with the `TableMapping.select` method.
    public static func filter(sql: String, arguments: StatementArguments? = nil) -> QueryInterfaceRequest<Self> {
        return all().filter(sql: sql, arguments: arguments)
    }
    
    /// Creates a QueryInterfaceRequest sorted according to the
    /// provided *orderings*.
    ///
    ///     // SELECT * FROM players ORDER BY name
    ///     let request = Player.order(Column("name"))
    ///
    /// The selection defaults to all columns. This default can be changed for
    /// all requests by the `TableMapping.databaseSelection` property, or
    /// for individual requests with the `TableMapping.select` method.
    public static func order(_ orderings: SQLOrderingTerm...) -> QueryInterfaceRequest<Self> {
        return all().order(orderings)
    }
    
    /// Creates a QueryInterfaceRequest sorted according to the
    /// provided *orderings*.
    ///
    ///     // SELECT * FROM players ORDER BY name
    ///     let request = Player.order([Column("name")])
    ///
    /// The selection defaults to all columns. This default can be changed for
    /// all requests by the `TableMapping.databaseSelection` property, or
    /// for individual requests with the `TableMapping.select` method.
    public static func order(_ orderings: [SQLOrderingTerm]) -> QueryInterfaceRequest<Self> {
        return all().order(orderings)
    }
    
    /// Creates a QueryInterfaceRequest sorted according to *sql*.
    ///
    ///     // SELECT * FROM players ORDER BY name
    ///     let request = Player.order(sql: "name")
    ///
    /// The selection defaults to all columns. This default can be changed for
    /// all requests by the `TableMapping.databaseSelection` property, or
    /// for individual requests with the `TableMapping.select` method.
    public static func order(sql: String, arguments: StatementArguments? = nil) -> QueryInterfaceRequest<Self> {
        return all().order(sql: sql, arguments: arguments)
    }
    
    /// Creates a QueryInterfaceRequest which fetches *limit* rows, starting at
    /// *offset*.
    ///
    ///     // SELECT * FROM players LIMIT 1
    ///     let request = Player.limit(1)
    ///
    /// The selection defaults to all columns. This default can be changed for
    /// all requests by the `TableMapping.databaseSelection` property, or
    /// for individual requests with the `TableMapping.select` method.
    public static func limit(_ limit: Int, offset: Int? = nil) -> QueryInterfaceRequest<Self> {
        return all().limit(limit, offset: offset)
    }
}

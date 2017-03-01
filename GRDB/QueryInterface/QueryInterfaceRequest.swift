/// A QueryInterfaceRequest describes an SQL query.
///
/// See https://github.com/groue/GRDB.swift#the-query-interface
public struct QueryInterfaceRequest<T> : TypedRequest {
    public typealias Fetched = T
    
    let query: QueryInterfaceSelectQueryDefinition
    
    init(query: QueryInterfaceSelectQueryDefinition) {
        self.query = query
    }
}

extension QueryInterfaceRequest : SQLSelectQuery {
    
    /// This function is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    ///
    /// # Low Level Query Interface
    ///
    /// See SQLSelectQuery.selectQuerySQL(_)
    public func selectQuerySQL(_ arguments: inout StatementArguments?) -> String {
        return query.selectQuerySQL(&arguments)
    }
}

extension QueryInterfaceRequest {
    
    // MARK: Request Derivation
    
    /// A new QueryInterfaceRequest with a new net of selected columns.
    ///
    ///     // SELECT id, email FROM persons
    ///     var request = Person.all()
    ///     request = request.select(Column("id"), Column("email"))
    ///
    /// Any previous selection is replaced:
    ///
    ///     // SELECT email FROM persons
    ///     request
    ///         .select(Column("id"))
    ///         .select(Column("email"))
    public func select(_ selection: SQLSelectable...) -> QueryInterfaceRequest<T> {
        return select(selection)
    }
    
    /// A new QueryInterfaceRequest with a new net of selected columns.
    ///
    ///     // SELECT id, email FROM persons
    ///     var request = Person.all()
    ///     request = request.select([Column("id"), Column("email")])
    ///
    /// Any previous selection is replaced:
    ///
    ///     // SELECT email FROM persons
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
    ///     // SELECT id, email FROM persons
    ///     var request = Person.all()
    ///     request = request.select(sql: "id, email")
    ///
    /// Any previous selection is replaced:
    ///
    ///     // SELECT email FROM persons
    ///     request
    ///         .select(sql: "id")
    ///         .select(sql: "email")
    public func select(sql: String, arguments: StatementArguments? = nil) -> QueryInterfaceRequest<T> {
        return select(SQLExpressionLiteral(sql, arguments: arguments))
    }
    
    /// A new QueryInterfaceRequest which returns distinct rows.
    ///
    ///     // SELECT DISTINCT * FROM persons
    ///     var request = Person.all()
    ///     request = request.distinct()
    ///
    ///     // SELECT DISTINCT name FROM persons
    ///     var request = Person.select(Column("name"))
    ///     request = request.distinct()
    public func distinct() -> QueryInterfaceRequest<T> {
        var query = self.query
        query.isDistinct = true
        return QueryInterfaceRequest(query: query)
    }
    
    /// A new QueryInterfaceRequest with the provided *predicate* added to the
    /// eventual set of already applied predicates.
    ///
    ///     // SELECT * FROM persons WHERE email = 'arthur@example.com'
    ///     var request = Person.all()
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
    ///     // SELECT * FROM persons WHERE email = 'arthur@example.com'
    ///     var request = Person.all()
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
    ///     // SELECT * FROM persons ORDER BY name
    ///     var request = Person.all()
    ///     request = request.order(Column("name"))
    ///
    /// Any previous ordering is replaced:
    ///
    ///     // SELECT * FROM persons ORDER BY name
    ///     request
    ///         .order(Column("email"))
    ///         .order(Column("name"))
    public func order(_ orderings: SQLOrderingTerm...) -> QueryInterfaceRequest<T> {
        return order(orderings)
    }
    
    /// A new QueryInterfaceRequest with the provided *orderings*.
    ///
    ///     // SELECT * FROM persons ORDER BY name
    ///     var request = Person.all()
    ///     request = request.order([Column("name")])
    ///
    /// Any previous ordering is replaced:
    ///
    ///     // SELECT * FROM persons ORDER BY name
    ///     request
    ///         .order([Column("email")])
    ///         .order([Column("name")])
    public func order(_ orderings: [SQLOrderingTerm]) -> QueryInterfaceRequest<T> {
        var query = self.query
        query.orderings = orderings
        return QueryInterfaceRequest(query: query)
    }
    
    /// A new QueryInterfaceRequest with the provided *sql* used for sorting.
    ///
    ///     // SELECT * FROM persons ORDER BY name
    ///     var request = Person.all()
    ///     request = request.order(sql: "name")
    ///
    /// Any previous ordering is replaced:
    ///
    ///     // SELECT * FROM persons ORDER BY name
    ///     request
    ///         .order(sql: "email")
    ///         .order(sql: "name")
    public func order(sql: String, arguments: StatementArguments? = nil) -> QueryInterfaceRequest<T> {
        return order([SQLExpressionLiteral(sql, arguments: arguments)])
    }
    
    /// A new QueryInterfaceRequest sorted in reversed order.
    ///
    ///     // SELECT * FROM persons ORDER BY name DESC
    ///     var request = Person.all().order(Column("name"))
    ///     request = request.reversed()
    public func reversed() -> QueryInterfaceRequest<T> {
        var query = self.query
        query.isReversed = !query.isReversed
        return QueryInterfaceRequest(query: query)
    }
    
    /// A QueryInterfaceRequest which fetches *limit* rows, starting
    /// at *offset*.
    ///
    ///     // SELECT * FROM persons LIMIT 1
    ///     var request = Person.all()
    ///     request = request.limit(1)
    public func limit(_ limit: Int, offset: Int? = nil) -> QueryInterfaceRequest<T> {
        var query = self.query
        query.limit = SQLLimit(limit: limit, offset: offset)
        return QueryInterfaceRequest(query: query)
    }
}

extension QueryInterfaceRequest {
    
    // MARK: Counting
    
    /// The number of rows fetched by the request.
    ///
    /// - parameter db: A database connection.
    public func fetchCount(_ db: Database) throws -> Int {
        return try query.fetchCount(db)
    }
}

extension QueryInterfaceRequest {
    
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
    ///     // SELECT * FROM persons
    ///     var request = Person.all()
    ///
    /// If the `selectsRowID` type property is true, then the selection includes
    /// the hidden "rowid" column:
    ///
    ///     // SELECT *, rowid FROM persons
    ///     var request = Person.all()
    public static func all() -> QueryInterfaceRequest<Self> {
        let selection: [SQLSelectable]
        if selectsRowID {
            selection = [star, Column.rowID]
        } else {
            selection = [star]
        }
        return QueryInterfaceRequest(query: QueryInterfaceSelectQueryDefinition(select: selection, from: .table(name: databaseTableName, alias: nil)))
    }
    
    /// Creates a QueryInterfaceRequest which fetches no record.
    public static func none() -> QueryInterfaceRequest<Self> {
        return filter(false)
    }
    
    /// Creates a QueryInterfaceRequest which selects *selection*.
    ///
    ///     // SELECT id, email FROM persons
    ///     var request = Person.select(Column("id"), Column("email"))
    public static func select(_ selection: SQLSelectable...) -> QueryInterfaceRequest<Self> {
        return all().select(selection)
    }
    
    /// Creates a QueryInterfaceRequest which selects *selection*.
    ///
    ///     // SELECT id, email FROM persons
    ///     var request = Person.select([Column("id"), Column("email")])
    public static func select(_ selection: [SQLSelectable]) -> QueryInterfaceRequest<Self> {
        return all().select(selection)
    }
    
    /// Creates a QueryInterfaceRequest which selects *sql*.
    ///
    ///     // SELECT id, email FROM persons
    ///     var request = Person.select(sql: "id, email")
    public static func select(sql: String, arguments: StatementArguments? = nil) -> QueryInterfaceRequest<Self> {
        return all().select(sql: sql, arguments: arguments)
    }
    
    /// Creates a QueryInterfaceRequest with the provided *predicate*.
    ///
    ///     // SELECT * FROM persons WHERE email = 'arthur@example.com'
    ///     var request = Person.filter(Column("email") == "arthur@example.com")
    ///
    /// If the `selectsRowID` type property is true, then the selection includes
    /// the hidden "rowid" column:
    ///
    ///     // SELECT *, rowid FROM persons WHERE email = 'arthur@example.com'
    ///     var request = Person.filter(Column("email") == "arthur@example.com")
    public static func filter(_ predicate: SQLExpressible) -> QueryInterfaceRequest<Self> {
        return all().filter(predicate)
    }
    
    /// Creates a QueryInterfaceRequest with the provided *predicate*.
    ///
    ///     // SELECT * FROM persons WHERE email = 'arthur@example.com'
    ///     var request = Person.filter(sql: "email = ?", arguments: ["arthur@example.com"])
    ///
    /// If the `selectsRowID` type property is true, then the selection includes
    /// the hidden "rowid" column:
    ///
    ///     // SELECT *, rowid FROM persons WHERE email = 'arthur@example.com'
    ///     var request = Person.filter(sql: "email = ?", arguments: ["arthur@example.com"])
    public static func filter(sql: String, arguments: StatementArguments? = nil) -> QueryInterfaceRequest<Self> {
        return all().filter(sql: sql, arguments: arguments)
    }
    
    /// Creates a QueryInterfaceRequest sorted according to the
    /// provided *orderings*.
    ///
    ///     // SELECT * FROM persons ORDER BY name
    ///     var request = Person.order(Column("name"))
    ///
    /// If the `selectsRowID` type property is true, then the selection includes
    /// the hidden "rowid" column:
    ///
    ///     // SELECT *, rowid FROM persons ORDER BY name
    ///     var request = Person.order(Column("name"))
    public static func order(_ orderings: SQLOrderingTerm...) -> QueryInterfaceRequest<Self> {
        return all().order(orderings)
    }
    
    /// Creates a QueryInterfaceRequest sorted according to the
    /// provided *orderings*.
    ///
    ///     // SELECT * FROM persons ORDER BY name
    ///     var request = Person.order([Column("name")])
    ///
    /// If the `selectsRowID` type property is true, then the selection includes
    /// the hidden "rowid" column:
    ///
    ///     // SELECT *, rowid FROM persons ORDER BY name
    ///     var request = Person.order([Column("name")])
    public static func order(_ orderings: [SQLOrderingTerm]) -> QueryInterfaceRequest<Self> {
        return all().order(orderings)
    }
    
    /// Creates a QueryInterfaceRequest sorted according to *sql*.
    ///
    ///     // SELECT * FROM persons ORDER BY name
    ///     var request = Person.order(sql: "name")
    ///
    /// If the `selectsRowID` type property is true, then the selection includes
    /// the hidden "rowid" column:
    ///
    ///     // SELECT *, rowid FROM persons ORDER BY name
    ///     var request = Person.order(sql: "name")
    public static func order(sql: String, arguments: StatementArguments? = nil) -> QueryInterfaceRequest<Self> {
        return all().order(sql: sql, arguments: arguments)
    }
    
    /// Creates a QueryInterfaceRequest which fetches *limit* rows, starting at
    /// *offset*.
    ///
    ///     // SELECT * FROM persons LIMIT 1
    ///     var request = Person.limit(1)
    ///
    /// If the `selectsRowID` type property is true, then the selection includes
    /// the hidden "rowid" column:
    ///
    ///     // SELECT *, rowid FROM persons LIMIT 1
    ///     var request = Person.limit(1)
    public static func limit(_ limit: Int, offset: Int? = nil) -> QueryInterfaceRequest<Self> {
        return all().limit(limit, offset: offset)
    }
}

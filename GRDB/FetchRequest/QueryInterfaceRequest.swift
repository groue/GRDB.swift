/// A QueryInterfaceRequest describes an SQL query.
///
/// See https://github.com/groue/GRDB.swift#the-query-interface
public struct QueryInterfaceRequest<T> {
    let query: _SQLSelectQuery
    
    /// Initializes a QueryInterfaceRequest based on table *tableName*.
    ///
    /// It represents the SQL query `SELECT * FROM tableName`.
    public init(tableName: String) {
        self.init(query: _SQLSelectQuery(select: [_SQLResultColumn.Star(nil)], from: .Table(name: tableName, alias: nil)))
    }
    
    init(query: _SQLSelectQuery) {
        self.query = query
    }
}


extension QueryInterfaceRequest : FetchRequest {
    
    /// Returns a prepared statement that is ready to be executed.
    ///
    /// - throws: A DatabaseError whenever SQLite could not parse the sql query.
    @warn_unused_result
    public func selectStatement(database: Database) throws -> SelectStatement {
        // TODO: split statement generation from arguments building
        var bindings: [DatabaseValueConvertible?] = []
        let sql = try query.sql(database, &bindings)
        let statement = try database.selectStatement(sql)
        try statement.setArgumentsWithValidation(StatementArguments(bindings))
        return statement
    }
    
    /// This method is part of the FetchRequest adoption; returns nil
    public func adapter(statement: SelectStatement) throws -> RowAdapter? {
        return nil
    }
}


extension QueryInterfaceRequest where T: RowConvertible {
    
    // MARK: Fetching Record and RowConvertible
    
    /// Returns a sequence of values.
    ///
    ///     let nameColumn = SQLColumn("name")
    ///     let request = Person.order(nameColumn)
    ///     let persons = request.fetch(db) // DatabaseSequence<Person>
    ///
    /// The returned sequence can be consumed several times, but it may yield
    /// different results, should database changes have occurred between two
    /// generations:
    ///
    ///     let persons = request.fetch(db)
    ///     Array(persons).count // 3
    ///     db.execute("DELETE ...")
    ///     Array(persons).count // 2
    ///
    /// If the database is modified while the sequence is iterating, the
    /// remaining elements are undefined.
    @warn_unused_result
    public func fetch(db: Database) -> DatabaseSequence<T> {
        return try! T.fetch(selectStatement(db))
    }
    
    /// Returns an array of values fetched from a fetch request.
    ///
    ///     let nameColumn = SQLColumn("name")
    ///     let request = Person.order(nameColumn)
    ///     let persons = request.fetchAll(db) // [Person]
    ///
    /// - parameter db: A database connection.
    @warn_unused_result
    public func fetchAll(db: Database) -> [T] {
        return Array(fetch(db))
    }
    
    /// Returns a single value fetched from a fetch request.
    ///
    ///     let nameColumn = SQLColumn("name")
    ///     let request = Person.order(nameColumn)
    ///     let person = request.fetchOne(db) // Person?
    ///
    /// - parameter db: A database connection.
    @warn_unused_result
    public func fetchOne(db: Database) -> T? {
        return fetch(db).generate().next()
    }
}


extension QueryInterfaceRequest {
    
    // MARK: Request Derivation
    
    /// Returns a new QueryInterfaceRequest with a new net of selected columns.
    @warn_unused_result
    public func select(selection: _SQLSelectable...) -> QueryInterfaceRequest<T> {
        return select(selection)
    }
    
    /// Returns a new QueryInterfaceRequest with a new net of selected columns.
    @warn_unused_result
    public func select(selection: [_SQLSelectable]) -> QueryInterfaceRequest<T> {
        var query = self.query
        query.selection = selection
        return QueryInterfaceRequest(query: query)
    }
    
    /// Returns a new QueryInterfaceRequest with a new net of selected columns.
    @warn_unused_result
    public func select(sql sql: String) -> QueryInterfaceRequest<T> {
        return select(_SQLLiteral(sql))
    }
    
    /// Returns a new QueryInterfaceRequest which returns distinct rows.
    public var distinct: QueryInterfaceRequest<T> {
        var query = self.query
        query.distinct = true
        return QueryInterfaceRequest(query: query)
    }
    
    /// Returns a new QueryInterfaceRequest with the provided *predicate* added to the
    /// eventual set of already applied predicates.
    @warn_unused_result
    public func filter(predicate: _SQLExpressible) -> QueryInterfaceRequest<T> {
        var query = self.query
        if let whereExpression = query.whereExpression {
            query.whereExpression = .InfixOperator("AND", whereExpression, predicate.sqlExpression)
        } else {
            query.whereExpression = predicate.sqlExpression
        }
        return QueryInterfaceRequest(query: query)
    }
    
    /// Returns a new QueryInterfaceRequest with the provided *predicate* added to the
    /// eventual set of already applied predicates.
    @warn_unused_result
    public func filter(sql sql: String) -> QueryInterfaceRequest<T> {
        return filter(_SQLLiteral(sql))
    }
    
    /// Returns a new QueryInterfaceRequest grouped according to *expressions*.
    @warn_unused_result
    public func group(expressions: _SQLExpressible...) -> QueryInterfaceRequest<T> {
        return group(expressions)
    }
    
    /// Returns a new QueryInterfaceRequest grouped according to *expressions*.
    @warn_unused_result
    public func group(expressions: [_SQLExpressible]) -> QueryInterfaceRequest<T> {
        var query = self.query
        query.groupByExpressions = expressions.map { $0.sqlExpression }
        return QueryInterfaceRequest(query: query)
    }
    
    /// Returns a new QueryInterfaceRequest with a new grouping.
    @warn_unused_result
    public func group(sql sql: String) -> QueryInterfaceRequest<T> {
        return group(_SQLLiteral(sql))
    }
    
    /// Returns a new QueryInterfaceRequest with the provided *predicate* added to the
    /// eventual set of already applied predicates.
    @warn_unused_result
    public func having(predicate: _SQLExpressible) -> QueryInterfaceRequest<T> {
        var query = self.query
        if let havingExpression = query.havingExpression {
            query.havingExpression = (havingExpression && predicate).sqlExpression
        } else {
            query.havingExpression = predicate.sqlExpression
        }
        return QueryInterfaceRequest(query: query)
    }
    
    /// Returns a new QueryInterfaceRequest with the provided *sql* added to
    /// the eventual set of already applied predicates.
    @warn_unused_result
    public func having(sql sql: String) -> QueryInterfaceRequest<T> {
        return having(_SQLLiteral(sql))
    }
    
    /// Returns a new QueryInterfaceRequest with the provided *orderings* added to
    /// the eventual set of already applied orderings.
    @warn_unused_result
    public func order(orderings: _SQLOrdering...) -> QueryInterfaceRequest<T> {
        return order(orderings)
    }
    
    /// Returns a new QueryInterfaceRequest with the provided *orderings* added to
    /// the eventual set of already applied orderings.
    @warn_unused_result
    public func order(orderings: [_SQLOrdering]) -> QueryInterfaceRequest<T> {
        var query = self.query
        query.orderings.appendContentsOf(orderings)
        return QueryInterfaceRequest(query: query)
    }
    
    /// Returns a new QueryInterfaceRequest with the provided *sql* added to the
    /// eventual set of already applied orderings.
    @warn_unused_result
    public func order(sql sql: String) -> QueryInterfaceRequest<T> {
        return order([_SQLLiteral(sql)])
    }
    
    /// Returns a new QueryInterfaceRequest sorted in reversed order.
    @warn_unused_result
    public func reverse() -> QueryInterfaceRequest<T> {
        var query = self.query
        query.reversed = !query.reversed
        return QueryInterfaceRequest(query: query)
    }
    
    /// Returns a QueryInterfaceRequest which fetches *limit* rows, starting at
    /// *offset*.
    @warn_unused_result
    public func limit(limit: Int, offset: Int? = nil) -> QueryInterfaceRequest<T> {
        var query = self.query
        query.limit = _SQLLimit(limit: limit, offset: offset)
        return QueryInterfaceRequest(query: query)
    }
}


extension QueryInterfaceRequest {
    
    // MARK: Counting
    
    /// Returns the number of rows matched by the request.
    ///
    /// - parameter db: A database connection.
    @warn_unused_result
    public func fetchCount(db: Database) -> Int {
        return Int.fetchOne(db, QueryInterfaceRequest(query: query.countQuery))!
    }
}


extension QueryInterfaceRequest {
    
    // MARK: QueryInterfaceRequest as subquery
    
    /// Returns an SQL expression that checks the inclusion of a value in
    /// the results of another request.
    public func contains(element: _SQLExpressible) -> _SQLExpression {
        return .InSubQuery(query, element.sqlExpression)
    }
    
    /// Returns an SQL expression that checks whether the receiver, as a
    /// subquery, returns any row.
    public var exists: _SQLExpression {
        return .Exists(query)
    }
}


extension TableMapping {
    
    // MARK: Request Derivation
    
    /// Returns a QueryInterfaceRequest which fetches all rows in the table.
    @warn_unused_result
    public static func all() -> QueryInterfaceRequest<Self> {
        return QueryInterfaceRequest(tableName: databaseTableName())
    }
    
    /// Returns a QueryInterfaceRequest which selects *selection*.
    @warn_unused_result
    public static func select(selection: _SQLSelectable...) -> QueryInterfaceRequest<Self> {
        return all().select(selection)
    }
    
    /// Returns a QueryInterfaceRequest which selects *selection*.
    @warn_unused_result
    public static func select(selection: [_SQLSelectable]) -> QueryInterfaceRequest<Self> {
        return all().select(selection)
    }
    
    /// Returns a QueryInterfaceRequest which selects *sql*.
    @warn_unused_result
    public static func select(sql sql: String) -> QueryInterfaceRequest<Self> {
        return all().select(sql: sql)
    }
    
    /// Returns a QueryInterfaceRequest with the provided *predicate*.
    @warn_unused_result
    public static func filter(predicate: _SQLExpressible) -> QueryInterfaceRequest<Self> {
        return all().filter(predicate)
    }
    
    /// Returns a QueryInterfaceRequest with the provided *predicate*.
    @warn_unused_result
    public static func filter(sql sql: String) -> QueryInterfaceRequest<Self> {
        return all().filter(sql: sql)
    }
    
    /// Returns a QueryInterfaceRequest sorted according to the
    /// provided *orderings*.
    @warn_unused_result
    public static func order(orderings: _SQLOrdering...) -> QueryInterfaceRequest<Self> {
        return all().order(orderings)
    }
    
    /// Returns a QueryInterfaceRequest sorted according to the
    /// provided *orderings*.
    @warn_unused_result
    public static func order(orderings: [_SQLOrdering]) -> QueryInterfaceRequest<Self> {
        return all().order(orderings)
    }
    
    /// Returns a QueryInterfaceRequest sorted according to *sql*.
    @warn_unused_result
    public static func order(sql sql: String) -> QueryInterfaceRequest<Self> {
        return all().order(sql: sql)
    }
    
    /// Returns a QueryInterfaceRequest which fetches *limit* rows, starting at
    /// *offset*.
    @warn_unused_result
    public static func limit(limit: Int, offset: Int? = nil) -> QueryInterfaceRequest<Self> {
        return all().limit(limit, offset: offset)
    }
}


extension TableMapping {
    
    // MARK: Counting
    
    /// Returns the number of records.
    ///
    /// - parameter db: A database connection.
    @warn_unused_result
    public static func fetchCount(db: Database) -> Int {
        return all().fetchCount(db)
    }
}

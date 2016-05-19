/// A FetchRequest describes an SQL query.
///
/// See https://github.com/groue/GRDB.swift#the-query-interface
public struct FetchRequest<T> {
    let query: _SQLSelectQuery
    
    /// Initializes a FetchRequest based on table *tableName*.
    public init(tableName: String) {
        self.init(query: _SQLSelectQuery(select: [_SQLResultColumn.Star(nil)], from: .Table(name: tableName, alias: nil)))
    }
    
    init(query: _SQLSelectQuery) {
        self.query = query
    }
}

extension FetchRequest : FetchRequestType {
    
    public typealias FetchedType = T
    
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
}


extension FetchRequest {
    
    // MARK: Request Derivation
    
    /// Returns a new FetchRequest with a new net of selected columns.
    @warn_unused_result
    public func select(selection: _SQLSelectable...) -> FetchRequest<T> {
        return select(selection)
    }
    
    /// Returns a new FetchRequest with a new net of selected columns.
    @warn_unused_result
    public func select(selection: [_SQLSelectable]) -> FetchRequest<T> {
        var query = self.query
        query.selection = selection
        return FetchRequest(query: query)
    }
    
    /// Returns a new FetchRequest with a new net of selected columns.
    @warn_unused_result
    public func select(sql sql: String) -> FetchRequest<T> {
        return select(_SQLLiteral(sql))
    }
    
    /// Returns a new FetchRequest which returns distinct rows.
    public var distinct: FetchRequest<T> {
        var query = self.query
        query.distinct = true
        return FetchRequest(query: query)
    }
    
    /// Returns a new FetchRequest with the provided *predicate* added to the
    /// eventual set of already applied predicates.
    @warn_unused_result
    public func filter(predicate: _SQLExpressionType) -> FetchRequest<T> {
        var query = self.query
        if let whereExpression = query.whereExpression {
            query.whereExpression = .InfixOperator("AND", whereExpression, predicate.sqlExpression)
        } else {
            query.whereExpression = predicate.sqlExpression
        }
        return FetchRequest(query: query)
    }
    
    /// Returns a new FetchRequest with the provided *predicate* added to the
    /// eventual set of already applied predicates.
    @warn_unused_result
    public func filter(sql sql: String) -> FetchRequest<T> {
        return filter(_SQLLiteral(sql))
    }
    
    /// Returns a new FetchRequest grouped according to *expressions*.
    @warn_unused_result
    public func group(expressions: _SQLExpressionType...) -> FetchRequest<T> {
        return group(expressions)
    }
    
    /// Returns a new FetchRequest grouped according to *expressions*.
    @warn_unused_result
    public func group(expressions: [_SQLExpressionType]) -> FetchRequest<T> {
        var query = self.query
        query.groupByExpressions = expressions.map { $0.sqlExpression }
        return FetchRequest(query: query)
    }
    
    /// Returns a new FetchRequest with a new grouping.
    @warn_unused_result
    public func group(sql sql: String) -> FetchRequest<T> {
        return group(_SQLLiteral(sql))
    }
    
    /// Returns a new FetchRequest with the provided *predicate* added to the
    /// eventual set of already applied predicates.
    @warn_unused_result
    public func having(predicate: _SQLExpressionType) -> FetchRequest<T> {
        var query = self.query
        if let havingExpression = query.havingExpression {
            query.havingExpression = (havingExpression && predicate).sqlExpression
        } else {
            query.havingExpression = predicate.sqlExpression
        }
        return FetchRequest(query: query)
    }
    
    /// Returns a new FetchRequest with the provided *sql* added to
    /// the eventual set of already applied predicates.
    @warn_unused_result
    public func having(sql sql: String) -> FetchRequest<T> {
        return having(_SQLLiteral(sql))
    }
    
    /// Returns a new FetchRequest with the provided *sortDescriptors* added to
    /// the eventual set of already applied sort descriptors.
    @warn_unused_result
    public func order(sortDescriptors: _SQLSortDescriptorType...) -> FetchRequest<T> {
        return order(sortDescriptors)
    }
    
    /// Returns a new FetchRequest with the provided *sortDescriptors* added to
    /// the eventual set of already applied sort descriptors.
    @warn_unused_result
    public func order(sortDescriptors: [_SQLSortDescriptorType]) -> FetchRequest<T> {
        var query = self.query
        query.sortDescriptors.appendContentsOf(sortDescriptors)
        return FetchRequest(query: query)
    }
    
    /// Returns a new FetchRequest with the provided *sql* added to the
    /// eventual set of already applied sort descriptors.
    @warn_unused_result
    public func order(sql sql: String) -> FetchRequest<T> {
        return order([_SQLLiteral(sql)])
    }
    
    /// Returns a new FetchRequest sorted in reversed order.
    @warn_unused_result
    public func reverse() -> FetchRequest<T> {
        var query = self.query
        query.reversed = !query.reversed
        return FetchRequest(query: query)
    }
    
    /// Returns a FetchRequest which fetches *limit* rows, starting at
    /// *offset*.
    @warn_unused_result
    public func limit(limit: Int, offset: Int? = nil) -> FetchRequest<T> {
        var query = self.query
        query.limit = _SQLLimit(limit: limit, offset: offset)
        return FetchRequest(query: query)
    }
}


extension FetchRequest {
    
    // MARK: Counting
    
    /// Returns the number of rows matched by the request.
    ///
    /// - parameter db: A database connection.
    @warn_unused_result
    public func fetchCount(db: Database) -> Int {
        return Int.fetchOne(db, FetchRequest(query: query.countQuery))!
    }
}


extension FetchRequest {
    
    // MARK: FetchRequest as subquery
    
    /// Returns an SQL expression that checks the inclusion of a value in
    /// the results of another request.
    public func contains(element: _SQLExpressionType) -> _SQLExpression {
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
    
    /// Returns a FetchRequest which fetches all rows in the table.
    @warn_unused_result
    public static func all() -> FetchRequest<Self> {
        return FetchRequest(tableName: databaseTableName())
    }
    
    /// Returns a FetchRequest which selects *selection*.
    @warn_unused_result
    public static func select(selection: _SQLSelectable...) -> FetchRequest<Self> {
        return all().select(selection)
    }
    
    /// Returns a FetchRequest which selects *selection*.
    @warn_unused_result
    public static func select(selection: [_SQLSelectable]) -> FetchRequest<Self> {
        return all().select(selection)
    }
    
    /// Returns a FetchRequest which selects *sql*.
    @warn_unused_result
    public static func select(sql sql: String) -> FetchRequest<Self> {
        return all().select(sql: sql)
    }
    
    /// Returns a FetchRequest with the provided *predicate*.
    @warn_unused_result
    public static func filter(predicate: _SQLExpressionType) -> FetchRequest<Self> {
        return all().filter(predicate)
    }
    
    /// Returns a FetchRequest with the provided *predicate*.
    @warn_unused_result
    public static func filter(sql sql: String) -> FetchRequest<Self> {
        return all().filter(sql: sql)
    }
    
    /// Returns a FetchRequest sorted according to the
    /// provided *sortDescriptors*.
    @warn_unused_result
    public static func order(sortDescriptors: _SQLSortDescriptorType...) -> FetchRequest<Self> {
        return all().order(sortDescriptors)
    }
    
    /// Returns a FetchRequest sorted according to the
    /// provided *sortDescriptors*.
    @warn_unused_result
    public static func order(sortDescriptors: [_SQLSortDescriptorType]) -> FetchRequest<Self> {
        return all().order(sortDescriptors)
    }
    
    /// Returns a FetchRequest sorted according to *sql*.
    @warn_unused_result
    public static func order(sql sql: String) -> FetchRequest<Self> {
        return all().order(sql: sql)
    }
    
    /// Returns a FetchRequest which fetches *limit* rows, starting at
    /// *offset*.
    @warn_unused_result
    public static func limit(limit: Int, offset: Int? = nil) -> FetchRequest<Self> {
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

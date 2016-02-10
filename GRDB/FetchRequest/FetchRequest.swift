/// A FetchRequest describes an SQL query.
///
/// See https://github.com/groue/GRDB.swift#the-query-interface
public struct FetchRequest<T> {
    let query: _SQLSelectQuery
    
    /// Initializes a FetchRequest based on table *tableName*.
    public init(tableName: String) {
        self.init(_SQLSelectQuery(select: [_SQLResultColumn.Star(nil)], from: .Table(name: tableName, alias: nil)))
    }
    
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
    
    init(_ query: _SQLSelectQuery) {
        self.query = query
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
        return FetchRequest(query)
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
        return FetchRequest(query)
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
        return FetchRequest(query)
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
        return FetchRequest(query)
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
        return FetchRequest(query)
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
        return FetchRequest(query)
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
        return FetchRequest(query)
    }
    
    /// Returns a FetchRequest which fetches *limit* rows, starting at
    /// *offset*.
    @warn_unused_result
    public func limit(limit: Int, offset: Int? = nil) -> FetchRequest<T> {
        var query = self.query
        query.limit = _SQLLimit(limit: limit, offset: offset)
        return FetchRequest(query)
    }
}


extension FetchRequest {
    
    // MARK: Counting
    
    /// Returns the number of rows matched by the request.
    @warn_unused_result
    public func fetchCount(db: Database) -> Int {
        return Int.fetchOne(db, select([_SQLExpression.Count(_SQLResultColumn.Star(nil))]))!
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


extension FetchRequest where T: RowConvertible {
    
    // MARK: Fetching Record and RowConvertible
    
    /// Returns a sequence of values.
    ///
    ///     let request = Person.order(name)
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
    ///     let request = Person.order(name)
    ///     let persons = request.fetchAll(db) // [Person]
    @warn_unused_result
    public func fetchAll(db: Database) -> [T] {
        return Array(fetch(db))
    }
    
    /// Returns a single value fetched from a fetch request.
    ///
    ///     let request = Person.order(name)
    ///     let person = request.fetchOne(db) // Person?
    @warn_unused_result
    public func fetchOne(db: Database) -> T? {
        return fetch(db).generate().next()
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
    
    /// Returns a FetchRequest sorted in reversed order.
    @warn_unused_result
    public static func reverse() -> FetchRequest<Self> {
        return all().reverse()
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
    @warn_unused_result
    public static func fetchCount(db: Database) -> Int {
        return all().fetchCount(db)
    }
}


extension DatabaseValueConvertible {
    
    // MARK: Fetching From FetchRequest
    
    /// Returns a sequence of values fetched from a fetch request.
    ///
    ///     let request = Person.select(name)
    ///     let names = String.fetch(db, request) // DatabaseSequence<String>
    ///
    /// The returned sequence can be consumed several times, but it may yield
    /// different results, should database changes have occurred between two
    /// generations:
    ///
    ///     let names = String.fetch(db, request)
    ///     Array(names) // Arthur, Barbara
    ///     db.execute("DELETE ...")
    ///     Array(names) // Arthur
    ///
    /// If the database is modified while the sequence is iterating, the
    /// remaining elements are undefined.
    @warn_unused_result
    public static func fetch<T>(db: Database, _ request: FetchRequest<T>) -> DatabaseSequence<Self> {
        return try! fetch(request.selectStatement(db))
    }
    
    /// Returns an array of values fetched from a fetch request.
    ///
    ///     let request = Person.select(name)
    ///     let names = String.fetchAll(db, request)  // [String]
    @warn_unused_result
    public static func fetchAll<T>(db: Database, _ request: FetchRequest<T>) -> [Self] {
        return try! fetchAll(request.selectStatement(db))
    }
    
    /// Returns a single value fetched from a fetch request.
    ///
    /// The result is nil if the query returns no row, or if no value can be
    /// extracted from the first row.
    ///
    ///     let request = Person.select(name)
    ///     let name = String.fetchOne(db, request)   // String?
    @warn_unused_result
    public static func fetchOne<T>(db: Database, _ request: FetchRequest<T>) -> Self? {
        return try! fetchOne(request.selectStatement(db))
    }
}


extension Optional where Wrapped: DatabaseValueConvertible {
    
    // MARK: Fetching From FetchRequest
    
    /// Returns a sequence of optional values fetched from a fetch request.
    ///
    ///     let request = Person.select(name)
    ///     let names = Optional<String>.fetch(db, request) // DatabaseSequence<String?>
    ///
    /// The returned sequence can be consumed several times, but it may yield
    /// different results, should database changes have occurred between two
    /// generations:
    ///
    ///     let names = Optional<String>.fetch(db, request)
    ///     Array(names) // Arthur, Barbara
    ///     db.execute("DELETE ...")
    ///     Array(names) // Arthur
    ///
    /// If the database is modified while the sequence is iterating, the
    /// remaining elements are undefined.
    @warn_unused_result
    public static func fetch<T>(db: Database, _ request: FetchRequest<T>) -> DatabaseSequence<Wrapped?> {
        return try! fetch(request.selectStatement(db))
    }
    
    /// Returns an array of optional values fetched from a fetch request.
    ///
    ///     let request = Person.select(name)
    ///     let names = Optional<String>.fetchAll(db, request)  // [String?]
    @warn_unused_result
    public static func fetchAll<T>(db: Database, _ request: FetchRequest<T>) -> [Wrapped?] {
        return try! fetchAll(request.selectStatement(db))
    }
}


extension DatabaseValueConvertible where Self: StatementColumnConvertible {
    
    // MARK: Fetching From FetchRequest
    
    /// Returns a sequence of values fetched from a fetch request.
    ///
    ///     let request = Person.select(name)
    ///     let names = String.fetch(db, request) // DatabaseSequence<String>
    ///
    /// The returned sequence can be consumed several times, but it may yield
    /// different results, should database changes have occurred between two
    /// generations:
    ///
    ///     let names = String.fetch(db, request)
    ///     Array(names) // Arthur, Barbara
    ///     db.execute("DELETE ...")
    ///     Array(names) // Arthur
    ///
    /// If the database is modified while the sequence is iterating, the
    /// remaining elements are undefined.
    @warn_unused_result
    public static func fetch<T>(db: Database, _ request: FetchRequest<T>) -> DatabaseSequence<Self> {
        return try! fetch(request.selectStatement(db))
    }
    
    /// Returns an array of values fetched from a fetch request.
    ///
    ///     let request = Person.select(name)
    ///     let names = String.fetchAll(db, request)  // [String]
    @warn_unused_result
    public static func fetchAll<T>(db: Database, _ request: FetchRequest<T>) -> [Self] {
        return try! fetchAll(request.selectStatement(db))
    }
    
    /// Returns a single value fetched from a fetch request.
    ///
    /// The result is nil if the query returns no row, or if no value can be
    /// extracted from the first row.
    ///
    ///     let request = Person.select(name)
    ///     let name = String.fetchOne(db, request)   // String?
    @warn_unused_result
    public static func fetchOne<T>(db: Database, _ request: FetchRequest<T>) -> Self? {
        return try! fetchOne(request.selectStatement(db))
    }
}


extension RowConvertible {
    
    // MARK: Fetching From FetchRequest
    
    /// Returns a sequence of records fetched from a fetch request.
    ///
    ///     let request = Person.order(name)
    ///     let persons = Person.fetch(db, request) // DatabaseSequence<Person>
    ///
    /// The returned sequence can be consumed several times, but it may yield
    /// different results, should database changes have occurred between two
    /// generations:
    ///
    ///     let persons = Person.fetch(db, request)
    ///     Array(persons).count // 3
    ///     db.execute("DELETE ...")
    ///     Array(persons).count // 2
    ///
    /// If the database is modified while the sequence is iterating, the
    /// remaining elements are undefined.
    @warn_unused_result
    public static func fetch<T>(db: Database, _ request: FetchRequest<T>) -> DatabaseSequence<Self> {
        return try! fetch(request.selectStatement(db))
    }
    
    /// Returns an array of records fetched from a fetch request.
    ///
    ///     let request = Person.order(name)
    ///     let persons = Person.fetchAll(db, request) // [Person]
    @warn_unused_result
    public static func fetchAll<T>(db: Database, _ request: FetchRequest<T>) -> [Self] {
        return try! fetchAll(request.selectStatement(db))
    }
    
    /// Returns a single record fetched from a fetch request.
    ///
    ///     let request = Person.order(name)
    ///     let person = Person.fetchOne(db, request) // Person?
    @warn_unused_result
    public static func fetchOne<T>(db: Database, _ request: FetchRequest<T>) -> Self? {
        return try! fetchOne(request.selectStatement(db))
    }
}

extension RowConvertible where Self: TableMapping {
    
    // MARK: Fetching All
    
    /// Returns a sequence of all records fetched from the database.
    ///
    ///     let persons = Person.fetch(db) // DatabaseSequence<Person>
    ///
    /// The returned sequence can be consumed several times, but it may yield
    /// different results, should database changes have occurred between two
    /// generations:
    ///
    ///     let persons = Person.fetch(db)
    ///     Array(persons).count // 3
    ///     db.execute("DELETE ...")
    ///     Array(persons).count // 2
    ///
    /// If the database is modified while the sequence is iterating, the
    /// remaining elements are undefined.
    @warn_unused_result
    public static func fetch(db: Database) -> DatabaseSequence<Self> {
        return all().fetch(db)
    }
    
    /// Returns an array of all records fetched from the database.
    ///
    ///     let persons = Person.fetchAll(db) // [Person]
    @warn_unused_result
    public static func fetchAll(db: Database) -> [Self] {
        return all().fetchAll(db)
    }
    
    /// Returns the first record fetched from a fetch request.
    ///
    ///     let person = Person.fetchOne(db) // Person?
    @warn_unused_result
    public static func fetchOne(db: Database) -> Self? {
        return all().fetchOne(db)
    }
}


extension Row {
    
    // MARK: Fetching From FetchRequest
    
    /// Returns a sequence of rows fetched from a fetch request.
    ///
    ///     let request = Person.select(id, name)
    ///     for row in Row.fetch(db, request) {
    ///         let id: Int64 = row.value(atIndex: 0)
    ///         let name: String = row.value(atIndex: 1)
    ///     }
    ///
    /// Fetched rows are reused during the sequence iteration: don't wrap a row
    /// sequence in an array with `Array(rows)` or `rows.filter { ... }` since
    /// you would not get the distinct rows you expect. Use `Row.fetchAll(...)`
    /// instead.
    ///
    /// For the same reason, make sure you make a copy whenever you extract a
    /// row for later use: `row.copy()`.
    ///
    /// The returned sequence can be consumed several times, but it may yield
    /// different results, should database changes have occurred between two
    /// generations:
    ///
    ///     let rows = Row.fetch(statement)
    ///     for row in rows { ... } // 3 steps
    ///     db.execute("DELETE ...")
    ///     for row in rows { ... } // 2 steps
    ///
    /// If the database is modified while the sequence is iterating, the
    /// remaining elements of the sequence are undefined.
    @warn_unused_result
    public static func fetch<T>(db: Database, _ request: FetchRequest<T>) -> DatabaseSequence<Row> {
        return try! fetch(request.selectStatement(db))
    }
    
    /// Returns an array of rows fetched from a fetch request.
    ///
    ///     let statement = db.selectStatement("SELECT ...")
    ///     let rows = Row.fetchAll(db, request)
    @warn_unused_result
    public static func fetchAll<T>(db: Database, _ request: FetchRequest<T>) -> [Row] {
        return try! fetchAll(request.selectStatement(db))
    }
    
    /// Returns a single row fetched from a fetch request.
    ///
    ///     let statement = db.selectStatement("SELECT ...")
    ///     let row = Row.fetchOne(db, request)
    @warn_unused_result
    public static func fetchOne<T>(db: Database, _ request: FetchRequest<T>) -> Row? {
        return try! fetchOne(request.selectStatement(db))
    }
}

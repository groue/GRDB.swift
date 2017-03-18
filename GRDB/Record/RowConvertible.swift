/// Types that adopt RowConvertible can be initialized from a database Row.
///
///     let row = try Row.fetchOne(db, "SELECT ...")!
///     let person = Person(row)
///
/// The protocol comes with built-in methods that allow to fetch cursors,
/// arrays, or single records:
///
///     try Person.fetchCursor(db, "SELECT ...", arguments:...) // DatabaseCursor<Person>
///     try Person.fetchAll(db, "SELECT ...", arguments:...)    // [Person]
///     try Person.fetchOne(db, "SELECT ...", arguments:...)    // Person?
///
///     let statement = try db.makeSelectStatement("SELECT ...")
///     try Person.fetchCursor(statement, arguments:...) // DatabaseCursor<Person>
///     try Person.fetchAll(statement, arguments:...)    // [Person]
///     try Person.fetchOne(statement, arguments:...)    // Person?
///
/// RowConvertible is adopted by Record.
public protocol RowConvertible {
    
    /// Initializes a record from `row`.
    ///
    /// For performance reasons, the row argument may be reused during the
    /// iteration of a fetch query. If you want to keep the row for later use,
    /// make sure to store a copy: `self.row = row.copy()`.
    init(row: Row)
    
    /// Do not call this method directly.
    ///
    /// This method is called in an arbitrary dispatch queue, after a record
    /// has been fetched from the database.
    ///
    /// Types that adopt RowConvertible have an opportunity to complete their
    /// initialization.
    mutating func awakeFromFetch(row: Row)
}

extension RowConvertible {
    
    /// Default implementation, which does nothing.
    public func awakeFromFetch(row: Row) { }

    
    // MARK: Fetching From SelectStatement
    
    /// A cursor over records fetched from a prepared statement.
    ///
    ///     let statement = try db.makeSelectStatement("SELECT * FROM persons")
    ///     let persons = try Person.fetchCursor(statement) // DatabaseCursor<Person>
    ///     while let person = try persons.next() { // Person
    ///         ...
    ///     }
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// The cursor must be iterated in a protected dispath queue.
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: A cursor over fetched records.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchCursor(_ statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> DatabaseCursor<Self> {
        // Reuse a single mutable row for performance.
        // It is the record's responsibility to copy the row if needed.
        // See Record.awakeFromFetch(), for example.
        let row = try Row(statement: statement).adapted(with: adapter, layout: statement)
        return statement.fetchCursor(arguments: arguments) {
            var record = self.init(row: row)
            record.awakeFromFetch(row: row)
            return record
        }
    }
    
    /// Returns an array of records fetched from a prepared statement.
    ///
    ///     let statement = try db.makeSelectStatement("SELECT * FROM persons")
    ///     let persons = try Person.fetchAll(statement) // [Person]
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An array of records.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchAll(_ statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> [Self] {
        return try Array(fetchCursor(statement, arguments: arguments, adapter: adapter))
    }
    
    /// Returns a single record fetched from a prepared statement.
    ///
    ///     let statement = try db.makeSelectStatement("SELECT * FROM persons")
    ///     let person = try Person.fetchOne(statement) // Person?
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An optional record.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchOne(_ statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> Self? {
        return try fetchCursor(statement, arguments: arguments, adapter: adapter).next()
    }
}

extension RowConvertible {
    
    // MARK: Fetching From Request
    
    /// Returns a cursor over records fetched from a fetch request.
    ///
    ///     let nameColumn = Column("firstName")
    ///     let request = Person.order(nameColumn)
    ///     let identities = try Identity.fetchCursor(db, request) // DatabaseCursor<Identity>
    ///     while let identity = try identities.next() { // Identity
    ///         ...
    ///     }
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// The cursor must be iterated in a protected dispath queue.
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - request: A fetch request.
    /// - returns: A cursor over fetched records.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchCursor(_ db: Database, _ request: Request) throws -> DatabaseCursor<Self> {
        let (statement, adapter) = try request.prepare(db)
        return try fetchCursor(statement, adapter: adapter)
    }
    
    /// Returns an array of records fetched from a fetch request.
    ///
    ///     let nameColumn = Column("name")
    ///     let request = Person.order(nameColumn)
    ///     let identities = try Identity.fetchAll(db, request) // [Identity]
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchAll(_ db: Database, _ request: Request) throws -> [Self] {
        let (statement, adapter) = try request.prepare(db)
        return try fetchAll(statement, adapter: adapter)
    }
    
    /// Returns a single record fetched from a fetch request.
    ///
    ///     let nameColumn = Column("name")
    ///     let request = Person.order(nameColumn)
    ///     let identity = try Identity.fetchOne(db, request) // Identity?
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchOne(_ db: Database, _ request: Request) throws -> Self? {
        let (statement, adapter) = try request.prepare(db)
        return try fetchOne(statement, adapter: adapter)
    }
}

extension RowConvertible {
    
    // MARK: Fetching From SQL
    
    /// Returns a cursor over records fetched from an SQL query.
    ///
    ///     let persons = try Person.fetchCursor(db, "SELECT * FROM persons") // DatabaseCursor<Person>
    ///     while let person = try persons.next() { // Person
    ///         ...
    ///     }
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// The cursor must be iterated in a protected dispath queue.
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL query.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: A cursor over fetched records.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchCursor(_ db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> DatabaseCursor<Self> {
        return try fetchCursor(db, SQLRequest(sql, arguments: arguments, adapter: adapter))
    }
    
    /// Returns an array of records fetched from an SQL query.
    ///
    ///     let persons = try Person.fetchAll(db, "SELECT * FROM persons") // [Person]
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL query.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An array of records.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchAll(_ db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> [Self] {
        return try fetchAll(db, SQLRequest(sql, arguments: arguments, adapter: adapter))
    }
    
    /// Returns a single record fetched from an SQL query.
    ///
    ///     let person = try Person.fetchOne(db, "SELECT * FROM persons") // Person?
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL query.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An optional record.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchOne(_ db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> Self? {
        return try fetchOne(db, SQLRequest(sql, arguments: arguments, adapter: adapter))
    }
}

extension RowConvertible where Self: TableMapping {
    
    // MARK: Fetching All
    
    /// A cursor over all records fetched from the database.
    ///
    ///     let persons = try Person.fetchCursor(db) // DatabaseCursor<Person>
    ///     while let person = try persons.next() {  // Person
    ///         ...
    ///     }
    ///
    /// Records are iterated in the natural ordering of the table.
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// The cursor must be iterated in a protected dispath queue.
    ///
    /// - parameter db: A database connection.
    /// - returns: A cursor over fetched records.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchCursor(_ db: Database) throws -> DatabaseCursor<Self> {
        return try all().fetchCursor(db)
    }
    
    /// An array of all records fetched from the database.
    ///
    ///     let persons = try Person.fetchAll(db) // [Person]
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchAll(_ db: Database) throws -> [Self] {
        return try all().fetchAll(db)
    }
    
    /// The first found record.
    ///
    ///     let person = try Person.fetchOne(db) // Person?
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchOne(_ db: Database) throws -> Self? {
        return try all().fetchOne(db)
    }
}

extension RowConvertible where Self: TableMapping {
    
    // MARK: Fetching by Single-Column Primary Key
    
    /// Returns a cursor over records, given their primary keys.
    ///
    ///     let persons = try Person.fetchCursor(db, keys: [1, 2, 3]) // DatabaseCursor<Person>
    ///     while let person = try persons.next() {
    ///         ...
    ///     }
    ///
    /// Records are iterated in unspecified order.
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - keys: A sequence of primary keys.
    /// - returns: A cursor over fetched records.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchCursor<Sequence: Swift.Sequence>(_ db: Database, keys: Sequence) throws -> DatabaseCursor<Self>? where Sequence.Iterator.Element: DatabaseValueConvertible {
        guard let statement = try makeFetchByPrimaryKeyStatement(db, keys: keys) else {
            return nil
        }
        return try fetchCursor(statement)
    }
    
    /// Returns an array of records, given their primary keys.
    ///
    ///     let persons = try Person.fetchAll(db, keys: [1, 2, 3]) // [Person]
    ///
    /// The order of records in the returned array is undefined.
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - keys: A sequence of primary keys.
    /// - returns: An array of records.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchAll<Sequence: Swift.Sequence>(_ db: Database, keys: Sequence) throws -> [Self] where Sequence.Iterator.Element: DatabaseValueConvertible {
        guard let statement = try makeFetchByPrimaryKeyStatement(db, keys: keys) else {
            return []
        }
        return try fetchAll(statement)
    }
    
    /// Returns a single record given its primary key.
    ///
    ///     let person = try Person.fetchOne(db, key: 123) // Person?
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - key: A primary key value.
    /// - returns: An optional record.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchOne<PrimaryKeyType: DatabaseValueConvertible>(_ db: Database, key: PrimaryKeyType?) throws -> Self? {
        guard let key = key else {
            return nil
        }
        return try fetchOne(makeFetchByPrimaryKeyStatement(db, keys: [key])!)
    }
    
    // Returns "SELECT * FROM table WHERE id IN (?,?,?)"
    //
    // Returns nil if values is empty.
    private static func makeFetchByPrimaryKeyStatement<Sequence: Swift.Sequence>(_ db: Database, keys: Sequence) throws -> SelectStatement? where Sequence.Iterator.Element: DatabaseValueConvertible {
        // Fail early if database table does not exist.
        let databaseTableName = self.databaseTableName
        let primaryKey = try db.primaryKey(databaseTableName)
        
        // Fail early if database table has not one column in its primary key
        let columns = primaryKey?.columns ?? []
        GRDBPrecondition(columns.count <= 1, "requires single column primary key in table: \(databaseTableName)")
        let column = columns.first ?? Column.rowID.name
        
        let keys = Array(keys)
        switch keys.count {
        case 0:
            // Avoid performing useless SELECT
            return nil
        case 1:
            // SELECT * FROM table WHERE id = ?
            let sql = "SELECT \(defaultSelection) FROM \(databaseTableName.quotedDatabaseIdentifier) WHERE \(column.quotedDatabaseIdentifier) = ?"
            let statement = try db.makeSelectStatement(sql)
            statement.arguments = StatementArguments(keys)
            return statement
        case let count:
            // SELECT * FROM table WHERE id IN (?,?,?)
            let keysSQL = databaseQuestionMarks(count: count)
            let sql = "SELECT \(defaultSelection) FROM \(databaseTableName.quotedDatabaseIdentifier) WHERE \(column.quotedDatabaseIdentifier) IN (\(keysSQL))"
            let statement = try db.makeSelectStatement(sql)
            statement.arguments = StatementArguments(keys)
            return statement
        }
    }
}

extension RowConvertible where Self: TableMapping {
    
    // MARK: Fetching by Key
    
    /// Returns a cursor over records identified by the provided unique keys
    /// (primary key or any key with a unique index on it).
    ///
    ///     let persons = try Person.fetchCursor(db, keys: [["email": "a@example.com"], ["email": "b@example.com"]]) // DatabaseCursor<Person>
    ///     while let person = try persons.next() { // Person
    ///         ...
    ///     }
    ///
    /// Records are iterated in unspecified order.
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - keys: An array of key dictionaries.
    /// - returns: A cursor over fetched records.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchCursor(_ db: Database, keys: [[String: DatabaseValueConvertible?]]) throws -> DatabaseCursor<Self>? {
        guard let statement = try makeFetchByKeyStatement(db, keys: keys) else {
            return nil
        }
        return try fetchCursor(statement)
    }
    
    /// Returns an array of records identified by the provided unique keys
    /// (primary key or any key with a unique index on it).
    ///
    ///     let persons = try Person.fetchAll(db, keys: [["email": "a@example.com"], ["email": "b@example.com"]]) // [Person]
    ///
    /// The order of records in the returned array is undefined.
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - keys: An array of key dictionaries.
    /// - returns: An array of records.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchAll(_ db: Database, keys: [[String: DatabaseValueConvertible?]]) throws -> [Self] {
        guard let statement = try makeFetchByKeyStatement(db, keys: keys) else {
            return []
        }
        return try fetchAll(statement)
    }
    
    /// Returns a single record identified by a unique key (the primary key or
    /// any key with a unique index on it).
    ///
    ///     let person = try Person.fetchOne(db, key: ["name": Arthur"]) // Person?
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - key: A dictionary of values.
    /// - returns: An optional record.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchOne(_ db: Database, key: [String: DatabaseValueConvertible?]) throws -> Self? {
        return try fetchOne(makeFetchByKeyStatement(db, keys: [key])!)
    }
    
    // Returns "SELECT * FROM table WHERE (a = ? AND b = ?) OR (a = ? AND b = ?) ...
    //
    // Returns nil if keys is empty.
    //
    // If there is no unique index on the columns, the method raises a fatal
    // (unless fatalErrorOnMissingUniqueIndex is false, for testability).
    static func makeFetchByKeyStatement(_ db: Database, keys: [[String: DatabaseValueConvertible?]], fatalErrorOnMissingUniqueIndex: Bool = true) throws -> SelectStatement? {
        // Avoid performing useless SELECT
        guard keys.count > 0 else {
            return nil
        }
        
        let databaseTableName = self.databaseTableName
        var arguments: [DatabaseValueConvertible?] = []
        var whereClauses: [String] = []
        for dictionary in keys {
            GRDBPrecondition(dictionary.count > 0, "Invalid empty key dictionary")
            let columns = Array(dictionary.keys)
            guard let orderedColumns = try db.columnsForUniqueKey(columns, in: databaseTableName) else {
                let error = DatabaseError(resultCode: .SQLITE_MISUSE, message: "table \(databaseTableName) has no unique index on column(s) \(columns.sorted().joined(separator: ", "))")
                if fatalErrorOnMissingUniqueIndex {
                    // Programmer error
                    fatalError(error.description)
                } else {
                    throw error
                }
            }
            arguments.append(contentsOf: orderedColumns.map { orderedColumn in
                dictionary.first { (column, value) in column.lowercased() == orderedColumn.lowercased() }!.value
            })
            whereClauses.append("(" + (orderedColumns.map { "\($0.quotedDatabaseIdentifier) = ?" } as [String]).joined(separator: " AND ") + ")")
        }
        
        let whereClause = whereClauses.joined(separator: " OR ")
        let sql = "SELECT \(defaultSelection) FROM \(databaseTableName.quotedDatabaseIdentifier) WHERE \(whereClause)"
        let statement = try db.makeSelectStatement(sql)
        statement.arguments = StatementArguments(arguments)
        return statement
    }
    
    fileprivate static var defaultSelection: String {
        if selectsRowID {
            return "*, rowid"
        } else {
            return "*"
        }
    }
}

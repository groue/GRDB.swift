#if !USING_BUILTIN_SQLITE
    #if os(OSX)
        import SQLiteMacOSX
    #elseif os(iOS)
        #if (arch(i386) || arch(x86_64))
            import SQLiteiPhoneSimulator
        #else
            import SQLiteiPhoneOS
        #endif
    #elseif os(watchOS)
        #if (arch(i386) || arch(x86_64))
            import SQLiteWatchSimulator
        #else
            import SQLiteWatchOS
        #endif
    #endif
#endif

/// When a type adopts both DatabaseValueConvertible and
/// StatementColumnConvertible, it is granted with faster access to the SQLite
/// database values.
public protocol StatementColumnConvertible {
    
    /// Returns a value initialized from a raw SQLite statement pointer.
    ///
    /// As an example, here is the how Int64 adopts StatementColumnConvertible:
    ///
    ///     extension Int64: StatementColumnConvertible {
    ///         public init(sqliteStatement: SQLiteStatement, index: Int32) {
    ///             self = sqlite3_column_int64(sqliteStatement, index)
    ///         }
    ///     }
    ///
    /// When you implement this method, don't check for NULL.
    ///
    /// See https://www.sqlite.org/c3ref/column_blob.html for more information.
    ///
    /// - parameters:
    ///     - sqliteStatement: A pointer to an SQLite statement.
    ///     - index: The column index.
    init(sqliteStatement: SQLiteStatement, index: Int32)
}


/// Types that adopt both DatabaseValueConvertible and
/// StatementColumnConvertible can be efficiently initialized from
/// database values.
///
/// See DatabaseValueConvertible for more information.
public extension DatabaseValueConvertible where Self: StatementColumnConvertible {
    
    
    // MARK: Fetching From SelectStatement
    
    /// Returns a sequence of values fetched from a prepared statement.
    ///
    ///     let statement = db.makeSelectStatement("SELECT name FROM ...")
    ///     let names = String.fetch(statement) // DatabaseSequence<String>
    ///
    /// The returned sequence can be consumed several times, but it may yield
    /// different results, should database changes have occurred between two
    /// generations:
    ///
    ///     let names = String.fetch(statement)
    ///     Array(names) // Arthur, Barbara
    ///     db.execute("DELETE ...")
    ///     Array(names) // Arthur
    ///
    /// If the database is modified while the sequence is iterating, the
    /// remaining elements are undefined.
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: A sequence of values.
    public static func fetch(_ statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) -> DatabaseSequence<Self> {
        if let adapter = adapter {
            let row = try! Row(statement: statement).adaptedRow(adapter: adapter, statement: statement)
            return statement.fetchSequence(arguments: arguments) {
                row.value(atIndex: 0)
            }
        } else {
            let sqliteStatement = statement.sqliteStatement
            return statement.fetchSequence(arguments: arguments) {
                guard sqlite3_column_type(sqliteStatement, 0) != SQLITE_NULL else {
                    fatalError("could not convert database NULL value to \(Self.self)")
                }
                return Self.init(sqliteStatement: sqliteStatement, index: 0)
            }
        }
    }
    
    /// Returns an array of values fetched from a prepared statement.
    ///
    ///     let statement = db.makeSelectStatement("SELECT name FROM ...")
    ///     let names = String.fetchAll(statement)  // [String]
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An array of values.
    public static func fetchAll(_ statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) -> [Self] {
        return Array(fetch(statement, arguments: arguments, adapter: adapter))
    }
    
    /// Returns a single value fetched from a prepared statement.
    ///
    ///     let statement = db.makeSelectStatement("SELECT name FROM ...")
    ///     let name = String.fetchOne(statement)   // String?
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An optional value.
    public static func fetchOne(_ statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) -> Self? {
        if let adapter = adapter {
            let row = try! Row(statement: statement).adaptedRow(adapter: adapter, statement: statement)
            let sequence = statement.fetchSequence(arguments: arguments) {
                row.value(atIndex: 0) as Self?
            }
            if let value = sequence.makeIterator().next() {
                return value
            }
            return nil
        } else {
            let sqliteStatement = statement.sqliteStatement
            let sequence = statement.fetchSequence(arguments: arguments) {
                (sqlite3_column_type(sqliteStatement, 0) == SQLITE_NULL) ?
                    (nil as Self?) :
                    Self.init(sqliteStatement: sqliteStatement, index: 0)
            }
            if let value = sequence.makeIterator().next() {
                return value
            }
            return nil
        }
    }
}


extension DatabaseValueConvertible where Self: StatementColumnConvertible {
    
    // MARK: Fetching From FetchRequest
    
    /// Returns a sequence of values fetched from a fetch request.
    ///
    ///     let nameColumn = Column("name")
    ///     let request = Person.select(nameColumn)
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
    public static func fetch(_ db: Database, _ request: FetchRequest) -> DatabaseSequence<Self> {
        let (statement, adapter) = try! request.prepare(db)
        return fetch(statement, adapter: adapter)
    }
    
    /// Returns an array of values fetched from a fetch request.
    ///
    ///     let nameColumn = Column("name")
    ///     let request = Person.select(nameColumn)
    ///     let names = String.fetchAll(db, request)  // [String]
    ///
    /// - parameter db: A database connection.
    public static func fetchAll(_ db: Database, _ request: FetchRequest) -> [Self] {
        let (statement, adapter) = try! request.prepare(db)
        return fetchAll(statement, adapter: adapter)
    }
    
    /// Returns a single value fetched from a fetch request.
    ///
    /// The result is nil if the query returns no row, or if no value can be
    /// extracted from the first row.
    ///
    ///     let nameColumn = Column("name")
    ///     let request = Person.select(nameColumn)
    ///     let name = String.fetchOne(db, request)   // String?
    ///
    /// - parameter db: A database connection.
    public static func fetchOne(_ db: Database, _ request: FetchRequest) -> Self? {
        let (statement, adapter) = try! request.prepare(db)
        return fetchOne(statement, adapter: adapter)
    }
}


extension DatabaseValueConvertible where Self: StatementColumnConvertible {

    // MARK: Fetching From SQL
    
    /// Returns a sequence of values fetched from an SQL query.
    ///
    ///     let names = String.fetch(db, "SELECT name FROM ...") // DatabaseSequence<String>
    ///
    /// The returned sequence can be consumed several times, but it may yield
    /// different results, should database changes have occurred between two
    /// generations:
    ///
    ///     let names = String.fetch(db, "SELECT name FROM ...")
    ///     Array(names) // Arthur, Barbara
    ///     execute("DELETE ...")
    ///     Array(names) // Arthur
    ///
    /// If the database is modified while the sequence is iterating, the
    /// remaining elements are undefined.
    ///
    /// - parameters:
    ///     - db: A Database.
    ///     - sql: An SQL query.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: A sequence of values.
    public static func fetch(_ db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) -> DatabaseSequence<Self> {
        return fetch(db, SQLFetchRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
    
    /// Returns an array of values fetched from an SQL query.
    ///
    ///     let names = String.fetchAll(db, "SELECT name FROM ...") // [String]
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL query.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An array of values.
    public static func fetchAll(_ db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) -> [Self] {
        return fetchAll(db, SQLFetchRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
    
    /// Returns a single value fetched from an SQL query.
    ///
    ///     let name = String.fetchOne(db, "SELECT name FROM ...") // String?
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL query.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An optional value.
    public static func fetchOne(_ db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) -> Self? {
        return fetchOne(db, SQLFetchRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
}

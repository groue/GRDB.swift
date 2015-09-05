/// A nicer name than COpaquePointer for SQLite connection handle
typealias SQLiteConnection = COpaquePointer

/**
A Database connection.

You don't create a database directly. Instead, you use a DatabaseQueue:

    let dbQueue = DatabaseQueue(...)

    // The Database is the `db` in the closure:
    dbQueue.inDatabase { db in
        db.execute(...)
    }
*/
public final class Database {
    
    // MARK: - Select Statements
    
    /**
    Returns a select statement that can be reused.
    
        let statement = db.selectStatement("SELECT * FROM persons WHERE age > ?")
        let moreThanTwentyCount = Int.fetchOne(statement, arguments: [20])!
        let moreThanThirtyCount = Int.fetchOne(statement, arguments: [30])!
    
    - parameter sql: An SQL query.
    - returns: A SelectStatement.
    */
    public func selectStatement(sql: String) -> SelectStatement {
        return try! SelectStatement(database: self, sql: sql)
    }
    
    
    // MARK: - Update Statements
    
    /**
    Returns an update statement that can be reused.
    
        let statement = try db.updateStatement("INSERT INTO persons (name) VALUES (?)")
        try statement.execute(arguments: ["Arthur"])
        try statement.execute(arguments: ["Barbara"])
    
    This method may throw a DatabaseError.
    
    - parameter sql: An SQL query.
    - returns: An UpdateStatement.
    - throws: A DatabaseError whenever a SQLite error occurs.
    */
    public func updateStatement(sql: String) throws -> UpdateStatement {
        return try UpdateStatement(database: self, sql: sql)
    }
    
    /**
    Executes an update statement.
    
        db.excute("INSERT INTO persons (name) VALUES (?)", arguments: ["Arthur"])
    
    This method may throw a DatabaseError.
    
    - parameter sql: An SQL query.
    - parameter arguments: Optional query arguments.
    - returns: A DatabaseChanges.
    - throws: A DatabaseError whenever a SQLite error occurs.
    */
    public func execute(sql: String, arguments: StatementArguments? = nil) throws -> DatabaseChanges {
        let statement = try updateStatement(sql)
        return try statement.execute(arguments: arguments)
    }
    
    
    /**
    Executes multiple SQL statements (separated by a semi-colon).
    
        try db.executeMultiStatement(
            "INSERT INTO persons (name) VALUES ('Harry');" +
            "INSERT INTO persons (name) VALUES ('Ron');" +
            "INSERT INTO persons (name) VALUES ('Hermione');")
    
    This method may throw a DatabaseError.
    
    - parameter sql: SQL containing multiple statements separated by semi-colons.
    - returns: A DatabaseChanges. Note that insertedRowID will always be nil.
    - throws: A DatabaseError whenever a SQLite error occurs.
    */
    public func executeMultiStatement(sql: String) throws -> DatabaseChanges {
        if let trace = self.configuration.trace {
            trace(sql: sql, arguments: nil)
        }
        
        let changedRowsBefore = sqlite3_total_changes(self.sqliteConnection)
        
        let code = sqlite3_exec(self.sqliteConnection, sql, nil, nil, nil)
        guard code == SQLITE_OK else {
            throw DatabaseError(code: code, message: self.lastErrorMessage, sql: sql, arguments: nil)
        }
        
        let changedRowsAfter = sqlite3_total_changes(self.sqliteConnection)
        return DatabaseChanges(changedRowCount: changedRowsAfter - changedRowsBefore, insertedRowID: nil)
    }
    
    
    // MARK: - Transactions
    
    /// A SQLite transaction type. See https://www.sqlite.org/lang_transaction.html
    public enum TransactionType {
        case Deferred
        case Immediate
        case Exclusive
    }
    
    /// The end of a transaction: Commit, or Rollback
    public enum TransactionCompletion {
        case Commit
        case Rollback
    }
    
    
    // MARK: - Database Informations
    
    /**
    Returns whether a table exists.
    
    - parameter tableName: A table name.
    - returns: true if the table exists.
    */
    public func tableExists(tableName: String) -> Bool {
        // SQlite identifiers are case-insensitive, case-preserving (http://www.alberton.info/dbms_identifiers_and_case_sensitivity.html)
        if let _ = Row.fetchOne(self, "SELECT \"sql\" FROM sqlite_master WHERE \"type\" = 'table' AND LOWER(name) = ?", arguments: [tableName.lowercaseString]) {
            return true
        } else {
            return false
        }
    }
    
    /// Cache for primaryKeyForTable()
    private var primaryKeys: [String: PrimaryKey] = [:]
    
    /// Return the primary key for table named `tableName`, or nil if table does
    /// not exist.
    ///
    /// This method is not thread-safe.
    func primaryKeyForTable(named name: String) -> PrimaryKey? {
        if let primaryKey = primaryKeys[name] {
            return primaryKey
        } else {
            let primaryKey = fetchPrimaryKeyForTable(named: name)
            primaryKeys[name] = primaryKey
            return primaryKey
        }
    }
    
    private func fetchPrimaryKeyForTable(named name: String) -> PrimaryKey? {
        // https://www.sqlite.org/pragma.html
        //
        // > PRAGMA database.table_info(table-name);
        // >
        // > This pragma returns one row for each column in the named table.
        // > Columns in the result set include the column name, data type,
        // > whether or not the column can be NULL, and the default value for
        // > the column. The "pk" column in the result set is zero for columns
        // > that are not part of the primary key, and is the index of the
        // > column in the primary key for columns that are part of the primary
        // > key.
        //
        // CREATE TABLE persons (
        //   id INTEGER PRIMARY KEY,
        //   firstName TEXT,
        //   lastName TEXT)
        //
        // PRAGMA table_info("persons")
        //
        // cid | name      | type    | notnull | dflt_value | pk |
        // 0   | id        | INTEGER | 0       | NULL       | 1  |
        // 1   | firstName | TEXT    | 0       | NULL       | 0  |
        // 2   | lastName  | TEXT    | 0       | NULL       | 0  |
        
        let rows = Row.fetchAll(self, "PRAGMA table_info(\(name.quotedDatabaseIdentifier))")
        guard rows.count > 0 else {
            // Table does not exist
            return nil
        }
        
        let columns = rows
            
            // Columns name, type, primary key index
            .map { (
                name: $0.value(named: "name")! as String,
                type: $0.value(named: "type")! as String,
                primaryKeyIndex: $0.value(named: "pk")! as Int) }
            
            // Columns part of the primary key.
            .filter { $0.primaryKeyIndex > 0 }
            
            // Sort by primary key index.
            .sort { $0.primaryKeyIndex < $1.primaryKeyIndex }
        
        switch columns.count {
        case 0:
            // No column => no primary key
            return PrimaryKey.None
        case 1:
            // Single column
            let column = columns.first!
            if column.type == "INTEGER" {
                // INTEGER PRIMARY KEY
                return .Managed(column.name)
            } else {
                return .Unmanaged([column.name])
            }
        default:
            // Multi-columns primary key
            return .Unmanaged(columns.map { $0.name })
        }
    }
    
    // MARK: - Non public
    
    /// The database configuration
    let configuration: Configuration
    
    /// The SQLite connection handle
    let sqliteConnection = SQLiteConnection()
    
    /// The last error message
    var lastErrorMessage: String? { return String.fromCString(sqlite3_errmsg(sqliteConnection)) }
    
    init(path: String, configuration: Configuration) throws {
        self.configuration = configuration
        
        // See https://www.sqlite.org/c3ref/open.html
        let code = sqlite3_open_v2(path, &sqliteConnection, configuration.sqliteOpenFlags, nil)
        if code != SQLITE_OK {
            throw DatabaseError(code: code, message: String.fromCString(sqlite3_errmsg(sqliteConnection)))
        }
        
        if configuration.foreignKeysEnabled {
            try execute("PRAGMA foreign_keys = ON")
        }
    }
    
    // Initializes an in-memory database
    convenience init(configuration: Configuration) {
        try! self.init(path: ":memory:", configuration: configuration)
    }
    
    deinit {
        if sqliteConnection != nil {
            sqlite3_close(sqliteConnection)
        }
    }
    
    /**
    Executes a block inside a database transaction.
    
        try dbQueue.inTransaction do {
            try db.execute("INSERT ...")
            return .Commit
        }
    
    If the block throws an error, the transaction is rollbacked and the error is
    rethrown.
    
    - parameter type:  The transaction type
                       See https://www.sqlite.org/lang_transaction.html
    - parameter block: A block that executes SQL statements and return either
                       .Commit or .Rollback.
    - throws: The error thrown by the block.
    */
    func inTransaction(type: TransactionType, block: () throws -> TransactionCompletion) rethrows {
        var completion: TransactionCompletion = .Rollback
        var dbError: ErrorType? = nil
        
        try! beginTransaction(type)
        
        do {
            completion = try block()
        } catch {
            completion = .Rollback
            dbError = error
        }
        
        switch completion {
        case .Commit:
            try! commit()
        case .Rollback:
            try! rollback()
        }
        
        if let dbError = dbError {
            try { () -> Void in throw dbError }()
        }
    }

    private func beginTransaction(type: TransactionType = .Exclusive) throws {
        switch type {
        case .Deferred:
            try execute("BEGIN DEFERRED TRANSACTION")
        case .Immediate:
            try execute("BEGIN IMMEDIATE TRANSACTION")
        case .Exclusive:
            try execute("BEGIN EXCLUSIVE TRANSACTION")
        }
    }
    
    private func rollback() throws {
        try execute("ROLLBACK TRANSACTION")
    }
    
    private func commit() throws {
        try execute("COMMIT TRANSACTION")
    }
}


// MARK: - Error Management

@noreturn func fatalDatabaseError(error: DatabaseError) {
    func throwDataBasase(error: DatabaseError) throws {
        throw error
    }
    try! throwDataBasase(error)
    fatalError("Should not happen")
}


// MARK: - Database Information

/// A primary key
enum PrimaryKey {
    
    /// No primary key
    case None
    
    /// A primary key managed by SQLite. Associated string is a column name.
    case Managed(String)
    
    /// A primary key not managed by SQLite. It can span accross several
    /// columns. Associated strings are column names.
    case Unmanaged([String])
    
    /// The columns in the primary key. May be empty.
    var columns: [String] {
        switch self {
        case .None:
            return []
        case .Managed(let column):
            return [column]
        case .Unmanaged(let columns):
            return columns
        }
    }
}


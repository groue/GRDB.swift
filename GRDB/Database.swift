//
// GRDB.swift
// https://github.com/groue/GRDB.swift
// Copyright (c) 2015 Gwendal Roué
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.


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
        let moreThanTwentyCount = statement.fetchOne(Int.self, arguments: [20])!
        let moreThanThirtyCount = statement.fetchOne(Int.self, arguments: [30])!
    
    - parameter sql: An SQL query.
    - returns: A SelectStatement.
    */
    public func selectStatement(sql: String) -> SelectStatement {
        return verboseFailOnError {
            return try SelectStatement(database: self, sql: sql, unsafe: false)
        }
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
    - returns: A UpdateStatement.Changes.
    */
    public func execute(sql: String, arguments: QueryArguments? = nil) throws -> UpdateStatement.Changes {
        let statement = try updateStatement(sql)
        return try statement.execute(arguments: arguments)
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
    
    
    // MARK: - Miscellaneous
    
    /**
    Returns whether a table exists.
    
    - parameter tableName: A table name.
    - returns: true if the table exists.
    */
    public func tableExists(tableName: String) -> Bool {
        // SQlite identifiers are case-insensitive, case-preserving (http://www.alberton.info/dbms_identifiers_and_case_sensitivity.html)
        if let _ = fetchOneRow("SELECT \"sql\" FROM sqlite_master WHERE \"type\" = 'table' AND LOWER(name) = ?", arguments: [tableName.lowercaseString]) {
            return true
        } else {
            return false
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
    */
    func inTransaction(type: TransactionType, block: () throws -> TransactionCompletion) throws {
        var completion: TransactionCompletion = .Rollback
        var dbError: ErrorType? = nil
        
        try beginTransaction(type)
        
        do {
            completion = try block()
        } catch {
            completion = .Rollback
            dbError = error
        }
        
        do {
            switch completion {
            case .Commit:
                try commit()
            case .Rollback:
                try rollback()
            }
        } catch {
            if dbError == nil {
                dbError = error
            }
        }
        
        if let dbError = dbError {
            throw dbError
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

/**
Convenience function that calls fatalError in case of error

    let x = verboseFailOnError {
        ...
    }
*/
func verboseFailOnError<Result>(@noescape block: (Void) throws -> Result) -> Result {
    do {
        return try block()
    } catch let error as DatabaseError {
        fatalError(error.description)
    } catch {
        fatalError("error: \(error)")
    }
}


// MARK: - Fetching Rows

/// The Database methods that fetch rows.
extension Database {
    
    /**
    Fetches a lazy sequence of rows.

        let rows = db.fetchRows("SELECT ...")

    - parameter sql: An SQL query.
    - parameter arguments: Optional query arguments.
    - returns: A lazy sequence of rows.
    */
    public func fetchRows(sql: String, arguments: QueryArguments? = nil) -> AnySequence<Row> {
        return selectStatement(sql).fetchRows(arguments: arguments)
    }
    
    /**
    Fetches an array of rows.
    
        let rows = db.fetchAllRows("SELECT ...")
    
    - parameter sql: An SQL query.
    - parameter arguments: Optional query arguments.
    - returns: An array of rows.
    */
    public func fetchAllRows(sql: String, arguments: QueryArguments? = nil) -> [Row] {
        return Array(fetchRows(sql, arguments: arguments))
    }
    
    /**
    Fetches a single row.
    
        let row = db.fetchOneRow("SELECT ...")
    
    - parameter sql: An SQL query.
    - parameter arguments: Optional query arguments.
    - returns: An optional row.
    */
    public func fetchOneRow(sql: String, arguments: QueryArguments? = nil) -> Row? {
        return fetchRows(sql, arguments: arguments).generate().next()
    }
}


// MARK: - Fetching Values

/// The Database methods that fetch values.
extension Database {
    
    /**
    Fetches a lazy sequence of values.

        let names = db.fetch(String.self, "SELECT name FROM ...")

    - parameter type:      The type of fetched values. It must adopt
                           DatabaseValueConvertible.
    - parameter sql:       An SQL query.
    - parameter arguments: Optional query arguments.
    - returns: A lazy sequence of values.
    */
    public func fetch<Value: DatabaseValueConvertible>(type: Value.Type, _ sql: String, arguments: QueryArguments? = nil) -> AnySequence<Value?> {
        return selectStatement(sql).fetch(type, arguments: arguments)
    }
    
    /**
    Fetches an array of values.

        let names = db.fetchAll(String.self, "SELECT name FROM ...")

    - parameter type:      The type of fetched values. It must adopt
                           DatabaseValueConvertible.
    - parameter sql:       An SQL query.
    - parameter arguments: Optional query arguments.
    - returns: An array of values.
    */
    public func fetchAll<Value: DatabaseValueConvertible>(type: Value.Type, _ sql: String, arguments: QueryArguments? = nil) -> [Value?] {
        return Array(fetch(type, sql, arguments: arguments))
    }
    
    /**
    Fetches a single value.

        let name = db.fetchOne(String.self, "SELECT name FROM ...")

    - parameter type:      The type of fetched values. It must adopt
                           DatabaseValueConvertible.
    - parameter sql:       An SQL query.
    - parameter arguments: Optional query arguments.
    - returns: An optional value.
    */
    public func fetchOne<Value: DatabaseValueConvertible>(type: Value.Type, _ sql: String, arguments: QueryArguments? = nil) -> Value? {
        if let first = fetch(type, sql, arguments: arguments).generate().next() {
            // one row containing an optional value
            return first
        } else {
            // no row
            return nil
        }
    }
}


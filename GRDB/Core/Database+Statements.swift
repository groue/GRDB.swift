import Foundation
#if SWIFT_PACKAGE
import CSQLite
#elseif GRDBCIPHER
import SQLCipher
#elseif !GRDBCUSTOMSQLITE && !GRDBCIPHER
import SQLite3
#endif

extension Database {
    
    // MARK: - Statements
    
    /// Returns a new prepared statement that can be reused.
    ///
    ///     let statement = try db.makeSelectStatement(sql: "SELECT COUNT(*) FROM player WHERE score > ?")
    ///     let moreThanTwentyCount = try Int.fetchOne(statement, arguments: [20])!
    ///     let moreThanThirtyCount = try Int.fetchOne(statement, arguments: [30])!
    ///
    /// - parameter sql: An SQL query.
    /// - returns: A SelectStatement.
    /// - throws: A DatabaseError whenever SQLite could not parse the sql query.
    public func makeSelectStatement(sql: String) throws -> SelectStatement {
        return try makeSelectStatement(sql: sql, prepFlags: 0)
    }
    
    /// Returns a new prepared statement that can be reused.
    ///
    ///     let statement = try db.makeSelectStatement(sql: "SELECT COUNT(*) FROM player WHERE score > ?", prepFlags: 0)
    ///     let moreThanTwentyCount = try Int.fetchOne(statement, arguments: [20])!
    ///     let moreThanThirtyCount = try Int.fetchOne(statement, arguments: [30])!
    ///
    /// - parameter sql: An SQL query.
    /// - parameter prepFlags: Flags for sqlite3_prepare_v3 (available from
    ///   SQLite 3.20.0, see http://www.sqlite.org/c3ref/prepare.html)
    /// - returns: A SelectStatement.
    /// - throws: A DatabaseError whenever SQLite could not parse the sql query.
    func makeSelectStatement(sql: String, prepFlags: Int32) throws -> SelectStatement {
        return try SelectStatement.prepare(self, sql: sql, prepFlags: prepFlags)
    }
    
    /// Returns a prepared statement that can be reused.
    ///
    ///     let statement = try db.cachedSelectStatement(sql: "SELECT COUNT(*) FROM player WHERE score > ?")
    ///     let moreThanTwentyCount = try Int.fetchOne(statement, arguments: [20])!
    ///     let moreThanThirtyCount = try Int.fetchOne(statement, arguments: [30])!
    ///
    /// The returned statement may have already been used: it may or may not
    /// contain values for its eventual arguments.
    ///
    /// - parameter sql: An SQL query.
    /// - returns: An UpdateStatement.
    /// - throws: A DatabaseError whenever SQLite could not parse the sql query.
    public func cachedSelectStatement(sql: String) throws -> SelectStatement {
        return try publicStatementCache.selectStatement(sql)
    }
    
    /// Returns a cached statement that does not conflict with user's cached statements.
    func internalCachedSelectStatement(sql: String) throws -> SelectStatement {
        return try internalStatementCache.selectStatement(sql)
    }
    
    /// Returns a new prepared statement that can be reused.
    ///
    ///     let statement = try db.makeUpdateStatement(sql: "INSERT INTO player (name) VALUES (?)")
    ///     try statement.execute(arguments: ["Arthur"])
    ///     try statement.execute(arguments: ["Barbara"])
    ///
    /// - parameter sql: An SQL query.
    /// - returns: An UpdateStatement.
    /// - throws: A DatabaseError whenever SQLite could not parse the sql query.
    public func makeUpdateStatement(sql: String) throws -> UpdateStatement {
        return try makeUpdateStatement(sql: sql, prepFlags: 0)
    }
    
    /// Returns a new prepared statement that can be reused.
    ///
    ///     let statement = try db.makeUpdateStatement(sql: "INSERT INTO player (name) VALUES (?)", prepFlags: 0)
    ///     try statement.execute(arguments: ["Arthur"])
    ///     try statement.execute(arguments: ["Barbara"])
    ///
    /// - parameter sql: An SQL query.
    /// - parameter prepFlags: Flags for sqlite3_prepare_v3 (available from
    ///   SQLite 3.20.0, see http://www.sqlite.org/c3ref/prepare.html)
    /// - returns: An UpdateStatement.
    /// - throws: A DatabaseError whenever SQLite could not parse the sql query.
    func makeUpdateStatement(sql: String, prepFlags: Int32) throws -> UpdateStatement {
        return try UpdateStatement.prepare(self, sql: sql, prepFlags: prepFlags)
    }
    
    /// Returns a prepared statement that can be reused.
    ///
    ///     let statement = try db.cachedUpdateStatement(sql: "INSERT INTO player (name) VALUES (?)")
    ///     try statement.execute(arguments: ["Arthur"])
    ///     try statement.execute(arguments: ["Barbara"])
    ///
    /// The returned statement may have already been used: it may or may not
    /// contain values for its eventual arguments.
    ///
    /// - parameter sql: An SQL query.
    /// - returns: An UpdateStatement.
    /// - throws: A DatabaseError whenever SQLite could not parse the sql query.
    public func cachedUpdateStatement(sql: String) throws -> UpdateStatement {
        return try publicStatementCache.updateStatement(sql)
    }
    
    /// Returns a cached statement that does not conflict with user's cached statements.
    func internalCachedUpdateStatement(sql: String) throws -> UpdateStatement {
        return try internalStatementCache.updateStatement(sql)
    }
    
    /// Executes one or several SQL statements, separated by semi-colons.
    ///
    ///     try db.execute(
    ///         sql: "INSERT INTO player (name) VALUES (:name)",
    ///         arguments: ["name": "Arthur"])
    ///
    ///     try db.execute(sql: """
    ///         INSERT INTO player (name) VALUES (?);
    ///         INSERT INTO player (name) VALUES (?);
    ///         INSERT INTO player (name) VALUES (?);
    ///         """, arguments: ["Arthur", "Barbara", "O'Brien"])
    ///
    /// This method may throw a DatabaseError.
    ///
    /// - parameters:
    ///     - sql: An SQL query.
    ///     - arguments: Statement arguments.
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    public func execute(sql: String, arguments: StatementArguments = StatementArguments()) throws {
        try execute(literal: SQLLiteral(sql: sql, arguments: arguments))
    }
    
    /// Executes one or several SQL statements, separated by semi-colons.
    ///
    ///     try db.execute(literal: SQLLiteral(
    ///         sql: "INSERT INTO player (name) VALUES (:name)",
    ///         arguments: ["name": "Arthur"]))
    ///
    ///     try db.execute(literal: SQLLiteral(sql: """
    ///         INSERT INTO player (name) VALUES (?);
    ///         INSERT INTO player (name) VALUES (?);
    ///         INSERT INTO player (name) VALUES (?);
    ///         """, arguments: ["Arthur", "Barbara", "O'Brien"]))
    ///
    /// With Swift 5, you can safely embed raw values in your SQL queries,
    /// without any risk of syntax errors or SQL injection:
    ///
    ///     try db.execute(literal: """
    ///         INSERT INTO player (name) VALUES (\("Arthur"));
    ///         INSERT INTO player (name) VALUES (\("Barbara"));
    ///         INSERT INTO player (name) VALUES (\("O'Brien"));
    ///         """)
    ///
    /// This method may throw a DatabaseError.
    ///
    /// - parameter sqlLiteral: An SQLLiteral.
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    public func execute(literal sqlLiteral: SQLLiteral) throws {
        // This method is like sqlite3_exec (https://www.sqlite.org/c3ref/exec.html)
        // It adds support for arguments, and the tricky part is to consume
        // arguments as statements are executed.
        //
        // This job is performed by StatementArguments.extractBindings(forStatement:allowingRemainingValues:)
        //
        // And before we return, we'll check that all arguments were consumed.
        
        var context = SQLGenerationContext.sqlLiteralContext
        let sql = sqlLiteral.sql(&context)
        var arguments = context.arguments
        let initialValuesCount = arguments.values.count
        
        // Build a C string (SQLite wants that), and execute SQL statements one
        // after the other.
        try sql.utf8CString.withUnsafeBufferPointer { buffer in
            guard let sqlStart = buffer.baseAddress else { return }
            let sqlEnd = sqlStart + buffer.count // past \0
            var statementStart = sqlStart
            while statementStart < sqlEnd {
                var statementEnd: UnsafePointer<Int8>? = nil
                let nextStatement: UpdateStatement?
                
                // Compile
                do {
                    let authorizer = StatementCompilationAuthorizer()
                    nextStatement = try withAuthorizer(authorizer) {
                        try UpdateStatement(
                            database: self,
                            statementStart: statementStart,
                            statementEnd: &statementEnd,
                            prepFlags: 0,
                            authorizer: authorizer)
                    }
                }
                
                guard let statement = nextStatement else {
                    // End of SQL string
                    break
                }
                
                // Extract statement arguments
                let bindings = try arguments.extractBindings(forStatement: statement, allowingRemainingValues: true)
                // unsafe is OK because we just extracted the correct number of arguments
                statement.setUncheckedArguments(StatementArguments(bindings))
                
                // Execute
                try statement.execute()
                
                // Next
                statementStart = statementEnd!
            }
        }
        
        // Check that all arguments were consumed: it is a programmer error to
        // provide arguments that do not match the statement.
        if arguments.values.isEmpty == false {
            throw DatabaseError(
                resultCode: .SQLITE_MISUSE,
                message: "wrong number of statement arguments: \(initialValuesCount)")
        }
    }
}

extension Database {
    func executeUpdateStatement(_ statement: UpdateStatement) throws {
        // Two things must prevent the statement from executing: aborted
        // transactions, and database suspension.
        try checkForAbortedTransaction(sql: statement.sql, arguments: statement.arguments)
        try checkForSuspensionViolation(from: statement)
        
        let authorizer = observationBroker.updateStatementWillExecute(statement)
        let sqliteStatement = statement.sqliteStatement
        var code: Int32 = SQLITE_OK
        withAuthorizer(authorizer) {
            while true {
                code = sqlite3_step(sqliteStatement)
                if code == SQLITE_ROW {
                    // Statement returns a row, but the user ignores the
                    // content of this row:
                    //
                    //     try db.execute(sql: "SELECT ...")
                    //
                    // That's OK: maybe the selected rows perform side effects.
                    // For example:
                    //
                    //      try db.execute(sql: "SELECT sqlcipher_export(...)")
                    //
                    // Or maybe the user doesn't know that the executed statement
                    // return rows (https://github.com/groue/GRDB.swift/issues/15);
                    //
                    //      try db.execute(sql: "PRAGMA journal_mode=WAL")
                    //
                    // It is thus important that we consume *all* rows.
                    continue
                } else {
                    break
                }
            }
        }
        
        // Statement has been fully executed, and authorizer has been reset.
        // We can now move on further tasks.
        
        if code == SQLITE_DONE {
            try updateStatementDidExecute(statement)
        } else {
            assert(code != SQLITE_ROW)
            try updateStatementDidFail(statement)
            throw DatabaseError(
                resultCode: code,
                message: lastErrorMessage,
                sql: statement.sql,
                arguments: statement.arguments)
        }
    }
    
    private func updateStatementDidExecute(_ statement: UpdateStatement) throws {
        if statement.invalidatesDatabaseSchemaCache {
            clearSchemaCache()
        }
        
        try observationBroker.updateStatementDidExecute(statement)
    }
    
    private func updateStatementDidFail(_ statement: UpdateStatement) throws {
        // Failed statements can not be reused, because sqlite3_reset won't
        // be able to restore the statement to its initial state:
        // https://www.sqlite.org/c3ref/reset.html
        //
        // So make sure we clear this statement from the cache.
        internalStatementCache.remove(statement)
        publicStatementCache.remove(statement)
        
        try observationBroker.updateStatementDidFail(statement)
    }
    
    @inline(__always)
    func selectStatementWillExecute(_ statement: SelectStatement) throws {
        // Two things must prevent the statement from executing: aborted
        // transactions, and database suspension.
        try checkForAbortedTransaction(sql: statement.sql, arguments: statement.arguments)
        try checkForSuspensionViolation(from: statement)
        
        if _isRecordingSelectedRegion {
            // Don't record schema introspection queries, which may be
            // run, or not, depending on the state of the schema cache.
            //
            // This gives us a quick way to make sure that the observation
            // below, which runs schema introspection queries as a side effect,
            // only tracks the "player" table:
            //
            //      let observation = ValueObservation.tracking { db in
            //          try Player.fetchOne(db, key: 1)
            //      }
            //
            // Strictly speaking, this prevents the recording of all schema
            // queries. But we assume, until proven wrong, that such recording
            // isn't needed by anyone.
            let region = statement.databaseRegion.ignoringInternalSQLiteTables()
            _selectedRegion.formUnion(region)
        }
    }
    
    func selectStatementDidFail(_ statement: SelectStatement) {
        // Failed statements can not be reused, because sqlite3_reset won't
        // be able to restore the statement to its initial state:
        // https://www.sqlite.org/c3ref/reset.html
        //
        // So make sure we clear this statement from the cache.
        internalStatementCache.remove(statement)
        publicStatementCache.remove(statement)
    }
}

/// A thread-unsafe statement cache
struct StatementCache {
    unowned let db: Database
    private var selectStatements: [String: SelectStatement] = [:]
    private var updateStatements: [String: UpdateStatement] = [:]
    
    init(database: Database) {
        self.db = database
    }
    
    mutating func selectStatement(_ sql: String) throws -> SelectStatement {
        if let statement = selectStatements[sql] {
            return statement
        }
        
        // http://www.sqlite.org/c3ref/c_prepare_persistent.html#sqlitepreparepersistent
        // > The SQLITE_PREPARE_PERSISTENT flag is a hint to the query
        // > planner that the prepared statement will be retained for a long
        // > time and probably reused many times.
        //
        // This looks like a perfect match for cached statements.
        //
        // However SQLITE_PREPARE_PERSISTENT was only introduced in
        // SQLite 3.20.0 http://www.sqlite.org/changes.html#version_3_20
        #if GRDBCUSTOMSQLITE || GRDBCIPHER
        let statement = try db.makeSelectStatement(sql: sql, prepFlags: SQLITE_PREPARE_PERSISTENT)
        #else
        let statement: SelectStatement
        if #available(iOS 12.0, OSX 10.14, watchOS 5.0, *) {
            // SQLite 3.24.0 or more
            statement = try db.makeSelectStatement(sql: sql, prepFlags: SQLITE_PREPARE_PERSISTENT)
        } else {
            // SQLite 3.19.3 or less
            statement = try db.makeSelectStatement(sql: sql)
        }
        #endif
        selectStatements[sql] = statement
        return statement
    }
    
    mutating func updateStatement(_ sql: String) throws -> UpdateStatement {
        if let statement = updateStatements[sql] {
            return statement
        }
        
        // http://www.sqlite.org/c3ref/c_prepare_persistent.html#sqlitepreparepersistent
        // > The SQLITE_PREPARE_PERSISTENT flag is a hint to the query
        // > planner that the prepared statement will be retained for a long
        // > time and probably reused many times.
        //
        // This looks like a perfect match for cached statements.
        //
        // However SQLITE_PREPARE_PERSISTENT was only introduced in
        // SQLite 3.20.0 http://www.sqlite.org/changes.html#version_3_20
        #if GRDBCUSTOMSQLITE || GRDBCIPHER
        let statement = try db.makeUpdateStatement(sql: sql, prepFlags: SQLITE_PREPARE_PERSISTENT)
        #else
        let statement: UpdateStatement
        if #available(iOS 12.0, OSX 10.14, watchOS 5.0, *) {
            // SQLite 3.24.0 or more
            statement = try db.makeUpdateStatement(sql: sql, prepFlags: SQLITE_PREPARE_PERSISTENT)
        } else {
            // SQLite 3.19.3 or less
            statement = try db.makeUpdateStatement(sql: sql)
        }
        #endif
        updateStatements[sql] = statement
        return statement
    }
    
    mutating func clear() {
        updateStatements = [:]
        selectStatements = [:]
    }
    
    mutating func remove(_ statement: SelectStatement) {
        selectStatements.removeFirst { $0.value === statement }
    }
    
    mutating func remove(_ statement: UpdateStatement) {
        updateStatements.removeFirst { $0.value === statement }
    }
}

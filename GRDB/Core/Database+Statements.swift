import Foundation

extension Database {
    
    // MARK: - Statements
    
    /// Returns a new prepared statement that can be reused.
    ///
    /// For example:
    ///
    /// ```swift
    /// let statement = try db.makeStatement(sql: "SELECT * FROM player WHERE id = ?")
    /// let player1 = try Player.fetchOne(statement, arguments: [1])!
    /// let player2 = try Player.fetchOne(statement, arguments: [2])!
    ///
    /// let statement = try db.makeStatement(sql: "INSERT INTO player (name) VALUES (?)")
    /// try statement.execute(arguments: ["Arthur"])
    /// try statement.execute(arguments: ["Barbara"])
    /// ```
    ///
    /// - parameter sql: An SQL string.
    /// - returns: A prepared statement.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func makeStatement(sql: String) throws -> Statement {
        try makeStatement(sql: sql, prepFlags: 0)
    }
    
    /// Returns a new prepared statement that can be reused.
    ///
    /// For example:
    ///
    /// ```swift
    /// let statement = try db.makeStatement(literal: "SELECT * FROM player WHERE id = ?")
    /// let player1 = try Player.fetchOne(statement, arguments: [1])!
    /// let player2 = try Player.fetchOne(statement, arguments: [2])!
    ///
    /// let statement = try db.makeStatement(literal: "INSERT INTO player (name) VALUES (?)")
    /// try statement.execute(arguments: ["Arthur"])
    /// try statement.execute(arguments: ["Barbara"])
    /// ```
    ///
    /// In the provided literal, no argument must be set, or all arguments must
    /// be set. An error is raised otherwise. For example:
    ///
    /// ```swift
    /// // OK
    /// try makeStatement(literal: """
    ///     SELECT COUNT(*) FROM player WHERE score > ?
    ///     """)
    /// try makeStatement(literal: """
    ///     SELECT COUNT(*) FROM player WHERE score > \(1000)
    ///     """)
    ///
    /// // NOT OK (first argument is not set, but second is)
    /// try makeStatement(literal: """
    ///     SELECT COUNT(*) FROM player
    ///     WHERE color = ? AND score > \(1000)
    ///     """)
    ///  ```
    ///
    /// - parameter sqlLiteral: An ``SQL`` literal.
    /// - returns: A prepared statement.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func makeStatement(literal sqlLiteral: SQL) throws -> Statement {
        let (sql, arguments) = try sqlLiteral.build(self)
        let statement = try makeStatement(sql: sql)
        if arguments.isEmpty == false {
            // Throws if arguments do not match
            try statement.setArguments(arguments)
        }
        return statement
    }
    
    /// Returns a new prepared statement that can be reused.
    ///
    /// For example:
    ///
    ///     let statement = try db.makeStatement(sql: "SELECT COUNT(*) FROM player WHERE score > ?", prepFlags: 0)
    ///     let moreThanTwentyCount = try Int.fetchOne(statement, arguments: [20])!
    ///     let moreThanThirtyCount = try Int.fetchOne(statement, arguments: [30])!
    ///
    /// - parameter sql: An SQL string.
    /// - parameter prepFlags: Flags for sqlite3_prepare_v3 (available from
    ///   SQLite 3.20.0, see <http://www.sqlite.org/c3ref/prepare.html>)
    /// - returns: A prepared statement.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    func makeStatement(sql: String, prepFlags: CUnsignedInt) throws -> Statement {
        let statements = SQLStatementCursor(database: self, sql: sql, arguments: nil, prepFlags: prepFlags)
        guard let statement = try statements.next() else {
            throw DatabaseError(
                resultCode: .SQLITE_ERROR,
                message: "empty statement",
                sql: sql)
        }
        do {
            guard try statements.next() == nil else {
                throw DatabaseError(
                    resultCode: .SQLITE_MISUSE,
                    message: """
                    Multiple statements found. To execute multiple statements, use \
                    Database.execute(sql:) or Database.allStatements(sql:) instead.
                    """,
                    sql: sql)
            }
        } catch {
            // Something while would not compile was found after the first statement.
            // Complain about multiple statements anyway.
            throw DatabaseError(
                resultCode: .SQLITE_MISUSE,
                message: """
                    Multiple statements found. To execute multiple statements, use \
                    Database.execute(sql:) or Database.allStatements(sql:) instead.
                    """,
                sql: sql)
        }
        return statement
    }
    
    /// Returns a prepared statement that can be reused.
    ///
    /// For example:
    ///
    /// ```swift
    /// let statement = try db.cachedStatement(sql: "SELECT * FROM player WHERE id = ?")
    /// let player1 = try Player.fetchOne(statement, arguments: [1])!
    /// let player2 = try Player.fetchOne(statement, arguments: [2])!
    ///
    /// let statement = try db.cachedStatement(sql: "INSERT INTO player (name) VALUES (?)")
    /// try statement.execute(arguments: ["Arthur"])
    /// try statement.execute(arguments: ["Barbara"])
    /// ```
    ///
    /// The returned statement may have already been used: it may or may not
    /// contain values for its eventual arguments.
    ///
    /// - parameter sql: An SQL string.
    /// - returns: A prepared statement.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func cachedStatement(sql: String) throws -> Statement {
        try publicStatementCache.statement(sql)
    }
    
    /// Returns a prepared statement that can be reused.
    ///
    /// For example:
    ///
    /// ```swift
    /// let statement = try db.cachedStatement(literal: "SELECT * FROM player WHERE id = ?")
    /// let player1 = try Player.fetchOne(statement, arguments: [1])!
    /// let player2 = try Player.fetchOne(statement, arguments: [2])!
    ///
    /// let statement = try db.cachedStatement(literal: "INSERT INTO player (name) VALUES (?)")
    /// try statement.execute(arguments: ["Arthur"])
    /// try statement.execute(arguments: ["Barbara"])
    /// ```
    ///
    /// In the provided literal, no argument must be set, or all arguments must
    /// be set. An error is raised otherwise. For example:
    ///
    /// ```swift
    /// // OK
    /// try cachedStatement(literal: """
    ///     SELECT COUNT(*) FROM player WHERE score > ?
    ///     """)
    /// try cachedStatement(literal: """
    ///     SELECT COUNT(*) FROM player WHERE score > \(1000)
    ///     """)
    ///
    /// // NOT OK (first argument is not set, but second is)
    /// try cachedStatement(literal: """
    ///     SELECT COUNT(*) FROM player
    ///     WHERE color = ? AND score > \(1000)
    ///     """)
    /// ```
    ///
    /// - parameter sqlLiteral: An ``SQL`` literal.
    /// - returns: A prepared statement.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func cachedStatement(literal sqlLiteral: SQL) throws -> Statement {
        let (sql, arguments) = try sqlLiteral.build(self)
        let statement = try cachedStatement(sql: sql)
        if arguments.isEmpty == false {
            // Throws if arguments do not match
            try statement.setArguments(arguments)
        }
        return statement
    }
    
    /// Returns a cached statement that does not conflict with user's cached statements.
    func internalCachedStatement(sql: String) throws -> Statement {
        try internalStatementCache.statement(sql)
    }
    
    /// Returns a cursor of prepared statements.
    ///
    /// For example:
    ///
    /// ```swift
    /// let statements = try db.allStatements(sql: """
    ///     INSERT INTO player (name) VALUES (?);
    ///     INSERT INTO player (name) VALUES (?);
    ///     INSERT INTO player (name) VALUES (?);
    ///     """, arguments: ["Arthur", "Barbara", "O'Brien"])
    /// while let statement = try statements.next() {
    ///     try statement.execute()
    /// }
    /// ```
    ///
    /// The `arguments` parameter must be nil, or all arguments must be set. The
    /// returned cursor will throw an error otherwise. For example:
    ///
    /// ```swift
    /// // OK
    /// try allStatements(sql: """
    ///     SELECT COUNT(*) FROM player WHERE score < ?;
    ///     SELECT COUNT(*) FROM player WHERE score > ?;
    ///     """)
    ///
    /// try allStatements(sql: """
    ///     SELECT COUNT(*) FROM player WHERE score < ?;
    ///     SELECT COUNT(*) FROM player WHERE score > ?;
    ///     """, arguments: [1000, 1000])
    ///
    /// // NOT OK (first argument is set, but second is not)
    /// try allStatements(sql: """
    ///     SELECT COUNT(*) FROM player WHERE score < ?;
    ///     SELECT COUNT(*) FROM player WHERE score > ?;
    ///     """, arguments: [1000])
    /// ```
    ///
    /// - parameters:
    ///     - sql: An SQL string.
    ///     - arguments: Statement arguments.
    /// - returns: A cursor of prepared ``Statement``.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func allStatements(sql: String, arguments: StatementArguments? = nil)
    throws -> SQLStatementCursor
    {
        SQLStatementCursor(database: self, sql: sql, arguments: arguments)
    }

    /// Returns a cursor of prepared statements.
    ///
    /// ``SQL`` literals allow you to safely embed raw values in your SQL,
    /// without any risk of syntax errors or SQL injection:
    ///
    /// ```swift
    /// let statements = try db.allStatements(literal: """
    ///     INSERT INTO player (name) VALUES (\("Arthur"));
    ///     INSERT INTO player (name) VALUES (\("Barbara"));
    ///     INSERT INTO player (name) VALUES (\("O'Brien"));
    ///     """)
    /// while let statement = try statements.next() {
    ///     try statement.execute()
    /// }
    /// ```
    ///
    /// In the provided literal, no argument must be set, or all arguments must
    /// be set. The returned cursor will throw an error otherwise. For example:
    ///
    /// ```swift
    /// // OK
    /// try allStatements(literal: """
    ///     SELECT COUNT(*) FROM player WHERE score < ?;
    ///     SELECT COUNT(*) FROM player WHERE score > ?;
    ///     """)
    ///
    /// try allStatements(literal: """
    ///     SELECT COUNT(*) FROM player WHERE score < \(1000);
    ///     SELECT COUNT(*) FROM player WHERE score > \(1000);
    ///     """)
    ///
    /// // NOT OK (first argument is set, but second is not)
    /// try allStatements(literal: """
    ///     SELECT COUNT(*) FROM player WHERE score < \(1000);
    ///     SELECT COUNT(*) FROM player WHERE score > ?;
    ///     """)
    /// ```
    ///
    /// - parameter sqlLiteral: An ``SQL`` literal.
    /// - returns: A cursor of prepared ``Statement``.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func allStatements(literal sqlLiteral: SQL) throws -> SQLStatementCursor {
        let context = SQLGenerationContext(self)
        let sql = try sqlLiteral.sql(context)
        let arguments = context.arguments.isEmpty
            ? nil               // builds statements without arguments
            : context.arguments // force arguments to match
        return SQLStatementCursor(database: self, sql: sql, arguments: arguments)
    }
    
    /// Executes one or several SQL statements.
    ///
    /// For example:
    ///
    /// ```swift
    /// try db.execute(
    ///     sql: "INSERT INTO player (name) VALUES (:name)",
    ///     arguments: ["name": "Arthur"])
    ///
    /// try db.execute(sql: """
    ///     INSERT INTO player (name) VALUES (?);
    ///     INSERT INTO player (name) VALUES (?);
    ///     INSERT INTO player (name) VALUES (?);
    ///     """, arguments: ["Arthur", "Barbara", "O'Brien"])
    /// ```
    ///
    /// - parameters:
    ///     - sql: An SQL string.
    ///     - arguments: Statement arguments.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func execute(sql: String, arguments: StatementArguments = StatementArguments()) throws {
        try execute(literal: SQL(sql: sql, arguments: arguments))
    }
    
    /// Executes one or several SQL statements.
    ///
    /// ``SQL`` literals allow you to safely embed raw values in your SQL,
    /// without any risk of syntax errors or SQL injection:
    ///
    /// ```swift
    /// try db.execute(literal: """
    ///     INSERT INTO player (name) VALUES (\("Arthur"))
    ///     """)
    ///
    /// try db.execute(literal: """
    ///     INSERT INTO player (name) VALUES (\("Arthur"));
    ///     INSERT INTO player (name) VALUES (\("Barbara"));
    ///     INSERT INTO player (name) VALUES (\("O'Brien"));
    ///     """)
    /// ```
    ///
    /// - parameter sqlLiteral: An ``SQL`` literal.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func execute(literal sqlLiteral: SQL) throws {
        let statements = try allStatements(literal: sqlLiteral)
        while let statement = try statements.next() {
            try statement.execute()
        }
    }
}

/// A cursor over all statements in an SQL string.
public class SQLStatementCursor {
    private let database: Database
    private let cString: ContiguousArray<CChar>
    private let prepFlags: CUnsignedInt
    private let initialArgumentCount: Int?
    
    // Mutated by iteration
    private var offset: Int // offset in the C string
    private var arguments: StatementArguments? // Nil when arguments are set later
    
    init(database: Database, sql: String, arguments: StatementArguments?, prepFlags: CUnsignedInt = 0) {
        self.database = database
        self.cString = sql.utf8CString
        self.prepFlags = prepFlags
        self.initialArgumentCount = arguments?.values.count
        self.offset = 0
        self.arguments = arguments
    }
}

extension SQLStatementCursor: Cursor {
    public func next() throws -> Statement? {
        guard offset < cString.count - 1 /* trailing \0 */ else {
            // End of C string -> end of cursor.
            try checkArgumentsAreEmpty()
            return nil
        }
        
        return try cString.withUnsafeBufferPointer { buffer in
            let baseAddress = buffer.baseAddress! // never nil because the buffer contains the trailing \0.
            
            // Compile next statement
            var statementEnd: UnsafePointer<Int8>? = nil
            let statement = try Statement(
                database: database,
                statementStart: baseAddress + offset,
                statementEnd: &statementEnd,
                prepFlags: prepFlags)
            
            // Advance to next statement
            offset = statementEnd! - baseAddress // never nil because statement compilation did not fail.
            
            guard let statement else {
                // No statement found -> end of cursor.
                try checkArgumentsAreEmpty()
                return nil
            }
            
            if arguments != nil {
                // Extract statement arguments
                let bindings = try arguments!.extractBindings(
                    forStatement: statement,
                    allowingRemainingValues: true)
                // unchecked is OK because we just extracted the correct
                // number of arguments
                statement.setUncheckedArguments(StatementArguments(bindings))
            }
            
            return statement
        }
    }
    
    /// Check that all arguments were consumed: it is a programmer error to
    /// provide arguments that do not match the statements.
    private func checkArgumentsAreEmpty() throws {
        if let arguments,
           let initialArgumentCount,
           arguments.values.isEmpty == false
        {
            throw DatabaseError(
                resultCode: .SQLITE_MISUSE,
                message: "wrong number of statement arguments: \(initialArgumentCount)")
        }
    }
}

extension Database {
    /// Makes sure statement can be executed, and prepares database observation.
    @usableFromInline
    func statementWillExecute(_ statement: Statement) throws {
        // Aborted transactions prevent statement execution (see the
        // documentation of this method for more information).
        try checkForAbortedTransaction(sql: statement.sql, arguments: statement.arguments)
        
        // Suspended databases must not execute statements that create the risk
        // of `0xdead10cc` exception (see the documentation of this method for
        // more information).
        try checkForSuspensionViolation(from: statement)
        
        // Record the database region selected by the statement execution.
        try registerAccess(to: statement.databaseRegion)
        
        // Database observation: prepare transaction observers.
        observationBroker?.statementWillExecute(statement)
    }
    
    /// May throw a cancelled commit error, if a transaction observer cancels
    /// an empty transaction.
    @usableFromInline
    func statementDidExecute(_ statement: Statement) throws {
        if statement.invalidatesDatabaseSchemaCache {
            clearSchemaCache()
        }
        
        checkForAutocommitTransition()
        
        // Database observation: cleanup
        try observationBroker?.statementDidExecute(statement)
    }
    
    /// Always throws an error
    @usableFromInline
    func statementDidFail(_ statement: Statement, withResultCode resultCode: CInt) throws -> Never {
        // Failed statements can not be reused, because `sqlite3_reset` won't
        // be able to restore the statement to its initial state:
        // https://www.sqlite.org/c3ref/reset.html
        //
        // So make sure we clear this statement from the cache.
        internalStatementCache.remove(statement)
        publicStatementCache.remove(statement)
        
        checkForAutocommitTransition()
        
        // Extract values that may be modified by the user in their
        // `TransactionObserver.databaseDidRollback(_:)` implementation
        // (see below).
        let message = lastErrorMessage
        let arguments = statement.arguments
        
        // Database observation: cleanup.
        //
        // If the statement failure is due to a transaction observer that has
        // cancelled a transaction, this calls `TransactionObserver.databaseDidRollback(_:)`,
        // and throws the user-provided cancelled commit error.
        try observationBroker?.statementDidFail(statement)
        
        // Throw statement failure
        throw DatabaseError(
            resultCode: resultCode,
            message: message,
            sql: statement.sql,
            arguments: arguments,
            publicStatementArguments: configuration.publicStatementArguments)
    }
    
    private func checkForAutocommitTransition() {
        if sqlite3_get_autocommit(sqliteConnection) == 0 {
            if autocommitState == .on {
                // Record transaction date as soon as the connection leaves
                // auto-commit mode.
                // We grab a result, so that this failure is later reported
                // whenever the user calls `Database.transactionDate`.
                transactionDateResult = Result { try configuration.transactionClock.now(self) }
            }
            autocommitState = .off
        } else {
            if autocommitState == .off {
                // Reset transaction date
                transactionDateResult = nil
            }
            autocommitState = .on
        }
    }
}

/// A thread-unsafe statement cache
struct StatementCache {
    unowned let db: Database
    private var statements: [String: Statement] = [:]
    
    init(database: Database) {
        self.db = database
    }
    
    mutating func statement(_ sql: String) throws -> Statement {
        if let statement = statements[sql] {
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
        let statement = try db.makeStatement(sql: sql, prepFlags: CUnsignedInt(SQLITE_PREPARE_PERSISTENT))
        #else
        let statement: Statement
        if #available(iOS 12, macOS 10.14, watchOS 5, *) { // SQLite 3.20+
            statement = try db.makeStatement(sql: sql, prepFlags: CUnsignedInt(SQLITE_PREPARE_PERSISTENT))
        } else {
            statement = try db.makeStatement(sql: sql)
        }
        #endif
        statements[sql] = statement
        return statement
    }
    
    mutating func clear() {
        statements = [:]
    }
    
    mutating func remove(_ statement: Statement) {
        statements.removeFirst { $0.value === statement }
    }
    
    mutating func removeAll(where shouldBeRemoved: (Statement) -> Bool) {
        statements = statements.filter { (_, statement) in !shouldBeRemoved(statement) }
    }
}

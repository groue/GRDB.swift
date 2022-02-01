import Foundation

extension Database {
    
    // MARK: - Statements
    
    /// Returns a new prepared statement that can be reused.
    ///
    ///     let statement = try db.makeStatement(sql: "SELECT * FROM player WHERE id = ?")
    ///     let player1 = try Player.fetchOne(statement, arguments: [1])!
    ///     let player2 = try Player.fetchOne(statement, arguments: [2])!
    ///
    ///     let statement = try db.makeStatement(sql: "INSERT INTO player (name) VALUES (?)")
    ///     try statement.execute(arguments: ["Arthur"])
    ///     try statement.execute(arguments: ["Barbara"])
    ///
    /// - parameter sql: An SQL query.
    /// - returns: A Statement.
    /// - throws: A DatabaseError whenever SQLite could not parse the sql query.
    public func makeStatement(sql: String) throws -> Statement {
        try makeStatement(sql: sql, prepFlags: 0)
    }
    
    /// Returns a new prepared statement that can be reused.
    ///
    ///     let statement = try db.makeStatement(literal: "SELECT * FROM player WHERE id = ?")
    ///     let player1 = try Player.fetchOne(statement, arguments: [1])!
    ///     let player2 = try Player.fetchOne(statement, arguments: [2])!
    ///
    ///     let statement = try db.makeStatement(literal: "INSERT INTO player (name) VALUES (?)")
    ///     try statement.execute(arguments: ["Arthur"])
    ///     try statement.execute(arguments: ["Barbara"])
    ///
    /// - parameter sqlLiteral: An `SQL` literal.
    /// - returns: A Statement.
    /// - throws: A DatabaseError whenever SQLite could not parse the sql query.
    /// - precondition: No argument must be set, or all arguments must be set.
    ///   An error is raised otherwise.
    ///
    ///         // OK
    ///         try makeStatement(literal: """
    ///             SELECT COUNT(*) FROM player WHERE score > ?
    ///             """)
    ///         try makeStatement(literal: """
    ///             SELECT COUNT(*) FROM player WHERE score > \(1000)
    ///             """)
    ///
    ///         // NOT OK
    ///         try makeStatement(literal: """
    ///             SELECT COUNT(*) FROM player
    ///             WHERE color = ? AND score > \(1000)
    ///             """)
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
    ///     let statement = try db.makeSelectStatement(sql: "SELECT * FROM player WHERE id = ?")
    ///     let player1 = try Player.fetchOne(statement, arguments: [1])!
    ///     let player2 = try Player.fetchOne(statement, arguments: [2])!
    ///
    /// - parameter sql: An SQL query.
    /// - returns: A Statement.
    /// - throws: A DatabaseError whenever SQLite could not parse the sql query.
    @available(*, deprecated, renamed: "makeStatement(sql:)")
    public func makeSelectStatement(sql: String) throws -> Statement {
        try makeStatement(sql: sql)
    }
    
    /// Returns a new prepared statement that can be reused.
    ///
    /// - parameter sqlLiteral: An `SQL` literal.
    /// - returns: A Statement.
    /// - throws: A DatabaseError whenever SQLite could not parse the sql query.
    /// - precondition: No argument must be set, or all arguments must be set.
    ///   An error is raised otherwise.
    ///
    ///         // OK
    ///         try makeSelectStatement(literal: """
    ///             SELECT COUNT(*) FROM player WHERE score > ?
    ///             """)
    ///         try makeSelectStatement(literal: """
    ///             SELECT COUNT(*) FROM player WHERE score > \(1000)
    ///             """)
    ///
    ///         // NOT OK
    ///         try makeSelectStatement(literal: """
    ///             SELECT COUNT(*) FROM player
    ///             WHERE color = ? AND score > \(1000)
    ///             """)
    @available(*, deprecated, renamed: "makeStatement(literal:)")
    public func makeSelectStatement(literal sqlLiteral: SQL) throws -> Statement {
        try makeStatement(literal: sqlLiteral)
    }
    
    /// Returns a new prepared statement that can be reused.
    ///
    ///     let statement = try db.makeStatement(sql: "SELECT COUNT(*) FROM player WHERE score > ?", prepFlags: 0)
    ///     let moreThanTwentyCount = try Int.fetchOne(statement, arguments: [20])!
    ///     let moreThanThirtyCount = try Int.fetchOne(statement, arguments: [30])!
    ///
    /// - parameter sql: An SQL query.
    /// - parameter prepFlags: Flags for sqlite3_prepare_v3 (available from
    ///   SQLite 3.20.0, see <http://www.sqlite.org/c3ref/prepare.html>)
    /// - returns: A Statement.
    /// - throws: A DatabaseError whenever SQLite could not parse the sql query.
    func makeStatement(sql: String, prepFlags: Int32) throws -> Statement {
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
    ///     let statement = try db.cachedStatement(sql: "SELECT * FROM player WHERE id = ?")
    ///     let player1 = try Player.fetchOne(statement, arguments: [1])!
    ///     let player2 = try Player.fetchOne(statement, arguments: [2])!
    ///
    ///     let statement = try db.cachedStatement(sql: "INSERT INTO player (name) VALUES (?)")
    ///     try statement.execute(arguments: ["Arthur"])
    ///     try statement.execute(arguments: ["Barbara"])
    ///
    /// The returned statement may have already been used: it may or may not
    /// contain values for its eventual arguments.
    ///
    /// - parameter sql: An SQL query.
    /// - returns: A Statement.
    /// - throws: A DatabaseError whenever SQLite could not parse the sql query.
    public func cachedStatement(sql: String) throws -> Statement {
        try publicStatementCache.statement(sql)
    }
    
    /// Returns a prepared statement that can be reused.
    ///
    ///     let statement = try db.cachedStatement(literal: "SELECT * FROM player WHERE id = ?")
    ///     let player1 = try Player.fetchOne(statement, arguments: [1])!
    ///     let player2 = try Player.fetchOne(statement, arguments: [2])!
    ///
    ///     let statement = try db.cachedStatement(literal: "INSERT INTO player (name) VALUES (?)")
    ///     try statement.execute(arguments: ["Arthur"])
    ///     try statement.execute(arguments: ["Barbara"])
    ///
    /// - parameter sqlLiteral: An `SQL` literal.
    /// - returns: A Statement.
    /// - throws: A DatabaseError whenever SQLite could not parse the sql query.
    /// - precondition: No argument must be set, or all arguments must be set.
    ///   An error is raised otherwise.
    ///
    ///         // OK
    ///         try cachedStatement(literal: """
    ///             SELECT COUNT(*) FROM player WHERE score > ?
    ///             """)
    ///         try cachedStatement(literal: """
    ///             SELECT COUNT(*) FROM player WHERE score > \(1000)
    ///             """)
    ///
    ///         // NOT OK
    ///         try cachedStatement(literal: """
    ///             SELECT COUNT(*) FROM player
    ///             WHERE color = ? AND score > \(1000)
    ///             """)
    public func cachedStatement(literal sqlLiteral: SQL) throws -> Statement {
        let (sql, arguments) = try sqlLiteral.build(self)
        let statement = try cachedStatement(sql: sql)
        if arguments.isEmpty == false {
            // Throws if arguments do not match
            try statement.setArguments(arguments)
        }
        return statement
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
    /// - returns: A Statement.
    /// - throws: A DatabaseError whenever SQLite could not parse the sql query.
    @available(*, deprecated, renamed: "cachedStatement(sql:)")
    public func cachedSelectStatement(sql: String) throws -> Statement {
        try cachedStatement(sql: sql)
    }
    
    /// Returns a prepared statement that can be reused.
    ///
    ///     let statement = try db.cachedSelectStatement(literal: "SELECT COUNT(*) FROM player WHERE score > \(20)")
    ///     let moreThanTwentyCount = try Int.fetchOne(statement)!
    ///
    /// - parameter sqlLiteral: An `SQL` literal.
    /// - returns: A Statement.
    /// - throws: A DatabaseError whenever SQLite could not parse the sql query.
    /// - precondition: No argument must be set, or all arguments must be set.
    ///   An error is raised otherwise.
    ///
    ///         // OK
    ///         try cachedSelectStatement(literal: """
    ///             SELECT COUNT(*) FROM player WHERE score > ?
    ///             """)
    ///         try cachedSelectStatement(literal: """
    ///             SELECT COUNT(*) FROM player WHERE score > \(1000)
    ///             """)
    ///
    ///         // NOT OK
    ///         try cachedSelectStatement(literal: """
    ///             SELECT COUNT(*) FROM player
    ///             WHERE color = ? AND score > \(1000)
    ///             """)
    @available(*, deprecated, renamed: "cachedStatement(literal:)")
    public func cachedSelectStatement(literal sqlLiteral: SQL) throws -> Statement {
        try cachedStatement(literal: sqlLiteral)
    }
    
    /// Returns a cached statement that does not conflict with user's cached statements.
    func internalCachedStatement(sql: String) throws -> Statement {
        try internalStatementCache.statement(sql)
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
    @available(*, deprecated, renamed: "makeStatement(sql:)")
    public func makeUpdateStatement(sql: String) throws -> Statement {
        try makeStatement(sql: sql)
    }
    
    /// Returns a new prepared statement that can be reused.
    ///
    /// - parameter sqlLiteral: An `SQL` literal.
    /// - returns: A Statement.
    /// - throws: A DatabaseError whenever SQLite could not parse the sql query.
    /// - precondition: No argument must be set, or all arguments must be set.
    ///   An error is raised otherwise.
    ///
    ///         // OK
    ///         try makeUpdateStatement(literal: """
    ///             UPDATE player SET name = ?
    ///             """)
    ///         try makeUpdateStatement(literal: """
    ///             UPDATE player SET name = \("O'Brien")
    ///             """)
    ///
    ///         // NOT OK
    ///         try makeUpdateStatement(literal: """
    ///             UPDATE player SET name = ?, score = \(10)
    ///             """)
    @available(*, deprecated, renamed: "makeStatement(literal:)")
    public func makeUpdateStatement(literal sqlLiteral: SQL) throws -> Statement {
        try makeStatement(literal: sqlLiteral)
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
    /// - returns: A Statement.
    /// - throws: A DatabaseError whenever SQLite could not parse the sql query.
    @available(*, deprecated, renamed: "cachedStatement(sql:)")
    public func cachedUpdateStatement(sql: String) throws -> Statement {
        try cachedStatement(sql: sql)
    }
    
    /// Returns a new prepared statement that can be reused.
    ///
    /// - parameter sqlLiteral: An `SQL` literal.
    /// - returns: A Statement.
    /// - throws: A DatabaseError whenever SQLite could not parse the sql query.
    /// - precondition: No argument must be set, or all arguments must be set.
    ///   An error is raised otherwise.
    ///
    ///         // OK
    ///         try cachedUpdateStatement(literal: """
    ///             UPDATE player SET name = ?
    ///             """)
    ///         try cachedUpdateStatement(literal: """
    ///             UPDATE player SET name = \("O'Brien")
    ///             """)
    ///
    ///         // NOT OK
    ///         try cachedUpdateStatement(literal: """
    ///             UPDATE player SET name = ?, score = \(10)
    ///             """)
    @available(*, deprecated, renamed: "cachedStatement(sql:)")
    public func cachedUpdateStatement(literal sqlLiteral: SQL) throws -> Statement {
        try cachedStatement(literal: sqlLiteral)
    }
    
    /// Returns a cursor of all SQL statements separated by semi-colons.
    ///
    ///     let statements = try db.allStatements(sql: """
    ///         INSERT INTO player (name) VALUES (?);
    ///         INSERT INTO player (name) VALUES (?);
    ///         INSERT INTO player (name) VALUES (?);
    ///         """, arguments: ["Arthur", "Barbara", "O'Brien"])
    ///     while let statement = try statements.next() {
    ///         try statement.execute()
    ///     }
    ///
    /// - parameters:
    ///     - sql: An SQL query.
    ///     - arguments: Statement arguments.
    /// - returns: A cursor of `Statement`
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    /// - precondition: Arguments must be nil, or all arguments must be set.
    ///   The returned cursor will throw an error otherwise.
    ///
    ///         // OK
    ///         try allStatements(sql: """
    ///             SELECT COUNT(*) FROM player WHERE score < ?;
    ///             SELECT COUNT(*) FROM player WHERE score > ?;
    ///             """)
    ///         try allStatements(sql: """
    ///             SELECT COUNT(*) FROM player WHERE score < ?;
    ///             SELECT COUNT(*) FROM player WHERE score > ?;
    ///             """, arguments: [1000, 1000])
    ///
    ///         // NOT OK
    ///         try allStatements(sql: """
    ///             SELECT COUNT(*) FROM player WHERE score < ?;
    ///             SELECT COUNT(*) FROM player WHERE score > ?;
    ///             """, arguments: [1000])
    public func allStatements(sql: String, arguments: StatementArguments? = nil)
    throws -> SQLStatementCursor
    {
        SQLStatementCursor(database: self, sql: sql, arguments: arguments)
    }

    /// Returns a cursor of all SQL statements separated by semi-colons.
    ///
    /// Literals allow you to safely embed raw values in your SQL, without any
    /// risk of syntax errors or SQL injection:
    ///
    ///     let statements = try db.allStatements(literal: """
    ///         INSERT INTO player (name) VALUES (\("Arthur"));
    ///         INSERT INTO player (name) VALUES (\("Barbara"));
    ///         INSERT INTO player (name) VALUES (\("O'Brien"));
    ///         """)
    ///     while let statement = try statements.next() {
    ///         try statement.execute()
    ///     }
    ///
    /// - parameter sqlLiteral: An `SQL` literal.
    /// - returns: A cursor of `Statement`
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    /// - precondition: No argument must be set, or all arguments must be set.
    ///   The returned cursor will throw an error otherwise.
    ///
    ///         // OK
    ///         try allStatements(literal: """
    ///             SELECT COUNT(*) FROM player WHERE score < ?;
    ///             SELECT COUNT(*) FROM player WHERE score > ?;
    ///             """)
    ///         try allStatements(literal: """
    ///             SELECT COUNT(*) FROM player WHERE score < \(1000);
    ///             SELECT COUNT(*) FROM player WHERE score > \(1000);
    ///             """)
    ///
    ///         // NOT OK
    ///         try allStatements(literal: """
    ///             SELECT COUNT(*) FROM player WHERE score < \(1000);
    ///             SELECT COUNT(*) FROM player WHERE score > ?;
    ///             """)
    public func allStatements(literal sqlLiteral: SQL) throws -> SQLStatementCursor {
        let context = SQLGenerationContext(self)
        let sql = try sqlLiteral.sql(context)
        let arguments = context.arguments.isEmpty
            ? nil               // builds statements without arguments
            : context.arguments // force arguments to match
        return SQLStatementCursor(database: self, sql: sql, arguments: arguments)
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
        try execute(literal: SQL(sql: sql, arguments: arguments))
    }
    
    /// Executes one or several SQL statements, separated by semi-colons.
    ///
    /// Literals allow you to safely embed raw values in your SQL, without any
    /// risk of syntax errors or SQL injection:
    ///
    ///     try db.execute(literal: """
    ///         INSERT INTO player (name) VALUES (\("Arthur"))
    ///         """)
    ///
    ///     try db.execute(literal: """
    ///         INSERT INTO player (name) VALUES (\("Arthur"));
    ///         INSERT INTO player (name) VALUES (\("Barbara"));
    ///         INSERT INTO player (name) VALUES (\("O'Brien"));
    ///         """)
    ///
    /// This method may throw a DatabaseError.
    ///
    /// - parameter sqlLiteral: An `SQL` literal.
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    public func execute(literal sqlLiteral: SQL) throws {
        let statements = try allStatements(literal: sqlLiteral)
        while let statement = try statements.next() {
            try statement.execute()
        }
    }
}

public class SQLStatementCursor: Cursor {
    private let database: Database
    private let cString: ContiguousArray<CChar>
    private let prepFlags: CInt
    private let initialArgumentCount: Int?
    
    // Mutated by iteration
    private var offset: Int // offset in the C string
    private var arguments: StatementArguments? // Nil when arguments are set later
    
    init(database: Database, sql: String, arguments: StatementArguments?, prepFlags: CInt = 0) {
        self.database = database
        self.cString = sql.utf8CString
        self.prepFlags = prepFlags
        self.initialArgumentCount = arguments?.values.count
        self.offset = 0
        self.arguments = arguments
    }
    
    public func next() throws -> Statement? {
        guard offset < cString.count - 1 /* trailing \0 */ else {
            try checkArgumentsAreEmpty()
            return nil
        }
        
        return try cString.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else {
                // Should never happen since buffer contains at least
                // the trailing \0
                return nil
            }
            
            var statementEnd: UnsafePointer<Int8>? = nil
            let compiledStatement = try Statement(
                database: database,
                statementStart: baseAddress + offset,
                statementEnd: &statementEnd,
                prepFlags: prepFlags)
            
            offset = statementEnd! - baseAddress
            
            guard let statement = compiledStatement else {
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
        if let arguments = arguments,
           let initialArgumentCount = initialArgumentCount,
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
        // Two things must prevent the statement from executing: aborted
        // transactions, and database suspension.
        try checkForAbortedTransaction(sql: statement.sql, arguments: statement.arguments)
        try checkForSuspensionViolation(from: statement)
        
        // Database observation: record what the statement is looking at.
        if isRecordingSelectedRegion {
            selectedRegion.formUnion(statement.databaseRegion)
        }
        
        // Database observation: prepare transaction observers.
        observationBroker.statementWillExecute(statement)
    }
    
    /// May throw a cancelled commit error, if a transaction observer cancels
    /// an empty transaction.
    @usableFromInline
    func statementDidExecute(_ statement: Statement) throws {
        if statement.invalidatesDatabaseSchemaCache {
            clearSchemaCache()
        }
        
        try observationBroker.statementDidExecute(statement)
    }
    
    /// Always throws an error
    @usableFromInline
    func statementDidFail(_ statement: Statement, withResultCode resultCode: Int32) throws -> Never {
        // Failed statements can not be reused, because sqlite3_reset won't
        // be able to restore the statement to its initial state:
        // https://www.sqlite.org/c3ref/reset.html
        //
        // So make sure we clear this statement from the cache.
        internalStatementCache.remove(statement)
        publicStatementCache.remove(statement)
        
        /// Exposes the user-provided cancelled commit error, if a transaction
        /// observer has cancelled a transaction.
        try observationBroker.statementDidFail(statement)
        
        throw DatabaseError(
            resultCode: resultCode,
            message: lastErrorMessage,
            sql: statement.sql,
            arguments: statement.arguments,
            publicStatementArguments: configuration.publicStatementArguments)
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
        let statement = try db.makeStatement(sql: sql, prepFlags: SQLITE_PREPARE_PERSISTENT)
        #else
        let statement: Statement
        if #available(iOS 12.0, OSX 10.14, watchOS 5.0, *) {
            // SQLite 3.24.0 or more
            statement = try db.makeStatement(sql: sql, prepFlags: SQLITE_PREPARE_PERSISTENT)
        } else {
            // SQLite 3.19.3 or less
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

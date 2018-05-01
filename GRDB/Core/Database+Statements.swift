import Foundation

extension Database {
    
    // MARK: - Statements
    
    /// Returns a new prepared statement that can be reused.
    ///
    ///     let statement = try db.makeSelectStatement("SELECT COUNT(*) FROM player WHERE score > ?")
    ///     let moreThanTwentyCount = try Int.fetchOne(statement, arguments: [20])!
    ///     let moreThanThirtyCount = try Int.fetchOne(statement, arguments: [30])!
    ///
    /// - parameter sql: An SQL query.
    /// - returns: A SelectStatement.
    /// - throws: A DatabaseError whenever SQLite could not parse the sql query.
    public func makeSelectStatement(_ sql: String) throws -> SelectStatement {
        return try makeSelectStatement(sql, prepFlags: 0)
    }
    
    /// Returns a new prepared statement that can be reused.
    ///
    ///     let statement = try db.makeSelectStatement("SELECT COUNT(*) FROM player WHERE score > ?", prepFlags: 0)
    ///     let moreThanTwentyCount = try Int.fetchOne(statement, arguments: [20])!
    ///     let moreThanThirtyCount = try Int.fetchOne(statement, arguments: [30])!
    ///
    /// - parameter sql: An SQL query.
    /// - parameter prepFlags: Flags for sqlite3_prepare_v3 (available from
    ///   SQLite 3.20.0, see http://www.sqlite.org/c3ref/prepare.html)
    /// - returns: A SelectStatement.
    /// - throws: A DatabaseError whenever SQLite could not parse the sql query.
    func makeSelectStatement(_ sql: String, prepFlags: Int32) throws -> SelectStatement {
        return try SelectStatement.prepare(sql: sql, prepFlags: prepFlags, in: self)
    }
    
    /// Returns a prepared statement that can be reused.
    ///
    ///     let statement = try db.cachedSelectStatement("SELECT COUNT(*) FROM player WHERE score > ?")
    ///     let moreThanTwentyCount = try Int.fetchOne(statement, arguments: [20])!
    ///     let moreThanThirtyCount = try Int.fetchOne(statement, arguments: [30])!
    ///
    /// The returned statement may have already been used: it may or may not
    /// contain values for its eventual arguments.
    ///
    /// - parameter sql: An SQL query.
    /// - returns: An UpdateStatement.
    /// - throws: A DatabaseError whenever SQLite could not parse the sql query.
    public func cachedSelectStatement(_ sql: String) throws -> SelectStatement {
        return try publicStatementCache.selectStatement(sql)
    }
    
    /// Returns a cached statement that does not conflict with user's cached statements.
    func internalCachedSelectStatement(_ sql: String) throws -> SelectStatement {
        return try internalStatementCache.selectStatement(sql)
    }
    
    /// Returns a new prepared statement that can be reused.
    ///
    ///     let statement = try db.makeUpdateStatement("INSERT INTO player (name) VALUES (?)")
    ///     try statement.execute(arguments: ["Arthur"])
    ///     try statement.execute(arguments: ["Barbara"])
    ///
    /// - parameter sql: An SQL query.
    /// - returns: An UpdateStatement.
    /// - throws: A DatabaseError whenever SQLite could not parse the sql query.
    public func makeUpdateStatement(_ sql: String) throws -> UpdateStatement {
        return try makeUpdateStatement(sql, prepFlags: 0)
    }
    
    /// Returns a new prepared statement that can be reused.
    ///
    ///     let statement = try db.makeUpdateStatement("INSERT INTO player (name) VALUES (?)", prepFlags: 0)
    ///     try statement.execute(arguments: ["Arthur"])
    ///     try statement.execute(arguments: ["Barbara"])
    ///
    /// - parameter sql: An SQL query.
    /// - parameter prepFlags: Flags for sqlite3_prepare_v3 (available from
    ///   SQLite 3.20.0, see http://www.sqlite.org/c3ref/prepare.html)
    /// - returns: An UpdateStatement.
    /// - throws: A DatabaseError whenever SQLite could not parse the sql query.
    func makeUpdateStatement(_ sql: String, prepFlags: Int32) throws -> UpdateStatement {
        return try UpdateStatement.prepare(sql: sql, prepFlags: prepFlags, in: self)
    }
    
    /// Returns a prepared statement that can be reused.
    ///
    ///     let statement = try db.cachedUpdateStatement("INSERT INTO player (name) VALUES (?)")
    ///     try statement.execute(arguments: ["Arthur"])
    ///     try statement.execute(arguments: ["Barbara"])
    ///
    /// The returned statement may have already been used: it may or may not
    /// contain values for its eventual arguments.
    ///
    /// - parameter sql: An SQL query.
    /// - returns: An UpdateStatement.
    /// - throws: A DatabaseError whenever SQLite could not parse the sql query.
    public func cachedUpdateStatement(_ sql: String) throws -> UpdateStatement {
        return try publicStatementCache.updateStatement(sql)
    }
    
    /// Returns a cached statement that does not conflict with user's cached statements.
    func internalCachedUpdateStatement(_ sql: String) throws -> UpdateStatement {
        return try internalStatementCache.updateStatement(sql)
    }
    
    /// Executes one or several SQL statements, separated by semi-colons.
    ///
    ///     try db.execute(
    ///         "INSERT INTO player (name) VALUES (:name)",
    ///         arguments: ["name": "Arthur"])
    ///
    ///     try db.execute("""
    ///         INSERT INTO player (name) VALUES (?);
    ///         INSERT INTO player (name) VALUES (?);
    ///         INSERT INTO player (name) VALUES (?);
    ///         """, arguments; ['Arthur', 'Barbara', 'Craig'])
    ///
    /// This method may throw a DatabaseError.
    ///
    /// - parameters:
    ///     - sql: An SQL query.
    ///     - arguments: Optional statement arguments.
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    public func execute(_ sql: String, arguments: StatementArguments? = nil) throws {
        // This method is like sqlite3_exec (https://www.sqlite.org/c3ref/exec.html)
        // It adds support for arguments, and the tricky part is to consume
        // arguments as statements are executed.
        //
        // Here we build two functions:
        // - consumeArguments returns arguments for a statement
        // - validateRemainingArguments validates the remaining arguments, after
        //   all statements have been executed, in the same way
        //   as Statement.validate(arguments:)
        
        var arguments = arguments ?? StatementArguments()
        let initialValuesCount = arguments.values.count
        let consumeArguments = { (statement: UpdateStatement) throws -> StatementArguments in
            let bindings = try arguments.consume(statement, allowingRemainingValues: true)
            return StatementArguments(bindings)
        }
        let validateRemainingArguments = {
            if !arguments.values.isEmpty {
                throw DatabaseError(resultCode: .SQLITE_MISUSE, message: "wrong number of statement arguments: \(initialValuesCount)")
            }
        }
        
        // Iterate SQL statements
        let sqlCodeUnits = sql.utf8CString
        try sqlCodeUnits.withUnsafeBufferPointer { codeUnits in
            let sqlStart = UnsafePointer<Int8>(codeUnits.baseAddress)!
            let sqlEnd = sqlStart + sqlCodeUnits.count
            var statementStart = sqlStart
            while statementStart < sqlEnd - 1 {
                var statementEnd: UnsafePointer<Int8>? = nil
                do {
                    let statement: UpdateStatement
                    // Compile
                    do {
                        let statementCompilationAuthorizer = StatementCompilationAuthorizer()
                        authorizer = statementCompilationAuthorizer
                        defer { authorizer = nil }
                        
                        statement = try UpdateStatement(
                            database: self,
                            statementStart: statementStart,
                            statementEnd: &statementEnd,
                            prepFlags: 0,
                            authorizer: statementCompilationAuthorizer)
                    }
                    
                    // Execute
                    let arguments = try consumeArguments(statement)
                    statement.unsafeSetArguments(arguments)
                    try statement.execute()
                    
                    // Next
                    statementStart = statementEnd!
                } catch is EmptyStatementError {
                    // End
                    break
                }
            }
        }
        
        // Force arguments validity: it is a programmer error to provide
        // arguments that do not match the statement.
        try! validateRemainingArguments()   // throws if there are remaining arguments.
    }
}

extension Database {

    func updateStatementWillExecute(_ statement: UpdateStatement) {
        observationBroker.updateStatementWillExecute(statement)
    }
    
    func updateStatementDidExecute(_ statement: UpdateStatement) throws {
        if statement.invalidatesDatabaseSchemaCache {
            clearSchemaCache()
        }
        
        try observationBroker.updateStatementDidExecute(statement)
    }
    
    func updateStatementDidFail(_ statement: UpdateStatement) throws {
        // Failed statements can not be reused, because sqlite3_reset won't
        // be able to restore the statement to its initial state:
        // https://www.sqlite.org/c3ref/reset.html
        //
        // So make sure we clear this statement from the cache.
        internalStatementCache.remove(statement)
        publicStatementCache.remove(statement)
        
        try observationBroker.updateStatementDidFail(statement)
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

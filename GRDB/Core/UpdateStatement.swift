/// A subclass of Statement that executes SQL queries.
///
/// You create UpdateStatement with the Database.updateStatement() method:
///
///     try dbQueue.inTransaction { db in
///         let statement = try db.updateStatement("INSERT INTO persons (name) VALUES (?)")
///         try statement.execute(arguments: ["Arthur"])
///         try statement.execute(arguments: ["Barbara"])
///         return .Commit
///     }
public final class UpdateStatement : Statement {
        
    /// Executes the SQL query.
    ///
    /// - parameter arguments: Statement arguments.
    /// - returns: A DatabaseChanges.
    /// - throws: A DatabaseError whenever a SQLite error occurs.
    public func execute(arguments arguments: StatementArguments = StatementArguments.Default) throws -> DatabaseChanges {
        if !arguments.isDefault {
            self.arguments = arguments
        }
        validateArguments()
        reset()
        
        let changes: DatabaseChanges
        let code = sqlite3_step(sqliteStatement)
        switch code {
        case SQLITE_DONE:
            let changedRowCount = Int(sqlite3_changes(database.sqliteConnection))
            let lastInsertedRowID = sqlite3_last_insert_rowid(database.sqliteConnection)
            let insertedRowID: Int64? = (lastInsertedRowID == 0) ? nil : lastInsertedRowID
            changes = DatabaseChanges(changedRowCount: changedRowCount, insertedRowID: insertedRowID)
        case SQLITE_ROW:
            // A row? The UpdateStatement is not supposed to return any...
            //
            // What are our options?
            //
            // 1. throw a DatabaseError with code SQLITE_ROW.
            // 2. raise a fatal error.
            // 3. log a warning about the ignored row, and return successfully.
            // 4. silently ignore the row, and return successfully.
            //
            // The problem with 1 is that this error is uneasy to understand.
            // See https://github.com/groue/GRDB.swift/issues/15 where both the
            // user and I were stupidly stuck in front of `PRAGMA journal_mode=WAL`.
            //
            // The problem with 2 is that the user would be forced to load a
            // value he does not care about (even if he should, but we can't
            // judge).
            //
            // The problem with 3 is that there is no way to avoid this warning.
            //
            // So let's just silently ignore the row, and return successfully.
            changes = DatabaseChanges(changedRowCount: 0, insertedRowID: nil)
        default:
            // This error may be a consequence of an error thrown by
            // TransactionObserverType.transactionWillCommit().
            // Let database handle this case, before throwing a error.
            try database.updateStatementDidFail()
            let errorArguments = self.arguments // self.arguments, not the arguments parameter.
            throw DatabaseError(code: code, message: database.lastErrorMessage, sql: sql, arguments: errorArguments)
        }
        
        // Now that changes information has been loaded, we can trigger database
        // transaction delegate callbacks that may eventually perform more
        // changes to the database.
        database.updateStatementDidExecute()
        
        return changes
    }
}

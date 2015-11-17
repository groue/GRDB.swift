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
        
        let code = sqlite3_step(sqliteStatement)
        guard code == SQLITE_DONE else {
            // This error may be a consequence of an error thrown by
            // TransactionObserverType.transactionWillCommit().
            // Let database handle this case, before throwing a error.
            try database.updateStatementDidFail()
            throw DatabaseError(code: code, message: database.lastErrorMessage, sql: sql, arguments: self.arguments)
        }
        
        let changedRowCount = Int(sqlite3_changes(database.sqliteConnection))
        let lastInsertedRowID = sqlite3_last_insert_rowid(database.sqliteConnection)
        let insertedRowID: Int64? = (lastInsertedRowID == 0) ? nil : lastInsertedRowID
        
        // Now that changes information has been loaded, we can trigger database
        // transaction delegate callbacks that may eventually perform more
        // changes to the database.
        database.updateStatementDidExecute()
        
        return DatabaseChanges(changedRowCount: changedRowCount, insertedRowID: insertedRowID)
    }
}

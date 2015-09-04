/**
A subclass of Statement that executes SQL queries.

You create UpdateStatement with the Database.updateStatement() method:

    try dbQueue.inTransaction { db in
        let statement = try db.updateStatement("INSERT INTO persons (name) VALUES (?)")
        try statement.execute(arguments: ["Arthur"])
        try statement.execute(arguments: ["Barbara"])
        return .Commit
    }
*/
public final class UpdateStatement : Statement {
        
    /**
    Executes the SQL query.
    
    - parameter arguments: Optional query arguments.
    - returns: A DatabaseChanges.
    - throws: A DatabaseError whenever a SQLite error occurs.
    */
    public func execute(arguments arguments: StatementArguments? = nil) throws -> DatabaseChanges {
        if let arguments = arguments {
            self.arguments = arguments
        }
        
        reset()
        
        if let trace = database.configuration.trace {
            trace(sql: sql, arguments: self.arguments)
        }
        
        let code = sqlite3_step(sqliteStatement)
        guard code == SQLITE_DONE else {
            throw DatabaseError(code: code, message: database.lastErrorMessage, sql: sql, arguments: self.arguments)
        }
        
        let changedRowCount = Int(sqlite3_changes(database.sqliteConnection))
        let lastInsertedRowID = sqlite3_last_insert_rowid(database.sqliteConnection)
        let insertedRowID: Int64? = (lastInsertedRowID == 0) ? nil : lastInsertedRowID
        return DatabaseChanges(changedRowCount: changedRowCount, insertedRowID: insertedRowID)
    }
}

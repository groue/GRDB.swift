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
    
    /// The changes performed by an UpdateStatement.
    public struct Changes {
        
        /// The number of rows changed by the statement.
        public let changedRowCount: Int
        
        /// The inserted Row ID. Relevant if and only if the statement is an
        /// INSERT statement.
        public let insertedRowID: Int64?
    }
    
    /**
    Executes the SQL query.
    
    - parameter arguments: Optional query arguments.
    - throws: A DatabaseError whenever a SQLite error occurs.
    */
    public func execute(arguments arguments: QueryArguments? = nil) throws -> Changes {
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
        return Changes(changedRowCount: changedRowCount, insertedRowID: insertedRowID)
    }
}

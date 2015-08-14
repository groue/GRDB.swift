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
A subclass of Statement that executes Multiple SQL statements in a single sqlite call.

You create MultipleStatement with the Database.multipleStatement() method:

    try dbQueue.inTransaction { db in
        let sql = "INSERT INTO persons (name) VALUES ('Harry');" +
            "INSERT INTO persons (name) VALUES ('Ron')" +
            "INSERT INTO persons (name) VALUES ('Hermione')"
        let statement = try db.multipleStatement(sql)
        return .Commit
    }
*/
public final class MultipleStatement : Statement {
    
    /// The changes performed by an MultipleStatement.
    public struct Changes {
        /// The number of rows changed by SQL executed.
        public let changedRowCount: Int
    }
    
    /**
    Executes the SQL query.
    
    - parameter arguments: Optional query arguments.
    - throws: A DatabaseError whenever a SQLite error occurs.
    */
    public func execute() throws -> Changes {
        reset()
        
        if let trace = database.configuration.trace {
            trace(sql: sql, arguments: nil)
        }
        
        let changedRowsBefore = sqlite3_total_changes(database.sqliteConnection)
        
        var errMsg:UnsafeMutablePointer<Int8> = nil
        let code = sqlite3_exec(database.sqliteConnection, sql, nil, nil, &errMsg)
        guard code == SQLITE_OK else {
            throw DatabaseError(code: code, message: database.lastErrorMessage, sql: sql, arguments: nil)
        }

        let changedRowsAfter = sqlite3_total_changes(database.sqliteConnection)

        return Changes(changedRowCount: changedRowsAfter - changedRowsBefore)
    }
    
}


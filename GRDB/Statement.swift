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



/// A nicer name than COpaquePointer for SQLite statement handle
typealias SQLiteStatement = COpaquePointer

private let SQLITE_TRANSIENT = unsafeBitCast(COpaquePointer(bitPattern: -1), sqlite3_destructor_type.self)

/**
A statement represents a SQL query.

It is the base class of UpdateStatement that executes *update statements*, and
SelectStatement that fetches rows.
*/
public class Statement {
    
    /// The SQL query
    public var sql: String
    
    /// The query arguments
    public var arguments: StatementArguments? {
        didSet {
            reset() // necessary before applying new arguments
            clearArguments()
            if let arguments = arguments {
                arguments.bindInStatement(self)
            }
        }
    }
    
    // MARK: - Not public
    
    /// The database
    let database: Database
    
    /// The SQLite statement handle
    let sqliteStatement: SQLiteStatement
    
    /// The identity of the DatabaseQueue where the statement was created.
    let databaseQueueID: DatabaseQueueID
    
    init(database: Database, sql: String) throws {
        // See https://www.sqlite.org/c3ref/prepare.html
        
        let sqlCodeUnits = sql.nulTerminatedUTF8
        var sqliteStatement: SQLiteStatement = nil
        var consumedCharactersCount: Int = 0
        var code: Int32 = 0
        sqlCodeUnits.withUnsafeBufferPointer { codeUnits in
            let sqlHead = UnsafePointer<Int8>(codeUnits.baseAddress)
            var sqlTail: UnsafePointer<Int8> = nil
            code = sqlite3_prepare_v2(database.sqliteConnection, sqlHead, -1, &sqliteStatement, &sqlTail)
            consumedCharactersCount = sqlTail - sqlHead + 1
        }
        
        self.database = database
        self.databaseQueueID = dispatch_get_specific(DatabaseQueue.databaseQueueIDKey)
        self.sql = sql
        self.sqliteStatement = sqliteStatement
        
        switch code {
        case SQLITE_OK:
            if consumedCharactersCount != sqlCodeUnits.count {
                fatalError("Invalid SQL string: multiple statements found. To execute multiple statements, use Database.executeMultiStatement() instead.")
            }
        default:
            throw DatabaseError(code: code, message: database.lastErrorMessage, sql: sql)
        }
    }
    
    deinit {
        if sqliteStatement != nil {
            sqlite3_finalize(sqliteStatement)
        }
    }
    
    // Exposed for StatementArguments. Don't make this one public unless we keep the arguments property in sync.
    final func bind(value: DatabaseValueConvertible?, atIndex index: Int) {
        let databaseValue = value?.databaseValue ?? .Null
        let code: Int32
        
        switch databaseValue {
        case .Null:
            code = sqlite3_bind_null(sqliteStatement, Int32(index))
        case .Integer(let int64):
            code = sqlite3_bind_int64(sqliteStatement, Int32(index), int64)
        case .Real(let double):
            code = sqlite3_bind_double(sqliteStatement, Int32(index), double)
        case .Text(let text):
            code = sqlite3_bind_text(sqliteStatement, Int32(index), text, -1, SQLITE_TRANSIENT)
        case .Blob(let blob):
            let data = blob.data
            code = sqlite3_bind_blob(sqliteStatement, Int32(index), data.bytes, Int32(data.length), SQLITE_TRANSIENT)
        }
        
        if code != SQLITE_OK {
            fatalDatabaseError(DatabaseError(code: code, message: database.lastErrorMessage, sql: sql))
        }
    }
    
    // Exposed for StatementArguments. Don't make this one public unless we keep the arguments property in sync.
    final func bind(value: DatabaseValueConvertible?, forKey key: String) {
        let index = Int(sqlite3_bind_parameter_index(sqliteStatement, ":\(key)"))
        guard index > 0 else {
            fatalError("Key not found in SQLite statement: `:\(key)`")
        }
        bind(value, atIndex: index)
    }
    
    // Not public until a need for it.
    final func reset() {
        let code = sqlite3_reset(sqliteStatement)
        if code != SQLITE_OK {
            fatalDatabaseError(DatabaseError(code: code, message: database.lastErrorMessage, sql: sql))
        }
    }
    
    // Don't make this one public or internal unless we keep the arguments property in sync.
    private func clearArguments() {
        let code = sqlite3_clear_bindings(sqliteStatement)
        if code != SQLITE_OK {
            fatalDatabaseError(DatabaseError(code: code, message: database.lastErrorMessage, sql: sql))
        }
    }
}

// MARK: - SQLite identifier quoting

extension String {
    /**
    Returns the receiver, quoted for safe insertion as an identifier in an SQL
    query.

        db.execute("SELECT * FROM \(tableName.quotedDatabaseIdentifier)")
    */
    public var quotedDatabaseIdentifier: String {
        // See https://www.sqlite.org/lang_keywords.html
        return "\"\(self)\""
    }
}

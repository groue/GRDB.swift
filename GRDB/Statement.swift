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


private let SQLITE_TRANSIENT = unsafeBitCast(COpaquePointer(bitPattern: -1), sqlite3_destructor_type.self)

public class Statement {
    let database: Database
    let sqliteStatement = SQLiteStatement()
    let databaseQueueID: DatabaseQueueID
    public lazy var sql: String = String.fromCString(UnsafePointer<Int8>(sqlite3_sql(self.sqliteStatement)))!
    public var bindings: Bindings? {
        didSet {
            reset() // necessary before applying new bindings
            clearBindings()
            if let bindings = bindings {
                bindings.bindInStatement(self)
            }
        }
    }
    
    init(database: Database, sql: String, bindings: Bindings?) throws {
        // See https://www.sqlite.org/c3ref/prepare.html
        self.database = database
        self.databaseQueueID = dispatch_get_specific(DatabaseQueue.databaseQueueIDKey)
        let code = sqlite3_prepare_v2(database.sqliteConnection, sql, -1, &sqliteStatement, nil)
        try SQLiteError.checkCResultCode(code, sqliteConnection: database.sqliteConnection, sql: sql)
        
        // Set bingins. Duplicate the didSet property observer since it is not
        // called during initialization.
        self.bindings = bindings
        if let bindings = bindings {
            bindings.bindInStatement(self)
        }
    }
    
    deinit {
        if sqliteStatement != nil {
            sqlite3_finalize(sqliteStatement)
        }
    }
    
    // Exposed for Bindings. Don't make this one public unless we keep the bindings property in sync.
    final func bind(value: SQLiteValueConvertible?, atIndex index: Int) {
        let sqliteValue = value?.sqliteValue ?? .Null
        let code: Int32
        
        switch sqliteValue {
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
            failOnError { () -> Void in
                throw SQLiteError(code: code, sqliteConnection: self.database.sqliteConnection, sql: self.sql)
            }
        }
    }
    
    // TODO: document that we only support the colon prefix (like FMDB).
    // Exposed for Bindings. Don't make this one public unless we keep the bindings property in sync.
    final func bind(value: SQLiteValueConvertible?, forKey key: String) {
        let index = Int(sqlite3_bind_parameter_index(sqliteStatement, ":\(key)"))
        guard index > 0 else {
            fatalError("Key not found in SQLite statement: `:\(key)`")
        }
        bind(value, atIndex: index)
    }
    
    // Not public until a need for it.
    // Today the only place where a statement is reset is in the bindings didSet observer.
    final func reset() {
        let code = sqlite3_reset(sqliteStatement)
        if code != SQLITE_OK {
            failOnError { () -> Void in
                throw SQLiteError(code: code, sqliteConnection: self.database.sqliteConnection, sql: self.sql)
            }
        }
    }
    
    // Don't make this one public or internal unless we keep the bindings property in sync.
    private func clearBindings() {
        let code = sqlite3_clear_bindings(sqliteStatement)
        if code != SQLITE_OK {
            failOnError { () -> Void in
                throw SQLiteError(code: code, sqliteConnection: self.database.sqliteConnection, sql: self.sql)
            }
        }
    }
}

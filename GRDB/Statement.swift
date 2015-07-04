//
//  Statement.swift
//  GRDB
//
//  Created by Gwendal Roué on 30/06/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

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
    final func bind(value: DatabaseValueType?, atIndex index: Int) {
        let code: Int32
        if let value = value {
            code = value.sqliteValue.bindInSQLiteStatement(sqliteStatement, atIndex: index)
        } else {
            code = sqlite3_bind_null(sqliteStatement, Int32(index))
        }
        if code != SQLITE_OK {
            failOnError { () -> Void in
                throw SQLiteError(code: code, sqliteConnection: self.database.sqliteConnection, sql: self.sql)
            }
        }
    }
    
    // TODO: document that we only support the colon prefix (like FMDB).
    // Exposed for Bindings. Don't make this one public unless we keep the bindings property in sync.
    final func bind(value: DatabaseValueType?, forKey key: String) {
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

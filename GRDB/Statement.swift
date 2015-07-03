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
    
    init(database: Database, sql: String, bindings: Bindings?) throws {
        // See https://www.sqlite.org/c3ref/prepare.html
        self.database = database
        self.databaseQueueID = dispatch_get_specific(DatabaseQueue.databaseQueueIDKey)
        let code = sqlite3_prepare_v2(database.sqliteConnection, sql, -1, &sqliteStatement, nil)
        try SQLiteError.checkCResultCode(code, sqliteConnection: database.sqliteConnection, sql: sql)
        bind(bindings)
    }
    
    deinit {
        if sqliteStatement != nil {
            sqlite3_finalize(sqliteStatement)
        }
    }
    
    public final func bind(value: DatabaseValue?, atIndex index: Int) {
        let code: Int32
        if let value = value {
            code = value.bindInSQLiteStatement(sqliteStatement, atIndex: index)
        } else {
            code = sqlite3_bind_null(sqliteStatement, Int32(index))
        }
        if code != SQLITE_OK {
            failOnError { () -> Void in
                throw SQLiteError(code: code, sqliteConnection: self.database.sqliteConnection, sql: self.sql)
            }
        }
    }
    
    public final func bind(value: DatabaseValue?, forKey key: String) {
        let index = Int(sqlite3_bind_parameter_index(sqliteStatement, key))
        guard index > 0 else {
            fatalError("Key not found: \(key)")
        }
        bind(value, atIndex: index)
    }
    
    public final func bind(bindings: Bindings?) {
        if let bindings = bindings {
            bindings.bindInStatement(self)
        }
    }

    public final func reset() {
        let code = sqlite3_reset(sqliteStatement)
        if code != SQLITE_OK {
            failOnError { () -> Void in
                throw SQLiteError(code: code, sqliteConnection: self.database.sqliteConnection, sql: self.sql)
            }
        }
    }
    
    public final func clearBindings() {
        let code = sqlite3_clear_bindings(sqliteStatement)
        if code != SQLITE_OK {
            failOnError { () -> Void in
                throw SQLiteError(code: code, sqliteConnection: self.database.sqliteConnection, sql: self.sql)
            }
        }
    }
}

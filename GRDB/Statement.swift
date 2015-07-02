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
    
    init(database: Database, sql: String) throws {
        // See https://www.sqlite.org/c3ref/prepare.html
        self.database = database
        self.databaseQueueID = dispatch_get_specific(DatabaseQueue.databaseQueueIDKey)
        let code = sqlite3_prepare_v2(database.sqliteConnection, sql, -1, &sqliteStatement, nil)
        try SQLiteError.checkCResultCode(code, sqliteConnection: database.sqliteConnection, sql: sql)
    }
    
    deinit {
        if sqliteStatement != nil {
            sqlite3_finalize(sqliteStatement)
        }
    }
    
    public func bind(value: DatabaseValue?, atIndex index: Int) {
        let code: Int32
        if let value = value {
            code = value.bindInSQLiteStatement(sqliteStatement, atIndex: index)
        } else {
            code = sqlite3_bind_null(sqliteStatement, Int32(index))
        }
        assert(code == SQLITE_OK)
    }
    
    public func bind(value: DatabaseValue?, forKey key: String) {
        let index = Int(sqlite3_bind_parameter_index(sqliteStatement, key))
        guard index > 0 else {
            fatalError("Key not found: \(key)")
        }
        bind(value, atIndex: index)
    }
    
    public func bind(dictionary: [String: DatabaseValue?]) {
        for (key, value) in dictionary {
            bind(value, forKey: key)
        }
    }
    
    public func bind(values: [DatabaseValue?]) {
        for (index, value) in values.enumerate() {
            bind(value, atIndex: index + 1)
        }
    }

    public func reset() throws {
        let code = sqlite3_reset(sqliteStatement)
        try SQLiteError.checkCResultCode(code, sqliteConnection: database.sqliteConnection, sql: sql)
    }
    
    public func clearBindings() {
        let code = sqlite3_clear_bindings(sqliteStatement)
        assert(code == SQLITE_OK)
    }
}

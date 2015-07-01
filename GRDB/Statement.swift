//
//  Statement.swift
//  GRDB
//
//  Created by Gwendal Roué on 30/06/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

typealias CStatement = COpaquePointer

public class Statement {
    let database: Database
    let cStatement = CStatement()
    
    public lazy var sql: String = String.fromCString(UnsafePointer<Int8>(sqlite3_sql(self.cStatement)))!
    
    init(database: Database, sql: String) throws {
        // See https://www.sqlite.org/c3ref/prepare.html
        self.database = database
        let code = sql.nulTerminatedUTF8.withUnsafeBufferPointer { codeUnits in
            sqlite3_prepare_v2(database.cConnection, UnsafePointer<Int8>(codeUnits.baseAddress), -1, &cStatement, nil)
        }
        try Error.checkCResultCode(code, cConnection: database.cConnection)
    }
    
    deinit {
        if cStatement != nil {
            sqlite3_finalize(cStatement)
        }
    }
    
    public func bind(value: DatabaseValue?, atIndex index: Int) {
        if let value = value {
            value.bindInStatement(self, atIndex: index)
        } else {
            let code = sqlite3_bind_null(cStatement, Int32(index))
            assert(code == SQLITE_OK)
        }
    }
    
    public func bind(value: DatabaseValue?, forKey key: String) {
        let index = Int(sqlite3_bind_parameter_index(cStatement, key))
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
        let code = sqlite3_reset(cStatement)
        try Error.checkCResultCode(code, cConnection: database.cConnection)
    }
    
    public func clearBindings() {
        let code = sqlite3_clear_bindings(cStatement)
        assert(code == SQLITE_OK)
    }
}

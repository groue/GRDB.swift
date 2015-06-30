//
//  Statement.swift
//  GRDB
//
//  Created by Gwendal Roué on 30/06/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

typealias CStatement = COpaquePointer

public class Statement {
    let cStatement = CStatement()
    let cConnection: CConnection
    
    init(cConnection: CConnection, query: String) throws {
        // See https://www.sqlite.org/c3ref/prepare.html
        self.cConnection = cConnection
        let code = query.nulTerminatedUTF8.withUnsafeBufferPointer { codeUnits in
            sqlite3_prepare_v2(cConnection, UnsafePointer<Int8>(codeUnits.baseAddress), -1, &cStatement, nil)
        }
        try Error.checkCResultCode(code, cConnection: cConnection)
    }
    
    deinit {
        if cStatement != nil {
            sqlite3_finalize(cStatement)
        }
    }
    
    public func bind(value: DBValue?, atIndex index: Int) {
        if let value = value {
            value.bindInStatement(self, atIndex: index)
        } else {
            let code = sqlite3_bind_null(cStatement, Int32(index))
            assert(code == SQLITE_OK)
        }
    }
    
    public func bind(value: DBValue?, forKey key: String) {
        let index = key.nulTerminatedUTF8.withUnsafeBufferPointer { codeUnits in
            Int(sqlite3_bind_parameter_index(cStatement, UnsafePointer<Int8>(codeUnits.baseAddress)))
        }
        guard index > 0 else {
            fatalError("Key not found: \(key)")
        }
        bind(value, atIndex: index)
    }
    
    public func bind(dictionary: [String: DBValue?]) {
        for (key, value) in dictionary {
            bind(value, forKey: key)
        }
    }
    
    public func bind(values: [DBValue?]) {
        for (index, value) in values.enumerate() {
            bind(value, atIndex: index + 1)
        }
    }

    public func reset() {
        let code = sqlite3_reset(cStatement)
        assert(code == SQLITE_OK)
    }
    
    public func clearBindings() {
        let code = sqlite3_clear_bindings(cStatement)
        assert(code == SQLITE_OK)
    }
}

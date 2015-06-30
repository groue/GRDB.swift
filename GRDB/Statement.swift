//
//  Statement.swift
//  GRDB
//
//  Created by Gwendal Roué on 30/06/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

typealias CStatement = COpaquePointer

internal let SQLITE_TRANSIENT = unsafeBitCast(COpaquePointer(bitPattern: -1), sqlite3_destructor_type.self)

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
    
    public lazy var columnCount: Int = Int(sqlite3_column_count(self.cStatement))
    public lazy var bindParameterCount: Int = Int(sqlite3_bind_parameter_count(self.cStatement))
    
    public func bind(value: DBValue, atIndex index: Int) {
        value.bindInStatement(self, atIndex: index)
    }
    
    public func bind(value: DBValue, forKey key: String) {
        let index = key.nulTerminatedUTF8.withUnsafeBufferPointer { codeUnits in
            Int(sqlite3_bind_parameter_index(cStatement, UnsafePointer<Int8>(codeUnits.baseAddress)))
        }
        guard index > 0 else {
            fatalError("Key not found: \(key)")
        }
        value.bindInStatement(self, atIndex: index)
    }

    public func reset() {
        let code = sqlite3_reset(cStatement)
        assert(code == SQLITE_OK)
    }
    
    public func clear_bindings() {
        let code = sqlite3_clear_bindings(cStatement)
        assert(code == SQLITE_OK)
    }
    
}

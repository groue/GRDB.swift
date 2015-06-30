//
//  Statement.swift
//  GRDB
//
//  Created by Gwendal Roué on 30/06/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

typealias CStatement = COpaquePointer

let SQLITE_TRANSIENT = UnsafePointer<sqlite3_destructor_type>(COpaquePointer(bitPattern: -1)).memory

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
    
    public func bindNullAtIndex(index:Int) {
        let code = sqlite3_bind_null(cStatement, Int32(index))
        assert(code == SQLITE_OK)
    }
    
    public func bindInt(int: Int, atIndex index:Int) {
        let code = sqlite3_bind_int64(cStatement, Int32(index), Int64(int))
        assert(code == SQLITE_OK)
    }
    
    public func bindDouble(double: Double, atIndex index:Int) {
        let code = sqlite3_bind_double(cStatement, Int32(index), double)
        assert(code == SQLITE_OK)
    }
    
    public func bindString(string: String, atIndex index:Int) {
        let code = string.nulTerminatedUTF8.withUnsafeBufferPointer { codeUnits in
            return sqlite3_bind_text(cStatement, Int32(index), UnsafePointer<Int8>(codeUnits.baseAddress), -1, SQLITE_TRANSIENT)
        }
        assert(code == SQLITE_OK)
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

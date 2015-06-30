//
//  Database.swift
//  GRDB
//
//  Created by Gwendal Roué on 30/06/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

typealias CConnection = COpaquePointer

public class Database {
    let cConnection = CConnection()
    
    public init(path: String) throws {
        // See https://www.sqlite.org/c3ref/open.html
        let code = path.nulTerminatedUTF8.withUnsafeBufferPointer { codeUnits in
            return sqlite3_open(UnsafePointer<Int8>(codeUnits.baseAddress), &cConnection)
        }
        try Error.checkCResultCode(code, cConnection: cConnection)
    }
    
    deinit {
        if cConnection != nil {
            sqlite3_close(cConnection)
        }
    }
    
    public func selectStatement(query: String) throws -> SelectStatement {
        return try SelectStatement(cConnection: cConnection, query: query)
    }
    
    public func updateStatement(query: String) throws -> UpdateStatement {
        return try UpdateStatement(cConnection: cConnection, query: query)
    }
}

//
//  Database.swift
//  GRDB
//
//  Created by Gwendal Roué on 30/06/2015.
//  Copyright © 2015 Stephen Celis. All rights reserved.
//

import Foundation

typealias CDatabase = COpaquePointer

public class Database {
    let cDB = CDatabase()
    
    public init(path: String) throws {
        let code = path.nulTerminatedUTF8.withUnsafeBufferPointer { codeUnits in
            sqlite3_open(UnsafePointer<Int8>(codeUnits.baseAddress), &cDB)
        }
        try Error.checkCResultCode(code, cDB: cDB)
    }
    
    deinit {
        if cDB != nil {
            sqlite3_close(cDB)
        }
    }
}

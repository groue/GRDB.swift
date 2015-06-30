//
//  Error.swift
//  GRDB
//
//  Created by Gwendal Roué on 30/06/2015.
//  Copyright © 2015 Stephen Celis. All rights reserved.
//

struct Error : ErrorType {
    let _domain: String = "GRDB.Error"
    let _code: Int
    let message: String?
    
    init(code: Int32, message: String? = nil) {
        self._code = Int(code)
        self.message = message
    }
    
    static func checkCResultCode(code: Int32, cDB: CDatabase) throws {
        if code != SQLITE_OK {
            let message: String?
            let cstring = sqlite3_errmsg(cDB)
            if cstring == nil {
                message = nil
            } else {
                message = String.fromCString(cstring)
            }
            throw Error(code: code, message: message)
        }
    }
}

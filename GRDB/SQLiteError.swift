//
//  SQLiteError.swift
//  GRDB
//
//  Created by Gwendal Roué on 30/06/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

public struct SQLiteError : ErrorType {
    public let _domain: String = "GRDB.SQLiteError"
    public let _code: Int
    
    public var code: Int { return _code }
    public let message: String?
    public let sql: String?
    
    init(code: Int32, message: String? = nil, sql: String? = nil) {
        self._code = Int(code)
        self.message = message
        self.sql = sql
    }
    
    init(code: Int32, cConnection: CConnection, sql: String? = nil) {
        let message: String?
        let cString = sqlite3_errmsg(cConnection)
        if cString == nil {
            message = nil
        } else {
            message = String.fromCString(cString)
        }
        self.init(code: code, message: message, sql: sql)
    }
    
    static func checkCResultCode(code: Int32, cConnection: CConnection, sql: String? = nil) throws {
        if code != SQLITE_OK {
            throw SQLiteError(code: code, cConnection: cConnection, sql: sql)
        }
    }
}

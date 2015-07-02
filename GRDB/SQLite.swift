//
//  SQLite.swift
//  GRDB
//
//  Created by Gwendal Roué on 02/07/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

typealias SQLiteConnection = COpaquePointer

public typealias SQLiteStatement = COpaquePointer

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
    
    init(code: Int32, sqliteConnection: SQLiteConnection, sql: String? = nil) {
        let message: String?
        let cString = sqlite3_errmsg(sqliteConnection)
        if cString == nil {
            message = nil
        } else {
            message = String.fromCString(cString)
        }
        self.init(code: code, message: message, sql: sql)
    }
    
    static func checkCResultCode(code: Int32, sqliteConnection: SQLiteConnection, sql: String? = nil) throws {
        if code != SQLITE_OK {
            throw SQLiteError(code: code, sqliteConnection: sqliteConnection, sql: sql)
        }
    }
}

public enum SQLiteValue {
    case Null
    case Integer(Int64)
    case Double(Swift.Double)
    case Text(String)
    case Blob
    
    public func value() -> DatabaseValue? {
        switch self {
        case .Null:
            return nil
        case .Integer(let int):
            return int
        case .Double(let double):
            return double
        case .Text(let string):
            return string
        case .Blob:
            fatalError("Not implemented")
        }
    }
    
    public func value<T: DatabaseValue>() -> T? {
        return T.fromSQLiteValue(self)
    }
}

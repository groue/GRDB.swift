//
// GRDB.swift
// https://github.com/groue/GRDB.swift
// Copyright (c) 2015 Gwendal Roué
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.


typealias SQLiteConnection = COpaquePointer
typealias SQLiteStatement = COpaquePointer

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

extension SQLiteError: CustomStringConvertible {
    public var description: String {
        // How to write this with a switch?
        if let sql = sql {
            if let message = message {
                fatalError("SQLite error \(code) with statement `\(sql)`: \(message)")
            } else {
                fatalError("SQLite error \(code) with statement `\(sql)`")
            }
        } else {
            if let message = message {
                fatalError("SQLite error \(code): \(message)")
            } else {
                fatalError("SQLite error \(code)")
            }
        }
    }
}

public enum SQLiteValue {
    case Null
    case Integer(Int64)
    case Real(Double)
    case Text(String)
    case Blob(GRDB.Blob)
    
    public func value() -> SQLiteValueConvertible? {
        switch self {
        case .Null:
            return nil
        case .Integer(let int64):
            return int64
        case .Real(let double):
            return double
        case .Text(let string):
            return string
        case .Blob(let blob):
            return blob
        }
    }
    
    public func value<Value: SQLiteValueConvertible>() -> Value? {
        return Value(sqliteValue: self)
    }
}

public enum SQLiteStorageClass {
    case Null
    case Integer
    case Real
    case Text
    case Blob
}

extension SQLiteValue {
    public var storageClass: SQLiteStorageClass {
        switch self {
        case .Null:
            return .Null
        case .Integer:
            return .Integer
        case .Real:
            return .Real
        case .Text:
            return .Text
        case .Blob:
            return .Blob
        }
    }
}


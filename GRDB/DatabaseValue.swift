//
//  DatabaseValue.swift
//  GRDB
//
//  Created by Gwendal Roué on 30/06/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

internal let SQLITE_TRANSIENT = unsafeBitCast(COpaquePointer(bitPattern: -1), sqlite3_destructor_type.self)

public enum DatabaseCell {
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
        return T.fromDatabaseCell(self)
    }
}

public protocol DatabaseValue {
    func bindInStatement(statement: Statement, atIndex index:Int)
    static func fromDatabaseCell(databaseCell: DatabaseCell) -> Self?
}

extension Bool: DatabaseValue {
    public func bindInStatement(statement: Statement, atIndex index: Int) {
        let code = sqlite3_bind_int(statement.cStatement, Int32(index), Int32(self ? 1 : 0))
        assert(code == SQLITE_OK)
    }
    
    public static func fromDatabaseCell(databaseCell: DatabaseCell) -> Bool? {
        switch databaseCell {
        case .Integer(let int):
            return int != 0
        default:
            return nil
        }
    }
}

extension Int: DatabaseValue {
    public func bindInStatement(statement: Statement, atIndex index: Int) {
        let code = sqlite3_bind_int64(statement.cStatement, Int32(index), Int64(self))
        assert(code == SQLITE_OK)
    }
    
    public static func fromDatabaseCell(databaseCell: DatabaseCell) -> Int? {
        switch databaseCell {
        case .Integer(let int):
            return Int(int)
        case .Double(let double):
            return Int(double)
        default:
            return nil
        }
    }
}

extension Int64: DatabaseValue {
    public func bindInStatement(statement: Statement, atIndex index: Int) {
        let code = sqlite3_bind_int64(statement.cStatement, Int32(index), self)
        assert(code == SQLITE_OK)
    }
    
    public static func fromDatabaseCell(databaseCell: DatabaseCell) -> Int64? {
        switch databaseCell {
        case .Integer(let int):
            return int
        case .Double(let double):
            return Int64(double)
        default:
            return nil
        }
    }
}

extension Double: DatabaseValue {
    public func bindInStatement(statement: Statement, atIndex index: Int) {
        let code = sqlite3_bind_double(statement.cStatement, Int32(index), self)
        assert(code == SQLITE_OK)
    }
    
    public static func fromDatabaseCell(databaseCell: DatabaseCell) -> Double? {
        switch databaseCell {
        case .Integer(let int):
            return Double(int)
        case .Double(let double):
            return double
        default:
            return nil
        }
    }
}

extension String: DatabaseValue {
    public func bindInStatement(statement: Statement, atIndex index: Int) {
        let code = nulTerminatedUTF8.withUnsafeBufferPointer { codeUnits in
            return sqlite3_bind_text(statement.cStatement, Int32(index), UnsafePointer<Int8>(codeUnits.baseAddress), -1, SQLITE_TRANSIENT)
        }
        assert(code == SQLITE_OK)
    }
    
    public static func fromDatabaseCell(databaseCell: DatabaseCell) -> String? {
        switch databaseCell {
        case .Text(let string):
            return string
        default:
            return nil
        }
    }
}

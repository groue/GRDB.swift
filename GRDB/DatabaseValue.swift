//
//  DatabaseValue.swift
//  GRDB
//
//  Created by Gwendal Roué on 30/06/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

private let SQLITE_TRANSIENT = unsafeBitCast(COpaquePointer(bitPattern: -1), sqlite3_destructor_type.self)

public protocol DatabaseValue {
    func bindInSQLiteStatement(statement: SQLiteStatement, atIndex index: Int) -> Int32
    static func fromSQLiteValue(value: SQLiteValue) -> Self?
}

extension Bool: DatabaseValue {
    public func bindInSQLiteStatement(statement: SQLiteStatement, atIndex index: Int) -> Int32 {
        return sqlite3_bind_int(statement, Int32(index), Int32(self ? 1 : 0))
    }
    
    public static func fromSQLiteValue(value: SQLiteValue) -> Bool? {
        switch value {
        case .Integer(let int):
            return int != 0
        default:
            return nil
        }
    }
}

extension Int: DatabaseValue {
    public func bindInSQLiteStatement(statement: SQLiteStatement, atIndex index: Int) -> Int32 {
        return sqlite3_bind_int64(statement, Int32(index), Int64(self))
    }
    
    public static func fromSQLiteValue(value: SQLiteValue) -> Int? {
        switch value {
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
    public func bindInSQLiteStatement(statement: SQLiteStatement, atIndex index: Int) -> Int32 {
        return sqlite3_bind_int64(statement, Int32(index), self)
    }
    
    public static func fromSQLiteValue(value: SQLiteValue) -> Int64? {
        switch value {
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
    public func bindInSQLiteStatement(statement: SQLiteStatement, atIndex index: Int) -> Int32 {
        return sqlite3_bind_double(statement, Int32(index), self)
    }
    
    public static func fromSQLiteValue(value: SQLiteValue) -> Double? {
        switch value {
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
    public func bindInSQLiteStatement(statement: SQLiteStatement, atIndex index: Int) -> Int32 {
        return sqlite3_bind_text(statement, Int32(index), self, -1, SQLITE_TRANSIENT)
    }
    
    public static func fromSQLiteValue(value: SQLiteValue) -> String? {
        switch value {
        case .Text(let string):
            return string
        default:
            return nil
        }
    }
}

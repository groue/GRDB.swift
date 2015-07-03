//
//  DatabaseValueType.swift
//  GRDB
//
//  Created by Gwendal Roué on 30/06/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

private let SQLITE_TRANSIENT = unsafeBitCast(COpaquePointer(bitPattern: -1), sqlite3_destructor_type.self)

public protocol DatabaseValueType {
    func bindInSQLiteStatement(statement: SQLiteStatement, atIndex index: Int) -> Int32
    static func fromSQLiteValue(value: SQLiteValue) -> Self?
}

public struct DatabaseEnum<T: RawRepresentable where T.RawValue: DatabaseValueType> : DatabaseValueType {
    public let value: T
    
    public init?(_ value: T?) {
        if let value = value {
            self.value = value
        } else {
            return nil
        }
    }
    
    public func bindInSQLiteStatement(statement: SQLiteStatement, atIndex index: Int) -> Int32 {
        return value.rawValue.bindInSQLiteStatement(statement, atIndex: index)
    }
    
    public static func fromSQLiteValue(value: SQLiteValue) -> DatabaseEnum<T>? {
        if let rawValue = T.RawValue.fromSQLiteValue(value), value = T.init(rawValue: rawValue) {
            return self.init(value)
        } else {
            return nil
        }
    }
}

extension Bool: DatabaseValueType {
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

extension Int: DatabaseValueType {
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

extension Int64: DatabaseValueType {
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

extension Double: DatabaseValueType {
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

extension String: DatabaseValueType {
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

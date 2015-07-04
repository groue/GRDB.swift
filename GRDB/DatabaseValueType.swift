//
//  DatabaseValueType.swift
//  GRDB
//
//  Created by Gwendal Roué on 30/06/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

public protocol DatabaseValueType {
    var sqliteValue: SQLiteValue { get }
    static func fromSQLiteValue(value: SQLiteValue) -> Self?
}

extension Bool: DatabaseValueType {
    public var sqliteValue: SQLiteValue {
        return .Integer(self ? 1 : 0)
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
    public var sqliteValue: SQLiteValue {
        return .Integer(Int64(self))
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
    public var sqliteValue: SQLiteValue {
        return .Integer(self)
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
    public var sqliteValue: SQLiteValue {
        return .Double(self)
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
    public var sqliteValue: SQLiteValue {
        return .Text(self)
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

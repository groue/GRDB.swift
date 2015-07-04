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
        // https://www.sqlite.org/datatype3.html
        //
        // > SQLite does not have a separate Boolean storage class. Instead,
        // > Boolean values are stored as integers 0 (false) and 1 (true).
        //
        // So we only support int as a valid storage class for Boolean:
        switch value {
        case .Integer(let int64):
            return int64 != 0
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
        case .Integer(let int64):
            return Int(int64)
        case .Real(let double):
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
        case .Integer(let int64):
            return int64
        case .Real(let double):
            return Int64(double)
        default:
            return nil
        }
    }
}

extension Double: DatabaseValueType {
    public var sqliteValue: SQLiteValue {
        return .Real(self)
    }
    
    public static func fromSQLiteValue(value: SQLiteValue) -> Double? {
        switch value {
        case .Integer(let int64):
            return Double(int64)
        case .Real(let double):
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

public struct Blob : DatabaseValueType {
    public let data: NSData
    
    init?(_ data: NSData?) {
        if let data = data {
            self.data = data
        } else {
            return nil
        }
    }

    public var sqliteValue: SQLiteValue {
        return .Blob(self)
    }
    
    public static func fromSQLiteValue(value: SQLiteValue) -> Blob? {
        switch value {
        case .Blob(let blob):
            return blob
        default:
            return nil
        }
    }
}

//
//  SQLiteValueConvertible.swift
//  GRDB
//
//  Created by Gwendal Roué on 30/06/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

public protocol SQLiteValueConvertible {
    var sqliteValue: SQLiteValue { get }
    init?(sqliteValue: SQLiteValue)
}

extension Bool: SQLiteValueConvertible {
    public var sqliteValue: SQLiteValue {
        return .Integer(self ? 1 : 0)
    }
    
    public init?(sqliteValue: SQLiteValue) {
        // https://www.sqlite.org/lang_expr.html#booleanexpr
        //
        // > # Boolean Expressions
        // >
        // > The SQL language features several contexts where an expression is
        // > evaluated and the result converted to a boolean (true or false)
        // > value. These contexts are:
        // >
        // > - the WHERE clause of a SELECT, UPDATE or DELETE statement,
        // > - the ON or USING clause of a join in a SELECT statement,
        // > - the HAVING clause of a SELECT statement,
        // > - the WHEN clause of an SQL trigger, and
        // > - the WHEN clause or clauses of some CASE expressions.
        // >
        // > To convert the results of an SQL expression to a boolean value,
        // > SQLite first casts the result to a NUMERIC value in the same way as
        // > a CAST expression. A numeric zero value (integer value 0 or real
        // > value 0.0) is considered to be false. A NULL value is still NULL.
        // > All other values are considered true.
        // >
        // > For example, the values NULL, 0.0, 0, 'english' and '0' are all
        // > considered to be false. Values 1, 1.0, 0.1, -0.1 and '1english' are
        // > considered to be true.
        //
        // OK so we have to support boolean for all storage classes.
        
        switch sqliteValue {
        case .Null:
            return nil
        case .Integer(let int64):
            self = (int64 != 0)
        case .Real(let double):
            self = (double != 0.0)
        case .Text:
            // The doc says that "english" should be false, and "1english"
            // should be true. I guess "-1english" and "0.1english" should be
            // true also. And... what about "0.0e10english"?
            //
            // Ideally, we'd ask SQLite to perform the conversion itself, and
            // return its own boolean interpretation of the string.
            // Unfortunately, it looks like it is not so easy...
            //
            // So let's take a short route for now. Assume false, since most
            // strings are indeed falsey.
            self = false
        case .Blob:
            self = true
        }
    }
}

extension Int: SQLiteValueConvertible {
    public var sqliteValue: SQLiteValue {
        return .Integer(Int64(self))
    }
    
    public init?(sqliteValue: SQLiteValue) {
        switch sqliteValue {
        case .Integer(let int64):
            self.init(int64)
        case .Real(let double):
            self.init(double)
        default:
            return nil
        }
    }
}

extension Int64: SQLiteValueConvertible {
    public var sqliteValue: SQLiteValue {
        return .Integer(self)
    }
    
    public init?(sqliteValue: SQLiteValue) {
        switch sqliteValue {
        case .Integer(let int64):
            self.init(int64)
        case .Real(let double):
            self.init(double)
        default:
            return nil
        }
    }
}

extension Double: SQLiteValueConvertible {
    public var sqliteValue: SQLiteValue {
        return .Real(self)
    }
    
    public init?(sqliteValue: SQLiteValue) {
        switch sqliteValue {
        case .Integer(let int64):
            self.init(int64)
        case .Real(let double):
            self.init(double)
        default:
            return nil
        }
    }
}

extension String: SQLiteValueConvertible {
    public var sqliteValue: SQLiteValue {
        return .Text(self)
    }
    
    public init?(sqliteValue: SQLiteValue) {
        switch sqliteValue {
        case .Text(let string):
            self = string
        default:
            return nil
        }
    }
}

public struct Blob : SQLiteValueConvertible {
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
    
    public init?(sqliteValue: SQLiteValue) {
        switch sqliteValue {
        case .Blob(let blob):
            self.init(blob.data)
        default:
            return nil
        }
    }
}

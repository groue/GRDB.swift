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


/**
The protocol for values that can be stored and extracted from SQLite databases.
*/
public protocol SQLiteValueConvertible {
    /// Returns a SQLite value that can be stored in the database.
    var sqliteValue: SQLiteValue { get }
    
    /// Create an instance initialized to `sqliteValue`.
    init?(sqliteValue: SQLiteValue)
}

/// Bool is convertible to and from SQLiteValue.
extension Bool: SQLiteValueConvertible {
    
    /// Returns a SQLite value that can be stored in the database.
    public var sqliteValue: SQLiteValue {
        return .Integer(self ? 1 : 0)
    }
    
    /// Create an instance initialized to `sqliteValue`.
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

/// Int is convertible to and from SQLiteValue.
extension Int: SQLiteValueConvertible {
    
    /// Returns a SQLite value that can be stored in the database.
    public var sqliteValue: SQLiteValue {
        return .Integer(Int64(self))
    }
    
    /// Create an instance initialized to `sqliteValue`.
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

/// Int64 is convertible to and from SQLiteValue.
extension Int64: SQLiteValueConvertible {
    
    /// Returns a SQLite value that can be stored in the database.
    public var sqliteValue: SQLiteValue {
        return .Integer(self)
    }
    
    /// Create an instance initialized to `sqliteValue`.
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

/// Double is convertible to and from SQLiteValue.
extension Double: SQLiteValueConvertible {
    
    /// Returns Returns a SQLite value that can be stored in the database..
    public var sqliteValue: SQLiteValue {
        return .Real(self)
    }
    
    /// Create an instance initialized to `sqliteValue`.
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

/// String is convertible to and from SQLiteValue.
extension String: SQLiteValueConvertible {
    
    /// Returns a SQLite value that can be stored in the database.
    public var sqliteValue: SQLiteValue {
        return .Text(self)
    }
    
    /// Create an instance initialized to `sqliteValue`.
    public init?(sqliteValue: SQLiteValue) {
        switch sqliteValue {
        case .Text(let string):
            self = string
        default:
            return nil
        }
    }
}

/// Blob is convertible to and from SQLiteValue.
public struct Blob : SQLiteValueConvertible {
    
    /// The data
    public let data: NSData
    
    /// Create a Blob from NSData. Returns nil if and only if *data* is nil.
    init?(_ data: NSData?) {
        if let data = data {
            self.data = data
        } else {
            return nil
        }
    }
    
    /// Returns a SQLite value that can be stored in the database.
    public var sqliteValue: SQLiteValue {
        return .Blob(self)
    }
    
    /// Create an instance initialized to `sqliteValue`.
    public init?(sqliteValue: SQLiteValue) {
        switch sqliteValue {
        case .Blob(let blob):
            self.init(blob.data)
        default:
            return nil
        }
    }
}

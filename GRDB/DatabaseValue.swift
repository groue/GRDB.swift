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
DatabaseValue is the intermediate type between SQLite and your values.

It has five cases that match the SQLite "storage classes":
https://www.sqlite.org/datatype3.html
*/
public enum DatabaseValue : Equatable {
    
    /// The NULL storage class.
    case Null
    
    /// The INTEGER storage class, wrapping an Int64.
    case Integer(Int64)
    
    /// The REAL storage class, wrapping a Double.
    case Real(Double)
    
    /// The TEXT storage class, wrapping a String.
    case Text(String)
    
    /// The BLOB storage class, wrapping a Blob.
    case Blob(GRDB.Blob)
    
    
    // MARK: - Extracting Swift Value
    
    /**
    Returns the wrapped value.
    
    If not nil (for the database NULL), its type is guaranteed to be one of the
    following: Int64, Double, String, and Blob.
    
    let value = databaseValue.value()
    */
    public func value() -> DatabaseValueConvertible? {
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
    
    /**
    Returns the wrapped value, converted to the requested type.
    
    The conversion returns nil if the SQLite value is NULL, or can't be
    converted to the requested type:
    
        let value: Bool? = databaseValue.value()
        let value: Int? = databaseValue.value()
        let value: Double? = databaseValue.value()
    
    **WARNING**: type casting requires a very careful use of the `as` operator
    (see [rdar://problem/21676393](http://openradar.appspot.com/radar?id=4951414862249984)):
    
        databaseValue.value()! as Int   // OK: Int
        databaseValue.value() as Int?   // OK: Int?
        databaseValue.value() as? Int   // NO NO NO DON'T DO THAT!
    
    Your custom types that adopt the DatabaseValueConvertible protocol handle
    their own conversion from raw SQLite values. Yet, here is the reference for
    built-in types:
    
    SQLite value: | NULL    INTEGER         REAL            TEXT        BLOB
    --------------|---------------------------------------------------------
    Bool          | nil     false if 0      false if 0.0    nil         nil
    Int           | nil     Int(*)          Int(*)          nil         nil
    Int64         | nil     Int64           Int64(*)        nil         nil
    Double        | nil     Double          Double          nil         nil
    String        | nil     nil             nil             String      nil
    Blob          | nil     nil             nil             nil         Blob
    
    (*) Conversions to Int and Int64 crash if the value is too big.
    
    */
    public func value<Value: DatabaseValueConvertible>() -> Value? {
        return Value(databaseValue: self)
    }
}

/// Equatable implementation for DatabaseValue
public func ==(lhs: DatabaseValue, rhs: DatabaseValue) -> Bool {
    switch (lhs, rhs) {
    case (.Null, .Null):
        return true
    case (.Integer(let lhs), .Integer(let rhs)):
        return lhs == rhs
    case (.Real(let lhs), .Real(let rhs)):
        return lhs == rhs
    case (.Integer(let lhs), .Real(let rhs)):
        return int64EqualDouble(lhs, rhs)
    case (.Real(let lhs), .Integer(let rhs)):
        return int64EqualDouble(rhs, lhs)
    case (.Text(let lhs), .Text(let rhs)):
        return lhs == rhs
    case (.Blob(let lhs), .Blob(let rhs)):
        return lhs.data.isEqualToData(rhs.data)
    default:
        return false
    }
}

private func int64EqualDouble(i: Int64, _ d: Double) -> Bool {
    if d >= Double(Int64.min) && d < Double(Int64.max) {
        return round(d) == d && i == Int64(d)
    } else {
        return false
    }
}

/// DatabaseValue adopts DatabaseValueConvertible.
extension DatabaseValue : DatabaseValueConvertible {
    /// Returns self
    public var databaseValue: DatabaseValue {
        return self
    }
    
    /// Create a copy of `databaseValue`.
    public init?(databaseValue: DatabaseValue) {
        self = databaseValue
    }
}

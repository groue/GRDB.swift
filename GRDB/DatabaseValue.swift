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
public enum DatabaseValue {
    
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
    
    /**
    Returns the wrapped value.
    
    If not nil (for NULL), its type is guaranteed to be one of the following:
    Int64, Double, String, and Blob.
    
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

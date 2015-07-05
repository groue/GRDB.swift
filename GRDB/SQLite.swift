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


// MARK: - SQLiteError

/**
SQLiteError wraps a SQLite error.
*/
public struct SQLiteError : ErrorType {
    
    /// Required for ErrorType conformance.
    public let _domain: String = "GRDB.SQLiteError"
    
    /// Required for ErrorType conformance.
    public var _code: Int { return code }
    
    /// The SQLite error code (see https://www.sqlite.org/c3ref/c_abort.html).
    public let code: Int
    
    /// The SQLite error message.
    public let message: String?
    
    /// The SQL query that yielded the error (if relevant).
    public let sql: String?
    
    
    // MARK: Not public
    
    init(code: Int32, message: String? = nil, sql: String? = nil) {
        self.code = Int(code)
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
}

extension SQLiteError: CustomStringConvertible {
    /// A textual representation of `self`.
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


// MARK: - SQLiteValue

/**
SQLiteValue is the intermediate type between SQLite storage and your values.

It has five cases that match the SQLite "storage classes": https://www.sqlite.org/datatype3.html
*/
public enum SQLiteValue {
    
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
    
        let value = sqliteValue.value()
    */
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
    
    /**
    Returns the wrapped value, converted to the requested type.
    
    The conversion returns nil if the SQLite value is NULL, or can't be
    converted to the requested type:
    
        let value: Bool? = sqliteValue.value()
        let value: Int? = sqliteValue.value()
        let value: Double? = sqliteValue.value()
    
    Your custom types that adopt the SQLiteValueConvertible protocol handle
    their own conversion from raw SQLite values. Yet, here is the reference for
    built-in types:
    
        SQLite value: | NULL    INTEGER         REAL            TEXT        BLOB
        --------------|---------------------------------------------------------
        Bool          | nil     false if 0      false if 0.0    false(**)   true
        Int           | nil     Int(*)          Int(*)          nil         nil
        Int64         | nil     Int64           Int64(*)        nil         nil
        Double        | nil     Double          Double          nil         nil
        String        | nil     nil             nil             String      nil
        Blob          | nil     nil             nil             nil         Blob
    
    (*) Conversions to Int and Int64 crash if the value is too big.
    (**) All strings are falsey. Caveat: SQLite performs [another conversion](https://www.sqlite.org/lang_expr.html#booleanexpr),
    which considers *most* strings as falsey, but not *all* strings).
    */
    public func value<Value: SQLiteValueConvertible>() -> Value? {
        return Value(sqliteValue: self)
    }
}


// MARK: - SQLite identifier quoting

extension String {
    /// Returns the receiver, quoted for safe insertion in an SQL query as an
    /// identifier.
    ///
    ///     db.execute("SELECT * FROM \(tableName.sqliteQuotedIdentifier)")
    public var sqliteQuotedIdentifier: String {
        // See https://www.sqlite.org/lang_keywords.html
        return "\"\(self)\""
    }
}


// MARK: - Not public

/// A nicer name than COpaquePointer for SQLite connection handle
typealias SQLiteConnection = COpaquePointer

/// A nicer name than COpaquePointer for SQLite statement handle
typealias SQLiteStatement = COpaquePointer


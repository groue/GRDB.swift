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
DatabaseError wraps a SQLite error.
*/
public struct DatabaseError : ErrorType {
    
    /// The SQLite error code (see https://www.sqlite.org/c3ref/c_abort.html).
    public let code: Int
    
    /// The SQLite error message.
    public let message: String?
    
    /// The SQL query that yielded the error (if relevant).
    public let sql: String?
    
    
    // MARK: Not public
    
    /// The query arguments that yielded the error (if relevant).
    /// Not public because the QueryArguments class has no public method.
    let arguments: QueryArguments?
    
    init(code: Int32, message: String? = nil, sql: String? = nil, arguments: QueryArguments? = nil) {
        self.code = Int(code)
        self.message = message
        self.sql = sql
        self.arguments = arguments
    }
}

extension DatabaseError: CustomStringConvertible {
    /// A textual representation of `self`.
    public var description: String {
        // How to write this with a switch?
        if let sql = sql {
            if let message = message {
                if let arguments = arguments {
                    return "SQLite error \(code) with statement `\(sql)` arguments \(arguments): \(message)"
                } else {
                    return "SQLite error \(code) with statement `\(sql)`: \(message)"
                }
            } else {
                if let arguments = arguments {
                    return "SQLite error \(code) with statement `\(sql)` arguments \(arguments)"
                } else {
                    return "SQLite error \(code) with statement `\(sql)`"
                }
            }
        } else {
            if let message = message {
                return "SQLite error \(code): \(message)"
            } else {
                return "SQLite error \(code)"
            }
        }
    }
}

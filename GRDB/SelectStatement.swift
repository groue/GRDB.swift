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


import Foundation

/// A subclass of Statement that fetches database rows.
public final class SelectStatement : Statement {
    
    /// The number of columns in the results.
    public lazy var columnCount: Int = Int(sqlite3_column_count(self.sqliteStatement))
    
    /// The names of columns, ordered from left to right.
    public lazy var columnNames: [String] = (0..<self.columnCount).map { index in
        return String.fromCString(sqlite3_column_name(self.sqliteStatement, Int32(index)))!
    }
    
    // MARK: - Not public
    
    /**
    If true, the fetched rows are *unsafe*.
    
    See Row(statement:unsafe:) for details.
    */
    let unsafe: Bool
    
    init(database: Database, sql: String, bindings: Bindings?, unsafe: Bool) throws {
        self.unsafe = unsafe
        try super.init(database: database, sql: sql, bindings: bindings)
        
        // Make sure the statement is created in a database queue:
        assert(databaseQueueID != nil)
    }
    
    /**
    Returns the SQLiteValue at given index.
    
    It is the *only* method which loads data straight from SQLite.
    
    We preserve the *raw storage class* of database values, and do not use the
    SQLite built-in casting between types.
    
    This is *by design*, because a GRDB user generally consumes database values
    long after the opportunity to use SQLite casting has passed, which is during
    the statement consumption.
    
        // All rows are loaded, which means that statement has been fully
        // consumed, and any SQLite casting opportunity has passed.
        let rows = db.fetchAllRows("SELECT ...")
    
        for row in rows {
            let age: Int = row.value(atIndex:0)     // the conversion actually happens in GRDB.
        }
    
    The only known caveat (so far) of snubbing SQLite built-in casting is the
    String to Bool conversion. See Row.value(atIndex:) for more information.
    */
    func sqliteValue(atIndex index: Int) -> SQLiteValue {
        switch sqlite3_column_type(sqliteStatement, Int32(index)) {
        case SQLITE_NULL:
            return .Null;
        case SQLITE_INTEGER:
            return .Integer(sqlite3_column_int64(sqliteStatement, Int32(index)))
        case SQLITE_FLOAT:
            return .Real(sqlite3_column_double(sqliteStatement, Int32(index)))
        case SQLITE_TEXT:
            let cString = UnsafePointer<Int8>(sqlite3_column_text(sqliteStatement, Int32(index)))
            return .Text(String.fromCString(cString)!)
        case SQLITE_BLOB:
            let bytes = sqlite3_column_blob(sqliteStatement, Int32(index))
            let length = sqlite3_column_bytes(sqliteStatement, Int32(index))
            let data = NSData(bytes: bytes, length: Int(length))
            return .Blob(Blob(data)!)
        default:
            fatalError("Unexpected SQLite column type")
        }
    }
}

/**
The SelectStatement methods that fetch rows.
*/
extension SelectStatement {
    
    /**
    Fetches a lazy sequence of rows.
    
        let statement = try db.selectStatement("SELECT ...")
        let rows = statement.fetchRows()
    
    - parameter bindings: Optional bindings for query parameters.
    - returns: A lazy sequence of rows.
    */
    public func fetchRows(bindings bindings: Bindings? = nil) -> AnySequence<Row> {
        if let bindings = bindings {
            self.bindings = bindings
        }

        if let trace = self.database.configuration.trace {
            trace(sql: self.sql, bindings: self.bindings)
        }
        
        return AnySequence { () -> AnyGenerator<Row> in
            // Let row sequences be iterated several times.
            self.reset()
            
            return anyGenerator { () -> Row? in
                // Make sure values are consumed in the correct queue.
                //
                // Here we avoid this pattern:
                //
                //      let rows = dbQueue.inDatabase { db in
                //          try db.fetchRows("...")
                //      }
                //      for row in rows {   // fatal error!
                //          ...
                //      }
                //
                // Check that the statement was created in a database queue,
                // and then that the current database queue is the same as the
                // one where the statement was created:
                assert(self.databaseQueueID != nil)
                guard self.databaseQueueID == dispatch_get_specific(DatabaseQueue.databaseQueueIDKey) else {
                    fatalError("SelectStatement was not iterated on its database queue. Consider wrapping the results of the fetch in an Array before escaping the database queue.")
                }
                
                let code = sqlite3_step(self.sqliteStatement)
                switch code {
                case SQLITE_DONE:
                    return nil
                case SQLITE_ROW:
                    return Row(statement: self, unsafe: self.unsafe)
                default:
                    verboseFailOnError { () -> Void in
                        throw SQLiteError(code: code, sqliteConnection: self.database.sqliteConnection, sql: self.sql)
                    }
                    return nil
                }
            }
        }
    }
    
    /**
    Fetches an array of rows.
    
        let statement = try db.selectStatement("SELECT ...")
        let rows = statement.fetchAllRows()
    
    - parameter bindings: Optional bindings for query parameters.
    - returns: An array of rows.
    */
    public func fetchAllRows(bindings bindings: Bindings? = nil) -> [Row] {
        return Array(fetchRows(bindings: bindings))
    }
    
    /**
    Fetches a single row.
    
        let statement = try db.selectStatement("SELECT ...")
        let row = statement.fetchOneRow()
    
    - parameter sql:      An SQL query.
    - parameter bindings: Optional bindings for query parameters.
    
    - returns: An optional row.
    */
    public func fetchOneRow(bindings bindings: Bindings? = nil) -> Row? {
        return fetchRows(bindings: bindings).generate().next()
    }
}

extension SelectStatement {
    
    // let names = statement.fetch(String.self)
    public func fetch<Value: SQLiteValueConvertible>(type: Value.Type, bindings: Bindings? = nil) -> AnySequence<Value?> {
        let rowSequence = fetchRows(bindings: bindings)
        return AnySequence { () -> AnyGenerator<Value?> in
            let rowGenerator = rowSequence.generate()
            return anyGenerator { () -> Value?? in
                if let row = rowGenerator.next() {
                    return Optional.Some(row.value(atIndex: 0))
                } else {
                    return nil
                }
            }
        }
    }
    
    // let names = statement.fetchAll(String.self)
    public func fetchAll<Value: SQLiteValueConvertible>(type: Value.Type, bindings: Bindings? = nil) -> [Value?] {
        return Array(fetch(type, bindings: bindings))
    }
    
    // let name = statement.fetchOne(String.self)
    public func fetchOne<Value: SQLiteValueConvertible>(type: Value.Type, bindings: Bindings? = nil) -> Value? {
        if let optionalValue = fetch(type, bindings: bindings).generate().next() {
            // one row containing an optional value
            return optionalValue
        } else {
            // no row
            return nil
        }
    }
}

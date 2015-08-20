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

/**
A subclass of Statement that fetches database rows.

You create SelectStatement with the Database.selectStatement() method:

    dbQueue.inDatabase { db in
        let statement = db.selectStatement("SELECT * FROM persons WHERE age > ?")
        let moreThanTwentyCount = statement.fetchOne(Int.self, arguments: [20])!
        let moreThanThirtyCount = statement.fetchOne(Int.self, arguments: [30])!
    }
*/
public final class SelectStatement : Statement {
    
    /// The number of columns in the resulting rows.
    public lazy var columnCount: Int = { [unowned self] in
        Int(sqlite3_column_count(self.sqliteStatement))
    }()
    
    /// The names of columns, ordered from left to right.
    public lazy var columnNames: [String] = { [unowned self] in
        (0..<self.columnCount).map { index in
            return String.fromCString(sqlite3_column_name(self.sqliteStatement, Int32(index)))!
        }
    }()
    
    // MARK: - Not public
    
    /**
    Returns the DatabaseValue at given index.
    
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
    */
    func databaseValue(atIndex index: Int) -> DatabaseValue {
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

/// The SelectStatement methods that fetch rows.
extension SelectStatement {
    
    /**
    Fetches a lazy sequence of rows.
    
        let statement = db.selectStatement("SELECT ...")
        let rows = statement.fetchRows()
    
    - parameter arguments: Optional query arguments.
    - returns: A lazy sequence of rows.
    */
    public func fetchRows(arguments arguments: StatementArguments? = nil) -> AnySequence<Row> {
        if let arguments = arguments {
            self.arguments = arguments
        }

        if let trace = self.database.configuration.trace {
            trace(sql: self.sql, arguments: self.arguments)
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
                    return Row(statement: self)
                default:
                    fatalDatabaseError(DatabaseError(code: code, message: self.database.lastErrorMessage, sql: self.sql, arguments: self.arguments))
                }
            }
        }
    }
    
    /**
    Fetches an array of rows.
    
        let statement = db.selectStatement("SELECT ...")
        let rows = statement.fetchAllRows()
    
    - parameter arguments: Optional query arguments.
    - returns: An array of rows.
    */
    public func fetchAllRows(arguments arguments: StatementArguments? = nil) -> [Row] {
        return Array(fetchRows(arguments: arguments))
    }
    
    /**
    Fetches a single row.
    
        let statement = db.selectStatement("SELECT ...")
        let row = statement.fetchOneRow()
    
    - parameter arguments: Optional query arguments.
    
    - returns: An optional row.
    */
    public func fetchOneRow(arguments arguments: StatementArguments? = nil) -> Row? {
        return fetchRows(arguments: arguments).generate().next()
    }
}

/// The SelectStatement methods that fetch values.
extension SelectStatement {
    
    /**
    Fetches a lazy sequence of values.

        let statement = db.selectStatement("SELECT name FROM ...")
        let names = statement.fetch(String.self)

    - parameter type:     The type of fetched values. It must adopt
                          DatabaseValueConvertible.
    - parameter arguments: Optional query arguments.
    
    - returns: A lazy sequence of values.
    */
    public func fetch<Value: DatabaseValueConvertible>(type: Value.Type, arguments: StatementArguments? = nil) -> AnySequence<Value?> {
        let rowSequence = fetchRows(arguments: arguments)
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
    
    /**
    Fetches an array of values.

        let statement = db.selectStatement("SELECT name FROM ...")
        let names = db.fetchAll(String.self)

    - parameter type:     The type of fetched values. It must adopt
                          DatabaseValueConvertible.
    - parameter arguments: Optional query arguments.
    
    - returns: An array of values.
    */
    public func fetchAll<Value: DatabaseValueConvertible>(type: Value.Type, arguments: StatementArguments? = nil) -> [Value?] {
        return Array(fetch(type, arguments: arguments))
    }
    
    /**
    Fetches a single value.

        let statement = db.selectStatement("SELECT name FROM ...")
        let name = db.fetchOne(String.self)

    - parameter type:     The type of fetched values. It must adopt
                          DatabaseValueConvertible.
    - parameter arguments: Optional query arguments.
    
    - returns: An optional value.
    */
    public func fetchOne<Value: DatabaseValueConvertible>(type: Value.Type, arguments: StatementArguments? = nil) -> Value? {
        if let optionalValue = fetch(type, arguments: arguments).generate().next() {
            // one row containing an optional value
            return optionalValue
        } else {
            // no row
            return nil
        }
    }
}

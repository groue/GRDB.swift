//
//  SelectStatement.swift
//  GRDB
//
//  Created by Gwendal Roué on 30/06/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

import Foundation

public final class SelectStatement : Statement {
    let unsafe: Bool
    public lazy var columnCount: Int = Int(sqlite3_column_count(self.sqliteStatement))
    public lazy var columnNames: [String] = (0..<self.columnCount).map { index in
        return String.fromCString(sqlite3_column_name(self.sqliteStatement, Int32(index)))!
    }

    init(database: Database, sql: String, bindings: Bindings?, unsafe: Bool) throws {
        self.unsafe = unsafe
        try super.init(database: database, sql: sql, bindings: bindings)
        assert(databaseQueueID != nil)
    }

    func sqliteValueAtIndex(index: Int) -> SQLiteValue {
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

extension SelectStatement {
    
    // let rows = statement.fetchRows()
    public func fetchRows(bindings bindings: Bindings? = nil) -> AnySequence<Row> {
        if let bindings = bindings {
            self.bindings = bindings
        }
        return AnySequence { () -> AnyGenerator<Row> in
            var trace = self.database.configuration.trace
            return anyGenerator { () -> Row? in
                // Make sure values are not consumed in a different queue.
                //
                // Here we avoid this pattern:
                //
                //      let rows = dbQueue.inDatabase { db in
                //          try db.fetchRows("...")
                //      }
                //      for row in rows {   // fatal error
                //          ...
                //      }
                assert(self.databaseQueueID != nil)
                guard self.databaseQueueID == dispatch_get_specific(DatabaseQueue.databaseQueueIDKey) else {
                    fatalError("SelectStatement was not iterated on its database queue. Consider wrapping the results of the fetch in an Array before escaping the database queue.")
                }
                
                if let appliedTrace = trace {
                    appliedTrace(self.sql)
                    trace = nil
                }
                let code = sqlite3_step(self.sqliteStatement)
                switch code {
                case SQLITE_DONE:
                    return nil
                case SQLITE_ROW:
                    return Row(statement: self, unsafe: self.unsafe)
                default:
                    failOnError { () -> Void in
                        throw SQLiteError(code: code, sqliteConnection: self.database.sqliteConnection, sql: self.sql)
                    }
                    return nil
                }
            }
        }
    }
    
    // let rows = statement.fetchAllRows()
    public func fetchAllRows(bindings bindings: Bindings? = nil) -> [Row] {
        return Array(fetchRows(bindings: bindings))
    }
    
    // let row = statement.fetchOneRow()
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

//
//  SelectStatement.swift
//  GRDB
//
//  Created by Gwendal Roué on 30/06/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

public final class SelectStatement : Statement {
    let unsafe: Bool
    public lazy var columnCount: Int = Int(sqlite3_column_count(self.sqliteStatement))
    public lazy var columnNames: [String] = (0..<self.columnCount).map { index in
        return String.fromCString(sqlite3_column_name(self.sqliteStatement, Int32(index)))!
    }

    init(database: Database, sql: String, bindings: Bindings?, unsafe: Bool) throws {
        self.unsafe = unsafe
        try super.init(database: database, sql: sql, bindings: bindings)
    }

    func sqliteValueAtIndex(index: Int) -> SQLiteValue {
        switch sqlite3_column_type(sqliteStatement, Int32(index)) {
        case SQLITE_NULL:
            return .Null;
        case SQLITE_INTEGER:
            return .Integer(sqlite3_column_int64(sqliteStatement, Int32(index)))
        case SQLITE_FLOAT:
            return .Double(sqlite3_column_double(sqliteStatement, Int32(index)))
        case SQLITE_TEXT:
            let cString = UnsafePointer<Int8>(sqlite3_column_text(sqliteStatement, Int32(index)))
            return .Text(String.fromCString(cString)!)
        default:
            fatalError("Not implemented")
        }
    }
}

extension SelectStatement {
    
    public func fetchRowGenerator() -> AnyGenerator<Row> {
        // TODO: Document this reset performed on each generation
        try! reset()
        
        var logSQL = database.configuration.verbose
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
            guard self.databaseQueueID == dispatch_get_specific(DatabaseQueue.databaseQueueIDKey) else {
                fatalError("SelectStatement was not iterated on its database queue. Consider wrapping the results of the fetch in an Array before escaping the database queue.")
            }
            
            if logSQL {
                NSLog("%@", self.sql)
                logSQL = false
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
    
    public func fetchRows() -> AnySequence<Row> {
        return AnySequence { self.fetchRowGenerator() }
    }
    
    public func fetchAllRows() -> [Row] {
        return Array(fetchRows())
    }
    
    public func fetchOneRow() -> Row? {
        return fetchRowGenerator().next()
    }
}

extension SelectStatement {
    
    public func fetchGenerator<T: DatabaseValue>(type: T.Type) -> AnyGenerator<T?> {
        let rowGenerator = fetchRowGenerator()
        return anyGenerator { () -> T?? in
            if let row = rowGenerator.next() {
                return Optional.Some(row.value(atIndex: 0) as T?)
            } else {
                return nil
            }
        }
    }
    
    public func fetch<T: DatabaseValue>(type: T.Type) -> AnySequence<T?> {
        return AnySequence { self.fetchGenerator(type) }
    }
    
    public func fetchAll<T: DatabaseValue>(type: T.Type) -> [T?] {
        return Array(fetch(type))
    }
    
    public func fetchOne<T: DatabaseValue>(type: T.Type) -> T? {
        if let optionalValue = fetchGenerator(type).next() {
            // one row containing an optional value
            return optionalValue
        } else {
            // no row
            return nil
        }
    }
}

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
    
    private func rowGenerator() -> AnyGenerator<Row> {
        // TODO: Document this reset performed on each generation
        try! reset()
        var logFirstStep = database.configuration.verbose
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
            
            if logFirstStep {
                NSLog("%@", self.sql)
                logFirstStep = false
            }
            let code = sqlite3_step(self.sqliteStatement)
            switch code {
            case SQLITE_DONE:
                return nil
            case SQLITE_ROW:
                return Row(statement: self, unsafe: self.unsafe)
            default:
                try! SQLiteError.checkCResultCode(code, sqliteConnection: self.database.sqliteConnection, sql: self.sql)
                return nil
            }
        }
    }
    
    
    private func valueGenerator<T: DatabaseValue>(type type: T.Type) -> AnyGenerator<T?> {
        let rowGenerator = self.rowGenerator()
        return anyGenerator { () -> T?? in
            if let row = rowGenerator.next() {
                return Optional.Some(row.value(atIndex: 0) as T?)
            } else {
                return nil
            }
        }
    }
}

public func fetchRowGenerator(statement: SelectStatement) -> AnyGenerator<Row> {
    return statement.rowGenerator()
}

public func fetchRows(statement: SelectStatement) -> AnySequence<Row> {
    return AnySequence { fetchRowGenerator(statement) }
}

public func fetchAllRows(statement: SelectStatement) -> [Row] {
    return fetchRows(statement).map { $0 }
}

public func fetchOneRow(statement: SelectStatement) -> Row? {
    return fetchRowGenerator(statement).next()
}

public func fetchValueGenerator<T: DatabaseValue>(type: T.Type, statement: SelectStatement) -> AnyGenerator<T?> {
    return statement.valueGenerator(type: type)
}

public func fetchValues<T: DatabaseValue>(type: T.Type, statement: SelectStatement) -> AnySequence<T?> {
    return AnySequence { fetchValueGenerator(type, statement: statement) }
}

public func fetchAllValues<T: DatabaseValue>(type: T.Type, statement: SelectStatement) -> [T?] {
    return fetchValues(type, statement: statement).map { $0 }
}

public func fetchOneValue<T: DatabaseValue>(type: T.Type, statement: SelectStatement) -> T? {
    if let optionalValue = fetchValueGenerator(type, statement: statement).next() {
        // one row containing an optional value
        return optionalValue
    } else {
        // no row
        return nil
    }
}

//
//  SelectStatement.swift
//  GRDB
//
//  Created by Gwendal Roué on 30/06/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

public class SelectStatement : Statement {
    public lazy var columnCount: Int = Int(sqlite3_column_count(self.cStatement))
    public lazy var columnNames: [String] = (0..<self.columnCount).map { index in
        return String.fromCString(sqlite3_column_name(self.cStatement, Int32(index)))!
    }
    
    // MARK: - fetchRows
    
    public func fetchRows(unsafe unsafe: Bool = false) -> AnySequence<Row> {
        return AnySequence {
            return self.rowGenerator(unsafe: unsafe)
        }
    }
    
    
    // MARK: - fetchFirstRow
    
    public func fetchFirstRow(unsafe unsafe: Bool = false) -> Row? {
        return self.rowGenerator(unsafe: unsafe).next()
    }
    
    
    // MARK: - fetchValues
    
    public func fetchValues<T: DatabaseValue>(type type: T.Type, unsafe: Bool = false) -> AnySequence<T?> {
        return AnySequence {
            return self.valueGenerator(type: type, unsafe: unsafe)
        }
    }
    
    
    // MARK: - fetchFirstValue
    
    public func fetchFirstValue<T: DatabaseValue>(unsafe unsafe: Bool = false) -> T? {
        if let first = self.valueGenerator(type: T.self, unsafe: unsafe).next() {
            return first
        } else {
            return nil
        }
    }
    
    func databaseCellAtIndex(index: Int) -> DatabaseCell {
        switch sqlite3_column_type(cStatement, Int32(index)) {
        case SQLITE_NULL:
            return .Null;
        case SQLITE_INTEGER:
            return .Integer(sqlite3_column_int64(cStatement, Int32(index)))
        case SQLITE_FLOAT:
            return .Double(sqlite3_column_double(cStatement, Int32(index)))
        case SQLITE_TEXT:
            let cString = UnsafePointer<Int8>(sqlite3_column_text(cStatement, Int32(index)))
            return .Text(String.fromCString(cString)!)
        default:
            fatalError("Not implemented")
        }
    }
    
    private func rowGenerator(unsafe unsafe: Bool) -> AnyGenerator<Row> {
        // TODO: Document this reset performed on each generation
        try! reset()
        var logFirstStep = database.configuration.verbose
        return anyGenerator { () -> Row? in
            if logFirstStep {
                NSLog("%@", self.sql)
                logFirstStep = false
            }
            let code = sqlite3_step(self.cStatement)
            switch code {
            case SQLITE_DONE:
                return nil
            case SQLITE_ROW:
                return Row(statement: self, unsafe: unsafe)
            default:
                try! Error.checkCResultCode(code, cConnection: self.database.cConnection)
                return nil
            }
        }
    }
    
    
    private func valueGenerator<T: DatabaseValue>(type type: T.Type, unsafe: Bool) -> AnyGenerator<T?> {
        let rowGenerator = self.rowGenerator(unsafe: unsafe)
        return anyGenerator { () -> T?? in
            if let row = rowGenerator.next() {
                return Optional.Some(row.value(atIndex: 0) as T?)
            } else {
                return nil
            }
        }
    }
    
}

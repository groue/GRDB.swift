//
//  Row.swift
//  GRDB
//
//  Created by Gwendal Roué on 30/06/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

public struct Row {
    let statement: SelectStatement
    
    init(statement: SelectStatement) {
        self.statement = statement
    }
    
    public func boolAtIndex(index: Int) -> Bool? {
        switch sqlite3_column_type(statement.cStatement, Int32(index)) {
        case SQLITE_NULL:
            return nil
        default:
            return sqlite3_column_int(statement.cStatement, Int32(index)) != 0
        }
    }
    
    public func intAtIndex(index: Int) -> Int? {
        switch sqlite3_column_type(statement.cStatement, Int32(index)) {
        case SQLITE_NULL:
            return nil
        default:
            return Int(sqlite3_column_int(statement.cStatement, Int32(index)))
        }
    }
    
    public func int64AtIndex(index: Int) -> Int64? {
        switch sqlite3_column_type(statement.cStatement, Int32(index)) {
        case SQLITE_NULL:
            return nil
        default:
            return sqlite3_column_int64(statement.cStatement, Int32(index))
        }
    }
    
    public func doubleAtIndex(index: Int) -> Double? {
        switch sqlite3_column_type(statement.cStatement, Int32(index)) {
        case SQLITE_NULL:
            return nil;
        default:
            return sqlite3_column_double(statement.cStatement, Int32(index))
        }
    }
    
    public func stringAtIndex(index: Int) -> String? {
        switch sqlite3_column_type(statement.cStatement, Int32(index)) {
        case SQLITE_NULL:
            return nil;
        default:
            let cString = UnsafePointer<Int8>(sqlite3_column_text(statement.cStatement, Int32(index)))
            return String.fromCString(cString)!
        }
    }
    
    public func valueAtIndex(index: Int) -> DBValue? {
        switch sqlite3_column_type(statement.cStatement, Int32(index)) {
        case SQLITE_NULL:
            return nil;
        case SQLITE_INTEGER:
            return sqlite3_column_int64(statement.cStatement, Int32(index))
        case SQLITE_FLOAT:
            return sqlite3_column_double(statement.cStatement, Int32(index))
        case SQLITE_TEXT:
            let cString = UnsafePointer<Int8>(sqlite3_column_text(statement.cStatement, Int32(index)))
            return String.fromCString(cString)!
        default:
            fatalError("Not implemented")
        }
    }
    
    public var asDictionary: [String: DBValue?] {
        var dictionary = [String: DBValue?]()
        for index in 0..<statement.columnCount {
            let cString = sqlite3_column_name(statement.cStatement, Int32(index))
            let key = String.fromCString(cString)!
            dictionary[key] = valueAtIndex(index)
        }
        return dictionary
    }
}

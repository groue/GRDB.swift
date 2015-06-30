//
//  Row.swift
//  GRDB
//
//  Created by Gwendal Roué on 30/06/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

public struct Row {
    let cStatement: CStatement
    
    init(cStatement: CStatement) {
        self.cStatement = cStatement
    }
    
    public func intAtIndex(index: Int) -> Int? {
        switch sqlite3_column_type(cStatement, Int32(index)) {
        case SQLITE_NULL:
            return nil;
        default:
            return Int(sqlite3_column_int(cStatement, Int32(index)))
        }
    }
    
    public func int64AtIndex(index: Int) -> Int64? {
        switch sqlite3_column_type(cStatement, Int32(index)) {
        case SQLITE_NULL:
            return nil;
        default:
            return sqlite3_column_int64(cStatement, Int32(index))
        }
    }
    
    public func doubleAtIndex(index: Int) -> Double? {
        switch sqlite3_column_type(cStatement, Int32(index)) {
        case SQLITE_NULL:
            return nil;
        default:
            return sqlite3_column_double(cStatement, Int32(index))
        }
    }
    
    public func stringAtIndex(index: Int) -> String? {
        switch sqlite3_column_type(cStatement, Int32(index)) {
        case SQLITE_NULL:
            return nil;
        default:
            let cString = UnsafePointer<Int8>(sqlite3_column_text(cStatement, Int32(index)))
            return String.fromCString(cString)
        }
    }
}

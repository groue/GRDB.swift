//
//  Row.swift
//  GRDB
//
//  Created by Gwendal Roué on 30/06/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

protocol RowImpl {
    func databaseCellAtIndex(index: Int) -> DatabaseCell
    var dictionary: [String: DatabaseValue?] { get }
}

public struct Row {
    let impl: RowImpl
    
    init(statement: SelectStatement, unsafe: Bool) {
        if unsafe {
            self.impl = UnsafeRowImpl(statement: statement)
        } else {
            self.impl = SafeRowImpl(statement: statement)
        }
    }
    
    public func valueAtIndex(index: Int) -> DatabaseValue? {
        return impl.databaseCellAtIndex(index).value()
    }
    
    public func valueAtIndex<T: DatabaseValue>(index: Int) -> T? {
        return impl.databaseCellAtIndex(index).value() as T?
    }
    
    public var dictionary: [String: DatabaseValue?] {
        return self.impl.dictionary
    }
    
    // SafeRowImpl can be safely accessed after sqlite3_step() and sqlite3_finalize() has been called.
    private struct SafeRowImpl : RowImpl {
        let databaseCells: [DatabaseCell]
        let columnNames: [String]
        
        init(statement: SelectStatement) {
            var databaseCells = [DatabaseCell]()
            var columnNames = [String]()
            for index in 0..<statement.columnCount {
                databaseCells.append(statement.databaseCellAtIndex(index))
                let columnName = String.fromCString(sqlite3_column_name(statement.cStatement, Int32(index)))!
                columnNames.append(columnName)
            }
            self.databaseCells = databaseCells
            self.columnNames = columnNames
        }
        
        func databaseCellAtIndex(index: Int) -> DatabaseCell {
            return databaseCells[index]
        }
        
        var dictionary: [String: DatabaseValue?] {
            var dictionary = [String: DatabaseValue?]()
            for (cell, columnName) in zip(databaseCells, columnNames) {
                dictionary[columnName] = cell.value()
            }
            return dictionary
        }
    }
    
    // UnsafeRowImpl can not be safely accessed after sqlite3_step() or sqlite3_finalize() has been called.
    private struct UnsafeRowImpl : RowImpl {
        let statement: SelectStatement
        
        init(statement: SelectStatement) {
            self.statement = statement
        }
        
        func databaseCellAtIndex(index: Int) -> DatabaseCell {
            return statement.databaseCellAtIndex(index)
        }
        
        var dictionary: [String: DatabaseValue?] {
            var dictionary = [String: DatabaseValue?]()
            for index in 0..<statement.columnCount {
                let columnName = String.fromCString(sqlite3_column_name(statement.cStatement, Int32(index)))!
                dictionary[columnName] = databaseCellAtIndex(index).value()
            }
            return dictionary
        }
    }
}

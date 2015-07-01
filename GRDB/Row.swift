//
//  Row.swift
//  GRDB
//
//  Created by Gwendal Roué on 30/06/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

protocol RowImpl {
    func databaseCellAtIndex(index: Int) -> DatabaseCell
    func indexForColumnNamed(name: String) -> Int?
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
    
    public func value<T: DatabaseValue>(atIndex index: Int) -> T? {
        return impl.databaseCellAtIndex(index).value() as T?
    }
    
    public func value<T: DatabaseValue>(named columnName: String) -> T? {
        if let index = impl.indexForColumnNamed(columnName) {
            return impl.databaseCellAtIndex(index).value() as T?
        } else {
            return nil
        }
    }
    
    public var dictionary: [String: DatabaseValue?] {
        return self.impl.dictionary
    }
    
    // SafeRowImpl can be safely accessed after sqlite3_step() and sqlite3_finalize() has been called.
    private struct SafeRowImpl : RowImpl {
        let databaseCells: [DatabaseCell]
        let columnNames: [String]
        
        init(statement: SelectStatement) {
            self.databaseCells = (0..<statement.columnCount).map { index in statement.databaseCellAtIndex(index) }
            self.columnNames = statement.columnNames
        }
        
        func databaseCellAtIndex(index: Int) -> DatabaseCell {
            return databaseCells[index]
        }
        
        func indexForColumnNamed(name: String) -> Int? {
            return columnNames.indexOf(name)
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
        
        func indexForColumnNamed(name: String) -> Int? {
            return statement.columnNames.indexOf(name)
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

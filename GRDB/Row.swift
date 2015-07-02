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
    var cellDictionary: [String: DatabaseCell] { get }
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
    
    init(cellDictionary: [String: DatabaseCell]) {
        self.impl = DictionaryRowImpl(cellDictionary: cellDictionary)
    }
    
    public func hasColumn(name: String) -> Bool {
        return impl.cellDictionary.indexForKey(name) != nil
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
        var dictionary = [String: DatabaseValue?]()
        for (columnName, cell) in impl.cellDictionary {
            dictionary[columnName] = cell.value()
        }
        return dictionary
    }
    
    // SafeRowImpl can be safely accessed after sqlite3_step() and sqlite3_finalize() has been called.
    // It preserves the column ordering of the statement.
    private struct SafeRowImpl : RowImpl {
        let databaseCells: [DatabaseCell]
        let columnNames: [String]
        let cellDictionary: [String: DatabaseCell]
        
        init(statement: SelectStatement) {
            self.databaseCells = (0..<statement.columnCount).map { index in statement.databaseCellAtIndex(index) }
            self.columnNames = statement.columnNames

            var cellDictionary = [String: DatabaseCell]()
            for (cell, columnName) in zip(databaseCells, columnNames) {
                cellDictionary[columnName] = cell
            }
            self.cellDictionary = cellDictionary
        }
        
        func databaseCellAtIndex(index: Int) -> DatabaseCell {
            return databaseCells[index]
        }
        
        func indexForColumnNamed(name: String) -> Int? {
            return columnNames.indexOf(name)
        }
    }
    
    // UnsafeRowImpl can not be safely accessed after sqlite3_step() or sqlite3_finalize() has been called.
    // It preserves the column ordering of the statement.
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
        
        var cellDictionary: [String: DatabaseCell] {
            var dic = [String: DatabaseCell]()
            for index in 0..<statement.columnCount {
                let columnName = String.fromCString(sqlite3_column_name(statement.cStatement, Int32(index)))!
                dic[columnName] = statement.databaseCellAtIndex(index)
            }
            return dic
        }
    }
    
    private struct DictionaryRowImpl: RowImpl {
        let cellDictionary: [String: DatabaseCell]
        
        init (cellDictionary: [String: DatabaseCell]) {
            self.cellDictionary = cellDictionary
        }
        
        func databaseCellAtIndex(index: Int) -> DatabaseCell {
            return cellDictionary[advance(cellDictionary.startIndex, index)].1
        }
        
        func indexForColumnNamed(name: String) -> Int? {
            if let index = cellDictionary.indexForKey(name) {
                return distance(cellDictionary.startIndex, index)
            } else {
                return nil
            }
        }
    }
}

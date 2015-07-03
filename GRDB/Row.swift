//
//  Row.swift
//  GRDB
//
//  Created by Gwendal Roué on 30/06/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

protocol RowImpl {
    func sqliteValueAtIndex(index: Int) -> SQLiteValue
    func indexForColumnNamed(name: String) -> Int?
    var sqliteDictionary: [String: SQLiteValue] { get }
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
    
    public init(sqliteDictionary: [String: SQLiteValue]) {
        self.impl = DictionaryRowImpl(sqliteDictionary: sqliteDictionary)
    }
    
    public func hasColumn(name: String) -> Bool {
        return impl.sqliteDictionary.indexForKey(name) != nil
    }
    
    public func value(atIndex index: Int) -> DatabaseValue? {
        return impl.sqliteValueAtIndex(index).value()
    }
    
    public func value<DatabaseValue: GRDB.DatabaseValue>(atIndex index: Int) -> DatabaseValue? {
        return impl.sqliteValueAtIndex(index).value() as DatabaseValue?
    }
    
    public func value(named columnName: String) -> DatabaseValue? {
        if let index = impl.indexForColumnNamed(columnName) {
            return impl.sqliteValueAtIndex(index).value()
        } else {
            return nil
        }
    }
    
    public func value<DatabaseValue: GRDB.DatabaseValue>(named columnName: String) -> DatabaseValue? {
        if let index = impl.indexForColumnNamed(columnName) {
            return impl.sqliteValueAtIndex(index).value() as DatabaseValue?
        } else {
            return nil
        }
    }
    
    public var dictionary: [String: DatabaseValue?] {
        var dictionary = [String: DatabaseValue?]()
        for (columnName, cell) in impl.sqliteDictionary {
            dictionary[columnName] = cell.value()
        }
        return dictionary
    }
    
    // SafeRowImpl can be safely accessed after sqlite3_step() and sqlite3_finalize() has been called.
    // It preserves the column ordering of the statement.
    private struct SafeRowImpl : RowImpl {
        let sqliteValues: [SQLiteValue]
        let columnNames: [String]
        let sqliteDictionary: [String: SQLiteValue]
        
        init(statement: SelectStatement) {
            self.sqliteValues = (0..<statement.columnCount).map { index in statement.sqliteValueAtIndex(index) }
            self.columnNames = statement.columnNames

            var sqliteDictionary = [String: SQLiteValue]()
            for (cell, columnName) in zip(sqliteValues, columnNames) {
                sqliteDictionary[columnName] = cell
            }
            self.sqliteDictionary = sqliteDictionary
        }
        
        func sqliteValueAtIndex(index: Int) -> SQLiteValue {
            return sqliteValues[index]
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
        
        func sqliteValueAtIndex(index: Int) -> SQLiteValue {
            return statement.sqliteValueAtIndex(index)
        }
        
        func indexForColumnNamed(name: String) -> Int? {
            return statement.columnNames.indexOf(name)
        }
        
        var sqliteDictionary: [String: SQLiteValue] {
            var dic = [String: SQLiteValue]()
            for index in 0..<statement.columnCount {
                let columnName = String.fromCString(sqlite3_column_name(statement.sqliteStatement, Int32(index)))!
                dic[columnName] = statement.sqliteValueAtIndex(index)
            }
            return dic
        }
    }
    
    private struct DictionaryRowImpl: RowImpl {
        let sqliteDictionary: [String: SQLiteValue]
        
        init (sqliteDictionary: [String: SQLiteValue]) {
            self.sqliteDictionary = sqliteDictionary
        }
        
        func sqliteValueAtIndex(index: Int) -> SQLiteValue {
            return sqliteDictionary[advance(sqliteDictionary.startIndex, index)].1
        }
        
        func indexForColumnNamed(name: String) -> Int? {
            if let index = sqliteDictionary.indexForKey(name) {
                return distance(sqliteDictionary.startIndex, index)
            } else {
                return nil
            }
        }
    }
}

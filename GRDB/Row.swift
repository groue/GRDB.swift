//
//  Row.swift
//  GRDB
//
//  Created by Gwendal Roué on 30/06/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

protocol RowImpl {
    var count: Int { get }
    func sqliteValueAtIndex(index: Int) -> SQLiteValue
    func columnNameAtIndex(index: Int) -> String
    func indexForColumnNamed(name: String) -> Int?
    var sqliteDictionary: [String: SQLiteValue] { get }
}

public struct Row: CollectionType {
    let impl: RowImpl
    
    
    // MARK: - Initializers
    
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
    
    
    // MARK: - Values
    
    public func hasColumn(name: String) -> Bool {
        return impl.sqliteDictionary.indexForKey(name) != nil
    }
    
    public func value(atIndex index: Int) -> DatabaseValueType? {
        return impl.sqliteValueAtIndex(index).value()
    }
    
    public func value<DatabaseValue: DatabaseValueType>(atIndex index: Int) -> DatabaseValue? {
        return impl.sqliteValueAtIndex(index).value()
    }
    
    public func value(named columnName: String) -> DatabaseValueType? {
        if let index = impl.indexForColumnNamed(columnName) {
            return impl.sqliteValueAtIndex(index).value()
        } else {
            return nil
        }
    }
    
    public func value<DatabaseValue: DatabaseValueType>(named columnName: String) -> DatabaseValue? {
        if let index = impl.indexForColumnNamed(columnName) {
            return impl.sqliteValueAtIndex(index).value()
        } else {
            return nil
        }
    }
    
    public var dictionary: [String: DatabaseValueType?] {
        var dictionary = [String: DatabaseValueType?]()
        for (columnName, cell) in impl.sqliteDictionary {
            dictionary[columnName] = cell.value()
        }
        return dictionary
    }
    
    
    // MARK: - CollectionType
    
    // TODO: test the row as collection
    
    // Use a custom index, so that we eventually can provide a subscript(Int)
    // that returns a DatabaseValueType.
    public struct RowIndex: ForwardIndexType {
        let index: Int
        
        init(_ index: Int) {
            self.index = index
        }
        
        public func successor() -> RowIndex {
            return RowIndex(index+1)
        }
    }
    
    public func generate() -> IndexingGenerator<Row> {
        return IndexingGenerator(self)
    }
    
    public var startIndex: RowIndex {
        return Index(0)
    }
    
    public var endIndex: RowIndex {
        return Index(impl.count)
    }
    
    public subscript(index: RowIndex) -> (String, SQLiteValue) {
        return (
            self.impl.columnNameAtIndex(index.index),
            self.impl.sqliteValueAtIndex(index.index))
    }
    
    
    // MARK: - DictionaryRowImpl
    
    private struct DictionaryRowImpl: RowImpl {
        let sqliteDictionary: [String: SQLiteValue]
        
        var count: Int {
            return sqliteDictionary.count
        }
        
        init (sqliteDictionary: [String: SQLiteValue]) {
            self.sqliteDictionary = sqliteDictionary
        }
        
        func sqliteValueAtIndex(index: Int) -> SQLiteValue {
            return sqliteDictionary[advance(sqliteDictionary.startIndex, index)].1
        }
        
        func columnNameAtIndex(index: Int) -> String {
            return sqliteDictionary[advance(sqliteDictionary.startIndex, index)].0
        }
        
        func indexForColumnNamed(name: String) -> Int? {
            if let index = sqliteDictionary.indexForKey(name) {
                return distance(sqliteDictionary.startIndex, index)
            } else {
                return nil
            }
        }
    }
    
    
    // MARK: - SafeRowImpl
    
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
        
        var count: Int {
            return columnNames.count
        }
        
        func sqliteValueAtIndex(index: Int) -> SQLiteValue {
            return sqliteValues[index]
        }
        
        func columnNameAtIndex(index: Int) -> String {
            return columnNames[index]
        }
        
        func indexForColumnNamed(name: String) -> Int? {
            return columnNames.indexOf(name)
        }
    }
    
    
    // MARK: - UnsafeRowImpl
    
    // UnsafeRowImpl can not be safely accessed after sqlite3_step() or sqlite3_finalize() has been called.
    // It preserves the column ordering of the statement.
    private struct UnsafeRowImpl : RowImpl {
        let statement: SelectStatement
        
        init(statement: SelectStatement) {
            self.statement = statement
        }
        
        var count: Int {
            return statement.columnCount
        }
        
        func sqliteValueAtIndex(index: Int) -> SQLiteValue {
            return statement.sqliteValueAtIndex(index)
        }
        
        func columnNameAtIndex(index: Int) -> String {
            return statement.columnNames[index]
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
}

public func ==(lhs: Row.RowIndex, rhs: Row.RowIndex) -> Bool {
    return lhs.index == rhs.index
}

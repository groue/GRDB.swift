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
    
    // Used by RowModel so that it can call RowModel.updateFromDatabaseRow()
    // to set the ID after an insertion.
    public init(sqliteDictionary: [String: SQLiteValue]) {
        self.impl = DictionaryRowImpl(sqliteDictionary: sqliteDictionary)
    }
    
    
    // MARK: - Values
    
    // if row.hasColumn("name") { self.name = row.value(named:"name") }
    public func hasColumn(name: String) -> Bool {
        return impl.sqliteDictionary.indexForKey(name) != nil
    }
    
    // if row.value(atIndex:0) == nil { ... }
    public func value(atIndex index: Int) -> SQLiteValueConvertible? {
        return impl.sqliteValueAtIndex(index).value()
    }
    
    // let name:String? = row.value(atIndex: 0)
    public func value<Value: SQLiteValueConvertible>(atIndex index: Int) -> Value? {
        return impl.sqliteValueAtIndex(index).value()
    }
    
    // if row.value(named: "name") == nil { ... }
    public func value(named columnName: String) -> SQLiteValueConvertible? {
        if let index = impl.indexForColumnNamed(columnName) {
            return impl.sqliteValueAtIndex(index).value()
        } else {
            return nil
        }
    }
    
    // let name:String? = row.value(named: "name")
    public func value<Value: SQLiteValueConvertible>(named columnName: String) -> Value? {
        if let index = impl.indexForColumnNamed(columnName) {
            return impl.sqliteValueAtIndex(index).value()
        } else {
            return nil
        }
    }
    
    // For tests.
    func sqliteValue(atIndex index: Int) -> SQLiteValue {
        return impl.sqliteValueAtIndex(index)
    }
    
    
    // MARK: - CollectionType
    
    // Row needs an index type in order to adopt CollectionType.
    //
    // We use a custom index, so that we eventually can provide a subscript(Int)
    // that returns a SQLiteValueConvertible.
    public struct RowIndex: ForwardIndexType {
        let index: Int
        
        init(_ index: Int) {
            self.index = index
        }
        
        public func successor() -> RowIndex {
            return RowIndex(index+1)
        }
    }
    
    // Required by Row adoption of CollectionType
    public func generate() -> IndexingGenerator<Row> {
        return IndexingGenerator(self)
    }
    
    // Required by Row adoption of CollectionType
    public var startIndex: RowIndex {
        return Index(0)
    }
    
    // Required by Row adoption of CollectionType
    public var endIndex: RowIndex {
        return Index(impl.count)
    }
    
    // Required by Row adoption of CollectionType
    public subscript(index: RowIndex) -> (String, SQLiteValue) {
        return (
            self.impl.columnNameAtIndex(index.index),
            self.impl.sqliteValueAtIndex(index.index))
    }
    
    
    // MARK: - DictionaryRowImpl
    
    // Implements a Rows on a top of a dictionary [String: SQLiteValue]
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
    
    // Implements a Rows on a top of a statement.
    //
    // It makes Array(rowSequence) work: as the sequence is iterated,
    // SafeRowImpl *copies* statement results.
    private struct SafeRowImpl : RowImpl {
        let sqliteValues: [SQLiteValue]
        let columnNames: [String]
        let sqliteDictionary: [String: SQLiteValue]
        
        init(statement: SelectStatement) {
            self.sqliteValues = (0..<statement.columnCount).map { index in statement.sqliteValueAtIndex(index) }
            self.columnNames = statement.columnNames

            var sqliteDictionary = [String: SQLiteValue]()
            for (sqliteValue, columnName) in zip(sqliteValues, columnNames) {
                sqliteDictionary[columnName] = sqliteValue
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
    
    // Implements a Rows on a top of a statement.
    //
    // It can't make Array(rowSequence) work: as the sequence is iterated,
    // UnsafeRowImpl *does not* copy statement results, and those results are
    // lost.
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

// Required by Row adoption of CollectionType
public func ==(lhs: Row.RowIndex, rhs: Row.RowIndex) -> Bool {
    return lhs.index == rhs.index
}

//
// GRDB.swift
// https://github.com/groue/GRDB.swift
// Copyright (c) 2015 Gwendal Roué
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.


/**
A row is the result of a database query.
*/
public struct Row: CollectionType {
    
    
    // MARK: - SQLiteValue
    
    /// Helper method for tests.
    /// Public experimental (TODO: document)
    public subscript(index: Int) -> SQLiteValue {
        return impl.sqliteValue(atIndex: index)
    }
    
    /// Public Experimental (TODO: document)
    public subscript(columnName: String) -> SQLiteValue? {
        if let index = impl.indexForColumn(named: columnName) {
            return impl.sqliteValue(atIndex: index)
        } else {
            return nil
        }
    }
    
    
    // MARK: - SQLiteValueConvertible value
    
    /**
    Returns the value at given index.
    
    Indexes span from 0 for the leftmost column to (row.count - 1) for the
    righmost column.
    
    If not nil (for NULL), its type is guaranteed to be one of the following:
    Int64, Double, String, and Blob.
    
        let value = row.value(atIndex: 0)
    
    - parameter index: The index of a column.
    - returns: An optional SQLiteValueConvertible.
    */
    public func value(atIndex index: Int) -> SQLiteValueConvertible? {
        return impl.sqliteValue(atIndex: index).value()
    }
    
    /**
    Returns the value at given index, converted to the requested type.
    
    Indexes span from 0 for the leftmost column to (row.count - 1) for the
    righmost column.
    
    The conversion returns nil if the fetched SQLite value is NULL, or can't be
    converted to the requested type:
    
        let value: Bool? = row.value(atIndex: 0)
        let value: Int? = row.value(atIndex: 0)
        let value: Double? = row.value(atIndex: 0)
    
    Your custom types that adopt the SQLiteValueConvertible protocol handle
    their own conversion from raw SQLite values. Yet, here is the reference for
    built-in types:
    
        SQLite value: | NULL    INTEGER         REAL            TEXT        BLOB
        --------------|---------------------------------------------------------
        Bool          | nil     false if 0      false if 0.0    nil         nil
        Int           | nil     Int(*)          Int(*)          nil         nil
        Int64         | nil     Int64           Int64(*)        nil         nil
        Double        | nil     Double          Double          nil         nil
        String        | nil     nil             nil             String      nil
        Blob          | nil     nil             nil             nil         Blob
    
    (*) Conversions to Int and Int64 crash if the value is too big.
    
    - parameter index: The index of a column.
    - returns: An optional *Value*.
    */
    public func value<Value: SQLiteValueConvertible>(atIndex index: Int) -> Value? {
        return impl.sqliteValue(atIndex: index).value()
    }
    
    /**
    Returns the value for the given column.
    
    If not nil (for NULL), its type is guaranteed to be one of the following:
    Int64, Double, String, and Blob.
    
        let value = row.value(named: "name")
    
    - parameter name: A column name.
    - returns: An optional SQLiteValueConvertible.
    */
    public func value(named columnName: String) -> SQLiteValueConvertible? {
        if let index = impl.indexForColumn(named: columnName) {
            return impl.sqliteValue(atIndex: index).value()
        } else {
            return nil
        }
    }
    
    /**
    Returns the value for the given column, converted to the requested type.
    
    The conversion returns nil if the fetched SQLite value is NULL, or can't be
    converted to the requested type:
    
        let value: Bool? = row.value(named: "count")
        let value: Int? = row.value(named: "count")
        let value: Double? = row.value(named: "count")
    
    Your custom types that adopt the SQLiteValueConvertible protocol handle
    their own conversion from raw SQLite values. Yet, here is the reference for
    built-in types:
    
        SQLite value: | NULL    INTEGER         REAL            TEXT        BLOB
        --------------|---------------------------------------------------------
        Bool          | nil     false if 0      false if 0.0    nil         nil
        Int           | nil     Int(*)          Int(*)          nil         nil
        Int64         | nil     Int64           Int64(*)        nil         nil
        Double        | nil     Double          Double          nil         nil
        String        | nil     nil             nil             String      nil
        Blob          | nil     nil             nil             nil         Blob
    
    (*) Conversions to Int and Int64 crash if the value is too big.
    
    - parameter name: A column name.
    - returns: An optional *Value*.
    */
    public func value<Value: SQLiteValueConvertible>(named columnName: String) -> Value? {
        if let index = impl.indexForColumn(named: columnName) {
            return impl.sqliteValue(atIndex: index).value()
        } else {
            return nil
        }
    }
    
    
    // MARK: - Collection of (columnName, sqliteValue)
    
    /**
    Row is a *collection* of (columnName, sqliteValue) pairs, ordered from left
    to right.

    Returns a *generator* over elements.
    */
    public func generate() -> IndexingGenerator<Row> {
        return IndexingGenerator(self)
    }
    
    /**
    Row is a *collection* of (columnName, sqliteValue) pairs, ordered from left
    to right.

    The index of the first element.
    */
    public var startIndex: RowIndex {
        return Index(0)
    }
    
    /**
    Row is a *collection* of (columnName, sqliteValue) pairs, ordered from left
    to right.

    Return the "past-the-end" index, successor of the index of the last element.
    */
    public var endIndex: RowIndex {
        return Index(impl.columnCount)
    }
    
    /**
    Row is a *collection* of (columnName, sqliteValue) pairs, ordered from left
    to right.
    
    Returns the element at given index.
    */
    public subscript(index: RowIndex) -> (String, SQLiteValue) {
        return (
            self.impl.columnName(atIndex: index.index),
            self.impl.sqliteValue(atIndex: index.index))
    }
    
    
    // MARK: - Not Public
    
    /**
    There are 3 different row implementations:

    - DictionaryRowImpl
    - SafeRowImpl
    - UnsafeRowImpl
    */
    let impl: RowImpl
    
    
    // MARK: Initializers
    
    /**
    Builds a row from the *current state* of the SQLite statement.
    
    If the *unsafe* argument is false, the row is implemented on top of
    SafeRowImpl, which *copies* the SQLite values so that the SQLite statement
    can be further iterated without corrupting the row.
    
    If the *unsafe* argument is true, the row is implemented on top of
    UnsafeRowImpl, which *does not* copy the SQLite values. Such an unsafe row
    is invalidated when the SQLite statement is further iterated.
    */
    init(statement: SelectStatement, unsafe: Bool) {
        if unsafe {
            self.impl = UnsafeRowImpl(statement: statement)
        } else {
            self.impl = SafeRowImpl(statement: statement)
        }
    }
    
    /**
    Builds a row from an ad-hoc dictionary.

    This initializer is used by RowModel.insert() so that it can call
    RowModel.updateFromDatabaseRow() to set the ID after the insertion.
    */
    public init(sqliteDictionary: [String: SQLiteValue]) {
        self.impl = DictionaryRowImpl(sqliteDictionary: sqliteDictionary)
    }
    
    
    // MARK: DictionaryRowImpl
    
    /// See Row.init(sqliteDictionary:)
    private struct DictionaryRowImpl : RowImpl {
        let sqliteDictionary: [String: SQLiteValue]
        
        var columnCount: Int {
            return sqliteDictionary.count
        }
        
        init (sqliteDictionary: [String: SQLiteValue]) {
            self.sqliteDictionary = sqliteDictionary
        }
        
        func sqliteValue(atIndex index: Int) -> SQLiteValue {
            return sqliteDictionary[advance(sqliteDictionary.startIndex, index)].1
        }
        
        func columnName(atIndex index: Int) -> String {
            return sqliteDictionary[advance(sqliteDictionary.startIndex, index)].0
        }
        
        func indexForColumn(named name: String) -> Int? {
            if let index = sqliteDictionary.indexForKey(name) {
                return distance(sqliteDictionary.startIndex, index)
            } else {
                return nil
            }
        }
    }
    
    
    // MARK: SafeRowImpl
    
    /// See Row.init(statement:unsafe:)
    private struct SafeRowImpl : RowImpl {
        let sqliteValues: [SQLiteValue]
        let columnNames: [String]
        let sqliteDictionary: [String: SQLiteValue]
        
        init(statement: SelectStatement) {
            self.sqliteValues = (0..<statement.columnCount).map { index in statement.sqliteValue(atIndex: index) }
            self.columnNames = statement.columnNames

            var sqliteDictionary = [String: SQLiteValue]()
            for (sqliteValue, columnName) in zip(sqliteValues, columnNames) {
                sqliteDictionary[columnName] = sqliteValue
            }
            self.sqliteDictionary = sqliteDictionary
        }
        
        var columnCount: Int {
            return columnNames.count
        }
        
        func sqliteValue(atIndex index: Int) -> SQLiteValue {
            return sqliteValues[index]
        }
        
        func columnName(atIndex index: Int) -> String {
            return columnNames[index]
        }
        
        func indexForColumn(named name: String) -> Int? {
            return columnNames.indexOf(name)
        }
    }
    
    
    // MARK: UnsafeRowImpl
    
    /// See Row.init(statement:unsafe:)
    private struct UnsafeRowImpl : RowImpl {
        let statement: SelectStatement
        
        init(statement: SelectStatement) {
            self.statement = statement
        }
        
        var columnCount: Int {
            return statement.columnCount
        }
        
        func sqliteValue(atIndex index: Int) -> SQLiteValue {
            return statement.sqliteValue(atIndex: index)
        }
        
        func columnName(atIndex index: Int) -> String {
            return statement.columnNames[index]
        }
        
        func indexForColumn(named name: String) -> Int? {
            return statement.columnNames.indexOf(name)
        }
        
        var sqliteDictionary: [String: SQLiteValue] {
            var dic = [String: SQLiteValue]()
            for index in 0..<statement.columnCount {
                let columnName = String.fromCString(sqlite3_column_name(statement.sqliteStatement, Int32(index)))!
                dic[columnName] = statement.sqliteValue(atIndex: index)
            }
            return dic
        }
    }
}

// The protocol for Row underlying implementation
protocol RowImpl {
    var columnCount: Int { get }
    func sqliteValue(atIndex index: Int) -> SQLiteValue
    func columnName(atIndex index: Int) -> String
    func indexForColumn(named name: String) -> Int?
    var sqliteDictionary: [String: SQLiteValue] { get }
}


/// Used to access the (columnName, sqliteValue) pairs in a Row.
public struct RowIndex: ForwardIndexType, BidirectionalIndexType, RandomAccessIndexType {
    let index: Int
    init(_ index: Int) { self.index = index }
    public func successor() -> RowIndex { return RowIndex(index + 1) }
    public func predecessor() -> RowIndex { return RowIndex(index - 1) }
    public func distanceTo(other: RowIndex) -> Int { return other.index - index }
    public func advancedBy(n: Int) -> RowIndex { return RowIndex(index + n) }
}

// Equatable implementation for RowIndex
public func ==(lhs: RowIndex, rhs: RowIndex) -> Bool {
    return lhs.index == rhs.index
}

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
    
    // MARK: - Extracting Swift Values
    
    /**
    Returns the value at given index.
    
    Indexes span from 0 for the leftmost column to (row.count - 1) for the
    righmost column.
    
    If not nil (for the database NULL), its type is guaranteed to be one of the
    following: Int64, Double, String, and Blob.
    
        let value = row.value(atIndex: 0)
    
    - parameter index: The index of a column.
    - returns: An optional DatabaseValueConvertible.
    */
    public func value(atIndex index: Int) -> DatabaseValueConvertible? {
        return impl
            .databaseValue(atIndex: index)
            .value()
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
    
    **WARNING**: type casting requires a very careful use of the `as` operator
    (see [rdar://problem/21676393](http://openradar.appspot.com/radar?id=4951414862249984)):
    
        row.value(atIndex: 0)! as Int   // OK: Int
        row.value(atIndex: 0) as Int?   // OK: Int?
        row.value(atIndex: 0) as? Int   // NO NO NO DON'T DO THAT!
    
    Your custom types that adopt the DatabaseValueConvertible protocol handle
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
    public func value<Value: DatabaseValueConvertible>(atIndex index: Int) -> Value? {
        return impl
            .databaseValue(atIndex: index)
            .value()
    }
    
    /**
    Returns the value for the given column.
    
    If not nil (for the database NULL), its type is guaranteed to be one of the
    following: Int64, Double, String, and Blob.
    
        let value = row.value(named: "name")
    
    - parameter name: A column name.
    - returns: An optional DatabaseValueConvertible.
    */
    public func value(named columnName: String) -> DatabaseValueConvertible? {
        let index = impl.indexForColumn(named: columnName)!
        return impl.databaseValue(atIndex: index).value()
    }
    
    /**
    Returns the value for the given column, converted to the requested type.
    
    The conversion returns nil if the fetched SQLite value is NULL, or can't be
    converted to the requested type:
    
        let value: Bool? = row.value(named: "count")
        let value: Int? = row.value(named: "count")
        let value: Double? = row.value(named: "count")
    
    **WARNING**: type casting requires a very careful use of the `as` operator
    (see [rdar://problem/21676393](http://openradar.appspot.com/radar?id=4951414862249984)):
    
        row.value(named: "count")! as Int   // OK: Int
        row.value(named: "count") as Int?   // OK: Int?
        row.value(named: "count") as? Int   // NO NO NO DON'T DO THAT!
    
    Your custom types that adopt the DatabaseValueConvertible protocol handle
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
    public func value<Value: DatabaseValueConvertible>(named columnName: String) -> Value? {
        let index = impl.indexForColumn(named: columnName)!
        return impl.databaseValue(atIndex: index).value()
    }
    
    
    // MARK: - Extracting DatabaseValue
    
    /**
    Returns a DatabaseValue, the intermediate type between SQLite and your
    values, if and only if the row contains the requested column.
    
        // Test if the column `name` is present:
        if let databaseValue = row["name"] {
            let name: String? = databaseValue.value()
        }

    - parameter columnName: A column name.
    - returns: A DatabaseValue if the row contains the requested column.
    */
    public subscript(columnName: String) -> DatabaseValue? {
        if let index = impl.indexForColumn(named: columnName) {
            return impl.databaseValue(atIndex: index)
        } else {
            return nil
        }
    }
    
    
    // MARK: - Row as a Collection of (ColumnName, DatabaseValue) Pairs
    
    /// Returns a *generator* over (ColumnName, DatabaseValue) pairs, from left
    /// to right.
    public func generate() -> IndexingGenerator<Row> {
        return IndexingGenerator(self)
    }
    
    /// The index of the first (ColumnName, DatabaseValue) pair.
    public var startIndex: RowIndex {
        return Index(0)
    }
    
    /// The "past-the-end" index, successor of the index of the last
    /// (ColumnName, DatabaseValue) pair.
    public var endIndex: RowIndex {
        return Index(impl.columnCount)
    }
    
    /// Returns the (ColumnName, DatabaseValue) pair at given index.
    public subscript(index: RowIndex) -> (String, DatabaseValue) {
        return (
            self.impl.columnName(atIndex: index.index),
            self.impl.databaseValue(atIndex: index.index))
    }
    
    
    // MARK: - Not Public
    
    /**
    There are 3 different row implementations:
    
    - DictionaryRowImpl
    - SafeRowImpl
    - UnsafeRowImpl
    */
    let impl: RowImpl
    
    /**
    Builds a row from an dictionary of values.
    
        let dic = [
            "name": .Text("Arthur"),
            "booksCount": .Integer(0)]
        let row = Row(databaseDictionary: dic)
    
    - parameter databaseDictionary: A dictionary of DatabaseValue.
    */
    init(dictionary: [String: DatabaseValueConvertible?]) {
        var databaseDictionary = [String: DatabaseValue]()
        for (key, value) in dictionary {
            if let value = value {
                databaseDictionary[key] = value.databaseValue
            } else {
                databaseDictionary[key] = .Null
            }
        }
        self.impl = DictionaryRowImpl(databaseDictionary: databaseDictionary)
    }
    
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
    
    func containsSameColumnsAndValuesAsRow(other: Row) -> Bool {
        guard count == other.count else {
            return true
        }
        for (key, dbv) in self {
            guard let otherDbv = other[key] else {
                return true
            }
            if dbv != otherDbv {
                return true
            }
        }
        return false
    }
    
    
    // MARK: - DictionaryRowImpl
    
    /// See Row.init(databaseDictionary:)
    private struct DictionaryRowImpl : RowImpl {
        let databaseDictionary: [String: DatabaseValue]
        
        var columnCount: Int {
            return databaseDictionary.count
        }
        
        init (databaseDictionary: [String: DatabaseValue]) {
            self.databaseDictionary = databaseDictionary
        }
        
        func databaseValue(atIndex index: Int) -> DatabaseValue {
            return databaseDictionary[advance(databaseDictionary.startIndex, index)].1
        }
        
        func columnName(atIndex index: Int) -> String {
            return databaseDictionary[advance(databaseDictionary.startIndex, index)].0
        }
        
        func indexForColumn(named name: String) -> Int? {
            if let index = databaseDictionary.indexForKey(name) {
                return distance(databaseDictionary.startIndex, index)
            } else {
                return nil
            }
        }
    }
    
    
    // MARK: - SafeRowImpl
    
    /// See Row.init(statement:unsafe:)
    private struct SafeRowImpl : RowImpl {
        let databaseValues: [DatabaseValue]
        let columnNames: [String]
        let databaseDictionary: [String: DatabaseValue]
        
        init(statement: SelectStatement) {
            self.databaseValues = (0..<statement.columnCount).map { index in statement.databaseValue(atIndex: index) }
            self.columnNames = statement.columnNames

            var databaseDictionary = [String: DatabaseValue]()
            for (databaseValue, columnName) in zip(databaseValues, columnNames) {
                databaseDictionary[columnName] = databaseValue
            }
            self.databaseDictionary = databaseDictionary
        }
        
        var columnCount: Int {
            return columnNames.count
        }
        
        func databaseValue(atIndex index: Int) -> DatabaseValue {
            return databaseValues[index]
        }
        
        func columnName(atIndex index: Int) -> String {
            return columnNames[index]
        }
        
        func indexForColumn(named name: String) -> Int? {
            return columnNames.indexOf(name)
        }
    }
    
    
    // MARK: - UnsafeRowImpl
    
    /// See Row.init(statement:unsafe:)
    private struct UnsafeRowImpl : RowImpl {
        let statement: SelectStatement
        
        init(statement: SelectStatement) {
            self.statement = statement
        }
        
        var columnCount: Int {
            return statement.columnCount
        }
        
        func databaseValue(atIndex index: Int) -> DatabaseValue {
            return statement.databaseValue(atIndex: index)
        }
        
        func columnName(atIndex index: Int) -> String {
            return statement.columnNames[index]
        }
        
        func indexForColumn(named name: String) -> Int? {
            return statement.columnNames.indexOf(name)
        }
        
        var databaseDictionary: [String: DatabaseValue] {
            var dic = [String: DatabaseValue]()
            for index in 0..<statement.columnCount {
                let columnName = String.fromCString(sqlite3_column_name(statement.sqliteStatement, Int32(index)))!
                dic[columnName] = statement.databaseValue(atIndex: index)
            }
            return dic
        }
    }
}

// The protocol for Row underlying implementation
protocol RowImpl {
    var columnCount: Int { get }
    func databaseValue(atIndex index: Int) -> DatabaseValue
    func columnName(atIndex index: Int) -> String
    func indexForColumn(named name: String) -> Int?
    var databaseDictionary: [String: DatabaseValue] { get }
}


/// Indexes to (columnName, databaseValue) pairs in a database row.
public struct RowIndex: ForwardIndexType, BidirectionalIndexType, RandomAccessIndexType {
    let index: Int
    init(_ index: Int) { self.index = index }
    
    /// The index of the next (ColumnName, DatabaseValue) pair in a row.
    public func successor() -> RowIndex { return RowIndex(index + 1) }

    /// The index of the previous (ColumnName, DatabaseValue) pair in a row.
    public func predecessor() -> RowIndex { return RowIndex(index - 1) }

    /// The number of columns between two (ColumnName, DatabaseValue) pairs in
    /// a row.
    public func distanceTo(other: RowIndex) -> Int { return other.index - index }
    
    /// Return `self` offset by `n` steps.
    public func advancedBy(n: Int) -> RowIndex { return RowIndex(index + n) }
}

/// Equatable implementation for RowIndex
public func ==(lhs: RowIndex, rhs: RowIndex) -> Bool {
    return lhs.index == rhs.index
}

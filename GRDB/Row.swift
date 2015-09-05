/**
A row is the result of a database query.
*/
public struct Row: CollectionType {
    
    
    // MARK: - Building rows
    
    /**
    Builds a row from an dictionary of values.
    
    - parameter databaseDictionary: A dictionary of DatabaseValue.
    */
    public init(dictionary: [String: DatabaseValueConvertible?]) {
        var databaseDictionary = [String: DatabaseValue]()
        for (key, value) in dictionary {
            databaseDictionary[key] = value?.databaseValue ?? .Null
        }
        self.impl = DictionaryRowImpl(databaseDictionary: databaseDictionary)
    }
    
    
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
        // IMPLEMENTATION NOTE
        // This method has a single know use case: checking if the value is nil,
        // as in:
        //
        //     if row.value(atIndex: 0) != nil { ... }
        //
        // Without this method, the code above would not compile.
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
        // IMPLEMENTATION NOTE
        // This method has a single know use case: checking if the value is nil,
        // as in:
        //
        //     if row.value(named: "foo") != nil { ... }
        //
        // Without this method, the code above would not compile.
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
    
    /// The number of columns in the row.
    public var count: Int {
        return impl.count
    }
    
    /// The names of columns in the row.
    ///
    /// Columns appear in the same order as they occur as the `.0` member
    /// of column-value pairs in `self`.
    public var columnNames: LazyMapCollection<Row, String> {
        return LazyMapCollection(self) { $0.0 }
    }
    
    /// The database values in the row.
    ///
    /// Values appear in the same order as they occur as the `.1` member
    /// of column-value pairs in `self`.
    public var databaseValues: LazyMapCollection<Row, DatabaseValue> {
        return LazyMapCollection(self) { $0.1 }
    }
    
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
        return Index(impl.count)
    }
    
    /// Returns the (ColumnName, DatabaseValue) pair at given index.
    public subscript(index: RowIndex) -> (String, DatabaseValue) {
        return (
            self.impl.columnName(atIndex: index.index),
            self.impl.databaseValue(atIndex: index.index))
    }
    
    
    // MARK: - Fetching From SelectStatement
    
    /**
    Fetches a lazy sequence of rows.
    
        let statement = db.selectStatement("SELECT ...")
        let rows = Row.fetch(statement)
    
    - parameter statement: The statement to run.
    - parameter arguments: Optional statement arguments.
    - returns: A lazy sequence of rows.
    */
    public static func fetch(statement: SelectStatement, arguments: StatementArguments? = nil) -> AnySequence<Row> {
        return statement.fetchRows(arguments: arguments)
    }
    
    /**
    Fetches an array of rows.
    
        let statement = db.selectStatement("SELECT ...")
        let rows = Row.fetchAll(statement)
    
    - parameter statement: The statement to run.
    - parameter arguments: Optional statement arguments.
    - returns: An array of rows.
    */
    public static func fetchAll(statement: SelectStatement, arguments: StatementArguments? = nil) -> [Row] {
        return Array(fetch(statement, arguments: arguments))
    }
    
    /**
    Fetches a single row.
    
        let statement = db.selectStatement("SELECT ...")
        let row = Row.fetchOne(statement)
    
    - parameter statement: The statement to run.
    - parameter arguments: Optional statement arguments.
    - returns: An optional row.
    */
    public static func fetchOne(statement: SelectStatement, arguments: StatementArguments? = nil) -> Row? {
        return fetch(statement, arguments: arguments).generate().next()
    }
    
    
    // MARK: - Fetching From Database
    
    /**
    Fetches a lazy sequence of rows.

        let rows = Row.fetch(db, "SELECT ...")

    - parameter db: A Database.
    - parameter sql: An SQL query.
    - parameter arguments: Optional statement arguments.
    - returns: A lazy sequence of rows.
    */
    public static func fetch(db: Database, _ sql: String, arguments: StatementArguments? = nil) -> AnySequence<Row> {
        return fetch(db.selectStatement(sql), arguments: arguments)
    }
    
    /**
    Fetches an array of rows.
    
        let rows = Row.fetchAll(db, "SELECT ...")
    
    - parameter db: A Database.
    - parameter sql: An SQL query.
    - parameter arguments: Optional statement arguments.
    - returns: An array of rows.
    */
    public static func fetchAll(db: Database, _ sql: String, arguments: StatementArguments? = nil) -> [Row] {
        return Array(fetch(db, sql, arguments: arguments))
    }
    
    /**
    Fetches a single row.
    
        let row = Row.fetchOne(db, "SELECT ...")
    
    - parameter db: A Database.
    - parameter sql: An SQL query.
    - parameter arguments: Optional statement arguments.
    - returns: An optional row.
    */
    public static func fetchOne(db: Database, _ sql: String, arguments: StatementArguments? = nil) -> Row? {
        return fetch(db, sql, arguments: arguments).generate().next()
    }

    
    // MARK: - Not Public
    
    let impl: RowImpl
    
    /**
    Builds a row from the *current state* of the SQLite statement.
    
    The row is implemented on top of SafeRowImpl, which *copies* the values from
    the SQLite statement so that it can be further iterated without corrupting
    the row.
    */
    init(statement: SelectStatement) {
        self.impl = SafeRowImpl(statement: statement)
    }
    
    
    // MARK: - DictionaryRowImpl
    
    /// See Row.init(databaseDictionary:)
    private struct DictionaryRowImpl : RowImpl {
        let databaseDictionary: [String: DatabaseValue]
        
        var count: Int {
            return databaseDictionary.count
        }
        
        init (databaseDictionary: [String: DatabaseValue]) {
            self.databaseDictionary = databaseDictionary
        }
        
        func databaseValue(atIndex index: Int) -> DatabaseValue {
            return databaseDictionary[databaseDictionary.startIndex.advancedBy(index)].1
        }
        
        func columnName(atIndex index: Int) -> String {
            return databaseDictionary[databaseDictionary.startIndex.advancedBy(index)].0
        }
        
        func indexForColumn(named name: String) -> Int? {
            if let index = databaseDictionary.indexForKey(name) {
                return databaseDictionary.startIndex.distanceTo(index)
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
        
        var count: Int {
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
}

/// Row adopts CustomStringConvertible.
extension Row: CustomStringConvertible {
    /// A textual representation of `self`.
    public var description: String {
        return "<Row"
            + map { (column, dbv) in
                " \(column):\(dbv)"
                }.joinWithSeparator("")
            + ">"
    }
}

// The protocol for Row underlying implementation
protocol RowImpl {
    var count: Int { get }
    func databaseValue(atIndex index: Int) -> DatabaseValue
    func columnName(atIndex index: Int) -> String
    func indexForColumn(named name: String) -> Int?
    var databaseDictionary: [String: DatabaseValue] { get }
}


/// Indexes to (columnName, databaseValue) pairs in a database row.
public struct RowIndex: ForwardIndexType, BidirectionalIndexType, RandomAccessIndexType {
    public typealias Distance = Int
    
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

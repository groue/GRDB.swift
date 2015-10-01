/**
A database row.
*/
public final class Row: CollectionType {
    // IMPLEMENTATION NOTE:
    //
    // Row could be a struct. It is a class for a single reason: so that is
    // looks like it is inherently mutable.
    //
    // This helps documentation a lot. The "reused" word in the following
    // documentation sentence would look weird if rows were structs:
    // 
    // > Fetched rows are reused during the iteration of a query, for
    // > performance reasons: make sure to make a copy of it whenever you want
    // > to keep a specific one: `row.copy()`.
    
    
    // MARK: - Building rows
    
    /**
    Builds a row from an dictionary of values.
    */
    public init(dictionary: [String: DatabaseValueConvertible?]) {
        var databaseDictionary = [String: DatabaseValue]()
        for (key, value) in dictionary {
            databaseDictionary[key] = value?.databaseValue ?? .Null
        }
        self.sqliteStatement = nil
        self.impl = DictionaryRowImpl(databaseDictionary: databaseDictionary)
    }
    
    /**
    Returns a copy of the row.
    
    Fetched rows are reused during the iteration of a query, for performance
    reasons: make sure to make a copy of it whenever you want to keep a specific
    one: `row.copy()`.
    */
    @warn_unused_result
    public func copy() -> Row {
        // Return a row that is detached from its eventual SQLite statement:
        return impl.detachedRow(self)
    }
    
    
    // MARK: - Extracting Swift Values
    
    /**
    Returns true if and only if the row has that column.
    
    This method is case-insensitive.
    
    - parameter columnName: A column name.
    - returns: Whether the row has this column.
    */
    public func hasColumn(columnName: String) -> Bool {
        return impl.indexForColumn(named: columnName) != nil
    }
    
    
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
    (see [rdar://21676393](http://openradar.appspot.com/radar?id=4951414862249984)):
    
        row.value(atIndex: 0) as Int    // OK: Int
        row.value(atIndex: 0) as Int?   // OK: Int?
        row.value(atIndex: 0) as? Int   // NO NO NO DON'T DO THAT!
        row.value(atIndex: 0) as! Int   // NO NO NO DON'T DO THAT!
    
    - parameter index: The index of a column.
    - returns: An optional *Value*.
    */
    public func value<Value: DatabaseValueConvertible>(atIndex index: Int) -> Value? {
        return Value.fromDatabaseValue(impl.databaseValue(atIndex: index))
    }
    
    /**
    This method is an optimized specialization of Row.value(atIndex:) for types
    that adopt both DatabaseValueConvertible and SQLiteStatementConvertible
    protocols.
    
        let value: Bool? = row.value(atIndex: 0)
        let value: Int? = row.value(atIndex: 0)
        let value: Double? = row.value(atIndex: 0)
    
    See the documentation of Row.value(atIndex:) for more information.
    
    - parameter index: The index of a column.
    - returns: An optional *Value*.
    */
    public func value<Value: protocol<DatabaseValueConvertible, SQLiteStatementConvertible>>(atIndex index: Int) -> Value? {
        let sqliteStatement = self.sqliteStatement
        if sqliteStatement != nil {
            // Metal row
            if sqlite3_column_type(sqliteStatement, Int32(index)) == SQLITE_NULL {
                return nil
            } else {
                return Value(sqliteStatement: sqliteStatement, index: Int32(index))
            }
        } else {
            // Detached row
            return Value.fromDatabaseValue(impl.databaseValue(atIndex: index))
        }
    }
    
    /**
    Returns the value at given index, converted to the requested type.
    
    Indexes span from 0 for the leftmost column to (row.count - 1) for the
    righmost column.
    
    Expect a crash if the SQLite value is NULL, or can't be converted to the
    requested type.
    
        let value: Bool = row.value(atIndex: 0)
        let value: Int = row.value(atIndex: 0)
        let value: Double = row.value(atIndex: 0)
    
    **WARNING**: type casting requires a very careful use of the `as` operator
    (see [rdar://21676393](http://openradar.appspot.com/radar?id=4951414862249984)):
    
        row.value(atIndex: 0) as Int    // OK: Int
        row.value(atIndex: 0) as Int?   // OK: Int?
        row.value(atIndex: 0) as? Int   // NO NO NO DON'T DO THAT!
        row.value(atIndex: 0) as! Int   // NO NO NO DON'T DO THAT!
    
    - parameter index: The index of a column.
    - returns: An optional *Value*.
    */
    public func value<Value: DatabaseValueConvertible>(atIndex index: Int) -> Value {
        return impl.databaseValue(atIndex: index).value()
    }
    
    /**
    This method is an optimized specialization of Row.value(atIndex:) for types
    that adopt both DatabaseValueConvertible and SQLiteStatementConvertible
    protocols.
    
        let value: Bool = row.value(atIndex: 0)
        let value: Int = row.value(atIndex: 0)
        let value: Double = row.value(atIndex: 0)
    
    See the documentation of Row.value(atIndex:) for more information.
    
    - parameter index: The index of a column.
    - returns: An optional *Value*.
    */
    public func value<Value: protocol<DatabaseValueConvertible, SQLiteStatementConvertible>>(atIndex index: Int) -> Value {
        let sqliteStatement = self.sqliteStatement
        if sqliteStatement != nil {
            // Metal row
            return Value(sqliteStatement: sqliteStatement, index: Int32(index))
        } else {
            // Detached row
            return Value.fromDatabaseValue(impl.databaseValue(atIndex: index))!
        }
    }
    
    /**
    Returns the value for the given column.
    
    If not nil (for the database NULL), its type is guaranteed to be one of the
    following: Int64, Double, String, and Blob.
    
        let value = row.value(named: "name")
    
    This method is case-insensitive.
    
    - parameter columnName: A column name.
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
        if let index = impl.indexForColumn(named: columnName) {
            return impl.databaseValue(atIndex: index).value()
        } else {
            fatalError("No such column: \(String(reflecting: columnName))")
        }
    }
    
    /**
    Returns the value for the given column, converted to the requested type.
    
    The conversion returns nil if the fetched SQLite value is NULL, or can't be
    converted to the requested type:
    
        let value: Bool? = row.value(named: "count")
        let value: Int? = row.value(named: "count")
        let value: Double? = row.value(named: "count")
    
    This method is case-insensitive.
    
    **WARNING**: type casting requires a very careful use of the `as` operator
    (see [rdar://21676393](http://openradar.appspot.com/radar?id=4951414862249984)):
    
        row.value(named: "count") as Int    // OK: Int
        row.value(named: "count") as Int?   // OK: Int?
        row.value(named: "count") as! Int   // NO NO NO DON'T DO THAT!
        row.value(named: "count") as? Int   // NO NO NO DON'T DO THAT!
    
    - parameter columnName: A column name.
    - returns: An optional *Value*.
    */
    public func value<Value: DatabaseValueConvertible>(named columnName: String) -> Value? {
        if let index = impl.indexForColumn(named: columnName) {
            return value(atIndex: index)
        } else {
            fatalError("No such column: \(String(reflecting: columnName))")
        }
    }
    
    /**
    This method is an optimized specialization of Row.value(named:) for types
    that adopt both DatabaseValueConvertible and SQLiteStatementConvertible
    protocols.
    
        let value: Bool? = row.value(named: "count")
        let value: Int? = row.value(named: "count")
        let value: Double? = row.value(named: "count")
    
    See the documentation of Row.value(named:) for more information.
    
    - parameter columnName: A column name.
    - returns: An optional *Value*.
    */
    public func value<Value: protocol<DatabaseValueConvertible, SQLiteStatementConvertible>>(named columnName: String) -> Value? {
        if let index = impl.indexForColumn(named: columnName) {
            return value(atIndex: index)
        } else {
            fatalError("No such column: \(String(reflecting: columnName))")
        }
    }
    
    /**
    Returns the value for the given column, converted to the requested type.
    
    Expect a crash if the SQLite value is NULL, or can't be converted to the
    requested type.
    
        let value: Bool? = row.value(named: "count")
        let value: Int? = row.value(named: "count")
        let value: Double? = row.value(named: "count")
    
    This method is case-insensitive.
    
    **WARNING**: type casting requires a very careful use of the `as` operator
    (see [rdar://21676393](http://openradar.appspot.com/radar?id=4951414862249984)):
    
        row.value(named: "count") as Int    // OK: Int
        row.value(named: "count") as Int?   // OK: Int?
        row.value(named: "count") as! Int   // NO NO NO DON'T DO THAT!
        row.value(named: "count") as? Int   // NO NO NO DON'T DO THAT!
    
    - parameter columnName: A column name.
    - returns: An optional *Value*.
    */
    public func value<Value: DatabaseValueConvertible>(named columnName: String) -> Value {
        if let index = impl.indexForColumn(named: columnName) {
            return value(atIndex: index)
        } else {
            fatalError("No such column: \(String(reflecting: columnName))")
        }
    }
    
    /**
    This method is an optimized specialization of Row.value(named:) for types
    that adopt both DatabaseValueConvertible and SQLiteStatementConvertible
    protocols.
    
        let value: Bool = row.value(named: "count")
        let value: Int = row.value(named: "count")
        let value: Double = row.value(named: "count")
    
    See the documentation of Row.value(named:) for more information.
    
    - parameter columnName: A column name.
    - returns: An optional *Value*.
    */
    public func value<Value: protocol<DatabaseValueConvertible, SQLiteStatementConvertible>>(named columnName: String) -> Value {
        if let index = impl.indexForColumn(named: columnName) {
            return value(atIndex: index)
        } else {
            fatalError("No such column: \(String(reflecting: columnName))")
        }
    }
    
    
    // MARK: - Extracting DatabaseValue
    
    /**
    Returns a DatabaseValue, the intermediate type between SQLite and your
    values, if and only if the row contains the requested column.
    
        // Test if the column `name` is present:
        if let databaseValue = row["name"] {
            let name: String? = databaseValue.value()
        }
    
    This method is case-insensitive.

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
    Returns a sequence of rows.

        for row in Row.fetch(db, "SELECT id, name FROM persons") {
            let id = row.int64(atIndex: 0)
            let name = row.string(atIndex: 1)
        }
    
    Fetched rows are reused during the sequence iteration: don't wrap a row
    sequence in an array with `Array(rows)` or `rows.filter { ... }` since you
    would not get the distinct rows you expect. Use `Row.fetchAll(...)` instead.
    
    For the same reason, make sure you make a copy whenever you extract a row
    for later use: `row.copy()`.
    
    The returned sequence can be consumed several times, but it may yield
    different results, should database changes have occurred between two
    generations:
    
        let rows = Row.fetch(statement)
        for row in rows { ... } // 3 steps
        db.execute("DELETE ...")
        for row in rows { ... } // 2 steps
    
    If the database is modified while the sequence is iterating, the remaining
    elements of the sequence are undefined.
    
    - parameter db: A Database.
    - parameter sql: An SQL query.
    - parameter arguments: Optional statement arguments.
    - returns: A sequence of rows.
    */
    public static func fetch(statement: SelectStatement, arguments: StatementArguments? = nil) -> DatabaseSequence<Row> {
        // Metal rows can be reused. And reusing them yields better performance.
        let row = Row(metalStatement: statement)
        return statement.fetch(arguments: arguments) { row }
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
        let sequence = statement.fetch(arguments: arguments) {
            Row(detachedStatement: statement)
        }
        return Array(sequence)
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
        let rows = statement.fetch(arguments: arguments) {
            Row(detachedStatement: statement)
        }
        return rows.generate().next()
    }
    
    
    // MARK: - Fetching From Database
    
    /**
    Returns a sequence of rows.
    
        for row in Row.fetch(db, "SELECT id, name FROM persons") {
            let id = row.int64(atIndex: 0)
            let name = row.string(atIndex: 1)
        }
    
    Fetched rows are reused during the sequence iteration: don't wrap a row
    sequence in an array with `Array(rows)` or `rows.filter { ... }` since you
    would not get the distinct rows you expect. Use `Row.fetchAll(...)` instead.
    
    For the same reason, make sure you make a copy whenever you extract a row
    for later use: `row.copy()`.
    
    The returned sequence can be consumed several times, but it may yield
    different results, should database changes have occurred between two
    generations:
    
        let rows = Row.fetch(db, "SELECT...")
        for row in rows { ... } // 3 steps
        db.execute("DELETE ...")
        for row in rows { ... } // 2 steps
    
    If the database is modified while the sequence is iterating, the remaining
    elements of the sequence are undefined.
    
    - parameter db: A Database.
    - parameter sql: An SQL query.
    - parameter arguments: Optional statement arguments.
    - returns: A sequence of rows.
    */
    public static func fetch(db: Database, _ sql: String, arguments: StatementArguments? = nil) -> DatabaseSequence<Row> {
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
        return fetchAll(db.selectStatement(sql), arguments: arguments)
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
        return fetchOne(db.selectStatement(sql), arguments: arguments)
    }

    
    // MARK: - Not Public
    
    /// There a three different RowImpl:
    ///
    /// - MetalRowImpl: metal rows grant direct access to the current state of
    ///   an SQLite statement. Such rows are reused during the iteration of a
    ///   statement.
    ///
    /// - DetachedRowImpl: detached rows hold a copy of the values that come
    ///   from an SQLite statement.
    ///
    /// - DictionaryRowImpl: dictionary rows are created by the library users.
    ///   They do not come from the database.
    let impl: RowImpl
    
    /// Only metal rows have a SQLiteStatement.
    ///
    /// Making sqliteStatement a property of Row instead of a property of RowImpl
    /// makes the extraction of SQLiteStatementConvertible values faster.
    let sqliteStatement: SQLiteStatement
    
    /**
    Builds a row from the an SQLite statement.
    
    The row is implemented on top of MetalRowImpl, which grants *direct* access
    to the SQLite statement. Iteration of the statement does modify the row.
    */
    init(metalStatement statement: SelectStatement) {
        self.sqliteStatement = statement.sqliteStatement
        self.impl = MetalRowImpl(statement: statement)
    }
    
    /**
    Builds a row from the *current state* of the SQLite statement.
    
    The row is implemented on top of DetachedRowImpl, which *copies* the values
    from the SQLite statement so that further iteration of the statement does
    not modify the row.
    */
    init(detachedStatement statement: SelectStatement) {
        self.sqliteStatement = nil
        self.impl = DetachedRowImpl(statement: statement)
    }
    
    
    // MARK: - DictionaryRowImpl
    
    /// See Row.init(databaseDictionary:)
    private struct DictionaryRowImpl : RowImpl {
        let databaseDictionary: [String: DatabaseValue]
        
        init (databaseDictionary: [String: DatabaseValue]) {
            self.databaseDictionary = databaseDictionary
        }
        
        var count: Int {
            return databaseDictionary.count
        }
        
        func databaseValue(atIndex index: Int) -> DatabaseValue {
            return databaseDictionary[databaseDictionary.startIndex.advancedBy(index)].1
        }
        
        func columnName(atIndex index: Int) -> String {
            return databaseDictionary[databaseDictionary.startIndex.advancedBy(index)].0
        }
        
        // This method MUST be case-insensitive.
        func indexForColumn(named name: String) -> Int? {
            let lowercaseName = name.lowercaseString
            if let index = databaseDictionary.indexOf({ (column, value) in column.lowercaseString == lowercaseName }) {
                return databaseDictionary.startIndex.distanceTo(index)
            } else {
                return nil
            }
        }
        
        func detachedRow(row: Row) -> Row {
            return row
        }
    }
    
    
    // MARK: - DetachedRowImpl
    
    /// See Row.init(detachedStatement:)
    private struct DetachedRowImpl : RowImpl {
        let databaseValues: [DatabaseValue]
        let columnNames: [String]
        
        init(statement: SelectStatement) {
            let sqliteStatement = statement.sqliteStatement
            self.databaseValues = (0..<statement.columnCount).map { DatabaseValue(sqliteStatement: sqliteStatement, index: $0) }
            self.columnNames = statement.columnNames
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
        
        // This method MUST be case-insensitive.
        func indexForColumn(named name: String) -> Int? {
            let lowercaseName = name.lowercaseString
            return columnNames.indexOf { $0.lowercaseString == lowercaseName }
        }
        
        func detachedRow(row: Row) -> Row {
            return row
        }
    }
    
    
    // MARK: - MetalRowImpl
    
    /// See Row.init(metalStatement:)
    private struct MetalRowImpl : RowImpl {
        let statement: SelectStatement
        let sqliteStatement: SQLiteStatement
        
        init(statement: SelectStatement) {
            self.statement = statement
            self.sqliteStatement = statement.sqliteStatement
        }
        
        var count: Int {
            return Int(sqlite3_column_count(sqliteStatement))
        }
        
        func databaseValue(atIndex index: Int) -> DatabaseValue {
            return DatabaseValue(sqliteStatement: sqliteStatement, index: index)
        }
        
        func columnName(atIndex index: Int) -> String {
            return statement.columnNames[index]
        }
        
        // This method MUST be case-insensitive.
        func indexForColumn(named name: String) -> Int? {
            return statement.indexForColumn(named: name)
        }
        
        func detachedRow(row: Row) -> Row {
            return Row(detachedStatement: statement)
        }
    }

}


// MARK: - CustomStringConvertible

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


// MARK: - RowImpl

// The protocol for Row underlying implementation
protocol RowImpl {
    var count: Int { get }
    func databaseValue(atIndex index: Int) -> DatabaseValue
    func columnName(atIndex index: Int) -> String
    func indexForColumn(named name: String) -> Int? // This method MUST be case-insensitive.
    func detachedRow(row: Row) -> Row               // The row argument has the receiver as an impl.
}


// MARK: - RowIndex

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

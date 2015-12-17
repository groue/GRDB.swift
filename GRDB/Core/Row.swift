import Foundation

/// A database row.
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
    
    /// Builds an empty row.
    public init() {
        self.sqliteStatement = nil
        self.impl = EmptyRowImpl()
    }
    
    /// Builds a row from an dictionary of values.
    public init(dictionary: [String: DatabaseValueConvertible?]) {
        var databaseDictionary = [String: DatabaseValue]()
        for (key, value) in dictionary {
            databaseDictionary[key] = value?.databaseValue ?? .Null
        }
        self.sqliteStatement = nil
        self.impl = DictionaryRowImpl(databaseDictionary: databaseDictionary)
    }
    
    /// Returns a copy of the row.
    ///
    /// Fetched rows are reused during the iteration of a query, for performance
    /// reasons: make sure to make a copy of it whenever you want to keep a
    /// specific one: `row.copy()`.
    @warn_unused_result
    public func copy() -> Row {
        return impl.copiedRow(self)
    }
    
    
    // MARK: - Extracting Column Values
    
    /// Returns true if and only if the row has that column.
    ///
    /// This method is case-insensitive.
    ///
    /// - parameter columnName: A column name.
    /// - returns: Whether the row has this column.
    public func hasColumn(columnName: String) -> Bool {
        return impl.indexForColumn(named: columnName) != nil
    }
    
    /// Returns Int64, Double, String, NSData or nil, depending on the value
    /// stored at the given index.
    ///
    /// Indexes span from 0 for the leftmost column to (row.count - 1) for the
    /// righmost column.
    ///
    /// - parameter index: A column index.
    /// - returns: An Int64, Double, String, NSData or nil.
    public func value(atIndex index: Int) -> DatabaseValueConvertible? {
        guard index >= 0 && index < count else {
            fatalError("Row index out of range")
        }
        return impl
            .databaseValue(atIndex: index)
            .value()
    }
    
    /// Returns the value at given index, converted to the requested type.
    ///
    /// Indexes span from 0 for the leftmost column to (row.count - 1) for the
    /// righmost column.
    ///
    /// The result is nil if the fetched SQLite value is NULL, or if the SQLite
    /// value can not be converted to `Value`.
    ///
    /// Successful conversions include:
    ///
    /// - Integer and real SQLite values to Swift Int, Int32, Int64, Double and
    ///   Bool (zero is the only false boolean).
    /// - Text SQLite values to Swift String.
    /// - Blob SQLite values to NSData.
    ///
    /// Types that adopt DatabaseValueConvertible can provide more conversions.
    ///
    /// - parameter index: A column index.
    /// - returns: An optional *Value*.
    public func value<Value: DatabaseValueConvertible>(atIndex index: Int) -> Value? {
        guard index >= 0 && index < count else {
            fatalError("Row index out of range")
        }
        return impl
            .databaseValue(atIndex: index)
            .value()
    }
    
    /// Returns the value at given index, converted to the requested type.
    ///
    /// Indexes span from 0 for the leftmost column to (row.count - 1) for the
    /// righmost column.
    ///
    /// The result is nil if the fetched SQLite value is NULL, or if the SQLite
    /// value can not be converted to `Value`.
    ///
    /// Successful conversions include:
    ///
    /// - Integer and real SQLite values to Swift Int, Int32, Int64, Double and
    ///   Bool (zero is the only false boolean).
    /// - Text SQLite values to Swift String.
    /// - Blob SQLite values to NSData.
    ///
    /// Types that adopt DatabaseValueConvertible and SQLiteStatementConvertible
    /// can provide more conversions.
    ///
    /// This method exists as an optimization opportunity for types that adopt
    /// SQLiteStatementConvertible. It *may* trigger SQLite built-in conversions
    /// (see https://www.sqlite.org/datatype3.html).
    ///
    /// - parameter index: A column index.
    /// - returns: An optional *Value*.
    public func value<Value: protocol<DatabaseValueConvertible, SQLiteStatementConvertible>>(atIndex index: Int) -> Value? {
        guard index >= 0 && index < count else {
            fatalError("Row index out of range")
        }
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
            return impl.databaseValue(atIndex: index).value()
        }
    }
    
    /// Returns the value at given index, converted to the requested type.
    ///
    /// Indexes span from 0 for the leftmost column to (row.count - 1) for the
    /// righmost column.
    ///
    /// This method crashes if the fetched SQLite value is NULL, or if the
    /// SQLite value can not be converted to `Value`.
    ///
    /// Successful conversions include:
    ///
    /// - Integer and real SQLite values to Swift Int, Int32, Int64, Double and
    ///   Bool (zero is the only false boolean).
    /// - Text SQLite values to Swift String.
    /// - Blob SQLite values to NSData.
    ///
    /// Types that adopt DatabaseValueConvertible can provide more conversions.
    ///
    /// - parameter index: A column index.
    /// - returns: A *Value*.
    public func value<Value: DatabaseValueConvertible>(atIndex index: Int) -> Value {
        guard index >= 0 && index < count else {
            fatalError("Row index out of range")
        }
        return impl
            .databaseValue(atIndex: index)
            .value()
    }
    
    /// Returns the value at given index, converted to the requested type.
    ///
    /// Indexes span from 0 for the leftmost column to (row.count - 1) for the
    /// righmost column.
    ///
    /// This method crashes if the fetched SQLite value is NULL, or if the
    /// SQLite value can not be converted to `Value`.
    ///
    /// Successful conversions include:
    ///
    /// - Integer and real SQLite values to Swift Int, Int32, Int64, Double and
    ///   Bool (zero is the only false boolean).
    /// - Text SQLite values to Swift String.
    /// - Blob SQLite values to NSData.
    ///
    /// Types that adopt DatabaseValueConvertible and SQLiteStatementConvertible
    /// can provide more conversions.
    ///
    /// This method exists as an optimization opportunity for types that adopt
    /// SQLiteStatementConvertible. It *may* trigger SQLite built-in conversions
    /// (see https://www.sqlite.org/datatype3.html).
    ///
    /// - parameter index: A column index.
    /// - returns: A *Value*.
    public func value<Value: protocol<DatabaseValueConvertible, SQLiteStatementConvertible>>(atIndex index: Int) -> Value {
        guard index >= 0 && index < count else {
            fatalError("Row index out of range")
        }
        let sqliteStatement = self.sqliteStatement
        if sqliteStatement != nil {
            // Metal row
            //
            // Perform a NULL check, and prevent SQLite from converting NULL to
            // a 0 integer, for example.
            guard sqlite3_column_type(sqliteStatement, Int32(index)) != SQLITE_NULL else {
                fatalError("Could not convert NULL to \(Value.self).")
            }
            return Value(sqliteStatement: sqliteStatement, index: Int32(index))
        } else {
            // Detached row
            return impl.databaseValue(atIndex: index).value()
        }
    }
    
    /// Returns Int64, Double, String, NSData or nil, depending on the value
    /// stored at the given column.
    ///
    /// Column name is case-insensitive. The result is nil if the row does not
    /// contain the column.
    ///
    /// - parameter columnName: A column name.
    /// - returns: An Int64, Double, String, NSData or nil.
    public func value(named columnName: String) -> DatabaseValueConvertible? {
        // IMPLEMENTATION NOTE
        // This method has a single know use case: checking if the value is nil,
        // as in:
        //
        //     if row.value(named: "foo") != nil { ... }
        //
        // Without this method, the code above would not compile.
        guard let index = impl.indexForColumn(named: columnName) else {
            return nil
        }
        return impl.databaseValue(atIndex: index).value()
    }
    
    /// Returns the value at given column, converted to the requested type.
    ///
    /// Column name is case-insensitive. The result is nil if the row does not
    /// contain the column, or if the fetched SQLite value is NULL, or if the
    /// SQLite value can not be converted to `Value`.
    ///
    /// Successful conversions include:
    ///
    /// - Integer and real SQLite values to Swift Int, Int32, Int64, Double and
    ///   Bool (zero is the only false boolean).
    /// - Text SQLite values to Swift String.
    /// - Blob SQLite values to NSData.
    ///
    /// Types that adopt DatabaseValueConvertible can provide more conversions.
    ///
    /// - parameter columnName: A column name.
    /// - returns: An optional *Value*.
    public func value<Value: DatabaseValueConvertible>(named columnName: String) -> Value? {
        guard let index = impl.indexForColumn(named: columnName) else {
            return nil
        }
        return value(atIndex: index)
    }
    
    /// Returns the value at given column, converted to the requested type.
    ///
    /// Column name is case-insensitive. The result is nil if the row does not
    /// contain the column, or if the fetched SQLite value is NULL, or if the
    /// SQLite value can not be converted to `Value`.
    ///
    /// Successful conversions include:
    ///
    /// - Integer and real SQLite values to Swift Int, Int32, Int64, Double and
    ///   Bool (zero is the only false boolean).
    /// - Text SQLite values to Swift String.
    /// - Blob SQLite values to NSData.
    ///
    /// Types that adopt DatabaseValueConvertible and SQLiteStatementConvertible
    /// can provide more conversions.
    ///
    /// This method exists as an optimization opportunity for types that adopt
    /// SQLiteStatementConvertible. It *may* trigger SQLite built-in conversions
    /// (see https://www.sqlite.org/datatype3.html).
    ///
    /// - parameter columnName: A column name.
    /// - returns: An optional *Value*.
    public func value<Value: protocol<DatabaseValueConvertible, SQLiteStatementConvertible>>(named columnName: String) -> Value? {
        guard let index = impl.indexForColumn(named: columnName) else {
            return nil
        }
        return value(atIndex: index)
    }
    
    /// Returns the value at given column, converted to the requested type.
    ///
    /// Column name is case-insensitive. If the row does not contain the column,
    /// a fatal error is raised.
    ///
    /// This method crashes if the fetched SQLite value is NULL, or if the
    /// SQLite value can not be converted to `Value`.
    ///
    /// Successful conversions include:
    ///
    /// - Integer and real SQLite values to Swift Int, Int32, Int64, Double and
    ///   Bool (zero is the only false boolean).
    /// - Text SQLite values to Swift String.
    /// - Blob SQLite values to NSData.
    ///
    /// Types that adopt DatabaseValueConvertible can provide more conversions.
    ///
    /// - parameter columnName: A column name.
    /// - returns: An optional *Value*.
    public func value<Value: DatabaseValueConvertible>(named columnName: String) -> Value {
        guard let index = impl.indexForColumn(named: columnName) else {
            fatalError("No such column: \(String(reflecting: columnName))")
        }
        return value(atIndex: index)
    }
    
    /// Returns the value at given column, converted to the requested type.
    ///
    /// Column name is case-insensitive. If the row does not contain the column,
    /// a fatal error is raised.
    ///
    /// This method crashes if the fetched SQLite value is NULL, or if the
    /// SQLite value can not be converted to `Value`.
    ///
    /// Successful conversions include:
    ///
    /// - Integer and real SQLite values to Swift Int, Int32, Int64, Double and
    ///   Bool (zero is the only false boolean).
    /// - Text SQLite values to Swift String.
    /// - Blob SQLite values to NSData.
    ///
    /// Types that adopt DatabaseValueConvertible and SQLiteStatementConvertible
    /// can provide more conversions.
    ///
    /// This method exists as an optimization opportunity for types that adopt
    /// SQLiteStatementConvertible. It *may* trigger SQLite built-in conversions
    /// (see https://www.sqlite.org/datatype3.html).
    ///
    /// - parameter columnName: A column name.
    /// - returns: An optional *Value*.
    public func value<Value: protocol<DatabaseValueConvertible, SQLiteStatementConvertible>>(named columnName: String) -> Value {
        guard let index = impl.indexForColumn(named: columnName) else {
            fatalError("No such column: \(String(reflecting: columnName))")
        }
        return value(atIndex: index)
    }
    
    /// Returns the optional `NSData` at given index.
    ///
    /// Indexes span from 0 for the leftmost column to (row.count - 1) for the
    /// righmost column.
    ///
    /// The result is nil if the fetched SQLite value is NULL, or if the SQLite
    /// value is not a blob.
    ///
    /// Otherwise, the returned data does not owns its bytes: it must not be
    /// used longer than the row's lifetime.
    ///
    /// - parameter index: A column index.
    /// - returns: An optional NSData.
    public func dataNoCopy(atIndex index: Int) -> NSData? {
        precondition(index >= 0 && index < count, "Row index out of range")
        return impl.dataNoCopy(atIndex: index)
    }
    
    /// Returns the optional `NSData` at given column.
    ///
    /// Column name is case-insensitive. The result is nil if the row does not
    /// contain the column, or if the fetched SQLite value is NULL, or if the
    /// SQLite value can not be converted to NSData.
    ///
    /// Otherwise, the returned data does not owns its bytes: it must not be
    /// used longer than the row's lifetime.
    ///
    /// - parameter columnName: A column name.
    /// - returns: An optional NSData.
    public func dataNoCopy(named columnName: String) -> NSData? {
        guard let index = impl.indexForColumn(named: columnName) else {
            return nil
        }
        return dataNoCopy(atIndex: index)
    }
    
    
    // MARK: - Extracting DatabaseValue
    
    /// Returns a DatabaseValue, the intermediate type between SQLite and your
    /// values, if and only if the row contains the requested column.
    ///
    ///     // Test if the column `name` is present:
    ///     if let databaseValue = row["name"] {
    ///         let name: String? = databaseValue.value()
    ///     }
    ///
    /// This method is case-insensitive.
    ///
    /// - parameter columnName: A column name.
    /// - returns: A DatabaseValue if the row contains the requested column.
    public subscript(columnName: String) -> DatabaseValue? {
        guard let index = impl.indexForColumn(named: columnName) else {
            return nil
        }
        return impl.databaseValue(atIndex: index)
    }
    
    
    // MARK: - Row as a Collection of (ColumnName, DatabaseValue) Pairs
    
    /// The number of columns in the row.
    public lazy var count: Int = { self.impl.count }()
    
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
            impl.columnName(atIndex: index.index),
            impl.databaseValue(atIndex: index.index))
    }
    
    
    // MARK: - Fetching From SelectStatement
    
    /// Returns a sequence of rows fetched from a prepared statement.
    ///
    ///     for row in Row.fetch(db, "SELECT id, name FROM persons") {
    ///         let id = row.int64(atIndex: 0)
    ///         let name = row.string(atIndex: 1)
    ///     }
    ///
    /// Fetched rows are reused during the sequence iteration: don't wrap a row
    /// sequence in an array with `Array(rows)` or `rows.filter { ... }` since
    /// you would not get the distinct rows you expect. Use `Row.fetchAll(...)`
    /// instead.
    ///
    /// For the same reason, make sure you make a copy whenever you extract a
    /// row for later use: `row.copy()`.
    ///
    /// The returned sequence can be consumed several times, but it may yield
    /// different results, should database changes have occurred between two
    /// generations:
    ///
    ///     let rows = Row.fetch(statement)
    ///     for row in rows { ... } // 3 steps
    ///     db.execute("DELETE ...")
    ///     for row in rows { ... } // 2 steps
    ///
    /// If the database is modified while the sequence is iterating, the
    /// remaining elements of the sequence are undefined.
    ///
    /// - parameter db: A Database.
    /// - parameter sql: An SQL query.
    /// - parameter arguments: Statement arguments.
    /// - returns: A sequence of rows.
    public static func fetch(statement: SelectStatement, arguments: StatementArguments = StatementArguments.Default) -> DatabaseSequence<Row> {
        // Metal rows can be reused. And reusing them yields better performance.
        let row = Row(metalStatement: statement)
        return statement.fetch(arguments: arguments) { row }
    }
    
    /// Returns an array of rows fetched from a prepared statement.
    ///
    ///     let statement = db.selectStatement("SELECT ...")
    ///     let rows = Row.fetchAll(statement)
    ///
    /// - parameter statement: The statement to run.
    /// - parameter arguments: Statement arguments.
    /// - returns: An array of rows.
    public static func fetchAll(statement: SelectStatement, arguments: StatementArguments = StatementArguments.Default) -> [Row] {
        let sequence = statement.fetch(arguments: arguments) {
            Row(detachedStatement: statement)
        }
        return Array(sequence)
    }
    
    /// Returns a single row fetched from a prepared statement.
    ///
    ///     let statement = db.selectStatement("SELECT ...")
    ///     let row = Row.fetchOne(statement)
    ///
    /// - parameter statement: The statement to run.
    /// - parameter arguments: Statement arguments.
    /// - returns: An optional row.
    public static func fetchOne(statement: SelectStatement, arguments: StatementArguments = StatementArguments.Default) -> Row? {
        let sequence = statement.fetch(arguments: arguments) {
            Row(detachedStatement: statement)
        }
        var generator = sequence.generate()
        return generator.next()
    }
    
    
    // MARK: - Fetching From Database
    
    /// Returns a sequence of rows fetched from an SQL query.
    ///
    ///     for row in Row.fetch(db, "SELECT id, name FROM persons") {
    ///         let id = row.int64(atIndex: 0)
    ///         let name = row.string(atIndex: 1)
    ///     }
    ///
    /// Fetched rows are reused during the sequence iteration: don't wrap a row
    /// sequence in an array with `Array(rows)` or `rows.filter { ... }` since
    /// you would not get the distinct rows you expect. Use `Row.fetchAll(...)`
    /// instead.
    ///
    /// For the same reason, make sure you make a copy whenever you extract a
    /// row for later use: `row.copy()`.
    ///
    /// The returned sequence can be consumed several times, but it may yield
    /// different results, should database changes have occurred between two
    /// generations:
    ///
    ///     let rows = Row.fetch(db, "SELECT...")
    ///     for row in rows { ... } // 3 steps
    ///     db.execute("DELETE ...")
    ///     for row in rows { ... } // 2 steps
    ///
    /// If the database is modified while the sequence is iterating, the
    /// remaining elements of the sequence are undefined.
    ///
    /// - parameter db: A Database.
    /// - parameter sql: An SQL query.
    /// - parameter arguments: Statement arguments.
    /// - returns: A sequence of rows.
    public static func fetch(db: Database, _ sql: String, arguments: StatementArguments = StatementArguments.Default) -> DatabaseSequence<Row> {
        return fetch(db.selectStatement(sql), arguments: arguments)
    }
    
    /// Returns an array of rows fetched from an SQL query.
    ///
    ///     let rows = Row.fetchAll(db, "SELECT ...")
    ///
    /// - parameter db: A Database.
    /// - parameter sql: An SQL query.
    /// - parameter arguments: Statement arguments.
    /// - returns: An array of rows.
    public static func fetchAll(db: Database, _ sql: String, arguments: StatementArguments = StatementArguments.Default) -> [Row] {
        return fetchAll(db.selectStatement(sql), arguments: arguments)
    }
    
    /// Returns a single row fetched from an SQL query.
    ///
    ///     let row = Row.fetchOne(db, "SELECT ...")
    ///
    /// - parameter db: A Database.
    /// - parameter sql: An SQL query.
    /// - parameter arguments: Statement arguments.
    /// - returns: An optional row.
    public static func fetchOne(db: Database, _ sql: String, arguments: StatementArguments = StatementArguments.Default) -> Row? {
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
    ///
    /// - EmptyRowImpl: empty row
    let impl: RowImpl
    
    /// Only metal rows have a SQLiteStatement.
    ///
    /// Making sqliteStatement a property of Row instead of a property of
    /// RowImpl makes the extraction of SQLiteStatementConvertible
    /// values faster.
    let sqliteStatement: SQLiteStatement
    
    /// Builds a row from the an SQLite statement.
    ///
    /// The row is implemented on top of MetalRowImpl, which grants *direct*
    /// access to the SQLite statement. Iteration of the statement does modify
    /// the row.
    init(metalStatement statement: SelectStatement) {
        self.sqliteStatement = statement.sqliteStatement
        self.impl = MetalRowImpl(statement: statement)
    }
    
    /// Builds a row from the *current state* of the SQLite statement.
    ///
    /// The row is implemented on top of DetachedRowImpl, which *copies* the
    /// values from the SQLite statement so that further iteration of the
    /// statement does not modify the row.
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
        
        func dataNoCopy(atIndex index:Int) -> NSData? {
            return databaseValue(atIndex: index).value()
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
            guard let index = databaseDictionary.indexOf({ (column, value) in column.lowercaseString == lowercaseName }) else {
                return nil
            }
            return databaseDictionary.startIndex.distanceTo(index)
        }
        
        func copiedRow(row: Row) -> Row {
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
        
        func dataNoCopy(atIndex index:Int) -> NSData? {
            return databaseValue(atIndex: index).value()
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
        
        func copiedRow(row: Row) -> Row {
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
        
        func dataNoCopy(atIndex index:Int) -> NSData? {
            guard sqlite3_column_type(sqliteStatement, Int32(index)) != SQLITE_NULL else {
                return nil
            }
            let bytes = sqlite3_column_blob(sqliteStatement, Int32(index))
            let length = sqlite3_column_bytes(sqliteStatement, Int32(index))
            return NSData(bytesNoCopy: UnsafeMutablePointer(bytes), length: Int(length), freeWhenDone: false)
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
        
        func copiedRow(row: Row) -> Row {
            return Row(detachedStatement: statement)
        }
    }
    
    
    // MARK: - EmptyRowImpl
    
    /// See Row.init()
    private struct EmptyRowImpl : RowImpl {
        var count: Int { return 0 }
        
        func databaseValue(atIndex index: Int) -> DatabaseValue {
            fatalError("Empty row has no column")
        }
        
        func dataNoCopy(atIndex index:Int) -> NSData? {
            fatalError("Empty row has no column")
        }
        
        func columnName(atIndex index: Int) -> String {
            fatalError("Empty row has no column")
        }
        
        func indexForColumn(named name: String) -> Int? {
            return nil
        }
        
        func copiedRow(row: Row) -> Row {
            return row
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
    func dataNoCopy(atIndex index:Int) -> NSData?
    func columnName(atIndex index: Int) -> String
    func indexForColumn(named name: String) -> Int? // This method MUST be case-insensitive.
    func copiedRow(row: Row) -> Row                 // row.impl is guaranteed to be self.
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

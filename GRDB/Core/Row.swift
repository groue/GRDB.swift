// Import C SQLite functions
#if SWIFT_PACKAGE
import CSQLite
#elseif GRDBCIPHER
import SQLCipher
#elseif !GRDBCUSTOMSQLITE && !GRDBCIPHER
import SQLite3
#endif

import Foundation

/// A database row.
///
/// To get `Row` instances, you will generally fetch them from a ``Database``
/// instance. For example:
///
/// ```swift
/// try dbQueue.read { db in
///     let rows = try Row.fetchCursor(db, sql: """
///         SELECT * FROM player
///         """)
///     while let row = try rows.next() {
///         let id: Int64 = row["id"]
///         let name: String = row["name"]
///     }
/// }
/// ```
///
/// ## Topics
///
/// ### Creating Rows
///
/// - ``init()``
/// - ``init(_:)-5uezw``
/// - ``init(_:)-65by6``
///
/// ### Copying a Row
///
/// - ``copy()``
///
/// ### Row Informations
///
/// - ``columnNames``
/// - ``containsNonNullValue``
/// - ``count-5flaw``
/// - ``databaseValues``
/// - ``hasColumn(_:)``
/// - ``hasNull(atIndex:)``
///
/// ### Accessing Row Values by Int Index
///
/// - ``subscript(_:)-9c1fw``
/// - ``subscript(_:)-3jhwm``
/// - ``subscript(_:)-7krrg``
/// - ``withUnsafeData(atIndex:_:)``
/// - ``dataNoCopy(atIndex:)``
///
/// ### Accessing Row Values by Column Name
///
/// - ``subscript(_:)-3tp8o``
/// - ``subscript(_:)-4k8od``
/// - ``subscript(_:)-9rbo7``
/// - ``withUnsafeData(named:_:)``
/// - ``dataNoCopy(named:)``
///
/// ### Accessing Row Values by Column
///
/// - ``subscript(_:)-9txgm``
/// - ``subscript(_:)-2esg7``
/// - ``subscript(_:)-wl9a``
/// - ``withUnsafeData(at:_:)``
/// - ``dataNoCopy(_:)``
///
/// ### Row Scopes & Associated Rows
///
/// - ``prefetchedRows``
/// - ``scopes``
/// - ``scopesTree``
/// - ``unadapted``
/// - ``unscoped``
/// - ``subscript(_:)-4dx01``
/// - ``subscript(_:)-8god3``
/// - ``subscript(_:)-jwnx``
/// - ``subscript(_:)-6ge6t``
/// - ``PrefetchedRowsView``
/// - ``ScopesTreeView``
/// - ``ScopesView``
///
/// ### Fetching Rows from Raw SQL
///
/// - ``fetchCursor(_:sql:arguments:adapter:)``
/// - ``fetchAll(_:sql:arguments:adapter:)``
/// - ``fetchSet(_:sql:arguments:adapter:)``
/// - ``fetchOne(_:sql:arguments:adapter:)``
///
/// ### Fetching Rows from a Prepared Statement
///
/// - ``fetchCursor(_:arguments:adapter:)``
/// - ``fetchAll(_:arguments:adapter:)``
/// - ``fetchSet(_:arguments:adapter:)``
/// - ``fetchOne(_:arguments:adapter:)``
///
/// ### Fetching Rows from a Request
///
/// - ``fetchCursor(_:_:)``
/// - ``fetchAll(_:_:)``
/// - ``fetchSet(_:_:)``
/// - ``fetchOne(_:_:)``
///
/// ### Row as RandomAccessCollection
///
/// - ``count-5flaw``
/// - ``subscript(_:)-68yae``
/// - ``Index``
///
/// ### Adapting Rows
///
/// - ``RowAdapter``
///
/// ### Supporting Types
///
/// - ``RowCursor``
public final class Row {
    // It is not a violation of the Demeter law when another type uses this
    // property, which is exposed for optimizations.
    let impl: any RowImpl
    
    /// Unless we are producing a row array, we use a single row when iterating
    /// a statement:
    ///
    ///     let rows = try Row.fetchCursor(db, sql: "SELECT ...")
    ///     let players = try Player.fetchAll(db, sql: "SELECT ...")
    let statement: Statement?
    @usableFromInline
    let sqliteStatement: SQLiteStatement?
    
    /// The number of columns in the row.
    public let count: Int
    
    /// A view on the prefetched associated rows.
    ///
    /// Prefetched rows are defined by the ``JoinableRequest/including(all:)``
    /// request method.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Author: TableRecord {
    ///     static let books = hasMany(Book.self)
    /// }
    ///
    /// struct Book: TableRecord { }
    ///
    /// let request = Author.including(all: Author.books)
    /// let authorRow = try Row.fetchOne(db, request)!
    ///
    /// print(authorRow)
    /// // Prints [id:1, name:"Herman Melville"]
    ///
    /// let bookRows = authorRow.prefetchedRows["books"]!
    /// print(bookRows[0])
    /// // Prints [id:42, title:"Moby-Dick", authorId:1]
    /// print(bookRows[1])
    /// // Prints [id:57, title:"Pierre", authorId:1]
    /// ```
    public internal(set) var prefetchedRows = PrefetchedRowsView()
    
    // MARK: - Building rows
    
    /// Creates an empty row.
    public convenience init() {
        self.init(impl: EmptyRowImpl())
    }
    
    /// Creates a row from a dictionary of database values.
    public convenience init(_ dictionary: [String: (any DatabaseValueConvertible)?]) {
        self.init(impl: ArrayRowImpl(columns: dictionary.map { ($0, $1?.databaseValue ?? .null) }))
    }
    
    /// Creates a row from a dictionary.
    ///
    /// The result is nil unless all dictionary keys are strings, and values
    /// conform to ``DatabaseValueConvertible``.
    public convenience init?(_ dictionary: [AnyHashable: Any]) {
        var initDictionary = [String: (any DatabaseValueConvertible)?]()
        for (key, value) in dictionary {
            guard let columnName = key as? String else {
                return nil
            }
            guard let dbValue = DatabaseValue(value: value) else {
                return nil
            }
            initDictionary[columnName] = dbValue
        }
        self.init(initDictionary)
    }
    
    /// Returns an immutable copy of the row.
    ///
    /// For performance reasons, rows fetched from a cursor are reused during
    /// the iteration of a query: make sure to make a copy of it whenever you
    /// want to keep a specific one: `row.copy()`.
    public func copy() -> Row {
        impl.copiedRow(self)
    }
    
    /// Returns true if and only if the row was fetched from a database.
    public var _isFetched: Bool { impl.isFetched }
    
    // MARK: - Not Public
    
    /// Creates a row that maps an SQLite statement. Further calls to
    /// sqlite3_step() modify the row.
    ///
    /// The row is implemented on top of StatementRowImpl, which grants *direct*
    /// access to the SQLite statement. Iteration of the statement does modify
    /// the row.
    init(statement: Statement) {
        self.statement = statement
        self.sqliteStatement = statement.sqliteStatement
        self.impl = StatementRowImpl(sqliteStatement: statement.sqliteStatement, statement: statement)
        self.count = Int(sqlite3_column_count(sqliteStatement))
    }
    
    /// Creates a row that maps an SQLite statement. Further calls to
    /// sqlite3_step() modify the row.
    init(sqliteStatement: SQLiteStatement) {
        self.statement = nil
        self.sqliteStatement = sqliteStatement
        self.impl = SQLiteStatementRowImpl(sqliteStatement: sqliteStatement)
        self.count = Int(sqlite3_column_count(sqliteStatement))
    }
    
    /// Creates a row that contain a copy of the current state of the
    /// SQLite statement. Further calls to sqlite3_step() do not modify the row.
    ///
    /// The row is implemented on top of StatementCopyRowImpl, which *copies*
    /// the values from the SQLite statement so that further iteration of the
    /// statement does not modify the row.
    convenience init(
        copiedFromSQLiteStatement sqliteStatement: SQLiteStatement,
        statement: Statement)
    {
        self.init(impl: StatementCopyRowImpl(
                    sqliteStatement: sqliteStatement,
                    columnNames: statement.columnNames))
    }
    
    init(impl: any RowImpl) {
        self.statement = nil
        self.sqliteStatement = nil
        self.impl = impl
        self.count = impl.count
    }
}

// Explicit non-conformance to Sendable: a row contains transient
// information. TODO GRDB7: split non sendable statement rows from sendable
// copied rows.
@available(*, unavailable)
extension Row: Sendable { }

#warning("TODO: remove what's not needed")
extension Row: RowProtocol {
    public typealias Index = RowIndex
    
    public func _scopes(prefetchedRows: PrefetchedRowsView) -> ScopesView {
        impl.scopes(prefetchedRows: prefetchedRows)
    }
    
    public func _columnName(atUncheckedIndex index: Int) -> String {
        impl.columnName(atUncheckedIndex: index)
    }
    
    public func _hasNull(atUncheckedIndex index: Int) -> Bool {
        impl.hasNull(atUncheckedIndex: index)
    }
    
    public func _databaseValue(atUncheckedIndex index: Int) -> DatabaseValue {
        impl.databaseValue(atUncheckedIndex: index)
    }
    
    public func _decode<Strategy: _RowDecodingStrategy>(
        with strategy: Strategy,
        atUncheckedIndex index: Int
    ) throws -> Strategy._RowDecodingOutput
    {
        if let sqliteStatement {
            let statementIndex = CInt(index)
            
            if sqlite3_column_type(sqliteStatement, statementIndex) == SQLITE_NULL {
                throw RowDecodingError.valueMismatch(
                    Strategy._RowDecodingOutput.self,
                    sqliteStatement: sqliteStatement,
                    index: statementIndex,
                    context: _makeRowDecodingContext(forKey: .columnIndex(index)))
            }
            
            return try strategy._decode(
                sqliteStatement: sqliteStatement,
                atUncheckedIndex: CInt(index),
                context: _makeRowDecodingContext(forKey: .columnIndex(index)))
        } else {
            return try strategy._decode(
                databaseValue: impl.databaseValue(atUncheckedIndex: index),
                context: _makeRowDecodingContext(forKey: .columnIndex(index)))
        }
    }
    
    public func _decode<Value: DatabaseValueConvertible>(
        _ type: Value.Type,
        atUncheckedIndex index: Int
    ) throws -> Value
    {
        if let sqliteStatement {
            let dbValue = DatabaseValue(sqliteStatement: sqliteStatement, index: CInt(index))
            return try Value._decode(
                databaseValue: dbValue,
                context: _makeRowDecodingContext(forKey: .columnIndex(index)))
        } else {
            return try Value._decode(
                databaseValue: impl.databaseValue(atUncheckedIndex: index),
                context: _makeRowDecodingContext(forKey: .columnIndex(index)))
        }
    }
    
    public func _fastDecode<Value: DatabaseValueConvertible & StatementColumnConvertible>(
        _ type: Value.Type,
        atUncheckedIndex index: Int
    ) throws -> Value
    {
        try impl.fastDecode(Value.self, atUncheckedIndex: index)
    }
    
    public func _withUnsafeData<T>(atUncheckedIndex index: Int, _ body: (Data?) throws -> T) throws -> T {
        try impl.withUnsafeData(atUncheckedIndex: index, body)
    }
    
    public func index(forColumn name: String) -> Int? {
        impl.index(forColumn: name)
    }
    
    public var _unscopedRow: Row {
        impl.unscopedRow(self)
    }
    
    public var _unadaptedRow: Row {
        impl.unadaptedRow(self)
    }
    
    public var _copiedRow: Row {
        impl.copiedRow(self)
    }
    
    public func _makeRowDecodingContext(forKey key: _RowKey?) -> _RowDecodingContext {
        if let statement {
            return _RowDecodingContext(
                row: copy(),
                key: key,
                sql: statement.sql,
                statementArguments: statement.arguments)
        } else if let sqliteStatement {
            return _RowDecodingContext(
                row: copy(),
                key: key,
                sql: String(cString: sqlite3_sql(sqliteStatement)).trimmedSQLStatement,
                statementArguments: nil) // Can't rebuild arguments
        } else {
            return _RowDecodingContext(
                row: copy(),
                key: key,
                sql: nil,
                statementArguments: nil)
        }
    }
}

extension Row {
    
    // MARK: - Scopes
    
    /// A view on the scopes defined by row adapters.
    ///
    /// The returned object provides an access to all available scopes in
    /// the row.
    ///
    /// Row scopes can be defined manually, with ``ScopeAdapter``.
    /// The ``JoinableRequest/including(required:)`` and
    /// ``JoinableRequest/including(optional:)`` request methods define scopes
    /// named after the key of included associations between record types.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Book: TableRecord {
    ///     static let author = belongsTo(Author.self)
    /// }
    ///
    /// struct Author: TableRecord {
    ///     static let country = belongsTo(Country.self)
    /// }
    ///
    /// struct Country: TableRecord { }
    ///
    /// // Fetch a book, with its author, and the country of its author.
    /// let request = Book
    ///     .including(required: Book.author
    ///         .including(required: Author.country))
    /// let bookRow = try Row.fetchOne(db, request)!
    ///
    /// print(bookRow)
    /// // Prints [id:42, title:"Moby-Dick", authorId:1]
    ///
    /// let authorRow = bookRow.scopes["author"]!
    /// print(authorRow)
    /// // Prints [id:1, name:"Herman Melville", countryCode: "US"]
    ///
    /// let countryRow = authorRow.scopes["country"]!
    /// print(countryRow)
    /// // Prints [code:"US" name:"United States of America"]
    /// ```
    ///
    /// See also ``scopesTree``.
    public var scopes: ScopesView {
        impl.scopes(prefetchedRows: prefetchedRows)
    }
    
    /// A view on the scopes tree defined by row adapters.
    ///
    /// The returned object provides an access to all available scopes in
    /// the row, recursively. For any given scope identifier, a breadth-first
    /// search is performed.
    ///
    /// Row scopes can be defined manually, with ``ScopeAdapter``.
    /// The ``JoinableRequest/including(required:)`` and
    /// ``JoinableRequest/including(optional:)`` request methods define scopes
    /// named after the key of included associations between record types.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Book: TableRecord {
    ///     static let author = belongsTo(Author.self)
    /// }
    ///
    /// struct Author: TableRecord {
    ///     static let country = belongsTo(Country.self)
    /// }
    ///
    /// struct Country: TableRecord { }
    ///
    /// // Fetch a book, with its author, and the country of its author.
    /// let request = Book
    ///     .including(required: Book.author
    ///         .including(required: Author.country))
    /// let bookRow = try Row.fetchOne(db, request)!
    ///
    /// print(bookRow)
    /// // Prints [id:42, title:"Moby-Dick", authorId:1]
    ///
    /// print(bookRow.scopesTree["author"])
    /// // Prints [id:1, name:"Herman Melville", countryCode: "US"]
    ///
    /// print(bookRow.scopesTree["country"])
    /// // Prints [code:"US" name:"United States of America"]
    /// ```
    ///
    /// See also ``scopes``.
    public var scopesTree: ScopesTreeView {
        ScopesTreeView(scopes: scopes)
    }
    
    /// The row, without any scope of prefetched rows.
    ///
    /// This property is useful when testing the content of rows fetched from
    /// joined requests.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Book: TableRecord {
    ///     static let author = belongsTo(Author.self)
    ///     static let awards = hasMany(Award.self)
    /// }
    ///
    /// struct Author: TableRecord { }
    /// struct Award: TableRecord { }
    ///
    /// // Fetch a book, with its author, and its awards.
    /// let request = Book
    ///     .including(required: Book.author)
    ///     .including(all: Book.awards)
    /// let bookRow = try Row.fetchOne(db, request)!
    ///
    /// // Failure
    /// XCTAssertEqual(bookRow, ["id":42, "title":"Moby-Dick", "authorId":1])
    ///
    /// // Success
    /// XCTAssertEqual(bookRow.unscoped, ["id":42, "title":"Moby-Dick", "authorId":1])
    /// ```
    public var unscoped: Row {
        var row = impl.unscopedRow(self)
        
        // Remove prefetchedRows
        if row.prefetchedRows.isEmpty == false {
            // Make sure we build another Row instance
            row = Row(impl: row.copy().impl)
            assert(row !== self)
            assert(row.prefetchedRows.isEmpty)
        }
        return row
    }
    
    /// The raw row fetched from the database.
    ///
    /// This property is useful when debugging the content of rows fetched from
    /// joined requests.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Book: TableRecord {
    ///     static let author = belongsTo(Author.self)
    /// }
    ///
    /// struct Author: TableRecord { }
    ///
    /// // SELECT book.*, author.*
    /// // FROM book
    /// // JOIN author ON author.id = book.authorId
    /// let request = Book.including(required: Book.author)
    /// let bookRow = try Row.fetchOne(db, request)!
    ///
    /// print(bookRow)
    /// // Prints [id:42, title:"Moby-Dick", authorId:1]
    ///
    /// print(bookRow.unadapted)
    /// // Prints [id:42, title:"Moby-Dick", authorId:1, id:1, name:"Herman Melville"]
    /// ```
    public var unadapted: Row {
        impl.unadaptedRow(self)
    }
}

// MARK: - RowCursor

/// A cursor of raw database rows.
///
/// A `RowCursor` iterates all rows from a database request.
///
/// For example:
///
/// ```swift
/// try dbQueue.read { db in
///     let rows = try Row.fetchCursor(db, sql: """
///         SELECT * FROM player
///         """)
///     while let row = try rows.next() {
///         let id: Int64 = row["id"]
///         let name: String = row["name"]
///     }
/// }
/// ```
public final class RowCursor: DatabaseCursor {
    public typealias Element = Row
    public let _statement: Statement
    public var _isDone = false
    @usableFromInline let _row: Row // Reused for performance
    
    init(statement: Statement, arguments: StatementArguments? = nil, adapter: (any RowAdapter)? = nil) throws {
        self._statement = statement
        self._row = try Row(statement: statement).adapted(with: adapter, layout: statement)
        
        // Assume cursor is created for immediate iteration: reset and set arguments
        try statement.prepareExecution(withArguments: arguments)
    }
    
    deinit {
        // Statement reset fails when sqlite3_step has previously failed.
        // Just ignore reset error.
        try? _statement.reset()
    }
    
    @inlinable
    public func _element(sqliteStatement: SQLiteStatement) -> Row { _row }
}

// Explicit non-conformance to Sendable: database cursors must be used from
// a serialized database access dispatch queue.
@available(*, unavailable)
extension RowCursor: Sendable { }

extension Row {
    
    // MARK: - Fetching From Prepared Statement
    
    /// Returns a cursor over rows fetched from a prepared statement.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///     let sql = "SELECT * FROM player WHERE lastName = ?"
    ///     let statement = try db.makeStatement(sql: sql)
    ///     let rows = try Row.fetchCursor(statement, arguments: [lastName])
    ///     while let row = try rows.next() {
    ///         let id: Int64 = row["id"]
    ///         let name: String = row["name"]
    ///     }
    /// }
    /// ```
    ///
    /// Fetched rows are reused during the cursor iteration: don't turn a row
    /// cursor into an array with `Array(rows)` since you would not get the
    /// distinct rows you expect.
    /// Use ``fetchAll(_:arguments:adapter:)`` instead.
    ///
    /// For the same reason, make sure you make a copy whenever you extract a
    /// row for later use: `row.copy()`.
    ///
    /// The returned cursor is valid only during the remaining execution of the
    /// database access. Do not store or return the cursor for later use.
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL string.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: A ``RowCursor`` over fetched rows.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchCursor(
        _ statement: Statement,
        arguments: StatementArguments? = nil,
        adapter: (any RowAdapter)? = nil)
    throws -> RowCursor
    {
        try RowCursor(statement: statement, arguments: arguments, adapter: adapter)
    }
    
    /// Returns an array of rows fetched from a prepared statement.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///     let sql = "SELECT * FROM player WHERE lastName = ?"
    ///     let statement = try db.makeStatement(sql: sql)
    ///     let rows = try Row.fetchAll(statement, arguments: [lastName])
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An array of rows.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchAll(
        _ statement: Statement,
        arguments: StatementArguments? = nil,
        adapter: (any RowAdapter)? = nil)
    throws -> [Row]
    {
        // The cursor reuses a single mutable row. Return immutable copies.
        try Array(fetchCursor(statement, arguments: arguments, adapter: adapter).map { $0.copy() })
    }
    
    /// Returns a set of rows fetched from a prepared statement.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///     let sql = "SELECT * FROM player WHERE lastName = ?"
    ///     let statement = try db.makeStatement(sql: sql)
    ///     let rows = try Row.fetchSet(statement, arguments: [lastName])
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: A set of rows.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchSet(
        _ statement: Statement,
        arguments: StatementArguments? = nil,
        adapter: (any RowAdapter)? = nil)
    throws -> Set<Row>
    {
        // The cursor reuses a single mutable row. Return immutable copies.
        try Set(fetchCursor(statement, arguments: arguments, adapter: adapter).map { $0.copy() })
    }
    
    /// Returns a single row fetched from a prepared statement.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///     let sql = "SELECT * FROM player WHERE lastName = ? LIMIT 1"
    ///     let statement = try db.makeStatement(sql: sql)
    ///     let row = try Row.fetchOne(statement, arguments: [lastName])
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An optional row.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchOne(
        _ statement: Statement,
        arguments: StatementArguments? = nil,
        adapter: (any RowAdapter)? = nil)
    throws -> Row?
    {
        let cursor = try fetchCursor(statement, arguments: arguments, adapter: adapter)
        // Keep cursor alive until we can copy the fetched row
        return try withExtendedLifetime(cursor) {
            try cursor.next().map { $0.copy() }
        }
    }
}

extension Row {
    
    // MARK: - Fetching From SQL
    
    /// Returns a cursor over rows fetched from an SQL query.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///     let sql = "SELECT * FROM player WHERE lastName = ?"
    ///     let rows = try Row.fetchCursor(db, sql: sql, arguments: [lastName])
    ///     while let row = try rows.next() {
    ///         let id: Int64 = row["id"]
    ///         let name: String = row["name"]
    ///     }
    /// }
    /// ```
    ///
    /// Fetched rows are reused during the cursor iteration: don't turn a row
    /// cursor into an array with `Array(rows)` since you would not get the
    /// distinct rows you expect.
    /// Use ``fetchAll(_:sql:arguments:adapter:)`` instead.
    ///
    /// For the same reason, make sure you make a copy whenever you extract a
    /// row for later use: `row.copy()`.
    ///
    /// The returned cursor is valid only during the remaining execution of the
    /// database access. Do not store or return the cursor for later use.
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL string.
    ///     - arguments: Statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: A ``RowCursor`` over fetched rows.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchCursor(
        _ db: Database,
        sql: String,
        arguments: StatementArguments = StatementArguments(),
        adapter: (any RowAdapter)? = nil)
    throws -> RowCursor
    {
        try fetchCursor(db, SQLRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
    
    /// Returns an array of rows fetched from an SQL query.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///     let sql = "SELECT * FROM player WHERE lastName = ?"
    ///     let rows = try Row.fetchAll(db, sql: sql, arguments: [lastName])
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL string.
    ///     - arguments: Statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An array of rows.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchAll(
        _ db: Database,
        sql: String,
        arguments: StatementArguments = StatementArguments(),
        adapter: (any RowAdapter)? = nil)
    throws -> [Row]
    {
        try fetchAll(db, SQLRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
    
    /// Returns a set of rows fetched from an SQL query.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///     let sql = "SELECT * FROM player WHERE lastName = ?"
    ///     let rows = try Row.fetchSet(db, sql: sql, arguments: [lastName])
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL string.
    ///     - arguments: Statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: A set of rows.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchSet(
        _ db: Database,
        sql: String,
        arguments: StatementArguments = StatementArguments(),
        adapter: (any RowAdapter)? = nil)
    throws -> Set<Row>
    {
        try fetchSet(db, SQLRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
    
    /// Returns a single row fetched from an SQL query.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///     let sql = "SELECT * FROM player WHERE lastName = ? LIMIT 1"
    ///     let row = try Row.fetchOne(db, sql: sql, arguments: [lastName])
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL string.
    ///     - arguments: Statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An optional row.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchOne(
        _ db: Database,
        sql: String,
        arguments: StatementArguments = StatementArguments(),
        adapter: (any RowAdapter)? = nil)
    throws -> Row?
    {
        try fetchOne(db, SQLRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
}

extension Row {
    
    // MARK: - Fetching From FetchRequest
    
    /// Returns a cursor over rows fetched from a fetch request.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///
    ///     // Query interface request
    ///     let request = Player.filter(Column("lastName") == lastName)
    ///
    ///     // SQL request
    ///     let request: SQLRequest<Row> = """
    ///         SELECT * FROM player WHERE lastName = \(lastName)
    ///         """
    ///
    ///     let rows = try Row.fetchCursor(db, request)
    ///     while let row = try rows.next() {
    ///         let id: Int64 = row["id"]
    ///         let name: String = row["name"]
    ///     }
    /// }
    /// ```
    ///
    /// Fetched rows are reused during the cursor iteration: don't turn a row
    /// cursor into an array with `Array(rows)` since you would not get the
    /// distinct rows you expect.
    /// Use ``fetchAll(_:_:)`` instead.
    ///
    /// For the same reason, make sure you make a copy whenever you extract a
    /// row for later use: `row.copy()`.
    ///
    /// The returned cursor is valid only during the remaining execution of the
    /// database access. Do not store or return the cursor for later use.
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - request: A FetchRequest.
    /// - returns: A ``RowCursor`` over fetched rows.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchCursor(_ db: Database, _ request: some FetchRequest) throws -> RowCursor {
        let request = try request.makePreparedRequest(db, forSingleResult: false)
        precondition(request.supplementaryFetch == nil, "Not implemented: fetchCursor with supplementary fetch")
        return try fetchCursor(request.statement, adapter: request.adapter)
    }
    
    /// Returns an array of rows fetched from a fetch request.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///
    ///     // Query interface request
    ///     let request = Player.filter(Column("lastName") == lastName)
    ///
    ///     // SQL request
    ///     let request: SQLRequest<Row> = """
    ///         SELECT * FROM player WHERE lastName = \(lastName)
    ///         """
    ///
    ///     let rows = try Row.fetchAll(db, request)
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - request: A FetchRequest.
    /// - returns: An array of rows.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchAll(_ db: Database, _ request: some FetchRequest) throws -> [Row] {
        let request = try request.makePreparedRequest(db, forSingleResult: false)
        let rows = try fetchAll(request.statement, adapter: request.adapter)
        try request.supplementaryFetch?(db, rows, nil)
        return rows
    }
    
    /// Returns a set of rows fetched from a fetch request.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///
    ///     // Query interface request
    ///     let request = Player.filter(Column("lastName") == lastName)
    ///
    ///     // SQL request
    ///     let request: SQLRequest<Row> = """
    ///         SELECT * FROM player WHERE lastName = \(lastName)
    ///         """
    ///
    ///     let rows = try Row.fetchSet(db, request)
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - request: A FetchRequest.
    /// - returns: A set of rows.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchSet(_ db: Database, _ request: some FetchRequest) throws -> Set<Row> {
        let request = try request.makePreparedRequest(db, forSingleResult: false)
        if let supplementaryFetch = request.supplementaryFetch {
            let rows = try fetchAll(request.statement, adapter: request.adapter)
            try supplementaryFetch(db, rows, nil)
            return Set(rows)
        } else {
            return try fetchSet(request.statement, adapter: request.adapter)
        }
    }
    
    /// Returns a single row fetched from a fetch request.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///
    ///     // Query interface request
    ///     let request = Player.filter(Column("lastName") == lastName)
    ///
    ///     // SQL request
    ///     let request: SQLRequest<Row> = """
    ///         SELECT * FROM player WHERE lastName = \(lastName) LIMIT 1
    ///         """
    ///
    ///     let row = try Row.fetchOne(db, request)
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - request: A FetchRequest.
    /// - returns: An optional row.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchOne(_ db: Database, _ request: some FetchRequest) throws -> Row? {
        let request = try request.makePreparedRequest(db, forSingleResult: true)
        guard let row = try fetchOne(request.statement, adapter: request.adapter) else {
            return nil
        }
        try request.supplementaryFetch?(db, [row], nil)
        return row
    }
}

extension FetchRequest<Row> {
    
    // MARK: Fetching Rows
    
    /// Returns a cursor over fetched rows.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///     let request: SQLRequest<Row> = """
    ///         SELECT * FROM player WHERE lastName = \(lastName)
    ///         """
    ///     let rows = try request.fetchCursor(db)
    ///     while let row = try rows.next() {
    ///         let id: Int64 = row["id"]
    ///         let name: String = row["name"]
    ///     }
    /// }
    /// ```
    ///
    /// Fetched rows are reused during the cursor iteration: don't turn a row
    /// cursor into an array with `Array(rows)` since you would not get the
    /// distinct rows you expect.
    /// Use ``FetchRequest/fetchAll(_:)-7p809`` instead.
    ///
    /// For the same reason, make sure you make a copy whenever you extract a
    /// row for later use: `row.copy()`.
    ///
    /// The returned cursor is valid only during the remaining execution of the
    /// database access. Do not store or return the cursor for later use.
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// - parameter db: A database connection.
    /// - returns: A ``RowCursor`` over fetched rows.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func fetchCursor(_ db: Database) throws -> RowCursor {
        try Row.fetchCursor(db, self)
    }
    
    /// Returns an array of fetched rows.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///     let request: SQLRequest<Row> = """
    ///         SELECT * FROM player WHERE lastName = \(lastName)
    ///         """
    ///     let rows = try request.fetchAll(db)
    /// }
    /// ```
    ///
    /// - parameter db: A database connection.
    /// - returns: An array of fetched rows.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func fetchAll(_ db: Database) throws -> [Row] {
        try Row.fetchAll(db, self)
    }
    
    /// Returns a set of fetched rows.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///     let request: SQLRequest<Row> = """
    ///         SELECT * FROM player WHERE lastName = \(lastName)
    ///         """
    ///     let rows = try request.fetchSet(db)
    /// }
    /// ```
    ///
    /// - parameter db: A database connection.
    /// - returns: A set of fetched rows.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func fetchSet(_ db: Database) throws -> Set<Row> {
        try Row.fetchSet(db, self)
    }
    
    /// Returns a single row.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///     let request: SQLRequest<Row> = """
    ///         SELECT * FROM player WHERE lastName = \(lastName) LIMIT 1
    ///         """
    ///     let rows = try request.fetchOne(db)
    /// }
    /// ```
    ///
    /// - parameter db: A database connection.
    /// - returns: An optional row.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func fetchOne(_ db: Database) throws -> Row? {
        try Row.fetchOne(db, self)
    }
}

extension Row: Equatable {
    /// Returns true if and only if both rows have the same columns and values,
    /// in the same order. Columns are compared in a case-sensitive way.
    public static func == (lhs: Row, rhs: Row) -> Bool {
        if lhs === rhs {
            return true
        }
        
        guard lhs.count == rhs.count else {
            return false
        }
        
        for ((lcol, lval), (rcol, rval)) in zip(lhs, rhs) {
            guard lcol == rcol else {
                return false
            }
            guard lval == rval else {
                return false
            }
        }
        
        let lscopeNames = lhs.scopes.names
        let rscopeNames = rhs.scopes.names
        guard lscopeNames == rscopeNames else {
            return false
        }
        
        for name in lscopeNames {
            let lscope = lhs.scopes[name]
            let rscope = rhs.scopes[name]
            guard lscope == rscope else {
                return false
            }
        }
        
        guard lhs.prefetchedRows == rhs.prefetchedRows else {
            return false
        }
        
        return true
    }
}

extension Row: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(count)
        for (column, dbValue) in self {
            hasher.combine(column)
            hasher.combine(dbValue)
        }
    }
}

extension Row: CustomStringConvertible { }

#warning("TODO: move to RowProtocol?")
extension Row: CustomDebugStringConvertible {
    public var debugDescription: String {
        debugDescription(level: 0)
    }
    
    private func debugDescription(level: Int) -> String {
        if level == 0 && self == self.unadapted && prefetchedRows.prefetches.isEmpty {
            return description
        }
        let prefix = repeatElement("  ", count: level + 1).joined()
        var str = ""
        if level == 0 {
            str = "▿ " + description
            let unadapted = self.unadapted
            if self != unadapted {
                str += "\n" + prefix + "unadapted: " + unadapted.description
            }
        } else {
            str = description
        }
        for (name, scopedRow) in scopes.sorted(by: { $0.name < $1.name }) {
            str += "\n" + prefix + "- " + name + ": " + scopedRow.debugDescription(level: level + 1)
        }
        for key in prefetchedRows.keys.sorted() {
            // rows is nil if key is a pivot in a "through" association
            if let rows = prefetchedRows[key] {
                let prefetchedRowsDescription: String
                switch rows.count {
                case 0:
                    prefetchedRowsDescription = "0 row"
                case 1:
                    prefetchedRowsDescription = "1 row"
                case let count:
                    prefetchedRowsDescription = "\(count) rows"
                }
                str += "\n" + prefix + "+ " + key + ": \(prefetchedRowsDescription)"
            }
        }
        
        return str
    }
}

extension Row: ExpressibleByDictionaryLiteral {
    /// Creates a row initialized with elements. Column order is preserved, and
    /// duplicated columns names are allowed.
    ///
    ///     let row: Row = ["foo": 1, "foo": "bar", "baz": nil]
    ///     print(row)
    ///     // Prints [foo:1 foo:"bar" baz:NULL]
    public convenience init(dictionaryLiteral elements: (String, (any DatabaseValueConvertible)?)...) {
        self.init(impl: ArrayRowImpl(columns: elements.map { ($0, $1?.databaseValue ?? .null) }))
    }
}

extension Row {
#warning("TODO: document")
    public convenience init(columnsWithValues: KeyValuePairs<String, (any DatabaseValueConvertible)?>) {
        self.init(impl: ArrayRowImpl(columns: columnsWithValues.map { ($0, $1?.databaseValue ?? .null) }))
    }
}

// MARK: - Row.ScopesView

extension Row {
    /// A view on the scopes defined by row adapters.
    ///
    /// `ScopesView` is a `Collection` of `(name: String, row: Row)` pairs.
    ///
    /// See ``Row/scopes`` for more information.
    public struct ScopesView {
        private let row: Row
        private let scopes: [String: any _LayoutedRowAdapter]
        private let prefetchedRows: Row.PrefetchedRowsView
        
        /// The available scopes in this row.
        public var names: Dictionary<String, any _LayoutedRowAdapter>.Keys {
            scopes.keys
        }
        
        init() {
            self.init(row: Row(), scopes: [:], prefetchedRows: Row.PrefetchedRowsView())
        }
        
        init(row: Row, scopes: [String: any _LayoutedRowAdapter], prefetchedRows: Row.PrefetchedRowsView) {
            self.row = row
            self.scopes = scopes
            self.prefetchedRows = prefetchedRows
        }
        
        /// The row associated with the given scope, or nil if the scope is
        /// not available.
        public subscript(_ name: String) -> Row? {
            scopes.index(forKey: name).map { self[$0].row }
        }
    }
}

extension Row.ScopesView: Collection {
    public typealias Index = Dictionary<String, any _LayoutedRowAdapter>.Index
    
    public var startIndex: Index {
        scopes.startIndex
    }
    
    public var endIndex: Index {
        scopes.endIndex
    }
    
    public func index(after i: Index) -> Index {
        scopes.index(after: i)
    }
    
    public subscript(position: Index) -> (name: String, row: Row) {
        let (name, adapter) = scopes[position]
        let adaptedRow = Row(base: row, adapter: adapter)
        if let prefetch = prefetchedRows.prefetches[name] {
            // Let the adapted row access its own prefetched rows.
            // Use case:
            //
            //      let request = A.including(required: A.b.including(all: B.c))
            //      let row = try Row.fetchOne(db, request)!
            //      row.prefetchedRows["cs"]              // Some array
            //      row.scopes["b"]!.prefetchedRows["cs"] // The same array
            adaptedRow.prefetchedRows = Row.PrefetchedRowsView(prefetches: prefetch.prefetches)
        }
        return (name: name, row: adaptedRow)
    }
}

// MARK: - Row.ScopesTreeView

extension Row {
    
    /// A view on the scopes tree defined by row adapters.
    ///
    /// See ``Row/scopesTree`` for more information.
    public struct ScopesTreeView {
        let scopes: ScopesView
        
        /// The scopes available on this row, recursively.
        public var names: Set<String> {
            var names = Set<String>()
            for (name, row) in scopes {
                names.insert(name)
                names.formUnion(row.scopesTree.names)
            }
            return names
        }
        
        /// The row associated with the given scope, or nil if the scope is
        /// not available.
        ///
        /// See ``Row/scopesTree`` for more information.
        ///
        /// - parameter key: An association key.
        public subscript(_ name: String) -> Row? {
            var fifo = Array(scopes)
            while !fifo.isEmpty {
                let scope = fifo.removeFirst()
                if scope.name == name {
                    return scope.row
                }
                fifo.append(contentsOf: scope.row.scopes)
            }
            return nil
        }
    }
}

// MARK: - Row.PrefetchedRowsView

extension Row {
    fileprivate struct Prefetch: Equatable {
        // Nil for intermediate associations
        var rows: [Row]?
        // OrderedDictionary so that breadth-first search gives a consistent result
        // (we preserve the ordering of associations in the request)
        var prefetches: OrderedDictionary<String, Prefetch>
    }
    
    /// A view on the prefetched associated rows.
    ///
    /// See ``Row/prefetchedRows`` for more information.
    public struct PrefetchedRowsView: Equatable {
        // OrderedDictionary so that breadth-first search gives a consistent result
        // (we preserve the ordering of associations in the request)
        fileprivate var prefetches: OrderedDictionary<String, Prefetch> = [:]
        
        /// A boolean value indicating if there is no prefetched
        /// associated rows.
        public var isEmpty: Bool {
            prefetches.isEmpty
        }
        
        /// The available association keys.
        ///
        /// Keys in the returned set can be used with ``subscript(_:)``.
        ///
        /// For example:
        ///
        /// ```swift
        /// struct Author: TableRecord {
        ///     static let books = hasMany(Book.self)
        /// }
        ///
        /// struct Book: TableRecord { }
        ///
        /// let request = Author.including(all: Author.books)
        /// let authorRow = try Row.fetchOne(db, request)!
        ///
        /// print(authorRow.prefetchedRows.keys)
        /// // Prints ["books"]
        ///
        /// let bookRows = authorRow.prefetchedRows["books"]!
        /// print(bookRows[0])
        /// // Prints [id:42, title:"Moby-Dick", authorId:1]
        /// print(bookRows[1])
        /// // Prints [id:57, title:"Pierre", authorId:1]
        /// ```
        public var keys: Set<String> {
            var result: Set<String> = []
            var fifo = Array(prefetches)
            while !fifo.isEmpty {
                let (prefetchKey, prefetch) = fifo.removeFirst()
                if prefetch.rows != nil {
                    result.insert(prefetchKey)
                }
                fifo.append(contentsOf: prefetch.prefetches)
            }
            return result
        }
        
        /// The prefetched rows associated with the given association key.
        ///
        /// The result is nil if the key is not available.
        ///
        /// See ``Row/prefetchedRows`` for more information.
        ///
        /// - parameter key: An association key.
        public subscript(_ key: String) -> [Row]? {
            var fifo = Array(prefetches)
            while !fifo.isEmpty {
                let (prefetchKey, prefetch) = fifo.removeFirst()
                if prefetchKey == key,
                   let rows = prefetch.rows // nil for "through" associations
                {
                    return rows
                }
                fifo.append(contentsOf: prefetch.prefetches)
            }
            return nil
        }
        
        mutating func setRows(_ rows: [Row], forKeyPath keyPath: [String]) {
            prefetches.setRows(rows, forKeyPath: keyPath)
        }
    }
}

extension OrderedDictionary<String, Row.Prefetch> {
    fileprivate mutating func setRows(_ rows: [Row], forKeyPath keyPath: [String]) {
        var keyPath = keyPath
        let key = keyPath.removeFirst()
        if keyPath.isEmpty {
            self[key, default: Row.Prefetch(rows: nil, prefetches: [:])].rows = rows
        } else {
            self[key, default: Row.Prefetch(rows: nil, prefetches: [:])].prefetches.setRows(rows, forKeyPath: keyPath)
        }
    }
}

// MARK: - RowImpl

// The protocol for Row underlying implementation
protocol RowImpl {
    var count: Int { get }
    var isFetched: Bool { get }
    
    func scopes(prefetchedRows: Row.PrefetchedRowsView) -> Row.ScopesView
    func columnName(atUncheckedIndex index: Int) -> String
    func hasNull(atUncheckedIndex index: Int) -> Bool
    func databaseValue(atUncheckedIndex index: Int) -> DatabaseValue
    
    func fastDecode<Value: DatabaseValueConvertible & StatementColumnConvertible>(
        _ type: Value.Type,
        atUncheckedIndex index: Int)
    throws -> Value
    
    func withUnsafeData<T>(atUncheckedIndex index: Int, _ body: (Data?) throws -> T) throws -> T
    
    /// Returns the index of the leftmost column that matches *name* (case-insensitive)
    func index(forColumn name: String) -> Int?
    
    // row.impl is guaranteed to be self.
    func unscopedRow(_ row: Row) -> Row
    func unadaptedRow(_ row: Row) -> Row
    func copiedRow(_ row: Row) -> Row
}

extension RowImpl {
    func copiedRow(_ row: Row) -> Row {
        // unless customized, assume unsafe and unadapted row
        Row(impl: ArrayRowImpl(columns: Array(row)))
    }
    
    func unscopedRow(_ row: Row) -> Row {
        // unless customized, assume unadapted row (see AdaptedRowImpl for customization)
        row
    }
    
    func unadaptedRow(_ row: Row) -> Row {
        // unless customized, assume unadapted row (see AdaptedRowImpl for customization)
        row
    }
    
    func scopes(prefetchedRows: Row.PrefetchedRowsView) -> Row.ScopesView {
        // unless customized, assume unuscoped row (see AdaptedRowImpl for customization)
        Row.ScopesView()
    }
    
    func hasNull(atUncheckedIndex index: Int) -> Bool {
        // unless customized, use slow check (see StatementRowImpl and AdaptedRowImpl for customization)
        databaseValue(atUncheckedIndex: index).isNull
    }
    
    func fastDecode<Value: DatabaseValueConvertible & StatementColumnConvertible>(
        _ type: Value.Type,
        atUncheckedIndex index: Int)
    throws -> Value
    {
        // unless customized, use slow decoding (see StatementRowImpl and AdaptedRowImpl for customization)
        try Value._decode(
            databaseValue: databaseValue(atUncheckedIndex: index),
            context: Row(impl: self)._makeRowDecodingContext(forKey: .columnIndex(index)))
    }
    
    func withUnsafeData<T>(atUncheckedIndex index: Int, _ body: (Data?) throws -> T) throws -> T {
        // unless customized, copy data (see StatementRowImpl and AdaptedRowImpl for customization)
        let data = try Optional<Data>._decode(
            databaseValue: databaseValue(atUncheckedIndex: index),
            context: Row(impl: self)._makeRowDecodingContext(forKey: .columnIndex(index)))
        return try body(data)
    }
}

// TODO: merge with StatementCopyRowImpl eventually?
/// See Row.init(dictionary:)
struct ArrayRowImpl: RowImpl {
    let columns: [(String, DatabaseValue)]
    
    init<Columns>(columns: Columns)
    where Columns: Collection, Columns.Element == (String, DatabaseValue)
    {
        self.columns = Array(columns)
    }
    
    var count: Int { columns.count }
    
    var isFetched: Bool { false }
    
    func databaseValue(atUncheckedIndex index: Int) -> DatabaseValue {
        columns[index].1
    }
    
    func columnName(atUncheckedIndex index: Int) -> String {
        columns[index].0
    }
    
    func index(forColumn name: String) -> Int? {
        let lowercaseName = name.lowercased()
        return columns.firstIndex { (column, _) in column.lowercased() == lowercaseName }
    }
    
    func copiedRow(_ row: Row) -> Row {
        row
    }
}

extension ArrayRowImpl: Sendable { }

// TODO: merge with ArrayRowImpl eventually?
/// See Row.init(copiedFromStatementRef:sqliteStatement:)
private struct StatementCopyRowImpl: RowImpl {
    let dbValues: ContiguousArray<DatabaseValue>
    let columnNames: [String]
    
    init(sqliteStatement: SQLiteStatement, columnNames: [String]) {
        let sqliteStatement = sqliteStatement
        self.dbValues = ContiguousArray(
            (0..<sqlite3_column_count(sqliteStatement))
                .map { DatabaseValue(sqliteStatement: sqliteStatement, index: $0) }
                as [DatabaseValue])
        self.columnNames = columnNames
    }
    
    var count: Int { columnNames.count }
    
    var isFetched: Bool { true }
    
    func databaseValue(atUncheckedIndex index: Int) -> DatabaseValue {
        dbValues[index]
    }
    
    func columnName(atUncheckedIndex index: Int) -> String {
        columnNames[index]
    }
    
    func index(forColumn name: String) -> Int? {
        let lowercaseName = name.lowercased()
        return columnNames.firstIndex { $0.lowercased() == lowercaseName }
    }
    
    func copiedRow(_ row: Row) -> Row {
        row
    }
}

/// See Row.init(statement:)
private struct StatementRowImpl: RowImpl {
    let statement: Statement
    let sqliteStatement: SQLiteStatement
    let lowercaseColumnIndexes: [String: Int]
    
    init(sqliteStatement: SQLiteStatement, statement: Statement) {
        self.statement = statement
        self.sqliteStatement = sqliteStatement
        // Optimize row[columnName]
        let lowercaseColumnNames = (0..<sqlite3_column_count(sqliteStatement))
            .map { String(cString: sqlite3_column_name(sqliteStatement, CInt($0))).lowercased() }
        self.lowercaseColumnIndexes = Dictionary(
            lowercaseColumnNames
                .enumerated()
                .map { ($0.element, $0.offset) },
            uniquingKeysWith: { (left, _) in left }) // keep leftmost indexes
    }
    
    var count: Int {
        Int(sqlite3_column_count(sqliteStatement))
    }
    
    var isFetched: Bool { true }
    
    func hasNull(atUncheckedIndex index: Int) -> Bool {
        // Avoid extracting values, because this modifies the SQLite statement.
        sqlite3_column_type(sqliteStatement, CInt(index)) == SQLITE_NULL
    }
    
    func databaseValue(atUncheckedIndex index: Int) -> DatabaseValue {
        DatabaseValue(sqliteStatement: sqliteStatement, index: CInt(index))
    }
    
    func fastDecode<Value: DatabaseValueConvertible & StatementColumnConvertible>(
        _ type: Value.Type,
        atUncheckedIndex index: Int)
    throws -> Value
    {
        try Value._fastDecode(
            sqliteStatement: sqliteStatement,
            atUncheckedIndex: CInt(index),
            context: _RowDecodingContext(statement: statement, index: index))
    }
    
    func withUnsafeData<T>(atUncheckedIndex index: Int, _ body: (Data?) throws -> T) throws -> T {
        guard sqlite3_column_type(sqliteStatement, CInt(index)) != SQLITE_NULL else {
            return try body(nil)
        }
        guard let bytes = sqlite3_column_blob(sqliteStatement, CInt(index)) else {
            return try body(Data())
        }
        
        let count = Int(sqlite3_column_bytes(sqliteStatement, CInt(index)))
        let data = Data(bytesNoCopy: UnsafeMutableRawPointer(mutating: bytes), count: count, deallocator: .none)
        return try body(data)
    }
    
    func columnName(atUncheckedIndex index: Int) -> String {
        statement.columnNames[index]
    }
    
    func index(forColumn name: String) -> Int? {
        if let index = lowercaseColumnIndexes[name] {
            return index
        }
        return lowercaseColumnIndexes[name.lowercased()]
    }
    
    func copiedRow(_ row: Row) -> Row {
        Row(copiedFromSQLiteStatement: sqliteStatement, statement: statement)
    }
}

// This one is not optimized at all, since it is only used in fatal conversion errors, so far
private struct SQLiteStatementRowImpl: RowImpl {
    let sqliteStatement: SQLiteStatement
    var count: Int { Int(sqlite3_column_count(sqliteStatement)) }
    var isFetched: Bool { true }
    
    func columnName(atUncheckedIndex index: Int) -> String {
        String(cString: sqlite3_column_name(sqliteStatement, CInt(index)))
    }
    
    func databaseValue(atUncheckedIndex index: Int) -> DatabaseValue {
        DatabaseValue(sqliteStatement: sqliteStatement, index: CInt(index))
    }
    
    func index(forColumn name: String) -> Int? {
        let name = name.lowercased()
        for index in 0..<count where columnName(atUncheckedIndex: index).lowercased() == name {
            return index
        }
        return nil
    }
}

/// See Row.init()
private struct EmptyRowImpl: RowImpl {
    var count: Int { 0 }
    
    var isFetched: Bool { false }
    
    func databaseValue(atUncheckedIndex index: Int) -> DatabaseValue {
        // Programmer error
        fatalError("row index out of range")
    }
    
    func columnName(atUncheckedIndex index: Int) -> String {
        // Programmer error
        fatalError("row index out of range")
    }
    
    func index(forColumn name: String) -> Int? { nil }
    
    func copiedRow(_ row: Row) -> Row { row }
}

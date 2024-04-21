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
    
    // MARK: - Not Public
    
    /// Returns true if and only if the row was fetched from a database.
    var isFetched: Bool { impl.isFetched }
    
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

extension Row: CustomStringConvertible {
    public var description: String {
        "["
        + map { (column, dbValue) in "\(column):\(dbValue)" }.joined(separator: " ")
        + "]"
    }
}

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

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

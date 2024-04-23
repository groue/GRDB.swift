/// A cursor that lazily iterates the results of a prepared ``Statement``.
///
/// ## Overview
///
/// To get a `DatabaseCursor` instance, use one of the `fetchCursor` methods.
/// For example:
///
/// - A cursor of ``Row`` built from a prepared ``Statement``:
///
///     ```swift
///     try dbQueue.read { db in
///         let statement = try db.makeStatement(sql: "SELECT * FROM player")
///         let rows = try Row.fetchCursor(statement)
///         while let row = try rows.next() {
///             let id: Int64 = row["id"]
///             let name: String = row["name"]
///         }
///     }
///     ```
///
/// - A cursor of `Int` built from an SQL string (see ``DatabaseValueConvertible``):
///
///     ```swift
///     try dbQueue.read { db in
///         let sql = "SELECT score FROM player"
///         let scores = try Int.fetchCursor(db, sql: sql)
///         while let score = try scores.next() {
///             print(score)
///         }
///     }
///     ```
///
/// - A cursor of `Player` records built from a request (see ``FetchableRecord`` and ``FetchRequest``):
///
///     ```swift
///     try dbQueue.read { db in
///         let request = Player.all()
///         let players = try request.fetchCursor(db)
///         while let player = try players.next() {
///             print(player.name, player.score)
///         }
///     }
///     ```
///
/// A database cursor is valid only during the current database access (read or
/// write). Do not store or escape a cursor for later use.
///
/// A database cursor resets its underlying prepared statement with
/// [`sqlite3_reset`](https://www.sqlite.org/c3ref/reset.html) when the cursor
/// is created, and when it is deallocated. Don't share the same prepared
/// statement between two cursors!
public protocol DatabaseCursor<Element>: Cursor {
    /// Must be initialized to false.
    var _isDone: Bool { get set }
    
    /// The statement iterated by the cursor
    var _statement: Statement { get }
    
    /// Called after one successful call to `sqlite3_step()`. Returns the
    /// element for the current statement step.
    func _element(sqliteStatement: SQLiteStatement) throws -> Element
}

// Read-only access to statement information. We don't want the user to modify
// a statement through a cursor, in case this would mess with the cursor state.
extension DatabaseCursor {
    /// The SQL query.
    public var sql: String { _statement.sql }
    
    /// The statement arguments.
    public var arguments: StatementArguments { _statement.arguments }
    
    /// The column names, ordered from left to right.
    public var columnNames: [String] { _statement.columnNames }
    
    /// The number of columns in the resulting rows.
    public var columnCount: Int { _statement.columnCount }
    
    /// The database region that the cursor looks into.
    public var databaseRegion: DatabaseRegion { _statement.databaseRegion }
}

extension DatabaseCursor {
    @inlinable
    public func next() throws -> Element? {
        if _isDone {
            return nil
        }
        if let element = try _statement.step(_element) {
            return element
        }
        _isDone = true
        return nil
    }
    
    // Specific implementation of `forEach`, for a slight performance
    // improvement due to the single `sqlite3_stmt_busy` check.
    @inlinable
    public func forEach(_ body: (Element) throws -> Void) throws {
        if _isDone { return }
        try _statement.forEachStep {
            try body(_element(sqliteStatement: $0))
        }
        _isDone = true
    }
}

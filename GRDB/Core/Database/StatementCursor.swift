/// A cursor that iterates a database statement without producing any value.
/// Each call to the `next()` method calls the `sqlite3_step()` C function.
///
/// For example:
///
/// ```swift
/// try dbQueue.read { db in
///     let statement = try db.makeStatement(sql: "SELECT performSideEffect()")
///     let cursor = statement.makeCursor()
///     try cursor.next()
/// }
/// ```
final class StatementCursor: DatabaseCursor {
    typealias Element = Void
    let _statement: Statement
    var _isDone = false
    
    // Use Statement.makeCursor() instead
    init(statement: Statement, arguments: StatementArguments? = nil) throws {
        self._statement = statement
        
        // Assume cursor is created for immediate iteration: reset and set arguments
        try statement.prepareExecution(withArguments: arguments)
    }
    
    deinit {
        // Statement reset fails when sqlite3_step has previously failed.
        // Just ignore reset error.
        try? _statement.reset()
    }
    
    @inlinable
    func _element(sqliteStatement: SQLiteStatement) throws { }
}

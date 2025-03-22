/// A `TableDefinition` lets you modify the components of a database table.
///
/// You don't create instances of this class. Instead, you use the `Database`
/// ``Database/alter(table:body:)`` method:
///
/// ```swift
/// try db.alter(table: "player") { t in // t is TableAlteration
///     t.add(column: "bonus", .integer)
/// }
/// ```
///
/// Related SQLite documentation: <https://www.sqlite.org/lang_altertable.html>
public final class TableAlteration {
    let name: String
    
    enum TableAlterationKind {
        case add(ColumnDefinition)
        case addColumnLiteral(SQL)
        case rename(old: String, new: String)
        case drop(String)
    }
    
    var alterations: [TableAlterationKind] = []
    
    init(name: String) {
        self.name = name
    }
    
    /// Appends a column.
    ///
    /// For example:
    ///
    /// ```swift
    /// // ALTER TABLE player ADD COLUMN bonus integer
    /// try db.alter(table: "player") { t in
    ///     t.add(column: "bonus", .integer)
    /// }
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/lang_altertable.html>
    ///
    /// - parameter name: the column name.
    /// - parameter type: the column type.
    /// - returns: An ColumnDefinition that allows you to refine the
    ///   column definition.
    @discardableResult
    public func add(column name: String, _ type: Database.ColumnType? = nil) -> ColumnDefinition {
        let column = ColumnDefinition(name: name, type: type)
        alterations.append(.add(column))
        return column
    }
    
    /// Appends a column.
    ///
    /// For example:
    ///
    /// ```swift
    /// // ALTER TABLE player ADD COLUMN bonus integer
    /// try db.alter(table: "player") { t in
    ///     t.addColumn(sql: "bonus integer")
    /// }
    /// ```
    public func addColumn(sql: String) {
        alterations.append(.addColumnLiteral(SQL(sql: sql)))
    }
    
    /// Appends a column.
    ///
    /// ``SQL`` literals allow you to safely embed raw values in your SQL,
    /// without any risk of syntax errors or SQL injection:
    ///
    /// ```swift
    /// // ALTER TABLE player ADD COLUMN name TEXT DEFAULT 'Anonymous'
    /// try db.alter(table: "player") { t in
    ///     t.addColumn(literal: "name TEXT DEFAULT \(defaultName)")
    /// }
    /// ```
    public func addColumn(literal: SQL) {
        alterations.append(.addColumnLiteral(literal))
    }
    
#if GRDBCUSTOMSQLITE || GRDBCIPHER
    /// Renames a column.
    ///
    /// For example:
    ///
    /// ```swift
    /// try db.alter(table: "player") { t in
    ///     t.rename(column: "url", to: "homeURL")
    /// }
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/lang_altertable.html>
    ///
    /// - parameter name: the old name of the column.
    /// - parameter newName: the new name of the column.
    public func rename(column name: String, to newName: String) {
        _rename(column: name, to: newName)
    }
    
    /// Drops a column.
    ///
    /// For example:
    ///
    /// ```swift
    /// try db.alter(table: "player") { t in
    ///     t.drop(column: "age")
    /// }
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/lang_altertable.html>
    ///
    /// - Parameter name: the name of the column to drop.
    public func drop(column name: String) {
        _drop(column: name)
    }
#else
    /// Renames a column.
    ///
    /// For example:
    ///
    /// ```swift
    /// try db.alter(table: "player") { t in
    ///     t.rename(column: "url", to: "homeURL")
    /// }
    /// ```
    ///
    /// Take care, when you rename **foreign keys** in <doc:Migrations>,
    /// to run the migration with the ``DatabaseMigrator/ForeignKeyChecks/immediate``
    /// foreign key checks, in order to avoid integrity failures:
    ///
    /// ```swift
    /// // RECOMMENDED: rename foreign keys with immediate foreign key checks.
    /// migrator.registerMigration("Guilds", foreignKeyChecks: .immediate) { db in
    ///     try db.rename(table: "team", to: "guild")
    ///     try db.alter(table: "player") { t in
    ///         t.rename(column: "teamId", to: "guildId")
    ///     }
    /// }
    ///
    /// // NOT RECOMMENDED: rename foreign keys with disabled foreign keys.
    /// migrator.registerMigration("Guilds") { db in
    ///     try db.rename(table: "team", to: "guild")
    ///     try db.alter(table: "player") { t in
    ///         t.rename(column: "teamId", to: "guildId")
    ///     }
    /// }
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/lang_altertable.html>
    ///
    /// - parameter name: the old name of the column.
    /// - parameter newName: the new name of the column.
    public func rename(column name: String, to newName: String) {
        _rename(column: name, to: newName)
    }
    
    /// Drops a column.
    ///
    /// For example:
    ///
    /// ```swift
    /// try db.alter(table: "player") { t in
    ///     t.drop(column: "age")
    /// }
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/lang_altertable.html>
    ///
    /// - Parameter name: the name of the column to drop.
    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) // SQLite 3.35.0+
    public func drop(column name: String) {
        _drop(column: name)
    }
#endif
    
    private func _rename(column name: String, to newName: String) {
        alterations.append(.rename(old: name, new: newName))
    }
    
    private func _drop(column name: String) {
        alterations.append(.drop(name))
    }
}

// Explicit non-conformance to Sendable: `TableAlteration` is a mutable
// class and there is no known reason for making it thread-safe.
@available(*, unavailable)
extension TableAlteration: Sendable { }

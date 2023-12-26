/// Describes a database column.
///
/// You get instances of `ColumnDefinition` when you create or alter a database
/// tables. For example:
///
/// ```swift
/// try db.create(table: "player") { t in
///     t.column("name", .text)          // ColumnDefinition
/// }
///
/// try db.alter(table: "player") { t in
///     t.add(column: "score", .integer) // ColumnDefinition
/// }
/// ```
///
/// See ``TableDefinition/column(_:_:)`` and ``TableAlteration/add(column:_:)``.
///
/// Related SQLite documentation:
///
/// - <https://www.sqlite.org/lang_createtable.html>
/// - <https://www.sqlite.org/lang_altertable.html>
///
/// ## Topics
///
/// ### Foreign Keys
///
/// - ``references(_:column:onDelete:onUpdate:deferred:)``
///
/// ### Indexes
///
/// - ``indexed()``
/// - ``unique(onConflict:)``
///
/// ### Default value
///
/// - ``defaults(to:)``
/// - ``defaults(sql:)``
///
/// ### Collations
///
/// - ``collate(_:)-4dljx``
/// - ``collate(_:)-9ywza``
///
/// ### Generated Columns
///
/// - ``generatedAs(_:_:)``
/// - ``generatedAs(sql:_:)``
/// - ``GeneratedColumnQualification``
///
/// ### Other Constraints
///
/// - ``check(_:)``
/// - ``check(sql:)``
/// - ``notNull(onConflict:)``
///
/// ### Sunsetted Methods
///
/// Those are legacy interfaces that are preserved for backwards compatibility.
/// Their use is not recommended.
///
/// - ``primaryKey(onConflict:autoincrement:)``
public final class ColumnDefinition {
    enum Indexing {
        case index
        case unique(Database.ConflictResolution)
    }
    
    struct ForeignKeyConstraint {
        var destinationTable: String
        var destinationColumn: String?
        var deleteAction: Database.ForeignKeyAction?
        var updateAction: Database.ForeignKeyAction?
        var isDeferred: Bool
    }
    
    /// The kind of a generated column.
    ///
    /// Related SQLite documentation: <https://sqlite.org/gencol.html#virtual_versus_stored_columns>
    public enum GeneratedColumnQualification {
        /// A `VIRTUAL` generated column.
        case virtual
        /// A `STORED` generated column.
        case stored
    }
    
    struct GeneratedColumnConstraint {
        var expression: SQLExpression
        var qualification: GeneratedColumnQualification
    }
    
    let name: String
    let type: Database.ColumnType?
    var primaryKey: (conflictResolution: Database.ConflictResolution?, autoincrement: Bool)?
    var indexing: Indexing?
    var notNullConflictResolution: Database.ConflictResolution?
    var checkConstraints: [SQLExpression] = []
    var foreignKeyConstraints: [ForeignKeyConstraint] = []
    var defaultExpression: SQLExpression?
    var collationName: String?
    var generatedColumnConstraint: GeneratedColumnConstraint?
    
    init(name: String, type: Database.ColumnType?) {
        self.name = name
        self.type = type
    }
    
    /// Adds a primary key constraint.
    ///
    /// For example:
    ///
    /// ```swift
    /// // CREATE TABLE player(
    /// //   id TEXT NOT NULL PRIMARY KEY
    /// // )
    /// try db.create(table: "player") { t in
    ///     t.primaryKey("id", .text)
    /// }
    /// ```
    ///
    /// - important: Make sure you add a not null constraint on your primary key
    ///   column, as in the above example, or SQLite will allow null values.
    ///   See <https://www.sqlite.org/quirks.html#primary_keys_can_sometimes_contain_nulls>
    ///   for more information.
    ///
    /// - warning: This is a legacy interface that is preserved for backwards
    ///   compatibility. Use of this interface is not recommended: prefer
    ///   ``TableDefinition/primaryKey(_:_:onConflict:)``
    ///   instead.
    ///
    /// - parameters:
    ///     - conflictResolution: An optional ``Database/ConflictResolution``.
    ///     - autoincrement: If true, the primary key is autoincremented.
    /// - returns: `self` so that you can further refine the column definition.
    @discardableResult
    public func primaryKey(
        onConflict conflictResolution: Database.ConflictResolution? = nil,
        autoincrement: Bool = false)
    -> Self
    {
        primaryKey = (conflictResolution: conflictResolution, autoincrement: autoincrement)
        return self
    }
    
    /// Adds a not null constraint.
    ///
    /// For example:
    ///
    /// ```swift
    /// // CREATE TABLE player(
    /// //   name TEXT NOT NULL
    /// // )
    /// try db.create(table: "player") { t in
    ///     t.column("name", .text).notNull()
    /// }
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/lang_createtable.html#notnullconst>
    ///
    /// - parameter conflictResolution: An optional ``Database/ConflictResolution``.
    /// - returns: `self` so that you can further refine the column definition.
    @discardableResult
    public func notNull(onConflict conflictResolution: Database.ConflictResolution? = nil) -> Self {
        notNullConflictResolution = conflictResolution ?? .abort
        return self
    }
    
    /// Adds a unique constraint.
    ///
    /// For example:
    ///
    /// ```swift
    /// // CREATE TABLE player(
    /// //   email TEXT UNIQUE
    /// // )
    /// try db.create(table: "player") { t in
    ///     t.column("email", .text).unique()
    /// }
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/lang_createtable.html#uniqueconst>
    ///
    /// - parameter conflictResolution: An optional ``Database/ConflictResolution``.
    /// - returns: `self` so that you can further refine the column definition.
    @discardableResult
    public func unique(onConflict conflictResolution: Database.ConflictResolution? = nil) -> Self {
        indexing = .unique(conflictResolution ?? .abort)
        return self
    }
    
    /// Adds an index.
    ///
    /// For example:
    ///
    /// ```swift
    /// // CREATE TABLE player(email TEXT);
    /// // CREATE INDEX player_on_email ON player(email);
    /// try db.create(table: "player") { t in
    ///     t.column("email", .text).indexed()
    /// }
    /// ```
    ///
    /// The name of the created index is `<table>_on_<column>`, where `table`
    /// and `column` are the names of the table and the column. See the
    /// example above.
    ///
    /// See also ``unique(onConflict:)``.
    ///
    /// - returns: `self` so that you can further refine the column definition.
    @discardableResult
    public func indexed() -> Self {
        if case .none = indexing {
            self.indexing = .index
        }
        return self
    }
    
    /// Adds a check constraint.
    ///
    /// For example:
    ///
    /// ```swift
    /// // CREATE TABLE player(
    /// //   name TEXT CHECK (LENGTH(name) > 0)
    /// // )
    /// try db.create(table: "player") { t in
    ///     t.column("name", .text).check { length($0) > 0 }
    /// }
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/lang_createtable.html#ckconst>
    ///
    /// - parameter condition: A closure whose argument is a ``Column`` that
    ///   represents the defined column, and returns the expression to check.
    /// - returns: `self` so that you can further refine the column definition.
    @discardableResult
    public func check(_ condition: (Column) -> any SQLExpressible) -> Self {
        checkConstraints.append(condition(Column(name)).sqlExpression)
        return self
    }
    
    /// Adds a check constraint.
    ///
    /// For example:
    ///
    /// ```swift
    /// // CREATE TABLE player(
    /// //   name TEXT CHECK (LENGTH(name) > 0)
    /// // )
    /// try db.create(table: "player") { t in
    ///     t.column("name", .text).check(sql: "LENGTH(name) > 0")
    /// }
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/lang_createtable.html#ckconst>
    ///
    /// - parameter sql: An SQL snippet.
    /// - returns: `self` so that you can further refine the column definition.
    @discardableResult
    public func check(sql: String) -> Self {
        checkConstraints.append(SQL(sql: sql).sqlExpression)
        return self
    }
    
    /// Defines the default value.
    ///
    /// For example:
    ///
    /// ```swift
    /// // CREATE TABLE player(
    /// //   email TEXT DEFAULT 'Anonymous'
    /// // )
    /// try db.create(table: "player") { t in
    ///     t.column("name", .text).defaults(to: "Anonymous")
    /// }
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/lang_createtable.html#dfltval>
    ///
    /// - parameter value: A ``DatabaseValueConvertible`` value.
    /// - returns: `self` so that you can further refine the column definition.
    @discardableResult
    public func defaults(to value: some DatabaseValueConvertible) -> Self {
        defaultExpression = value.sqlExpression
        return self
    }
    
    /// Defines the default value.
    ///
    /// For example:
    ///
    /// ```swift
    /// // CREATE TABLE player(
    /// //   creationDate DATETIME DEFAULT CURRENT_TIMESTAMP
    /// // )
    /// try db.create(table: "player") { t in
    ///     t.column("creationDate", .DateTime).defaults(sql: "CURRENT_TIMESTAMP")
    /// }
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/lang_createtable.html#dfltval>
    ///
    /// - parameter sql: An SQL snippet.
    /// - returns: `self` so that you can further refine the column definition.
    @discardableResult
    public func defaults(sql: String) -> Self {
        defaultExpression = SQL(sql: sql).sqlExpression
        return self
    }
    
    /// Defines the default collation.
    ///
    /// For example:
    ///
    /// ```swift
    /// // CREATE TABLE player(
    /// //   email TEXT COLLATE NOCASE
    /// // )
    /// try db.create(table: "player") { t in
    ///     t.column("email", .text).collate(.nocase)
    /// }
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/datatype3.html#collation>
    ///
    /// - parameter collation: A ``Database/CollationName``.
    /// - returns: `self` so that you can further refine the column definition.
    @discardableResult
    public func collate(_ collation: Database.CollationName) -> Self {
        collationName = collation.rawValue
        return self
    }
    
    /// Defines the default collation.
    ///
    /// For example:
    ///
    /// ```swift
    /// try db.create(table: "player") { t in
    ///     t.column("name", .text).collate(.localizedCaseInsensitiveCompare)
    /// }
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/datatype3.html#collation>
    ///
    /// - parameter collation: A ``DatabaseCollation``.
    /// - returns: `self` so that you can further refine the column definition.
    @discardableResult
    public func collate(_ collation: DatabaseCollation) -> Self {
        collationName = collation.name
        return self
    }
    
#if GRDBCUSTOMSQLITE || GRDBCIPHER
    /// Defines the column as a generated column.
    ///
    /// For example:
    ///
    /// ```swift
    /// // CREATE TABLE player(
    /// //   id INTEGER PRIMARY KEY AUTOINCREMENT,
    /// //   score INTEGER NOT NULL,
    /// //   bonus INTEGER NOT NULL,
    /// //   totalScore INTEGER GENERATED ALWAYS AS (score + bonus) VIRTUAL
    /// // )
    /// try db.create(table: "player") { t in
    ///     t.autoIncrementedPrimaryKey("id")
    ///     t.column("score", .integer).notNull()
    ///     t.column("bonus", .integer).notNull()
    ///     t.column("totalScore", .integer).generatedAs(sql: "score + bonus")
    /// }
    /// ```
    ///
    /// Related SQLite documentation: <https://sqlite.org/gencol.html>
    ///
    /// - parameters:
    ///     - sql: An SQL expression.
    ///     - qualification: The generated column's qualification, which
    ///       defaults to ``GeneratedColumnQualification/virtual``.
    /// - returns: `self` so that you can further refine the column definition.
    @discardableResult
    public func generatedAs(
        sql: String,
        _ qualification: GeneratedColumnQualification = .virtual)
    -> Self
    {
        let expression = SQL(sql: sql).sqlExpression
        generatedColumnConstraint = GeneratedColumnConstraint(
            expression: expression,
            qualification: qualification)
        return self
    }
    
    /// Defines the column as a generated column.
    ///
    /// For example:
    ///
    /// ```swift
    /// // CREATE TABLE player(
    /// //   id INTEGER PRIMARY KEY AUTOINCREMENT,
    /// //   score INTEGER NOT NULL,
    /// //   bonus INTEGER NOT NULL,
    /// //   totalScore INTEGER GENERATED ALWAYS AS (score + bonus) VIRTUAL
    /// // )
    /// try db.create(table: "player") { t in
    ///     t.autoIncrementedPrimaryKey("id")
    ///     t.column("score", .integer).notNull()
    ///     t.column("bonus", .integer).notNull()
    ///     t.column("totalScore", .integer).generatedAs(Column("score") + Column("bonus"))
    /// }
    /// ```
    ///
    /// Related SQLite documentation: <https://sqlite.org/gencol.html>
    ///
    /// - parameters:
    ///     - expression: The generated expression.
    ///     - qualification: The generated column's qualification, which
    ///       defaults to ``GeneratedColumnQualification/virtual``.
    /// - returns: `self` so that you can further refine the column definition.
    @discardableResult
    public func generatedAs(
        _ expression: some SQLExpressible,
        _ qualification: GeneratedColumnQualification = .virtual)
    -> Self
    {
        generatedColumnConstraint = GeneratedColumnConstraint(
            expression: expression.sqlExpression,
            qualification: qualification)
        return self
    }
#else
    /// Defines the column as a generated column.
    ///
    /// For example:
    ///
    /// ```swift
    /// // CREATE TABLE player(
    /// //   id INTEGER PRIMARY KEY AUTOINCREMENT,
    /// //   score INTEGER NOT NULL,
    /// //   bonus INTEGER NOT NULL,
    /// //   totalScore INTEGER GENERATED ALWAYS AS (score + bonus) VIRTUAL
    /// // )
    /// try db.create(table: "player") { t in
    ///     t.autoIncrementedPrimaryKey("id")
    ///     t.column("score", .integer).notNull()
    ///     t.column("bonus", .integer).notNull()
    ///     t.column("totalScore", .integer).generatedAs(sql: "score + bonus")
    /// }
    /// ```
    ///
    /// Related SQLite documentation: <https://sqlite.org/gencol.html>
    ///
    /// - parameters:
    ///     - sql: An SQL expression.
    ///     - qualification: The generated column's qualification, which
    ///       defaults to ``GeneratedColumnQualification/virtual``.
    /// - returns: `self` so that you can further refine the column definition.
    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) // SQLite 3.35.0+ (3.31 actually)
    @discardableResult
    public func generatedAs(
        sql: String,
        _ qualification: GeneratedColumnQualification = .virtual)
    -> Self
    {
        let expression = SQL(sql: sql).sqlExpression
        generatedColumnConstraint = GeneratedColumnConstraint(
            expression: expression,
            qualification: qualification)
        return self
    }
    
    /// Defines the column as a generated column.
    ///
    /// For example:
    ///
    /// ```swift
    /// // CREATE TABLE player(
    /// //   id INTEGER PRIMARY KEY AUTOINCREMENT,
    /// //   score INTEGER NOT NULL,
    /// //   bonus INTEGER NOT NULL,
    /// //   totalScore INTEGER GENERATED ALWAYS AS (score + bonus) VIRTUAL
    /// // )
    /// try db.create(table: "player") { t in
    ///     t.autoIncrementedPrimaryKey("id")
    ///     t.column("score", .integer).notNull()
    ///     t.column("bonus", .integer).notNull()
    ///     t.column("totalScore", .integer).generatedAs(Column("score") + Column("bonus"))
    /// }
    /// ```
    ///
    /// Related SQLite documentation: <https://sqlite.org/gencol.html>
    ///
    /// - parameters:
    ///     - expression: The generated expression.
    ///     - qualification: The generated column's qualification, which
    ///       defaults to ``GeneratedColumnQualification/virtual``.
    /// - returns: `self` so that you can further refine the column definition.
    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) // SQLite 3.35.0+ (3.31 actually)
    @discardableResult
    public func generatedAs(
        _ expression: some SQLExpressible,
        _ qualification: GeneratedColumnQualification = .virtual)
    -> Self
    {
        generatedColumnConstraint = GeneratedColumnConstraint(
            expression: expression.sqlExpression,
            qualification: qualification)
        return self
    }
#endif
    
    /// Adds a foreign key constraint.
    ///
    /// For example:
    ///
    /// ```swift
    /// // CREATE TABLE book(
    /// //   authorId INTEGER REFERENCES author(id) ON DELETE CASCADE
    /// // )
    /// try db.create(table: "book") { t in
    ///     t.column("authorId", .integer).references("author", onDelete: .cascade)
    /// }
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/foreignkeys.html>
    ///
    /// - parameters:
    ///     - table: The referenced table.
    ///     - column: The referenced column in the referenced table. If not
    ///       specified, the column of the primary key of the referenced table
    ///       is used.
    ///     - deleteAction: Optional action when the referenced row is deleted.
    ///     - updateAction: Optional action when the referenced row is updated.
    ///     - isDeferred: A boolean value indicating whether the foreign key
    ///       constraint is deferred.
    ///       See <https://www.sqlite.org/foreignkeys.html#fk_deferred>.
    /// - returns: `self` so that you can further refine the column definition.
    @discardableResult
    public func references(
        _ table: String,
        column: String? = nil,
        onDelete deleteAction: Database.ForeignKeyAction? = nil,
        onUpdate updateAction: Database.ForeignKeyAction? = nil,
        deferred isDeferred: Bool = false) -> Self
    {
        foreignKeyConstraints.append(ForeignKeyConstraint(
            destinationTable: table,
            destinationColumn: column,
            deleteAction: deleteAction,
            updateAction: updateAction,
            isDeferred: isDeferred))
        return self
    }
    
    func indexDefinition(in table: String, options: IndexOptions = []) -> IndexDefinition? {
        switch indexing {
        case .none: return nil
        case .unique: return nil
        case .index:
            return IndexDefinition(
                name: "\(table)_on_\(name)",
                table: table,
                expressions: [.column(name)],
                options: options,
                condition: nil)
        }
    }
}

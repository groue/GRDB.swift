/// Table creation options.
public struct TableOptions: OptionSet, Sendable {
    public let rawValue: Int
    
    public init(rawValue: Int) { self.rawValue = rawValue }
    
    /// Only creates the table if it does not already exist.
    public static let ifNotExists = TableOptions(rawValue: 1 << 0)
    
    /// Creates a temporary table.
    public static let temporary = TableOptions(rawValue: 1 << 1)
    
    /// Creates a [`WITHOUT ROWID`](https://www.sqlite.org/withoutrowid.html) table.
    ///
    /// Such tables can not be tracked with <doc:DatabaseObservation> tools.
    public static let withoutRowID = TableOptions(rawValue: 1 << 2)
    
#if GRDBCUSTOMSQLITE || GRDBCIPHER
    /// Creates a [STRICT](https://www.sqlite.org/stricttables.html) table.
    public static let strict = TableOptions(rawValue: 1 << 3)
#else
    /// Creates a [STRICT](https://www.sqlite.org/stricttables.html) table.
    @available(iOS 15.4, macOS 12.4, tvOS 15.4, watchOS 8.5, *) // SQLite 3.37+
    public static let strict = TableOptions(rawValue: 1 << 3)
#endif
}

/// A `TableDefinition` lets you define the components of a database table.
///
/// See the documentation of the `Database`
/// ``Database/create(table:options:body:)`` method for usage information:
///
/// ```swift
/// try db.create(table: "player") { t in // t is TableDefinition
///     t.autoIncrementedPrimaryKey("id")
///     t.column("name", .text).notNull()
/// }
/// ```
///
/// ## Topics
///
/// ### Define Columns
///
/// - ``column(_:_:)``
/// - ``column(literal:)``
/// - ``column(sql:)``
/// - ``ColumnDefinition``
///
/// ### Define the Primary Key
///
/// - ``autoIncrementedPrimaryKey(_:onConflict:)``
/// - ``primaryKey(_:_:onConflict:)``
/// - ``primaryKey(onConflict:body:)``
/// - ``primaryKey(_:onConflict:)``
///
/// ### Define a Foreign Key
///
/// - ``belongsTo(_:inTable:onDelete:onUpdate:deferred:indexed:)``
/// - ``foreignKey(_:references:columns:onDelete:onUpdate:deferred:)``
/// - ``ForeignKeyDefinition``
///
/// ### Define a Unique Key
///
/// - ``uniqueKey(_:onConflict:)``
///
/// ### Define Others Constraints
///
/// - ``check(_:)-6u1za``
/// - ``check(_:)-jpcg``
/// - ``check(sql:)``
/// - ``constraint(literal:)``
/// - ``constraint(sql:)``
public final class TableDefinition {
    struct KeyConstraint {
        enum Component {
            case columnName(String)
            case columnDefinition(ColumnDefinition)
            case foreignKeyDefinition(ForeignKeyDefinition)
        }
        var components: [Component]
        var conflictResolution: Database.ConflictResolution?
        
        init(components: [Component], conflictResolution: Database.ConflictResolution?) {
            self.components = components
            self.conflictResolution = conflictResolution
        }
        
        init(columns: [String], conflictResolution: Database.ConflictResolution?) {
            let components = columns.map { name in
                Component.columnName(name)
            }
            self.init(components: components, conflictResolution: conflictResolution)
        }
    }
    
    enum ColumnComponent {
        case columnDefinition(ColumnDefinition)
        case columnLiteral(SQL)
        case foreignKeyDefinition(ForeignKeyDefinition)
        case foreignKeyConstraint(SQLForeignKeyConstraint)
    }
    
    let name: String
    let options: TableOptions
    var columnComponents: [ColumnComponent] = []
    var inPrimaryKeyBody = false
    var primaryKeyConstraint: KeyConstraint?
    var uniqueKeyConstraints: [KeyConstraint] = []
    var checkConstraints: [SQLExpression] = []
    var literalConstraints: [SQL] = []
    
    init(name: String, options: TableOptions) {
        self.name = name
        self.options = options
    }
    
    /// Appends an auto-incremented primary key column.
    ///
    /// For example:
    ///
    /// ```swift
    /// // CREATE TABLE player (
    /// //   id INTEGER PRIMARY KEY AUTOINCREMENT
    /// // )
    /// try db.create(table: "player") { t in
    ///     t.autoIncrementedPrimaryKey("id")
    /// }
    /// ```
    ///
    /// The auto-incremented primary key is an integer primary key that
    /// automatically generates unused values when you do not explicitly
    /// provide one, and prevents the reuse of ids over the lifetime of
    /// the database.
    ///
    /// Related SQLite documentation:
    /// - <https://www.sqlite.org/lang_createtable.html#primkeyconst>
    /// - <https://www.sqlite.org/lang_createtable.html#rowid>
    ///
    /// - parameter name: the name of the primary key.
    /// - parameter conflictResolution: An optional conflict resolution
    ///   (see <https://www.sqlite.org/lang_conflict.html>).
    /// - returns: `self` so that you can further refine the column definition.
    @discardableResult
    public func autoIncrementedPrimaryKey(
        _ name: String,
        onConflict conflictResolution: Database.ConflictResolution? = nil)
    -> ColumnDefinition
    {
        column(name, .integer).primaryKey(onConflict: conflictResolution, autoincrement: true)
    }
    
    /// Appends a primary key column.
    ///
    /// For example:
    ///
    /// ```swift
    /// // CREATE TABLE country (
    /// //   isoCode TEXT NOT NULL PRIMARY KEY
    /// // )
    /// try db.create(table: "country") { t in
    ///     t.primaryKey("isoCode", .text)
    /// }
    /// ```
    ///
    /// - parameter name: the column name.
    /// - parameter type: the column type.
    /// - parameter conflictResolution: An optional conflict resolution
    ///   (see <https://www.sqlite.org/lang_conflict.html>).
    /// - returns: A ``ColumnDefinition`` that allows you to refine the
    ///   column definition.
    @discardableResult
    public func primaryKey(
        _ name: String,
        _ type: Database.ColumnType,
        onConflict conflictResolution: Database.ConflictResolution? = nil)
    -> ColumnDefinition
    {
        let pk = column(name, type).primaryKey(onConflict: conflictResolution)
        if type == .integer {
            // INTEGER PRIMARY KEY is always NOT NULL
            return pk
        } else {
            // Add a not null constraint in order to fix an SQLite bug:
            // <https://www.sqlite.org/quirks.html#primary_keys_can_sometimes_contain_nulls>
            return pk.notNull()
        }
    }
    
    /// Defines the primary key on wrapped columns.
    ///
    /// For example:
    ///
    /// ```swift
    /// // CREATE TABLE passport (
    /// //   citizenId INTEGER NOT NULL,
    /// //   countryCode TEXT NOT NULL,
    /// //   issueDate DATE NOT NULL,
    /// //   PRIMARY KEY (citizenId, countryCode)
    /// // )
    /// try db.create(table: "passport") { t in
    ///     t.primaryKey {
    ///         t.column("citizenId", .integer)
    ///         t.column("countryCode", .text)
    ///     }
    ///     t.column("issueDate", .date).notNull()
    /// }
    /// ```
    ///
    /// A NOT NULL constraint is always added to the wrapped primary key columns.
    public func primaryKey(
        onConflict conflictResolution: Database.ConflictResolution? = nil,
        body: () throws -> Void)
    rethrows
    {
        guard primaryKeyConstraint == nil else {
            // Programmer error
            fatalError("can't define several primary keys")
        }
        primaryKeyConstraint = KeyConstraint(components: [], conflictResolution: conflictResolution)
        
        let oldValue = inPrimaryKeyBody
        inPrimaryKeyBody = true
        defer { inPrimaryKeyBody = oldValue }
        try body()
    }
    
    /// Appends a table column.
    ///
    /// For example:
    ///
    /// ```swift
    /// // CREATE TABLE player (
    /// //   name TEXT
    /// // )
    /// try db.create(table: "player") { t in
    ///     t.column("name", .text)
    /// }
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/lang_createtable.html#tablecoldef>
    ///
    /// - parameter name: the column name.
    /// - parameter type: the eventual column type.
    /// - returns: A ``ColumnDefinition`` that allows you to refine the
    ///   column definition.
    @discardableResult
    public func column(_ name: String, _ type: Database.ColumnType? = nil) -> ColumnDefinition {
        let column = ColumnDefinition(name: name, type: type)
        columnComponents.append(.columnDefinition(column))
        
        if inPrimaryKeyBody {
            // Add a not null constraint in order to fix an SQLite bug:
            // <https://www.sqlite.org/quirks.html#primary_keys_can_sometimes_contain_nulls>
            column.notNull()
            primaryKeyConstraint!.components.append(.columnDefinition(column))
        }
        
        return column
    }
    
    /// Appends a table column.
    ///
    /// For example:
    ///
    /// ```swift
    /// // CREATE TABLE player (
    /// //   name TEXT
    /// // )
    /// try db.create(table: "player") { t in
    ///     t.column(sql: "name TEXT")
    /// }
    /// ```
    public func column(sql: String) {
        column(literal: SQL(sql: sql))
    }
    
    /// Appends a table column.
    ///
    /// ``SQL`` literals allow you to safely embed raw values in your SQL,
    /// without any risk of syntax errors or SQL injection:
    ///
    /// ```swift
    /// // CREATE TABLE player (
    /// //   name TEXT DEFAULT 'Anonymous'
    /// // )
    /// let defaultName = "Anonymous"
    /// try db.create(table: "player") { t in
    ///     t.column(literal: "name TEXT DEFAULT \(defaultName)")
    /// }
    /// ```
    public func column(literal: SQL) {
        GRDBPrecondition(!inPrimaryKeyBody, "Primary key columns can not be defined with raw SQL")
        columnComponents.append(.columnLiteral(literal))
    }
    
    /// Adds a primary key constraint.
    ///
    /// For example:
    ///
    /// ```swift
    /// // CREATE TABLE citizenship (
    /// //   citizenId INTEGER NOT NULL,
    /// //   countryCode TEXT NOT NULL,
    /// //   PRIMARY KEY (citizenId, countryCode)
    /// // )
    /// try db.create(table: "citizenship") { t in
    ///     t.column("citizenId", .integer).notNull()
    ///     t.column("countryCode", .text).notNull()
    ///     t.primaryKey(["citizenId", "countryCode"])
    /// }
    /// ```
    ///
    /// - important: Make sure you add not null constraints on your primary key
    ///   columns, as in the above example, or SQLite will allow null values.
    ///   See <https://www.sqlite.org/quirks.html#primary_keys_can_sometimes_contain_nulls>
    ///   for more information.
    ///
    /// - parameter columns: The primary key columns.
    /// - parameter conflictResolution: An optional conflict resolution
    ///   (see <https://www.sqlite.org/lang_conflict.html>).
    public func primaryKey(_ columns: [String], onConflict conflictResolution: Database.ConflictResolution? = nil) {
        guard primaryKeyConstraint == nil else {
            // Programmer error
            fatalError("can't define several primary keys")
        }
        primaryKeyConstraint = KeyConstraint(columns: columns, conflictResolution: conflictResolution)
    }
    
    /// Adds a unique constraint.
    ///
    /// For example:
    ///
    /// ```swift
    /// // CREATE TABLE place (
    /// //   latitude DOUBLE,
    /// //   longitude DOUBLE,
    /// //   UNIQUE (latitude, longitude)
    /// // )
    /// try db.create(table: "place") { t in
    ///     t.column("latitude", .double)
    ///     t.column("longitude", .double)
    ///     t.uniqueKey(["latitude", "longitude"])
    /// }
    /// ```
    ///
    /// When defining a unique constraint on a single column, you can use the
    /// ``ColumnDefinition/unique(onConflict:)`` shortcut:
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
    /// - parameter columns: The unique key columns.
    /// - parameter conflictResolution: An optional conflict resolution
    ///   (see <https://www.sqlite.org/lang_conflict.html>).
    public func uniqueKey(_ columns: [String], onConflict conflictResolution: Database.ConflictResolution? = nil) {
        uniqueKeyConstraints.append(KeyConstraint(columns: columns, conflictResolution: conflictResolution))
    }
    
    /// Adds a foreign key.
    ///
    /// For example:
    ///
    /// ```swift
    /// // CREATE TABLE passport (
    /// //   issueDate DATE NOT NULL,
    /// //   citizenId INTEGER NOT NULL,
    /// //   countryCode INTEGER NOT NULL,
    /// //   FOREIGN KEY (citizenId, countryCode)
    /// //     REFERENCES citizenship(citizenId, countryCode)
    /// //     ON DELETE CASCADE
    /// // )
    /// try db.create(table: "passport") { t in
    ///     t.column("issueDate", .date).notNull()
    ///     t.column("citizenId", .integer).notNull()
    ///     t.column("countryCode", .text).notNull()
    ///     t.foreignKey(["citizenId", "countryCode"], references: "citizenship", onDelete: .cascade)
    /// }
    /// ```
    ///
    /// When defining a foreign key on a single column, you can use the
    /// ``ColumnDefinition/references(_:column:onDelete:onUpdate:deferred:)``
    /// shortcut:
    ///
    /// ```swift
    /// try db.create(table: "player") { t in
    ///     t.column("teamId", .integer).references("team", onDelete: .cascade)
    /// }
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/foreignkeys.html>
    ///
    /// - parameters:
    ///     - columns: The foreign key columns.
    ///     - table: The referenced table.
    ///     - destinationColumns: The columns in the referenced table. If not
    ///       specified, the columns of the primary key of the referenced table
    ///       are used.
    ///     - deleteAction: Optional action when the referenced row is deleted.
    ///     - updateAction: Optional action when the referenced row is updated.
    ///     - isDeferred: A boolean value indicating whether the foreign key
    ///       constraint is deferred.
    ///       See <https://www.sqlite.org/foreignkeys.html#fk_deferred>.
    public func foreignKey(
        _ columns: [String],
        references table: String,
        columns destinationColumns: [String]? = nil,
        onDelete deleteAction: Database.ForeignKeyAction? = nil,
        onUpdate updateAction: Database.ForeignKeyAction? = nil,
        deferred isDeferred: Bool = false)
    {
        let foreignKeyConstraint = SQLForeignKeyConstraint(
            columns: columns,
            destinationTable: table,
            destinationColumns: destinationColumns,
            deleteAction: deleteAction,
            updateAction: updateAction,
            isDeferred: isDeferred)
        columnComponents.append(.foreignKeyConstraint(foreignKeyConstraint))
    }
    
    /// Declares an association to another table.
    ///
    /// `belongsTo` appends as many columns as there are columns in the
    /// primary key of the referenced table, and declares a foreign key that
    /// guarantees schema integrity. All primary keys are supported,
    /// including composite primary keys that span several columns, and the
    /// hidden `rowid` column.
    ///
    /// Added columns are prefixed with `name`, and end with the name of the
    /// matching column in the primary key of the referenced table. In the
    /// following example, `belongsTo("team")` adds a `teamId` column, and
    /// `belongsTo("country")` adds a `countryCode` column:
    ///
    /// ```swift
    /// try db.create(table: "team") { t in
    ///     t.autoIncrementedPrimaryKey("id")
    /// }
    /// try db.create(table: "country") { t in
    ///     t.primaryKey("code", .text)
    /// }
    ///
    /// // CREATE TABLE player (
    /// //   id INTEGER PRIMARY KEY AUTOINCREMENT,
    /// //   teamId INTEGER REFERENCES team(id),
    /// //   countryCode TEXT NOT NULL REFERENCES country(code),
    /// // )
    /// try db.create(table: "player") { t in
    ///     t.autoIncrementedPrimaryKey("id")
    ///     t.belongsTo("team")
    ///     t.belongsTo("country").notNull()
    /// }
    /// ```
    ///
    /// When in doubt, you can check the names of the created columns:
    ///
    /// ```swift
    /// // Prints ["id", "teamId", "countryCode"]
    /// try print(db.columns(in: "player").map(\.name))
    /// ```
    ///
    /// Singular names can refer to database tables whose name is plural:
    ///
    /// ```swift
    /// try db.create(table: "teams") { t in
    ///     t.autoIncrementedPrimaryKey("id")
    /// }
    /// try db.create(table: "countries") { t in
    ///     t.primaryKey("code", .text)
    /// }
    ///
    /// // CREATE TABLE players (
    /// //   teamId INTEGER REFERENCES teams(id),
    /// //   countryCode TEXT REFERENCES countries(code),
    /// // )
    /// try db.create(table: "players") { t in
    ///     t.belongsTo("team")
    ///     t.belongsTo("country")
    /// }
    /// ```
    ///
    /// When the added columns should have a custom prefix, specify an
    /// explicit table name:
    ///
    /// ```swift
    /// // CREATE TABLE player (
    /// //   id INTEGER PRIMARY KEY AUTOINCREMENT,
    /// //   captainId INTEGER REFERENCES player(id),
    /// // )
    /// try db.create(table: "player") { t in
    ///     t.autoIncrementedPrimaryKey("id")
    ///     t.belongsTo("captain", inTable: "player")
    /// }
    ///
    /// // CREATE TABLE book (
    /// //   id INTEGER PRIMARY KEY AUTOINCREMENT,
    /// //   authorId INTEGER REFERENCES person(id),
    /// //   translatorId INTEGER REFERENCES person(id),
    /// //   title TEXT
    /// // )
    /// try db.create(table: "book") { t in
    ///     t.autoIncrementedPrimaryKey("id")
    ///     t.belongsTo("author", inTable: "person")
    ///     t.belongsTo("translator", inTable: "person")
    ///     t.column("title", .text)
    /// }
    /// ```
    ///
    /// Specify foreign key actions:
    ///
    /// ```swift
    /// try db.create(table: "player") { t in
    ///     t.belongsTo("team", onDelete: .cascade)
    ///     t.belongsTo("captain", inTable: "player", onDelete: .setNull)
    /// }
    /// ```
    ///
    /// The added columns are indexed by default. You can disable this
    /// automatic index with the `indexed: false` option. You can also make
    /// this index unique with ``ForeignKeyDefinition/unique()``:
    ///
    /// ```swift
    /// try db.create(table: "player") { t in
    ///     // teamId is not indexed
    ///     t.belongsTo("team", indexed: false)
    ///
    ///     // One single player per country
    ///     t.belongsTo("country").unique()
    /// }
    /// ```
    ///
    /// For more precision in the definition of foreign keys, use instead
    /// ``ColumnDefinition/references(_:column:onDelete:onUpdate:deferred:)``
    /// or ``TableDefinition/foreignKey(_:references:columns:onDelete:onUpdate:deferred:)``.
    /// For example:
    ///
    /// ```swift
    /// try db.create(table: "player") { t in
    ///     // This convenience method...
    ///     t.belongsTo("team")
    ///
    ///     // ... is equivalent to:
    ///     t.column("teamId", .integer)
    ///         .references("team")
    ///         .indexed()
    ///
    ///     // ... and is equivalent to:
    ///     t.column("teamId", .integer).indexed()
    ///     t.foreignKey(["teamId"], references: "team")
    /// }
    /// ```
    ///
    /// See [Associations](https://github.com/groue/GRDB.swift/blob/master/Documentation/AssociationsBasics.md)
    /// for more information about foreign keys and associations.
    ///
    /// - parameters:
    ///     - name: The name of the foreign key, used as a prefix for the
    ///       added columns.
    ///     - table: The referenced table. If nil, the referenced table is
    ///       designated by the `name` parameter.
    ///     - deleteAction: Optional action when the referenced row
    ///       is deleted.
    ///     - updateAction: Optional action when the referenced row
    ///       is updated.
    ///     - isDeferred: A boolean value indicating whether the foreign key
    ///       constraint is deferred.
    ///       See <https://www.sqlite.org/foreignkeys.html#fk_deferred>.
    ///     - indexed: A boolean value indicating whether the foreign key is
    ///       indexed. It is true by default.
    /// - returns: A ``ForeignKeyDefinition`` that allows you to refine the
    ///   foreign key.
    @discardableResult
    public func belongsTo(
        _ name: String,
        inTable table: String? = nil,
        onDelete deleteAction: Database.ForeignKeyAction? = nil,
        onUpdate updateAction: Database.ForeignKeyAction? = nil,
        deferred isDeferred: Bool = false,
        indexed: Bool = true)
    -> ForeignKeyDefinition
    {
        let foreignKey = ForeignKeyDefinition(
            name: name,
            table: table,
            deleteAction: deleteAction,
            updateAction: updateAction,
            isIndexed: indexed && !inPrimaryKeyBody,
            isDeferred: isDeferred)
        columnComponents.append(.foreignKeyDefinition(foreignKey))
        
        if inPrimaryKeyBody {
            // Add a not null constraint in order to fix an SQLite bug:
            // <https://www.sqlite.org/quirks.html#primary_keys_can_sometimes_contain_nulls>
            foreignKey.notNull()
            primaryKeyConstraint!.components.append(.foreignKeyDefinition(foreignKey))
        }
        
        return foreignKey
    }
    
    /// Adds a check constraint.
    ///
    /// For example:
    ///
    /// ```swift
    /// // CREATE TABLE player (
    /// //   personalPhone TEXT,
    /// //   workPhone TEXT,
    /// //   CHECK personalPhone IS NOT NULL OR workPhone IS NOT NULL
    /// // )
    /// try db.create(table: "player") { t in
    ///     t.column("personalPhone", .text)
    ///     t.column("workPhone", .text)
    ///     let personalPhone = Column("personalPhone")
    ///     let workPhone = Column("workPhone")
    ///     t.check(personalPhone != nil || workPhone != nil)
    /// }
    /// ```
    ///
    /// When defining a check constraint on a single column, you can use the
    /// ``ColumnDefinition/check(_:)`` shortcut:
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
    /// - parameter condition: The checked condition.
    @available(*, deprecated)
    public func check(_ condition: some SQLExpressible) {
        checkConstraints.append(condition.sqlExpression)
    }
    
    /// Adds a check constraint.
    ///
    /// For example:
    ///
    /// ```swift
    /// // CREATE TABLE player (
    /// //   personalPhone TEXT,
    /// //   workPhone TEXT,
    /// //   CHECK personalPhone IS NOT NULL OR workPhone IS NOT NULL
    /// // )
    /// try db.create(table: "player") { t in
    ///     t.column("personalPhone", .text)
    ///     t.column("workPhone", .text)
    ///     let personalPhone = Column("personalPhone")
    ///     let workPhone = Column("workPhone")
    ///     t.check(personalPhone != nil || workPhone != nil)
    /// }
    /// ```
    ///
    /// When defining a check constraint on a single column, you can use the
    /// ``ColumnDefinition/check(_:)`` shortcut:
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
    /// - parameter condition: The checked condition.
    public func check(_ condition: some SQLSpecificExpressible) {
        checkConstraints.append(condition.sqlExpression)
    }
    
    /// Adds a check constraint.
    ///
    /// For example:
    ///
    /// ```swift
    /// // CREATE TABLE player (
    /// //   personalPhone TEXT,
    /// //   workPhone TEXT,
    /// //   CHECK personalPhone IS NOT NULL OR workPhone IS NOT NULL
    /// // )
    /// try db.create(table: "player") { t in
    ///     t.column("personalPhone", .text)
    ///     t.column("workPhone", .text)
    ///     t.check(sql: "personalPhone IS NOT NULL OR workPhone IS NOT NULL")
    /// }
    /// ```
    ///
    /// When defining a check constraint on a single column, you can use the
    /// ``ColumnDefinition/check(sql:)`` shortcut:
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
    /// - parameter sql: An SQL snippet
    public func check(sql: String) {
        checkConstraints.append(SQL(sql: sql).sqlExpression)
    }
    
    /// Appends a table constraint.
    ///
    /// For example:
    ///
    /// ```swift
    /// // CREATE TABLE player (
    /// //   score INTEGER,
    /// //   CHECK (score >= 0)
    /// // )
    /// try db.create(table: "player") { t in
    ///     t.column("score", .integer)
    ///     t.constraint(sql: "CHECK (score >= 0)")
    /// }
    /// ```
    public func constraint(sql: String) {
        literalConstraints.append(SQL(sql: sql))
    }
    
    /// Appends a table constraint.
    ///
    /// ``SQL`` literals allow you to safely embed raw values in your SQL,
    /// without any risk of syntax errors or SQL injection:
    ///
    /// ```swift
    /// // CREATE TABLE player (
    /// //   score INTEGER,
    /// //   CHECK (score >= 0)
    /// // )
    /// let minScore = 0
    /// try db.create(table: "player") { t in
    ///     t.column("score", .integer)
    ///     t.constraint(literal: "CHECK (score >= \(minScore))")
    /// }
    /// ```
    public func constraint(literal: SQL) {
        literalConstraints.append(literal)
    }
}

// Explicit non-conformance to Sendable: `TableDefinition` is a mutable
// class and there is no known reason for making it thread-safe.
@available(*, unavailable)
extension TableDefinition: Sendable { }

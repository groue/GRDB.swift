extension Database {
    
    // MARK: - Database Schema
    
    /// Creates a database table.
    ///
    /// For example:
    ///
    /// ```swift
    /// try db.create(table: "place") { t in
    ///     t.autoIncrementedPrimaryKey("id")
    ///     t.column("title", .text)
    ///     t.column("favorite", .boolean).notNull().default(false)
    ///     t.column("longitude", .double).notNull()
    ///     t.column("latitude", .double).notNull()
    /// }
    /// ```
    ///
    /// Related SQLite documentation:
    /// - <https://www.sqlite.org/lang_createtable.html>
    /// - <https://www.sqlite.org/withoutrowid.html>
    ///
    /// - warning: This is a legacy interface that is preserved for backwards
    ///   compatibility. Use of this interface is not recommended: prefer
    ///   ``create(table:options:body:)`` instead.
    ///
    /// - parameters:
    ///     - name: The table name.
    ///     - temporary: If true, creates a temporary table.
    ///     - ifNotExists: If false (the default), an error is thrown if the
    ///       table already exists. Otherwise, the table is created unless it
    ///       already exists.
    ///     - withoutRowID: If true, uses WITHOUT ROWID optimization.
    ///     - body: A closure that defines table columns and constraints.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    @_disfavoredOverload
    public func create(
        table name: String,
        temporary: Bool = false,
        ifNotExists: Bool = false,
        withoutRowID: Bool = false,
        body: (TableDefinition) throws -> Void)
    throws
    {
        var options: TableOptions = []
        if temporary { options.insert(.temporary) }
        if ifNotExists { options.insert(.ifNotExists) }
        if withoutRowID { options.insert(.withoutRowID) }
        try create(table: name, options: options, body: body)
    }
    
    /// Creates a database table.
    ///
    /// ### Reference documentation
    ///
    /// SQLite has many reference documents about table creation. They are a
    /// great learning material:
    ///
    /// - [CREATE TABLE](https://www.sqlite.org/lang_createtable.html)
    /// - [Datatypes In SQLite](https://www.sqlite.org/datatype3.html)
    /// - [SQLite Foreign Key Support](https://www.sqlite.org/foreignkeys.html)
    /// - [The ON CONFLICT Clause](https://www.sqlite.org/lang_conflict.html)
    /// - [Rowid Tables](https://www.sqlite.org/rowidtable.html)
    /// - [The WITHOUT ROWID Optimization](https://www.sqlite.org/withoutrowid.html)
    /// - [STRICT Tables](https://www.sqlite.org/stricttables.html)
    ///
    /// ### Usage
    ///
    /// ```swift
    /// // CREATE TABLE place (
    /// //   id INTEGER PRIMARY KEY AUTOINCREMENT,
    /// //   title TEXT,
    /// //   isFavorite BOOLEAN NOT NULL DEFAULT 0,
    /// //   latitude DOUBLE NOT NULL,
    /// //   longitude DOUBLE NOT NULL
    /// // )
    /// try db.create(table: "place") { t in
    ///     t.autoIncrementedPrimaryKey("id")
    ///     t.column("title", .text)
    ///     t.column("isFavorite", .boolean).notNull().default(false)
    ///     t.column("longitude", .double).notNull()
    ///     t.column("latitude", .double).notNull()
    /// }
    /// ```
    ///
    /// ### Configure table creation
    ///
    /// Use the `options` parameter to configure table creation
    /// (see ``TableOptions``):
    ///
    /// ```swift
    /// // CREATE TABLE player ( ... )
    /// try db.create(table: "player") { t in ... }
    ///
    /// // CREATE TEMPORARY TABLE player IF NOT EXISTS (
    /// try db.create(table: "player", options: [.temporary, .ifNotExists]) { t in ... }
    /// ```
    ///
    /// ### Add columns
    ///
    /// Add columns with their name and eventual type (`text`, `integer`,
    /// `double`, `real`, `numeric`, `boolean`, `blob`, `date`, `datetime`
    /// and `any`) - see ``Database/ColumnType``:
    ///
    /// ```swift
    /// // CREATE TABLE example (
    /// //   a,
    /// //   name TEXT,
    /// //   creationDate DATETIME,
    /// try db.create(table: "example") { t in
    ///     t.column("a")
    ///     t.column("name", .text)
    ///     t.column("creationDate", .datetime)
    /// ```
    ///
    /// The `column()` method returns a ``ColumnDefinition`` that you can
    /// further configure:
    ///
    /// ### Not null constraints, default values
    ///
    /// ```swift
    /// // email TEXT NOT NULL,
    /// t.column("email", .text).notNull()
    ///
    /// // name TEXT DEFAULT 'O''Reilly',
    /// t.column("name", .text).defaults(to: "O'Reilly")
    ///
    /// // flag BOOLEAN NOT NULL DEFAULT 0,
    /// t.column("flag", .boolean).notNull().defaults(to: false)
    ///
    /// // creationDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    /// t.column("creationDate", .datetime).defaults(sql: "CURRENT_TIMESTAMP")
    /// ```
    ///
    /// ### Primary, unique, and foreign keys
    ///
    /// Use an individual column as **primary**, **unique**, or **foreign key**.
    /// When defining a foreign key, the referenced column is the primary key of
    /// the referenced table (unless you specify otherwise):
    ///
    /// ```swift
    /// // id INTEGER PRIMARY KEY AUTOINCREMENT,
    /// t.autoIncrementedPrimaryKey("id")
    ///
    /// // uuid TEXT NOT NULL PRIMARY KEY,
    /// t.primaryKey("uuid", .text)
    ///
    /// // email TEXT UNIQUE,
    /// t.column("email", .text)
    ///     .unique()
    ///
    /// // countryCode TEXT REFERENCES country(code) ON DELETE CASCADE,
    /// t.column("countryCode", .text)
    ///     .references("country", onDelete: .cascade)
    /// ```
    ///
    /// Primary, unique and foreign keys can also be added on several columns:
    ///
    /// ```swift
    /// // a INTEGER NOT NULL,
    /// // b TEXT NOT NULL,
    /// // PRIMARY KEY (a, b)
    /// t.primaryKey {
    ///     t.column("a", .integer)
    ///     t.column("b", .text)
    /// }
    ///
    /// // a INTEGER NOT NULL,
    /// // b TEXT NOT NULL,
    /// // PRIMARY KEY (a, b)
    /// t.column("a", .integer).notNull()
    /// t.column("b", .text).notNull()
    /// t.primaryKey(["a", "b"])
    ///
    /// // a INTEGER,
    /// // b TEXT,
    /// // UNIQUE (a, b) ON CONFLICT REPLACE
    /// t.column("a", .integer)
    /// t.column("b", .text)
    /// t.uniqueKey(["a", "b"], onConflict: .replace)
    ///
    /// // a INTEGER,
    /// // b TEXT,
    /// // FOREIGN KEY (a, b) REFERENCES parents(c, d)
    /// t.column("a", .integer)
    /// t.column("b", .text)
    /// t.foreignKey(["a", "b"], references: "parents")
    /// ```
    ///
    /// > Tip: when you need an integer primary key that automatically generates
    /// unique values, it is recommended that you use the
    /// ``TableDefinition/autoIncrementedPrimaryKey(_:onConflict:)`` method:
    /// >
    /// > ```swift
    /// > try db.create(table: "example") { t in
    /// >     t.autoIncrementedPrimaryKey("id")
    /// >     ...
    /// > }
    /// > ```
    /// >
    /// > The reason for this recommendation is that auto-incremented primary
    /// > keys forbid the reuse of ids. This prevents your app or
    /// > <doc:DatabaseObservation> to think that a row was updated, when it was
    /// > actually deleted and replaced. Depending on your application needs,
    /// > this may be acceptable. But usually it is not.
    ///
    /// ### Indexed columns
    ///
    /// ```swift
    /// t.column("score", .integer).indexed()
    /// ```
    ///
    /// For extra index options, see ``create(indexOn:columns:options:condition:)``.
    ///
    /// ### Generated columns
    ///
    /// See [Generated columns](https://sqlite.org/gencol.html) for
    /// more information:
    ///
    /// ```swift
    /// t.column("totalScore", .integer).generatedAs(sql: "score + bonus")
    /// t.column("totalScore", .integer).generatedAs(Column("score") + Column("bonus"))
    /// ```
    ///
    /// ### Integrity checks
    ///
    /// SQLite will only let conforming rows in:
    ///
    /// ```swift
    /// // name TEXT CHECK (LENGTH(name) > 0)
    /// t.column("name", .text).check { length($0) > 0 }
    ///
    /// // score INTEGER CHECK (score > 0)
    /// t.column("score", .integer).check(sql: "score > 0")
    ///
    /// // CHECK (a + b < 10),
    /// t.check(Column("a") + Column("b") < 10)
    ///
    /// // CHECK (a + b < 10)
    /// t.check(sql: "a + b < 10")
    /// ```
    ///
    /// ### Raw SQL columns and constraints
    ///
    /// Columns and constraints can be defined with raw sql:
    ///
    /// ```swift
    /// t.column(sql: "name TEXT")
    /// t.constraint(sql: "CHECK (a + b < 10)")
    /// ```
    ///
    /// ``SQL`` literals allow you to safely embed raw values in your SQL,
    /// without any risk of syntax errors or SQL injection:
    ///
    /// ```swift
    /// let defaultName = "O'Reilly"
    /// t.column(literal: "name TEXT DEFAULT \(defaultName)")
    ///
    /// let forbiddenName = "admin"
    /// t.constraint(literal: "CHECK (name <> \(forbiddenName))")
    /// ```
    ///
    /// - parameters:
    ///     - name: The table name.
    ///     - options: Table creation options.
    ///     - body: A closure that defines table columns and constraints.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func create(
        table name: String,
        options: TableOptions = [],
        body: (TableDefinition) throws -> Void)
    throws
    {
        let table = TableDefinition(
            name: name,
            options: options)
        try body(table)
        let generator = try SQLTableGenerator(self, table: table)
        let sql = try generator.sql(self)
        try execute(sql: sql)
    }
    
    /// Renames a database table.
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/lang_altertable.html>
    ///
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func rename(table name: String, to newName: String) throws {
        try execute(sql: "ALTER TABLE \(name.quotedDatabaseIdentifier) RENAME TO \(newName.quotedDatabaseIdentifier)")
    }
    
    /// Modifies a database table.
    ///
    /// For example:
    ///
    /// ```swift
    /// try db.alter(table: "player") { t in
    ///     t.add(column: "url", .text)
    /// }
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/lang_altertable.html>
    ///
    /// - parameters:
    ///     - name: The table name.
    ///     - body: A closure that defines table alterations.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func alter(table name: String, body: (TableAlteration) -> Void) throws {
        let alteration = TableAlteration(name: name)
        body(alteration)
        let generator = SQLTableAlterationGenerator(alteration)
        let sql = try generator.sql(self)
        try execute(sql: sql)
    }
    
    /// Deletes a database table.
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/lang_droptable.html>
    ///
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func drop(table name: String) throws {
        try execute(sql: "DROP TABLE \(name.quotedDatabaseIdentifier)")
    }
    
    /// Creates a database view.
    ///
    /// You can create a view with an ``SQLRequest``:
    ///
    /// ```swift
    /// // CREATE VIEW hero AS SELECT * FROM player WHERE isHero == 1
    /// try db.create(view: "hero", as: SQLRequest(literal: """
    ///     SELECT * FROM player WHERE isHero == 1
    ///     """)
    /// ```
    ///
    /// You can also create a view with a ``QueryInterfaceRequest``:
    ///
    /// ```swift
    /// // CREATE VIEW hero AS SELECT * FROM player WHERE isHero == 1
    /// try db.create(
    ///     view: "hero",
    ///     as: Player.filter(Column("isHero") == true))
    /// ```
    ///
    /// When creating views in <doc:Migrations>, it is not recommended to
    /// use record types defined in the application. Instead of the `Player`
    /// record type, prefer `Table("player")`:
    ///
    /// ```swift
    /// // RECOMMENDED IN MIGRATIONS
    /// try db.create(
    ///     view: "hero",
    ///     as: Table("player").filter(Column("isHero") == true))
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/lang_createview.html>
    ///
    /// - parameters:
    ///     - view: The view name.
    ///     - options: View creation options.
    ///     - columns: The columns of the view. If nil, the columns are the
    ///       columns of the request.
    ///     - request: The request that feeds the view.
    public func create(
        view name: String,
        options: ViewOptions = [],
        columns: [String]? = nil,
        as request: SQLSubqueryable)
    throws {
        var literal: SQL = "CREATE "
        
        if options.contains(.temporary) {
            literal += "TEMPORARY "
        }
        
        literal += "VIEW "
        
        if options.contains(.ifNotExists) {
            literal += "IF NOT EXISTS "
        }
        
        literal += "\(identifier: name) "
        
        if let columns {
            literal += "("
            literal += columns.map { "\(identifier: $0)" }.joined(separator: ", ")
            literal += ") "
        }
        
        literal += "AS \(request)"
        
        // CREATE VIEW does not support arguments, so make sure we use
        // literal values.
        let context = SQLGenerationContext(self, argumentsSink: .literalValues)
        let sql = try literal.sql(context)
        try execute(sql: sql)
    }
    
    /// Creates a database view.
    ///
    /// For example:
    ///
    /// ```swift
    /// // CREATE VIEW hero AS SELECT * FROM player WHERE isHero == 1
    /// try db.create(view: "hero", asLiteral: """
    ///     SELECT * FROM player WHERE isHero == 1
    ///     """)
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/lang_createview.html>
    ///
    /// - parameters:
    ///     - view: The view name.
    ///     - options: View creation options.
    ///     - columns: The columns of the view. If nil, the columns are the
    ///       columns of the request.
    ///     - sqlLiteral: An `SQL` literal.
    public func create(
        view name: String,
        options: ViewOptions = [],
        columns: [String]? = nil,
        asLiteral sqlLiteral: SQL)
    throws {
        try create(view: name, options: options, columns: columns, as: SQLRequest(literal: sqlLiteral))
    }
    
    /// Deletes a database view.
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/lang_dropview.html>
    ///
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func drop(view name: String) throws {
        try execute(sql: "DROP VIEW \(name.quotedDatabaseIdentifier)")
    }
    
    /// Creates an index on the specified table and columns.
    ///
    /// For example:
    ///
    /// ```swift
    /// // CREATE INDEX index_player_on_email ON player(email)
    /// try db.create(index: "index_player_on_email", on: "player", columns: ["email"])
    /// ```
    ///
    /// SQLite can also index expressions (<https://www.sqlite.org/expridx.html>)
    /// and use specific collations. To create such an index, use
    /// ``create(index:on:expressions:options:condition:)``.
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/lang_createindex.html>
    ///
    /// - warning: This is a legacy interface that is preserved for backwards
    ///   compatibility. Use of this interface is not recommended: prefer
    ///   ``create(indexOn:columns:options:condition:)`` instead.
    ///
    /// - parameters:
    ///     - name: The index name.
    ///     - table: The name of the indexed table.
    ///     - columns: The indexed columns.
    ///     - unique: If true, creates a unique index.
    ///     - ifNotExists: If true, no error is thrown if index already exists.
    ///     - condition: If not nil, creates a partial index
    ///       (see <https://www.sqlite.org/partialindex.html>).
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    @_disfavoredOverload
    public func create(
        index name: String,
        on table: String,
        columns: [String],
        unique: Bool = false,
        ifNotExists: Bool = false,
        condition: (any SQLExpressible)? = nil)
    throws
    {
        var options: IndexOptions = []
        if ifNotExists { options.insert(.ifNotExists) }
        if unique { options.insert(.unique) }
        try create(index: name, on: table, columns: columns, options: options, condition: condition)
    }
    
    /// Creates an index on the specified table and columns.
    ///
    /// For example:
    ///
    /// ```swift
    /// // CREATE INDEX index_player_on_email ON player(email)
    /// try db.create(index: "index_player_on_email", on: "player", columns: ["email"])
    /// ```
    ///
    /// To create a unique index, specify the `.unique` option:
    ///
    /// ```swift
    /// // CREATE UNIQUE INDEX index_player_on_email ON player(email)
    /// try db.create(index: "index_player_on_email", on: "player", columns: ["email"], options: .unique)
    /// ```
    ///
    /// SQLite can also index expressions (<https://www.sqlite.org/expridx.html>)
    /// and use specific collations. To create such an index, use a raw SQL
    /// query:
    ///
    /// ```swift
    /// try db.execute(sql: "CREATE INDEX ...")
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/lang_createindex.html>
    ///
    /// - parameters:
    ///     - name: The index name.
    ///     - table: The name of the indexed table.
    ///     - columns: The indexed columns.
    ///     - options: Index creation options.
    ///     - condition: If not nil, creates a partial index
    ///       (see <https://www.sqlite.org/partialindex.html>).
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func create(
        index name: String,
        on table: String,
        columns: [String],
        options: IndexOptions = [],
        condition: (any SQLExpressible)? = nil)
    throws
    {
        let index = IndexDefinition(
            name: name,
            table: table,
            expressions: columns.map { .column($0) },
            options: options,
            condition: condition?.sqlExpression)
        let generator = SQLIndexGenerator(index: index)
        let sql = try generator.sql(self)
        try execute(sql: sql)
    }
    
    /// Creates an index on the specified table and expressions.
    ///
    /// This method can generally create indexes on expressions (see
    /// <https://www.sqlite.org/expridx.html>):
    ///
    /// ```swift
    /// // CREATE INDEX txy ON t(x+y)
    /// try db.create(
    ///     index: "txy",
    ///     on: "t",
    ///     expressions: [Column("x") + Column("y")])
    /// ```
    ///
    /// In particular, you can specify the collation on indexed
    /// columns (see <https://www.sqlite.org/lang_createindex.html#collations>):
    ///
    /// ```swift
    /// // CREATE INDEX index_player_name ON player(name COLLATE NOCASE)
    /// try db.create(
    ///     index: "index_player_name",
    ///     on: "player",
    ///     expressions: [Column("name").collating(.nocase)])
    /// ```
    ///
    /// - parameters:
    ///     - name: The index name.
    ///     - table: The name of the indexed table.
    ///     - expressions: The indexed expressions.
    ///     - options: Index creation options.
    ///     - condition: If not nil, creates a partial index
    ///       (see <https://www.sqlite.org/partialindex.html>).
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func create(
        index name: String,
        on table: String,
        expressions: [any SQLExpressible],
        options: IndexOptions = [],
        condition: (any SQLExpressible)? = nil)
    throws
    {
        let index = IndexDefinition(
            name: name,
            table: table,
            expressions: expressions.map { $0.sqlExpression },
            options: options,
            condition: condition?.sqlExpression)
        let generator = SQLIndexGenerator(index: index)
        let sql = try generator.sql(self)
        try execute(sql: sql)
    }
    
    /// Creates an index with a default name on the specified table and columns.
    ///
    /// The created index is named after the table and the column name(s):
    ///
    /// ```swift
    /// // CREATE INDEX index_player_on_email ON player(email)
    /// try db.create(indexOn: "player", columns: ["email"])
    /// ```
    ///
    /// To create a unique index, specify the `.unique` option:
    ///
    /// ```swift
    /// // CREATE UNIQUE INDEX index_player_on_email ON player(email)
    /// try db.create(indexOn: "player", columns: ["email"], options: .unique)
    /// ```
    ///
    /// In order to specify the index name, use
    /// ``create(index:on:columns:options:condition:)`` instead.
    ///
    /// SQLite can also index expressions (<https://www.sqlite.org/expridx.html>)
    /// and use specific collations. To create such an index, use
    /// ``create(index:on:expressions:options:condition:)``.
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/lang_createindex.html>
    ///
    /// - parameters:
    ///     - table: The name of the indexed table.
    ///     - columns: The indexed columns.
    ///     - options: Index creation options.
    ///     - condition: If not nil, creates a partial index
    ///       (see <https://www.sqlite.org/partialindex.html>).
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func create(
        indexOn table: String,
        columns: [String],
        options: IndexOptions = [],
        condition: (any SQLExpressible)? = nil)
    throws
    {
        try create(
            index: Database.defaultIndexName(on: table, columns: columns),
            on: table,
            columns: columns,
            options: options,
            condition: condition)
    }
    
    /// Deletes a database index.
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/lang_dropindex.html>
    ///
    /// - parameter name: The index name.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func drop(index name: String) throws {
        try execute(sql: "DROP INDEX \(name.quotedDatabaseIdentifier)")
    }
    
    /// Deletes the database index on the specified table and columns
    /// if exactly one such index exists.
    ///
    /// - parameters:
    ///     - table: The name of the indexed table.
    ///     - columns: The indexed columns.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func drop(indexOn table: String, columns: [String]) throws {
        let lowercasedColumns = columns.map { $0.lowercased() }
        let indexes = try indexes(on: table).filter { index in
            index.columns.map({ $0.lowercased() }) == lowercasedColumns
        }
        if let index = indexes.first, indexes.count == 1 {
            try drop(index: index.name)
        }
    }
    
    /// Deletes and recreates from scratch all indices that use this collation.
    ///
    /// This method is useful when the definition of a collation sequence
    /// has changed.
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/lang_reindex.html>
    ///
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func reindex(collation: Database.CollationName) throws {
        try execute(sql: "REINDEX \(collation.rawValue)")
    }
    
    /// Deletes and recreates from scratch all indices that use this collation.
    ///
    /// This method is useful when the definition of a collation sequence
    /// has changed.
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/lang_reindex.html>
    ///
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func reindex(collation: DatabaseCollation) throws {
        try reindex(collation: Database.CollationName(rawValue: collation.name))
    }
}

/// View creation options
public struct ViewOptions: OptionSet {
    public let rawValue: Int
    
    public init(rawValue: Int) { self.rawValue = rawValue }
    
    /// Only creates the view if it does not already exist.
    public static let ifNotExists = ViewOptions(rawValue: 1 << 0)
    
    /// Creates a temporary view.
    public static let temporary = ViewOptions(rawValue: 1 << 1)
}

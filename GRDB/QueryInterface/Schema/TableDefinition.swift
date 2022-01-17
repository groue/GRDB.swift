extension Database {
    
    // MARK: - Database Schema
    
    // TODO: deprecate just before GRDB 6
    /// Creates a database table.
    ///
    ///     try db.create(table: "place") { t in
    ///         t.autoIncrementedPrimaryKey("id")
    ///         t.column("title", .text)
    ///         t.column("favorite", .boolean).notNull().default(false)
    ///         t.column("longitude", .double).notNull()
    ///         t.column("latitude", .double).notNull()
    ///     }
    ///
    /// See <https://www.sqlite.org/lang_createtable.html> and
    /// <https://www.sqlite.org/withoutrowid.html>
    ///
    /// - warning: This method is sunsetted. You should prefer
    ///   `create(table:options:body:)` instead.
    ///
    /// - parameters:
    ///     - name: The table name.
    ///     - temporary: If true, creates a temporary table.
    ///     - ifNotExists: If false (the default), an error is thrown if the
    ///       table already exists. Otherwise, the table is created unless it
    ///       already exists.
    ///     - withoutRowID: If true, uses WITHOUT ROWID optimization.
    ///     - body: A closure that defines table columns and constraints.
    /// - throws: A DatabaseError whenever an SQLite error occurs.
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
    ///     try db.create(table: "place") { t in
    ///         t.autoIncrementedPrimaryKey("id")
    ///         t.column("title", .text)
    ///         t.column("favorite", .boolean).notNull().default(false)
    ///         t.column("longitude", .double).notNull()
    ///         t.column("latitude", .double).notNull()
    ///     }
    ///
    /// See <https://www.sqlite.org/lang_createtable.html> and
    /// <https://www.sqlite.org/withoutrowid.html>
    ///
    /// - parameters:
    ///     - name: The table name.
    ///     - options: Table creation options.
    ///     - body: A closure that defines table columns and constraints.
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    public func create(
        table name: String,
        options: TableOptions = [],
        body: (TableDefinition) throws -> Void)
    throws
    {
        let definition = TableDefinition(
            name: name,
            options: options)
        try body(definition)
        let sql = try definition.sql(self)
        try execute(sql: sql)
    }
    
    /// Renames a database table.
    ///
    /// See <https://www.sqlite.org/lang_altertable.html>
    ///
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    public func rename(table name: String, to newName: String) throws {
        try execute(sql: "ALTER TABLE \(name.quotedDatabaseIdentifier) RENAME TO \(newName.quotedDatabaseIdentifier)")
    }
    
    /// Modifies a database table.
    ///
    ///     try db.alter(table: "player") { t in
    ///         t.add(column: "url", .text)
    ///     }
    ///
    /// See <https://www.sqlite.org/lang_altertable.html>
    ///
    /// - parameters:
    ///     - name: The table name.
    ///     - body: A closure that defines table alterations.
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    public func alter(table name: String, body: (TableAlteration) -> Void) throws {
        let alteration = TableAlteration(name: name)
        body(alteration)
        let sql = try alteration.sql(self)
        try execute(sql: sql)
    }
    
    /// Deletes a database table.
    ///
    /// See <https://www.sqlite.org/lang_droptable.html>
    ///
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    public func drop(table name: String) throws {
        try execute(sql: "DROP TABLE \(name.quotedDatabaseIdentifier)")
    }
    
    // TODO: deprecate just before GRDB 6
    /// Creates an index.
    ///
    ///     try db.create(index: "playerByEmail", on: "player", columns: ["email"])
    ///
    /// SQLite can also index expressions (https://www.sqlite.org/expridx.html)
    /// and use specific collations. To create such an index, use a raw SQL
    /// query.
    ///
    ///     try db.execute(sql: "CREATE INDEX ...")
    ///
    /// See <https://www.sqlite.org/lang_createindex.html>
    ///
    /// - warning: This method is sunsetted. You should prefer
    ///   `create(index:on:columns:options:condition:)` instead.
    ///
    /// - parameters:
    ///     - name: The index name.
    ///     - table: The name of the indexed table.
    ///     - columns: The indexed columns.
    ///     - unique: If true, creates a unique index.
    ///     - ifNotExists: If true, no error is thrown if index already exists.
    ///     - condition: If not nil, creates a partial index
    ///       (see <https://www.sqlite.org/partialindex.html>).
    @_disfavoredOverload
    public func create(
        index name: String,
        on table: String,
        columns: [String],
        unique: Bool = false,
        ifNotExists: Bool = false,
        condition: SQLExpressible? = nil)
    throws
    {
        var options: IndexOptions = []
        if ifNotExists { options.insert(.ifNotExists) }
        if unique { options.insert(.unique) }
        try create(index: name, on: table, columns: columns, options: options, condition: condition)
    }
    
    /// Creates an index.
    ///
    ///     try db.create(index: "playerByEmail", on: "player", columns: ["email"])
    ///
    /// SQLite can also index expressions (https://www.sqlite.org/expridx.html)
    /// and use specific collations. To create such an index, use a raw SQL
    /// query.
    ///
    ///     try db.execute(sql: "CREATE INDEX ...")
    ///
    /// See <https://www.sqlite.org/lang_createindex.html>
    ///
    /// - parameters:
    ///     - name: The index name.
    ///     - table: The name of the indexed table.
    ///     - columns: The indexed columns.
    ///     - options: Index creation options.
    ///     - condition: If not nil, creates a partial index
    ///       (see <https://www.sqlite.org/partialindex.html>).
    public func create(
        index name: String,
        on table: String,
        columns: [String],
        options: IndexOptions = [],
        condition: SQLExpressible? = nil)
    throws
    {
        let definition = IndexDefinition(
            name: name,
            table: table,
            columns: columns,
            options: options,
            condition: condition?.sqlExpression)
        let sql = try definition.sql(self)
        try execute(sql: sql)
    }
    
    /// Deletes a database index.
    ///
    /// See <https://www.sqlite.org/lang_dropindex.html>
    ///
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    public func drop(index name: String) throws {
        try execute(sql: "DROP INDEX \(name.quotedDatabaseIdentifier)")
    }
    
    /// Delete and recreate from scratch all indices that use this collation.
    ///
    /// This method is useful when the definition of a collation sequence
    /// has changed.
    ///
    /// See <https://www.sqlite.org/lang_reindex.html>
    ///
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    public func reindex(collation: Database.CollationName) throws {
        try execute(sql: "REINDEX \(collation.rawValue)")
    }
    
    /// Delete and recreate from scratch all indices that use this collation.
    ///
    /// This method is useful when the definition of a collation sequence
    /// has changed.
    ///
    /// See <https://www.sqlite.org/lang_reindex.html>
    ///
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    public func reindex(collation: DatabaseCollation) throws {
        try reindex(collation: Database.CollationName(rawValue: collation.name))
    }
}

/// Table creation options
public struct TableOptions: OptionSet {
    /// :nodoc:
    public let rawValue: Int
    
    /// :nodoc:
    public init(rawValue: Int) { self.rawValue = rawValue }
    
    /// Only creates the table if it does not already exist.
    public static let ifNotExists = TableOptions(rawValue: 1 << 0)
    
    /// Creates a temporary table.
    public static let temporary = TableOptions(rawValue: 1 << 1)
    
    /// Creates a without rowid table. See <https://www.sqlite.org/withoutrowid.html>
    public static let withoutRowID = TableOptions(rawValue: 1 << 2)
    
#if GRDBCUSTOMSQLITE
    /// Creates a strict table. See <https://www.sqlite.org/stricttables.html>
    public static let strict = TableOptions(rawValue: 1 << 3)
#endif
}

/// The TableDefinition class lets you define table columns and constraints.
///
/// You don't create instances of this class. Instead, you use the Database
/// `create(table:)` method:
///
///     try db.create(table: "player") { t in // t is TableDefinition
///         t.column(...)
///     }
///
/// See <https://www.sqlite.org/lang_createtable.html>
public final class TableDefinition {
    private typealias KeyConstraint = (
        columns: [String],
        conflictResolution: Database.ConflictResolution?)
    
    private struct ForeignKeyConstraint {
        var columns: [String]
        var table: String
        var destinationColumns: [String]?
        var deleteAction: Database.ForeignKeyAction?
        var updateAction: Database.ForeignKeyAction?
        var deferred: Bool
    }
    
    private enum ColumnItem {
        case definition(ColumnDefinition)
        case literal(SQL)
        
        var columnDefinition: ColumnDefinition? {
            switch self {
            case let .definition(def): return def
            case .literal: return nil
            }
        }
        
        func sql(_ db: Database, tableName: String, primaryKeyColumns: [String]?) throws -> String {
            switch self {
            case let .definition(def):
                return try def.sql(db, tableName: tableName, primaryKeyColumns: primaryKeyColumns)
            case let .literal(sqlLiteral):
                let context = SQLGenerationContext(db, argumentsSink: .forRawSQL)
                return try sqlLiteral.sql(context)
            }
        }
    }
    
    private let name: String
    private let options: TableOptions
    private var columns: [ColumnItem] = []
    private var primaryKeyConstraint: KeyConstraint?
    private var uniqueKeyConstraints: [KeyConstraint] = []
    private var foreignKeyConstraints: [ForeignKeyConstraint] = []
    private var checkConstraints: [SQLExpression] = []
    private var literalConstraints: [SQL] = []
    
    init(name: String, options: TableOptions) {
        self.name = name
        self.options = options
    }
    
    /// Defines the auto-incremented primary key.
    ///
    ///     try db.create(table: "player") { t in
    ///         t.autoIncrementedPrimaryKey("id")
    ///     }
    ///
    /// The auto-incremented primary key is an integer primary key that
    /// automatically generates unused values when you do not explicitly
    /// provide one, and prevents the reuse of ids over the lifetime of
    /// the database.
    ///
    /// **It is the preferred way to define a numeric primary key**.
    ///
    /// The fact that an auto-incremented primary key prevents the reuse of
    /// ids is an excellent guard against data races that could happen when your
    /// application processes ids in an asynchronous way. The auto-incremented
    /// primary key provides the guarantee that a given id can't reference a row
    /// that is different from the one it used to be at the beginning of the
    /// asynchronous process, even if this row gets deleted and a new one is
    /// inserted in between.
    ///
    /// See <https://www.sqlite.org/lang_createtable.html#primkeyconst> and
    /// <https://www.sqlite.org/lang_createtable.html#rowid>
    ///
    /// - parameter conflictResolution: An optional conflict resolution
    ///   (see <https://www.sqlite.org/lang_conflict.html>).
    /// - returns: Self so that you can further refine the column definition.
    @discardableResult
    public func autoIncrementedPrimaryKey(
        _ name: String,
        onConflict conflictResolution: Database.ConflictResolution? = nil)
    -> ColumnDefinition
    {
        column(name, .integer).primaryKey(onConflict: conflictResolution, autoincrement: true)
    }
    
    /// Appends a table column.
    ///
    ///     try db.create(table: "player") { t in
    ///         t.column("name", .text)
    ///     }
    ///
    /// See <https://www.sqlite.org/lang_createtable.html#tablecoldef>
    ///
    /// - parameter name: the column name.
    /// - parameter type: the eventual column type.
    /// - returns: An ColumnDefinition that allows you to refine the
    ///   column definition.
    @discardableResult
    public func column(_ name: String, _ type: Database.ColumnType? = nil) -> ColumnDefinition {
        let column = ColumnDefinition(name: name, type: type)
        columns.append(.definition(column))
        return column
    }
    
    /// Appends a table column defined with raw SQL.
    ///
    ///     try db.create(table: "player") { t in
    ///         t.column(sql: "name TEXT")
    ///     }
    public func column(sql: String) {
        columns.append(.literal(SQL(sql: sql)))
    }
    
    /// Appends a table column defined with an SQL *literal*.
    ///
    /// Literals allow you to safely embed raw values in your SQL, without any
    /// risk of syntax errors or SQL injection:
    ///
    ///     // CREATE TABLE player (
    ///     //   name TEXT DEFAULT 'Anonymous'
    ///     // )
    ///     let defaultName = "Anonymous"
    ///     try db.create(table: "player") { t in
    ///         t.column(literal: "name TEXT DEFAULT \(defaultName)")
    ///     }
    public func column(literal: SQL) {
        columns.append(.literal(literal))
    }
    
    /// Defines the table primary key.
    ///
    ///     try db.create(table: "citizenship") { t in
    ///         t.column("citizenID", .integer)
    ///         t.column("countryCode", .text)
    ///         t.primaryKey(["citizenID", "countryCode"])
    ///     }
    ///
    /// See <https://www.sqlite.org/lang_createtable.html#primkeyconst> and
    /// <https://www.sqlite.org/lang_createtable.html#rowid>
    ///
    /// - parameter columns: The primary key columns.
    /// - parameter conflictResolution: An optional conflict resolution
    ///   (see <https://www.sqlite.org/lang_conflict.html>).
    public func primaryKey(_ columns: [String], onConflict conflictResolution: Database.ConflictResolution? = nil) {
        guard primaryKeyConstraint == nil else {
            // Programmer error
            fatalError("can't define several primary keys")
        }
        primaryKeyConstraint = (columns: columns, conflictResolution: conflictResolution)
    }
    
    /// Adds a unique key.
    ///
    ///     try db.create(table: "place") { t in
    ///         t.column("latitude", .double)
    ///         t.column("longitude", .double)
    ///         t.uniqueKey(["latitude", "longitude"])
    ///     }
    ///
    /// See <https://www.sqlite.org/lang_createtable.html#uniqueconst>
    ///
    /// - parameter columns: The unique key columns.
    /// - parameter conflictResolution: An optional conflict resolution
    ///   (see <https://www.sqlite.org/lang_conflict.html>).
    public func uniqueKey(_ columns: [String], onConflict conflictResolution: Database.ConflictResolution? = nil) {
        uniqueKeyConstraints.append((columns: columns, conflictResolution: conflictResolution))
    }
    
    /// Adds a foreign key.
    ///
    ///     try db.create(table: "passport") { t in
    ///         t.column("issueDate", .date)
    ///         t.column("citizenID", .integer)
    ///         t.column("countryCode", .text)
    ///         t.foreignKey(["citizenID", "countryCode"], references: "citizenship", onDelete: .cascade)
    ///     }
    ///
    /// See <https://www.sqlite.org/foreignkeys.html>
    ///
    /// - parameters:
    ///     - columns: The foreign key columns.
    ///     - table: The referenced table.
    ///     - destinationColumns: The columns in the referenced table. If not
    ///       specified, the columns of the primary key of the referenced table
    ///       are used.
    ///     - deleteAction: Optional action when the referenced row is deleted.
    ///     - updateAction: Optional action when the referenced row is updated.
    ///     - deferred: If true, defines a deferred foreign key constraint.
    ///       See <https://www.sqlite.org/foreignkeys.html#fk_deferred>.
    public func foreignKey(
        _ columns: [String],
        references table: String,
        columns destinationColumns: [String]? = nil,
        onDelete deleteAction: Database.ForeignKeyAction? = nil,
        onUpdate updateAction: Database.ForeignKeyAction? = nil,
        deferred: Bool = false)
    {
        foreignKeyConstraints.append(ForeignKeyConstraint(
                                        columns: columns,
                                        table: table,
                                        destinationColumns: destinationColumns,
                                        deleteAction: deleteAction,
                                        updateAction: updateAction,
                                        deferred: deferred))
    }
    
    /// Adds a CHECK constraint.
    ///
    ///     try db.create(table: "player") { t in
    ///         t.column("personalPhone", .text)
    ///         t.column("workPhone", .text)
    ///         let personalPhone = Column("personalPhone")
    ///         let workPhone = Column("workPhone")
    ///         t.check(personalPhone != nil || workPhone != nil)
    ///     }
    ///
    /// See <https://www.sqlite.org/lang_createtable.html#ckconst>
    ///
    /// - parameter condition: The checked condition
    public func check(_ condition: SQLExpressible) {
        checkConstraints.append(condition.sqlExpression)
    }
    
    /// Adds a CHECK constraint.
    ///
    ///     try db.create(table: "player") { t in
    ///         t.column("personalPhone", .text)
    ///         t.column("workPhone", .text)
    ///         t.check(sql: "personalPhone IS NOT NULL OR workPhone IS NOT NULL")
    ///     }
    ///
    /// See <https://www.sqlite.org/lang_createtable.html#ckconst>
    ///
    /// - parameter sql: An SQL snippet
    public func check(sql: String) {
        checkConstraints.append(SQL(sql: sql).sqlExpression)
    }
    
    /// Appends a table constraint defined with raw SQL.
    ///
    ///     // CREATE TABLE player (
    ///     //   ...
    ///     //   CHECK (score >= 0)
    ///     // )
    ///     try db.create(table: "player") { t in
    ///         ...
    ///         t.constraint(sql: "CHECK (score >= 0)")
    ///     }
    public func constraint(sql: String) {
        literalConstraints.append(SQL(sql: sql))
    }
    
    /// Appends a table constraint defined with an SQL *literal*.
    ///
    /// Literals allow you to safely embed raw values in your SQL, without any
    /// risk of syntax errors or SQL injection:
    ///
    ///     // CREATE TABLE player (
    ///     //   ...
    ///     //   CHECK (score >= 0)
    ///     // )
    ///     let minScore = 0
    ///     try db.create(table: "player") { t in
    ///         ...
    ///         t.constraint(literal: "CHECK (score >= \(minScore))")
    ///     }
    public func constraint(literal: SQL) {
        literalConstraints.append(literal)
    }
    
    fileprivate func sql(_ db: Database) throws -> String {
        var statements: [String] = []
        
        do {
            var chunks: [String] = []
            chunks.append("CREATE")
            if options.contains(.temporary) {
                chunks.append("TEMPORARY")
            }
            chunks.append("TABLE")
            if options.contains(.ifNotExists) {
                chunks.append("IF NOT EXISTS")
            }
            chunks.append(name.quotedDatabaseIdentifier)
            
            let primaryKeyColumns: [String]
            if let (columns, _) = primaryKeyConstraint {
                primaryKeyColumns = columns
            } else if let column = columns.lazy.compactMap(\.columnDefinition).first(where: { $0.primaryKey != nil }) {
                primaryKeyColumns = [column.name]
            } else {
                // WITHOUT ROWID optimization requires a primary key. If the
                // user sets withoutRowID, but does not define a primary key,
                // this is undefined behavior.
                //
                // We thus can use the rowId column even when the withoutRowID
                // flag is set ;-)
                primaryKeyColumns = [Column.rowID.name]
            }
            
            do {
                var items: [String] = []
                try items.append(contentsOf: columns.map {
                    try $0.sql(db, tableName: name, primaryKeyColumns: primaryKeyColumns)
                })
                
                if let (columns, conflictResolution) = primaryKeyConstraint {
                    var chunks: [String] = []
                    chunks.append("PRIMARY KEY")
                    chunks.append("(\(columns.map(\.quotedDatabaseIdentifier).joined(separator: ", ")))")
                    if let conflictResolution = conflictResolution {
                        chunks.append("ON CONFLICT")
                        chunks.append(conflictResolution.rawValue)
                    }
                    items.append(chunks.joined(separator: " "))
                }
                
                for (columns, conflictResolution) in uniqueKeyConstraints {
                    var chunks: [String] = []
                    chunks.append("UNIQUE")
                    chunks.append("(\(columns.map(\.quotedDatabaseIdentifier).joined(separator: ", ")))")
                    if let conflictResolution = conflictResolution {
                        chunks.append("ON CONFLICT")
                        chunks.append(conflictResolution.rawValue)
                    }
                    items.append(chunks.joined(separator: " "))
                }
                
                for constraint in foreignKeyConstraints {
                    var chunks: [String] = []
                    chunks.append("FOREIGN KEY")
                    chunks.append("(\(constraint.columns.map(\.quotedDatabaseIdentifier).joined(separator: ", ")))")
                    chunks.append("REFERENCES")
                    if let destinationColumns = constraint.destinationColumns {
                        chunks.append("""
                            \(constraint.table.quotedDatabaseIdentifier)(\
                            \(destinationColumns.map(\.quotedDatabaseIdentifier).joined(separator: ", "))\
                            )
                            """)
                    } else if constraint.table == name {
                        chunks.append("""
                            \(constraint.table.quotedDatabaseIdentifier)(\
                            \(primaryKeyColumns.map(\.quotedDatabaseIdentifier).joined(separator: ", "))\
                            )
                            """)
                    } else {
                        let primaryKey = try db.primaryKey(constraint.table)
                        chunks.append("""
                            \(constraint.table.quotedDatabaseIdentifier)(\
                            \(primaryKey.columns.map(\.quotedDatabaseIdentifier).joined(separator: ", "))\
                            )
                            """)
                    }
                    if let deleteAction = constraint.deleteAction {
                        chunks.append("ON DELETE")
                        chunks.append(deleteAction.rawValue)
                    }
                    if let updateAction = constraint.updateAction {
                        chunks.append("ON UPDATE")
                        chunks.append(updateAction.rawValue)
                    }
                    if constraint.deferred {
                        chunks.append("DEFERRABLE INITIALLY DEFERRED")
                    }
                    items.append(chunks.joined(separator: " "))
                }
                
                for checkExpression in checkConstraints {
                    var chunks: [String] = []
                    try chunks.append("CHECK (\(checkExpression.quotedSQL(db)))")
                    items.append(chunks.joined(separator: " "))
                }
                
                for literal in literalConstraints {
                    let context = SQLGenerationContext(db, argumentsSink: .forRawSQL)
                    try items.append(literal.sql(context))
                }
                
                chunks.append("(\(items.joined(separator: ", ")))")
            }
            
            var tableOptions: [String] = []
            
#if GRDBCUSTOMSQLITE
            if options.contains(.strict) {
                tableOptions.append("STRICT")
            }
#endif
            
            if options.contains(.withoutRowID) {
                tableOptions.append("WITHOUT ROWID")
            }
            
            if !tableOptions.isEmpty {
                chunks.append(tableOptions.joined(separator: ", "))
            }
            
            statements.append(chunks.joined(separator: " "))
        }
        
        var indexOptions: IndexOptions = []
        if options.contains(.ifNotExists) { indexOptions.insert(.ifNotExists) }
        let indexStatements = try columns
            .compactMap { $0.columnDefinition?.indexDefinition(in: name, options: indexOptions) }
            .map { try $0.sql(db) }
        statements.append(contentsOf: indexStatements)
        return statements.joined(separator: "; ")
    }
}

/// The TableAlteration class lets you alter database tables.
///
/// You don't create instances of this class. Instead, you use the Database
/// `alter(table:)` method:
///
///     try db.alter(table: "player") { t in // t is TableAlteration
///         t.add(column: ...)
///     }
///
/// See <https://www.sqlite.org/lang_altertable.html>
public final class TableAlteration {
    private let name: String
    
    private enum TableAlterationKind {
        case add(ColumnDefinition)
        case addColumnLiteral(SQL)
        case rename(old: String, new: String)
        case drop(String)
    }
    
    private var alterations: [TableAlterationKind] = []
    
    init(name: String) {
        self.name = name
    }
    
    /// Appends a column to the table.
    ///
    ///     try db.alter(table: "player") { t in
    ///         t.add(column: "url", .text)
    ///     }
    ///
    /// See <https://www.sqlite.org/lang_altertable.html>
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
    
    /// Appends a table column defined with raw SQL.
    ///
    ///     // ALTER TABLE player ADD COLUMN name TEXT
    ///     try db.alter(table: "player") { t in
    ///         t.addColumn(sql: "name TEXT")
    ///     }
    public func addColumn(sql: String) {
        alterations.append(.addColumnLiteral(SQL(sql: sql)))
    }
    
    /// Appends a table column defined with an SQL *literal*.
    ///
    /// Literals allow you to safely embed raw values in your SQL, without any
    /// risk of syntax errors or SQL injection:
    ///
    ///     // ALTER TABLE player ADD COLUMN name TEXT DEFAULT 'Anonymous'
    ///     let defaultName = "Anonymous"
    ///     try db.alter(table: "player") { t in
    ///         t.addColumn(literal: "name TEXT DEFAULT \(defaultName)")
    ///     }
    public func addColumn(literal: SQL) {
        alterations.append(.addColumnLiteral(literal))
    }
    
    #if GRDBCUSTOMSQLITE || GRDBCIPHER
    /// Renames a column in a table.
    ///
    ///     try db.alter(table: "player") { t in
    ///         t.rename(column: "url", to: "homeURL")
    ///     }
    ///
    /// See <https://www.sqlite.org/lang_altertable.html>
    ///
    /// - parameter name: the column name to rename.
    /// - parameter newName: the new name of the column.
    public func rename(column name: String, to newName: String) {
        _rename(column: name, to: newName)
    }
    
    /// Drops a column from the table.
    ///
    ///     try db.alter(table: "player") { t in
    ///         t.drop(column: "age")
    ///     }
    ///
    /// See <https://www.sqlite.org/lang_altertable.html>
    ///
    /// - Parameter name: the column name to drop.
    public func drop(column name: String) {
        _drop(column: name)
    }
    #else
    /// Renames a column in a table.
    ///
    ///     try db.alter(table: "player") { t in
    ///         t.rename(column: "url", to: "homeURL")
    ///     }
    ///
    /// See <https://www.sqlite.org/lang_altertable.html>
    ///
    /// - parameter name: the column name to rename.
    /// - parameter newName: the new name of the column.
    @available(iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public func rename(column name: String, to newName: String) {
        _rename(column: name, to: newName)
    }
    
    /// Drops a column from the table.
    ///
    ///     try db.alter(table: "player") { t in
    ///         t.drop(column: "age")
    ///     }
    ///
    /// See <https://www.sqlite.org/lang_altertable.html>
    ///
    /// - Parameter name: the column name to drop.
    @available(iOS 15.0, tvOS 15.0, watchOS 8.0, macOS 12.0, *)
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
    
    fileprivate func sql(_ db: Database) throws -> String {
        var statements: [String] = []
        
        for alteration in alterations {
            switch alteration {
            case let .add(column):
                var chunks: [String] = []
                chunks.append("ALTER TABLE")
                chunks.append(name.quotedDatabaseIdentifier)
                chunks.append("ADD COLUMN")
                try chunks.append(column.sql(db, tableName: name, primaryKeyColumns: nil))
                let statement = chunks.joined(separator: " ")
                statements.append(statement)
                
                if let indexDefinition = column.indexDefinition(in: name) {
                    try statements.append(indexDefinition.sql(db))
                }
                
            case let .addColumnLiteral(sqlLiteral):
                var chunks: [String] = []
                chunks.append("ALTER TABLE")
                chunks.append(name.quotedDatabaseIdentifier)
                chunks.append("ADD COLUMN")
                let context = SQLGenerationContext(db, argumentsSink: .forRawSQL)
                try chunks.append(sqlLiteral.sql(context))
                let statement = chunks.joined(separator: " ")
                statements.append(statement)
                
            case let .rename(oldName, newName):
                var chunks: [String] = []
                chunks.append("ALTER TABLE")
                chunks.append(name.quotedDatabaseIdentifier)
                chunks.append("RENAME COLUMN")
                chunks.append(oldName.quotedDatabaseIdentifier)
                chunks.append("TO")
                chunks.append(newName.quotedDatabaseIdentifier)
                let statement = chunks.joined(separator: " ")
                statements.append(statement)
                
            case let .drop(column):
                var chunks: [String] = []
                chunks.append("ALTER TABLE")
                chunks.append(name.quotedDatabaseIdentifier)
                chunks.append("DROP COLUMN")
                chunks.append(column.quotedDatabaseIdentifier)
                let statement = chunks.joined(separator: " ")
                statements.append(statement)
            }
        }
        
        return statements.joined(separator: "; ")
    }
}

/// The ColumnDefinition class lets you refine a table column.
///
/// You get instances of this class when you create or alter a database table:
///
///     try db.create(table: "player") { t in
///         t.column(...)      // ColumnDefinition
///     }
///
///     try db.alter(table: "player") { t in
///         t.add(column: ...) // ColumnDefinition
///     }
///
/// See <https://www.sqlite.org/lang_createtable.html> and
/// <https://www.sqlite.org/lang_altertable.html>
public final class ColumnDefinition {
    enum Index {
        case none
        case index
        case unique(Database.ConflictResolution)
    }
    
    private struct ForeignKeyConstraint {
        var table: String
        var column: String?
        var deleteAction: Database.ForeignKeyAction?
        var updateAction: Database.ForeignKeyAction?
        var deferred: Bool
    }
    
    /// The `GeneratedColumnQualification` enum defines whether a generated
    /// column sis virtual or stored.
    ///
    /// See <https://sqlite.org/gencol.html#virtual_versus_stored_columns>
    public enum GeneratedColumnQualification {
        case virtual
        case stored
    }
    
    private struct GeneratedColumnConstraint {
        var expression: SQLExpression
        var qualification: GeneratedColumnQualification
    }
    
    fileprivate let name: String
    private let type: Database.ColumnType?
    fileprivate var primaryKey: (conflictResolution: Database.ConflictResolution?, autoincrement: Bool)?
    private var index: Index = .none
    private var notNullConflictResolution: Database.ConflictResolution?
    private var checkConstraints: [SQLExpression] = []
    private var foreignKeyConstraints: [ForeignKeyConstraint] = []
    private var defaultExpression: SQLExpression?
    private var collationName: String?
    private var generatedColumnConstraint: GeneratedColumnConstraint?
    
    init(name: String, type: Database.ColumnType?) {
        self.name = name
        self.type = type
    }
    
    /// Adds a primary key constraint on the column.
    ///
    ///     try db.create(table: "player") { t in
    ///         t.column("id", .integer).primaryKey()
    ///     }
    ///
    /// See <https://www.sqlite.org/lang_createtable.html#primkeyconst> and
    /// <https://www.sqlite.org/lang_createtable.html#rowid>
    ///
    /// - parameters:
    ///     - conflictResolution: An optional conflict resolution
    ///       (see <https://www.sqlite.org/lang_conflict.html>).
    ///     - autoincrement: If true, the primary key is autoincremented.
    /// - returns: Self so that you can further refine the column definition.
    @discardableResult
    public func primaryKey(
        onConflict conflictResolution: Database.ConflictResolution? = nil,
        autoincrement: Bool = false)
    -> Self
    {
        primaryKey = (conflictResolution: conflictResolution, autoincrement: autoincrement)
        return self
    }
    
    /// Adds a NOT NULL constraint on the column.
    ///
    ///     try db.create(table: "player") { t in
    ///         t.column("name", .text).notNull()
    ///     }
    ///
    /// See <https://www.sqlite.org/lang_createtable.html#notnullconst>
    ///
    /// - parameter conflictResolution: An optional conflict resolution
    ///   (see <https://www.sqlite.org/lang_conflict.html>).
    /// - returns: Self so that you can further refine the column definition.
    @discardableResult
    public func notNull(onConflict conflictResolution: Database.ConflictResolution? = nil) -> Self {
        notNullConflictResolution = conflictResolution ?? .abort
        return self
    }
    
    /// Adds a UNIQUE constraint on the column.
    ///
    ///     try db.create(table: "player") { t in
    ///         t.column("email", .text).unique()
    ///     }
    ///
    /// See <https://www.sqlite.org/lang_createtable.html#uniqueconst>
    ///
    /// - parameter conflictResolution: An optional conflict resolution
    ///   (see <https://www.sqlite.org/lang_conflict.html>).
    /// - returns: Self so that you can further refine the column definition.
    @discardableResult
    public func unique(onConflict conflictResolution: Database.ConflictResolution? = nil) -> Self {
        index = .unique(conflictResolution ?? .abort)
        return self
    }
    
    /// Adds an index of the column.
    ///
    ///     try db.create(table: "player") { t in
    ///         t.column("email", .text).indexed()
    ///     }
    ///
    /// See <https://www.sqlite.org/lang_createtable.html#uniqueconst>
    ///
    /// - returns: Self so that you can further refine the column definition.
    @discardableResult
    public func indexed() -> Self {
        if case .none = index {
            self.index = .index
        }
        return self
    }
    
    /// Adds a CHECK constraint on the column.
    ///
    ///     try db.create(table: "player") { t in
    ///         t.column("name", .text).check { length($0) > 0 }
    ///     }
    ///
    /// See <https://www.sqlite.org/lang_createtable.html#ckconst>
    ///
    /// - parameter condition: A closure whose argument is an Column that
    ///   represents the defined column, and returns the expression to check.
    /// - returns: Self so that you can further refine the column definition.
    @discardableResult
    public func check(_ condition: (Column) -> SQLExpressible) -> Self {
        checkConstraints.append(condition(Column(name)).sqlExpression)
        return self
    }
    
    /// Adds a CHECK constraint on the column.
    ///
    ///     try db.create(table: "player") { t in
    ///         t.column("name", .text).check(sql: "LENGTH(name) > 0")
    ///     }
    ///
    /// See <https://www.sqlite.org/lang_createtable.html#ckconst>
    ///
    /// - parameter sql: An SQL snippet.
    /// - returns: Self so that you can further refine the column definition.
    @discardableResult
    public func check(sql: String) -> Self {
        checkConstraints.append(SQL(sql: sql).sqlExpression)
        return self
    }
    
    /// Defines the default column value.
    ///
    ///     try db.create(table: "player") { t in
    ///         t.column("name", .text).defaults(to: "Anonymous")
    ///     }
    ///
    /// See <https://www.sqlite.org/lang_createtable.html#dfltval>
    ///
    /// - parameter value: A DatabaseValueConvertible value.
    /// - returns: Self so that you can further refine the column definition.
    @discardableResult
    public func defaults(to value: DatabaseValueConvertible) -> Self {
        defaultExpression = value.sqlExpression
        return self
    }
    
    /// Defines the default column value.
    ///
    ///     try db.create(table: "player") { t in
    ///         t.column("creationDate", .DateTime).defaults(sql: "CURRENT_TIMESTAMP")
    ///     }
    ///
    /// See <https://www.sqlite.org/lang_createtable.html#dfltval>
    ///
    /// - parameter sql: An SQL snippet.
    /// - returns: Self so that you can further refine the column definition.
    @discardableResult
    public func defaults(sql: String) -> Self {
        defaultExpression = SQL(sql: sql).sqlExpression
        return self
    }
    
    /// Defines the default column collation.
    ///
    ///     try db.create(table: "player") { t in
    ///         t.column("email", .text).collate(.nocase)
    ///     }
    ///
    /// See <https://www.sqlite.org/datatype3.html#collation>
    ///
    /// - parameter collation: An Database.CollationName.
    /// - returns: Self so that you can further refine the column definition.
    @discardableResult
    public func collate(_ collation: Database.CollationName) -> Self {
        collationName = collation.rawValue
        return self
    }
    
    /// Defines the default column collation.
    ///
    ///     try db.create(table: "player") { t in
    ///         t.column("name", .text).collate(.localizedCaseInsensitiveCompare)
    ///     }
    ///
    /// See <https://www.sqlite.org/datatype3.html#collation>
    ///
    /// - parameter collation: A custom DatabaseCollation.
    /// - returns: Self so that you can further refine the column definition.
    @discardableResult
    public func collate(_ collation: DatabaseCollation) -> Self {
        collationName = collation.name
        return self
    }
    
    #if GRDBCUSTOMSQLITE
    /// Defines the column as a generated column.
    ///
    ///     try db.create(table: "player") { t in
    ///         t.column("id", .integer).primaryKey()
    ///         t.column("score", .integer).notNull()
    ///         t.column("bonus", .integer).notNull()
    ///         t.column("totalScore", .integer).generatedAs(sql: "score + bonus", .stored)
    ///     }
    ///
    /// See <https://sqlite.org/gencol.html>. Note particularly the limitations of
    /// generated columns, e.g. they may not have a default value.
    ///
    /// - parameters:
    ///     - sql: An SQL expression.
    ///     - qualification: The generated column's qualification, which
    ///       defaults to `.virtual`.
    /// - returns: Self so that you can further refine the column definition.
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
    ///     try db.create(table: "player") { t in
    ///         t.column("id", .integer).primaryKey()
    ///         t.column("score", .integer).notNull()
    ///         t.column("bonus", .integer).notNull()
    ///         t.column("totalScore", .integer).generatedAs(Column("score") + Column("bonus"), .stored)
    ///     }
    ///
    /// See <https://sqlite.org/gencol.html>. Note particularly the limitations of
    /// generated columns, e.g. they may not have a default value.
    ///
    /// - parameters:
    ///     - expression: The generated expression.
    ///     - qualification: The generated column's qualification, which
    ///       defaults to `.virtual`.
    /// - returns: Self so that you can further refine the column definition.
    @discardableResult
    public func generatedAs(
        _ expression: SQLExpressible,
        _ qualification: GeneratedColumnQualification = .virtual)
    -> Self
    {
        generatedColumnConstraint = GeneratedColumnConstraint(
            expression: expression.sqlExpression,
            qualification: qualification)
        return self
    }
    #endif
    
    /// Defines a foreign key.
    ///
    ///     try db.create(table: "book") { t in
    ///         t.column("authorId", .integer).references("author", onDelete: .cascade)
    ///     }
    ///
    /// See <https://www.sqlite.org/foreignkeys.html>
    ///
    /// - parameters
    ///     - table: The referenced table.
    ///     - column: The column in the referenced table. If not specified, the
    ///       column of the primary key of the referenced table is used.
    ///     - deleteAction: Optional action when the referenced row is deleted.
    ///     - updateAction: Optional action when the referenced row is updated.
    ///     - deferred: If true, defines a deferred foreign key constraint.
    ///       See <https://www.sqlite.org/foreignkeys.html#fk_deferred>.
    /// - returns: Self so that you can further refine the column definition.
    @discardableResult
    public func references(
        _ table: String,
        column: String? = nil,
        onDelete deleteAction: Database.ForeignKeyAction? = nil,
        onUpdate updateAction: Database.ForeignKeyAction? = nil,
        deferred: Bool = false) -> Self
    {
        foreignKeyConstraints.append(ForeignKeyConstraint(
                                        table: table,
                                        column: column,
                                        deleteAction: deleteAction,
                                        updateAction: updateAction,
                                        deferred: deferred))
        return self
    }
    
    fileprivate func sql(_ db: Database, tableName: String, primaryKeyColumns: [String]?) throws -> String {
        var chunks: [String] = []
        chunks.append(name.quotedDatabaseIdentifier)
        if let type = type {
            chunks.append(type.rawValue)
        }
        
        if let (conflictResolution, autoincrement) = primaryKey {
            chunks.append("PRIMARY KEY")
            if let conflictResolution = conflictResolution {
                chunks.append("ON CONFLICT")
                chunks.append(conflictResolution.rawValue)
            }
            if autoincrement {
                chunks.append("AUTOINCREMENT")
            }
        }
        
        switch notNullConflictResolution {
        case .none:
            break
        case .abort?:
            chunks.append("NOT NULL")
        case let conflictResolution?:
            chunks.append("NOT NULL ON CONFLICT")
            chunks.append(conflictResolution.rawValue)
        }
        
        switch index {
        case .none:
            break
        case .unique(let conflictResolution):
            switch conflictResolution {
            case .abort:
                chunks.append("UNIQUE")
            default:
                chunks.append("UNIQUE ON CONFLICT")
                chunks.append(conflictResolution.rawValue)
            }
        case .index:
            break
        }
        
        for checkConstraint in checkConstraints {
            try chunks.append("CHECK (\(checkConstraint.quotedSQL(db)))")
        }
        
        if let defaultExpression = defaultExpression {
            try chunks.append("DEFAULT \(defaultExpression.quotedSQL(db))")
        }
        
        if let collationName = collationName {
            chunks.append("COLLATE")
            chunks.append(collationName)
        }
        
        for constraint in foreignKeyConstraints {
            chunks.append("REFERENCES")
            if let column = constraint.column {
                // explicit reference
                chunks.append("\(constraint.table.quotedDatabaseIdentifier)(\(column.quotedDatabaseIdentifier))")
            } else if constraint.table.lowercased() == tableName.lowercased() {
                // implicit autoreference
                let primaryKeyColumns = try primaryKeyColumns ?? db.primaryKey(constraint.table).columns
                chunks.append("""
                    \(constraint.table.quotedDatabaseIdentifier)(\
                    \(primaryKeyColumns.map(\.quotedDatabaseIdentifier).joined(separator: ", "))\
                    )
                    """)
            } else {
                // implicit external reference
                let primaryKeyColumns = try db.primaryKey(constraint.table).columns
                chunks.append("""
                    \(constraint.table.quotedDatabaseIdentifier)(\
                    \(primaryKeyColumns.map(\.quotedDatabaseIdentifier).joined(separator: ", "))\
                    )
                    """)
            }
            if let deleteAction = constraint.deleteAction {
                chunks.append("ON DELETE")
                chunks.append(deleteAction.rawValue)
            }
            if let updateAction = constraint.updateAction {
                chunks.append("ON UPDATE")
                chunks.append(updateAction.rawValue)
            }
            if constraint.deferred {
                chunks.append("DEFERRABLE INITIALLY DEFERRED")
            }
        }
        
        if let constraint = generatedColumnConstraint {
            try chunks.append("GENERATED ALWAYS AS (\(constraint.expression.quotedSQL(db)))")
            let qualificationLiteral: String
            switch constraint.qualification {
            case .stored:
                qualificationLiteral = "STORED"
            case .virtual:
                qualificationLiteral = "VIRTUAL"
            }
            chunks.append(qualificationLiteral)
        }
        
        return chunks.joined(separator: " ")
    }
    
    fileprivate func indexDefinition(in table: String, options: IndexOptions = []) -> IndexDefinition? {
        switch index {
        case .none: return nil
        case .unique: return nil
        case .index:
            return IndexDefinition(
                name: "\(table)_on_\(name)",
                table: table,
                columns: [name],
                options: options,
                condition: nil)
        }
    }
}

/// Table creation options
public struct IndexOptions: OptionSet {
    /// :nodoc:
    public let rawValue: Int
    
    /// :nodoc:
    public init(rawValue: Int) { self.rawValue = rawValue }
    
    /// Only creates the index if it does not already exist.
    public static let ifNotExists = IndexOptions(rawValue: 1 << 0)
    
    /// Creates a unique index.
    public static let unique = IndexOptions(rawValue: 1 << 1)
}

private struct IndexDefinition {
    let name: String
    let table: String
    let columns: [String]
    let options: IndexOptions
    let condition: SQLExpression?
    
    func sql(_ db: Database) throws -> String {
        var chunks: [String] = []
        chunks.append("CREATE")
        if options.contains(.unique) {
            chunks.append("UNIQUE")
        }
        chunks.append("INDEX")
        if options.contains(.ifNotExists) {
            chunks.append("IF NOT EXISTS")
        }
        chunks.append(name.quotedDatabaseIdentifier)
        chunks.append("ON")
        chunks.append("""
            \(table.quotedDatabaseIdentifier)(\
            \(columns.map(\.quotedDatabaseIdentifier).joined(separator: ", "))\
            )
            """)
        if let condition = condition {
            try chunks.append("WHERE \(condition.quotedSQL(db))")
        }
        return chunks.joined(separator: " ")
    }
}

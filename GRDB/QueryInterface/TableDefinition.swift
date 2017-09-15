extension Database {
    
    // MARK: - Database Schema
    
    #if GRDBCUSTOMSQLITE || GRDBCIPHER
    /// Creates a database table.
    ///
    ///     try db.create(table: "pointOfInterests") { t in
    ///         t.column("id", .integer).primaryKey()
    ///         t.column("title", .text)
    ///         t.column("favorite", .boolean).notNull().default(false)
    ///         t.column("longitude", .double).notNull()
    ///         t.column("latitude", .double).notNull()
    ///     }
    ///
    /// See https://www.sqlite.org/lang_createtable.html and
    /// https://www.sqlite.org/withoutrowid.html
    ///
    /// - parameters:
    ///     - name: The table name.
    ///     - temporary: If true, creates a temporary table.
    ///     - ifNotExists: If false, no error is thrown if table already exists.
    ///     - withoutRowID: If true, uses WITHOUT ROWID optimization.
    ///     - body: A closure that defines table columns and constraints.
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    public func create(table name: String, temporary: Bool = false, ifNotExists: Bool = false, withoutRowID: Bool = false, body: (TableDefinition) -> Void) throws {
        let definition = TableDefinition(name: name, temporary: temporary, ifNotExists: ifNotExists, withoutRowID: withoutRowID)
        body(definition)
        let sql = try definition.sql(self)
        try execute(sql)
    }
    #else
    /// Creates a database table.
    ///
    ///     try db.create(table: "pointOfInterests") { t in
    ///         t.column("id", .integer).primaryKey()
    ///         t.column("title", .text)
    ///         t.column("favorite", .boolean).notNull().default(false)
    ///         t.column("longitude", .double).notNull()
    ///         t.column("latitude", .double).notNull()
    ///     }
    ///
    /// See https://www.sqlite.org/lang_createtable.html and
    /// https://www.sqlite.org/withoutrowid.html
    ///
    /// - parameters:
    ///     - name: The table name.
    ///     - temporary: If true, creates a temporary table.
    ///     - ifNotExists: If false, no error is thrown if table already exists.
    ///     - withoutRowID: If true, uses WITHOUT ROWID optimization.
    ///     - body: A closure that defines table columns and constraints.
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    @available(iOS 8.2, OSX 10.10, *)
    public func create(table name: String, temporary: Bool = false, ifNotExists: Bool = false, withoutRowID: Bool, body: (TableDefinition) -> Void) throws {
        // WITHOUT ROWID was added in SQLite 3.8.2 http://www.sqlite.org/changes.html#version_3_8_2
        // It is available from iOS 8.2 and OS X 10.10 https://github.com/yapstudios/YapDatabase/wiki/SQLite-version-(bundled-with-OS)
        let definition = TableDefinition(name: name, temporary: temporary, ifNotExists: ifNotExists, withoutRowID: withoutRowID)
        body(definition)
        let sql = try definition.sql(self)
        try execute(sql)
    }
    
    /// Creates a database table.
    ///
    ///     try db.create(table: "pointOfInterests") { t in
    ///         t.column("id", .integer).primaryKey()
    ///         t.column("title", .text)
    ///         t.column("favorite", .boolean).notNull().default(false)
    ///         t.column("longitude", .double).notNull()
    ///         t.column("latitude", .double).notNull()
    ///     }
    ///
    /// See https://www.sqlite.org/lang_createtable.html
    ///
    /// - parameters:
    ///     - name: The table name.
    ///     - temporary: If true, creates a temporary table.
    ///     - ifNotExists: If false, no error is thrown if table already exists.
    ///     - body: A closure that defines table columns and constraints.
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    public func create(table name: String, temporary: Bool = false, ifNotExists: Bool = false, body: (TableDefinition) -> Void) throws {
        let definition = TableDefinition(name: name, temporary: temporary, ifNotExists: ifNotExists, withoutRowID: false)
        body(definition)
        let sql = try definition.sql(self)
        try execute(sql)
    }
    #endif

    /// Renames a database table.
    ///
    /// See https://www.sqlite.org/lang_altertable.html
    ///
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    public func rename(table name: String, to newName: String) throws {
        try execute("ALTER TABLE \(name.quotedDatabaseIdentifier) RENAME TO \(newName.quotedDatabaseIdentifier)")
    }
    
    /// Modifies a database table.
    ///
    ///     try db.alter(table: "players") { t in
    ///         t.add(column: "url", .text)
    ///     }
    ///
    /// See https://www.sqlite.org/lang_altertable.html
    ///
    /// - parameters:
    ///     - name: The table name.
    ///     - body: A closure that defines table alterations.
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    public func alter(table name: String, body: (TableAlteration) -> Void) throws {
        let alteration = TableAlteration(name: name)
        body(alteration)
        let sql = try alteration.sql(self)
        try execute(sql)
    }
    
    /// Deletes a database table.
    ///
    /// See https://www.sqlite.org/lang_droptable.html
    ///
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    public func drop(table name: String) throws {
        try execute("DROP TABLE \(name.quotedDatabaseIdentifier)")
    }
    
    #if GRDBCUSTOMSQLITE || GRDBCIPHER
    /// Creates an index.
    ///
    ///     try db.create(index: "playerByEmail", on: "player", columns: ["email"])
    ///
    /// SQLite can also index expressions (https://www.sqlite.org/expridx.html)
    /// and use specific collations. To create such an index, use a raw SQL
    /// query.
    ///
    ///     try db.execute("CREATE INDEX ...")
    ///
    /// See https://www.sqlite.org/lang_createindex.html
    ///
    /// - parameters:
    ///     - name: The index name.
    ///     - table: The name of the indexed table.
    ///     - columns: The indexed columns.
    ///     - unique: If true, creates a unique index.
    ///     - ifNotExists: If false, no error is thrown if index already exists.
    ///     - condition: If not nil, creates a partial index
    ///       (see https://www.sqlite.org/partialindex.html).
    public func create(index name: String, on table: String, columns: [String], unique: Bool = false, ifNotExists: Bool = false, condition: SQLExpressible? = nil) throws {
        // Partial indexes were introduced in SQLite 3.8.0 http://www.sqlite.org/changes.html#version_3_8_0
        // It is available from iOS 8.2 and OS X 10.10 https://github.com/yapstudios/YapDatabase/wiki/SQLite-version-(bundled-with-OS)
        let definition = IndexDefinition(name: name, table: table, columns: columns, unique: unique, ifNotExists: ifNotExists, condition: condition?.sqlExpression)
        let sql = definition.sql()
        try execute(sql)
    }
    #else
    /// Creates an index.
    ///
    ///     try db.create(index: "playerByEmail", on: "player", columns: ["email"])
    ///
    /// SQLite can also index expressions (https://www.sqlite.org/expridx.html)
    /// and use specific collations. To create such an index, use a raw SQL
    /// query.
    ///
    ///     try db.execute("CREATE INDEX ...")
    ///
    /// See https://www.sqlite.org/lang_createindex.html
    ///
    /// - parameters:
    ///     - name: The index name.
    ///     - table: The name of the indexed table.
    ///     - columns: The indexed columns.
    ///     - unique: If true, creates a unique index.
    ///     - ifNotExists: If false, no error is thrown if index already exists.
    public func create(index name: String, on table: String, columns: [String], unique: Bool = false, ifNotExists: Bool = false) throws {
        // Partial indexes were introduced in SQLite 3.8.0 http://www.sqlite.org/changes.html#version_3_8_0
        // It is available from iOS 8.2 and OS X 10.10 https://github.com/yapstudios/YapDatabase/wiki/SQLite-version-(bundled-with-OS)
        let definition = IndexDefinition(name: name, table: table, columns: columns, unique: unique, ifNotExists: ifNotExists, condition: nil)
        let sql = definition.sql()
        try execute(sql)
    }
    
    /// Creates a partial index.
    ///
    ///     try db.create(index: "playerByEmail", on: "player", columns: ["email"], condition: Column("email") != nil)
    ///
    /// See https://www.sqlite.org/lang_createindex.html, and
    /// https://www.sqlite.org/partialindex.html
    ///
    /// - parameters:
    ///     - name: The index name.
    ///     - table: The name of the indexed table.
    ///     - columns: The indexed columns.
    ///     - unique: If true, creates a unique index.
    ///     - ifNotExists: If false, no error is thrown if index already exists.
    ///     - condition: The condition that indexed rows must verify.
    @available(iOS 8.2, OSX 10.10, *)
    public func create(index name: String, on table: String, columns: [String], unique: Bool = false, ifNotExists: Bool = false, condition: SQLExpressible) throws {
        // Partial indexes were introduced in SQLite 3.8.0 http://www.sqlite.org/changes.html#version_3_8_0
        // It is available from iOS 8.2 and OS X 10.10 https://github.com/yapstudios/YapDatabase/wiki/SQLite-version-(bundled-with-OS)
        let definition = IndexDefinition(name: name, table: table, columns: columns, unique: unique, ifNotExists: ifNotExists, condition: condition.sqlExpression)
        let sql = definition.sql()
        try execute(sql)
    }
    #endif
    
    /// Deletes a database index.
    ///
    /// See https://www.sqlite.org/lang_dropindex.html
    ///
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    public func drop(index name: String) throws {
        try execute("DROP INDEX \(name.quotedDatabaseIdentifier)")
    }
}

/// The TableDefinition class lets you define table columns and constraints.
///
/// You don't create instances of this class. Instead, you use the Database
/// `create(table:)` method:
///
///     try db.create(table: "players") { t in // t is TableDefinition
///         t.column(...)
///     }
///
/// See https://www.sqlite.org/lang_createtable.html
public final class TableDefinition {
    private typealias KeyConstraint = (columns: [String], conflictResolution: Database.ConflictResolution?)
    
    private let name: String
    private let temporary: Bool
    private let ifNotExists: Bool
    private let withoutRowID: Bool
    private var columns: [ColumnDefinition] = []
    private var primaryKeyConstraint: KeyConstraint?
    private var uniqueKeyConstraints: [KeyConstraint] = []
    private var foreignKeyConstraints: [(columns: [String], table: String, destinationColumns: [String]?, deleteAction: Database.ForeignKeyAction?, updateAction: Database.ForeignKeyAction?, deferred: Bool)] = []
    private var checkConstraints: [SQLExpression] = []
    
    init(name: String, temporary: Bool, ifNotExists: Bool, withoutRowID: Bool) {
        self.name = name
        self.temporary = temporary
        self.ifNotExists = ifNotExists
        self.withoutRowID = withoutRowID
    }
    
    /// Appends a table column.
    ///
    ///     try db.create(table: "players") { t in
    ///         t.column("name", .text)
    ///     }
    ///
    /// See https://www.sqlite.org/lang_createtable.html#tablecoldef
    ///
    /// - parameter name: the column name.
    /// - parameter type: the eventual column type.
    /// - returns: An ColumnDefinition that allows you to refine the
    ///   column definition.
    @discardableResult
    public func column(_ name: String, _ type: Database.ColumnType? = nil) -> ColumnDefinition {
        let column = ColumnDefinition(name: name, type: type)
        columns.append(column)
        return column
    }
    
    /// Defines the table primary key.
    ///
    ///     try db.create(table: "citizenships") { t in
    ///         t.column("citizenID", .integer)
    ///         t.column("countryCode", .text)
    ///         t.primaryKey(["citizenID", "countryCode"])
    ///     }
    ///
    /// See https://www.sqlite.org/lang_createtable.html#primkeyconst and
    /// https://www.sqlite.org/lang_createtable.html#rowid
    ///
    /// - parameter columns: The primary key columns.
    /// - parameter conflitResolution: An optional conflict resolution
    ///   (see https://www.sqlite.org/lang_conflict.html).
    public func primaryKey(_ columns: [String], onConflict conflictResolution: Database.ConflictResolution? = nil) {
        guard primaryKeyConstraint == nil else {
            // Programmer error
            fatalError("can't define several primary keys")
        }
        primaryKeyConstraint = (columns: columns, conflictResolution: conflictResolution)
    }
    
    /// Adds a unique key.
    ///
    ///     try db.create(table: "pointOfInterests") { t in
    ///         t.column("latitude", .double)
    ///         t.column("longitude", .double)
    ///         t.uniqueKey(["latitude", "longitude"])
    ///     }
    ///
    /// See https://www.sqlite.org/lang_createtable.html#uniqueconst
    ///
    /// - parameter columns: The unique key columns.
    /// - parameter conflitResolution: An optional conflict resolution
    ///   (see https://www.sqlite.org/lang_conflict.html).
    public func uniqueKey(_ columns: [String], onConflict conflictResolution: Database.ConflictResolution? = nil) {
        uniqueKeyConstraints.append((columns: columns, conflictResolution: conflictResolution))
    }
    
    /// Adds a foreign key.
    ///
    ///     try db.create(table: "passport") { t in
    ///         t.column("issueDate", .date)
    ///         t.column("citizenID", .integer)
    ///         t.column("countryCode", .text)
    ///         t.foreignKey(["citizenID", "countryCode"], references: "citizenships", onDelete: .cascade)
    ///     }
    ///
    /// See https://www.sqlite.org/foreignkeys.html
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
    ///       See https://www.sqlite.org/foreignkeys.html#fk_deferred.
    public func foreignKey(_ columns: [String], references table: String, columns destinationColumns: [String]? = nil, onDelete deleteAction: Database.ForeignKeyAction? = nil, onUpdate updateAction: Database.ForeignKeyAction? = nil, deferred: Bool = false) {
        foreignKeyConstraints.append((columns: columns, table: table, destinationColumns: destinationColumns, deleteAction: deleteAction, updateAction: updateAction, deferred: deferred))
    }
    
    /// Adds a CHECK constraint.
    ///
    ///     try db.create(table: "players") { t in
    ///         t.column("personalPhone", .text)
    ///         t.column("workPhone", .text)
    ///         let personalPhone = Column("personalPhone")
    ///         let workPhone = Column("workPhone")
    ///         t.check(personalPhone != nil || workPhone != nil)
    ///     }
    ///
    /// See https://www.sqlite.org/lang_createtable.html#ckconst
    ///
    /// - parameter condition: The checked condition
    public func check(_ condition: SQLExpressible) {
        checkConstraints.append(condition.sqlExpression)
    }
    
    /// Adds a CHECK constraint.
    ///
    ///     try db.create(table: "players") { t in
    ///         t.column("personalPhone", .text)
    ///         t.column("workPhone", .text)
    ///         t.check(sql: "personalPhone IS NOT NULL OR workPhone IS NOT NULL")
    ///     }
    ///
    /// See https://www.sqlite.org/lang_createtable.html#ckconst
    ///
    /// - parameter sql: An SQL snippet
    public func check(sql: String) {
        checkConstraints.append(SQLExpressionLiteral(sql))
    }
    
    fileprivate func sql(_ db: Database) throws -> String {
        var statements: [String] = []
        
        do {
            var chunks: [String] = []
            chunks.append("CREATE")
            if temporary {
                chunks.append("TEMPORARY")
            }
            chunks.append("TABLE")
            if ifNotExists {
                chunks.append("IF NOT EXISTS")
            }
            chunks.append(name.quotedDatabaseIdentifier)
            
            let primaryKeyColumns: [String]
            if let (columns, _) = primaryKeyConstraint {
                primaryKeyColumns = columns
            } else if let index = columns.index(where: { $0.primaryKey != nil }) {
                primaryKeyColumns = [columns[index].name]
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
                try items.append(contentsOf: columns.map { try $0.sql(db, tableName: name, primaryKeyColumns: primaryKeyColumns) })
                
                if let (columns, conflictResolution) = primaryKeyConstraint {
                    var chunks: [String] = []
                    chunks.append("PRIMARY KEY")
                    chunks.append("(\((columns.map { $0.quotedDatabaseIdentifier } as [String]).joined(separator: ", ")))")
                    if let conflictResolution = conflictResolution {
                        chunks.append("ON CONFLICT")
                        chunks.append(conflictResolution.rawValue)
                    }
                    items.append(chunks.joined(separator: " "))
                }
                
                for (columns, conflictResolution) in uniqueKeyConstraints {
                    var chunks: [String] = []
                    chunks.append("UNIQUE")
                    chunks.append("(\((columns.map { $0.quotedDatabaseIdentifier } as [String]).joined(separator: ", ")))")
                    if let conflictResolution = conflictResolution {
                        chunks.append("ON CONFLICT")
                        chunks.append(conflictResolution.rawValue)
                    }
                    items.append(chunks.joined(separator: " "))
                }
                
                for (columns, table, destinationColumns, deleteAction, updateAction, deferred) in foreignKeyConstraints {
                    var chunks: [String] = []
                    chunks.append("FOREIGN KEY")
                    chunks.append("(\((columns.map { $0.quotedDatabaseIdentifier } as [String]).joined(separator: ", ")))")
                    chunks.append("REFERENCES")
                    if let destinationColumns = destinationColumns {
                        chunks.append("\(table.quotedDatabaseIdentifier)(\((destinationColumns.map { $0.quotedDatabaseIdentifier } as [String]).joined(separator: ", ")))")
                    } else if table == name {
                        chunks.append("\(table.quotedDatabaseIdentifier)(\((primaryKeyColumns.map { $0.quotedDatabaseIdentifier } as [String]).joined(separator: ", ")))")
                    } else {
                        let primaryKey = try db.primaryKey(table)
                        chunks.append("\(table.quotedDatabaseIdentifier)(\((primaryKey.columns.map { $0.quotedDatabaseIdentifier } as [String]).joined(separator: ", ")))")
                    }
                    if let deleteAction = deleteAction {
                        chunks.append("ON DELETE")
                        chunks.append(deleteAction.rawValue)
                    }
                    if let updateAction = updateAction {
                        chunks.append("ON UPDATE")
                        chunks.append(updateAction.rawValue)
                    }
                    if deferred {
                        chunks.append("DEFERRABLE INITIALLY DEFERRED")
                    }
                    items.append(chunks.joined(separator: " "))
                }
                
                for checkExpression in checkConstraints {
                    var chunks: [String] = []
                    chunks.append("CHECK")
                    chunks.append("(" + checkExpression.sql + ")")
                    items.append(chunks.joined(separator: " "))
                }
                
                chunks.append("(\(items.joined(separator: ", ")))")
            }
            
            if withoutRowID {
                chunks.append("WITHOUT ROWID")
            }
            statements.append(chunks.joined(separator: " "))
        }
        
        let indexStatements = columns
            .flatMap { $0.indexDefinition(in: name) }
            .map { $0.sql() }
        statements.append(contentsOf: indexStatements)
        return statements.joined(separator: "; ")
    }
}

/// The TableAlteration class lets you alter database tables.
///
/// You don't create instances of this class. Instead, you use the Database
/// `alter(table:)` method:
///
///     try db.alter(table: "players") { t in // t is TableAlteration
///         t.add(column: ...)
///     }
///
/// See https://www.sqlite.org/lang_altertable.html
public final class TableAlteration {
    private let name: String
    private var addedColumns: [ColumnDefinition] = []
    
    init(name: String) {
        self.name = name
    }
    
    /// Appends a column to the table.
    ///
    ///     try db.alter(table: "players") { t in
    ///         t.add(column: "url", .text)
    ///     }
    ///
    /// See https://www.sqlite.org/lang_altertable.html
    ///
    /// - parameter name: the column name.
    /// - parameter type: the column type.
    /// - returns: An ColumnDefinition that allows you to refine the
    ///   column definition.
    @discardableResult
    public func add(column name: String, _ type: Database.ColumnType) -> ColumnDefinition {
        let column = ColumnDefinition(name: name, type: type)
        addedColumns.append(column)
        return column
    }
    
    fileprivate func sql(_ db: Database) throws -> String {
        var statements: [String] = []
        
        for column in addedColumns {
            var chunks: [String] = []
            chunks.append("ALTER TABLE")
            chunks.append(name.quotedDatabaseIdentifier)
            chunks.append("ADD COLUMN")
            try chunks.append(column.sql(db, tableName: name, primaryKeyColumns: nil))
            let statement = chunks.joined(separator: " ")
            statements.append(statement)
            
            if let indexDefinition = column.indexDefinition(in: name) {
                statements.append(indexDefinition.sql())
            }
        }
        
        return statements.joined(separator: "; ")
    }
}

/// The ColumnDefinition class lets you refine a table column.
///
/// You get instances of this class when you create or alter a database table:
///
///     try db.create(table: "players") { t in
///         t.column(...)      // ColumnDefinition
///     }
///
///     try db.alter(table: "players") { t in
///         t.add(column: ...) // ColumnDefinition
///     }
///
/// See https://www.sqlite.org/lang_createtable.html and
/// https://www.sqlite.org/lang_altertable.html
public final class ColumnDefinition {
    enum Index {
        case none
        case index
        case unique(Database.ConflictResolution)
    }
    fileprivate let name: String
    private let type: Database.ColumnType?
    fileprivate var primaryKey: (conflictResolution: Database.ConflictResolution?, autoincrement: Bool)?
    private var index: Index = .none
    private var notNullConflictResolution: Database.ConflictResolution?
    private var checkConstraints: [SQLExpression] = []
    private var foreignKeyConstraints: [(table: String, column: String?, deleteAction: Database.ForeignKeyAction?, updateAction: Database.ForeignKeyAction?, deferred: Bool)] = []
    private var defaultExpression: SQLExpression?
    private var collationName: String?
    
    init(name: String, type: Database.ColumnType?) {
        self.name = name
        self.type = type
    }
    
    /// Adds a primary key constraint on the column.
    ///
    ///     try db.create(table: "players") { t in
    ///         t.column("id", .integer).primaryKey()
    ///     }
    ///
    /// See https://www.sqlite.org/lang_createtable.html#primkeyconst and
    /// https://www.sqlite.org/lang_createtable.html#rowid
    ///
    /// - parameters:
    ///     - conflitResolution: An optional conflict resolution
    ///       (see https://www.sqlite.org/lang_conflict.html).
    ///     - autoincrement: If true, the primary key is autoincremented.
    /// - returns: Self so that you can further refine the column definition.
    @discardableResult
    public func primaryKey(onConflict conflictResolution: Database.ConflictResolution? = nil, autoincrement: Bool = false) -> Self {
        primaryKey = (conflictResolution: conflictResolution, autoincrement: autoincrement)
        return self
    }
    
    /// Adds a NOT NULL constraint on the column.
    ///
    ///     try db.create(table: "players") { t in
    ///         t.column("name", .text).notNull()
    ///     }
    ///
    /// See https://www.sqlite.org/lang_createtable.html#notnullconst
    ///
    /// - parameter conflitResolution: An optional conflict resolution
    ///   (see https://www.sqlite.org/lang_conflict.html).
    /// - returns: Self so that you can further refine the column definition.
    @discardableResult
    public func notNull(onConflict conflictResolution: Database.ConflictResolution? = nil) -> Self {
        notNullConflictResolution = conflictResolution ?? .abort
        return self
    }
    
    /// Adds a UNIQUE constraint on the column.
    ///
    ///     try db.create(table: "players") { t in
    ///         t.column("email", .text).unique()
    ///     }
    ///
    /// See https://www.sqlite.org/lang_createtable.html#uniqueconst
    ///
    /// - parameter conflitResolution: An optional conflict resolution
    ///   (see https://www.sqlite.org/lang_conflict.html).
    /// - returns: Self so that you can further refine the column definition.
    @discardableResult
    public func unique(onConflict conflictResolution: Database.ConflictResolution? = nil) -> Self {
        index = .unique(conflictResolution ?? .abort)
        return self
    }
    
    /// Adds an index of the column.
    ///
    ///     try db.create(table: "players") { t in
    ///         t.column("email", .text).indexed()
    ///     }
    ///
    /// See https://www.sqlite.org/lang_createtable.html#uniqueconst
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
    ///     try db.create(table: "players") { t in
    ///         t.column("name", .text).check { length($0) > 0 }
    ///     }
    ///
    /// See https://www.sqlite.org/lang_createtable.html#ckconst
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
    ///     try db.create(table: "players") { t in
    ///         t.column("name", .text).check(sql: "LENGTH(name) > 0")
    ///     }
    ///
    /// See https://www.sqlite.org/lang_createtable.html#ckconst
    ///
    /// - parameter sql: An SQL snippet.
    /// - returns: Self so that you can further refine the column definition.
    @discardableResult
    public func check(sql: String) -> Self {
        checkConstraints.append(SQLExpressionLiteral(sql))
        return self
    }
    
    /// Defines the default column value.
    ///
    ///     try db.create(table: "players") { t in
    ///         t.column("name", .text).defaults(to: "Anonymous")
    ///     }
    ///
    /// See https://www.sqlite.org/lang_createtable.html#dfltval
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
    ///     try db.create(table: "players") { t in
    ///         t.column("creationDate", .DateTime).defaults(sql: "CURRENT_TIMESTAMP")
    ///     }
    ///
    /// See https://www.sqlite.org/lang_createtable.html#dfltval
    ///
    /// - parameter sql: An SQL snippet.
    /// - returns: Self so that you can further refine the column definition.
    @discardableResult
    public func defaults(sql: String) -> Self {
        defaultExpression = SQLExpressionLiteral(sql)
        return self
    }
    
    // Defines the default column collation.
    ///
    ///     try db.create(table: "players") { t in
    ///         t.column("email", .text).collate(.nocase)
    ///     }
    ///
    /// See https://www.sqlite.org/datatype3.html#collation
    ///
    /// - parameter collation: An Database.CollationName.
    /// - returns: Self so that you can further refine the column definition.
    @discardableResult
    public func collate(_ collation: Database.CollationName) -> Self {
        collationName = collation.rawValue
        return self
    }
    
    // Defines the default column collation.
    ///
    ///     try db.create(table: "players") { t in
    ///         t.column("name", .text).collate(.localizedCaseInsensitiveCompare)
    ///     }
    ///
    /// See https://www.sqlite.org/datatype3.html#collation
    ///
    /// - parameter collation: A custom DatabaseCollation.
    /// - returns: Self so that you can further refine the column definition.
    @discardableResult
    public func collate(_ collation: DatabaseCollation) -> Self {
        collationName = collation.name
        return self
    }
    
    /// Defines a foreign key.
    ///
    ///     try db.create(table: "books") { t in
    ///         t.column("authorId", .integer).references("authors", onDelete: .cascade)
    ///     }
    ///
    /// See https://www.sqlite.org/foreignkeys.html
    ///
    /// - parameters
    ///     - table: The referenced table.
    ///     - column: The column in the referenced table. If not specified, the
    ///       column of the primary key of the referenced table is used.
    ///     - deleteAction: Optional action when the referenced row is deleted.
    ///     - updateAction: Optional action when the referenced row is updated.
    ///     - deferred: If true, defines a deferred foreign key constraint.
    ///       See https://www.sqlite.org/foreignkeys.html#fk_deferred.
    /// - returns: Self so that you can further refine the column definition.
    @discardableResult
    public func references(_ table: String, column: String? = nil, onDelete deleteAction: Database.ForeignKeyAction? = nil, onUpdate updateAction: Database.ForeignKeyAction? = nil, deferred: Bool = false) -> Self {
        foreignKeyConstraints.append((table: table, column: column, deleteAction: deleteAction, updateAction: updateAction, deferred: deferred))
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
            chunks.append("CHECK")
            chunks.append("(" + checkConstraint.sql + ")")
        }
        
        if let defaultExpression = defaultExpression {
            chunks.append("DEFAULT")
            chunks.append(defaultExpression.sql)
        }
        
        if let collationName = collationName {
            chunks.append("COLLATE")
            chunks.append(collationName)
        }
        
        for (table, column, deleteAction, updateAction, deferred) in foreignKeyConstraints {
            chunks.append("REFERENCES")
            if let column = column {
                // explicit reference
                chunks.append("\(table.quotedDatabaseIdentifier)(\(column.quotedDatabaseIdentifier))")
            } else if table.lowercased() == tableName.lowercased() {
                // implicit autoreference
                let primaryKeyColumns = try primaryKeyColumns ?? db.primaryKey(table).columns
                chunks.append("\(table.quotedDatabaseIdentifier)(\((primaryKeyColumns.map { $0.quotedDatabaseIdentifier } as [String]).joined(separator: ", ")))")
            } else {
                // implicit external reference
                let primaryKeyColumns = try db.primaryKey(table).columns
                chunks.append("\(table.quotedDatabaseIdentifier)(\((primaryKeyColumns.map { $0.quotedDatabaseIdentifier } as [String]).joined(separator: ", ")))")
            }
            if let deleteAction = deleteAction {
                chunks.append("ON DELETE")
                chunks.append(deleteAction.rawValue)
            }
            if let updateAction = updateAction {
                chunks.append("ON UPDATE")
                chunks.append(updateAction.rawValue)
            }
            if deferred {
                chunks.append("DEFERRABLE INITIALLY DEFERRED")
            }
        }
        
        return chunks.joined(separator: " ")
    }
    
    fileprivate func indexDefinition(in table: String) -> IndexDefinition? {
        switch index {
        case .none: return nil
        case .unique: return nil
        case .index:
            return IndexDefinition(
                name: "\(table)_on_\(name)",
                table: table,
                columns: [name],
                unique: false,
                ifNotExists: false,
                condition: nil)
        }
    }
}

private struct IndexDefinition {
    let name: String
    let table: String
    let columns: [String]
    let unique: Bool
    let ifNotExists: Bool
    let condition: SQLExpression?
    
    func sql() -> String {
        var chunks: [String] = []
        chunks.append("CREATE")
        if unique {
            chunks.append("UNIQUE")
        }
        chunks.append("INDEX")
        if ifNotExists {
            chunks.append("IF NOT EXISTS")
        }
        chunks.append(name.quotedDatabaseIdentifier)
        chunks.append("ON")
        chunks.append("\(table.quotedDatabaseIdentifier)(\((columns.map { $0.quotedDatabaseIdentifier } as [String]).joined(separator: ", ")))")
        if let condition = condition {
            chunks.append("WHERE")
            chunks.append(condition.sql)
        }
        return chunks.joined(separator: " ")
    }
}

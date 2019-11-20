/// A DatabaseMigrator registers and applies database migrations.
///
/// Migrations are named blocks of SQL statements that are guaranteed to be
/// applied in order, once and only once.
///
/// When a user upgrades your application, only non-applied migration are run.
///
/// Usage:
///
///     var migrator = DatabaseMigrator()
///
///     // 1st migration
///     migrator.registerMigration("createLibrary") { db in
///         try db.create(table: "author") { t in
///             t.autoIncrementedPrimaryKey("id")
///             t.column("creationDate", .datetime)
///             t.column("name", .text).notNull()
///         }
///
///         try db.create(table: "book") { t in
///             t.autoIncrementedPrimaryKey("id")
///             t.column("authorId", .integer)
///                 .notNull()
///                 .references("author", onDelete: .cascade)
///             t.column("title", .text).notNull()
///         }
///     }
///
///     // 2nd migration
///     migrator.registerMigration("AddBirthYearToAuthors") { db in
///         try db.alter(table: "author") { t
///             t.add(column: "birthYear", .integer)
///         }
///     }
///
///     // Migrations for future versions will be inserted here:
///     //
///     // // 3rd migration
///     // migrator.registerMigration("...") { db in
///     //     ...
///     // }
///
///     try migrator.migrate(dbQueue)
public struct DatabaseMigrator {
    /// When the `eraseDatabaseOnSchemaChange` flag is true, the migrator will
    /// automatically wipe out the full database content, and recreate the whole
    /// database from scratch, if it detects that a migration has changed its
    /// definition.
    ///
    /// This flag can destroy your precious users' data!
    ///
    /// But it may be useful in two situations:
    ///
    /// 1. During application development, as you are still designing
    ///     migrations, and the schema changes often.
    ///
    ///     In this case, it is recommended that you make sure this flag does
    ///     not ship in the distributed application, in order to avoid undesired
    ///     data loss:
    ///
    ///         var migrator = DatabaseMigrator()
    ///         #if DEBUG
    ///         // Speed up development by nuking the database when migrations change
    ///         migrator.eraseDatabaseOnSchemaChange = true
    ///         #endif
    ///
    /// 2. When the database content can easily be recreated, such as a cache
    ///     for some downloaded data.
    public var eraseDatabaseOnSchemaChange = false
    private var migrations: [Migration] = []
    
    /// A new migrator.
    public init() {
    }
    
    /// Registers a migration.
    ///
    ///     migrator.registerMigration("createAuthors") { db in
    ///         try db.create(table: "author") { t in
    ///             t.autoIncrementedPrimaryKey("id")
    ///             t.column("creationDate", .datetime)
    ///             t.column("name", .text).notNull()
    ///         }
    ///     }
    ///
    /// - parameters:
    ///     - identifier: The migration identifier.
    ///     - block: The migration block that performs SQL statements.
    /// - precondition: No migration with the same same as already been registered.
    public mutating func registerMigration(_ identifier: String, migrate: @escaping (Database) throws -> Void) {
        registerMigration(Migration(identifier: identifier, migrate: migrate))
    }
    
    #if GRDBCUSTOMSQLITE || GRDBCIPHER
    /// Registers an advanced migration, as described at https://www.sqlite.org/lang_altertable.html#otheralter
    ///
    ///     // Add a NOT NULL constraint on players.name:
    ///     migrator.registerMigrationWithDeferredForeignKeyCheck("AddNotNullCheckOnName") { db in
    ///         try db.create(table: "new_player") { t in
    ///             t.autoIncrementedPrimaryKey("id")
    ///             t.column("name", .text).notNull()
    ///         }
    ///         try db.execute(sql: "INSERT INTO new_player SELECT * FROM player")
    ///         try db.drop(table: "player")
    ///         try db.rename(table: "new_player", to: "player")
    ///     }
    ///
    /// While your migration code runs with disabled foreign key checks, those
    /// are re-enabled and checked at the end of the migration, regardless of
    /// eventual errors.
    ///
    /// - parameters:
    ///     - identifier: The migration identifier.
    ///     - block: The migration block that performs SQL statements.
    /// - precondition: No migration with the same same as already been registered.
    ///
    /// :nodoc:
    public mutating func registerMigrationWithDeferredForeignKeyCheck(
        _ identifier: String,
        migrate: @escaping (Database) throws -> Void)
    {
        registerMigration(Migration(identifier: identifier, disabledForeignKeyChecks: true, migrate: migrate))
    }
    #else
    @available(OSX 10.10, *)
    /// Registers an advanced migration, as described at https://www.sqlite.org/lang_altertable.html#otheralter
    ///
    ///     // Add a NOT NULL constraint on players.name:
    ///     migrator.registerMigrationWithDeferredForeignKeyCheck("AddNotNullCheckOnName") { db in
    ///         try db.create(table: "new_player") { t in
    ///             t.autoIncrementedPrimaryKey("id")
    ///             t.column("name", .text).notNull()
    ///         }
    ///         try db.execute(sql: "INSERT INTO new_player SELECT * FROM player")
    ///         try db.drop(table: "player")
    ///         try db.rename(table: "new_player", to: "player")
    ///     }
    ///
    /// While your migration code runs with disabled foreign key checks, those
    /// are re-enabled and checked at the end of the migration, regardless of
    /// eventual errors.
    ///
    /// - parameters:
    ///     - identifier: The migration identifier.
    ///     - block: The migration block that performs SQL statements.
    /// - precondition: No migration with the same same as already been registered.
    public mutating func registerMigrationWithDeferredForeignKeyCheck(
        _ identifier: String,
        migrate: @escaping (Database) throws -> Void)
    {
        registerMigration(Migration(identifier: identifier, disabledForeignKeyChecks: true, migrate: migrate))
    }
    #endif
    
    /// Iterate migrations in the same order as they were registered. If a
    /// migration has not yet been applied, its block is executed in
    /// a transaction.
    ///
    /// - parameter db: A DatabaseWriter (DatabaseQueue or DatabasePool) where
    ///   migrations should apply.
    /// - throws: An eventual error thrown by the registered migration blocks.
    public func migrate(_ writer: DatabaseWriter) throws {
        guard let lastMigration = migrations.last else {
            return
        }
        try migrate(writer, upTo: lastMigration.identifier)
    }
    
    /// Iterate migrations in the same order as they were registered, up to the
    /// provided target. If a migration has not yet been applied, its block is
    /// executed in a transaction.
    ///
    /// - parameter db: A DatabaseWriter (DatabaseQueue or DatabasePool) where
    ///   migrations should apply.
    /// - targetIdentifier: The identifier of a registered migration.
    /// - throws: An eventual error thrown by the registered migration blocks.
    public func migrate(_ writer: DatabaseWriter, upTo targetIdentifier: String) throws {
        if eraseDatabaseOnSchemaChange {
            // Create a temporary witness database, on disk, just in case
            // migrations would involve a lot of data.
            let witness = try DatabaseQueue(path: "", configuration: writer.configuration)
            
            // Erase database if we detect a change in the current schema.
            let (currentIdentifier, currentSchema) = try writer.writeWithoutTransaction { db -> (String?, SchemaInfo) in
                try setupMigrations(db)
                let identifiers = try appliedIdentifiers(db)
                let currentIdentifier = migrations
                    .reversed()
                    .first { identifiers.contains($0.identifier) }?
                    .identifier
                return try (currentIdentifier, db.schema())
            }
            
            if let currentIdentifier = currentIdentifier {
                let witnessSchema: SchemaInfo = try witness.writeWithoutTransaction { db in
                    try setupMigrations(db)
                    try runMigrations(db, upTo: currentIdentifier)
                    return try db.schema()
                }
                
                if currentSchema != witnessSchema {
                    try writer.erase()
                }
            }
        }
        
        // Migrate to target schema
        try writer.writeWithoutTransaction { db in
            try setupMigrations(db)
            try runMigrations(db, upTo: targetIdentifier)
        }
    }
    
    /// Returns the set of applied migration identifiers.
    public func appliedMigrations(in reader: DatabaseReader) throws -> Set<String> {
        return try reader.read { db in
            return try appliedIdentifiers(db)
        }
    }
    
    
    // MARK: - Non public
    
    private mutating func registerMigration(_ migration: Migration) {
        GRDBPrecondition(
            !migrations.map({ $0.identifier }).contains(migration.identifier),
            "already registered migration: \(String(reflecting: migration.identifier))")
        migrations.append(migration)
    }
    
    private func setupMigrations(_ db: Database) throws {
        try db.execute(sql: "CREATE TABLE IF NOT EXISTS grdb_migrations (identifier TEXT NOT NULL PRIMARY KEY)")
    }
    
    private func appliedIdentifiers(_ db: Database) throws -> Set<String> {
        let tableExists = try Bool.fetchOne(db, sql: """
            SELECT EXISTS (SELECT 1 FROM sqlite_master WHERE type='table' AND name='grdb_migrations')
            """)!
        guard tableExists else {
            return []
        }
        return try Set(String.fetchAll(db, sql: "SELECT identifier FROM grdb_migrations"))
    }
    
    private func runMigrations(_ db: Database, upTo targetIdentifier: String) throws {
        var prefixMigrations: [Migration] = []
        for migration in migrations {
            prefixMigrations.append(migration)
            if migration.identifier == targetIdentifier {
                break
            }
        }
        
        // targetIdentifier must refer to a registered migration
        GRDBPrecondition(
            prefixMigrations.last?.identifier == targetIdentifier,
            "undefined migration: \(String(reflecting: targetIdentifier))")
        
        // Subsequent migration must not be applied
        let appliedIdentifiers = try self.appliedIdentifiers(db)
        if prefixMigrations.count < migrations.count {
            let nextIdentifier = migrations[prefixMigrations.count].identifier
            GRDBPrecondition(
                !appliedIdentifiers.contains(nextIdentifier),
                "database is already migrated beyond migration \(String(reflecting: targetIdentifier))")
        }
        
        for migration in prefixMigrations where !appliedIdentifiers.contains(migration.identifier) {
            try migration.run(db)
        }
    }
}

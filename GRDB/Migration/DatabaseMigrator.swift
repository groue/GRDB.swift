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
///     // v1.0 database
///     migrator.registerMigration("createAuthors") { db in
///         try db.execute("""
///             CREATE TABLE authors (
///                 id INTEGER PRIMARY KEY,
///                 creationDate TEXT,
///                 name TEXT NOT NULL
///             )
///             """)
///     }
///
///     migrator.registerMigration("createBooks") { db in
///         try db.execute("""
///             CREATE TABLE books (
///                 uuid TEXT PRIMARY KEY,
///                 authorID INTEGER NOT NULL
///                          REFERENCES authors(id)
///                          ON DELETE CASCADE ON UPDATE CASCADE,
///                 title TEXT NOT NULL
///             )
///             """)
///     }
///
///     // v2.0 database
///     migrator.registerMigration("AddBirthYearToAuthors") { db in
///         try db.execute("ALTER TABLE authors ADD COLUMN birthYear INT")
///     }
///
///     try migrator.migrate(dbQueue)
public struct DatabaseMigrator {
    
    /// A new migrator.
    public init() {
    }
    
    /// Registers a migration.
    ///
    ///     migrator.registerMigration("createPlayers") { db in
    ///         try db.execute("""
    ///             CREATE TABLE players (
    ///                 id INTEGER PRIMARY KEY,
    ///                 creationDate TEXT,
    ///                 name TEXT NOT NULL
    ///             )
    ///             """)
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
        ///         try db.execute("""
        ///             CREATE TABLE new_players (id INTEGER PRIMARY KEY, name TEXT NOT NULL);
        ///             INSERT INTO new_players SELECT * FROM players;
        ///             DROP TABLE players;
        ///             ALTER TABLE new_players RENAME TO players;
        ///             """)
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
        public mutating func registerMigrationWithDeferredForeignKeyCheck(_ identifier: String, migrate: @escaping (Database) throws -> Void) {
            registerMigration(Migration(identifier: identifier, disabledForeignKeyChecks: true, migrate: migrate))
        }
    #else
        @available(iOS 8.2, OSX 10.10, *)
        /// Registers an advanced migration, as described at https://www.sqlite.org/lang_altertable.html#otheralter
        ///
        ///     // Add a NOT NULL constraint on players.name:
        ///     migrator.registerMigrationWithDeferredForeignKeyCheck("AddNotNullCheckOnName") { db in
        ///         try db.execute("""
        ///             CREATE TABLE new_players (id INTEGER PRIMARY KEY, name TEXT NOT NULL);
        ///             INSERT INTO new_players SELECT * FROM players;
        ///             DROP TABLE players;
        ///             ALTER TABLE new_players RENAME TO players;
        ///             """)
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
        public mutating func registerMigrationWithDeferredForeignKeyCheck(_ identifier: String, migrate: @escaping (Database) throws -> Void) {
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
        try writer.write { db in
            try setupMigrations(db)
            try runMigrations(db)
        }
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
        try writer.write { db in
            try setupMigrations(db)
            try runMigrations(db, upTo: targetIdentifier)
        }
    }
    
    
    // MARK: - Non public
    
    private var migrations: [Migration] = []
    
    private mutating func registerMigration(_ migration: Migration) {
        GRDBPrecondition(!migrations.map({ $0.identifier }).contains(migration.identifier), "already registered migration: \(String(reflecting: migration.identifier))")
        migrations.append(migration)
    }
    
    private func setupMigrations(_ db: Database) throws {
        try db.execute("CREATE TABLE IF NOT EXISTS grdb_migrations (identifier TEXT NOT NULL PRIMARY KEY)")
    }
    
    private func appliedIdentifiers(_ db: Database) throws -> Set<String> {
        return try Set(String.fetchAll(db, "SELECT identifier FROM grdb_migrations"))
    }
    
    private func runMigrations(_ db: Database) throws {
        let appliedIdentifiers = try self.appliedIdentifiers(db)
        for migration in migrations where !appliedIdentifiers.contains(migration.identifier) {
            try migration.run(db)
        }
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
        GRDBPrecondition(prefixMigrations.last?.identifier == targetIdentifier, "undefined migration: \(String(reflecting: targetIdentifier))")
        
        // Subsequent migration must not be applied
        let appliedIdentifiers = try self.appliedIdentifiers(db)
        if prefixMigrations.count < migrations.count {
            let nextIdentifier = migrations[prefixMigrations.count].identifier
            GRDBPrecondition(!appliedIdentifiers.contains(nextIdentifier), "database is already migrated beyond migration \(String(reflecting: targetIdentifier))")
        }
        
        for migration in prefixMigrations where !appliedIdentifiers.contains(migration.identifier) {
            try migration.run(db)
        }
    }
}

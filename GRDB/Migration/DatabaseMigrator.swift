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
        ///         try db.execute("INSERT INTO new_player SELECT * FROM player")
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
        public mutating func registerMigrationWithDeferredForeignKeyCheck(_ identifier: String, migrate: @escaping (Database) throws -> Void) {
            registerMigration(Migration(identifier: identifier, disabledForeignKeyChecks: true, migrate: migrate))
        }
    #else
        @available(iOS 8.2, OSX 10.10, *)
        /// Registers an advanced migration, as described at https://www.sqlite.org/lang_altertable.html#otheralter
        ///
        ///     // Add a NOT NULL constraint on players.name:
        ///     migrator.registerMigrationWithDeferredForeignKeyCheck("AddNotNullCheckOnName") { db in
        ///         try db.create(table: "new_player") { t in
        ///             t.autoIncrementedPrimaryKey("id")
        ///             t.column("name", .text).notNull()
        ///         }
        ///         try db.execute("INSERT INTO new_player SELECT * FROM player")
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
        try writer.writeWithoutTransaction { db in
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
        try writer.writeWithoutTransaction { db in
            try setupMigrations(db)
            try runMigrations(db, upTo: targetIdentifier)
        }
    }
    
    /// Returns the set of applied migration identifiers.
    public func appliedMigrations(in reader: DatabaseReader) throws -> Set<String> {
        return try reader.read { try appliedIdentifiers($0) }
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

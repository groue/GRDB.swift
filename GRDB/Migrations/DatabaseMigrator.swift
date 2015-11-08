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
///     migrator.registerMigration("createPersons") { db in
///         try db.execute(
///             "CREATE TABLE persons (" +
///                 "id INTEGER PRIMARY KEY, " +
///                 "creationDate TEXT, " +
///                 "name TEXT NOT NULL" +
///             ")")
///     }
///
///     migrator.registerMigration("createBooks") { db in
///         try db.execute(
///             "CREATE TABLE books (" +
///                 "uuid TEXT PRIMARY KEY, " +
///                 "ownerID INTEGER NOT NULL " +
///                 "        REFERENCES persons(id) " +
///                 "        ON DELETE CASCADE ON UPDATE CASCADE, " +
///                 "title TEXT NOT NULL" +
///             ")")
///     }
///
///     // v2.0 database
///     migrator.registerMigration("AddAgeToPersons") { db in
///         try db.execute("ALTER TABLE persons ADD COLUMN age INT")
///     }
///
///     try migrator.migrate(dbQueue)
public struct DatabaseMigrator {
    
    /// A new migrator.
    public init() {
    }
    
    /// Registers a migration.
    ///
    ///     migrator.registerMigration("createPersons") { db in
    ///         try db.execute(
    ///             "CREATE TABLE persons (" +
    ///                 "id INTEGER PRIMARY KEY, " +
    ///                 "creationDate TEXT, " +
    ///                 "name TEXT NOT NULL" +
    ///             ")")
    ///     }
    ///
    /// - parameter identifier: The migration identifier. It must be unique.
    /// - parameter block: The migration block that performs SQL statements.
    public mutating func registerMigration(identifier: String, _ block: (db: Database) throws -> Void) {
        registerMigration(Migration(identifier: identifier, disableForeignKeys: false, block: block))
    }
    
    /// Registers a migration with disabled foreign key checks.
    ///
    ///     migrator.registerMigrationWithDisabledForeignKeys("dropTableColumn") { db in
    ///         try db.execute("...")
    ///     }
    ///
    /// This technique, described at https://www.sqlite.org/lang_altertable.html#otheralter,
    /// allows you to make arbitrary changes to the database schema.
    ///
    /// If foreign key checks were enabled, they are enabled again after your
    /// migration code has run, regardless of eventual errors.
    ///
    /// - parameter identifier: The migration identifier. It must be unique.
    /// - parameter block: The migration block that performs SQL statements.
    public mutating func registerMigrationWithoutForeignKeyChecks(identifier: String, _ block: (db: Database) throws -> Void) {
        registerMigration(Migration(identifier: identifier, disableForeignKeys: true, block: block))
    }
    
    /// Iterate migrations in the same order as they were registered. If a
    /// migration has not yet been applied, its block is executed in
    /// a transaction.
    ///
    /// - parameter dbQueue: The Database Queue where migrations should apply.
    /// - throws: An eventual error thrown by the registered migration blocks.
    public func migrate(dbQueue: DatabaseQueue) throws {
        try dbQueue.inDatabase { db in
            try self.setupMigrations(db)
            try self.runMigrations(db)
        }
    }
    
    
    // MARK: - Non public
    
    private var migrations: [Migration] = []
    
    private mutating func registerMigration(migration: Migration) {
        guard migrations.map({ $0.identifier }).indexOf(migration.identifier) == nil else {
            fatalError("Already registered migration: \"\(migration.identifier)\"")
        }
        migrations.append(migration)
    }
    
    private func setupMigrations(db: Database) throws {
        try db.execute("CREATE TABLE IF NOT EXISTS grdb_migrations (identifier TEXT NOT NULL PRIMARY KEY)")
    }
    
    private func runMigrations(db: Database) throws {
        let appliedMigrationIdentifiers = String.fetchAll(db, "SELECT identifier FROM grdb_migrations")
        try migrations
            .filter { !appliedMigrationIdentifiers.contains($0.identifier) }
            .forEach { try $0.run(db) }
    }
}
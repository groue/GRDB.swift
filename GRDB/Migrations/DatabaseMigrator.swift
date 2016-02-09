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
    /// To perform advanced migrations, as described at https://www.sqlite.org/lang_altertable.html#otheralter,
    /// set the disabledForeignKeyChecks parameter to true:
    ///
    ///     // Add a NOT NULL constraint on persons.name:
    ///     migrator.registerMigration("AddNotNullCheckOnName", withDisabledForeignKeyChecks: true) { db in
    ///         try db.execute(
    ///             "CREATE TABLE new_persons (id INTEGER PRIMARY KEY, name TEXT NOT NULL);" +
    ///             "INSERT INTO new_persons SELECT * FROM persons;" +
    ///             "DROP TABLE persons;" +
    ///             "ALTER TABLE new_persons RENAME TO persons;")
    ///     }
    ///
    /// - parameters:
    ///     - identifier: The migration identifier.
    ///     - disabledForeignKeyChecks: If true, the migration is run with
    ///       disabled foreign key checks.
    ///     - block: The migration block that performs SQL statements.
    /// - precondition: No migration with the same same as already been registered.
    public mutating func registerMigration(identifier: String, withDisabledForeignKeyChecks disabledForeignKeyChecks: Bool = false, migrate: (db: Database) throws -> Void) {
        registerMigration(Migration(identifier: identifier, disabledForeignKeyChecks: disabledForeignKeyChecks, migrate: migrate))
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
        precondition(!migrations.map({ $0.identifier }).contains(migration.identifier), "already registered migration: \"\(migration.identifier)\"")
        migrations.append(migration)
    }
    
    private func setupMigrations(db: Database) throws {
        try db.execute("CREATE TABLE IF NOT EXISTS grdb_migrations (identifier TEXT NOT NULL PRIMARY KEY)")
    }
    
    private func runMigrations(db: Database) throws {
        let appliedIdentifiers = String.fetchAll(db, "SELECT identifier FROM grdb_migrations")
        for migration in migrations where !appliedIdentifiers.contains(migration.identifier) {
            try migration.run(db)
        }
    }
}
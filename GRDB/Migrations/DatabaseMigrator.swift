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
        try setupMigrations(dbQueue)
        try runMigrations(dbQueue)
    }
    
    
    // MARK: - Non public
    
    private struct Migration {
        let identifier: String
        let disableForeignKeys: Bool
        let block: (db: Database) throws -> Void
        
        func run(dbQueue: DatabaseQueue) throws {
            // When disableForeignKeys is true, we support database alterations
            // that are described at https://www.sqlite.org/lang_altertable.html#otheralter
            //
            // > The only schema altering commands directly supported by SQLite are the "rename
            // > table" and "add column" commands shown above. However, applications can make
            // > other arbitrary changes to the format of a table using a simple sequence of
            // > operations. The steps to make arbitrary changes to the schema design of some
            // > table X are as follows:
            // >
            // > 1. If foreign key constraints are enabled, disable them using
            // > PRAGMA foreign_keys=OFF.
            // >
            // > 2. Start a transaction.
            // >
            // > (...steps that can be implemented by the user...)
            // >
            // > 10. If foreign key constraints were originally enabled then run PRAGMA
            // > foreign_key_check to verify that the schema change did not break any foreign key
            // > constraints.
            // > 
            // > 11. Commit the transaction started in step 2.
            // > 
            // > 12. If foreign keys constraints were originally enabled, reenable them now.

            try dbQueue.inDatabase { db in
                let restoreForeignKeys: Bool
                if self.disableForeignKeys {
                    // Restore foreign keys if and only if they are active.
                    restoreForeignKeys = Bool.fetchOne(db, "PRAGMA foreign_keys")!
                } else {
                    restoreForeignKeys = false
                }
                
                // > 1. If foreign key constraints are enabled, disable them using
                // > PRAGMA foreign_keys=OFF.
                if restoreForeignKeys {
                    try db.execute("PRAGMA foreign_keys = OFF")
                }
                
                // > 12. If foreign keys constraints were originally enabled, reenable them now.
                defer {
                    if restoreForeignKeys {
                        try! db.execute("PRAGMA foreign_keys = ON")
                    }
                }
                
                // > 2. Start a transaction.
                try db.inTransaction(.Immediate) {
                    try self.block(db: db)
                    try db.execute("INSERT INTO grdb_migrations (identifier) VALUES (?)", arguments: [self.identifier])

                    // > 10. If foreign key constraints were originally enabled then run PRAGMA
                    // > foreign_key_check to verify that the schema change did not break any foreign key
                    // > constraints.
                    if restoreForeignKeys && Row.fetchOne(db, "PRAGMA foreign_key_check") != nil {
                        // https://www.sqlite.org/pragma.html#pragma_foreign_key_check
                        //
                        // PRAGMA foreign_key_check does not return an error,
                        // but the list of violated foreign key constraints.
                        //
                        // Let's turn any violation into an SQLITE_CONSTRAINT
                        // error, and rollback the transaction.
                        throw DatabaseError(code: SQLITE_CONSTRAINT, message: "FOREIGN KEY constraint failed", sql: "PRAGMA foreign_key_check", arguments: nil)
                    }
                    
                    // > 11. Commit the transaction started in step 2.
                    return .Commit
                }
            }
        }
    }
    
    private var migrations: [Migration] = []
    
    private mutating func registerMigration(migration: Migration) {
        guard migrations.map({ $0.identifier }).indexOf(migration.identifier) == nil else {
            fatalError("Already registered migration: \"\(migration.identifier)\"")
        }
        migrations.append(migration)
    }
    
    private func setupMigrations(dbQueue: DatabaseQueue) throws {
        try dbQueue.inDatabase { db in
            try db.execute(
                "CREATE TABLE IF NOT EXISTS grdb_migrations (identifier TEXT NOT NULL PRIMARY KEY)")
        }
    }
    
    private func runMigrations(dbQueue: DatabaseQueue) throws {
        let appliedMigrationIdentifiers = dbQueue.inDatabase { db in
            String.fetchAll(db, "SELECT identifier FROM grdb_migrations")
        }
        
        try migrations
            .filter { !appliedMigrationIdentifiers.contains($0.identifier) }
            .forEach { try $0.run(dbQueue) }
    }
}
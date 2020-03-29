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
    
    // MARK: - Registering Migrations
    
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
    
    /// Registers a migration.
    ///
    ///     migrator.registerMigrationWithDeferredForeignKeyCheck("createAuthors") { db in
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
    @available(*, deprecated, renamed: "registerMigration(_:migrate:)")
    public mutating func registerMigrationWithDeferredForeignKeyCheck(
        _ identifier: String,
        migrate: @escaping (Database) throws -> Void)
    {
        registerMigration(identifier, migrate: migrate)
    }
    
    // MARK: - Applying Migrations
    
    /// Iterate migrations in the same order as they were registered. If a
    /// migration has not yet been applied, its block is executed in
    /// a transaction.
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool)
    ///   where migrations should apply.
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
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool)
    ///   where migrations should apply.
    /// - parameter targetIdentifier: The identifier of a registered migration.
    /// - throws: An eventual error thrown by the registered migration blocks.
    public func migrate(_ writer: DatabaseWriter, upTo targetIdentifier: String) throws {
        try writer.barrierWriteWithoutTransaction { db in
            if eraseDatabaseOnSchemaChange {
                var needsErase = false
                try db.inTransaction(.deferred) {
                    let appliedIdentifiers = try self.appliedIdentifiers(db)
                    let knownIdentifiers = Set(migrations.map { $0.identifier })
                    if !appliedIdentifiers.isSubset(of: knownIdentifiers) {
                        // Database contains an unknown migration
                        needsErase = true
                        return .commit
                    }
                    
                    if let lastAppliedIdentifier = migrations.lazy
                        .map({ $0.identifier })
                        .last(where: { appliedIdentifiers.contains($0) })
                    {
                        // Database has been partially migrated.
                        //
                        // Create a temporary witness database (on disk, just in case
                        // migrations would involve a lot of data).
                        var witnessConfiguration = writer.configuration
                        witnessConfiguration.targetQueue = nil // Avoid deadlocks
                        let witness = try DatabaseQueue(path: "", configuration: witnessConfiguration)
                        
                        // Grab schema of migrated witness database
                        let witnessSchema: SchemaInfo = try witness.writeWithoutTransaction { db in
                            try runMigrations(db, upTo: lastAppliedIdentifier)
                            return try db.schema()
                        }
                        
                        // Erase database if we detect a schema change
                        if try db.schema() != witnessSchema {
                            needsErase = true
                            return .commit
                        }
                    }
                    
                    return .commit
                }
                
                if needsErase {
                    try db.erase()
                }
            }
            
            // Migrate to target schema
            try runMigrations(db, upTo: targetIdentifier)
        }
    }
    
    // MARK: - Querying Migrations
    
    /// Returns the set of applied migration identifiers.
    ///
    /// - parameter reader: A DatabaseReader (DatabaseQueue or DatabasePool).
    /// - throws: An eventual database error.
    @available(*, deprecated, message: "Wrap this method: reader.read(migrator.appliedMigrations) }")
    public func appliedMigrations(in reader: DatabaseReader) throws -> Set<String> {
        return try Set(reader.read(appliedMigrations))
    }
    
    /// Returns the applied migration identifiers, in the same order as
    /// registered migrations.
    ///
    /// - parameter db: A database connection.
    /// - throws: An eventual database error.
    public func appliedMigrations(_ db: Database) throws -> [String] {
        let appliedIdentifiers = try self.appliedIdentifiers(db)
        return migrations.map { $0.identifier }.filter { appliedIdentifiers.contains($0) }
    }
    
    /// Returns the identifiers of completed migrations, of which all previous
    /// migrations have been applied.
    ///
    /// - parameter db: A database connection.
    /// - throws: An eventual database error.
    public func completedMigrations(_ db: Database) throws -> [String] {
        let appliedIdentifiers = try appliedMigrations(db)
        let knownIdentifiers = migrations.map { $0.identifier }
        return Array(zip(appliedIdentifiers, knownIdentifiers)
            .prefix(while: { $0 == $1 })
            .map { $0.0 })
    }
    
    /// Returns true if all migrations are applied.
    ///
    /// - parameter reader: A DatabaseReader (DatabaseQueue or DatabasePool).
    /// - throws: An eventual database error.
    @available(*, deprecated, message: "Wrap this method: reader.read(migrator.hasCompletedMigrations) }")
    public func hasCompletedMigrations(in reader: DatabaseReader) throws -> Bool {
        return try reader.read(hasCompletedMigrations)
    }
    
    /// Returns true if all migrations are applied.
    ///
    /// - parameter db: A database connection.
    /// - throws: An eventual database error.
    public func hasCompletedMigrations(_ db: Database) throws -> Bool {
        return try completedMigrations(db).last == migrations.last?.identifier
    }
    
    /// Returns true if all migrations up to the provided target are applied,
    /// and maybe further.
    ///
    /// - parameter reader: A DatabaseReader (DatabaseQueue or DatabasePool).
    /// - parameter targetIdentifier: The identifier of a registered migration.
    /// - throws: An eventual database error.
    @available(*, deprecated, message: "Prefer reader.read(migrator.completedMigrations).contains(targetIdentifier)")
    public func hasCompletedMigrations(in reader: DatabaseReader, through targetIdentifier: String) throws -> Bool {
        return try reader.read(completedMigrations).contains(targetIdentifier)
    }
    
    /// Returns the identifier of the last migration for which all predecessors
    /// have been applied.
    ///
    /// - parameter reader: A DatabaseReader (DatabaseQueue or DatabasePool).
    /// - returns: An eventual migration identifier.
    /// - throws: An eventual database error.
    @available(*, deprecated, message: "Prefer reader.read(migrator.completedMigrations).last")
    public func lastCompletedMigration(in reader: DatabaseReader) throws -> String? {
        return try reader.read(completedMigrations).last
    }
    
    // MARK: - Non public
    
    private mutating func registerMigration(_ migration: Migration) {
        GRDBPrecondition(
            !migrations.map({ $0.identifier }).contains(migration.identifier),
            "already registered migration: \(String(reflecting: migration.identifier))")
        migrations.append(migration)
    }
    
    /// Returns the applied migration identifiers, even unregistered ones
    ///
    /// - parameter db: A database connection.
    /// - throws: An eventual database error.
    public func appliedIdentifiers(_ db: Database) throws -> Set<String> {
        do {
            return try Set(String.fetchCursor(db, sql: "SELECT identifier FROM grdb_migrations"))
        } catch {
            // Rethrow if we can't prove grdb_migrations does not exist yet
            if (try? !db.tableExists("grdb_migrations")) ?? false {
                return []
            }
            throw error
        }
    }
    
    /// Returns unapplied migration identifier,
    private func unappliedMigrations(upTo targetIdentifier: String, appliedIdentifiers: [String]) -> [Migration] {
        var expectedMigrations: [Migration] = []
        for migration in migrations {
            expectedMigrations.append(migration)
            if migration.identifier == targetIdentifier {
                break
            }
        }
        
        // targetIdentifier must refer to a registered migration
        GRDBPrecondition(
            expectedMigrations.last?.identifier == targetIdentifier,
            "undefined migration: \(String(reflecting: targetIdentifier))")
        
        return expectedMigrations.filter { !appliedIdentifiers.contains($0.identifier) }
    }
    
    private func runMigrations(_ db: Database, upTo targetIdentifier: String) throws {
        let appliedIdentifiers = try self.appliedMigrations(db)
        
        // Subsequent migration must not be applied
        if let targetIndex = migrations.firstIndex(where: { $0.identifier == targetIdentifier }),
            let lastAppliedIdentifier = appliedIdentifiers.last,
            let lastAppliedIndex = migrations.firstIndex(where: { $0.identifier == lastAppliedIdentifier }),
            targetIndex < lastAppliedIndex
        {
            fatalError("database is already migrated beyond migration \(String(reflecting: targetIdentifier))")
        }
        
        let unappliedMigrations = self.unappliedMigrations(
            upTo: targetIdentifier,
            appliedIdentifiers: appliedIdentifiers)
        
        if unappliedMigrations.isEmpty {
            return
        }
        
        try db.execute(sql: "CREATE TABLE IF NOT EXISTS grdb_migrations (identifier TEXT NOT NULL PRIMARY KEY)")
        for migration in unappliedMigrations {
            try migration.run(db)
        }
    }
}

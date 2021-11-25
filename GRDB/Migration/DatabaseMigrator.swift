#if canImport(Combine)
import Combine
#endif
import Foundation

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
    /// Controls how migrations handle foreign keys constraints.
    public enum ForeignKeyChecks {
        /// The migration runs with disabled foreign keys, until foreign keys
        /// are checked right before changes are committed on disk.
        ///
        /// These deferred checks are not executed if the migrator comes
        /// from `disablingDeferredForeignKeyChecks()`.
        ///
        /// Deferred foreign key checks are necessary for migrations that
        /// perform schema changes as described in
        /// <https://www.sqlite.org/lang_altertable.html#making_other_kinds_of_table_schema_changes>
        case deferred
        
        /// The migration runs for foreign keys on.
        ///
        /// Immediate foreign key checks are not compatible with migrations that
        /// perform schema changes as described in
        /// <https://www.sqlite.org/lang_altertable.html#making_other_kinds_of_table_schema_changes>
        case immediate
    }
    
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
    private var defersForeignKeyChecks = true
    private var _migrations: [Migration] = []
    
    /// A new migrator.
    public init() {
    }
    
    // MARK: - Disabling Foreign Key Checks
    
    /// Returns a migrator that will not perform deferred foreign key checks in
    /// all newly registered migrations.
    ///
    /// The returned migrator is _unsafe_, because it no longer guarantees the
    /// integrity of the database. It is your responsibility to register
    /// migrations that do not break foreign key constraints.
    ///
    /// Running migrations without foreign key checks can improve migration
    /// performance on huge databases.
    ///
    /// Example:
    ///
    ///     var migrator = DatabaseMigrator()
    ///     migrator.registerMigration("A") { db in
    ///         // Runs with deferred foreign key checks
    ///     }
    ///     migrator.registerMigration("B", foreignKeyChecks: .immediate) { db in
    ///         // Runs with immediate foreign key checks
    ///     }
    ///
    ///     migrator = migrator.disablingDeferredForeignKeyChecks()
    ///     migrator.registerMigration("C") { db in
    ///         // Runs with disabled foreign key checks
    ///     }
    ///     migrator.registerMigration("D", foreignKeyChecks: .immediate) { db in
    ///         // Runs with immediate foreign key checks
    ///     }
    ///
    /// - warning: Before using this unsafe method, try to run your migrations with
    /// `.immediate` foreign key checks, if possible. This may enhance migration
    /// performances, while preserving the database integrity guarantee.
    public func disablingDeferredForeignKeyChecks() -> DatabaseMigrator {
        with { $0.defersForeignKeyChecks = false }
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
    ///     - foreignKeyChecks: This parameter is ignored if the database has
    ///       not enabled foreign keys.
    ///
    ///       The default `.deferred` checks have the migration run with
    ///       disabled foreign keys, until foreign keys are checked right before
    ///       changes are committed on disk. These deferred checks are not
    ///       executed if the migrator comes
    ///       from `disablingDeferredForeignKeyChecks()`.
    ///
    ///       The `.immediate` checks have the migration run with foreign
    ///       keys enabled.
    ///
    ///       Only use `.immediate` if you are sure that the migration does not
    ///       perform schema changes described in
    ///       <https://www.sqlite.org/lang_altertable.html#making_other_kinds_of_table_schema_changes>
    ///     - block: The migration block that performs SQL statements.
    /// - precondition: No migration with the same same as already been registered.
    public mutating func registerMigration(
        _ identifier: String,
        foreignKeyChecks: ForeignKeyChecks = .deferred,
        migrate: @escaping (Database) throws -> Void)
    {
        let migrationChecks: Migration.ForeignKeyChecks
        switch foreignKeyChecks {
        case .deferred:
            if defersForeignKeyChecks {
                migrationChecks = .deferred
            } else {
                migrationChecks = .disabled
            }
        case .immediate:
            migrationChecks = .immediate
        }
        registerMigration(Migration(identifier: identifier, foreignKeyChecks: migrationChecks, migrate: migrate))
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
        guard let lastMigration = _migrations.last else {
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
            try migrate(db, upTo: targetIdentifier)
        }
    }
    
    /// Iterate migrations in the same order as they were registered. If a
    /// migration has not yet been applied, its block is executed in
    /// a transaction.
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool)
    ///   where migrations should apply.
    /// - parameter completion: A closure that is called in a protected dispatch
    ///   queue that can write in the database, with the eventual
    ///   migration error.
    public func asyncMigrate(
        _ writer: DatabaseWriter,
        completion: @escaping (Database, Error?) -> Void)
    {
        writer.asyncBarrierWriteWithoutTransaction { db in
            do {
                if let lastMigration = self._migrations.last {
                    try self.migrate(db, upTo: lastMigration.identifier)
                }
                completion(db, nil)
            } catch {
                completion(db, error)
            }
        }
    }
    
    // MARK: - Querying Migrations
    
    /// The list of registered migration identifiers, in the same order as they
    /// have been registered.
    public var migrations: [String] {
        _migrations.map(\.identifier)
    }
    
    /// Returns the identifiers of registered and applied migrations, in the
    /// order of registration.
    ///
    /// See also `appliedIdentifiers(_:)`.
    ///
    /// - parameter db: A database connection.
    /// - throws: An eventual database error.
    public func appliedMigrations(_ db: Database) throws -> [String] {
        let appliedIdentifiers = try self.appliedIdentifiers(db)
        return _migrations.map { $0.identifier }.filter { appliedIdentifiers.contains($0) }
    }
    
    /// Returns the applied migration identifiers, even unregistered ones.
    ///
    /// See also `appliedMigrations(_:)`.
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
    
    /// Returns the identifiers of completed migrations, of which all previous
    /// migrations have been applied.
    ///
    /// - parameter db: A database connection.
    /// - throws: An eventual database error.
    public func completedMigrations(_ db: Database) throws -> [String] {
        let appliedIdentifiers = try appliedMigrations(db)
        let knownIdentifiers = _migrations.map(\.identifier)
        return zip(appliedIdentifiers, knownIdentifiers)
            .prefix(while: { (applied: String, known: String) in applied == known })
            .map { $0.0 }
    }
    
    /// Returns true if all migrations are applied.
    ///
    /// - parameter db: A database connection.
    /// - throws: An eventual database error.
    public func hasCompletedMigrations(_ db: Database) throws -> Bool {
        try completedMigrations(db).last == _migrations.last?.identifier
    }
    
    /// Returns whether database contains unknown migration
    /// identifiers, which is likely the sign that the database
    /// has migrated further than the migrator itself supports.
    ///
    /// - parameter db: A database connection.
    /// - throws: An eventual database error.
    public func hasBeenSuperseded(_ db: Database) throws -> Bool {
        let appliedIdentifiers = try self.appliedIdentifiers(db)
        let knownIdentifiers = _migrations.map(\.identifier)
        return appliedIdentifiers.contains { !knownIdentifiers.contains($0) }
    }
    
    // MARK: - Non public
    
    private mutating func registerMigration(_ migration: Migration) {
        GRDBPrecondition(
            !_migrations.map({ $0.identifier }).contains(migration.identifier),
            "already registered migration: \(String(reflecting: migration.identifier))")
        _migrations.append(migration)
    }
    
    /// Returns unapplied migration identifier,
    private func unappliedMigrations(upTo targetIdentifier: String, appliedIdentifiers: [String]) -> [Migration] {
        var expectedMigrations: [Migration] = []
        for migration in _migrations {
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
        try db.execute(sql: "CREATE TABLE IF NOT EXISTS grdb_migrations (identifier TEXT NOT NULL PRIMARY KEY)")
        let appliedIdentifiers = try self.appliedMigrations(db)
        
        // Subsequent migration must not be applied
        if let targetIndex = _migrations.firstIndex(where: { $0.identifier == targetIdentifier }),
           let lastAppliedIdentifier = appliedIdentifiers.last,
           let lastAppliedIndex = _migrations.firstIndex(where: { $0.identifier == lastAppliedIdentifier }),
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
        
        for migration in unappliedMigrations {
            try migration.run(db)
        }
    }
    
    private func migrate(_ db: Database, upTo targetIdentifier: String) throws {
        if eraseDatabaseOnSchemaChange {
            var needsErase = false
            try db.inTransaction(.deferred) {
                let appliedIdentifiers = try self.appliedIdentifiers(db)
                let knownIdentifiers = Set(_migrations.map { $0.identifier })
                if !appliedIdentifiers.isSubset(of: knownIdentifiers) {
                    // Database contains an unknown migration
                    needsErase = true
                    return .commit
                }
                
                if let lastAppliedIdentifier = _migrations
                    .map(\.identifier)
                    .last(where: { appliedIdentifiers.contains($0) })
                {
                    // Some migrations were already applied.
                    //
                    // Let's migrate a temporary database up to the same
                    // level, and compare the database schemas. If they
                    // differ, we'll erase the database.
                    let tmpSchema: SchemaInfo = try {
                        // Make sure the temporary database is configured
                        // just as the migrated database
                        var tmpConfig = db.configuration
                        tmpConfig.targetQueue = nil // Avoid deadlocks
                        tmpConfig.label = "GRDB.DatabaseMigrator.temporary"
                        
                        // Create the temporary database on disk, just in
                        // case migrations would involve a lot of data.
                        //
                        // SQLite supports temporary on-disk databases, but
                        // those are not guaranteed to accept the
                        // preparation functions provided by the user.
                        //
                        // See https://github.com/groue/GRDB.swift/issues/931
                        // for an issue created by such databases.
                        //
                        // So let's create a "regular" temporary database:
                        let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory())
                            .appendingPathComponent(ProcessInfo().globallyUniqueString)
                        defer {
                            try? FileManager().removeItem(at: tmpURL)
                        }
                        let tmpDatabase = try DatabaseQueue(path: tmpURL.path, configuration: tmpConfig)
                        return try tmpDatabase.writeWithoutTransaction { db in
                            try runMigrations(db, upTo: lastAppliedIdentifier)
                            return try db.schema(.main)
                        }
                    }()
                    
                    if try db.schema(.main) != tmpSchema {
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

extension DatabaseMigrator: Refinable { }

#if canImport(Combine)
extension DatabaseMigrator {
    // MARK: - Publishing Migrations
    
    /// Returns a Publisher that asynchronously migrates a database.
    ///
    ///     let migrator: DatabaseMigrator = ...
    ///     let dbQueue: DatabaseQueue = ...
    ///     let publisher = migrator.migratePublisher(dbQueue)
    ///
    /// It completes on the main dispatch queue.
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool)
    ///   where migrations should apply.
    @available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *)
    public func migratePublisher(_ writer: DatabaseWriter) -> DatabasePublishers.Migrate {
        migratePublisher(writer, receiveOn: DispatchQueue.main)
    }
    
    /// Returns a Publisher that asynchronously migrates a database.
    ///
    ///     let migrator: DatabaseMigrator = ...
    ///     let dbQueue: DatabaseQueue = ...
    ///     let publisher = migrator.migratePublisher(dbQueue, receiveOn: DispatchQueue.global())
    ///
    /// It completes on `scheduler`.
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool)
    ///   where migrations should apply.
    /// - parameter scheduler: A Combine Scheduler.
    @available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *)
    public func migratePublisher<S>(_ writer: DatabaseWriter, receiveOn scheduler: S)
    -> DatabasePublishers.Migrate
    where S: Scheduler
    {
        DatabasePublishers.Migrate(
            upstream: OnDemandFuture { promise in
                self.asyncMigrate(writer) { _, error in
                    if let error = error {
                        promise(.failure(error))
                    } else {
                        promise(.success(()))
                    }
                }
            }
            .eraseToAnyPublisher()
            .receiveValues(on: scheduler)
            .eraseToAnyPublisher()
        )
    }
}

@available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension DatabasePublishers {
    /// A publisher that migrates a database. It publishes exactly
    /// one element, or an error.
    ///
    /// See `DatabaseMigrator.migratePublisher(_:receiveOn:)`.
    public struct Migrate: Publisher {
        public typealias Output = Void
        public typealias Failure = Error
        
        fileprivate let upstream: AnyPublisher<Void, Error>
        
        public func receive<S>(subscriber: S) where S: Subscriber, Self.Failure == S.Failure, Self.Output == S.Input {
            upstream.receive(subscriber: subscriber)
        }
    }
}
#endif

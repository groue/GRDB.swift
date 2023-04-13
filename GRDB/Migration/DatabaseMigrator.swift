#if canImport(Combine)
import Combine
#endif
import Foundation

// TODO: provide concurrent apis for migrations that run @Sendable closures.
/// A `DatabaseMigrator` registers and applies database migrations.
///
/// For an overview of database migrations and `DatabaseMigrator` usage,
/// see <doc:Migrations>.
///
/// ## Topics
///
/// ### Creating a DatabaseMigrator
///
/// - ``init()``
///
/// ### Registering Migrations
///
/// - ``registerMigration(_:foreignKeyChecks:migrate:)``
/// - ``ForeignKeyChecks``
///
/// ### Configuring a DatabaseMigrator
///
/// - ``eraseDatabaseOnSchemaChange``
/// - ``disablingDeferredForeignKeyChecks()``
///
/// ### Migrating a Database
///
/// - ``asyncMigrate(_:completion:)``
/// - ``migrate(_:)``
/// - ``migrate(_:upTo:)``
/// - ``migratePublisher(_:receiveOn:)``
///
/// ### Querying Migrations
///
/// - ``migrations``
/// - ``appliedIdentifiers(_:)``
/// - ``appliedMigrations(_:)``
/// - ``completedMigrations(_:)``
/// - ``hasBeenSuperseded(_:)``
/// - ``hasCompletedMigrations(_:)``
public struct DatabaseMigrator {
    /// Controls how a migration handle foreign keys constraints.
    public enum ForeignKeyChecks {
        /// The migration runs with disabled foreign keys.
        ///
        /// Foreign keys are checked right before changes are committed on disk,
        /// unless the `DatabaseMigrator` is the result of
        /// ``DatabaseMigrator/disablingDeferredForeignKeyChecks()``.
        ///
        /// In this case, you can perform your own deferred foreign key checks
        /// with ``Database/checkForeignKeys(in:)`` or
        /// ``Database/checkForeignKeys()``:
        /// 
        /// ```swift
        /// migrator = migrator.disablingDeferredForeignKeyChecks()
        /// migrator.registerMigration("Partially checked migration") { db in
        ///     ...
        ///
        ///     // Throws an error and stops migrations if there exists a
        ///     // foreign key violation in the 'book' table.
        ///     try db.checkForeignKeys(in: "book")
        /// }
        /// ```
        case deferred
        
        /// The migration runs with enabled foreign keys.
        ///
        /// Immediate foreign key checks are NOT compatible with migrations that
        /// recreate tables as described
        /// in <doc:Migrations#Defining-the-Database-Schema-from-a-Migration>.
        case immediate
    }
    
    /// A boolean value indicating whether the migrator recreates the whole
    /// database from scratch if it detects a change in the definition
    /// of migrations.
    ///
    /// - warning: This flag can destroy your precious users' data!
    ///
    /// When true, the database migrator wipes out the full database content,
    /// and runs all migrations from the start, if one of those conditions
    /// is met:
    ///
    /// - A migration has been removed, or renamed.
    /// - A schema change is detected. A schema change is any difference in
    ///   the `sqlite_master` table, which contains the SQL used to create
    ///   database tables, indexes, triggers, and views.
    ///
    /// This flag is useful during application development: you are still
    /// designing migrations, and the schema changes often.
    ///
    /// It is recommended to not ship it in the distributed application, in
    /// order to avoid undesired data loss. Use the `DEBUG`
    /// compilation condition:
    ///
    /// ```swift
    /// var migrator = DatabaseMigrator()
    /// #if DEBUG
    /// // Speed up development by nuking the database when migrations change
    /// migrator.eraseDatabaseOnSchemaChange = true
    /// #endif
    /// ```
    public var eraseDatabaseOnSchemaChange = false
    private var defersForeignKeyChecks = true
    private var _migrations: [Migration] = []
    
    /// A new migrator.
    public init() {
    }
    
    // MARK: - Disabling Foreign Key Checks
    
    /// Returns a migrator that disables foreign key checks in all newly
    /// registered migrations.
    ///
    /// The returned migrator is _unsafe_, because it no longer guarantees the
    /// integrity of the database. It is now _your_ responsibility to register
    /// migrations that do not break foreign key constraints. See
    /// ``Database/checkForeignKeys()`` and ``Database/checkForeignKeys(in:)``.
    ///
    /// Running migrations without foreign key checks can improve migration
    /// performance on huge databases.
    ///
    /// Example:
    ///
    /// ```swift
    /// var migrator = DatabaseMigrator()
    /// migrator.registerMigration("A") { db in
    ///     // Runs with deferred foreign key checks
    /// }
    /// migrator.registerMigration("B", foreignKeyChecks: .immediate) { db in
    ///     // Runs with immediate foreign key checks
    /// }
    ///
    /// migrator = migrator.disablingDeferredForeignKeyChecks()
    /// migrator.registerMigration("C") { db in
    ///     // Runs without foreign key checks
    /// }
    /// migrator.registerMigration("D", foreignKeyChecks: .immediate) { db in
    ///     // Runs with immediate foreign key checks
    /// }
    /// ```
    ///
    /// - warning: Before using this unsafe method, try to register your
    ///   migrations with the `foreignKeyChecks: .immediate` option, _if
    ///   possible_, as in the example above. This will enhance migration
    ///   performances, while preserving the database integrity guarantee.
    public func disablingDeferredForeignKeyChecks() -> DatabaseMigrator {
        with { $0.defersForeignKeyChecks = false }
    }
    
    // MARK: - Registering Migrations
    
    /// Registers a migration.
    ///
    /// The registered migration is appended to the list of migrations to run:
    /// it will execute after previously registered migrations, and before
    /// migrations that are registered later.
    ///
    /// For example:
    ///
    /// ```swift
    /// migrator.registerMigration("createAuthors") { db in
    ///     try db.create(table: "author") { t in
    ///         t.autoIncrementedPrimaryKey("id")
    ///         t.column("creationDate", .datetime)
    ///         t.column("name", .text).notNull()
    ///     }
    /// }
    /// ```
    ///
    /// Database operations are wrapped in a transaction. If they throw an
    /// error, the transaction is rollbacked, migrations are aborted, and the
    /// error is thrown by the migrating method.
    ///
    /// By default, database operations run with disabled foreign keys, and
    /// foreign keys are checked right before changes are committed on disk. You
    /// can control this behavior with the `foreignKeyChecks` argument.
    ///
    /// Database operations run in the writer dispatch queue, serialized
    /// with all database updates performed by the migrated `DatabaseWriter`.
    ///
    /// The `Database` argument to `migrate` is valid only during the execution
    /// of the closure. Do not store or return the database connection for
    /// later use.
    ///
    /// - parameters:
    ///     - identifier: The migration identifier.
    ///     - foreignKeyChecks: This parameter is ignored if the database
    ///       ``Configuration`` has disabled foreign keys.
    ///
    ///       The default `.deferred` checks have the migration run with
    ///       disabled foreign keys, until foreign keys are checked right before
    ///       changes are committed on disk. These deferred checks are not
    ///       executed if the migrator is the result of
    ///       ``disablingDeferredForeignKeyChecks()``.
    ///
    ///       The `.immediate` checks have the migration run with foreign
    ///       keys enabled. Make sure you only use `.immediate` if the migration
    ///       does not perform schema changes described in
    ///       <https://www.sqlite.org/lang_altertable.html#making_other_kinds_of_table_schema_changes>
    ///     - migrate: A closure that performs database operations.
    /// - precondition: No migration with the same identifier as already
    ///   been registered.
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
    
    /// Runs all unapplied migrations, in the same order as they
    /// were registered.
    ///
    /// - parameter writer: A DatabaseWriter.
    /// - throws: The error thrown by the first failed migration.
    public func migrate(_ writer: some DatabaseWriter) throws {
        guard let lastMigration = _migrations.last else {
            return
        }
        try migrate(writer, upTo: lastMigration.identifier)
    }
    
    /// Runs all unapplied migrations, in the same order as they
    /// were registered, up to the target migration identifier (included).
    ///
    /// - precondition: `targetIdentifier` is the identifier of a
    ///   registered migration.
    ///
    /// - precondition: The database has not already been migrated beyond the
    ///   target migration.
    ///
    /// - parameter writer: A DatabaseWriter.
    /// - parameter targetIdentifier: A migration identifier.
    /// - throws: The error thrown by the first failed migration.
    public func migrate(_ writer: some DatabaseWriter, upTo targetIdentifier: String) throws {
        try writer.barrierWriteWithoutTransaction { db in
            try migrate(db, upTo: targetIdentifier)
        }
    }
    
    /// Schedules unapplied migrations for execution, and returns immediately.
    ///
    /// - parameter writer: A DatabaseWriter.
    /// - parameter completion: A function that can access the database. Its
    ///   argument is a `Result` that provides a connection to the migrated
    ///   database, or the failure that prevented the migrations
    ///   from succeeding.
    public func asyncMigrate(
        _ writer: some DatabaseWriter,
        completion: @escaping (Result<Database, Error>) -> Void)
    {
        writer.asyncBarrierWriteWithoutTransaction { dbResult in
            do {
                let db = try dbResult.get()
                if let lastMigration = self._migrations.last {
                    try self.migrate(db, upTo: lastMigration.identifier)
                }
                completion(.success(db))
            } catch {
                completion(.failure(error))
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
    /// - parameter db: A database connection.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func appliedMigrations(_ db: Database) throws -> [String] {
        let appliedIdentifiers = try self.appliedIdentifiers(db)
        return _migrations.map { $0.identifier }.filter { appliedIdentifiers.contains($0) }
    }
    
    /// Returns the applied migration identifiers, even unregistered ones.
    ///
    /// - parameter db: A database connection.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func appliedIdentifiers(_ db: Database) throws -> Set<String> {
        do {
            return try String.fetchSet(db, sql: "SELECT identifier FROM grdb_migrations")
        } catch {
            // Rethrow if we can't prove grdb_migrations does not exist yet
            if (try? !db.tableExists("grdb_migrations")) ?? false {
                return []
            }
            throw error
        }
    }
    
    /// Returns the identifiers of registered and completed migrations, in the
    /// order of registration.
    ///
    /// A migration is completed if and only if all previous migrations have
    /// been applied.
    ///
    /// - parameter db: A database connection.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func completedMigrations(_ db: Database) throws -> [String] {
        let appliedIdentifiers = try appliedMigrations(db)
        let knownIdentifiers = _migrations.map(\.identifier)
        return zip(appliedIdentifiers, knownIdentifiers)
            .prefix(while: { (applied: String, known: String) in applied == known })
            .map { $0.0 }
    }
    
    /// A boolean value indicating whether all registered migrations, and only
    /// registered migrations, have been applied.
    ///
    /// - parameter db: A database connection.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func hasCompletedMigrations(_ db: Database) throws -> Bool {
        try completedMigrations(db).last == _migrations.last?.identifier
    }
    
    /// A boolean value indicating whether the database refers to
    /// unregistered migrations.
    ///
    /// When the result is true, the database has likely been migrated by a
    /// more recent migrator.
    ///
    /// - parameter db: A database connection.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
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
                    let tmpSchema = try {
                        // Make sure the temporary database is configured
                        // just as the migrated database
                        var tmpConfig = db.configuration
                        tmpConfig.targetQueue = nil // Avoid deadlocks
                        tmpConfig.writeTargetQueue = nil // Avoid deadlocks
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
                    
                    // Only compare user objects
                    func isUserObject(_ object: SchemaObject) -> Bool {
                        !Database.isSQLiteInternalTable(object.name) && !Database.isGRDBInternalTable(object.name)
                    }
                    let tmpUserSchema = tmpSchema.filter(isUserObject)
                    let userSchema = try db.schema(.main).filter(isUserObject)
                    if userSchema != tmpUserSchema {
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
    /// The database is not accessed until subscription. Value and completion
    /// are published on `scheduler` (the main dispatch queue by default).
    ///
    /// - parameter writer: A DatabaseWriter.
    ///   where migrations should apply.
    /// - parameter scheduler: A Combine Scheduler.
    @available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
    public func migratePublisher(
        _ writer: some DatabaseWriter,
        receiveOn scheduler: some Scheduler = DispatchQueue.main)
    -> DatabasePublishers.Migrate
    {
        DatabasePublishers.Migrate(
            upstream: OnDemandFuture { promise in
                self.asyncMigrate(writer) { dbResult in
                    promise(dbResult.map { _ in })
                }
            }
            .receiveValues(on: scheduler)
            .eraseToAnyPublisher()
        )
    }
}

@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
extension DatabasePublishers {
    /// A publisher that migrates a database.
    ///
    /// `Migrate` publishes exactly one element, or an error.
    ///
    /// You build such a publisher from ``DatabaseMigrator``.
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

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
/// - ``registerMigration(_:foreignKeyChecks:merging:migrate:)``
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
///
/// ### Detecting Schema Changes
///
/// - ``hasSchemaChanges(_:)``
public struct DatabaseMigrator: Sendable {
    /// Controls how a migration handle foreign keys constraints.
    public enum ForeignKeyChecks: Sendable {
        /// The migration runs with disabled foreign keys.
        ///
        /// Foreign keys are checked right before changes are committed on disk,
        /// unless the `DatabaseMigrator` is the result of
        /// ``DatabaseMigrator/disablingDeferredForeignKeyChecks()``.
        ///
        /// In this case, you can perform your own deferred foreign key checks
        /// with ``Database/checkForeignKeys(in:in:)`` or
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
    ///
    /// See also ``hasSchemaChanges(_:)``.
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
    /// ``Database/checkForeignKeys()`` and ``Database/checkForeignKeys(in:in:)``.
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
    /// The registered migration is appended to the list of migrations. It
    /// will execute after previously registered migrations.
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
        migrate: @escaping @Sendable (Database) throws -> Void)
    {
        registerMigration(identifier, foreignKeyChecks: foreignKeyChecks, merging: []) { db, ids in
            precondition(ids.isEmpty)
            try migrate(db)
        }
    }
    
    /// Registers a merged migration.
    ///
    /// Like migrations registered with ``registerMigration(_:foreignKeyChecks:migrate:)``,
    /// the merged migration is appended to the list of migrations. It
    /// will execute after previously registered migrations.
    ///
    /// A merged migration merges and replaces a set of migrations defined
    /// in a previous version of the application. For example, to merge the
    /// migrations "v1", "v2" and "v3", redefine the "v3" migration so that
    /// it merges "v1" and "v2", as in the example below.
    ///
    /// The second argument of the `migrate` closure is the subset of merged
    /// migrations that have already been applied when the merged
    /// migration runs.
    ///
    /// ```swift
    /// // Old code
    /// migrator.registerMigration("v1") { db in
    ///     // Apply schema version 1
    /// }
    /// migrator.registerMigration("v2") { db in
    ///     // Apply schema version 2
    /// }
    /// migrator.registerMigration("v3") { db in
    ///     // Apply schema version 3
    /// }
    ///
    /// // New code:
    /// // - Migrations v1 and v2 are deleted.
    /// // - Migration v3 is redefined and merges v1 and v2:
    /// migrator.registerMigration("v3", merging: ["v1", "v2"]) { db, appliedIDs in
    ///     if !appliedIDs.contains("v1") {
    ///         // Apply schema version 1
    ///     }
    ///     if !appliedIDs.contains("v2") {
    ///         // Apply schema version 2
    ///     }
    ///     // Apply schema version 3
    /// }
    /// ```
    ///
    /// In the above sample code, the merged migration is named like the
    /// last one of the merged set. You can also give it a brand new name,
    /// as in the alternative below. Notice the different logic in the
    /// migration code.
    ///
    /// **In all cases avoid naming the merged migration like the first
    /// elements in the merged set** (`v1` or `v2` in our example).
    ///
    /// ```swift
    /// // Alternative new code:
    /// // - Migrations v1, v2 and v3 are deleted.
    /// // - The new migration v3-new merges v1, v2 and v3:
    /// migrator.registerMigration("v3-new", merging: ["v1", "v2", "v3"]) { db, appliedIDs in
    ///     if !appliedIDs.contains("v1") {
    ///         // Apply schema version 1
    ///     }
    ///     if !appliedIDs.contains("v2") {
    ///         // Apply schema version 2
    ///     }
    ///     if !appliedIDs.contains("v3") {
    ///         // Apply schema version 3
    ///     }
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - identifier: The migration identifier.
    ///     - mergedIdentifiers: A set of previous migration identifiers
    ///       that are merged in this migration.
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
    ///     - migrate: A closure that performs database operations. The
    ///       first argument is a database connection. The second argument
    ///       is the set of previous migrations that has been applied when
    ///       the merged migration runs.
    /// - precondition: No migration with the same identifier as already
    ///   been registered.
    public mutating func registerMigration(
        _ identifier: String,
        foreignKeyChecks: ForeignKeyChecks = .deferred,
        merging mergedIdentifiers: Set<String> = [],
        migrate: @escaping @Sendable (_ db: Database, _ appliedIdentifiers: Set<String>) throws -> Void)
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
        
        // Remove the migration identifier from the list of merged identifiers.
        // Arguably, the semantics are ambiguous. And raising a fatal error
        // is a high price when we can just fix the input.
        var mergedIdentifiers = mergedIdentifiers
        mergedIdentifiers.remove(identifier)
        
        registerMigration(Migration(
            identifier: identifier,
            mergedIdentifiers: mergedIdentifiers,
            foreignKeyChecks: migrationChecks,
            migrate: migrate))
    }
    
    // MARK: - Applying Migrations
    
    /// Runs all unapplied migrations, in the same order as they
    /// were registered.
    ///
    /// - parameter writer: A DatabaseWriter.
    /// - throws: The error thrown by the first failed migration.
    public func migrate(_ writer: any DatabaseWriter) throws {
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
    public func migrate(_ writer: any DatabaseWriter, upTo targetIdentifier: String) throws {
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
        _ writer: any DatabaseWriter,
        completion: @escaping @Sendable (Result<Database, Error>) -> Void)
    {
        writer.asyncBarrierWriteWithoutTransaction { dbResult in
            do {
                let db = try dbResult.get()
                if let lastMigration = _migrations.last {
                    try migrate(db, upTo: lastMigration.identifier)
                }
                completion(.success(db))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Detecting Schema Changes
    
    /// Returns a boolean value indicating whether the migrator detects a
    /// change in the definition of migrations.
    ///
    /// The result is true if one of those conditions is met:
    ///
    /// - A migration has been removed, or renamed.
    /// - There exists any difference in the `sqlite_master` table, which
    ///   contains the SQL used to create database tables, indexes,
    ///   triggers, and views.
    ///
    /// This method supports the ``eraseDatabaseOnSchemaChange`` option.
    /// When `eraseDatabaseOnSchemaChange` does not exactly fit your
    /// needs, you can implement it manually as below:
    ///
    /// ```swift
    /// #if DEBUG
    /// // Speed up development by nuking the database when migrations change
    /// if dbQueue.read(migrator.hasSchemaChanges) {
    ///     try dbQueue.erase()
    ///     // Perform other needed logic
    /// }
    /// #endif
    /// try migrator.migrate(dbQueue)
    /// ```
    ///
    public func hasSchemaChanges(_ db: Database) throws -> Bool {
        let appliedIdentifiers = try appliedIdentifiers(db)
        let knownIdentifiers = Set(_migrations.map { $0.identifier })
        if !appliedIdentifiers.isSubset(of: knownIdentifiers) {
            // Database contains an unknown migration
            return true
        }
        
        if let lastAppliedIdentifier = _migrations
            .map(\.identifier)
            .last(where: { appliedIdentifiers.contains($0) })
        {
            // Some migrations were already applied.
            //
            // Let's migrate a temporary database up to the same
            // level, and compare the database schemas. If they
            // differ, we'll return true
            let tmpSchema = try {
                // Make sure the temporary database is configured
                // just as the migrated database
                var tmpConfig = db.configuration
                tmpConfig.readonly = false // We need write access
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
                    .appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString)
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
                return true
            }
        }
        
        return false
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
    
    private struct Execution {
        enum Mode {
            case run(mergedIdentifiers: Set<String>)
            case deleteMergedIdentifiers
        }
        
        var migration: Migration
        var mode: Mode
    }
    
    private mutating func registerMigration(_ migration: Migration) {
        GRDBPrecondition(
            !_migrations.map({ $0.identifier }).contains(migration.identifier),
            "already registered migration: \(String(reflecting: migration.identifier))")
        _migrations.append(migration)
    }
    
    /// Returns unapplied migration executions
    private func unappliedExecutions(upTo targetIdentifier: String, appliedIdentifiers: Set<String>) -> [Execution] {
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
        
        return expectedMigrations.compactMap { migration in
            if appliedIdentifiers.contains(migration.identifier) {
                if migration.mergedIdentifiers.isDisjoint(with: appliedIdentifiers) {
                    // Nothing to do
                    return nil
                } else {
                    // Migration is applied, but we have some merged identifiers to delete
                    return Execution(migration: migration, mode: .deleteMergedIdentifiers)
                }
            } else {
                // Migration is not applied yet.
                let appliedMergedIdentifiers = migration.mergedIdentifiers.intersection(appliedIdentifiers)
                return Execution(migration: migration, mode: .run(mergedIdentifiers: appliedMergedIdentifiers))
            }
        }
    }
    
    private func runMigrations(_ db: Database, upTo targetIdentifier: String) throws {
        try db.execute(sql: "CREATE TABLE IF NOT EXISTS grdb_migrations (identifier TEXT NOT NULL PRIMARY KEY)")
        
        // Subsequent migration must not be applied
        let appliedMigrations = try self.appliedMigrations(db) // Only known ids
        if let targetIndex = _migrations.firstIndex(where: { $0.identifier == targetIdentifier }),
           let lastAppliedMigration = appliedMigrations.last,
           let lastAppliedIndex = _migrations.firstIndex(where: { $0.identifier == lastAppliedMigration }),
           targetIndex < lastAppliedIndex
        {
            fatalError("database is already migrated beyond migration \(String(reflecting: targetIdentifier))")
        }
        
        let appliedIdentifiers = try self.appliedIdentifiers(db) // All ids, even unknown ones
        let unappliedExecutions = self.unappliedExecutions(
            upTo: targetIdentifier,
            appliedIdentifiers: appliedIdentifiers)
        
        if unappliedExecutions.isEmpty {
            return
        }
        
        for execution in unappliedExecutions {
            switch execution.mode {
            case .run(let mergedIdentifiers):
                try execution.migration.run(db, mergedIdentifiers: mergedIdentifiers)
            case .deleteMergedIdentifiers:
                try execution.migration.deleteMergedIdentifiers(db)
            }
        }
    }
    
    private func migrate(_ db: Database, upTo targetIdentifier: String) throws {
        if eraseDatabaseOnSchemaChange {
            var needsErase = false
            try db.inTransaction(.deferred) {
                needsErase = try hasSchemaChanges(db)
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
    public func migratePublisher(
        _ writer: any DatabaseWriter,
        receiveOn scheduler: some Combine.Scheduler = DispatchQueue.main)
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

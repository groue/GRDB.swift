/// An internal struct that defines a migration.
struct Migration: Sendable {
    enum ForeignKeyChecks {
        case deferred
        case immediate
        case disabled
    }
    
    typealias Migrate = @Sendable (_ db: Database, _ mergedIdentifiers: Set<String>) throws -> Void
    
    let identifier: String
    let mergedIdentifiers: Set<String>
    var foreignKeyChecks: ForeignKeyChecks
    // Private so that the guarantees of `run(_:)` are enforced.
    private let migrate: Migrate
    
    init(
        identifier: String,
        mergedIdentifiers: Set<String>,
        foreignKeyChecks: ForeignKeyChecks,
        migrate: @escaping Migrate
    ) {
        self.identifier = identifier
        self.mergedIdentifiers = mergedIdentifiers
        self.foreignKeyChecks = foreignKeyChecks
        self.migrate = migrate
    }
    
    func run(_ db: Database, mergedIdentifiers: Set<String>) throws {
        // Migrations access the raw SQLite schema, without alteration due
        // to the schemaSource. The goal is to ensure that migrations are
        // immutable, immune from spooky actions at a distance.
        try db.withSchemaSource(nil) {
            if try Bool.fetchOne(db, sql: "PRAGMA foreign_keys") ?? false {
                switch foreignKeyChecks {
                case .deferred:
                    try runWithDeferredForeignKeysChecks(db, mergedIdentifiers: mergedIdentifiers)
                case .immediate:
                    try runWithImmediateForeignKeysChecks(db, mergedIdentifiers: mergedIdentifiers)
                case .disabled:
                    try runWithDisabledForeignKeysChecks(db, mergedIdentifiers: mergedIdentifiers)
                }
            } else {
                try runWithImmediateForeignKeysChecks(db, mergedIdentifiers: mergedIdentifiers)
            }
        }
    }
    
    
    func deleteMergedIdentifiers(_ db: Database) throws {
        if mergedIdentifiers.isEmpty == false {
            try db.execute(literal: "DELETE FROM grdb_migrations WHERE identifier IN \(mergedIdentifiers)")
        }
    }
    
    private func runWithImmediateForeignKeysChecks(_ db: Database, mergedIdentifiers: Set<String>) throws {
        try db.inTransaction(.immediate) {
            try migrate(db, mergedIdentifiers)
            try updateAppliedIdentifier(db)
            return .commit
        }
    }
    
    private func runWithDisabledForeignKeysChecks(_ db: Database, mergedIdentifiers: Set<String>) throws {
        try db.execute(sql: "PRAGMA foreign_keys = OFF")
        try throwingFirstError(
            execute: {
                try db.inTransaction(.immediate) {
                    try migrate(db, mergedIdentifiers)
                    try updateAppliedIdentifier(db)
                    return .commit
                }
            },
            finally: {
                try db.execute(sql: "PRAGMA foreign_keys = ON")
            })
    }

    private func runWithDeferredForeignKeysChecks(_ db: Database, mergedIdentifiers: Set<String>) throws {
        // Support for database alterations described at
        // https://www.sqlite.org/lang_altertable.html#otheralter
        //
        // > 1. If foreign key constraints are enabled, disable them using
        // > PRAGMA foreign_keys=OFF.
        try db.execute(sql: "PRAGMA foreign_keys = OFF")
        
        try throwingFirstError(
            execute: {
                // > 2. Start a transaction.
                try db.inTransaction(.immediate) {
                    try migrate(db, mergedIdentifiers)
                    try updateAppliedIdentifier(db)
                    
                    // > 10. If foreign key constraints were originally enabled
                    // > then run PRAGMA foreign_key_check to verify that the
                    // > schema change did not break any foreign
                    // > key constraints.
                    try db.checkForeignKeys()
                    
                    // > 11. Commit the transaction started in step 2.
                    return .commit
                }
            },
            finally: {
                // > 12. If foreign keys constraints were originally enabled,
                // > reenable them now.
                try db.execute(sql: "PRAGMA foreign_keys = ON")
            })
    }
    
    private func updateAppliedIdentifier(_ db: Database) throws {
        try deleteMergedIdentifiers(db)
        try db.execute(literal: "INSERT INTO grdb_migrations (identifier) VALUES (\(identifier))")
    }
}

/// An internal struct that defines a migration.
struct Migration {
    enum ForeignKeyChecks {
        case deferred
        case immediate
        case disabled
    }
    
    let identifier: String
    var foreignKeyChecks: ForeignKeyChecks
    let migrate: (Database) throws -> Void
    
    func run(_ db: Database) throws {
        if try Bool.fetchOne(db, sql: "PRAGMA foreign_keys") ?? false {
            switch foreignKeyChecks {
            case .deferred:
                try runWithDeferredForeignKeysChecks(db)
            case .immediate:
                try runWithImmediateForeignKeysChecks(db)
            case .disabled:
                try runWithDisabledForeignKeysChecks(db)
            }
        } else {
            try runWithImmediateForeignKeysChecks(db)
        }
    }
    
    private func runWithImmediateForeignKeysChecks(_ db: Database) throws {
        try db.inTransaction(.immediate) {
            try migrate(db)
            try insertAppliedIdentifier(db)
            return .commit
        }
    }
    
    private func runWithDisabledForeignKeysChecks(_ db: Database) throws {
        try db.execute(sql: "PRAGMA foreign_keys = OFF")
        try throwingFirstError(
            execute: {
                try db.inTransaction(.immediate) {
                    try migrate(db)
                    try insertAppliedIdentifier(db)
                    return .commit
                }
            },
            finally: {
                try db.execute(sql: "PRAGMA foreign_keys = ON")
            })
    }

    private func runWithDeferredForeignKeysChecks(_ db: Database) throws {
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
                    try migrate(db)
                    try insertAppliedIdentifier(db)
                    
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
    
    private func insertAppliedIdentifier(_ db: Database) throws {
        try db.execute(sql: "INSERT INTO grdb_migrations (identifier) VALUES (?)", arguments: [identifier])
    }
}

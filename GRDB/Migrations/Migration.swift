/// An internal struct that defines a migration.
struct Migration {
    let identifier: String
    let disabledForeignKeyChecks: Bool
    let migrate: (db: Database) throws -> Void
    
    func run(db: Database) throws {
        if disabledForeignKeyChecks && Bool.fetchOne(db, "PRAGMA foreign_keys")! {
            try runWithDisabledForeignKeys(db)
        } else {
            try runWithoutDisabledForeignKeys(db)
        }
    }
    
    private func runWithoutDisabledForeignKeys(db: Database) throws {
        try db.inTransaction(.Immediate) {
            try self.migrate(db: db)
            try self.insertAppliedIdentifier(db)
            return .Commit
        }
    }
    
    private func runWithDisabledForeignKeys(db: Database) throws {
        // Support for database alterations described at
        // https://www.sqlite.org/lang_altertable.html#otheralter
        //
        // > 1. If foreign key constraints are enabled, disable them using
        // > PRAGMA foreign_keys=OFF.
        try db.execute("PRAGMA foreign_keys = OFF")
        
        defer {
            // > 12. If foreign keys constraints were originally enabled, reenable them now.
            try! db.execute("PRAGMA foreign_keys = ON")
        }
        
        // > 2. Start a transaction.
        try db.inTransaction(.Immediate) {
            try self.migrate(db: db)
            try self.insertAppliedIdentifier(db)
            
            // > 10. If foreign key constraints were originally enabled then run PRAGMA
            // > foreign_key_check to verify that the schema change did not break any foreign key
            // > constraints.
            if Row.fetchOne(db, "PRAGMA foreign_key_check") != nil {
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
    
    private func insertAppliedIdentifier(db: Database) throws {
        try db.execute("INSERT INTO grdb_migrations (identifier) VALUES (?)", arguments: [identifier])
    }
}
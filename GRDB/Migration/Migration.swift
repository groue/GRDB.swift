/// An internal struct that defines a migration.
struct Migration {
    let identifier: String
    let disabledForeignKeyChecks: Bool
    let migrate: (Database) throws -> Void
    
    #if GRDBCUSTOMSQLITE || GRDBCIPHER
        init(identifier: String, disabledForeignKeyChecks: Bool = false, migrate: @escaping (Database) throws -> Void) {
            self.identifier = identifier
            self.disabledForeignKeyChecks = disabledForeignKeyChecks
            self.migrate = migrate
        }
    #else
        init(identifier: String, migrate: @escaping (Database) throws -> Void) {
            self.identifier = identifier
            self.disabledForeignKeyChecks = false
            self.migrate = migrate
        }
    
        @available(iOS 8.2, OSX 10.10, *)
        // PRAGMA foreign_key_check was introduced in SQLite 3.7.16 http://www.sqlite.org/changes.html#version_3_7_16
        // It is available from iOS 8.2 and OS X 10.10 https://github.com/yapstudios/YapDatabase/wiki/SQLite-version-(bundled-with-OS)
        init(identifier: String, disabledForeignKeyChecks: Bool, migrate: @escaping (Database) throws -> Void) {
            self.identifier = identifier
            self.disabledForeignKeyChecks = disabledForeignKeyChecks
            self.migrate = migrate
        }
    #endif
    
    func run(_ db: Database) throws {
        if try disabledForeignKeyChecks && (Bool.fetchOne(db, "PRAGMA foreign_keys") ?? false) {
            try runWithDisabledForeignKeys(db)
        } else {
            try runWithoutDisabledForeignKeys(db)
        }
    }
    
    
    private func runWithoutDisabledForeignKeys(_ db: Database) throws {
        try db.inTransaction(.immediate) {
            try migrate(db)
            try insertAppliedIdentifier(db)
            return .commit
        }
    }
    
    private func runWithDisabledForeignKeys(_ db: Database) throws {
        // Support for database alterations described at
        // https://www.sqlite.org/lang_altertable.html#otheralter
        //
        // > 1. If foreign key constraints are enabled, disable them using
        // > PRAGMA foreign_keys=OFF.
        try db.execute("PRAGMA foreign_keys = OFF")
        
        // > 2. Start a transaction.
        try db.inTransaction(.immediate) {
            try migrate(db)
            try insertAppliedIdentifier(db)
            
            // > 10. If foreign key constraints were originally enabled then run PRAGMA
            // > foreign_key_check to verify that the schema change did not break any foreign key
            // > constraints.
            if try Row.fetchOne(db, "PRAGMA foreign_key_check") != nil {
                // https://www.sqlite.org/pragma.html#pragma_foreign_key_check
                //
                // PRAGMA foreign_key_check does not return an error,
                // but the list of violated foreign key constraints.
                //
                // Let's turn any violation into an SQLITE_CONSTRAINT
                // error, and rollback the transaction.
                throw DatabaseError(resultCode: .SQLITE_CONSTRAINT, message: "FOREIGN KEY constraint failed")
            }
            
            // > 11. Commit the transaction started in step 2.
            return .commit
        }
        
        // > 12. If foreign keys constraints were originally enabled, reenable them now.
        try db.execute("PRAGMA foreign_keys = ON")
    }
    
    private func insertAppliedIdentifier(_ db: Database) throws {
        try db.execute("INSERT INTO grdb_migrations (identifier) VALUES (?)", arguments: [identifier])
    }
}

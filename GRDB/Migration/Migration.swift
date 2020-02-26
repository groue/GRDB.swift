#if SWIFT_PACKAGE
import CSQLite
#elseif GRDBCIPHER
import SQLCipher
#elseif !GRDBCUSTOMSQLITE && !GRDBCIPHER
import SQLite3
#endif

/// An internal struct that defines a migration.
struct Migration {
    let identifier: String
    let migrate: (Database) throws -> Void
    
    init(identifier: String, migrate: @escaping (Database) throws -> Void) {
        self.identifier = identifier
        self.migrate = migrate
    }
    
    func run(_ db: Database) throws {
        // PRAGMA foreign_key_check and SQLITE_CONSTRAINT_FOREIGNKEY were
        // introduced in SQLite 3.7.16
        // http://www.sqlite.org/changes.html#version_3_7_16
        if try sqlite3_libversion_number() >= 3007016 && (Bool.fetchOne(db, sql: "PRAGMA foreign_keys") ?? false) {
            try runWithDeferredForeignKeysChecks(db)
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
                    if try db
                        .makeSelectStatement(sql: "PRAGMA foreign_key_check")
                        .makeCursor()
                        .isEmpty() == false
                    {
                        // https://www.sqlite.org/pragma.html#pragma_foreign_key_check
                        //
                        // PRAGMA foreign_key_check does not return an error,
                        // but the list of violated foreign key constraints.
                        //
                        // Let's turn any violation into an
                        // SQLITE_CONSTRAINT_FOREIGNKEY error, and rollback
                        // the transaction.
                        throw DatabaseError(
                            resultCode: .SQLITE_CONSTRAINT_FOREIGNKEY,
                            message: "FOREIGN KEY constraint failed")
                    }
                    
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

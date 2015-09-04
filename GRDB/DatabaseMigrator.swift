//
// GRDB.swift
// https://github.com/groue/GRDB.swift
// Copyright (c) 2015 Gwendal Roué
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.


/**
A DatabaseMigrator registers and applies database migrations.

Migrations are named blocks of SQL statements that are guaranteed to be applied
in order, once and only once.

When a user upgrades your application, only non-applied migration are run.

Usage:

    var migrator = DatabaseMigrator()

    // v1.0 database
    migrator.registerMigration("createPersons") { db in
        try db.execute(
            "CREATE TABLE persons (" +
                "id INTEGER PRIMARY KEY, " +
                "creationDate TEXT, " +
                "name TEXT NOT NULL" +
            ")")
    }

    migrator.registerMigration("createBooks") { db in
        try db.execute(
            "CREATE TABLE books (" +
                "uuid TEXT PRIMARY KEY, " +
                "ownerID INTEGER NOT NULL " +
                "        REFERENCES persons(id) " +
                "        ON DELETE CASCADE ON UPDATE CASCADE, " +
                "title TEXT NOT NULL" +
            ")")
    }

    // v2.0 database
    migrator.registerMigration("AddAgeToPersons") { db in
        try db.execute("ALTER TABLE persons ADD COLUMN age INT")
    }

    try migrator.migrate(dbQueue)

*/
public struct DatabaseMigrator {
    
    /// A new migrator.
    public init() {
    }
    
    /**
    Registers a migration.
    
        migrator.registerMigration("createPersons") { db in
            try db.execute(
                "CREATE TABLE persons (" +
                    "id INTEGER PRIMARY KEY, " +
                    "creationDate TEXT, " +
                    "name TEXT NOT NULL" +
                ")")
        }

    
    - parameter identifier: The migration identifier. It must be unique.
    - parameter block:      The migration block that performs SQL statements.
    */
    public mutating func registerMigration(identifier: String, _ block: (db: Database) throws -> Void) {
        guard migrations.map({ $0.identifier }).indexOf(identifier) == nil else {
            fatalError("Already registered migration: \"\(identifier)\"")
        }
        migrations.append(Migration(identifier: identifier, block: block))
    }
    
    /**
    Iterate migrations in the same order as they were registered. If a migration
    has not yet been applied, its block is executed in a transaction.
    
    - parameter dbQueue: The Database Queue where migrations should apply.
    - throws: An eventual error thrown by the registered migration blocks.
    */
    public func migrate(dbQueue: DatabaseQueue) throws {
        try setupMigrations(dbQueue)
        try runMigrations(dbQueue)
    }
    
    
    // MARK: - Non public
    
    private struct Migration {
        let identifier: String
        let block: (db: Database) throws -> Void
    }
    
    private var migrations: [Migration] = []
    
    private func setupMigrations(dbQueue: DatabaseQueue) throws {
        try dbQueue.inDatabase { db in
            try db.execute(
                "CREATE TABLE IF NOT EXISTS grdb_migrations (" +
                    "identifier VARCHAR(128) PRIMARY KEY NOT NULL," +
                    "position INT" +
                ")")
        }
    }
    
    private func runMigrations(dbQueue: DatabaseQueue) throws {
        let appliedMigrationIdentifiers = dbQueue.inDatabase { db in
            String.fetch(db, "SELECT identifier FROM grdb_migrations").map { $0! }
        }
    
        for (position, migration) in self.migrations.enumerate() {
            if appliedMigrationIdentifiers.indexOf(migration.identifier) == nil {
                try dbQueue.inTransaction { db in
                    try migration.block(db: db)
                    try db.execute("INSERT INTO grdb_migrations (position, identifier) VALUES (?, ?)", arguments: [position, migration.identifier])
                    return .Commit
                }
            }
        }
    }
}
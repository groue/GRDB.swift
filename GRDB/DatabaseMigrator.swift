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


public struct DatabaseMigrator {
    
    public init() {
    }
    
    public mutating func registerMigration(identifier: String, _ block: (db: Database) throws -> Void) {
        guard migrations.map({ $0.identifier }).indexOf(identifier) == nil else {
            fatalError("Already registered migration: \"\(identifier)\"")
        }
        migrations.append(Migration(identifier: identifier, block: block))
    }

    public func migrate(dbQueue: DatabaseQueue) throws {
        try setupMigrations(dbQueue)
        try runMigrations(dbQueue)
    }

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
            db.fetch(String.self, "SELECT identifier FROM grdb_migrations").map { $0! }
        }
    
        for (position, migration) in self.migrations.enumerate() {
            if appliedMigrationIdentifiers.indexOf(migration.identifier) == nil {
                try dbQueue.inTransaction { db in
                    try migration.block(db: db)
                    try db.execute("INSERT INTO grdb_migrations (position, identifier) VALUES (?, ?)", bindings: [position, migration.identifier])
                    return .Commit
                }
            }
        }
    }
}
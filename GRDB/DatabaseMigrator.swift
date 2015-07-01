//
//  DatabaseMigrator.swift
//  GRDB
//
//  Created by Gwendal Roué on 01/07/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

public struct DatabaseMigrator {
    
    public mutating func registerMigration(identifier: String, block: (db: Database) throws -> Void) {
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
                "CREATE TABLE grdb_migrations IF NOT EXISTS (" +
                    "identifier VARCHAR(128) PRIMARY KEY NOT NULL," +
                    "position INT" +
                ")")
        }
    }
    
    private func runMigrations(dbQueue: DatabaseQueue) throws {
        try dbQueue.inTransaction { db -> Void in
            let appliedMigrationIdentifiers = try db.fetchValues(String.self, sql: "SELECT identifier FROM db_migrations").map { $0! }
        
            for (position, migration) in self.migrations.enumerate() {
                if appliedMigrationIdentifiers.indexOf(migration.identifier) == nil {
                    try migration.block(db: db)
                    try db.execute("INSERT INTO db_migrations (position, identifier) VALUES (?, ?)", arguments: [position, migration.identifier])
                }
            }
        }
    }
}
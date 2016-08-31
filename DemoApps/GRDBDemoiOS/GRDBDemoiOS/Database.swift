import GRDB
import UIKit

// The shared database queue
var dbQueue: DatabaseQueue!

func setupDatabase(application: UIApplication) {
    
    // Connect to the database
    // See https://github.com/groue/GRDB.swift/#database-connections
    
    let documentsPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true).first! as NSString
    let databasePath = documentsPath.stringByAppendingPathComponent("db.sqlite")
    dbQueue = try! DatabaseQueue(path: databasePath)
    
    
    // Be a nice iOS citizen, and don't consume too much memory
    // See https://github.com/groue/GRDB.swift/#memory-management
    
    dbQueue.setupMemoryManagement(application: application)
    
    
    // Use DatabaseMigrator to setup the database
    // See https://github.com/groue/GRDB.swift/#migrations
    
    var migrator = DatabaseMigrator()
    
    migrator.registerMigration("createPersons") { db in
        // Compare person names in a localized case insensitive fashion
        // See https://github.com/groue/GRDB.swift/#unicode
        try db.create(table: "persons") { t in
            t.column("id", .Integer).primaryKey()
            t.column("name", .Text).notNull().collate(.localizedCaseInsensitiveCompare)
            t.column("score", .Integer).notNull()
        }
    }
    
    migrator.registerMigration("addPersons") { db in
        // Populate the persons table with random data
        for _ in 0..<8 {
            try Person(name: Person.randomName(), score: Person.randomScore()).insert(db)
        }
    }
    
    try! migrator.migrate(dbQueue)
}

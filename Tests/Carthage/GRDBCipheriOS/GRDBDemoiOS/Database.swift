import GRDBCipher
import UIKit

// The shared database queue
var dbQueue: DatabaseQueue!

func setupDatabase(application: UIApplication) {
    
    // Connect to the database
    // See https://github.com/groue/GRDB.swift/#database-connections
    
    let documentsPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true).first! as NSString
    let databasePath = documentsPath.stringByAppendingPathComponent("db.sqlite")
    var configuration = Configuration()
    configuration.passphrase = "secret"
    dbQueue = try! DatabaseQueue(path: databasePath)
    
    
    // Be a nice iOS citizen, and don't consume too much memory
    // See https://github.com/groue/GRDB.swift/#memory-management
    
    dbQueue.setupMemoryManagement(application: application)
    
    
    // Use DatabaseMigrator to setup the database
    // See https://github.com/groue/GRDB.swift/#migrations
    
    var migrator = DatabaseMigrator()
    
    migrator.registerMigration("createPersons") { db in
        // Have person names compared in a localized case insensitive fashion
        // See https://github.com/groue/GRDB.swift/#unicide
        let collation = DatabaseCollation.localizedCaseInsensitiveCompare
        try db.execute(
            "CREATE TABLE persons (" +
                "id INTEGER PRIMARY KEY, " +
                "name TEXT NOT NULL COLLATE \(collation.name), " +
                "score INTEGER NOT NULL " +
            ")")
    }
    
    migrator.registerMigration("addPersons") { db in
        // Populate the persons table with random data
        for _ in 0..<8 {
            try Person(name: Person.randomName(), score: Person.randomScore()).insert(db)
        }
    }
    
    try! migrator.migrate(dbQueue)
}

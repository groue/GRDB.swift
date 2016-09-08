import GRDB
import WatchKit

// The shared database queue
var dbQueue: DatabaseQueue!

func setupDatabase() {
    
    // Connect to the database
    // See https://github.com/groue/GRDB.swift/#database-connections
    
    let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first! as NSString
    let databasePath = documentsPath.appendingPathComponent("db.sqlite")
    dbQueue = try! DatabaseQueue(path: databasePath)
    
    
    // Use DatabaseMigrator to setup the database
    // See https://github.com/groue/GRDB.swift/#migrations
    
    var migrator = DatabaseMigrator()
    
    migrator.registerMigration("createPersons") { db in
        // Compare person names in a localized case insensitive fashion
        // See https://github.com/groue/GRDB.swift/#unicode
        try db.create(table: "persons") { t in
            t.column("id", .integer).primaryKey()
            t.column("name", .text).notNull().collate(.localizedCaseInsensitiveCompare)
        }
    }
    
    migrator.registerMigration("addPersons") { db in
        // Populate the persons table with random data
        for _ in 0..<8 {
            try Person(name: Person.randomName()).insert(db)
        }
    }
    
    try! migrator.migrate(dbQueue)
}

import GRDB

/// The shared database queue, stored in a global.
/// It is initialized in setupDatabase()
var dbQueue: DatabaseQueue!

func setupDatabase() {
    
    // Connect to the database
    //
    // See https://github.com/groue/GRDB.swift/#database-connections
    
    let documentsPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true).first! as NSString
    let databasePath = documentsPath.stringByAppendingPathComponent("db.sqlite")
    dbQueue = try! DatabaseQueue(path: databasePath)
    
    
    // SQLite does not support Unicode: let's add a custom collation which will
    // allow us to sort persons by name.
    //
    // See https://github.com/groue/GRDB.swift/#string-comparison
    
    let collation = DatabaseCollation("localized_case_insensitive") { (lhs, rhs) in
        return (lhs as NSString).localizedCaseInsensitiveCompare(rhs)
    }
    dbQueue.addCollation(collation)
    
    
    // Use DatabaseMigrator to setup the database
    //
    // See https://github.com/groue/GRDB.swift/#migrations
    
    var migrator = DatabaseMigrator()
    migrator.registerMigration("createPersons") { db in
        try db.execute(
            "CREATE TABLE persons (" +
                "id INTEGER PRIMARY KEY, " +
                "name TEXT NOT NULL COLLATE localized_case_insensitive, " +
                "score INTEGER NOT NULL " +
            ")")
    }
    migrator.registerMigration("addPersons") { db in
        try Person(name: "Alice", score: 150).insert(db)
        try Person(name: "Bob", score: 70).insert(db)
        try Person(name: "Craig", score: 220).insert(db)
        try Person(name: "David", score: 80).insert(db)
        try Person(name: "Elise", score: 100).insert(db)
        try Person(name: "Fiona", score: 40).insert(db)
    }
    try! migrator.migrate(dbQueue)
}
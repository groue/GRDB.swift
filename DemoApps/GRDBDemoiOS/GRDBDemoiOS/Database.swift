import GRDB

// The columns for the GRDB Query Interface
//
// See https://github.com/groue/GRDB.swift/#the-query-interface

struct Col {
    static let id = SQLColumn("id")
    static let firstName = SQLColumn("firstName")
    static let lastName = SQLColumn("lastName")
}


// The shared database queue, stored in a global.
// It is initialized in setupDatabase()

var dbQueue: DatabaseQueue!

func setupDatabase() {
    
    // Connect to the database
    //
    // See https://github.com/groue/GRDB.swift/#database-queues
    
    let documentsPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true).first! as NSString
    let databasePath = documentsPath.stringByAppendingPathComponent("db.sqlite")
    dbQueue = try! DatabaseQueue(path: databasePath)
    
    
    // Use DatabaseMigrator to setup the database
    //
    // See https://github.com/groue/GRDB.swift/#migrations
    
    var migrator = DatabaseMigrator()
    migrator.registerMigration("createPersons") { db in
        // Have person names compared in a localized case insensitive fashion
        let collation = DatabaseCollation.localizedCaseInsensitiveCompare
        try db.execute(
            "CREATE TABLE persons (" +
                "id INTEGER PRIMARY KEY, " +
                "firstName TEXT COLLATE \(collation.name), " +
                "lastName TEXT COLLATE \(collation.name)" +
            ")")
    }
    migrator.registerMigration("addPersons") { db in
        try Person(firstName: "Arthur", lastName: "Miller").insert(db)
        try Person(firstName: "Barbra", lastName: "Streisand").insert(db)
        try Person(firstName: "Cinderella").insert(db)
    }
    try! migrator.migrate(dbQueue)
}
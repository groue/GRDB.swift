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
                "name TEXT NOT NULL COLLATE \(collation.name), " +
                "score INTEGER NOT NULL " +
            ")")
    }
    migrator.registerMigration("addPersons") { db in
        for _ in 0..<8 {
            try Person(name: randomName(), score: randomScore()).insert(db)
        }
    }
    try! migrator.migrate(dbQueue)
}


private let names = ["Arthur", "Anita", "Barbara", "Bernard", "Craig", "Chiara", "David", "Dean", "Éric", "Elena", "Fatima", "Frederik", "Gilbert", "Georgette", "Henriette", "Hassan", "Ignacio", "Irene", "Julie", "Jack", "Karl", "Kristel", "Louis", "Liz", "Masashi", "Mary", "Noam", "Nicole", "Ophelie", "Oleg", "Pascal", "Patricia", "Quentin", "Quinn", "Raoul", "Rachel", "Stephan", "Susie", "Tristan", "Tatiana", "Ursule", "Urbain", "Victor", "Violette", "Wilfried", "Wilhelmina", "Yvon", "Yann", "Zazie", "Zoé"]

func randomName() -> String {
    return names[Int(arc4random_uniform(UInt32(names.count)))]
}

func randomScore() -> Int {
    return 10 * Int(arc4random_uniform(101))
}

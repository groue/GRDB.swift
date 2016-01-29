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
    
    
    // SQLite does not support Unicode: let's add a custom collation which will
    // allow us to sort persons by name.
    //
    // See https://github.com/groue/GRDB.swift/#string-comparison
    
    let collation = DatabaseCollation("localized_case_insensitive") { (lhs, rhs) in
        return (lhs as NSString).localizedCaseInsensitiveCompare(rhs)
    }
    
    dbQueue.inDatabase { db in
        db.addCollation(collation)
    }
    
    
    // Use DatabaseMigrator to setup the database
    //
    // See https://github.com/groue/GRDB.swift/#migrations
    
    var migrator = DatabaseMigrator()
    migrator.registerMigration("createPersons") { db in
        try db.execute(
            "CREATE TABLE persons (" +
                "id INTEGER PRIMARY KEY, " +
                "firstName TEXT, " +
                "lastName TEXT ," +
                "visible BOOLEAN DEFAULT TRUE ," +
                "position INTEGER " +
            ")")
    }
    migrator.registerMigration("addPersons") { db in
        try Person(firstName: "Arthur", lastName: "Miller").insert(db)
        try Person(firstName: "Barbra", lastName: "Streisand").insert(db)
        try Person(firstName: "Cinderella").insert(db)
        try Person(firstName: "John", lastName: "Appleseed").insert(db)
        try Person(firstName: "Kate", lastName: "Bell").insert(db)
        try Person(firstName: "Anna", lastName: "Haro").insert(db)
        try Person(firstName: "Daniel", lastName: "Higgins").insert(db)
        try Person(firstName: "David", lastName: "Taylor").insert(db)
        try Person(firstName: "Hank", lastName: "Zakroff").insert(db)
        try Person(firstName: "Steve", lastName: "Jobs").insert(db)
        try Person(firstName: "Bill", lastName: "Gates").insert(db)
        try Person(firstName: "Zlatan", lastName: "Ibrahimovic").insert(db)
        try Person(firstName: "Barack", lastName: "Obama").insert(db)
        try Person(firstName: "François", lastName: "Hollande").insert(db)
        try Person(firstName: "Britney", lastName: "Spears").insert(db)
        try Person(firstName: "Andre", lastName: "Agassi").insert(db)
        try Person(firstName: "Roger", lastName: "Federer").insert(db)
        try Person(firstName: "Rafael", lastName: "Nadal").insert(db)
        try Person(firstName: "Gael", lastName: "Monfils").insert(db)
        try Person(firstName: "Jo Wilfried", lastName: "Tsonga").insert(db)
        try Person(firstName: "Serena", lastName: "Williams").insert(db)
        try Person(firstName: "Venus", lastName: "Williams").insert(db)
        try Person(firstName: "Amélie", lastName: "Poulain").insert(db)
    }
    try! migrator.migrate(dbQueue)
}
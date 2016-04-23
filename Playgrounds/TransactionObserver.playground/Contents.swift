// To run this playground, select and build the GRDBOSX scheme.

import GRDB


// Create the databsae

var configuration = Configuration()
configuration.trace = { print($0) }
let dbQueue = DatabaseQueue(configuration: configuration)   // Memory database
var migrator = DatabaseMigrator()
migrator.registerMigration("createPersons") { db in
    try db.execute(
        "CREATE TABLE persons (" +
            "id INTEGER PRIMARY KEY, " +
            "name TEXT NOT NULL " +
        ")")
}
migrator.registerMigration("createPets") { db in
    try db.execute(
        "CREATE TABLE pets (" +
            "id INTEGER PRIMARY KEY, " +
            "name TEXT, " +
            "ownerId INTEGER NOT NULL REFERENCES persons(id) ON DELETE CASCADE" +
        ")")
}
try! migrator.migrate(dbQueue)



/// TableChangeObserver prints on the main thread the changes database tables.
class TableChangeObserver : NSObject, TransactionObserverType {
    private var changedTableNames: Set<String> = []
    
    func databaseDidChangeWithEvent(event: DatabaseEvent) {
        changedTableNames.insert(event.tableName)
    }
    
    func databaseWillCommit() throws {
    }
    
    func databaseDidCommit(db: Database) {
        print("Changed table(s): \(changedTableNames.joinWithSeparator(", "))")
        changedTableNames = []
    }
    
    func databaseDidRollback(db: Database) {
        changedTableNames = []
    }
}



// Register observer

let observer = TableChangeObserver()
dbQueue.addTransactionObserver(observer)


//

print("-- Changes 1")
try! dbQueue.inDatabase { db in
    try db.execute("INSERT INTO persons (name) VALUES (?)", arguments: ["Arthur"])
    let arthurId = db.lastInsertedRowID
    try db.execute("INSERT INTO persons (name) VALUES (?)", arguments: ["Barbara"])
    try db.execute("INSERT INTO pets (ownerId, name) VALUES (?, ?)", arguments: [arthurId, "Barbara"])
}

print("-- Changes 2")
try dbQueue.inTransaction { db in
    try db.execute("INSERT INTO persons (name) VALUES ('Arthur')")
    try db.execute("INSERT INTO persons (name) VALUES ('Barbara')")
    return .Rollback
}


print("-- Changes 3")
try dbQueue.inDatabase { db in
    try db.execute("DELETE FROM persons")
}

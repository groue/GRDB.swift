//: To run this playground:
//:
//: - Open GRDB.xcworkspace
//: - Select the GRDBOSX scheme: menu Product > Scheme > GRDBOSX
//: - Build: menu Product > Build
//: - Select the playground in the Playgrounds Group
//: - Run the playground

import GRDB


// Create the databsae

let dbQueue = DatabaseQueue()   // Memory database
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
class TableChangeObserver : NSObject, TransactionObserver {
    private var changedTableNames: Set<String> = []
    
    func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool {
        return true
    }
    
    func databaseDidChange(with event: DatabaseEvent) {
        changedTableNames.insert(event.tableName)
    }
    
    func databaseWillCommit() throws {
    }
    
    func databaseDidCommit(_ db: Database) {
        print("Changed table(s): \(changedTableNames.joined(separator: ", "))")
        changedTableNames = []
    }
    
    func databaseDidRollback(_ db: Database) {
        changedTableNames = []
    }
}



// Register observer

let observer = TableChangeObserver()
dbQueue.add(transactionObserver: observer)


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
    return .rollback
}


print("-- Changes 3")
try dbQueue.write { db in
    try db.execute("DELETE FROM persons")
    try db.execute("DELETE FROM pets")
}

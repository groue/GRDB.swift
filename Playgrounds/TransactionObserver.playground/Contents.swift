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
migrator.registerMigration("createPerson") { db in
    try db.create(table: "person") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("name", .text).notNull()
    }
}
migrator.registerMigration("createPet") { db in
    try db.create(table: "pet") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("name", .text).notNull()
        t.column("ownerId", .integer).references("person", onDelete: .cascade)
    }
}
try! migrator.migrate(dbQueue)


//

class TableChangeObserver : NSObject, TransactionObserver {
    private var changedTableNames: Set<String> = []
    
    func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool {
        return true
    }
    
    func databaseDidChange(with event: DatabaseEvent) {
        changedTableNames.insert(event.tableName)
    }
    
    func databaseDidCommit(_ db: Database) {
        print("Changed table(s): \(changedTableNames.joined(separator: ", "))")
        changedTableNames = []
    }
    
    func databaseDidRollback(_ db: Database) {
        changedTableNames = []
    }
}

let observer = TableChangeObserver()
dbQueue.add(transactionObserver: observer)


//

print("-- Changes without transaction")
try dbQueue.inDatabase { db in
    try db.execute(sql: "INSERT INTO person (name) VALUES (?)", arguments: ["Arthur"])
    let arthurId = db.lastInsertedRowID
    try db.execute(sql: "INSERT INTO person (name) VALUES (?)", arguments: ["Barbara"])
    try db.execute(sql: "INSERT INTO pet (ownerId, name) VALUES (?, ?)", arguments: [arthurId, "Barbara"])
    try db.execute(sql: "DELETE FROM person WHERE id = ?", arguments: [arthurId])
}

print("-- Rollbacked changes")
try dbQueue.inTransaction { db in
    try db.execute(sql: "INSERT INTO person (name) VALUES ('Arthur')")
    try db.execute(sql: "INSERT INTO person (name) VALUES ('Barbara')")
    return .rollback
}


print("-- Changes wrapped in a transaction")
try dbQueue.write { db in
    try db.execute(sql: "DELETE FROM person")
    try db.execute(sql: "INSERT INTO person (name) VALUES (?)", arguments: ["Arthur"])
    let arthurId = db.lastInsertedRowID
    try db.execute(sql: "INSERT INTO person (name) VALUES (?)", arguments: ["Barbara"])
    try db.execute(sql: "INSERT INTO pet (ownerId, name) VALUES (?, ?)", arguments: [arthurId, "Barbara"])
    try db.execute(sql: "DELETE FROM person WHERE id = ?", arguments: [arthurId])
}

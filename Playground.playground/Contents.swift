// To run this playground, select and build the GRDBOSX scheme.

import GRDB


// Create the databsae

let dbQueue = DatabaseQueue()
var migrator = DatabaseMigrator()
migrator.registerMigration("createPersons") { db in
    try db.execute("CREATE TABLE persons (" +
        "id INTEGER PRIMARY KEY, " +
        "firstName TEXT, " +
        "lastName TEXT" +
        ")")
}
try! migrator.migrate(dbQueue)


// Define a RowModel

class Person : RowModel {
    var id: Int64!
    var firstName: String?
    var lastName: String?
    var fullName: String {
        return " ".join([firstName, lastName].flatMap { $0 })
    }
    
    init(firstName: String? = nil, lastName: String? = nil) {
        self.firstName = firstName
        self.lastName = lastName
        super.init()
    }
    
    // RowModel overrides
    
    override class var databaseTable: Table? {
        return Table(named: "persons", primaryKey: .RowID("id"))
    }
    
    override func setDatabaseValue(dbv: DatabaseValue, forColumn column: String) {
        switch column {
        case "id": id = dbv.value()
        case "firstName": firstName = dbv.value()
        case "lastName": lastName = dbv.value()
        default: super.setDatabaseValue(dbv, forColumn: column)
        }
    }
    
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return [
            "id": id,
            "firstName": firstName,
            "lastName": lastName]
    }
    
    required init(row: Row) {
        super.init(row: row)
    }
}


// Insert and fetch persons from the database

try! dbQueue.inTransaction { db in
    try Person(firstName: "Arthur", lastName: "Miller").insert(db)
    try Person(firstName: "Barbara", lastName: "Streisand").insert(db)
    try Person(firstName: "Cinderella").insert(db)
    return .Commit
}

let persons = dbQueue.inDatabase { db in
    db.fetchAll(Person.self, "SELECT * FROM persons ORDER BY firstName, lastName")
}

print(persons)
print(persons.map { $0.fullName })



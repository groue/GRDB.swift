// To run this playground, select and build the GRDBOSX scheme.

import GRDB


// Create the databsae

var configuration = Configuration()
configuration.trace = LogSQL
let dbQueue = DatabaseQueue(configuration: configuration)   // Memory database
var migrator = DatabaseMigrator()
migrator.registerMigration("createPersons") { db in
    try db.execute("CREATE TABLE persons (" +
        "id INTEGER PRIMARY KEY, " +
        "firstName TEXT, " +
        "lastName TEXT" +
        ")")
}
try! migrator.migrate(dbQueue)


// Define a Record

class Person : Record {
    var id: Int64?
    var firstName: String?
    var lastName: String?
    var fullName: String {
        return [firstName, lastName].flatMap { $0 }.joinWithSeparator(" ")
    }
    
    init(id: Int64? = nil, firstName: String?, lastName: String?) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        super.init()
    }
    
    // Record overrides
    
    override class func databaseTableName() -> String {
        return "persons"
    }
    
    required init(row: Row) {
        id = row.value(named: "id")
        firstName = row.value(named: "firstName")
        lastName = row.value(named: "lastName")
        super.init(row: row)
    }
    
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return [
            "id": id,
            "firstName": firstName,
            "lastName": lastName]
    }
}


// Insert and fetch persons from the database

try! dbQueue.inTransaction { db in
    try Person(firstName: "Arthur", lastName: "Miller").insert(db)
    try Person(firstName: "Barbara", lastName: "Streisand").insert(db)
    try Person(firstName: "Cinderella", lastName: nil).insert(db)
    return .Commit
}

let persons = dbQueue.inDatabase { db in
    Person.fetchAll(db, "SELECT * FROM persons ORDER BY firstName, lastName")
}

print(persons)
print(persons.map { $0.fullName })

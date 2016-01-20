// To run this playground, select and build the GRDBOSX scheme.

import GRDB


// ==============================================
// SETUP

// Create the databsae

var configuration = Configuration()
configuration.trace = { print($0) } // Log all SQL statements

let dbQueue = DatabaseQueue(configuration: configuration)   // Memory database
var migrator = DatabaseMigrator()
migrator.registerMigration("createPersons") { db in
    try db.execute(
        "CREATE TABLE persons (" +
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
    
    required init(_ row: Row) {
        id = row.value(named: "id")
        firstName = row.value(named: "firstName")
        lastName = row.value(named: "lastName")
        super.init(row)
    }
    
    override var persistentDictionary: [String: DatabaseValueConvertible?] {
        return ["id": id, "firstName": firstName, "lastName": lastName]
    }
    
    override func didInsertWithRowID(rowID: Int64, forColumn column: String?) {
        id = rowID
    }
}


// Define colums

struct Col {
    static let firstName = SQLColumn("firstName")
    static let lastName = SQLColumn("lastName")
}


// END OF SETUP
// ==============================================

try! dbQueue.inTransaction { db in
    try Person(firstName: "Arthur", lastName: "Miller").insert(db)
    try Person(firstName: "Barbra", lastName: "Streisand").insert(db)
    try Person(firstName: "Cinderella", lastName: nil).insert(db)
    return .Commit
}

let persons = dbQueue.inDatabase { db in
    Person.order(Col.firstName, Col.lastName).fetchAll(db)
}

print(persons.map { $0.fullName })

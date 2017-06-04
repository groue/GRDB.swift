//: To run this playground, select and build the GRDBOSX scheme.
//:
//: Record
//: ======
//:
//: This playground is a demo of the Record class, the type that provides fetching methods, persistence methods, and change tracking.

import GRDB


//: ## Setup
//:
//: First open an in-memory database, with a trace function that prints all SQL statements.

var configuration = Configuration()
configuration.trace = { print($0) }
let dbQueue = DatabaseQueue(configuration: configuration)

//: Create a database table which stores persons.

try dbQueue.inDatabase { db in
    try db.execute(
        "CREATE TABLE persons (" +
            "id INTEGER PRIMARY KEY, " +
            "firstName TEXT, " +
            "lastName TEXT" +
        ")")
}


//: ## Subclassing Record
//:
//: The Person class is a subclass of Record, with regular properties, and a regular initializer:

class Person : Record {
    var id: Int64?
    var firstName: String?
    var lastName: String?
    
    var fullName: String {
        return [firstName, lastName].flatMap { $0 }.joined(separator: " ")
    }
    
    init(firstName: String?, lastName: String?) {
        self.id = nil
        self.firstName = firstName
        self.lastName = lastName
        super.init()
    }
    
    
//: Subclasses of Record have to override the methods that define how they interact with the database.
//:
//: 1. The table name:
    
    override class var databaseTableName: String {
        return "persons"
    }
    
//: 2. How to build a Person from a database row:
    
    required init(row: Row) {
        id = row.value(named: "id")
        firstName = row.value(named: "firstName")
        lastName = row.value(named: "lastName")
        super.init(row: row)
    }
    
//: 3. The dictionary of values that are stored in the database:
    
    override func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["firstName"] = firstName
        container["lastName"] = lastName
    }
    
//: 4. When relevant, update the person's id after a database row has been inserted:
    
    override func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}


//: ## Insert Records
//:
//: Persons are regular objects, that you can freely create:

let arthur = Person(firstName: "Arthur", lastName: "Miller")
let barbra = Person(firstName: "Barbra", lastName: "Streisand")
let cinderella = Person(firstName: "Cinderella", lastName: nil)

//: They are not stored in the database yet. Insert them:

try dbQueue.inDatabase { db in
    try arthur.insert(db)
    try barbra.insert(db)
    try cinderella.insert(db)
}


//: ## Fetching Records

try dbQueue.inDatabase { db in
    
    //: Fetch records from the database:
    let allPersons = try Person.fetchAll(db)

    //: Fetch record by primary key:
    let person = try Person.fetchOne(db, key: arthur.id)!
    person.fullName

    //: Fetch persons with an SQL query:
    let millers = try Person.fetchAll(db, "SELECT * FROM persons WHERE lastName = ?", arguments: ["Miller"])
    millers.first!.fullName


    //: To fetch persons using the query interface, you need some colums that can filter or sort:

    struct Col {
        static let firstName = Column("firstName")
        static let lastName = Column("lastName")
    }

    //: Sort
    let personsSortedByName = try Person.order(Col.firstName, Col.lastName).fetchAll(db)

    //: Filter
    let streisands = try Person.filter(Col.lastName == "Streisand").fetchAll(db)
}

// To run this playground, select and build the GRDBOSX scheme.
//
// This sample code shows how to use GRDB to synchronize a database table
// with a JSON payload. We use as few SQL queries as possible:
//
// - Only one SELECT query.
// - One query per insert, delete, and update.
// - Useless UPDATE statements are avoided.

import Foundation
import GRDB


// Open an in-memory database that logs all its SQL statements

var configuration = Configuration()
configuration.trace = { print($0) }
let dbQueue = DatabaseQueue(configuration: configuration)


// Create a database table

try dbQueue.inDatabase { db in
    try db.execute(
        "CREATE TABLE persons (" +
            "id INTEGER PRIMARY KEY, " +
            "name TEXT " +
        ")")
}


// Define the Person subclass of GRDB's Record.
//
// Record provides change tracking that helps avoiding useless
// UPDATE statements.
class Person : Record {
    var id: Int64?
    var name: String?
    
    func update(from json: [String: Any]) {
        id = (json["id"] as! NSNumber).int64Value
        name = (json["name"] as! String)
    }
    
    // Record overrides
    
    override class var databaseTableName: String {
        return "persons"
    }
    
    required init(row: Row) {
        id = row.value(named: "id")
        name = row.value(named: "name")
        super.init(row: row)
    }
    
    override func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["name"] = name
    }
    
    override func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}


// Synchronizes the persons table with a JSON payload
func synchronizePersons(with jsonString: String, in db: Database) throws {
    let jsonData = jsonString.data(using: .utf8)!
    let json = try JSONSerialization.jsonObject(with: jsonData, options: []) as! [String: Any]
    
    // A support function that extracts an ID from a JSON person.
    func jsonPersonId(_ jsonPerson: [String: Any]) -> Int64 {
        return (jsonPerson["id"] as! NSNumber).int64Value
    }
    
    // Sort JSON persons by id:
    let jsonPersons = (json["persons"] as! [[String: Any]]).sorted {
        return jsonPersonId($0) < jsonPersonId($1)
    }
    
    // Sort database persons by id:
    let persons = try Person.fetchAll(db, "SELECT * FROM persons ORDER BY id")
    
    // Now that both lists are sorted by id, we can compare them with
    // the sortedMerge() function (see https://gist.github.com/groue/7e8510849ded36f7d770).
    //
    // We'll delete, insert or update persons, depending on their presence
    // in either lists.
    for mergeStep in sortedMerge(
        left: persons,          // Database persons
        right: jsonPersons,     // JSON persons
        leftKey: { $0.id! },    // The id of a database person
        rightKey: jsonPersonId) // The id of a JSON person
    {
        switch mergeStep {
        case .left(let person):
            // Delete database person without matching JSON person:
            try person.delete(db)
        case .right(let jsonPerson):
            // Insert JSON person without matching database person:
            let row = Row(jsonPerson)! // Granted JSON keys are database columns
            let person = Person(row: row)
            try person.insert(db)
        case .common(let person, let jsonPerson):
            // Update database person with its JSON counterpart:
            person.update(from: jsonPerson)
            if person.hasPersistentChangedValues {
                try person.update(db)
            }
        }
    }
}

do {
    let jsonString =
    "{ \"persons\": [" +
        "{ \"id\": 1, \"name\": \"Arthur\"}, " +
        "{ \"id\": 2, \"name\": \"Barbara\"}, " +
        "{ \"id\": 3, \"name\": \"Craig\"}, " +
        "]" +
    "}"
    print("---\nImport \(jsonString)")
    try dbQueue.inTransaction { db in
        // SELECT * FROM persons ORDER BY id
        // INSERT INTO "persons" ("id","name") VALUES (1,'Arthur')
        // INSERT INTO "persons" ("id","name") VALUES (2,'Barbara')
        // INSERT INTO "persons" ("id","name") VALUES (3,'Craig')
        try synchronizePersons(with: jsonString, in: db)
        return .commit
    }
}

do {
    let jsonString =
    "{ \"persons\": [" +
        "{ \"id\": 2, \"name\": \"Barbie\"}, " +
        "{ \"id\": 3, \"name\": \"Craig\"}, " +
        "{ \"id\": 4, \"name\": \"Daniel\"}, " +
        "]" +
    "}"
    print("---\nImport \(jsonString)")
    try dbQueue.inTransaction { db in
        // SELECT * FROM persons ORDER BY id
        // DELETE FROM "persons" WHERE "id"=1
        // UPDATE "persons" SET "name"='Barbie' WHERE "id"=2
        // INSERT INTO "persons" ("id","name") VALUES (4,'Daniel')
        try synchronizePersons(with: jsonString, in: db)
        return .commit
    }
}

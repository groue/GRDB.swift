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
    
    func updateFromJSON(json: NSDictionary) {
        id = (json["id"] as? NSNumber)?.longLongValue
        name = json["name"] as? String
    }
    
    // Record overrides
    
    override class func databaseTableName() -> String {
        return "persons"
    }
    
    required init(_ row: Row) {
        id = row.value(named: "id")
        name = row.value(named: "name")
        super.init(row)
    }
    
    override var persistentDictionary: [String: DatabaseValueConvertible?] {
        return ["id": id, "name": name]
    }
    
    override func didInsertWithRowID(rowID: Int64, forColumn column: String?) {
        id = rowID
    }
}


// Synchronizes the persons table with a JSON payload
func synchronizePersonsWithJSON(jsonString: String, inDatabase db: Database) throws {
    let jsonData = jsonString.dataUsingEncoding(NSUTF8StringEncoding)!
    let json = try NSJSONSerialization.JSONObjectWithData(jsonData, options: []) as! NSDictionary
    
    // A support function that extracts an ID from a JSON person.
    func jsonPersonId(jsonPerson: NSDictionary) -> Int64 {
        return (jsonPerson["id"] as! NSNumber).longLongValue
    }
    
    // Sort JSON persons by id:
    let jsonPersons = (json["persons"] as! [NSDictionary]).sort {
        return jsonPersonId($0) < jsonPersonId($1)
    }
    
    // Sort database persons by id:
    let persons = Person.fetchAll(db, "SELECT * FROM persons ORDER BY id")
    
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
        case .Left(let person):
            // Delete database person without matching JSON person:
            try person.delete(db)
        case .Right(let jsonPerson):
            // Insert JSON person without matching database person:
            let row = Row(jsonPerson)! // Granted JSON keys are database columns
            let person = Person(row)
            try person.insert(db)
        case .Common(let person, let jsonPerson):
            // Update database person with its JSON counterpart:
            person.updateFromJSON(jsonPerson)
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
        try synchronizePersonsWithJSON(jsonString, inDatabase: db)
        return .Commit
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
        try synchronizePersonsWithJSON(jsonString, inDatabase: db)
        return .Commit
    }
}

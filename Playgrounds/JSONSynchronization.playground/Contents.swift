// To run this playground, select and build the GRDBOSX scheme.
//
// This sample code shows how to synchronize a database table with a JSON
// payload with as few SQL queries as possible. In particular, useless UPDATE
// statement are avoided.

import Foundation
import GRDB


// Create the databsae

var configuration = Configuration()
configuration.trace = LogSQL
let dbQueue = DatabaseQueue(configuration: configuration)   // Memory database
try dbQueue.inDatabase { db in
    try db.execute(
        "CREATE TABLE persons (" +
            "id INTEGER PRIMARY KEY, " +
            "name TEXT " +
        ")")
}


// Person is a subclass of Record.
//
// We'll use the change tracking granted by the Record class to avoid useless
// UPDATE statements.
class Person : Record {
    var id: Int64?
    var name: String?
    
    override class func databaseTableName() -> String? {
        return "persons"
    }
    
    override func updateFromRow(row: Row) {
        if let dbv = row["id"] { id = dbv.value() }
        if let dbv = row["name"] { name = dbv.value() }
        super.updateFromRow(row) // Subclasses are required to call super.
    }
    
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return ["id": id, "name": name]
    }
}


// Synchronizes the persons table with a JSON payload
func synchronizePersonsWithJSON(jsonString: String, inDatabase db: Database) throws {
    let jsonData = jsonString.dataUsingEncoding(NSUTF8StringEncoding)!
    let json = try NSJSONSerialization.JSONObjectWithData(jsonData, options: []) as! NSDictionary
    
    // A function that extracts an ID from a JSON person.
    func jsonPersonId(jsonPerson: NSDictionary) -> Int64 {
        return (jsonPerson["id"] as! NSNumber).longLongValue
    }
    
    // Sort JSON persons by id:
    let jsonPersons = (json["persons"] as! [NSDictionary]).sort {
        return jsonPersonId($0) < jsonPersonId($1)
    }
    
    // Load database persons, sorted by id.
    let persons = Person.fetchAll(db, "SELECT * FROM persons ORDER BY id")
    
    // Now that both lists are sorted by id, we can compare them with 
    // the sortedMerge() function.
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
            // Database person without matching JSON person:
            try person.delete(db)
        case .Right(let jsonPerson):
            // JSON person without matching database person:
            let row = Row(dictionary: jsonPerson)
            let person = Person(row: row)
            try person.insert(db)
        case .Common(let person, let jsonPerson):
            // Matching database and JSON persons:
            let row = Row(dictionary: jsonPerson)
            person.updateFromRow(row)
            if person.databaseEdited {
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

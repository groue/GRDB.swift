//: Playground - noun: a place where people can play

import GRDB

struct DBDate: SQLiteValueConvertible {
    
    // MARK: - DBDate <-> NSDate conversion
    
    let date: NSDate
    
    // Define a failable initializer in order to consistently use nil as the
    // NULL marker throughout the conversions NSDate <-> DBDate <-> SQLite
    init?(_ date: NSDate?) {
        if let date = date {
            self.date = date
        } else {
            return nil
        }
    }
    
    // MARK: - DBDate <-> SQLiteValue conversion
    
    var sqliteValue: SQLiteValue {
        return .Real(date.timeIntervalSince1970)
    }
    
    init?(sqliteValue: SQLiteValue) {
        // Don't handle the raw SQLiteValue unless you know what you do.
        // It is recommended to use GRDB built-in conversions instead:
        if let timestamp = Double(sqliteValue: sqliteValue) {
            self.init(NSDate(timeIntervalSince1970: timestamp))
        } else {
            return nil
        }
    }
}

class Person: RowModel {
    var id: Int64?
    var name: String?
    var age: Int?
    var creationDate: NSDate?
    
    override class var databaseTableName: String? {
        return "persons"
    }
    
    override class var databasePrimaryKey: PrimaryKey {
        return .SQLiteRowID("id")
    }
    
    override var databaseDictionary: [String: SQLiteValueConvertible?] {
        return [
            "id": id,
            "name": name,
            "age": age,
            "creationTimestamp": DBDate(creationDate),
        ]
    }
    
    override func updateFromDatabaseRow(row: Row) {
        if row.hasColumn("id") { id = row.value(named: "id") }
        if row.hasColumn("name") { name = row.value(named: "name") }
        if row.hasColumn("age") { age = row.value(named: "age") }
        if row.hasColumn("creationTimestamp") {
            let dbDate: DBDate? = row.value(named: "creationTimestamp")
            creationDate = dbDate?.date
        }
    }
    
    override func insert(db: Database) throws {
        if creationDate == nil {
            creationDate = NSDate()
        }
        
        try super.insert(db)
    }
    
    init (name: String? = nil, age: Int? = nil) {
        self.name = name
        self.age = age
        super.init()
    }
    
    required init(row: Row) {
        super.init(row: row)
    }
    
    static func setupDatabase(db: Database) throws {
        try db.execute(
            "CREATE TABLE persons (" +
                "id INTEGER PRIMARY KEY, " +
                "name TEXT, " +
                "creationTimestamp DOUBLE" +
            ")")
    }
}

class Pet: RowModel {
    var UUID: String?
    var masterID: Int64?
    var name: String?
    
    override class var databaseTableName: String? {
        return "pets"
    }
    
    override class var databasePrimaryKey: PrimaryKey {
        return .Single("UUID")
    }
    
    override var databaseDictionary: [String: SQLiteValueConvertible?] {
        return ["UUID": UUID, "name": name, "masterID": masterID]
    }
    
    override func updateFromDatabaseRow(row: Row) {
        if row.hasColumn("UUID") { UUID = row.value(named: "UUID") }
        if row.hasColumn("name") { name = row.value(named: "name") }
        if row.hasColumn("masterID") { masterID = row.value(named: "masterID") }
    }
    
    init (UUID: String? = nil, name: String? = nil, masterID: Int64? = nil) {
        self.UUID = UUID
        self.name = name
        self.masterID = masterID
        super.init()
    }
    
    required init(row: Row) {
        super.init(row: row)
    }
    
    override func insert(db: Database) throws {
        if UUID == nil {
            UUID = NSUUID().UUIDString
        }
        
        try super.insert(db)
    }
    
    static func setupDatabase(db: Database) throws {
        try db.execute(
            "CREATE TABLE pets (" +
                "UUID TEXT NOT NULL PRIMARY KEY, " +
                "masterID INTEGER NOT NULL " +
                "         REFERENCES persons(ID) " +
                "         ON DELETE CASCADE ON UPDATE CASCADE, " +
                "name TEXT" +
            ")")
    }
}

let dbQueue = try DatabaseQueue()

let p = Person()

var migrator = DatabaseMigrator()
migrator.registerMigration("createPersons", Person.setupDatabase)
migrator.registerMigration("createPets", Pet.setupDatabase)
try migrator.migrate(dbQueue)

let arthur = Person(name: "Arthur", age: 41)
let barbara = Person(name: "Barbara", age: 27)

try dbQueue.inTransaction { db in
    try arthur.save(db)
    try barbara.save(db)
    return .Commit
}

let bobby = Pet(name: "Bobby", masterID: arthur.id)

try dbQueue.inTransaction { db in
    try bobby.save(db)
    return .Commit
}

let (persons, pets) = dbQueue.inDatabase { db in
    (db.fetchAll(Person.self, "SELECT * FROM persons"),
     db.fetchAll(Pet.self, "SELECT * FROM pets"))
}

persons.count
pets.count

for person in persons {
    print(person)
}
for pet in pets {
    print(pet)
}

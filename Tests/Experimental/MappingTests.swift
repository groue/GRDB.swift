//import XCTest
//import GRDB
//
//// Taking inspiration from https://github.com/LoganWright/Genome
//
//class Mapping {
//    enum Direction {
//        case Fetch(Row)
//        case Save
//    }
//    let direction: Direction
//    var dictionary: [String: DatabaseValueConvertible?] = [:]
//    init() {
//        direction = .Save
//    }
//    init(row: Row) {
//        direction = .Fetch(row)
//    }
//    subscript(name: String) -> Binding {
//        switch direction {
//        case .Save:
//            return Binding(
//                name: name,
//                direction: .Save({ (value: DatabaseValueConvertible?) in
//                    self.dictionary[name] = value
//                }))
//        case .Fetch(let row):
//            return Binding(name: name, direction: .Fetch(row[name]))
//        }
//    }
//}
//
//class Binding {
//    enum Direction {
//        case Fetch(DatabaseValue?)
//        case Save((DatabaseValueConvertible?) -> ())
//    }
//    let name: String
//    let direction: Direction
//    
//    init(name: String, direction: Direction) {
//        self.name = name
//        self.direction = direction
//    }
//    
//    func bind<Value: DatabaseValueConvertible>(inout value: Value) {
//        switch direction {
//        case .Fetch(let databaseValue):
//            if let databaseValue = databaseValue {
//                value = Value.fromDatabaseValue(databaseValue)!
//            }
//        case .Save(let f):
//            f(value)
//        }
//    }
//    
//    func bind<Value: DatabaseValueConvertible>(inout value: Value?) {
//        switch direction {
//        case .Fetch(let databaseValue):
//            if let databaseValue = databaseValue {
//                value = Value.fromDatabaseValue(databaseValue)
//            }
//        case .Save(let f):
//            f(value)
//        }
//    }
//    
//    func bind<Value: DatabaseValueConvertible>(inout value: Value!) {
//        switch direction {
//        case .Fetch(let databaseValue):
//            if let databaseValue = databaseValue {
//                value = Value.fromDatabaseValue(databaseValue)
//            }
//        case .Save(let f):
//            f(value)
//        }
//    }
//}
//
//infix operator <-> { associativity left precedence 160 }
//func <-><Value: DatabaseValueConvertible>(inout value: Value, binding: Binding) {
//    binding.bind(&value)
//}
//func <-><Value: DatabaseValueConvertible>(inout value: Value?, binding: Binding) {
//    binding.bind(&value)
//}
//func <-><Value: DatabaseValueConvertible>(inout value: Value!, binding: Binding) {
//    binding.bind(&value)
//}
//
//
//
//class MappedRecord : Record {
//    var id: Int64!
//    var firstName: String?
//    var lastName: String?
//    var fullName: String {
//        return [firstName, lastName].flatMap { $0 }.joined(separator: " ")
//    }
//    
//    init(firstName: String? = nil, lastName: String? = nil) {
//        self.firstName = firstName
//        self.lastName = lastName
//        super.init()
//    }
//    
//    // The experiment:
//    
//    func map(mapping: Mapping) {
//        id <-> mapping["id"]
//        firstName <-> mapping["firstName"]
//        lastName <-> mapping["lastName"]
//    }
//    
//    // Record overrides
//    
//    override class var databaseTableName: String {
//        return "persons"
//    }
//    
//    override func updateFromRow(row: Row) {
//        map(Mapping(row: row))
//        super.updateFromRow(row) // Subclasses are required to call super.
//    }
//    
//    override var persistentDictionary: [String: DatabaseValueConvertible?] {
//        let mapping = Mapping()
//        map(mapping)
//        return mapping.dictionary
//    }
//    
//    required init(row: Row) {
//        super.init(row: row)
//    }
//}
//
//
//class MappingTests: GRDBTestCase {
//
//    func testExample() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try db.execute("CREATE TABLE persons (" +
//                    "id INTEGER PRIMARY KEY, " +
//                    "firstName TEXT, " +
//                    "lastName TEXT" +
//                    ")")
//                
//                try MappedRecord(firstName: "Arthur", lastName: "Miller").insert(db)
//                try MappedRecord(firstName: "Barbra", lastName: "Streisand").insert(db)
//                try MappedRecord(firstName: "Cinderella").insert(db)
//                
//                let records = MappedRecord.fetchAll(db, "SELECT * FROM persons ORDER BY firstName, lastName")
//                
//                print(records)
//                print(records.map { $0.fullName })
//            
//            }
//        }
//    }
//}

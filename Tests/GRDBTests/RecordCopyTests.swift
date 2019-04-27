import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private class Person : Record {
    var id: Int64!
    var name: String!
    var age: Int?
    var creationDate: Date
    
    init(id: Int64?, name: String?, age: Int?, creationDate: Date) {
        self.id = id
        self.name = name
        self.age = age
        self.creationDate = creationDate
        super.init()
    }
    
    // Record
    
    required init(row: Row) {
        id = row["id"]
        age = row["age"]
        name = row["name"]
        creationDate = row["creationDate"]
        super.init(row: row)
    }
    
    override func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["name"] = name
        container["age"] = age
        container["creationDate"] = creationDate
    }
}

class RecordCopyTests: GRDBTestCase {
    
    func testRecordCopy() {
        let person1 = Person(id: 123, name: "Arthur", age: 41, creationDate: Date())
        let person2 = person1.copy()
        XCTAssertTrue(person2.id == person1.id)
        XCTAssertTrue(person2.name == person1.name)
        XCTAssertTrue(person2.age == person1.age)
        XCTAssertTrue(abs(person2.creationDate.timeIntervalSince(person1.creationDate)) < 1e-3)
    }
}

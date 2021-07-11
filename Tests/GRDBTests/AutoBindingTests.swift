import XCTest
import GRDB

private struct Student: FetchableRecord, MutablePersistableRecord, Codable {
    static let databaseTableName = "student"
    
    var studentId: Int?
    var firstName: String
    var lastName: String
    
    init(studentId: Int? = nil, firstName: String, lastName: String) {
        self.studentId = studentId
        self.firstName = firstName
        self.lastName = lastName
    }
    
    mutating func didInsert(with rowID: Int64, for column: String?) {
        studentId = Int(rowID)
    }
}

class AutoBindingTests: GRDBTestCase {

    override func setup(_ dbWriter: DatabaseWriter) throws {
        try dbWriter.write { db in
            try db.create(table: "student") { t in
                t.column("student_id", .integer).primaryKey()
                t.column("first_name", .text)
                t.column("last_name", .text)
            }
            try! db.execute(sql: "INSERT INTO student (first_name, last_name) VALUES ('A', 'B')")
            try! db.execute(sql: "INSERT INTO student (first_name, last_name) VALUES ('C', 'D')")
        }
    }
    
    func testFetchAll() throws {
        let dbQueue = try makeDatabaseQueue()
        dbQueue.inDatabase { db in
            let rows = try! Student.fetchAll(db)
            XCTAssertEqual(rows.count, 2)
        }
    }
    
    func testFetchOne() throws {
        let dbQueue = try makeDatabaseQueue()
        dbQueue.inDatabase { db in
            let student = try! Student.fetchOne(db, key: 1)
            XCTAssertNotNil(student)
        }
    }
    
    func testInsert() throws {
        let dbQueue = try makeDatabaseQueue()
        var student = Student(firstName: "Michael", lastName: "Chen")
        dbQueue.inDatabase { db in
            try! student.insert(db)
            XCTAssertNotNil(student.studentId)
        }
    }
    
    func testUpdate() throws {
        let dbQueue = try makeDatabaseQueue()
        let student = Student(studentId: 1, firstName: "AA", lastName: "BB")
        dbQueue.inDatabase { db in
            try! student.update(db)
            let row = try! Student.fetchOne(db, key: 1)
            XCTAssertNotNil(row)
            XCTAssertEqual(row?.firstName, "AA")
            XCTAssertEqual(row?.lastName, "BB")
        }
    }
    
    func testDelete() throws {
        let dbQueue = try makeDatabaseQueue()
        let student = Student(studentId: 1, firstName: "", lastName: "")
        dbQueue.inDatabase { db in
            try! student.delete(db)
            let row = try! Student.fetchOne(db, key: 1)
            XCTAssertNil(row)
        }
    }
}

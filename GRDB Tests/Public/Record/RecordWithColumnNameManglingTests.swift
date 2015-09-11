import XCTest
import GRDB

class WrongMangling : Record {
    var id: Int64?
    var name: String?
    
    override static func databaseTableName() -> String {
        return "mangles"
    }
    
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        // User won't peek fancy column names, here, because he will notice that
        // the generated INSERT query uses exactly those names:
        return ["id": id, "name": name]
    }
    
    override func updateFromRow(row: Row) {
        // Here user may peed fancy column names that match his SQL queries.
        // However this is not the way to do it.
        if let dbv = row["mangled_id"] { id = dbv.value() }
        if let dbv = row["mangled_name"] { name = dbv.value() }
        super.updateFromRow(row)
    }
}

class GoodMangling : Record {
    var id: Int64?
    var name: String?
    
    override static func databaseTableName() -> String {
        return "mangles"
    }
    
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        // Regular column names
        return ["id": id, "name": name]
    }
    
    override func updateFromRow(row: Row) {
        // Regular column names
        if let dbv = row["id"] { id = dbv.value() }
        if let dbv = row["name"] { name = dbv.value() }
        super.updateFromRow(row)
    }
}

class RecordWithColumnNameManglingTests: GRDBTestCase {
    
    func testWrongMangling() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE mangles (id INTEGER PRIMARY KEY, name TEXT)")
                do {
                    let record = WrongMangling()
                    record.name = "foo"
                    try record.save(db)
                    XCTAssertFalse(record.databaseEdited)
                }
                do {
                    let record = WrongMangling.fetchOne(db, "SELECT id AS mangled_id, name AS mangled_name FROM mangles")!
                    XCTAssertEqual(record.id, 1)
                    XCTAssertEqual(record.name, "foo")
                    XCTAssertTrue(record.databaseEdited)    // Here lies the problem with WrongMangling.
                }
            }
        }
    }
    
    func testGoodMangling() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE mangles (id INTEGER PRIMARY KEY, name TEXT)")
                do {
                    let record = GoodMangling()
                    record.name = "foo"
                    try record.save(db)
                    XCTAssertFalse(record.databaseEdited)
                }
                do {
                    let record = GoodMangling.fetchOne(db, "SELECT id AS mangled_id, name AS mangled_name FROM mangles")!
                    XCTAssertEqual(record.id, 1)
                    XCTAssertEqual(record.name, "foo")
                    XCTAssertFalse(record.databaseEdited)    // GoodMangling does it better.
                }
            }
        }
    }
    
}

import XCTest
import GRDB

// BadlyMangledStuff.updateFromRow() accepts a row with mangled column names.
// Its databaseEdited flag is wrong.
class BadlyMangledStuff : Record {
    var id: Int64?
    var name: String?
    
    override static func databaseTableName() -> String {
        return "stuffs"
    }
    
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        // User won't peek fancy column names because he will notice that the
        // generated INSERT query needs actual column names.
        return ["id": id, "name": name]
    }
    
    override func updateFromRow(row: Row) {
        // Here user may peek fancy column names that match his SQL queries.
        // However this is not the way to do it (see testBadlyMangledStuff()).
        if let dbv = row["mangled_id"] { id = dbv.value() }
        if let dbv = row["mangled_name"] { name = dbv.value() }
        super.updateFromRow(row)
    }
    
    static func setupInDatabase(db: Database) throws {
        try db.execute("CREATE TABLE stuffs (id INTEGER PRIMARY KEY, name TEXT)")
    }
}

class RecordWithColumnNameManglingTests: GRDBTestCase {
    
    override func setUp() {
        super.setUp()
        
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createBadlyMangledStuff", BadlyMangledStuff.setupInDatabase)
        assertNoError {
            try migrator.migrate(dbQueue)
        }
    }
    
    func testBadlyMangledStuff() {
        assertNoError {
            try dbQueue.inDatabase { db in
                do {
                    let record = BadlyMangledStuff()
                    record.name = "foo"
                    try record.save(db)
                    
                    // Nothing special here
                    XCTAssertFalse(record.databaseEdited)
                }
                do {
                    let record = BadlyMangledStuff.fetchOne(db, "SELECT id AS mangled_id, name AS mangled_name FROM stuffs")!
                    // OK we could extract values.
                    XCTAssertEqual(record.id, 1)
                    XCTAssertEqual(record.name, "foo")
                    
                    // But here lies the problem with BadlyMangledStuff.
                    // It should not be edited:
                    XCTAssertTrue(record.databaseEdited)
                }
            }
        }
    }
}

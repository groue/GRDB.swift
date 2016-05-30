import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

// BadlyMangledStuff.updateFromRow() accepts a row with mangled column names.
// Its hasPersistentChangedValues flag is wrong.
class BadlyMangledStuff : Record {
    var id: Int64?
    var name: String?
    
    init(id: Int64? = nil, name: String? = nil) {
        self.id = id
        self.name = name
        super.init()
    }
    
    static func setupInDatabase(db: Database) throws {
        try db.execute("CREATE TABLE stuffs (id INTEGER PRIMARY KEY, name TEXT)")
    }
    
    // Record
    
    override static func databaseTableName() -> String {
        return "stuffs"
    }
    
    required init(_ row: Row) {
        // Here user may peek fancy column names that match his SQL queries.
        // However this is not the way to do it (see testBadlyMangledStuff()).
        id = row.value(named: "mangled_id")
        name = row.value(named: "mangled_name")
        super.init(row)
    }
    
    override var persistentDictionary: [String: DatabaseValueConvertible?] {
        // User won't peek fancy column names because he will notice that the
        // generated INSERT query needs actual column names.
        return ["id": id, "name": name]
    }
    
    override func didInsertWithRowID(rowID: Int64, forColumn column: String?) {
        self.id = rowID
    }
}

class RecordWithColumnNameManglingTests: GRDBTestCase {
    
    override func setUpDatabase(dbWriter: DatabaseWriter) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createBadlyMangledStuff", migrate: BadlyMangledStuff.setupInDatabase)
        try migrator.migrate(dbWriter)
    }
    
    func testBadlyMangledStuff() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                do {
                    let record = BadlyMangledStuff()
                    record.name = "foo"
                    try record.save(db)
                    
                    // Nothing special here
                    XCTAssertFalse(record.hasPersistentChangedValues)
                }
                do {
                    let record = BadlyMangledStuff.fetchOne(db, "SELECT id AS mangled_id, name AS mangled_name FROM stuffs")!
                    // OK we could extract values.
                    XCTAssertEqual(record.id, 1)
                    XCTAssertEqual(record.name, "foo")
                    
                    // But here lies the problem with BadlyMangledStuff.
                    // It should not be edited:
                    XCTAssertTrue(record.hasPersistentChangedValues)
                }
            }
        }
    }
}

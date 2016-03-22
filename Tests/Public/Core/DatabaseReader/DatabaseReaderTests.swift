import XCTest
import GRDB

#if os(OSX)
    import SQLiteMacOSX
#elseif os(iOS)
#if (arch(i386) || arch(x86_64))
    import SQLiteiPhoneSimulator
    #else
    import SQLiteiPhoneOS
#endif
#endif

// A type that adopts DatabaseValueConvertible but does not adopt StatementColumnConvertible
private struct WrappedInt: DatabaseValueConvertible {
    let int: Int
    init(int: Int) {
        self.int = int
    }
    var databaseValue: DatabaseValue {
        return int.databaseValue
    }
    static func fromDatabaseValue(databaseValue: DatabaseValue) -> WrappedInt? {
        guard let int = Int.fromDatabaseValue(databaseValue) else {
            return nil
        }
        return WrappedInt(int: int)
    }
}

// A type that adopts DatabaseValueConvertible and StatementColumnConvertible
private struct FastWrappedInt: DatabaseValueConvertible, StatementColumnConvertible {
    let int: Int
    let fast: Bool
    
    init(int: Int, fast: Bool) {
        self.int = int
        self.fast = fast
    }
    
    init(sqliteStatement: SQLiteStatement, index: Int32) {
        self.init(int: Int(sqlite3_column_int64(sqliteStatement, index)), fast: true)
    }
    
    var databaseValue: DatabaseValue {
        return int.databaseValue
    }
    
    static func fromDatabaseValue(databaseValue: DatabaseValue) -> FastWrappedInt? {
        guard let int = Int.fromDatabaseValue(databaseValue) else {
            return nil
        }
        return FastWrappedInt(int: int, fast: false)
    }
}

private struct Item: RowConvertible, TableMapping {
    let id: Int64
    
    static func databaseTableName() -> String {
        return "items"
    }
    
    init(_ row: Row) {
        self.id = row.value(named: "id")
    }
}

class DatabaseReaderTests : GRDBTestCase {
    
    func testDatabaseValueConvertibleFetch() {
        XCTAssertEqual(WrappedInt.fetchOne(dbQueue, "SELECT 123")!.int, 123)
        XCTAssertEqual(WrappedInt.fetchAll(dbQueue, "SELECT 123 UNION SELECT 321").map { $0.int }, [123, 321])
        
        XCTAssertEqual(WrappedInt.fetchOne(dbPool, "SELECT 123")!.int, 123)
        XCTAssertEqual(WrappedInt.fetchAll(dbPool, "SELECT 123 UNION SELECT 321").map { $0.int }, [123, 321])
        
        dbQueue.inDatabase { db in
            XCTAssertEqual(WrappedInt.fetchOne(db, "SELECT 123")!.int, 123)
            XCTAssertEqual(WrappedInt.fetchAll(db, "SELECT 123 UNION SELECT 321").map { $0.int }, [123, 321])
        }
    }
    
    func testStatementColumnConvertibleFetch() {
        XCTAssertEqual(FastWrappedInt.fetchOne(dbQueue, "SELECT 123")!.int, 123)
        XCTAssertEqual(FastWrappedInt.fetchAll(dbQueue, "SELECT 123 UNION SELECT 321").map { $0.int }, [123, 321])
        
        XCTAssertEqual(FastWrappedInt.fetchOne(dbPool, "SELECT 123")!.int, 123)
        XCTAssertEqual(FastWrappedInt.fetchAll(dbPool, "SELECT 123 UNION SELECT 321").map { $0.int }, [123, 321])
        
        dbQueue.inDatabase { db in
            XCTAssertEqual(FastWrappedInt.fetchOne(db, "SELECT 123")!.int, 123)
            XCTAssertEqual(FastWrappedInt.fetchAll(db, "SELECT 123 UNION SELECT 321").map { $0.int }, [123, 321])
        }
    }
    
    func testRowConvertibleFetch() {
        XCTAssertEqual(Item.fetchOne(dbQueue, "SELECT 123 AS id")!.id, 123)
        XCTAssertEqual(Item.fetchAll(dbQueue, "SELECT 123 AS id UNION SELECT 321").map { $0.id }, [123, 321])
        
        XCTAssertEqual(Item.fetchOne(dbPool, "SELECT 123 AS id")!.id, 123)
        XCTAssertEqual(Item.fetchAll(dbPool, "SELECT 123 AS id UNION SELECT 321").map { $0.id }, [123, 321])
        
        dbQueue.inDatabase { db in
            XCTAssertEqual(Item.fetchOne(db, "SELECT 123 AS id")!.id, 123)
            XCTAssertEqual(Item.fetchAll(db, "SELECT 123 AS id UNION SELECT 321").map { $0.id }, [123, 321])
        }
    }
    
    func testTableMappingFetch() {
        let populateDatabase = { (db: Database) -> () in
            try db.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
            try db.execute("INSERT INTO items (id) VALUES (NULL)")
            try db.execute("INSERT INTO items (id) VALUES (NULL)")
        }
        assertNoError {
            try dbQueue.inDatabase { db in try populateDatabase(db) }
            try dbPool.write { db in try populateDatabase(db) }
        }
        
        XCTAssertEqual(Item.fetchOne(dbQueue, key: 1)!.id, 1)
        XCTAssertEqual(Item.fetchAll(dbQueue, keys: [1, 2]).map { $0.id }, [1, 2])
        
        XCTAssertEqual(Item.fetchOne(dbPool, key: 1)!.id, 1)
        XCTAssertEqual(Item.fetchAll(dbPool, keys: [1, 2]).map { $0.id }, [1, 2])
        
        dbQueue.inDatabase { db in
            XCTAssertEqual(Item.fetchOne(db, key: 1)!.id, 1)
            XCTAssertEqual(Item.fetchAll(db, keys: [1, 2]).map { $0.id }, [1, 2])
        }
    }
    
    func testFetchRequestFetch() {
        let populateDatabase = { (db: Database) -> () in
            try db.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
            try db.execute("INSERT INTO items (id) VALUES (NULL)")
            try db.execute("INSERT INTO items (id) VALUES (NULL)")
        }
        assertNoError {
            try dbQueue.inDatabase { db in try populateDatabase(db) }
            try dbPool.write { db in try populateDatabase(db) }
        }
        
        let idCol = SQLColumn("id")
        
        XCTAssertEqual(Item.filter(idCol == 1).fetchOne(dbQueue)!.id, 1)
        XCTAssertEqual(Item.all().fetchAll(dbQueue).map { $0.id }, [1, 2])
        XCTAssertEqual(Item.filter(idCol == 1).fetchCount(dbQueue), 1)
        
        XCTAssertEqual(Item.filter(idCol == 1).fetchOne(dbPool)!.id, 1)
        XCTAssertEqual(Item.all().fetchAll(dbPool).map { $0.id }, [1, 2])
        XCTAssertEqual(Item.filter(idCol == 1).fetchCount(dbPool), 1)
        
        dbQueue.inDatabase { db in
            XCTAssertEqual(Item.filter(idCol == 1).fetchOne(db)!.id, 1)
            XCTAssertEqual(Item.all().fetchAll(db).map { $0.id }, [1, 2])
            XCTAssertEqual(Item.filter(idCol == 1).fetchCount(db), 1)
        }
    }
    
}

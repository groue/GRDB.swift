import XCTest
import GRDB

// A type that adopts DatabaseValueConvertible and SQLiteStatementConvertible
struct FastWrappedInt: DatabaseValueConvertible, SQLiteStatementConvertible {
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

class SQLiteStatementConvertibleFetchTests: GRDBTestCase {
    
    func testSlowConversion() {
        let slow = FastWrappedInt.fromDatabaseValue(0.databaseValue)!
        XCTAssertEqual(slow.int, 0)
        XCTAssertEqual(slow.fast, false)
    }
    
    func testRowExtractionIsFast() {
        assertNoError {
            dbQueue.inDatabase { db in
                for row in Row.fetch(db, "SELECT NULL") {
                    let one: FastWrappedInt? = row.value(atIndex: 0)
                    XCTAssertTrue(one == nil)
                }
                for row in Row.fetch(db, "SELECT 1") {
                    let one: FastWrappedInt? = row.value(atIndex: 0)
                    XCTAssertEqual(one!.int, 1)
                    XCTAssertEqual(one!.fast, true)
                }
                for row in Row.fetch(db, "SELECT 1 AS int") {
                    let one: FastWrappedInt? = row.value(named: "int")
                    XCTAssertEqual(one!.int, 1)
                    XCTAssertEqual(one!.fast, true)
                }
                for row in Row.fetch(db, "SELECT 1") {
                    let one: FastWrappedInt = row.value(atIndex: 0)
                    XCTAssertEqual(one.int, 1)
                    XCTAssertEqual(one.fast, true)
                }
                for row in Row.fetch(db, "SELECT 1 AS int") {
                    let one: FastWrappedInt = row.value(named: "int")
                    XCTAssertEqual(one.int, 1)
                    XCTAssertEqual(one.fast, true)
                }
            }
        }
    }
    
    func testFetchFromStatementIsFast() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (2)")
                
                let statement = try db.selectStatement("SELECT int FROM ints ORDER BY int")
                let sequence = FastWrappedInt.fetch(statement)
                
                XCTAssertEqual(Array(sequence).map { $0.int }, [1,2])
                XCTAssertEqual(Array(sequence).map { $0.fast }, [true, true])
            }
        }
    }
    
    func testFetchAllFromStatementIsFast() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (2)")
                
                let statement = try db.selectStatement("SELECT int FROM ints ORDER BY int")
                let array = FastWrappedInt.fetchAll(statement)
                
                XCTAssertEqual(array.map { $0.int }, [1,2])
                XCTAssertEqual(array.map { $0.fast }, [true, true])
            }
        }
    }
    
    func testFetchOneFromStatementIsFast() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                let statement = try db.selectStatement("SELECT int FROM ints ORDER BY int")
                
                let nilBecauseMissingRow = FastWrappedInt.fetchOne(statement)
                XCTAssertTrue(nilBecauseMissingRow == nil)
                
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                let nilBecauseMissingNULL = FastWrappedInt.fetchOne(statement)
                XCTAssertTrue(nilBecauseMissingNULL == nil)
                
                try db.execute("DELETE FROM ints")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                let one = FastWrappedInt.fetchOne(statement)!
                XCTAssertEqual(one.int, 1)
                XCTAssertEqual(one.fast, true)
            }
        }
    }
    
    func testFetchFromDatabaseIsFast() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (2)")
                
                let sequence = FastWrappedInt.fetch(db, "SELECT int FROM ints ORDER BY int")
                
                XCTAssertEqual(Array(sequence).map { $0.int }, [1,2])
                XCTAssertEqual(Array(sequence).map { $0.fast }, [true, true])
            }
        }
    }
    
    func testFetchAllFromDatabaseIsFast() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (2)")
                
                let array = FastWrappedInt.fetchAll(db, "SELECT int FROM ints ORDER BY int")
                
                XCTAssertEqual(array.map { $0.int }, [1,2])
                XCTAssertEqual(array.map { $0.fast }, [true, true])
            }
        }
    }
    
    func testFetchOneFromDatabaseIsFast() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                
                let nilBecauseMissingRow = FastWrappedInt.fetchOne(db, "SELECT int FROM ints ORDER BY int")
                XCTAssertTrue(nilBecauseMissingRow == nil)
                
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                let nilBecauseMissingNULL = FastWrappedInt.fetchOne(db, "SELECT int FROM ints ORDER BY int")
                XCTAssertTrue(nilBecauseMissingNULL == nil)
                
                try db.execute("DELETE FROM ints")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                let one = FastWrappedInt.fetchOne(db, "SELECT int FROM ints ORDER BY int")!
                XCTAssertEqual(one.int, 1)
                XCTAssertEqual(one.fast, true)
            }
        }
    }
    
    func testOptionalFetchFromStatementIsFast() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                
                let statement = try db.selectStatement("SELECT int FROM ints ORDER BY int")
                let sequence = Optional<FastWrappedInt>.fetch(statement)
                
                let ints = Array(sequence)
                XCTAssertEqual(ints.count, 2)
                XCTAssertTrue(ints[0] == nil)
                XCTAssertEqual(ints[1]!.int, 1)
                // TODO: uncomment when we have a workaround for rdar://22852669
//                XCTAssertEqual(ints[1]!.fast, true)
            }
        }
    }
    
    func testOptionalFetchAllFromStatementIsFast() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                
                let statement = try db.selectStatement("SELECT int FROM ints ORDER BY int")
                let array = Optional<FastWrappedInt>.fetchAll(statement)
                
                XCTAssertEqual(array.count, 2)
                XCTAssertTrue(array[0] == nil)
                XCTAssertEqual(array[1]!.int, 1)
                // TODO: uncomment when we have a workaround for rdar://22852669
//                XCTAssertEqual(array[1]!.fast, true)
            }
        }
    }
    
    func testOptionalFetchFromDatabaseIsFast() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                
                let sequence = Optional<FastWrappedInt>.fetch(db, "SELECT int FROM ints ORDER BY int")
                
                let ints = Array(sequence)
                XCTAssertEqual(ints.count, 2)
                XCTAssertTrue(ints[0] == nil)
                XCTAssertEqual(ints[1]!.int, 1)
                // TODO: uncomment when we have a workaround for rdar://22852669
//                XCTAssertEqual(ints[1]!.fast, true)
            }
        }
    }
    
    func testOptionalFetchAllFromDatabaseIsFast() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                
                let array = Optional<FastWrappedInt>.fetchAll(db, "SELECT int FROM ints ORDER BY int")
                
                XCTAssertEqual(array.count, 2)
                XCTAssertTrue(array[0] == nil)
                XCTAssertEqual(array[1]!.int, 1)
                // TODO: uncomment when we have a workaround for rdar://22852669
//                XCTAssertEqual(array[1]!.fast, true)
            }
        }
    }
}

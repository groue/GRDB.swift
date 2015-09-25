import XCTest
import GRDB

class SQLiteStatementConvertibleFetchTests: GRDBTestCase {
    
    func testFetchFromStatement() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (2)")
                
                let statement = db.selectStatement("SELECT int FROM ints ORDER BY int")
                let sequence = Int.fetch(statement)
                
                XCTAssertEqual(Array(sequence), [1,2])
            }
        }
    }
    
    func testFetchAllFromStatement() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (2)")
                
                let statement = db.selectStatement("SELECT int FROM ints ORDER BY int")
                let array = Int.fetchAll(statement)
                
                XCTAssertEqual(array, [1,2])
            }
        }
    }
    
    func testFetchOneFromStatement() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                let statement = db.selectStatement("SELECT int FROM ints ORDER BY int")
                
                let nilBecauseMissingRow = Int.fetchOne(statement)
                XCTAssertTrue(nilBecauseMissingRow == nil)
                
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                let nilBecauseMissingNULL = Int.fetchOne(statement)
                XCTAssertTrue(nilBecauseMissingNULL == nil)
                
                try db.execute("DELETE FROM ints")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                let one = Int.fetchOne(statement)!
                XCTAssertEqual(one, 1)
            }
        }
    }
    
    func testFetchFromDatabaes() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (2)")
                
                let sequence = Int.fetch(db, "SELECT int FROM ints ORDER BY int")
                
                XCTAssertEqual(Array(sequence), [1,2])
            }
        }
    }
    
    func testFetchAllFromDatabase() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (2)")
                
                let array = Int.fetchAll(db, "SELECT int FROM ints ORDER BY int")
                
                XCTAssertEqual(array, [1,2])
            }
        }
    }
    
    func testFetchOneFromDatabase() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                
                let nilBecauseMissingRow = Int.fetchOne(db, "SELECT int FROM ints ORDER BY int")
                XCTAssertTrue(nilBecauseMissingRow == nil)
                
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                let nilBecauseMissingNULL = Int.fetchOne(db, "SELECT int FROM ints ORDER BY int")
                XCTAssertTrue(nilBecauseMissingNULL == nil)
                
                try db.execute("DELETE FROM ints")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                let one = Int.fetchOne(db, "SELECT int FROM ints ORDER BY int")!
                XCTAssertEqual(one, 1)
            }
        }
    }
    
    func testOptionalFetchFromStatement() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                
                let statement = db.selectStatement("SELECT int FROM ints ORDER BY int")
                let sequence = Optional<Int>.fetch(statement)
                
                let ints = Array(sequence)
                XCTAssertEqual(ints.count, 2)
                XCTAssertTrue(ints[0] == nil)
                XCTAssertEqual(ints[1]!, 1)
            }
        }
    }
    
    func testOptionalFetchAllFromStatement() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                
                let statement = db.selectStatement("SELECT int FROM ints ORDER BY int")
                let array = Optional<Int>.fetchAll(statement)
                
                XCTAssertEqual(array.count, 2)
                XCTAssertTrue(array[0] == nil)
                XCTAssertEqual(array[1]!, 1)
            }
        }
    }
    
    func testOptionalFetchFromDatabaes() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                
                let sequence = Optional<Int>.fetch(db, "SELECT int FROM ints ORDER BY int")
                
                let ints = Array(sequence)
                XCTAssertEqual(ints.count, 2)
                XCTAssertTrue(ints[0] == nil)
                XCTAssertEqual(ints[1]!, 1)
            }
        }
    }
    
    func testOptionalFetchAllFromDatabase() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                
                let array = Optional<Int>.fetchAll(db, "SELECT int FROM ints ORDER BY int")
                
                XCTAssertEqual(array.count, 2)
                XCTAssertTrue(array[0] == nil)
                XCTAssertEqual(array[1]!, 1)
            }
        }
    }
}

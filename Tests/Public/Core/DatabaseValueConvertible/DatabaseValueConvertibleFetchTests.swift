import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
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

class DatabaseValueConvertibleFetchTests: GRDBTestCase {
    
    func testFetchFromStatement() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (2)")
                
                let statement = try db.selectStatement("SELECT int FROM ints ORDER BY int")
                let sequence = WrappedInt.fetch(statement)
                
                XCTAssertEqual(sequence.map { $0.int }, [1,2])
            }
        }
    }
    
    func testFetchAllFromStatement() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (2)")
                
                let statement = try db.selectStatement("SELECT int FROM ints ORDER BY int")
                let array = WrappedInt.fetchAll(statement)
                
                XCTAssertEqual(array.map { $0.int }, [1,2])
            }
        }
    }
    
    func testFetchOneFromStatement() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                let statement = try db.selectStatement("SELECT int FROM ints ORDER BY int")
                
                let nilBecauseMissingRow = WrappedInt.fetchOne(statement)
                XCTAssertTrue(nilBecauseMissingRow == nil)
                
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                let nilBecauseMissingNULL = WrappedInt.fetchOne(statement)
                XCTAssertTrue(nilBecauseMissingNULL == nil)
                
                try db.execute("DELETE FROM ints")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                let one = WrappedInt.fetchOne(statement)!
                XCTAssertEqual(one.int, 1)
            }
        }
    }
    
    func testFetchFromDatabase() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (2)")
                
                let sequence = WrappedInt.fetch(db, "SELECT int FROM ints ORDER BY int")
                
                XCTAssertEqual(sequence.map { $0.int }, [1,2])
            }
        }
    }
    
    func testFetchAllFromDatabase() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (2)")
                
                let array = WrappedInt.fetchAll(db, "SELECT int FROM ints ORDER BY int")
                
                XCTAssertEqual(array.map { $0.int }, [1,2])
            }
        }
    }
    
    func testFetchOneFromDatabase() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                
                let nilBecauseMissingRow = WrappedInt.fetchOne(db, "SELECT int FROM ints ORDER BY int")
                XCTAssertTrue(nilBecauseMissingRow == nil)
                
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                let nilBecauseMissingNULL = WrappedInt.fetchOne(db, "SELECT int FROM ints ORDER BY int")
                XCTAssertTrue(nilBecauseMissingNULL == nil)
                
                try db.execute("DELETE FROM ints")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                let one = WrappedInt.fetchOne(db, "SELECT int FROM ints ORDER BY int")!
                XCTAssertEqual(one.int, 1)
            }
        }
    }
    
    func testOptionalFetchFromStatement() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                
                let statement = try db.selectStatement("SELECT int FROM ints ORDER BY int")
                let sequence = Optional<WrappedInt>.fetch(statement)
                
                let ints = sequence.map { $0?.int }
                XCTAssertEqual(ints.count, 2)
                XCTAssertTrue(ints[0] == nil)
                XCTAssertEqual(ints[1]!, 1)
            }
        }
    }
    
    func testOptionalFetchAllFromStatement() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                
                let statement = try db.selectStatement("SELECT int FROM ints ORDER BY int")
                let array = Optional<WrappedInt>.fetchAll(statement)
                
                let ints = array.map { $0?.int }
                XCTAssertEqual(ints.count, 2)
                XCTAssertTrue(ints[0] == nil)
                XCTAssertEqual(ints[1]!, 1)
            }
        }
    }
    
    func testOptionalFetchFromDatabase() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                
                let sequence = Optional<WrappedInt>.fetch(db, "SELECT int FROM ints ORDER BY int")
                
                let ints = sequence.map { $0?.int }
                XCTAssertEqual(ints.count, 2)
                XCTAssertTrue(ints[0] == nil)
                XCTAssertEqual(ints[1]!, 1)
            }
        }
    }
    
    func testOptionalFetchAllFromDatabase() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                
                let array = Optional<WrappedInt>.fetchAll(db, "SELECT int FROM ints ORDER BY int")
                
                let ints = array.map { $0?.int }
                XCTAssertEqual(ints.count, 2)
                XCTAssertTrue(ints[0] == nil)
                XCTAssertEqual(ints[1]!, 1)
            }
        }
    }
}

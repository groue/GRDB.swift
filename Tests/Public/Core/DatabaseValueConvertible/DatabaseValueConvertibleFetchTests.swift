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
    static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> WrappedInt? {
        guard let int = Int.fromDatabaseValue(databaseValue) else {
            return nil
        }
        return WrappedInt(int: int)
    }
}

class DatabaseValueConvertibleFetchTests: GRDBTestCase {
    
    func testFetchCursorFromStatement() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (2)")
                
                let statement = try db.makeSelectStatement("SELECT int, -int FROM ints ORDER BY int")
                let cursor = try WrappedInt.fetchCursor(statement)
                
                XCTAssertEqual(try cursor.next()!.int, 1)
                XCTAssertEqual(try cursor.next()!.int, 2)
                XCTAssertTrue(try cursor.next() == nil)
                XCTAssertTrue(try cursor.next() == nil) // safety
            }
        }
    }
    
    func testFetchCursorFromStatementWithAdapter() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (2)")
                
                let statement = try db.makeSelectStatement("SELECT int, -int FROM ints ORDER BY int")
                let cursor = try WrappedInt.fetchCursor(statement, adapter: SuffixRowAdapter(fromIndex: 1))
                
                XCTAssertEqual(try cursor.next()!.int, -1)
                XCTAssertEqual(try cursor.next()!.int, -2)
                XCTAssertTrue(try cursor.next() == nil)
                XCTAssertTrue(try cursor.next() == nil) // safety
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
                
                let statement = try db.makeSelectStatement("SELECT int, -int FROM ints ORDER BY int")
                let array = try WrappedInt.fetchAll(statement)
                
                XCTAssertEqual(array.map { $0.int }, [1,2])
            }
        }
    }
    
    func testFetchAllFromStatementWithAdapter() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (2)")
                
                let statement = try db.makeSelectStatement("SELECT int, -int FROM ints ORDER BY int")
                let array = try WrappedInt.fetchAll(statement, adapter: SuffixRowAdapter(fromIndex: 1))
                
                XCTAssertEqual(array.map { $0.int }, [-1,-2])
            }
        }
    }
    
    func testFetchOneFromStatement() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                let statement = try db.makeSelectStatement("SELECT int, -int FROM ints ORDER BY int")
                
                let nilBecauseMissingRow = try WrappedInt.fetchOne(statement)
                XCTAssertTrue(nilBecauseMissingRow == nil)
                
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                let nilBecauseMissingNULL = try WrappedInt.fetchOne(statement)
                XCTAssertTrue(nilBecauseMissingNULL == nil)
                
                try db.execute("DELETE FROM ints")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                let one = try WrappedInt.fetchOne(statement)!
                XCTAssertEqual(one.int, 1)
            }
        }
    }
    
    func testFetchOneFromStatementWithAdapter() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                let statement = try db.makeSelectStatement("SELECT int, -int FROM ints ORDER BY int")
                
                let nilBecauseMissingRow = try WrappedInt.fetchOne(statement, adapter: SuffixRowAdapter(fromIndex: 1))
                XCTAssertTrue(nilBecauseMissingRow == nil)
                
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                let nilBecauseMissingNULL = try WrappedInt.fetchOne(statement, adapter: SuffixRowAdapter(fromIndex: 1))
                XCTAssertTrue(nilBecauseMissingNULL == nil)
                
                try db.execute("DELETE FROM ints")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                let one = try WrappedInt.fetchOne(statement, adapter: SuffixRowAdapter(fromIndex: 1))!
                XCTAssertEqual(one.int, -1)
            }
        }
    }
    
    func testFetchCursorFromSQL() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (2)")
                
                let cursor = try WrappedInt.fetchCursor(db, "SELECT int, -int FROM ints ORDER BY int")
                
                XCTAssertEqual(try cursor.next()!.int, 1)
                XCTAssertEqual(try cursor.next()!.int, 2)
                XCTAssertTrue(try cursor.next() == nil)
                XCTAssertTrue(try cursor.next() == nil) // safety
            }
        }
    }
    
    func testFetchCursorFromSQLWithAdapter() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (2)")
                
                let cursor = try WrappedInt.fetchCursor(db, "SELECT int, -int FROM ints ORDER BY int", adapter: SuffixRowAdapter(fromIndex: 1))
                
                XCTAssertEqual(try cursor.next()!.int, -1)
                XCTAssertEqual(try cursor.next()!.int, -2)
                XCTAssertTrue(try cursor.next() == nil)
                XCTAssertTrue(try cursor.next() == nil) // safety
            }
        }
    }
    
    func testFetchAllFromSQL() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (2)")
                
                let array = try WrappedInt.fetchAll(db, "SELECT int, -int FROM ints ORDER BY int")
                
                XCTAssertEqual(array.map { $0.int }, [1,2])
            }
        }
    }
    
    func testFetchAllFromSQLWithAdapter() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (2)")
                
                let array = try WrappedInt.fetchAll(db, "SELECT int, -int FROM ints ORDER BY int", adapter: SuffixRowAdapter(fromIndex: 1))
                
                XCTAssertEqual(array.map { $0.int }, [-1,-2])
            }
        }
    }
    
    func testFetchOneFromSQL() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                
                let nilBecauseMissingRow = try WrappedInt.fetchOne(db, "SELECT int, -int FROM ints ORDER BY int")
                XCTAssertTrue(nilBecauseMissingRow == nil)
                
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                let nilBecauseMissingNULL = try WrappedInt.fetchOne(db, "SELECT int, -int FROM ints ORDER BY int")
                XCTAssertTrue(nilBecauseMissingNULL == nil)
                
                try db.execute("DELETE FROM ints")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                let one = try WrappedInt.fetchOne(db, "SELECT int, -int FROM ints ORDER BY int")!
                XCTAssertEqual(one.int, 1)
            }
        }
    }
    
    func testFetchOneFromSQLWithAdapter() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                
                let nilBecauseMissingRow = try WrappedInt.fetchOne(db, "SELECT int, -int FROM ints ORDER BY int", adapter: SuffixRowAdapter(fromIndex: 1))
                XCTAssertTrue(nilBecauseMissingRow == nil)
                
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                let nilBecauseMissingNULL = try WrappedInt.fetchOne(db, "SELECT int, -int FROM ints ORDER BY int", adapter: SuffixRowAdapter(fromIndex: 1))
                XCTAssertTrue(nilBecauseMissingNULL == nil)
                
                try db.execute("DELETE FROM ints")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                let one = try WrappedInt.fetchOne(db, "SELECT int, -int FROM ints ORDER BY int", adapter: SuffixRowAdapter(fromIndex: 1))!
                XCTAssertEqual(one.int, -1)
            }
        }
    }
    
    func testFetchCursorFromFetchRequest() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (2)")
                
                struct Request : FetchRequest {
                    func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
                        let statement = try db.makeSelectStatement("SELECT int, -int FROM ints ORDER BY int")
                        return (statement, SuffixRowAdapter(fromIndex: 1))
                    }
                }
                let cursor = try WrappedInt.fetchCursor(db, Request())
                
                XCTAssertEqual(try cursor.next()!.int, -1)
                XCTAssertEqual(try cursor.next()!.int, -2)
                XCTAssertTrue(try cursor.next() == nil)
                XCTAssertTrue(try cursor.next() == nil) // safety
            }
        }
    }
    
    func testFetchAllFromFetchRequest() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (2)")
                
                struct Request : FetchRequest {
                    func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
                        let statement = try db.makeSelectStatement("SELECT int, -int FROM ints ORDER BY int")
                        return (statement, SuffixRowAdapter(fromIndex: 1))
                    }
                }
                let array = try WrappedInt.fetchAll(db, Request())
                
                XCTAssertEqual(array.map { $0.int }, [-1,-2])
            }
        }
    }
    
    func testFetchOneFromFetchRequest() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                
                struct Request : FetchRequest {
                    func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
                        let statement = try db.makeSelectStatement("SELECT int, -int FROM ints ORDER BY int")
                        return (statement, SuffixRowAdapter(fromIndex: 1))
                    }
                }
                let nilBecauseMissingRow = try WrappedInt.fetchOne(db, Request())
                XCTAssertTrue(nilBecauseMissingRow == nil)
                
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                let nilBecauseMissingNULL = try WrappedInt.fetchOne(db, Request())
                XCTAssertTrue(nilBecauseMissingNULL == nil)
                
                try db.execute("DELETE FROM ints")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                let one = try WrappedInt.fetchOne(db, Request())!
                XCTAssertEqual(one.int, -1)
            }
        }
    }
    
    func testOptionalFetchCursorFromStatement() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                
                let statement = try db.makeSelectStatement("SELECT int, -int FROM ints ORDER BY int")
                let cursor = try Optional<WrappedInt>.fetchCursor(statement)
                
                XCTAssertTrue(try cursor.next()! == nil)
                XCTAssertEqual(try cursor.next()!!.int, 1)
                XCTAssertTrue(try cursor.next() == nil)
                XCTAssertTrue(try cursor.next() == nil) // safety
            }
        }
    }
    
    func testOptionalFetchCursorFromStatementWithAdapter() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                
                let statement = try db.makeSelectStatement("SELECT int, -int FROM ints ORDER BY int")
                let cursor = try Optional<WrappedInt>.fetchCursor(statement, adapter: SuffixRowAdapter(fromIndex: 1))
                
                XCTAssertTrue(try cursor.next()! == nil)
                XCTAssertEqual(try cursor.next()!!.int, -1)
                XCTAssertTrue(try cursor.next() == nil)
                XCTAssertTrue(try cursor.next() == nil) // safety
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
                
                let statement = try db.makeSelectStatement("SELECT int, -int FROM ints ORDER BY int")
                let array = try Optional<WrappedInt>.fetchAll(statement)
                
                let ints = array.map { $0?.int }
                XCTAssertEqual(ints.count, 2)
                XCTAssertTrue(ints[0] == nil)
                XCTAssertEqual(ints[1]!, 1)
            }
        }
    }
    
    func testOptionalFetchAllFromStatementWithAdapter() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                
                let statement = try db.makeSelectStatement("SELECT int, -int FROM ints ORDER BY int")
                let array = try Optional<WrappedInt>.fetchAll(statement, adapter: SuffixRowAdapter(fromIndex: 1))
                
                let ints = array.map { $0?.int }
                XCTAssertEqual(ints.count, 2)
                XCTAssertTrue(ints[0] == nil)
                XCTAssertEqual(ints[1]!, -1)
            }
        }
    }
    
    func testOptionalFetchCursorFromSQL() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                
                let cursor = try Optional<WrappedInt>.fetchCursor(db, "SELECT int, -int FROM ints ORDER BY int")
                
                XCTAssertTrue(try cursor.next()! == nil)
                XCTAssertEqual(try cursor.next()!!.int, 1)
                XCTAssertTrue(try cursor.next() == nil)
                XCTAssertTrue(try cursor.next() == nil) // safety
            }
        }
    }
    
    func testOptionalFetchCursorFromSQLWithAdapter() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                
                let cursor = try Optional<WrappedInt>.fetchCursor(db, "SELECT int, -int FROM ints ORDER BY int", adapter: SuffixRowAdapter(fromIndex: 1))
                
                XCTAssertTrue(try cursor.next()! == nil)
                XCTAssertEqual(try cursor.next()!!.int, -1)
                XCTAssertTrue(try cursor.next() == nil)
                XCTAssertTrue(try cursor.next() == nil) // safety
            }
        }
    }
    
    func testOptionalFetchAllFromSQL() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                
                let array = try Optional<WrappedInt>.fetchAll(db, "SELECT int, -int FROM ints ORDER BY int")
                
                let ints = array.map { $0?.int }
                XCTAssertEqual(ints.count, 2)
                XCTAssertTrue(ints[0] == nil)
                XCTAssertEqual(ints[1]!, 1)
            }
        }
    }
    
    func testOptionalFetchAllFromSQLWithAdapter() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                
                let array = try Optional<WrappedInt>.fetchAll(db, "SELECT int, -int FROM ints ORDER BY int", adapter: SuffixRowAdapter(fromIndex: 1))
                
                let ints = array.map { $0?.int }
                XCTAssertEqual(ints.count, 2)
                XCTAssertTrue(ints[0] == nil)
                XCTAssertEqual(ints[1]!, -1)
            }
        }
    }
    
    func testOptionalFetchCursorFromFetchRequest() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                
                struct Request : FetchRequest {
                    func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
                        let statement = try db.makeSelectStatement("SELECT int, -int FROM ints ORDER BY int")
                        return (statement, SuffixRowAdapter(fromIndex: 1))
                    }
                }
                let cursor = try Optional<WrappedInt>.fetchCursor(db, Request())
                
                XCTAssertTrue(try cursor.next()! == nil)
                XCTAssertEqual(try cursor.next()!!.int, -1)
                XCTAssertTrue(try cursor.next() == nil)
                XCTAssertTrue(try cursor.next() == nil) // safety
            }
        }
    }
    
    func testOptionalFetchAllFromFetchRequest() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                
                struct Request : FetchRequest {
                    func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
                        let statement = try db.makeSelectStatement("SELECT int, -int FROM ints ORDER BY int")
                        return (statement, SuffixRowAdapter(fromIndex: 1))
                    }
                }
                let array = try Optional<WrappedInt>.fetchAll(db, Request())
                
                let ints = array.map { $0?.int }
                XCTAssertEqual(ints.count, 2)
                XCTAssertTrue(ints[0] == nil)
                XCTAssertEqual(ints[1]!, -1)
            }
        }
    }
}

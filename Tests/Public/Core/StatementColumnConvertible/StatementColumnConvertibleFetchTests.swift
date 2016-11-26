import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

#if !USING_BUILTIN_SQLITE
    #if os(OSX)
        import SQLiteMacOSX
    #elseif os(iOS)
        #if (arch(i386) || arch(x86_64))
            import SQLiteiPhoneSimulator
        #else
            import SQLiteiPhoneOS
        #endif
    #elseif os(watchOS)
        #if (arch(i386) || arch(x86_64))
            import SQLiteWatchSimulator
        #else
            import SQLiteWatchOS
        #endif
    #endif
#endif

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
    
    static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> FastWrappedInt? {
        guard let int = Int.fromDatabaseValue(databaseValue) else {
            return nil
        }
        return FastWrappedInt(int: int, fast: false)
    }
}

class StatementColumnConvertibleFetchTests: GRDBTestCase {
    
    func testSlowConversion() {
        let slow = FastWrappedInt.fromDatabaseValue(0.databaseValue)!
        XCTAssertEqual(slow.int, 0)
        XCTAssertEqual(slow.fast, false)
    }
    
    func testRowExtraction() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
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
    
    func testFetchCursorFromStatement() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (2)")
                
                let statement = try db.makeSelectStatement("SELECT int, -int FROM ints ORDER BY int")
                let cursor = try FastWrappedInt.fetchCursor(statement)
                
                var i = try cursor.next()!
                XCTAssertEqual(i.int, 1)
                XCTAssertTrue(i.fast)
                i = try cursor.next()!
                XCTAssertEqual(i.int, 2)
                XCTAssertTrue(i.fast)
                
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
                let cursor = try FastWrappedInt.fetchCursor(statement, adapter: SuffixRowAdapter(fromIndex: 1))
                
                var i = try cursor.next()!
                XCTAssertEqual(i.int, -1)
                XCTAssertTrue(i.fast)
                i = try cursor.next()!
                XCTAssertEqual(i.int, -2)
                XCTAssertTrue(i.fast)
                
                XCTAssertTrue(try cursor.next() == nil)
                XCTAssertTrue(try cursor.next() == nil) // safety
            }
        }
    }
    
    func testFetchSequenceFromStatement() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (2)")
                
                let statement = try db.makeSelectStatement("SELECT int, -int FROM ints ORDER BY int")
                let sequence = FastWrappedInt.fetch(statement)
                
                XCTAssertEqual(Array(sequence).map { $0.int }, [1,2])
                XCTAssertEqual(Array(sequence).map { $0.fast }, [true, true])
            }
        }
    }
    
    func testFetchSequenceFromStatementWithAdapter() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (2)")
                
                let statement = try db.makeSelectStatement("SELECT int, -int FROM ints ORDER BY int")
                let sequence = FastWrappedInt.fetch(statement, adapter: SuffixRowAdapter(fromIndex: 1))
                
                XCTAssertEqual(Array(sequence).map { $0.int }, [-1,-2])
                // NICE TO HAVE: make it fast, and the following test pass:
//                XCTAssertEqual(Array(sequence).map { $0.fast }, [true, true])
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
                let array = FastWrappedInt.fetchAll(statement)
                
                XCTAssertEqual(array.map { $0.int }, [1,2])
                XCTAssertEqual(array.map { $0.fast }, [true, true])
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
                let array = FastWrappedInt.fetchAll(statement, adapter: SuffixRowAdapter(fromIndex: 1))
                
                XCTAssertEqual(array.map { $0.int }, [-1,-2])
                // NICE TO HAVE: make it fast, and the following test pass:
//                XCTAssertEqual(array.map { $0.fast }, [true, true])
            }
        }
    }
    
    func testFetchOneFromStatement() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                let statement = try db.makeSelectStatement("SELECT int, -int FROM ints ORDER BY int")
                
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
    
    func testFetchOneFromStatementWithAdapter() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                let statement = try db.makeSelectStatement("SELECT int, -int FROM ints ORDER BY int")
                
                let nilBecauseMissingRow = FastWrappedInt.fetchOne(statement, adapter: SuffixRowAdapter(fromIndex: 1))
                XCTAssertTrue(nilBecauseMissingRow == nil)
                
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                let nilBecauseMissingNULL = FastWrappedInt.fetchOne(statement, adapter: SuffixRowAdapter(fromIndex: 1))
                XCTAssertTrue(nilBecauseMissingNULL == nil)
                
                try db.execute("DELETE FROM ints")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                let one = FastWrappedInt.fetchOne(statement, adapter: SuffixRowAdapter(fromIndex: 1))!
                XCTAssertEqual(one.int, -1)
                // NICE TO HAVE: make it fast, and the following test pass:
//                XCTAssertEqual(one.fast, true)
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
                
                let cursor = try FastWrappedInt.fetchCursor(db, "SELECT int, -int FROM ints ORDER BY int")
                
                var i = try cursor.next()!
                XCTAssertEqual(i.int, 1)
                XCTAssertTrue(i.fast)
                i = try cursor.next()!
                XCTAssertEqual(i.int, 2)
                XCTAssertTrue(i.fast)
                
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
                
                let cursor = try FastWrappedInt.fetchCursor(db, "SELECT int, -int FROM ints ORDER BY int", adapter: SuffixRowAdapter(fromIndex: 1))
                
                var i = try cursor.next()!
                XCTAssertEqual(i.int, -1)
                XCTAssertTrue(i.fast)
                i = try cursor.next()!
                XCTAssertEqual(i.int, -2)
                XCTAssertTrue(i.fast)
                
                XCTAssertTrue(try cursor.next() == nil)
                XCTAssertTrue(try cursor.next() == nil) // safety
            }
        }
    }
    
    func testFetchSequenceFromSQL() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (2)")
                
                let sequence = FastWrappedInt.fetch(db, "SELECT int, -int FROM ints ORDER BY int")
                
                XCTAssertEqual(Array(sequence).map { $0.int }, [1,2])
                XCTAssertEqual(Array(sequence).map { $0.fast }, [true, true])
            }
        }
    }
    
    func testFetchSequenceFromSQLWithAdapter() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (2)")
                
                let sequence = FastWrappedInt.fetch(db, "SELECT int, -int FROM ints ORDER BY int", adapter: SuffixRowAdapter(fromIndex: 1))
                
                XCTAssertEqual(Array(sequence).map { $0.int }, [-1,-2])
                // NICE TO HAVE: make it fast, and the following test pass:
//                XCTAssertEqual(Array(sequence).map { $0.fast }, [true, true])
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
                
                let array = FastWrappedInt.fetchAll(db, "SELECT int, -int FROM ints ORDER BY int")
                
                XCTAssertEqual(array.map { $0.int }, [1,2])
                XCTAssertEqual(array.map { $0.fast }, [true, true])
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
                
                let array = FastWrappedInt.fetchAll(db, "SELECT int, -int FROM ints ORDER BY int", adapter: SuffixRowAdapter(fromIndex: 1))
                
                XCTAssertEqual(array.map { $0.int }, [-1,-2])
                // NICE TO HAVE: make it fast, and the following test pass:
//                XCTAssertEqual(array.map { $0.fast }, [true, true])
            }
        }
    }
    
    func testFetchOneFromSQL() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                
                let nilBecauseMissingRow = FastWrappedInt.fetchOne(db, "SELECT int, -int FROM ints ORDER BY int")
                XCTAssertTrue(nilBecauseMissingRow == nil)
                
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                let nilBecauseMissingNULL = FastWrappedInt.fetchOne(db, "SELECT int, -int FROM ints ORDER BY int")
                XCTAssertTrue(nilBecauseMissingNULL == nil)
                
                try db.execute("DELETE FROM ints")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                let one = FastWrappedInt.fetchOne(db, "SELECT int, -int FROM ints ORDER BY int")!
                XCTAssertEqual(one.int, 1)
                XCTAssertEqual(one.fast, true)
            }
        }
    }
    
    func testFetchOneFromSQLWithAdapter() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                
                let nilBecauseMissingRow = FastWrappedInt.fetchOne(db, "SELECT int, -int FROM ints ORDER BY int", adapter: SuffixRowAdapter(fromIndex: 1))
                XCTAssertTrue(nilBecauseMissingRow == nil)
                
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                let nilBecauseMissingNULL = FastWrappedInt.fetchOne(db, "SELECT int, -int FROM ints ORDER BY int", adapter: SuffixRowAdapter(fromIndex: 1))
                XCTAssertTrue(nilBecauseMissingNULL == nil)
                
                try db.execute("DELETE FROM ints")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                let one = FastWrappedInt.fetchOne(db, "SELECT int, -int FROM ints ORDER BY int", adapter: SuffixRowAdapter(fromIndex: 1))!
                XCTAssertEqual(one.int, -1)
                // NICE TO HAVE: make it fast, and the following test pass:
//                XCTAssertEqual(one.fast, true)
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
                let cursor = try FastWrappedInt.fetchCursor(db, Request())
                
                var i = try cursor.next()!
                XCTAssertEqual(i.int, -1)
                XCTAssertTrue(i.fast)
                i = try cursor.next()!
                XCTAssertEqual(i.int, -2)
                XCTAssertTrue(i.fast)
                
                XCTAssertTrue(try cursor.next() == nil)
                XCTAssertTrue(try cursor.next() == nil) // safety
            }
        }
    }
    
    func testFetchSequenceFromFetchRequest() {
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
                let sequence = FastWrappedInt.fetch(db, Request())
                
                XCTAssertEqual(Array(sequence).map { $0.int }, [-1,-2])
                // NICE TO HAVE: make it fast, and the following test pass:
//                XCTAssertEqual(Array(sequence).map { $0.fast }, [true, true])
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
                let array = FastWrappedInt.fetchAll(db, Request())
                
                XCTAssertEqual(array.map { $0.int }, [-1,-2])
                // NICE TO HAVE: make it fast, and the following test pass:
//                XCTAssertEqual(array.map { $0.fast }, [true, true])
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
                let nilBecauseMissingRow = FastWrappedInt.fetchOne(db, Request())
                XCTAssertTrue(nilBecauseMissingRow == nil)
                
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                let nilBecauseMissingNULL = FastWrappedInt.fetchOne(db, Request())
                XCTAssertTrue(nilBecauseMissingNULL == nil)
                
                try db.execute("DELETE FROM ints")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                let one = FastWrappedInt.fetchOne(db, Request())!
                XCTAssertEqual(one.int, -1)
                // NICE TO HAVE: make it fast, and the following test pass:
//                XCTAssertEqual(one.fast, true)
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
                let cursor = try Optional<FastWrappedInt>.fetchCursor(statement)
                
                var i = try cursor.next()!
                XCTAssertTrue(i == nil)
                i = try cursor.next()!
                XCTAssertEqual(i!.int, 1)
                // TODO: uncomment when we have a workaround for rdar://22852669
//                XCTAssertTrue(i!.fast)
                
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
                let cursor = try Optional<FastWrappedInt>.fetchCursor(statement, adapter: SuffixRowAdapter(fromIndex: 1))
                
                var i = try cursor.next()!
                XCTAssertTrue(i == nil)
                i = try cursor.next()!
                XCTAssertEqual(i!.int, -1)
                // TODO: uncomment when we have a workaround for rdar://22852669
//                XCTAssertTrue(i!.fast)
                
                XCTAssertTrue(try cursor.next() == nil)
                XCTAssertTrue(try cursor.next() == nil) // safety
            }
        }
    }
    
    func testOptionalFetchSequenceFromStatement() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                
                let statement = try db.makeSelectStatement("SELECT int, -int FROM ints ORDER BY int")
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
    
    func testOptionalFetchSequenceFromStatementWithAdapter() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                
                let statement = try db.makeSelectStatement("SELECT int, -int FROM ints ORDER BY int")
                let sequence = Optional<FastWrappedInt>.fetch(statement, adapter: SuffixRowAdapter(fromIndex: 1))
                
                let ints = Array(sequence)
                XCTAssertEqual(ints.count, 2)
                XCTAssertTrue(ints[0] == nil)
                XCTAssertEqual(ints[1]!.int, -1)
                // TODO: uncomment when we have a workaround for rdar://22852669
//                XCTAssertEqual(ints[1]!.fast, true)
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
                let array = Optional<FastWrappedInt>.fetchAll(statement)
                
                XCTAssertEqual(array.count, 2)
                XCTAssertTrue(array[0] == nil)
                XCTAssertEqual(array[1]!.int, 1)
                // TODO: uncomment when we have a workaround for rdar://22852669
//                XCTAssertEqual(array[1]!.fast, true)
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
                let array = Optional<FastWrappedInt>.fetchAll(statement, adapter: SuffixRowAdapter(fromIndex: 1))
                
                XCTAssertEqual(array.count, 2)
                XCTAssertTrue(array[0] == nil)
                XCTAssertEqual(array[1]!.int, -1)
                // TODO: uncomment when we have a workaround for rdar://22852669
//                XCTAssertEqual(array[1]!.fast, true)
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
                
                let cursor = try Optional<FastWrappedInt>.fetchCursor(db, "SELECT int, -int FROM ints ORDER BY int")
                
                var i = try cursor.next()!
                XCTAssertTrue(i == nil)
                i = try cursor.next()!
                XCTAssertEqual(i!.int, 1)
                // TODO: uncomment when we have a workaround for rdar://22852669
//                XCTAssertTrue(i!.fast)
                
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
                
                let cursor = try Optional<FastWrappedInt>.fetchCursor(db, "SELECT int, -int FROM ints ORDER BY int", adapter: SuffixRowAdapter(fromIndex: 1))
                
                var i = try cursor.next()!
                XCTAssertTrue(i == nil)
                i = try cursor.next()!
                XCTAssertEqual(i!.int, -1)
                // TODO: uncomment when we have a workaround for rdar://22852669
//                XCTAssertTrue(i!.fast)
                
                XCTAssertTrue(try cursor.next() == nil)
                XCTAssertTrue(try cursor.next() == nil) // safety
            }
        }
    }
    
    func testOptionalFetchSequenceFromSQL() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                
                let sequence = Optional<FastWrappedInt>.fetch(db, "SELECT int, -int FROM ints ORDER BY int")
                
                let ints = Array(sequence)
                XCTAssertEqual(ints.count, 2)
                XCTAssertTrue(ints[0] == nil)
                XCTAssertEqual(ints[1]!.int, 1)
                // TODO: uncomment when we have a workaround for rdar://22852669
//                XCTAssertEqual(ints[1]!.fast, true)
            }
        }
    }
    
    func testOptionalFetchSequenceFromSQLWithAdapter() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                
                let sequence = Optional<FastWrappedInt>.fetch(db, "SELECT int, -int FROM ints ORDER BY int", adapter: SuffixRowAdapter(fromIndex: 1))
                
                let ints = Array(sequence)
                XCTAssertEqual(ints.count, 2)
                XCTAssertTrue(ints[0] == nil)
                XCTAssertEqual(ints[1]!.int, -1)
                // TODO: uncomment when we have a workaround for rdar://22852669
//                XCTAssertEqual(ints[1]!.fast, true)
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
                
                let array = Optional<FastWrappedInt>.fetchAll(db, "SELECT int, -int FROM ints ORDER BY int")
                
                XCTAssertEqual(array.count, 2)
                XCTAssertTrue(array[0] == nil)
                XCTAssertEqual(array[1]!.int, 1)
                // TODO: uncomment when we have a workaround for rdar://22852669
//                XCTAssertEqual(array[1]!.fast, true)
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
                
                let array = Optional<FastWrappedInt>.fetchAll(db, "SELECT int, -int FROM ints ORDER BY int", adapter: SuffixRowAdapter(fromIndex: 1))
                
                XCTAssertEqual(array.count, 2)
                XCTAssertTrue(array[0] == nil)
                XCTAssertEqual(array[1]!.int, -1)
                // TODO: uncomment when we have a workaround for rdar://22852669
//                XCTAssertEqual(array[1]!.fast, true)
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
                let cursor = try Optional<FastWrappedInt>.fetchCursor(db, Request())
                
                var i = try cursor.next()!
                XCTAssertTrue(i == nil)
                i = try cursor.next()!
                XCTAssertEqual(i!.int, -1)
                // TODO: uncomment when we have a workaround for rdar://22852669
//                XCTAssertTrue(i!.fast)
                
                XCTAssertTrue(try cursor.next() == nil)
                XCTAssertTrue(try cursor.next() == nil) // safety
            }
        }
    }
    
    func testOptionalFetchSequenceFromFetchRequest() {
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
                let sequence = Optional<FastWrappedInt>.fetch(db, Request())
                
                let ints = Array(sequence)
                XCTAssertEqual(ints.count, 2)
                XCTAssertTrue(ints[0] == nil)
                XCTAssertEqual(ints[1]!.int, -1)
                // TODO: uncomment when we have a workaround for rdar://22852669
//                XCTAssertEqual(ints[1]!.fast, true)
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
                let array = Optional<FastWrappedInt>.fetchAll(db, Request())
                
                XCTAssertEqual(array.count, 2)
                XCTAssertTrue(array[0] == nil)
                XCTAssertEqual(array[1]!.int, -1)
                // TODO: uncomment when we have a workaround for rdar://22852669
//                XCTAssertEqual(array[1]!.fast, true)
            }
        }
    }
}

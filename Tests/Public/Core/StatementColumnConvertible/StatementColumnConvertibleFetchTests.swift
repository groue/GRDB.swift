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
            try dbQueue.inDatabase { db in
                var rows = try Row.fetchCursor(db, "SELECT NULL")
                while let row = try rows.next() {
                    let one: FastWrappedInt? = row.value(atIndex: 0)
                    XCTAssertTrue(one == nil)
                }
                rows = try Row.fetchCursor(db, "SELECT 1")
                while let row = try rows.next() {
                    let one: FastWrappedInt? = row.value(atIndex: 0)
                    XCTAssertEqual(one!.int, 1)
                    XCTAssertEqual(one!.fast, true)
                }
                rows = try Row.fetchCursor(db, "SELECT 1 AS int")
                while let row = try rows.next() {
                    let one: FastWrappedInt? = row.value(named: "int")
                    XCTAssertEqual(one!.int, 1)
                    XCTAssertEqual(one!.fast, true)
                }
                rows = try Row.fetchCursor(db, "SELECT 1")
                while let row = try rows.next() {
                    let one: FastWrappedInt = row.value(atIndex: 0)
                    XCTAssertEqual(one.int, 1)
                    XCTAssertEqual(one.fast, true)
                }
                rows = try Row.fetchCursor(db, "SELECT 1 AS int")
                while let row = try rows.next() {
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
    
    func testFetchAllFromStatement() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (2)")
                
                let statement = try db.makeSelectStatement("SELECT int, -int FROM ints ORDER BY int")
                let array = try FastWrappedInt.fetchAll(statement)
                
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
                let array = try FastWrappedInt.fetchAll(statement, adapter: SuffixRowAdapter(fromIndex: 1))
                
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
                
                let nilBecauseMissingRow = try FastWrappedInt.fetchOne(statement)
                XCTAssertTrue(nilBecauseMissingRow == nil)
                
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                let nilBecauseMissingNULL = try FastWrappedInt.fetchOne(statement)
                XCTAssertTrue(nilBecauseMissingNULL == nil)
                
                try db.execute("DELETE FROM ints")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                let one = try FastWrappedInt.fetchOne(statement)!
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
                
                let nilBecauseMissingRow = try FastWrappedInt.fetchOne(statement, adapter: SuffixRowAdapter(fromIndex: 1))
                XCTAssertTrue(nilBecauseMissingRow == nil)
                
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                let nilBecauseMissingNULL = try FastWrappedInt.fetchOne(statement, adapter: SuffixRowAdapter(fromIndex: 1))
                XCTAssertTrue(nilBecauseMissingNULL == nil)
                
                try db.execute("DELETE FROM ints")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                let one = try FastWrappedInt.fetchOne(statement, adapter: SuffixRowAdapter(fromIndex: 1))!
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
    
    func testFetchAllFromSQL() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (2)")
                
                let array = try FastWrappedInt.fetchAll(db, "SELECT int, -int FROM ints ORDER BY int")
                
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
                
                let array = try FastWrappedInt.fetchAll(db, "SELECT int, -int FROM ints ORDER BY int", adapter: SuffixRowAdapter(fromIndex: 1))
                
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
                
                let nilBecauseMissingRow = try FastWrappedInt.fetchOne(db, "SELECT int, -int FROM ints ORDER BY int")
                XCTAssertTrue(nilBecauseMissingRow == nil)
                
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                let nilBecauseMissingNULL = try FastWrappedInt.fetchOne(db, "SELECT int, -int FROM ints ORDER BY int")
                XCTAssertTrue(nilBecauseMissingNULL == nil)
                
                try db.execute("DELETE FROM ints")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                let one = try FastWrappedInt.fetchOne(db, "SELECT int, -int FROM ints ORDER BY int")!
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
                
                let nilBecauseMissingRow = try FastWrappedInt.fetchOne(db, "SELECT int, -int FROM ints ORDER BY int", adapter: SuffixRowAdapter(fromIndex: 1))
                XCTAssertTrue(nilBecauseMissingRow == nil)
                
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                let nilBecauseMissingNULL = try FastWrappedInt.fetchOne(db, "SELECT int, -int FROM ints ORDER BY int", adapter: SuffixRowAdapter(fromIndex: 1))
                XCTAssertTrue(nilBecauseMissingNULL == nil)
                
                try db.execute("DELETE FROM ints")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                let one = try FastWrappedInt.fetchOne(db, "SELECT int, -int FROM ints ORDER BY int", adapter: SuffixRowAdapter(fromIndex: 1))!
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
                let nilBecauseMissingRow = try FastWrappedInt.fetchOne(db, Request())
                XCTAssertTrue(nilBecauseMissingRow == nil)
                
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                let nilBecauseMissingNULL = try FastWrappedInt.fetchOne(db, Request())
                XCTAssertTrue(nilBecauseMissingNULL == nil)
                
                try db.execute("DELETE FROM ints")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                let one = try FastWrappedInt.fetchOne(db, Request())!
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
    
    func testOptionalFetchAllFromStatement() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                
                let statement = try db.makeSelectStatement("SELECT int, -int FROM ints ORDER BY int")
                let array = try Optional<FastWrappedInt>.fetchAll(statement)
                
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
                let array = try Optional<FastWrappedInt>.fetchAll(statement, adapter: SuffixRowAdapter(fromIndex: 1))
                
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
    
    func testOptionalFetchAllFromSQL() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                
                let array = try Optional<FastWrappedInt>.fetchAll(db, "SELECT int, -int FROM ints ORDER BY int")
                
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
                
                let array = try Optional<FastWrappedInt>.fetchAll(db, "SELECT int, -int FROM ints ORDER BY int", adapter: SuffixRowAdapter(fromIndex: 1))
                
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
                let array = try Optional<FastWrappedInt>.fetchAll(db, Request())
                
                XCTAssertEqual(array.count, 2)
                XCTAssertTrue(array[0] == nil)
                XCTAssertEqual(array[1]!.int, -1)
                // TODO: uncomment when we have a workaround for rdar://22852669
//                XCTAssertEqual(array[1]!.fast, true)
            }
        }
    }
}

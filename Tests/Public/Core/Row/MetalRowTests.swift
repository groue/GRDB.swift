import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class MetalRowTests: GRDBTestCase {
    
    func testRowAsSequence() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (a INTEGER, b INTEGER, c INTEGER)")
                try db.execute("INSERT INTO ints (a,b,c) VALUES (0, 1, 2)")
                var rowFetched = false
                for row in Row.fetch(db, "SELECT * FROM ints") {
                    rowFetched = true
                    var columnNames = [String]()
                    var ints = [Int]()
                    var bools = [Bool]()
                    for (columnName, databaseValue) in row {
                        columnNames.append(columnName)
                        ints.append(databaseValue.value() as Int)
                        bools.append(databaseValue.value() as Bool)
                    }
                    
                    XCTAssertEqual(columnNames, ["a", "b", "c"])
                    XCTAssertEqual(ints, [0, 1, 2])
                    XCTAssertEqual(bools, [false, true, true])
                }
                XCTAssertTrue(rowFetched)
            }
        }
    }
    
    func testRowValueAtIndex() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (a INTEGER, b INTEGER, c INTEGER)")
                try db.execute("INSERT INTO ints (a,b,c) VALUES (0, 1, 2)")
                var rowFetched = false
                for row in Row.fetch(db, "SELECT * FROM ints") {
                    rowFetched = true
                    
                    // Int extraction, form 1
                    XCTAssertEqual(row.value(atIndex: 0) as Int, 0)
                    XCTAssertEqual(row.value(atIndex: 1) as Int, 1)
                    XCTAssertEqual(row.value(atIndex: 2) as Int, 2)
                    
                    // Int extraction, form 2
                    XCTAssertEqual(row.value(atIndex: 0)! as Int, 0)
                    XCTAssertEqual(row.value(atIndex: 1)! as Int, 1)
                    XCTAssertEqual(row.value(atIndex: 2)! as Int, 2)
                    
                    // Int? extraction
                    XCTAssertEqual((row.value(atIndex: 0) as Int?), 0)
                    XCTAssertEqual((row.value(atIndex: 1) as Int?), 1)
                    XCTAssertEqual((row.value(atIndex: 2) as Int?), 2)
                    
                    // Bool extraction, form 1
                    XCTAssertEqual(row.value(atIndex: 0) as Bool, false)
                    XCTAssertEqual(row.value(atIndex: 1) as Bool, true)
                    XCTAssertEqual(row.value(atIndex: 2) as Bool, true)
                    
                    // Bool extraction, form 2
                    XCTAssertEqual(row.value(atIndex: 0)! as Bool, false)
                    XCTAssertEqual(row.value(atIndex: 1)! as Bool, true)
                    XCTAssertEqual(row.value(atIndex: 2)! as Bool, true)
                    
                    // Bool? extraction
                    XCTAssertEqual((row.value(atIndex: 0) as Bool?), false)
                    XCTAssertEqual((row.value(atIndex: 1) as Bool?), true)
                    XCTAssertEqual((row.value(atIndex: 2) as Bool?), true)
                    
                    // Expect fatal error:
                    //
                    // row.value(atIndex: -1)
                    // row.value(atIndex: 3)
                }
                XCTAssertTrue(rowFetched)
            }
        }
    }
    
    func testRowValueNamed() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (a INTEGER, b INTEGER, c INTEGER)")
                try db.execute("INSERT INTO ints (a,b,c) VALUES (0, 1, 2)")
                var rowFetched = false
                for row in Row.fetch(db, "SELECT * FROM ints") {
                    rowFetched = true
                    
                    // Int extraction, form 1
                    XCTAssertEqual(row.value(named: "a") as Int, 0)
                    XCTAssertEqual(row.value(named: "b") as Int, 1)
                    XCTAssertEqual(row.value(named: "c") as Int, 2)
                    
                    // Int extraction, form 2
                    XCTAssertEqual(row.value(named: "a")! as Int, 0)
                    XCTAssertEqual(row.value(named: "b")! as Int, 1)
                    XCTAssertEqual(row.value(named: "c")! as Int, 2)
                    
                    // Int? extraction
                    XCTAssertEqual((row.value(named: "a") as Int?)!, 0)
                    XCTAssertEqual((row.value(named: "b") as Int?)!, 1)
                    XCTAssertEqual((row.value(named: "c") as Int?)!, 2)
                    
                    // Bool extraction, form 1
                    XCTAssertEqual(row.value(named: "a") as Bool, false)
                    XCTAssertEqual(row.value(named: "b") as Bool, true)
                    XCTAssertEqual(row.value(named: "c") as Bool, true)
                    
                    // Bool extraction, form 2
                    XCTAssertEqual(row.value(named: "a")! as Bool, false)
                    XCTAssertEqual(row.value(named: "b")! as Bool, true)
                    XCTAssertEqual(row.value(named: "c")! as Bool, true)
                    
                    // Bool? extraction
                    XCTAssertEqual((row.value(named: "a") as Bool?)!, false)
                    XCTAssertEqual((row.value(named: "b") as Bool?)!, true)
                    XCTAssertEqual((row.value(named: "c") as Bool?)!, true)
                    
                    // Expect fatal error:
                    // row.value(named: "foo")
                    // row.value(named: "foo") as Int?
                }
                XCTAssertTrue(rowFetched)
            }
        }
    }
    
    func testRowDatabaseValueAtIndex() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                var rowFetched = false
                for row in Row.fetch(db, "SELECT NULL, 1, 1.1, 'foo', x'53514C697465'") {
                    rowFetched = true
                    guard case .Null = row.databaseValue(atIndex: 0).storage else { XCTFail(); return }
                    guard case .Int64(let int64) = row.databaseValue(atIndex: 1).storage where int64 == 1 else { XCTFail(); return }
                    guard case .Double(let double) = row.databaseValue(atIndex: 2).storage where double == 1.1 else { XCTFail(); return }
                    guard case .String(let string) = row.databaseValue(atIndex: 3).storage where string == "foo" else { XCTFail(); return }
                    guard case .Blob(let data) = row.databaseValue(atIndex: 4).storage where data == "SQLite".dataUsingEncoding(NSUTF8StringEncoding) else { XCTFail(); return }
                }
                XCTAssertTrue(rowFetched)
            }
        }
    }
    
    func testRowDatabaseValueNamed() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                var rowFetched = false
                for row in Row.fetch(db, "SELECT NULL AS \"null\", 1 AS \"int64\", 1.1 AS \"double\", 'foo' AS \"string\", x'53514C697465' AS \"blob\"") {
                    rowFetched = true
                    guard case .Null = row.databaseValue(named: "null")!.storage else { XCTFail(); return }
                    guard case .Int64(let int64) = row.databaseValue(named: "int64")!.storage where int64 == 1 else { XCTFail(); return }
                    guard case .Double(let double) = row.databaseValue(named: "double")!.storage where double == 1.1 else { XCTFail(); return }
                    guard case .String(let string) = row.databaseValue(named: "string")!.storage where string == "foo" else { XCTFail(); return }
                    guard case .Blob(let data) = row.databaseValue(named: "blob")!.storage where data == "SQLite".dataUsingEncoding(NSUTF8StringEncoding) else { XCTFail(); return }
                }
                XCTAssertTrue(rowFetched)
            }
        }
    }
    
    func testRowCount() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (a INTEGER, b INTEGER, c INTEGER)")
                try db.execute("INSERT INTO ints (a,b,c) VALUES (0, 1, 2)")
                var rowFetched = false
                for row in Row.fetch(db, "SELECT * FROM ints") {
                    rowFetched = true
                    XCTAssertEqual(row.count, 3)
                }
                XCTAssertTrue(rowFetched)
            }
        }
    }
    
    func testRowColumnNames() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (a INTEGER, b INTEGER, c INTEGER)")
                try db.execute("INSERT INTO ints (a,b,c) VALUES (0, 1, 2)")
                var rowFetched = false
                for row in Row.fetch(db, "SELECT a, b, c FROM ints") {
                    rowFetched = true
                    XCTAssertEqual(Array(row.columnNames), ["a", "b", "c"])
                }
                XCTAssertTrue(rowFetched)
            }
        }
    }
    
    func testRowDatabaseValues() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (a INTEGER, b INTEGER, c INTEGER)")
                try db.execute("INSERT INTO ints (a,b,c) VALUES (0, 1, 2)")
                var rowFetched = false
                for row in Row.fetch(db, "SELECT a, b, c FROM ints") {
                    rowFetched = true
                    XCTAssertEqual(Array(row.databaseValues), [0.databaseValue, 1.databaseValue, 2.databaseValue])
                }
                XCTAssertTrue(rowFetched)
            }
        }
    }
    
    func testRowIsCaseInsensitive() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                var rowFetched = false
                for row in Row.fetch(db, "SELECT 'foo' AS nAmE") {
                    rowFetched = true
                    XCTAssertEqual(row.databaseValue(named: "name"), "foo".databaseValue)
                    XCTAssertEqual(row.databaseValue(named: "NAME"), "foo".databaseValue)
                    XCTAssertEqual(row.databaseValue(named: "NaMe"), "foo".databaseValue)
                    XCTAssertEqual(row.value(named: "name") as String, "foo")
                    XCTAssertEqual(row.value(named: "NAME") as String, "foo")
                    XCTAssertEqual(row.value(named: "NaMe") as String, "foo")
                }
                XCTAssertTrue(rowFetched)
            }
        }
    }
    
    func testRowIsCaseInsensitiveAndReturnsLeftmostMatchingColumn() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                var rowFetched = false
                for row in Row.fetch(db, "SELECT 1 AS name, 2 AS NAME") {
                    rowFetched = true
                    XCTAssertEqual(row.databaseValue(named: "name"), 1.databaseValue)
                    XCTAssertEqual(row.databaseValue(named: "NAME"), 1.databaseValue)
                    XCTAssertEqual(row.databaseValue(named: "NaMe"), 1.databaseValue)
                    XCTAssertEqual(row.value(named: "name") as Int, 1)
                    XCTAssertEqual(row.value(named: "NAME") as Int, 1)
                    XCTAssertEqual(row.value(named: "NaMe") as Int, 1)
                }
                XCTAssertTrue(rowFetched)
            }
        }
    }
    
    func testMissingColumn() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                var rowFetched = false
                for row in Row.fetch(db, "SELECT 'foo' AS name") {
                    rowFetched = true
                    XCTAssertFalse(row.hasColumn("missing"))
                    XCTAssertTrue(row.databaseValue(named: "missing") == nil)
                    XCTAssertTrue(row.value(named: "missing") == nil)
                }
                XCTAssertTrue(rowFetched)
            }
        }
    }
    
    func testRowHasColumnIsCaseInsensitive() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                var rowFetched = false
                for row in Row.fetch(db, "SELECT 'foo' AS nAmE, 1 AS foo") {
                    rowFetched = true
                    XCTAssertTrue(row.hasColumn("name"))
                    XCTAssertTrue(row.hasColumn("NAME"))
                    XCTAssertTrue(row.hasColumn("Name"))
                    XCTAssertTrue(row.hasColumn("NaMe"))
                    XCTAssertTrue(row.hasColumn("foo"))
                    XCTAssertTrue(row.hasColumn("Foo"))
                    XCTAssertTrue(row.hasColumn("FOO"))
                }
                XCTAssertTrue(rowFetched)
            }
        }
    }
    
    func testVariants() {
        let dbQueue = DatabaseQueue()
        dbQueue.inDatabase { db in
            var rowFetched = false
            for row in Row.fetch(db, "SELECT 'foo' AS nAmE, 1 AS foo") {
                rowFetched = true
                XCTAssertTrue(row.variant(named: "missing") == nil)
            }
            XCTAssertTrue(rowFetched)
        }
    }
    
    func testCopy() {
        assertNoError {
            let dbQueue = DatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (a INTEGER, b INTEGER, c INTEGER)")
                try db.execute("INSERT INTO ints (a,b,c) VALUES (0, 1, 2)")
                var rowFetched = false
                for row in Row.fetch(db, "SELECT * FROM ints") {
                    rowFetched = true
                    let copiedRow = row.copy()
                    XCTAssertEqual(copiedRow.count, 3)
                    XCTAssertEqual(copiedRow.value(named: "a") as Int, 0)
                    XCTAssertEqual(copiedRow.value(named: "b") as Int, 1)
                    XCTAssertEqual(copiedRow.value(named: "c") as Int, 2)
                }
                XCTAssertTrue(rowFetched)
            }
        }
    }
    
    func testEqualityWithCopy() {
        assertNoError {
            let dbQueue = DatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (a INTEGER, b INTEGER, c INTEGER)")
                try db.execute("INSERT INTO ints (a,b,c) VALUES (0, 1, 2)")
                var rowFetched = false
                for row in Row.fetch(db, "SELECT * FROM ints") {
                    rowFetched = true
                    let copiedRow = row.copy()
                    XCTAssertEqual(row, copiedRow)
                }
                XCTAssertTrue(rowFetched)
            }
        }
    }
}

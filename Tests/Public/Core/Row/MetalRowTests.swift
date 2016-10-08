import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private enum CustomValue : Int, DatabaseValueConvertible, Equatable {
    case a = 0
    case b = 1
    case c = 2
}

class MetalRowTests : RowTestCase {
    
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
                    
                    // Raw extraction
                    assertRowRawValueEqual(row, index: 0, value: 0 as Int64)
                    assertRowRawValueEqual(row, index: 1, value: 1 as Int64)
                    assertRowRawValueEqual(row, index: 2, value: 2 as Int64)
                    
                    // DatabaseValueConvertible & StatementColumnConvertible
                    assertRowConvertedValueEqual(row, index: 0, value: 0 as Int)
                    assertRowConvertedValueEqual(row, index: 1, value: 1 as Int)
                    assertRowConvertedValueEqual(row, index: 2, value: 2 as Int)
                    
                    // DatabaseValueConvertible
                    assertRowConvertedValueEqual(row, index: 0, value: CustomValue.a)
                    assertRowConvertedValueEqual(row, index: 1, value: CustomValue.b)
                    assertRowConvertedValueEqual(row, index: 2, value: CustomValue.c)
                    
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
                    
                    // Raw extraction
                    assertRowRawValueEqual(row, name: "a", value: 0 as Int64)
                    assertRowRawValueEqual(row, name: "b", value: 1 as Int64)
                    assertRowRawValueEqual(row, name: "c", value: 2 as Int64)
                    
                    // DatabaseValueConvertible & StatementColumnConvertible
                    assertRowConvertedValueEqual(row, name: "a", value: 0 as Int)
                    assertRowConvertedValueEqual(row, name: "b", value: 1 as Int)
                    assertRowConvertedValueEqual(row, name: "c", value: 2 as Int)
                    
                    // DatabaseValueConvertible
                    assertRowConvertedValueEqual(row, name: "a", value: CustomValue.a)
                    assertRowConvertedValueEqual(row, name: "b", value: CustomValue.b)
                    assertRowConvertedValueEqual(row, name: "c", value: CustomValue.c)
                }
                XCTAssertTrue(rowFetched)
            }
        }
    }
    
    func testRowValueFromColumn() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (a INTEGER, b INTEGER, c INTEGER)")
                try db.execute("INSERT INTO ints (a,b,c) VALUES (0, 1, 2)")
                var rowFetched = false
                for row in Row.fetch(db, "SELECT * FROM ints") {
                    rowFetched = true
                    
                    // Raw extraction
                    assertRowRawValueEqual(row, column: Column("a"), value: 0 as Int64)
                    assertRowRawValueEqual(row, column: Column("b"), value: 1 as Int64)
                    assertRowRawValueEqual(row, column: Column("c"), value: 2 as Int64)
                    
                    // DatabaseValueConvertible & StatementColumnConvertible
                    assertRowConvertedValueEqual(row, column: Column("a"), value: 0 as Int)
                    assertRowConvertedValueEqual(row, column: Column("b"), value: 1 as Int)
                    assertRowConvertedValueEqual(row, column: Column("c"), value: 2 as Int)
                    
                    // DatabaseValueConvertible
                    assertRowConvertedValueEqual(row, column: Column("a"), value: CustomValue.a)
                    assertRowConvertedValueEqual(row, column: Column("b"), value: CustomValue.b)
                    assertRowConvertedValueEqual(row, column: Column("c"), value: CustomValue.c)
                }
                XCTAssertTrue(rowFetched)
            }
        }
    }
    
    func testDataNoCopy() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                let data = "foo".data(using: .utf8)!
                var rowFetched = false
                for row in Row.fetch(db, "SELECT ? AS a", arguments: [data]) {
                    rowFetched = true
                    
                    XCTAssertEqual(row.dataNoCopy(atIndex: 0), data)
                    XCTAssertEqual(row.dataNoCopy(named: "a"), data)
                    XCTAssertEqual(row.dataNoCopy(Column("a")), data)
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
                    guard case .null = (row.value(atIndex: 0) as DatabaseValue).storage else { XCTFail(); return }
                    guard case .int64(let int64) = (row.value(atIndex: 1) as DatabaseValue).storage, int64 == 1 else { XCTFail(); return }
                    guard case .double(let double) = (row.value(atIndex: 2) as DatabaseValue).storage, double == 1.1 else { XCTFail(); return }
                    guard case .string(let string) = (row.value(atIndex: 3) as DatabaseValue).storage, string == "foo" else { XCTFail(); return }
                    guard case .blob(let data) = (row.value(atIndex: 4) as DatabaseValue).storage, data == "SQLite".data(using: .utf8) else { XCTFail(); return }
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
                    guard case .null = (row.value(named: "null") as DatabaseValue).storage else { XCTFail(); return }
                    guard case .int64(let int64) = (row.value(named: "int64") as DatabaseValue).storage, int64 == 1 else { XCTFail(); return }
                    guard case .double(let double) = (row.value(named: "double") as DatabaseValue).storage, double == 1.1 else { XCTFail(); return }
                    guard case .string(let string) = (row.value(named: "string") as DatabaseValue).storage, string == "foo" else { XCTFail(); return }
                    guard case .blob(let data) = (row.value(named: "blob") as DatabaseValue).storage, data == "SQLite".data(using: .utf8) else { XCTFail(); return }
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
                    XCTAssertEqual(row.value(named: "name") as DatabaseValue, "foo".databaseValue)
                    XCTAssertEqual(row.value(named: "NAME") as DatabaseValue, "foo".databaseValue)
                    XCTAssertEqual(row.value(named: "NaMe") as DatabaseValue, "foo".databaseValue)
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
                    XCTAssertEqual(row.value(named: "name") as DatabaseValue, 1.databaseValue)
                    XCTAssertEqual(row.value(named: "NAME") as DatabaseValue, 1.databaseValue)
                    XCTAssertEqual(row.value(named: "NaMe") as DatabaseValue, 1.databaseValue)
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
                    XCTAssertTrue(row.value(named: "missing") as DatabaseValue? == nil)
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
                XCTAssertTrue(row.scoped(on: "missing") == nil)
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

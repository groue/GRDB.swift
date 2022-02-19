import XCTest
import GRDB

private enum CustomValue : Int, DatabaseValueConvertible, Equatable {
    case a = 0
    case b = 1
    case c = 2
}

class RowFromStatementTests : RowTestCase {
    
    func testRowAsSequence() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE ints (a INTEGER, b INTEGER, c INTEGER)")
            try db.execute(sql: "INSERT INTO ints (a,b,c) VALUES (0, 1, 2)")
            var rowFetched = false
            let rows = try Row.fetchCursor(db, sql: "SELECT * FROM ints")
            while let row = try rows.next() {
                rowFetched = true
                var columnNames = [String]()
                var ints = [Int]()
                var bools = [Bool]()
                for (columnName, dbValue) in row {
                    columnNames.append(columnName)
                    ints.append(Int.fromDatabaseValue(dbValue)!)
                    bools.append(Bool.fromDatabaseValue(dbValue)!)
                }
                
                XCTAssertEqual(columnNames, ["a", "b", "c"])
                XCTAssertEqual(ints, [0, 1, 2])
                XCTAssertEqual(bools, [false, true, true])
            }
            XCTAssertTrue(rowFetched)
        }
    }

    func testRowValueAtIndex() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE ints (a INTEGER, b INTEGER, c INTEGER)")
            try db.execute(sql: "INSERT INTO ints (a,b,c) VALUES (0, 1, 2)")
            var rowFetched = false
            let rows = try Row.fetchCursor(db, sql: "SELECT * FROM ints")
            while let row = try rows.next() {
                rowFetched = true
                
                // Raw extraction
                assertRowRawValueEqual(row, index: 0, value: 0.databaseValue)
                assertRowRawValueEqual(row, index: 1, value: 1.databaseValue)
                assertRowRawValueEqual(row, index: 2, value: 2.databaseValue)
                
                // DatabaseValueConvertible & StatementColumnConvertible
                try assertRowConvertedValueEqual(row, index: 0, value: 0 as Int)
                try assertRowConvertedValueEqual(row, index: 1, value: 1 as Int)
                try assertRowConvertedValueEqual(row, index: 2, value: 2 as Int)
                
                // DatabaseValueConvertible
                try assertRowConvertedValueEqual(row, index: 0, value: CustomValue.a)
                try assertRowConvertedValueEqual(row, index: 1, value: CustomValue.b)
                try assertRowConvertedValueEqual(row, index: 2, value: CustomValue.c)
                
                // Expect fatal error:
                //
                // row[-1]
                // row[3]
            }
            XCTAssertTrue(rowFetched)
        }
    }

    func testRowValueNamed() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE ints (a INTEGER, b INTEGER, c INTEGER)")
            try db.execute(sql: "INSERT INTO ints (a,b,c) VALUES (0, 1, 2)")
            var rowFetched = false
            let rows = try Row.fetchCursor(db, sql: "SELECT * FROM ints")
            while let row = try rows.next() {
                rowFetched = true
                
                // Raw extraction
                assertRowRawValueEqual(row, name: "a", value: 0.databaseValue)
                assertRowRawValueEqual(row, name: "b", value: 1.databaseValue)
                assertRowRawValueEqual(row, name: "c", value: 2.databaseValue)
                
                // DatabaseValueConvertible & StatementColumnConvertible
                try assertRowConvertedValueEqual(row, name: "a", value: 0 as Int)
                try assertRowConvertedValueEqual(row, name: "b", value: 1 as Int)
                try assertRowConvertedValueEqual(row, name: "c", value: 2 as Int)
                
                // DatabaseValueConvertible
                try assertRowConvertedValueEqual(row, name: "a", value: CustomValue.a)
                try assertRowConvertedValueEqual(row, name: "b", value: CustomValue.b)
                try assertRowConvertedValueEqual(row, name: "c", value: CustomValue.c)
            }
            XCTAssertTrue(rowFetched)
        }
    }

    func testRowValueFromColumn() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE ints (a INTEGER, b INTEGER, c INTEGER)")
            try db.execute(sql: "INSERT INTO ints (a,b,c) VALUES (0, 1, 2)")
            var rowFetched = false
            let rows = try Row.fetchCursor(db, sql: "SELECT * FROM ints")
            while let row = try rows.next() {
                rowFetched = true
                
                // Raw extraction
                assertRowRawValueEqual(row, column: Column("a"), value: 0.databaseValue)
                assertRowRawValueEqual(row, column: Column("b"), value: 1.databaseValue)
                assertRowRawValueEqual(row, column: Column("c"), value: 2.databaseValue)
                
                // DatabaseValueConvertible & StatementColumnConvertible
                try assertRowConvertedValueEqual(row, column: Column("a"), value: 0 as Int)
                try assertRowConvertedValueEqual(row, column: Column("b"), value: 1 as Int)
                try assertRowConvertedValueEqual(row, column: Column("c"), value: 2 as Int)
                
                // DatabaseValueConvertible
                try assertRowConvertedValueEqual(row, column: Column("a"), value: CustomValue.a)
                try assertRowConvertedValueEqual(row, column: Column("b"), value: CustomValue.b)
                try assertRowConvertedValueEqual(row, column: Column("c"), value: CustomValue.c)
            }
            XCTAssertTrue(rowFetched)
        }
    }

    func testDataNoCopy() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let data = "foo".data(using: .utf8)!
            let emptyData = Data()
            var rowFetched = false
            let rows = try Row.fetchCursor(db, sql: "SELECT ? AS a, ? AS b, ? AS c", arguments: [data, emptyData, nil])
            while let row = try rows.next() {
                rowFetched = true
                
                try XCTAssertEqual(row.dataNoCopy(atIndex: 0), data)
                try XCTAssertEqual(row.dataNoCopy(named: "a"), data)
                try XCTAssertEqual(row.dataNoCopy(Column("a")), data)
                
                try XCTAssertEqual(row.dataNoCopy(atIndex: 1), emptyData)
                try XCTAssertEqual(row.dataNoCopy(named: "b"), emptyData)
                try XCTAssertEqual(row.dataNoCopy(Column("b")), emptyData)
                
                try XCTAssertNil(row.dataNoCopy(atIndex: 2))
                try XCTAssertNil(row.dataNoCopy(named: "c"))
                try XCTAssertNil(row.dataNoCopy(Column("c")))
            }
            XCTAssertTrue(rowFetched)
        }
    }

    func testRowDatabaseValueAtIndex() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var rowFetched = false
            let rows = try Row.fetchCursor(db, sql: "SELECT NULL, 1, 1.1, 'foo', x'53514C697465'")
            while let row = try rows.next() {
                rowFetched = true
                guard case .null = row.databaseValue(atIndex: 0).storage else { XCTFail(); return }
                guard case .int64(let int64) = row.databaseValue(atIndex: 1).storage, int64 == 1 else { XCTFail(); return }
                guard case .double(let double) = row.databaseValue(atIndex: 2).storage, double == 1.1 else { XCTFail(); return }
                guard case .string(let string) = row.databaseValue(atIndex: 3).storage, string == "foo" else { XCTFail(); return }
                guard case .blob(let data) = row.databaseValue(atIndex: 4).storage, data == "SQLite".data(using: .utf8) else { XCTFail(); return }
            }
            XCTAssertTrue(rowFetched)
        }
    }

    func testRowDatabaseValueNamed() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var rowFetched = false
            let rows = try Row.fetchCursor(db, sql: "SELECT NULL AS \"null\", 1 AS \"int64\", 1.1 AS \"double\", 'foo' AS \"string\", x'53514C697465' AS \"blob\"")
            while let row = try rows.next() {
                rowFetched = true
                guard case .null = row.databaseValue(forColumn: "null")!.storage else { XCTFail(); return }
                guard case .int64(let int64) = row.databaseValue(forColumn: "int64")!.storage, int64 == 1 else { XCTFail(); return }
                guard case .double(let double) = row.databaseValue(forColumn: "double")!.storage, double == 1.1 else { XCTFail(); return }
                guard case .string(let string) = row.databaseValue(forColumn: "string")!.storage, string == "foo" else { XCTFail(); return }
                guard case .blob(let data) = row.databaseValue(forColumn: "blob")!.storage, data == "SQLite".data(using: .utf8) else { XCTFail(); return }
            }
            XCTAssertTrue(rowFetched)
        }
    }

    func testRowCount() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE ints (a INTEGER, b INTEGER, c INTEGER)")
            try db.execute(sql: "INSERT INTO ints (a,b,c) VALUES (0, 1, 2)")
            var rowFetched = false
            let rows = try Row.fetchCursor(db, sql: "SELECT * FROM ints")
            while let row = try rows.next() {
                rowFetched = true
                XCTAssertEqual(row.count, 3)
            }
            XCTAssertTrue(rowFetched)
        }
    }

    func testRowColumnNames() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE ints (a INTEGER, b INTEGER, c INTEGER)")
            try db.execute(sql: "INSERT INTO ints (a,b,c) VALUES (0, 1, 2)")
            var rowFetched = false
            let rows = try Row.fetchCursor(db, sql: "SELECT a, b, c FROM ints")
            while let row = try rows.next() {
                rowFetched = true
                XCTAssertEqual(Array(row.columnNames), ["a", "b", "c"])
            }
            XCTAssertTrue(rowFetched)
        }
    }

    func testRowDatabaseValues() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE ints (a INTEGER, b INTEGER, c INTEGER)")
            try db.execute(sql: "INSERT INTO ints (a,b,c) VALUES (0, 1, 2)")
            var rowFetched = false
            let rows = try Row.fetchCursor(db, sql: "SELECT a, b, c FROM ints")
            while let row = try rows.next() {
                rowFetched = true
                XCTAssertEqual(Array(row.databaseValues), [0.databaseValue, 1.databaseValue, 2.databaseValue])
            }
            XCTAssertTrue(rowFetched)
        }
    }

    func testRowIsCaseInsensitive() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var rowFetched = false
            let rows = try Row.fetchCursor(db, sql: "SELECT 'foo' AS nAmE")
            while let row = try rows.next() {
                rowFetched = true
                XCTAssertEqual(row.databaseValue(forColumn: "name"), "foo".databaseValue)
                XCTAssertEqual(row.databaseValue(forColumn: "NAME"), "foo".databaseValue)
                XCTAssertEqual(row.databaseValue(forColumn: "NaMe"), "foo".databaseValue)
                try XCTAssertEqual(row["name"] as String, "foo")
                try XCTAssertEqual(row["NAME"] as String, "foo")
                try XCTAssertEqual(row["NaMe"] as String, "foo")
            }
            XCTAssertTrue(rowFetched)
        }
    }

    func testRowIsCaseInsensitiveAndReturnsLeftmostMatchingColumn() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var rowFetched = false
            let rows = try Row.fetchCursor(db, sql: "SELECT 1 AS name, 2 AS NAME")
            while let row = try rows.next() {
                rowFetched = true
                XCTAssertEqual(row.databaseValue(forColumn: "name"), 1.databaseValue)
                XCTAssertEqual(row.databaseValue(forColumn: "NAME"), 1.databaseValue)
                XCTAssertEqual(row.databaseValue(forColumn: "NaMe"), 1.databaseValue)
                try XCTAssertEqual(row["name"] as Int, 1)
                try XCTAssertEqual(row["NAME"] as Int, 1)
                try XCTAssertEqual(row["NaMe"] as Int, 1)
            }
            XCTAssertTrue(rowFetched)
        }
    }

    func testMissingColumn() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var rowFetched = false
            let rows = try Row.fetchCursor(db, sql: "SELECT 'foo' AS name")
            while let row = try rows.next() {
                rowFetched = true
                XCTAssertFalse(row.hasColumn("missing"))
                XCTAssertTrue(row.databaseValue(forColumn: "missing") == nil)
                XCTAssertTrue(row["missing"] == nil)
            }
            XCTAssertTrue(rowFetched)
        }
    }

    func testRowHasColumnIsCaseInsensitive() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var rowFetched = false
            let rows = try Row.fetchCursor(db, sql: "SELECT 'foo' AS nAmE, 1 AS foo")
            while let row = try rows.next() {
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

    func testScopes() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var rowFetched = false
            let rows = try Row.fetchCursor(db, sql: "SELECT 'foo' AS nAmE, 1 AS foo")
            while let row = try rows.next() {
                rowFetched = true
                XCTAssertTrue(row.scopes.isEmpty)
                XCTAssertTrue(row.scopes["missing"] == nil)
                XCTAssertTrue(row.scopesTree["missing"] == nil)
            }
            XCTAssertTrue(rowFetched)
        }
    }

    func testCopy() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE ints (a INTEGER, b INTEGER, c INTEGER)")
            try db.execute(sql: "INSERT INTO ints (a,b,c) VALUES (0, 1, 2)")
            var rowFetched = false
            let rows = try Row.fetchCursor(db, sql: "SELECT * FROM ints")
            while let row = try rows.next() {
                rowFetched = true
                let copiedRow = row.copy()
                XCTAssertEqual(copiedRow.count, 3)
                try XCTAssertEqual(copiedRow["a"] as Int, 0)
                try XCTAssertEqual(copiedRow["b"] as Int, 1)
                try XCTAssertEqual(copiedRow["c"] as Int, 2)
            }
            XCTAssertTrue(rowFetched)
        }
    }

    func testEqualityWithCopy() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE ints (a INTEGER, b INTEGER, c INTEGER)")
            try db.execute(sql: "INSERT INTO ints (a,b,c) VALUES (0, 1, 2)")
            var rowFetched = false
            let rows = try Row.fetchCursor(db, sql: "SELECT * FROM ints")
            while let row = try rows.next() {
                rowFetched = true
                let copiedRow = row.copy()
                XCTAssertEqual(row, copiedRow)
            }
            XCTAssertTrue(rowFetched)
        }
    }

    func testDatabaseCursorMap() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let cursor = try Row.fetchCursor(db, sql: "SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3")
            let values = cursor.map { try $0[0] as Int }
            XCTAssertEqual(try values.next()!, 1)
            XCTAssertEqual(try values.next()!, 2)
            XCTAssertEqual(try values.next()!, 3)
            XCTAssertTrue(try values.next() == nil)
        }
    }
    
    func testDescription() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let rows = try Row.fetchCursor(db, sql: "SELECT NULL AS \"null\", 1 AS \"int\", 1.1 AS \"double\", 'foo' AS \"string\", x'53514C697465' AS \"data\"")
            var rowFetched = false
            while let row = try rows.next() {
                rowFetched = true
                XCTAssertEqual(row.description, "[null:NULL int:1 double:1.1 string:\"foo\" data:Data(6 bytes)]")
                XCTAssertEqual(row.debugDescription, "[null:NULL int:1 double:1.1 string:\"foo\" data:Data(6 bytes)]")
            }
            XCTAssertTrue(rowFetched)
        }
    }
}

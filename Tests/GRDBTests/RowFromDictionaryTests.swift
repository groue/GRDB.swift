import XCTest
import GRDB

private enum CustomValue : Int, DatabaseValueConvertible, Equatable {
    case a = 0
    case b = 1
    case c = 2
}

class RowFromDictionaryTests : RowTestCase {
    
    func testRowAsSequence() {
        let row = Row(["a": 0, "b": 1, "c": 2])
        
        var columnNames = Set<String>()
        var ints = Set<Int>()
        var bools = Set<Bool>()
        for (columnName, dbValue) in row {
            columnNames.insert(columnName)
            ints.insert(Int.fromDatabaseValue(dbValue)!)
            bools.insert(Bool.fromDatabaseValue(dbValue)!)
        }
        
        XCTAssertEqual(columnNames, ["a", "b", "c"])
        XCTAssertEqual(ints, [0, 1, 2])
        XCTAssertEqual(bools, [false, true, true])
    }
    
    func testRowValueAtIndex() {
        let dictionary: [String: (any DatabaseValueConvertible)?] = ["a": 0, "b": 1, "c": 2]
        let row = Row(dictionary)
        
        let aIndex = dictionary.distance(from: dictionary.startIndex, to: dictionary.index(forKey: "a")!)
        let bIndex = dictionary.distance(from: dictionary.startIndex, to: dictionary.index(forKey: "b")!)
        let cIndex = dictionary.distance(from: dictionary.startIndex, to: dictionary.index(forKey: "c")!)
        
        // Raw extraction
        assertRowRawValueEqual(row, index: aIndex, value: 0 as Int64)
        assertRowRawValueEqual(row, index: bIndex, value: 1 as Int64)
        assertRowRawValueEqual(row, index: cIndex, value: 2 as Int64)
        
        // DatabaseValueConvertible & StatementColumnConvertible
        assertRowConvertedValueEqual(row, index: aIndex, value: 0 as Int)
        assertRowConvertedValueEqual(row, index: bIndex, value: 1 as Int)
        assertRowConvertedValueEqual(row, index: cIndex, value: 2 as Int)
        
        // DatabaseValueConvertible
        assertRowConvertedValueEqual(row, index: aIndex, value: CustomValue.a)
        assertRowConvertedValueEqual(row, index: bIndex, value: CustomValue.b)
        assertRowConvertedValueEqual(row, index: cIndex, value: CustomValue.c)
        
        // Expect fatal error:
        //
        // row[-1]
        // row[3]
    }
    
    func testRowValueNamed() {
        let row = Row(["a": 0, "b": 1, "c": 2])
        
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
    
    func testRowValueFromColumn() {
        let row = Row(["a": 0, "b": 1, "c": 2])
        
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
    
    func testWithUnsafeData() throws {
        do {
            let data = "foo".data(using: .utf8)!
            let row: Row = ["a": data]
            
            try row.withUnsafeData(atIndex: 0) { XCTAssertEqual($0, data) }
            try row.withUnsafeData(named: "a") { XCTAssertEqual($0, data) }
            try row.withUnsafeData(at: Column("a")) { XCTAssertEqual($0, data) }
            
            try row.withUnsafeData(named: "missing") { XCTAssertNil($0) }
            try row.withUnsafeData(at: Column("missing")) { XCTAssertNil($0) }
        }
        do {
            let emptyData = Data()
            let row: Row = ["a": emptyData]
            
            try row.withUnsafeData(atIndex: 0) { XCTAssertEqual($0, emptyData) }
            try row.withUnsafeData(named: "a") { XCTAssertEqual($0, emptyData) }
            try row.withUnsafeData(at: Column("a")) { XCTAssertEqual($0, emptyData) }
        }
        do {
            let row: Row = ["a": nil]
            
            try row.withUnsafeData(atIndex: 0) { XCTAssertNil($0) }
            try row.withUnsafeData(named: "a") { XCTAssertNil($0) }
            try row.withUnsafeData(at: Column("a")) { XCTAssertNil($0) }
        }
    }
    
    func testRowDatabaseValueAtIndex() throws {
        let dictionary: [String: (any DatabaseValueConvertible)?] = ["null": nil, "int64": 1, "double": 1.1, "string": "foo", "blob": "SQLite".data(using: .utf8)]
        let row = Row(dictionary)
        
        let nullIndex = dictionary.distance(from: dictionary.startIndex, to: dictionary.index(forKey: "null")!)
        let int64Index = dictionary.distance(from: dictionary.startIndex, to: dictionary.index(forKey: "int64")!)
        let doubleIndex = dictionary.distance(from: dictionary.startIndex, to: dictionary.index(forKey: "double")!)
        let stringIndex = dictionary.distance(from: dictionary.startIndex, to: dictionary.index(forKey: "string")!)
        let blobIndex = dictionary.distance(from: dictionary.startIndex, to: dictionary.index(forKey: "blob")!)
        
        guard case .null = (row[nullIndex] as DatabaseValue).storage else { XCTFail(); return }
        guard case .int64(let int64) = (row[int64Index] as DatabaseValue).storage, int64 == 1 else { XCTFail(); return }
        guard case .double(let double) = (row[doubleIndex] as DatabaseValue).storage, double == 1.1 else { XCTFail(); return }
        guard case .string(let string) = (row[stringIndex] as DatabaseValue).storage, string == "foo" else { XCTFail(); return }
        guard case .blob(let data) = (row[blobIndex] as DatabaseValue).storage, data == "SQLite".data(using: .utf8) else { XCTFail(); return }
    }

    func testRowDatabaseValueNamed() throws {
        let dictionary: [String: (any DatabaseValueConvertible)?] = ["null": nil, "int64": 1, "double": 1.1, "string": "foo", "blob": "SQLite".data(using: .utf8)]
        let row = Row(dictionary)
        
        guard case .null = (row["null"] as DatabaseValue).storage else { XCTFail(); return }
        guard case .int64(let int64) = (row["int64"] as DatabaseValue).storage, int64 == 1 else { XCTFail(); return }
        guard case .double(let double) = (row["double"] as DatabaseValue).storage, double == 1.1 else { XCTFail(); return }
        guard case .string(let string) = (row["string"] as DatabaseValue).storage, string == "foo" else { XCTFail(); return }
        guard case .blob(let data) = (row["blob"] as DatabaseValue).storage, data == "SQLite".data(using: .utf8) else { XCTFail(); return }
    }

    func testRowCount() {
        let row = Row(["a": 0, "b": 1, "c": 2])
        XCTAssertEqual(row.count, 3)
    }
    
    func testRowColumnNames() {
        let row = Row(["a": 0, "b": 1, "c": 2])
        XCTAssertEqual(Array(row.columnNames).sorted(), ["a", "b", "c"])
    }
    
    func testRowDatabaseValues() {
        let row = Row(["a": 0, "b": 1, "c": 2])
        XCTAssertEqual(row.databaseValues.sorted { Int.fromDatabaseValue($0)! < Int.fromDatabaseValue($1)! }, [0.databaseValue, 1.databaseValue, 2.databaseValue])
    }
    
    func testRowIsCaseInsensitive() {
        let row = Row(["name": "foo"])
        XCTAssertEqual(row["name"] as DatabaseValue, "foo".databaseValue)
        XCTAssertEqual(row["NAME"] as DatabaseValue, "foo".databaseValue)
        XCTAssertEqual(row["NaMe"] as DatabaseValue, "foo".databaseValue)
        XCTAssertEqual(row["name"] as String, "foo")
        XCTAssertEqual(row["NAME"] as String, "foo")
        XCTAssertEqual(row["NaMe"] as String, "foo")
    }
    
    func testMissingColumn() {
        let row = Row(["name": "foo"])
        XCTAssertFalse(row.hasColumn("missing"))
        XCTAssertTrue(row["missing"] as DatabaseValue? == nil)
        XCTAssertTrue(row["missing"] == nil)
    }
    
    func testRowHasColumnIsCaseInsensitive() {
        let row = Row(["nAmE": "foo", "foo": 1])
        XCTAssertTrue(row.hasColumn("name"))
        XCTAssertTrue(row.hasColumn("NAME"))
        XCTAssertTrue(row.hasColumn("Name"))
        XCTAssertTrue(row.hasColumn("NaMe"))
        XCTAssertTrue(row.hasColumn("foo"))
        XCTAssertTrue(row.hasColumn("Foo"))
        XCTAssertTrue(row.hasColumn("FOO"))
    }
    
    func testScopes() {
        let row = Row(["a": 0, "b": 1, "c": 2])
        XCTAssertTrue(row.scopes.isEmpty)
        XCTAssertTrue(row.scopes["missing"] == nil)
        XCTAssertTrue(row.scopesTree["missing"] == nil)
    }
    
    func testCopy() {
        let row = Row(["a": 0, "b": 1, "c": 2])
        
        let copiedRow = row.copy()
        XCTAssertEqual(copiedRow.count, 3)
        XCTAssertEqual(copiedRow["a"] as Int, 0)
        XCTAssertEqual(copiedRow["b"] as Int, 1)
        XCTAssertEqual(copiedRow["c"] as Int, 2)
    }
    
    func testEqualityWithCopy() {
        let row = Row(["a": 0, "b": 1, "c": 2])
        
        let copiedRow = row.copy()
        XCTAssertEqual(row, copiedRow)
    }
    
    func testDescription() throws {
        let row = Row(["a": 0, "b": "foo"])
        let variants: Set<String> = ["[a:0 b:\"foo\"]", "[b:\"foo\" a:0]"]
        XCTAssert(variants.contains(row.description))
        let debugVariants: Set<String> = ["[a:0 b:\"foo\"]", "[b:\"foo\" a:0]"]
        XCTAssert(debugVariants.contains(row.debugDescription))
    }
    
    func testCoalesce() throws {
        let rows = [
            Row(["nickname": "Artie", "name": "Arthur"]),
            Row(["nickname": nil, "name": "Jacob"]),
            Row(["nickname": nil, "name": nil]),
        ]
        let values = rows.map { row in
            [
                row.coalesce(Array<String>()) as String?,
                row.coalesce(["nickname"]) as String?,
                row.coalesce(["nickname", "name"]) as String?,
                row.coalesce([Column("nickname"), Column("name")]) as String?,
            ]
        }
        XCTAssertEqual(values, [
            [nil, "Artie", "Artie", "Artie"],
            [nil, nil, "Jacob", "Jacob"],
            [nil, nil, nil, nil],
        ])
    }
}

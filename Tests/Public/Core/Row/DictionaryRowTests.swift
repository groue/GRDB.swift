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

class DictionaryRowTests : RowTestCase {
    
    func testRowAsSequence() {
        let row = Row(["a": 0, "b": 1, "c": 2])
        
        var columnNames = Set<String>()
        var ints = Set<Int>()
        var bools = Set<Bool>()
        for (columnName, databaseValue) in row {
            columnNames.insert(columnName)
            ints.insert(databaseValue.value() as Int)
            bools.insert(databaseValue.value() as Bool)
        }
        
        XCTAssertEqual(columnNames, ["a", "b", "c"])
        XCTAssertEqual(ints, [0, 1, 2])
        XCTAssertEqual(bools, [false, true, true])
    }
    
    func testRowValueAtIndex() {
        let dictionary: [String: DatabaseValueConvertible?] = ["a": 0, "b": 1, "c": 2]
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
        // row.value(atIndex: -1)
        // row.value(atIndex: 3)
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
    
    func testDataNoCopy() {
        let data = "foo".data(using: .utf8)!
        let row = Row(["a": data])
        
        XCTAssertEqual(row.dataNoCopy(atIndex: 0), data)
        XCTAssertEqual(row.dataNoCopy(named: "a"), data)
        XCTAssertEqual(row.dataNoCopy(Column("a")), data)
    }
    
    func testRowDatabaseValueAtIndex() {
        assertNoError {
            let dictionary: [String: DatabaseValueConvertible?] = ["null": nil, "int64": 1, "double": 1.1, "string": "foo", "blob": "SQLite".data(using: .utf8)]
            let row = Row(dictionary)
            
            let nullIndex = dictionary.distance(from: dictionary.startIndex, to: dictionary.index(forKey: "null")!)
            let int64Index = dictionary.distance(from: dictionary.startIndex, to: dictionary.index(forKey: "int64")!)
            let doubleIndex = dictionary.distance(from: dictionary.startIndex, to: dictionary.index(forKey: "double")!)
            let stringIndex = dictionary.distance(from: dictionary.startIndex, to: dictionary.index(forKey: "string")!)
            let blobIndex = dictionary.distance(from: dictionary.startIndex, to: dictionary.index(forKey: "blob")!)
            
            guard case .null = (row.value(atIndex: nullIndex) as DatabaseValue).storage else { XCTFail(); return }
            guard case .int64(let int64) = (row.value(atIndex: int64Index) as DatabaseValue).storage, int64 == 1 else { XCTFail(); return }
            guard case .double(let double) = (row.value(atIndex: doubleIndex) as DatabaseValue).storage, double == 1.1 else { XCTFail(); return }
            guard case .string(let string) = (row.value(atIndex: stringIndex) as DatabaseValue).storage, string == "foo" else { XCTFail(); return }
            guard case .blob(let data) = (row.value(atIndex: blobIndex) as DatabaseValue).storage, data == "SQLite".data(using: .utf8) else { XCTFail(); return }
        }
    }
    
    func testRowDatabaseValueNamed() {
        assertNoError {
            let dictionary: [String: DatabaseValueConvertible?] = ["null": nil, "int64": 1, "double": 1.1, "string": "foo", "blob": "SQLite".data(using: .utf8)]
            let row = Row(dictionary)

            guard case .null = (row.value(named: "null") as DatabaseValue).storage else { XCTFail(); return }
            guard case .int64(let int64) = (row.value(named: "int64") as DatabaseValue).storage, int64 == 1 else { XCTFail(); return }
            guard case .double(let double) = (row.value(named: "double") as DatabaseValue).storage, double == 1.1 else { XCTFail(); return }
            guard case .string(let string) = (row.value(named: "string") as DatabaseValue).storage, string == "foo" else { XCTFail(); return }
            guard case .blob(let data) = (row.value(named: "blob") as DatabaseValue).storage, data == "SQLite".data(using: .utf8) else { XCTFail(); return }
        }
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
        XCTAssertEqual(row.databaseValues.sorted { ($0.value() as Int!) < ($1.value() as Int!) }, [0.databaseValue, 1.databaseValue, 2.databaseValue])
    }
    
    func testRowIsCaseInsensitive() {
        let row = Row(["name": "foo"])
        XCTAssertEqual(row.value(named: "name") as DatabaseValue, "foo".databaseValue)
        XCTAssertEqual(row.value(named: "NAME") as DatabaseValue, "foo".databaseValue)
        XCTAssertEqual(row.value(named: "NaMe") as DatabaseValue, "foo".databaseValue)
        XCTAssertEqual(row.value(named: "name") as String, "foo")
        XCTAssertEqual(row.value(named: "NAME") as String, "foo")
        XCTAssertEqual(row.value(named: "NaMe") as String, "foo")
    }
    
    func testMissingColumn() {
        let row = Row(["name": "foo"])
        XCTAssertFalse(row.hasColumn("missing"))
        XCTAssertTrue(row.value(named: "missing") as DatabaseValue? == nil)
        XCTAssertTrue(row.value(named: "missing") == nil)
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
    
    func testSubRows() {
        let row = Row(["a": 0, "b": 1, "c": 2])
        XCTAssertTrue(row.scoped(on: "missing") == nil)
    }
    
    func testCopy() {
        let row = Row(["a": 0, "b": 1, "c": 2])
        
        let copiedRow = row.copy()
        XCTAssertEqual(copiedRow.count, 3)
        XCTAssertEqual(copiedRow.value(named: "a") as Int, 0)
        XCTAssertEqual(copiedRow.value(named: "b") as Int, 1)
        XCTAssertEqual(copiedRow.value(named: "c") as Int, 2)
    }
    
    func testEqualityWithCopy() {
        let row = Row(["a": 0, "b": 1, "c": 2])
        
        let copiedRow = row.copy()
        XCTAssertEqual(row, copiedRow)
    }
}

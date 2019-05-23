import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private enum CustomValue : Int, DatabaseValueConvertible, Equatable {
    case a = 0
    case b = 1
    case c = 2
}

class AdapterRowTests : RowTestCase {
    
    func testRowAsSequence() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let adapter = ColumnMapping(["a": "basea", "b": "baseb", "c": "basec"])
            let row = try Row.fetchOne(db, sql: "SELECT 0 AS basea, 'XXX' AS extra, 1 AS baseb, 2 as basec", adapter: adapter)!
            
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
    }
    
    func testRowValueAtIndex() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let adapter = ColumnMapping(["a": "basea", "b": "baseb", "c": "basec"])
            let row = try Row.fetchOne(db, sql: "SELECT 0 AS basea, 'XXX' AS extra, 1 AS baseb, 2 as basec", adapter: adapter)!
            
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
            // row[-1]
            // row[3]
        }
    }
    
    func testRowValueNamed() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let adapter = ColumnMapping(["a": "basea", "b": "baseb", "c": "basec"])
            let row = try Row.fetchOne(db, sql: "SELECT 0 AS basea, 'XXX' AS extra, 1 AS baseb, 2 as basec", adapter: adapter)!
            
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
    }
    
    func testRowValueFromColumn() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let adapter = ColumnMapping(["a": "basea", "b": "baseb", "c": "basec"])
            let row = try Row.fetchOne(db, sql: "SELECT 0 AS basea, 'XXX' AS extra, 1 AS baseb, 2 as basec", adapter: adapter)!
            
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
    }
    
    func testDataNoCopy() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let data = "foo".data(using: .utf8)!
            let emptyData = Data()
            let adapter = ColumnMapping(["a": "basea", "b": "baseb", "c": "basec"])
            let row = try Row.fetchOne(db, sql: "SELECT ? AS basea, ? AS baseb, ? AS basec", arguments: [data, emptyData, nil], adapter: adapter)!
            
            XCTAssertEqual(row.dataNoCopy(atIndex: 0), data)
            XCTAssertEqual(row.dataNoCopy(named: "a"), data)
            XCTAssertEqual(row.dataNoCopy(Column("a")), data)
            
            XCTAssertEqual(row.dataNoCopy(atIndex: 1), emptyData)
            XCTAssertEqual(row.dataNoCopy(named: "b"), emptyData)
            XCTAssertEqual(row.dataNoCopy(Column("b")), emptyData)
            
            XCTAssertNil(row.dataNoCopy(atIndex: 2))
            XCTAssertNil(row.dataNoCopy(named: "c"))
            XCTAssertNil(row.dataNoCopy(Column("c")))
        }
    }

    func testRowDatabaseValueAtIndex() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let adapter = ColumnMapping(["null": "basenull", "int64": "baseint64", "double": "basedouble", "string": "basestring", "blob": "baseblob"])
            let row = try Row.fetchOne(db, sql: "SELECT NULL AS basenull, 'XXX' AS extra, 1 AS baseint64, 1.1 AS basedouble, 'foo' AS basestring, x'53514C697465' AS baseblob", adapter: adapter)!
            
            guard case .null = (row[0] as DatabaseValue).storage else { XCTFail(); return }
            guard case .int64(let int64) = (row[1] as DatabaseValue).storage, int64 == 1 else { XCTFail(); return }
            guard case .double(let double) = (row[2] as DatabaseValue).storage, double == 1.1 else { XCTFail(); return }
            guard case .string(let string) = (row[3] as DatabaseValue).storage, string == "foo" else { XCTFail(); return }
            guard case .blob(let data) = (row[4] as DatabaseValue).storage, data == "SQLite".data(using: .utf8) else { XCTFail(); return }
        }
    }

    func testRowDatabaseValueNamed() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let adapter = ColumnMapping(["null": "basenull", "int64": "baseint64", "double": "basedouble", "string": "basestring", "blob": "baseblob"])
            let row = try Row.fetchOne(db, sql: "SELECT NULL AS basenull, 'XXX' AS extra, 1 AS baseint64, 1.1 AS basedouble, 'foo' AS basestring, x'53514C697465' AS baseblob", adapter: adapter)!
            
            guard case .null = (row["null"] as DatabaseValue).storage else { XCTFail(); return }
            guard case .int64(let int64) = (row["int64"] as DatabaseValue).storage, int64 == 1 else { XCTFail(); return }
            guard case .double(let double) = (row["double"] as DatabaseValue).storage, double == 1.1 else { XCTFail(); return }
            guard case .string(let string) = (row["string"] as DatabaseValue).storage, string == "foo" else { XCTFail(); return }
            guard case .blob(let data) = (row["blob"] as DatabaseValue).storage, data == "SQLite".data(using: .utf8) else { XCTFail(); return }
        }
    }

    func testRowCount() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let adapter = ColumnMapping(["a": "basea", "b": "baseb", "c": "basec"])
            let row = try Row.fetchOne(db, sql: "SELECT 0 AS basea, 'XXX' AS extra, 1 AS baseb, 2 as basec", adapter: adapter)!
            
            XCTAssertEqual(row.count, 3)
        }
    }

    func testRowColumnNames() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let adapter = ColumnMapping(["a": "basea", "b": "baseb", "c": "basec"])
            let row = try Row.fetchOne(db, sql: "SELECT 0 AS basea, 'XXX' AS extra, 1 AS baseb, 2 as basec", adapter: adapter)!
            
            XCTAssertEqual(Array(row.columnNames), ["a", "b", "c"])
        }
    }

    func testRowDatabaseValues() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let adapter = ColumnMapping(["a": "basea", "b": "baseb", "c": "basec"])
            let row = try Row.fetchOne(db, sql: "SELECT 0 AS basea, 'XXX' AS extra, 1 AS baseb, 2 as basec", adapter: adapter)!
            
            XCTAssertEqual(Array(row.databaseValues), [0.databaseValue, 1.databaseValue, 2.databaseValue])
        }
    }

    func testRowIsCaseInsensitive() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let adapter = ColumnMapping(["nAmE": "basenAmE"])
            let row = try Row.fetchOne(db, sql: "SELECT 'foo' AS basenAmE, 'XXX' AS extra", adapter: adapter)!
            
            XCTAssertEqual(row["name"] as DatabaseValue, "foo".databaseValue)
            XCTAssertEqual(row["NAME"] as DatabaseValue, "foo".databaseValue)
            XCTAssertEqual(row["NaMe"] as DatabaseValue, "foo".databaseValue)
            XCTAssertEqual(row["name"] as String, "foo")
            XCTAssertEqual(row["NAME"] as String, "foo")
            XCTAssertEqual(row["NaMe"] as String, "foo")
        }
    }

    func testRowIsCaseInsensitiveAndReturnsLeftmostMatchingColumn() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let adapter = ColumnMapping(["name": "basename", "NAME": "baseNAME"])
            let row = try Row.fetchOne(db, sql: "SELECT 1 AS basename, 'XXX' AS extra, 2 AS baseNAME", adapter: adapter)!
            
            XCTAssertEqual(row["name"] as DatabaseValue, 1.databaseValue)
            XCTAssertEqual(row["NAME"] as DatabaseValue, 1.databaseValue)
            XCTAssertEqual(row["NaMe"] as DatabaseValue, 1.databaseValue)
            XCTAssertEqual(row["name"] as Int, 1)
            XCTAssertEqual(row["NAME"] as Int, 1)
            XCTAssertEqual(row["NaMe"] as Int, 1)
        }
    }

    func testRowAdapterIsCaseInsensitiveAndPicksLeftmostBaseColumn() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let adapter = ColumnMapping(["name": "baseNaMe"])
            let row = try Row.fetchOne(db, sql: "SELECT 1 AS basename, 2 AS baseNaMe, 3 AS BASENAME", adapter: adapter)!
            
            XCTAssertEqual(row["name"] as DatabaseValue, 1.databaseValue)
        }
    }
    
    func testMissingColumn() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let adapter = ColumnMapping(["name": "name"])
            let row = try Row.fetchOne(db, sql: "SELECT 1 AS name, 'foo' AS missing", adapter: adapter)!
            
            XCTAssertFalse(row.hasColumn("missing"))
            XCTAssertFalse(row.hasColumn("missingInBaseRow"))
            XCTAssertTrue(row["missing"] as DatabaseValue? == nil)
            XCTAssertTrue(row["missingInBaseRow"] as DatabaseValue? == nil)
            XCTAssertTrue(row["missing"] == nil)
            XCTAssertTrue(row["missingInBaseRow"] == nil)
        }
    }

    func testRowHasColumnIsCaseInsensitive() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let adapter = ColumnMapping(["nAmE": "basenAmE", "foo": "basefoo"])
            let row = try Row.fetchOne(db, sql: "SELECT 'foo' AS basenAmE, 'XXX' AS extra, 1 AS basefoo", adapter: adapter)!
            
            XCTAssertTrue(row.hasColumn("name"))
            XCTAssertTrue(row.hasColumn("NAME"))
            XCTAssertTrue(row.hasColumn("Name"))
            XCTAssertTrue(row.hasColumn("NaMe"))
            XCTAssertTrue(row.hasColumn("foo"))
            XCTAssertTrue(row.hasColumn("Foo"))
            XCTAssertTrue(row.hasColumn("FOO"))
        }
    }

    func testScopes() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let adapter = ScopeAdapter([
                "sub1": ColumnMapping(["id": "id1", "val": "val1"]),
                "sub2": ColumnMapping(["id": "id2", "val": "val2"])])
            let row = try Row.fetchOne(db, sql: "SELECT 1 AS id1, 'foo1' AS val1, 2 as id2, 'foo2' AS val2", adapter: adapter)!
            
            XCTAssertEqual(row.count, 4)
            XCTAssertEqual(row["id1"] as Int, 1)
            XCTAssertEqual(row["val1"] as String, "foo1")
            XCTAssertEqual(row["id2"] as Int, 2)
            XCTAssertEqual(row["val2"] as String, "foo2")
            
            XCTAssertEqual(Set(row.scopes.names), ["sub1", "sub2"])
            XCTAssertEqual(row.scopes.count, 2)
            for (name, scopedRow) in row.scopes {
                if name == "sub1" {
                    XCTAssertEqual(scopedRow, ["id": 1, "val": "foo1"])
                } else if name == "sub2" {
                    XCTAssertEqual(scopedRow, ["id": 2, "val": "foo2"])
                } else {
                    XCTFail()
                }
            }
            
            XCTAssertEqual(row.scopesTree.names, ["sub1", "sub2"])
            
            XCTAssertEqual(row.scopes["sub1"]!, ["id": 1, "val": "foo1"])
            XCTAssertTrue(row.scopes["sub1"]!.scopes.isEmpty)
            XCTAssertEqual(row.scopesTree["sub1"], row.scopes["sub1"])
            
            XCTAssertEqual(row.scopes["sub2"]!, ["id": 2, "val": "foo2"])
            XCTAssertTrue(row.scopes["sub2"]!.scopes.isEmpty)
            XCTAssertEqual(row.scopesTree["sub2"], row.scopes["sub2"])

            XCTAssertTrue(row.scopes["SUB1"] == nil)
            XCTAssertTrue(row.scopesTree["SUB1"] == nil)
            
            XCTAssertTrue(row.scopes["missing"] == nil)
            XCTAssertTrue(row.scopesTree["missing"] == nil)
        }
    }

    func testScopesWithMainMapping() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let adapter = ColumnMapping(["id": "id0", "val": "val0"])
                .addingScopes([
                    "sub1": ColumnMapping(["id": "id1", "val": "val1"]),
                    "sub2": ColumnMapping(["id": "id2", "val": "val2"])])
            let row = try Row.fetchOne(db, sql: "SELECT 0 AS id0, 'foo0' AS val0, 1 AS id1, 'foo1' AS val1, 2 as id2, 'foo2' AS val2", adapter: adapter)!
            
            XCTAssertEqual(row.count, 2)
            XCTAssertEqual(row["id"] as Int, 0)
            XCTAssertEqual(row["val"] as String, "foo0")
            
            XCTAssertEqual(Set(row.scopes.names), ["sub1", "sub2"])
            XCTAssertEqual(row.scopes.count, 2)
            for (name, scopedRow) in row.scopes {
                if name == "sub1" {
                    XCTAssertEqual(scopedRow, ["id": 1, "val": "foo1"])
                } else if name == "sub2" {
                    XCTAssertEqual(scopedRow, ["id": 2, "val": "foo2"])
                } else {
                    XCTFail()
                }
            }
            
            XCTAssertEqual(row.scopesTree.names, ["sub1", "sub2"])
            
            XCTAssertEqual(row.scopes["sub1"]!, ["id": 1, "val": "foo1"])
            XCTAssertTrue(row.scopes["sub1"]!.scopes.isEmpty)
            XCTAssertEqual(row.scopesTree["sub1"], row.scopes["sub1"])
            
            XCTAssertEqual(row.scopes["sub2"], ["id": 2, "val": "foo2"])
            XCTAssertTrue(row.scopes["sub2"]!.scopes.isEmpty)
            XCTAssertEqual(row.scopesTree["sub2"], row.scopes["sub2"])

            XCTAssertTrue(row.scopes["SUB1"] == nil)
            XCTAssertTrue(row.scopesTree["SUB1"] == nil)
            
            XCTAssertTrue(row.scopes["missing"] == nil)
            XCTAssertTrue(row.scopesTree["missing"] == nil)
        }
    }

    func testMergeScopes() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let adapter0 = ColumnMapping(["id": "id0", "val": "val0"])
            let adapter1 = ColumnMapping(["id": "id1", "val": "val1"])
            let adapter2 = ColumnMapping(["id": "id2", "val": "val2"])
            
            // - sub0 is defined in the the first scoped adapter
            // - sub1 is defined in the the first scoped adapter, and then
            // redefined in the second
            // - sub2 is defined in the the second scoped adapter
            let mainAdapter = ScopeAdapter(["sub0": adapter0, "sub1": adapter2])
            let adapter = mainAdapter.addingScopes(["sub1": adapter1, "sub2": adapter2])
            let row = try Row.fetchOne(db, sql: "SELECT 0 AS id0, 'foo0' AS val0, 1 AS id1, 'foo1' AS val1, 2 as id2, 'foo2' AS val2", adapter: adapter)!
            
            XCTAssertEqual(Set(row.scopes.names), ["sub0", "sub1", "sub2"])
            XCTAssertEqual(row.scopes.count, 3)
            for (name, scopedRow) in row.scopes {
                if name == "sub0" {
                    XCTAssertEqual(scopedRow, ["id": 0, "val": "foo0"])
                } else if name == "sub1" {
                    XCTAssertEqual(scopedRow, ["id": 1, "val": "foo1"])
                } else if name == "sub2" {
                    XCTAssertEqual(scopedRow, ["id": 2, "val": "foo2"])
                } else {
                    XCTFail()
                }
            }
            
            XCTAssertEqual(row.scopesTree.names, ["sub0", "sub1", "sub2"])
            
            XCTAssertEqual(row.scopes["sub0"], ["id": 0, "val": "foo0"])
            XCTAssertTrue(row.scopes["sub0"]!.scopes.isEmpty)
            XCTAssertEqual(row.scopesTree["sub0"], row.scopes["sub0"])

            XCTAssertEqual(row.scopes["sub1"], ["id": 1, "val": "foo1"])
            XCTAssertTrue(row.scopes["sub1"]!.scopes.isEmpty)
            XCTAssertEqual(row.scopesTree["sub1"], row.scopes["sub1"])
            
            XCTAssertEqual(row.scopes["sub2"], ["id": 2, "val": "foo2"])
            XCTAssertTrue(row.scopes["sub2"]!.scopes.isEmpty)
            XCTAssertEqual(row.scopesTree["sub2"], row.scopes["sub2"])
        }
    }

    func testThreeLevelScopes() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let adapter = ColumnMapping(["id": "id0", "val": "val0"])
                .addingScopes([
                    "sub1": ColumnMapping(["id": "id1", "val": "val1"])
                        .addingScopes([
                            "sub2": ColumnMapping(["id": "id2", "val": "val2"])])])
            let row = try Row.fetchOne(db, sql: "SELECT 0 AS id0, 'foo0' AS val0, 1 AS id1, 'foo1' AS val1, 2 as id2, 'foo2' AS val2", adapter: adapter)!
            
            XCTAssertEqual(row.count, 2)
            XCTAssertEqual(row["id"] as Int, 0)
            XCTAssertEqual(row["val"] as String, "foo0")
            
            XCTAssertEqual(Set(row.scopes.names), ["sub1"])
            XCTAssertEqual(row.scopes.count, 1)
            for (name, scopedRow) in row.scopes {
                if name == "sub1" {
                    XCTAssertEqual(scopedRow.unscoped, ["id": 1, "val": "foo1"])
                } else {
                    XCTFail()
                }
            }
            
            let scopedRow = row.scopes["sub1"]!
            XCTAssertEqual(scopedRow.unscoped, ["id": 1, "val": "foo1"])
            
            XCTAssertEqual(Set(scopedRow.scopes.names), ["sub2"])
            XCTAssertEqual(scopedRow.scopes.count, 1)
            for (name, subScopedRow) in scopedRow.scopes {
                if name == "sub2" {
                    XCTAssertEqual(subScopedRow, ["id": 2, "val": "foo2"])
                } else {
                    XCTFail()
                }
            }
            
            XCTAssertEqual(scopedRow.scopes["sub2"]!, ["id": 2, "val": "foo2"])
            XCTAssertTrue(scopedRow.scopes["sub2"]!.scopes.isEmpty)
            
            // sub2 is only defined in sub1
            XCTAssertTrue(row.scopes["sub2"] == nil)
            
            XCTAssertEqual(row.scopesTree.names, ["sub1", "sub2"])
            XCTAssertEqual(row.scopesTree["sub1"], row.scopes["sub1"])
            XCTAssertEqual(row.scopesTree["sub2"], row.scopes["sub1"]!.scopes["sub2"])
        }
    }

    func testSuffixAdapter() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let sql = "SELECT 0 AS a0, 1 AS a1, 2 AS a2, 3 AS a3"
            do {
                let row = try Row.fetchOne(db, sql: sql, adapter: SuffixRowAdapter(fromIndex:0))!
                XCTAssertEqual(Array(row.columnNames), ["a0", "a1", "a2", "a3"])
                XCTAssertEqual(Array(row.databaseValues), [0.databaseValue, 1.databaseValue, 2.databaseValue, 3.databaseValue])
            }
            do {
                let row = try Row.fetchOne(db, sql: sql, adapter: SuffixRowAdapter(fromIndex:1))!
                XCTAssertEqual(Array(row.columnNames), ["a1", "a2", "a3"])
                XCTAssertEqual(Array(row.databaseValues), [1.databaseValue, 2.databaseValue, 3.databaseValue])
            }
            do {
                let row = try Row.fetchOne(db, sql: sql, adapter: SuffixRowAdapter(fromIndex:3))!
                XCTAssertEqual(Array(row.columnNames), ["a3"])
                XCTAssertEqual(Array(row.databaseValues), [3.databaseValue])
            }
            do {
                let row = try Row.fetchOne(db, sql: sql, adapter: SuffixRowAdapter(fromIndex:4))!
                XCTAssertEqual(Array(row.columnNames), [])
                XCTAssertEqual(Array(row.databaseValues), [])
            }
        }
    }

    func testSuffixAdapterIndexesAreIndependentFromScopes() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let adapter = ScopeAdapter([
                "sub1": SuffixRowAdapter(fromIndex: 1)
                    .addingScopes([
                        "sub2": SuffixRowAdapter(fromIndex: 1)])])
            let row = try Row.fetchOne(db, sql: "SELECT 0 AS a0, 1 AS a1, 2 AS a2, 3 AS a3", adapter: adapter)!
            
            XCTAssertEqual(Set(row.scopes.names), ["sub1"])
            XCTAssertEqual(row.scopes.count, 1)
            for (name, scopedRow) in row.scopes {
                if name == "sub1" {
                    XCTAssertEqual(scopedRow.unscoped, ["a1": 1, "a2": 2, "a3": 3])
                } else {
                    XCTFail()
                }
            }
            
            let scopedRow = row.scopes["sub1"]!
            XCTAssertEqual(scopedRow.unscoped, ["a1": 1, "a2": 2, "a3": 3])
            
            XCTAssertEqual(Set(scopedRow.scopes.names), ["sub2"])
            XCTAssertEqual(scopedRow.scopes.count, 1)
            for (name, subScopedRow) in scopedRow.scopes {
                if name == "sub2" {
                    XCTAssertEqual(subScopedRow, ["a1": 1, "a2": 2, "a3": 3])
                } else {
                    XCTFail()
                }
            }
            
            let subScopedRow = scopedRow.scopes["sub2"]!
            XCTAssertEqual(subScopedRow, ["a1": 1, "a2": 2, "a3": 3])
            XCTAssertTrue(subScopedRow.scopes.isEmpty)
            
            // sub2 is only defined in sub1
            XCTAssertTrue(row.scopes["sub2"] == nil)
            
            XCTAssertEqual(row.scopesTree.names, ["sub1", "sub2"])
            XCTAssertEqual(row.scopesTree["sub1"], row.scopes["sub1"])
            XCTAssertEqual(row.scopesTree["sub2"], row.scopes["sub1"]!.scopes["sub2"])
        }
    }

    func testRangeAdapterWithCountableRange() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let sql = "SELECT 0 AS a0, 1 AS a1, 2 AS a2, 3 AS a3"
            do {
                let row = try Row.fetchOne(db, sql: sql, adapter: RangeRowAdapter(0..<0))!
                XCTAssertEqual(Array(row.columnNames), [])
                XCTAssertEqual(Array(row.databaseValues), [])
            }
            do {
                let row = try Row.fetchOne(db, sql: sql, adapter: RangeRowAdapter(0..<1))!
                XCTAssertEqual(Array(row.columnNames), ["a0"])
                XCTAssertEqual(Array(row.databaseValues), [0.databaseValue])
            }
            do {
                let row = try Row.fetchOne(db, sql: sql, adapter: RangeRowAdapter(1..<3))!
                XCTAssertEqual(Array(row.columnNames), ["a1", "a2"])
                XCTAssertEqual(Array(row.databaseValues), [1.databaseValue, 2.databaseValue])
            }
            do {
                let row = try Row.fetchOne(db, sql: sql, adapter: RangeRowAdapter(0..<4))!
                XCTAssertEqual(Array(row.columnNames), ["a0", "a1", "a2", "a3"])
                XCTAssertEqual(Array(row.databaseValues), [0.databaseValue, 1.databaseValue, 2.databaseValue, 3.databaseValue])
            }
            do {
                let row = try Row.fetchOne(db, sql: sql, adapter: RangeRowAdapter(4..<4))!
                XCTAssertEqual(Array(row.columnNames), [])
                XCTAssertEqual(Array(row.databaseValues), [])
            }
        }
    }

    func testRangeAdapterWithCountableClosedRange() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let sql = "SELECT 0 AS a0, 1 AS a1, 2 AS a2, 3 AS a3"
            do {
                let row = try Row.fetchOne(db, sql: sql, adapter: RangeRowAdapter(0...0))!
                XCTAssertEqual(Array(row.columnNames), ["a0"])
                XCTAssertEqual(Array(row.databaseValues), [0.databaseValue])
            }
            do {
                let row = try Row.fetchOne(db, sql: sql, adapter: RangeRowAdapter(0...1))!
                XCTAssertEqual(Array(row.columnNames), ["a0", "a1"])
                XCTAssertEqual(Array(row.databaseValues), [0.databaseValue, 1.databaseValue])
            }
            do {
                let row = try Row.fetchOne(db, sql: sql, adapter: RangeRowAdapter(1...2))!
                XCTAssertEqual(Array(row.columnNames), ["a1", "a2"])
                XCTAssertEqual(Array(row.databaseValues), [1.databaseValue, 2.databaseValue])
            }
            do {
                let row = try Row.fetchOne(db, sql: sql, adapter: RangeRowAdapter(0...3))!
                XCTAssertEqual(Array(row.columnNames), ["a0", "a1", "a2", "a3"])
                XCTAssertEqual(Array(row.databaseValues), [0.databaseValue, 1.databaseValue, 2.databaseValue, 3.databaseValue])
            }
            do {
                let row = try Row.fetchOne(db, sql: sql, adapter: RangeRowAdapter(3...3))!
                XCTAssertEqual(Array(row.columnNames), ["a3"])
                XCTAssertEqual(Array(row.databaseValues), [3.databaseValue])
            }
        }
    }

    func testRangeAdapterIndexesAreIndependentFromScopes() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let adapter = ScopeAdapter([
                "sub1": RangeRowAdapter(1..<3)
                    .addingScopes([
                        "sub2": RangeRowAdapter(1..<3)])])
            let row = try Row.fetchOne(db, sql: "SELECT 0 AS a0, 1 AS a1, 2 AS a2, 3 AS a3", adapter: adapter)!
            
            XCTAssertEqual(Set(row.scopes.names), ["sub1"])
            XCTAssertEqual(row.scopes.count, 1)
            for (name, scopedRow) in row.scopes {
                if name == "sub1" {
                    XCTAssertEqual(scopedRow.unscoped, ["a1": 1, "a2": 2])
                } else {
                    XCTFail()
                }
            }
            
            let scopedRow = row.scopes["sub1"]!
            XCTAssertEqual(scopedRow.unscoped, ["a1": 1, "a2": 2])
            
            XCTAssertEqual(Set(scopedRow.scopes.names), ["sub2"])
            XCTAssertEqual(scopedRow.scopes.count, 1)
            for (name, subScopedRow) in scopedRow.scopes {
                if name == "sub2" {
                    XCTAssertEqual(subScopedRow, ["a1": 1, "a2": 2])
                } else {
                    XCTFail()
                }
            }
            
            let subScopedRow = scopedRow.scopes["sub2"]!
            XCTAssertEqual(subScopedRow, ["a1": 1, "a2": 2])
            XCTAssertTrue(subScopedRow.scopes.isEmpty)
            
            // sub2 is only defined in sub1
            XCTAssertTrue(row.scopes["sub2"] == nil)
            
            XCTAssertEqual(row.scopesTree.names, ["sub1", "sub2"])
            XCTAssertEqual(row.scopesTree["sub1"], row.scopes["sub1"])
            XCTAssertEqual(row.scopesTree["sub2"], row.scopes["sub1"]!.scopes["sub2"])
        }
    }

    func testCopy() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let adapter = ColumnMapping(["a": "basea", "b": "baseb", "c": "basec"])
                .addingScopes(["sub": ColumnMapping(["a": "baseb"])])
            var copiedRow: Row? = nil
            let baseRows = try Row.fetchCursor(db, sql: "SELECT 0 AS basea, 'XXX' AS extra, 1 AS baseb, 2 as basec", adapter: adapter)
            while let baseRow = try baseRows.next() {
                copiedRow = baseRow.copy()
            }
            
            if let copiedRow = copiedRow {
                XCTAssertEqual(copiedRow.count, 3)
                XCTAssertEqual(copiedRow["a"] as Int, 0)
                XCTAssertEqual(copiedRow["b"] as Int, 1)
                XCTAssertEqual(copiedRow["c"] as Int, 2)
                
                XCTAssertEqual(Set(copiedRow.scopes.names), ["sub"])
                XCTAssertEqual(copiedRow.scopes.count, 1)
                for (name, scopedRow) in copiedRow.scopes {
                    if name == "sub" {
                        XCTAssertEqual(scopedRow, ["a": 1])
                    } else {
                        XCTFail()
                    }
                }
                
                XCTAssertEqual(Set(copiedRow.scopes.names), ["sub"])
                XCTAssertEqual(copiedRow.scopes["sub"]!, ["a": 1])
                XCTAssertTrue(copiedRow.scopes["sub"]!.scopes.isEmpty)
                XCTAssertEqual(copiedRow.scopesTree.names, ["sub"])
                XCTAssertEqual(copiedRow.scopesTree["sub"]!, ["a": 1])
            } else {
                XCTFail()
            }
        }
    }

    func testEqualityWithCopy() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let adapter = ColumnMapping(["a": "basea", "b": "baseb", "c": "basec"])
            var row: Row? = nil
            let baseRows = try Row.fetchCursor(db, sql: "SELECT 0 AS basea, 'XXX' AS extra, 1 AS baseb, 2 as basec", adapter: adapter)
            while let baseRow = try baseRows.next() {
                row = baseRow.copy()
                XCTAssertEqual(row, baseRow)
            }
            if let row = row {
                let copiedRow = row.copy()
                XCTAssertEqual(row, copiedRow)
            } else {
                XCTFail()
            }
        }
    }

    func testEqualityComparesScopes() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let adapter1 = ColumnMapping(["a": "basea", "b": "baseb", "c": "basec"])
                .addingScopes(["sub": ColumnMapping(["b": "baseb"])])
            let adapter2 = ColumnMapping(["a": "basea", "b": "baseb2", "c": "basec"])
            let adapter3 = ColumnMapping(["a": "basea", "b": "baseb2", "c": "basec"])
                .addingScopes(["sub": ColumnMapping(["b": "baseb2"])])
            let adapter4 = ColumnMapping(["a": "basea", "b": "baseb", "c": "basec"])
                .addingScopes(["sub": ColumnMapping(["b": "baseb"]), "altSub": ColumnMapping(["a": "baseb2"])])
            let adapter5 = ColumnMapping(["a": "basea", "b": "baseb", "c": "basec"])
                .addingScopes(["sub": ColumnMapping(["b": "baseb", "c": "basec"])])
            let row1 = try Row.fetchOne(db, sql: "SELECT 0 AS basea, 'XXX' AS extra, 1 AS baseb, 1 AS baseb2, 2 as basec", adapter: adapter1)!
            let row2 = try Row.fetchOne(db, sql: "SELECT 0 AS basea, 'XXX' AS extra, 1 AS baseb, 1 AS baseb2, 2 as basec", adapter: adapter2)!
            let row3 = try Row.fetchOne(db, sql: "SELECT 0 AS basea, 'XXX' AS extra, 1 AS baseb, 1 AS baseb2, 2 as basec", adapter: adapter3)!
            let row4 = try Row.fetchOne(db, sql: "SELECT 0 AS basea, 'XXX' AS extra, 1 AS baseb, 1 AS baseb2, 2 as basec", adapter: adapter4)!
            let row5 = try Row.fetchOne(db, sql: "SELECT 0 AS basea, 'XXX' AS extra, 1 AS baseb, 1 AS baseb2, 2 as basec", adapter: adapter5)!
            
            let tests = [
                (row1, row2, false),
                (row1, row3, true),
                (row1, row4, false),
                (row1, row5, false),
                (row1.scopes["sub"], row3.scopes["sub"], true),
                (row1.scopes["sub"], row4.scopes["sub"], true),
                (row1.scopes["sub"], row5.scopes["sub"], false)]
            for (lrow, rrow, equal) in tests {
                if equal {
                    XCTAssertEqual(lrow, rrow)
                } else {
                    XCTAssertNotEqual(lrow, rrow)
                }
            }
        }
    }

    func testEqualityWithNonMappedRow() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let adapter = ColumnMapping(["id": "baseid", "val": "baseval"])
            let mappedRow1 = try Row.fetchOne(db, sql: "SELECT 1 AS baseid, 'XXX' AS extra, 'foo' AS baseval", adapter: adapter)!
            let mappedRow2 = try Row.fetchOne(db, sql: "SELECT 'foo' AS baseval, 'XXX' AS extra, 1 AS baseid", adapter: adapter)!
            let nonMappedRow1 = try Row.fetchOne(db, sql: "SELECT 1 AS id, 'foo' AS val")!
            let nonMappedRow2 = try Row.fetchOne(db, sql: "SELECT 'foo' AS val, 1 AS id")!
            
            // All rows contain the same values. But they differ by column ordering.
            XCTAssertEqual(Array(mappedRow1.columnNames), ["id", "val"])
            XCTAssertEqual(Array(mappedRow2.columnNames), ["val", "id"])
            XCTAssertEqual(Array(nonMappedRow1.columnNames), ["id", "val"])
            XCTAssertEqual(Array(nonMappedRow2.columnNames), ["val", "id"])
            
            // Row equality takes ordering in account:
            XCTAssertNotEqual(mappedRow1, mappedRow2)
            XCTAssertEqual(mappedRow1, nonMappedRow1)
            XCTAssertNotEqual(mappedRow1, nonMappedRow2)
            XCTAssertNotEqual(mappedRow2, nonMappedRow1)
            XCTAssertEqual(mappedRow2, nonMappedRow2)
        }
    }

    func testEmptyMapping() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let adapter = ColumnMapping([:])
            let row = try Row.fetchOne(db, sql: "SELECT 'foo' AS foo", adapter: adapter)!
            
            XCTAssertTrue(row.isEmpty)
            XCTAssertEqual(row.count, 0)
            XCTAssertEqual(Array(row.columnNames), [])
            XCTAssertEqual(Array(row.databaseValues), [])
            XCTAssertFalse(row.hasColumn("foo"))
        }
    }

    func testRequestAdapter() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            do {
                let row = try SQLRequest<Row>(sql: "SELECT 0 AS a0, 1 AS a1, 2 AS a2", adapter: SuffixRowAdapter(fromIndex: 1))
                    .fetchOne(db)!
                XCTAssertEqual(Array(row.columnNames), ["a1", "a2"])
                XCTAssertEqual(Array(row.databaseValues), [1.databaseValue, 2.databaseValue])
            }
            do {
                let row = try SQLRequest<Row>(sql: "SELECT 0 AS a0, 1 AS a1, 2 AS a2")
                    .adapted { _ in SuffixRowAdapter(fromIndex: 1) }
                    .fetchOne(db)!
                XCTAssertEqual(Array(row.columnNames), ["a1", "a2"])
                XCTAssertEqual(Array(row.databaseValues), [1.databaseValue, 2.databaseValue])
            }
            do {
                let row = try SQLRequest<Row>(sql: "SELECT 0 AS a0, 1 AS a1, 2 AS a2", adapter: SuffixRowAdapter(fromIndex: 1))
                    .adapted { _ in SuffixRowAdapter(fromIndex: 1) }
                    .fetchOne(db)!
                XCTAssertEqual(Array(row.columnNames), ["a2"])
                XCTAssertEqual(Array(row.databaseValues), [2.databaseValue])
            }
            do {
                let row = try SQLRequest<Row>(sql: "SELECT 0 AS a0", adapter: ColumnMapping(["a1": "a0"]))
                    .adapted { _ in ColumnMapping(["a2": "a1"]) }
                    .fetchOne(db)!
                XCTAssertEqual(Array(row.columnNames), ["a2"])
                XCTAssertEqual(Array(row.databaseValues), [0.databaseValue])
            }
            do {
                let row = try SQLRequest<Row>(sql: "SELECT 0 AS a0", adapter: ColumnMapping(["a1": "a0"]))
                    .adapted { _ in ColumnMapping(["a2": "a1"]) }
                    .adapted { _ in ColumnMapping(["a3": "a2"]) }
                    .fetchOne(db)!
                XCTAssertEqual(Array(row.columnNames), ["a3"])
                XCTAssertEqual(Array(row.databaseValues), [0.databaseValue])
            }
        }
    }
    
    func testDescription() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let adapter = ColumnMapping(["id": "id0", "val": "val0"])
                .addingScopes([
                    "a": ColumnMapping(["id": "id1", "val": "val1"])
                        .addingScopes([
                            "b": ColumnMapping(["id": "id2", "val": "val2"])
                                .addingScopes([
                                    "c": SuffixRowAdapter(fromIndex:4)]),
                            "a": SuffixRowAdapter(fromIndex:0)]),
                    "b": ColumnMapping(["id": "id1", "val": "val1"])
                        .addingScopes([
                            "ba": ColumnMapping(["id": "id2", "val": "val2"])])])
            let row = try Row.fetchOne(db, sql: "SELECT 0 AS id0, 'foo0' AS val0, 1 AS id1, 'foo1' AS val1, 2 as id2, 'foo2' AS val2", adapter: adapter)!
            
            XCTAssertEqual(row.description, "[id:0 val:\"foo0\"]")
            XCTAssertEqual(row.debugDescription, """
                ▿ [id:0 val:"foo0"]
                  unadapted: [id0:0 val0:"foo0" id1:1 val1:"foo1" id2:2 val2:"foo2"]
                  - a: [id:1 val:"foo1"]
                    - a: [id0:0 val0:"foo0" id1:1 val1:"foo1" id2:2 val2:"foo2"]
                    - b: [id:2 val:"foo2"]
                      - c: [id2:2 val2:"foo2"]
                  - b: [id:1 val:"foo1"]
                    - ba: [id:2 val:"foo2"]
                """)
            XCTAssertEqual(row.scopes["a"]!.description, "[id:1 val:\"foo1\"]")
            XCTAssertEqual(row.scopes["a"]!.debugDescription, """
                ▿ [id:1 val:"foo1"]
                  unadapted: [id0:0 val0:"foo0" id1:1 val1:"foo1" id2:2 val2:"foo2"]
                  - a: [id0:0 val0:"foo0" id1:1 val1:"foo1" id2:2 val2:"foo2"]
                  - b: [id:2 val:"foo2"]
                    - c: [id2:2 val2:"foo2"]
                """)
        }
    }
}

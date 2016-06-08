import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class AdapterRowTests: GRDBTestCase {
    
    func testRowAsSequence() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                let adapter = ColumnMapping(["a": "basea", "b": "baseb", "c": "basec"])
                let row = Row.fetchOne(db, "SELECT 0 AS basea, 'XXX' AS extra, 1 AS baseb, 2 as basec", adapter: adapter)!
                
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
        }
    }
    
    func testRowValueAtIndex() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                let adapter = ColumnMapping(["a": "basea", "b": "baseb", "c": "basec"])
                let row = Row.fetchOne(db, "SELECT 0 AS basea, 'XXX' AS extra, 1 AS baseb, 2 as basec", adapter: adapter)!
                
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
        }
    }
    
    func testRowValueNamed() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                let adapter = ColumnMapping(["a": "basea", "b": "baseb", "c": "basec"])
                let row = Row.fetchOne(db, "SELECT 0 AS basea, 'XXX' AS extra, 1 AS baseb, 2 as basec", adapter: adapter)!
                
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
        }
    }
    
    func testRowDatabaseValueAtIndex() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                let adapter = ColumnMapping(["null": "basenull", "int64": "baseint64", "double": "basedouble", "string": "basestring", "blob": "baseblob"])
                let row = Row.fetchOne(db, "SELECT NULL AS basenull, 'XXX' AS extra, 1 AS baseint64, 1.1 AS basedouble, 'foo' AS basestring, x'53514C697465' AS baseblob", adapter: adapter)!
                
                guard case .Null = row.databaseValue(atIndex: 0).storage else { XCTFail(); return }
                guard case .Int64(let int64) = row.databaseValue(atIndex: 1).storage where int64 == 1 else { XCTFail(); return }
                guard case .Double(let double) = row.databaseValue(atIndex: 2).storage where double == 1.1 else { XCTFail(); return }
                guard case .String(let string) = row.databaseValue(atIndex: 3).storage where string == "foo" else { XCTFail(); return }
                guard case .Blob(let data) = row.databaseValue(atIndex: 4).storage where data == "SQLite".dataUsingEncoding(NSUTF8StringEncoding) else { XCTFail(); return }
            }
        }
    }
    
    func testRowDatabaseValueNamed() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                let adapter = ColumnMapping(["null": "basenull", "int64": "baseint64", "double": "basedouble", "string": "basestring", "blob": "baseblob"])
                let row = Row.fetchOne(db, "SELECT NULL AS basenull, 'XXX' AS extra, 1 AS baseint64, 1.1 AS basedouble, 'foo' AS basestring, x'53514C697465' AS baseblob", adapter: adapter)!
                
                guard case .Null = row.databaseValue(named: "null")!.storage else { XCTFail(); return }
                guard case .Int64(let int64) = row.databaseValue(named: "int64")!.storage where int64 == 1 else { XCTFail(); return }
                guard case .Double(let double) = row.databaseValue(named: "double")!.storage where double == 1.1 else { XCTFail(); return }
                guard case .String(let string) = row.databaseValue(named: "string")!.storage where string == "foo" else { XCTFail(); return }
                guard case .Blob(let data) = row.databaseValue(named: "blob")!.storage where data == "SQLite".dataUsingEncoding(NSUTF8StringEncoding) else { XCTFail(); return }
            }
        }
    }
    
    func testRowCount() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                let adapter = ColumnMapping(["a": "basea", "b": "baseb", "c": "basec"])
                let row = Row.fetchOne(db, "SELECT 0 AS basea, 'XXX' AS extra, 1 AS baseb, 2 as basec", adapter: adapter)!
                
                XCTAssertEqual(row.count, 3)
            }
        }
    }
    
    func testRowColumnNames() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                let adapter = ColumnMapping(["a": "basea", "b": "baseb", "c": "basec"])
                let row = Row.fetchOne(db, "SELECT 0 AS basea, 'XXX' AS extra, 1 AS baseb, 2 as basec", adapter: adapter)!
                
                XCTAssertEqual(Array(row.columnNames), ["a", "b", "c"])
            }
        }
    }
    
    func testRowDatabaseValues() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                let adapter = ColumnMapping(["a": "basea", "b": "baseb", "c": "basec"])
                let row = Row.fetchOne(db, "SELECT 0 AS basea, 'XXX' AS extra, 1 AS baseb, 2 as basec", adapter: adapter)!
                
                XCTAssertEqual(Array(row.databaseValues), [0.databaseValue, 1.databaseValue, 2.databaseValue])
            }
        }
    }
    
    func testRowIsCaseInsensitive() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                let adapter = ColumnMapping(["nAmE": "basenAmE"])
                let row = Row.fetchOne(db, "SELECT 'foo' AS basenAmE, 'XXX' AS extra", adapter: adapter)!
                
                XCTAssertEqual(row.databaseValue(named: "name"), "foo".databaseValue)
                XCTAssertEqual(row.databaseValue(named: "NAME"), "foo".databaseValue)
                XCTAssertEqual(row.databaseValue(named: "NaMe"), "foo".databaseValue)
                XCTAssertEqual(row.value(named: "name") as String, "foo")
                XCTAssertEqual(row.value(named: "NAME") as String, "foo")
                XCTAssertEqual(row.value(named: "NaMe") as String, "foo")
            }
        }
    }
    
    func testRowIsCaseInsensitiveAndReturnsLeftmostMatchingColumn() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                let adapter = ColumnMapping(["name": "basename", "NAME": "baseNAME"])
                let row = Row.fetchOne(db, "SELECT 1 AS basename, 'XXX' AS extra, 2 AS baseNAME", adapter: adapter)!

                XCTAssertEqual(row.databaseValue(named: "name"), 1.databaseValue)
                XCTAssertEqual(row.databaseValue(named: "NAME"), 1.databaseValue)
                XCTAssertEqual(row.databaseValue(named: "NaMe"), 1.databaseValue)
                XCTAssertEqual(row.value(named: "name") as Int, 1)
                XCTAssertEqual(row.value(named: "NAME") as Int, 1)
                XCTAssertEqual(row.value(named: "NaMe") as Int, 1)
            }
        }
    }
    
    func testRowAdapterIsCaseInsensitiveAndPicksLeftmostBaseColumn() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                let adapter = ColumnMapping(["name": "baseNaMe"])
                let row = Row.fetchOne(db, "SELECT 1 AS basename, 2 AS baseNaMe, 3 AS BASENAME", adapter: adapter)!
                
                XCTAssertEqual(row.databaseValue(named: "name"), 1.databaseValue)
            }
        }
    }
    
    func testMissingColumn() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                let adapter = ColumnMapping(["name": "name"])
                let row = Row.fetchOne(db, "SELECT 1 AS name, 'foo' AS missing", adapter: adapter)!
                
                XCTAssertFalse(row.hasColumn("missing"))
                XCTAssertFalse(row.hasColumn("missingInBaseRow"))
                XCTAssertTrue(row.databaseValue(named: "missing") == nil)
                XCTAssertTrue(row.databaseValue(named: "missingInBaseRow") == nil)
                XCTAssertTrue(row.value(named: "missing") == nil)
                XCTAssertTrue(row.value(named: "missingInBaseRow") == nil)
            }
        }
    }
    
    func testRowHasColumnIsCaseInsensitive() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                let adapter = ColumnMapping(["nAmE": "basenAmE", "foo": "basefoo"])
                let row = Row.fetchOne(db, "SELECT 'foo' AS basenAmE, 'XXX' AS extra, 1 AS basefoo", adapter: adapter)!

                XCTAssertTrue(row.hasColumn("name"))
                XCTAssertTrue(row.hasColumn("NAME"))
                XCTAssertTrue(row.hasColumn("Name"))
                XCTAssertTrue(row.hasColumn("NaMe"))
                XCTAssertTrue(row.hasColumn("foo"))
                XCTAssertTrue(row.hasColumn("Foo"))
                XCTAssertTrue(row.hasColumn("FOO"))
            }
        }
    }
    
    func testVariants() {
        let dbQueue = DatabaseQueue()
        dbQueue.inDatabase { db in
            let adapter = VariantRowAdapter(variants: [
                    "sub1": ColumnMapping(["id": "id1", "val": "val1"]),
                    "sub2": ColumnMapping(["id": "id2", "val": "val2"])])
            let row = Row.fetchOne(db, "SELECT 1 AS id1, 'foo1' AS val1, 2 as id2, 'foo2' AS val2", adapter: adapter)!
            
            XCTAssertEqual(row.count, 4)
            XCTAssertEqual(row.value(named: "id1") as Int, 1)
            XCTAssertEqual(row.value(named: "val1") as String, "foo1")
            XCTAssertEqual(row.value(named: "id2") as Int, 2)
            XCTAssertEqual(row.value(named: "val2") as String, "foo2")
            
            if let variant = row.variant(named: "sub1") {
                XCTAssertEqual(variant.count, 2)
                XCTAssertEqual(variant.value(named: "id") as Int, 1)
                XCTAssertEqual(variant.value(named: "val") as String, "foo1")
            } else {
                XCTFail()
            }
            
            if let variant = row.variant(named: "sub2") {
                XCTAssertEqual(variant.count, 2)
                XCTAssertEqual(variant.value(named: "id") as Int, 2)
                XCTAssertEqual(variant.value(named: "val") as String, "foo2")
            } else {
                XCTFail()
            }
            
            XCTAssertTrue(row.variant(named: "SUB1") == nil)     // case-insensitivity is not really required here, and case-sensitivity helps the implementation because it allows the use of a dictionary. So let's enforce this with a public test.
            XCTAssertTrue(row.variant(named: "missing") == nil)
        }
    }
    
    func testVariantsWithMainMapping() {
        let dbQueue = DatabaseQueue()
        dbQueue.inDatabase { db in
            let adapter = ColumnMapping(["id": "id0", "val": "val0"])
                .adapterWithVariants([
                    "sub1": ColumnMapping(["id": "id1", "val": "val1"]),
                    "sub2": ColumnMapping(["id": "id2", "val": "val2"])])
            let row = Row.fetchOne(db, "SELECT 0 AS id0, 'foo0' AS val0, 1 AS id1, 'foo1' AS val1, 2 as id2, 'foo2' AS val2", adapter: adapter)!

            XCTAssertEqual(row.count, 2)
            XCTAssertEqual(row.value(named: "id") as Int, 0)
            XCTAssertEqual(row.value(named: "val") as String, "foo0")

            if let variant = row.variant(named: "sub1") {
                XCTAssertEqual(variant.count, 2)
                XCTAssertEqual(variant.value(named: "id") as Int, 1)
                XCTAssertEqual(variant.value(named: "val") as String, "foo1")
            } else {
                XCTFail()
            }
            
            if let variant = row.variant(named: "sub2") {
                XCTAssertEqual(variant.count, 2)
                XCTAssertEqual(variant.value(named: "id") as Int, 2)
                XCTAssertEqual(variant.value(named: "val") as String, "foo2")
            } else {
                XCTFail()
            }
            
            XCTAssertTrue(row.variant(named: "SUB1") == nil)     // case-insensitivity is not really required here, and case-sensitivity helps the implementation because it allows the use of a dictionary. So let's enforce this with a public test.
            XCTAssertTrue(row.variant(named: "missing") == nil)
        }
    }
    
    func testMergeVariants() {
        let dbQueue = DatabaseQueue()
        dbQueue.inDatabase { db in
            let adapter0 = ColumnMapping(["id": "id0", "val": "val0"])
            let adapter1 = ColumnMapping(["id": "id1", "val": "val1"])
            let adapter2 = ColumnMapping(["id": "id2", "val": "val2"])
            
            let mainAdapter = VariantRowAdapter(variants: ["sub0": adapter0, "sub1": adapter2])
            let adapter = mainAdapter.adapterWithVariants(["sub1": adapter1, "sub2": adapter2])
            let row = Row.fetchOne(db, "SELECT 0 AS id0, 'foo0' AS val0, 1 AS id1, 'foo1' AS val1, 2 as id2, 'foo2' AS val2", adapter: adapter)!
            
            // sub0 is defined in the the first variant adapter
            if let variant = row.variant(named: "sub0") {
                XCTAssertEqual(variant.count, 2)
                XCTAssertEqual(variant.value(named: "id") as Int, 0)
                XCTAssertEqual(variant.value(named: "val") as String, "foo0")
            } else {
                XCTFail()
            }
            
            // sub1 is defined in the the first variant adapter, and then
            // redefined in the second
            if let variant = row.variant(named: "sub1") {
                XCTAssertEqual(variant.count, 2)
                XCTAssertEqual(variant.value(named: "id") as Int, 1)
                XCTAssertEqual(variant.value(named: "val") as String, "foo1")
            } else {
                XCTFail()
            }
            
            // sub2 is defined in the the second variant adapter
            if let variant = row.variant(named: "sub2") {
                XCTAssertEqual(variant.count, 2)
                XCTAssertEqual(variant.value(named: "id") as Int, 2)
                XCTAssertEqual(variant.value(named: "val") as String, "foo2")
            } else {
                XCTFail()
            }
        }
    }
    
    func testThreeLevelVariants() {
        let dbQueue = DatabaseQueue()
        dbQueue.inDatabase { db in
            let adapter = ColumnMapping(["id": "id0", "val": "val0"])
                .adapterWithVariants([
                    "sub1": ColumnMapping(["id": "id1", "val": "val1"])
                        .adapterWithVariants([
                            "sub2": ColumnMapping(["id": "id2", "val": "val2"])])])
            let row = Row.fetchOne(db, "SELECT 0 AS id0, 'foo0' AS val0, 1 AS id1, 'foo1' AS val1, 2 as id2, 'foo2' AS val2", adapter: adapter)!
            
            XCTAssertEqual(row.count, 2)
            XCTAssertEqual(row.value(named: "id") as Int, 0)
            XCTAssertEqual(row.value(named: "val") as String, "foo0")
            
            if let variant = row.variant(named: "sub1") {
                XCTAssertEqual(variant.count, 2)
                XCTAssertEqual(variant.value(named: "id") as Int, 1)
                XCTAssertEqual(variant.value(named: "val") as String, "foo1")
                
                if let variant = variant.variant(named: "sub2") {
                    XCTAssertEqual(variant.count, 2)
                    XCTAssertEqual(variant.value(named: "id") as Int, 2)
                    XCTAssertEqual(variant.value(named: "val") as String, "foo2")
                } else {
                    XCTFail()
                }
            } else {
                XCTFail()
            }
            
            // sub2 is only defined in sub1
            XCTAssertTrue(row.variant(named: "sub2") == nil)
        }
    }
    
    func testSuffixAdapter() {
        let dbQueue = DatabaseQueue()
        dbQueue.inDatabase { db in
            let adapter = VariantRowAdapter(
                variants: [
                    "sub1": SuffixRowAdapter(fromIndex: 2)
                        .adapterWithVariants([
                            "sub2": SuffixRowAdapter(fromIndex: 4)])])
            let row = Row.fetchOne(db, "SELECT 0 AS id, 'foo0' AS val, 1 AS id, 'foo1' AS val, 2 as id, 'foo2' AS val", adapter: adapter)!
            
            XCTAssertEqual(row.count, 6)
            XCTAssertEqual(row.value(named: "id") as Int, 0)
            XCTAssertEqual(row.value(named: "val") as String, "foo0")
            
            if let variant = row.variant(named: "sub1") {
                XCTAssertEqual(variant.count, 4)
                XCTAssertEqual(variant.value(named: "id") as Int, 1)
                XCTAssertEqual(variant.value(named: "val") as String, "foo1")
                
                if let variant = variant.variant(named: "sub2") {
                    XCTAssertEqual(variant.count, 2)
                    XCTAssertEqual(variant.value(named: "id") as Int, 2)
                    XCTAssertEqual(variant.value(named: "val") as String, "foo2")
                } else {
                    XCTFail()
                }
            } else {
                XCTFail()
            }
            
            // sub2 is only defined in sub1
            XCTAssertTrue(row.variant(named: "sub2") == nil)
        }
    }
    
    func testCopy() {
        let dbQueue = DatabaseQueue()
        dbQueue.inDatabase { db in
            let adapter = ColumnMapping(["a": "basea", "b": "baseb", "c": "basec"])
                .adapterWithVariants(["sub": ColumnMapping(["a": "baseb"])])
            var copiedRow: Row? = nil
            for baseRow in Row.fetch(db, "SELECT 0 AS basea, 'XXX' AS extra, 1 AS baseb, 2 as basec", adapter: adapter) {
                copiedRow = baseRow.copy()
            }
            
            if let copiedRow = copiedRow {
                XCTAssertEqual(copiedRow.count, 3)
                XCTAssertEqual(copiedRow.value(named: "a") as Int, 0)
                XCTAssertEqual(copiedRow.value(named: "b") as Int, 1)
                XCTAssertEqual(copiedRow.value(named: "c") as Int, 2)
                if let variant = copiedRow.variant(named: "sub") {
                    XCTAssertEqual(variant.count, 1)
                    XCTAssertEqual(variant.value(named: "a") as Int, 1)
                }
            } else {
                XCTFail()
            }
        }
    }
    
    func testEqualityWithCopy() {
        let dbQueue = DatabaseQueue()
        dbQueue.inDatabase { db in
            let adapter = ColumnMapping(["a": "basea", "b": "baseb", "c": "basec"])
            var row: Row? = nil
            for baseRow in Row.fetch(db, "SELECT 0 AS basea, 'XXX' AS extra, 1 AS baseb, 2 as basec", adapter: adapter) {
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
    
    func testEqualityComparesVariants() {
        let dbQueue = DatabaseQueue()
        dbQueue.inDatabase { db in
            let adapter1 = ColumnMapping(["a": "basea", "b": "baseb", "c": "basec"])
                .adapterWithVariants(["sub": ColumnMapping(["b": "baseb"])])
            let adapter2 = ColumnMapping(["a": "basea", "b": "baseb2", "c": "basec"])
            let adapter3 = ColumnMapping(["a": "basea", "b": "baseb2", "c": "basec"])
                .adapterWithVariants(["sub": ColumnMapping(["b": "baseb2"])])
            let adapter4 = ColumnMapping(["a": "basea", "b": "baseb", "c": "basec"])
                .adapterWithVariants(["sub": ColumnMapping(["b": "baseb"]), "altSub": ColumnMapping(["a": "baseb2"])])
            let adapter5 = ColumnMapping(["a": "basea", "b": "baseb", "c": "basec"])
                .adapterWithVariants(["sub": ColumnMapping(["b": "baseb", "c": "basec"])])
            let row1 = Row.fetchOne(db, "SELECT 0 AS basea, 'XXX' AS extra, 1 AS baseb, 1 AS baseb2, 2 as basec", adapter: adapter1)!
            let row2 = Row.fetchOne(db, "SELECT 0 AS basea, 'XXX' AS extra, 1 AS baseb, 1 AS baseb2, 2 as basec", adapter: adapter2)!
            let row3 = Row.fetchOne(db, "SELECT 0 AS basea, 'XXX' AS extra, 1 AS baseb, 1 AS baseb2, 2 as basec", adapter: adapter3)!
            let row4 = Row.fetchOne(db, "SELECT 0 AS basea, 'XXX' AS extra, 1 AS baseb, 1 AS baseb2, 2 as basec", adapter: adapter4)!
            let row5 = Row.fetchOne(db, "SELECT 0 AS basea, 'XXX' AS extra, 1 AS baseb, 1 AS baseb2, 2 as basec", adapter: adapter5)!
            
            let tests = [
                (row1, row2, false),
                (row1, row3, true),
                (row1, row4, false),
                (row1, row5, false),
                (row1.variant(named: "sub"), row3.variant(named: "sub"), true),
                (row1.variant(named: "sub"), row4.variant(named: "sub"), true),
                (row1.variant(named: "sub"), row5.variant(named: "sub"), false)]
            for (lrow, rrow, equal) in tests {
                print(lrow)
                print(rrow)
                print(lrow == rrow)
                if equal {
                    XCTAssertEqual(lrow, rrow)
                } else {
                    XCTAssertNotEqual(lrow, rrow)
                }
            }
        }
    }
    
    func testEqualityWithNonMappedRow() {
        let dbQueue = DatabaseQueue()
        dbQueue.inDatabase { db in
            let adapter = ColumnMapping(["id": "baseid", "val": "baseval"])
            let mappedRow1 = Row.fetchOne(db, "SELECT 1 AS baseid, 'XXX' AS extra, 'foo' AS baseval", adapter: adapter)!
            let mappedRow2 = Row.fetchOne(db, "SELECT 'foo' AS baseval, 'XXX' AS extra, 1 AS baseid", adapter: adapter)!
            let nonMappedRow1 = Row.fetchOne(db, "SELECT 1 AS id, 'foo' AS val")!
            let nonMappedRow2 = Row.fetchOne(db, "SELECT 'foo' AS val, 1 AS id")!
            
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
    
    func testEmptyMapping() {
        let dbQueue = DatabaseQueue()
        dbQueue.inDatabase { db in
            let adapter = ColumnMapping([:])
            let row = Row.fetchOne(db, "SELECT 'foo' AS foo", adapter: adapter)!
            
            XCTAssertTrue(row.isEmpty)
            XCTAssertEqual(row.count, 0)
            XCTAssertEqual(Array(row.columnNames), [])
            XCTAssertEqual(Array(row.databaseValues), [])
            XCTAssertFalse(row.hasColumn("foo"))
        }
    }
}

import XCTest
import GRDB

class MappedRowTests: GRDBTestCase {
    
    func testRowAdapter() {
        let dbQueue = DatabaseQueue()
        dbQueue.inDatabase { db in
            let adapter = RowAdapter(
                mapping: ["id": "fooid", "val": "FOOVAL"],   // case insensitivity of base column names
                subrowMappings: [
                    "foo": ["id": "barid", "val": "barval"]])
            let row = Row.fetchOne(db, "SELECT 1 AS fooid, 'foo' AS fooval, 2 as barid, 'bar' AS barval", adapter: adapter)!
            
            
            // # Row equality
            
            XCTAssertEqual(row, Row.fetchOne(db, "SELECT 1 AS id, 'foo' AS val")!)
            XCTAssertNotEqual(row, Row.fetchOne(db, "SELECT 'foo' AS val, 1 AS id")!)
            
            
            // # Subrows
            
            let row2 = row.subrow(named: "foo")!
            XCTAssertEqual(row2.count, 2)
            XCTAssertEqual(row2.value(named: "id") as Int, 2)
            XCTAssertEqual(row2.value(named: "val") as String, "bar")
            
            
            // # TODO: test row.copy
        }
    }

    func testRowAsSequence() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                let adapter = RowAdapter(mapping: ["a": "basea", "b": "baseb", "c": "basec"])
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
                let adapter = RowAdapter(mapping: ["a": "basea", "b": "baseb", "c": "basec"])
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
                let adapter = RowAdapter(mapping: ["a": "basea", "b": "baseb", "c": "basec"])
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
                let adapter = RowAdapter(mapping: ["null": "basenull", "int64": "baseint64", "double": "basedouble", "string": "basestring", "blob": "baseblob"])
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
                let adapter = RowAdapter(mapping: ["null": "basenull", "int64": "baseint64", "double": "basedouble", "string": "basestring", "blob": "baseblob"])
                let row = Row.fetchOne(db, "SELECT NULL AS basenull, 'XXX' AS extra, 1 AS baseint64, 1.1 AS basedouble, 'foo' AS basestring, x'53514C697465' AS baseblob", adapter: adapter)!
                
                guard case .Null = row.databaseValue(named: "null").storage else { XCTFail(); return }
                guard case .Int64(let int64) = row.databaseValue(named: "int64").storage where int64 == 1 else { XCTFail(); return }
                guard case .Double(let double) = row.databaseValue(named: "double").storage where double == 1.1 else { XCTFail(); return }
                guard case .String(let string) = row.databaseValue(named: "string").storage where string == "foo" else { XCTFail(); return }
                guard case .Blob(let data) = row.databaseValue(named: "blob").storage where data == "SQLite".dataUsingEncoding(NSUTF8StringEncoding) else { XCTFail(); return }
            }
        }
    }
    
    func testRowCount() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                let adapter = RowAdapter(mapping: ["a": "basea", "b": "baseb", "c": "basec"])
                let row = Row.fetchOne(db, "SELECT 0 AS basea, 'XXX' AS extra, 1 AS baseb, 2 as basec", adapter: adapter)!
                
                XCTAssertEqual(row.count, 3)
            }
        }
    }
    
    func testRowColumnNames() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                let adapter = RowAdapter(mapping: ["a": "basea", "b": "baseb", "c": "basec"])
                let row = Row.fetchOne(db, "SELECT 0 AS basea, 'XXX' AS extra, 1 AS baseb, 2 as basec", adapter: adapter)!
                
                XCTAssertEqual(Array(row.columnNames), ["a", "b", "c"])
            }
        }
    }
    
    func testRowDatabaseValues() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                let adapter = RowAdapter(mapping: ["a": "basea", "b": "baseb", "c": "basec"])
                let row = Row.fetchOne(db, "SELECT 0 AS basea, 'XXX' AS extra, 1 AS baseb, 2 as basec", adapter: adapter)!
                
                XCTAssertEqual(Array(row.databaseValues), [0.databaseValue, 1.databaseValue, 2.databaseValue])
            }
        }
    }
    
    func testRowIsCaseInsensitive() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                let adapter = RowAdapter(mapping: ["nAmE": "basenAmE"])
                let row = Row.fetchOne(db, "SELECT 'foo' AS basenAmE, 'XXX' AS extra", adapter: adapter)!
                
                XCTAssertEqual(row["name"], "foo".databaseValue)
                XCTAssertEqual(row["NAME"], "foo".databaseValue)
                XCTAssertEqual(row["NaMe"], "foo".databaseValue)
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
                let adapter = RowAdapter(mapping: ["name": "basename", "NAME": "baseNAME"])
                let row = Row.fetchOne(db, "SELECT 1 AS basename, 'XXX' AS extra, 2 AS baseNAME", adapter: adapter)!

                XCTAssertEqual(row["name"], 1.databaseValue)
                XCTAssertEqual(row["NAME"], 1.databaseValue)
                XCTAssertEqual(row["NaMe"], 1.databaseValue)
                XCTAssertEqual(row.value(named: "name") as Int, 1)
                XCTAssertEqual(row.value(named: "NAME") as Int, 1)
                XCTAssertEqual(row.value(named: "NaMe") as Int, 1)
            }
        }
    }
    
    func testMissingColumn() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                let adapter = RowAdapter(mapping: ["name": "name"])
                let row = Row.fetchOne(db, "SELECT 1 AS name, 'foo' AS missing", adapter: adapter)!
                
                XCTAssertFalse(row.hasColumn("missing"))
                XCTAssertFalse(row.hasColumn("missingInBaseRow"))
                XCTAssertTrue(row["missing"] == nil)
                XCTAssertTrue(row["missingInBaseRow"] == nil)
                XCTAssertTrue(row.value(named: "missing") == nil)
                XCTAssertTrue(row.value(named: "missingInBaseRow") == nil)
            }
        }
    }
    
    func testRowHasColumnIsCaseInsensitive() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                let adapter = RowAdapter(mapping: ["nAmE": "basenAmE", "foo": "basefoo"])
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
}

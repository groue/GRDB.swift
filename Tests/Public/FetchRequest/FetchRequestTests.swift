import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private struct CustomFetchRequest : FetchRequest {
    func selectStatement(_ db: Database) throws -> SelectStatement {
        return try db.makeSelectStatement("SELECT 1 AS 'produced'")
    }
    
    func adapter(_ statement: SelectStatement) throws -> RowAdapter? {
        return RowAdapter(mapping: ["consumed": "produced"])
    }
}

private struct CustomRecord: RowConvertible {
    let consumed: Int
    init(row: Row) {
        consumed = row.value(named: "consumed")
    }
}

class FetchRequestTests: GRDBTestCase {
    
    func testDatabaseValueConvertibleFetch() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                var fetchedInt: Int? = nil
                for i in Int.fetch(db, CustomFetchRequest()) {
                    fetchedInt = i
                }
                XCTAssertEqual(fetchedInt!, 1)
            }
        }
    }
    
    func testDatabaseValueConvertibleFetchAll() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                let fetchedInts = Int.fetchAll(db, CustomFetchRequest())
                XCTAssertEqual(fetchedInts, [1])
            }
        }
    }
    
    func testDatabaseValueConvertibleFetchOne() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                let fetchedInt = Int.fetchOne(db, CustomFetchRequest())!
                XCTAssertEqual(fetchedInt, 1)
            }
        }
    }

    func testRowFetch() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                var fetched = false
                for row in Row.fetch(db, CustomFetchRequest()) {
                    fetched = true
                    XCTAssertEqual(Array(row.columnNames), ["consumed"])
                    XCTAssertEqual(Array(row.databaseValues), [1.databaseValue])
                }
                XCTAssertTrue(fetched)
            }
        }
    }

    func testRowFetchAll() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                let rows = Row.fetchAll(db, CustomFetchRequest())
                XCTAssertEqual(rows.count, 1)
                XCTAssertEqual(Array(rows[0].columnNames), ["consumed"])
                XCTAssertEqual(Array(rows[0].databaseValues), [1.databaseValue])
            }
        }
    }
    
    func testRowFetchOne() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                let row = Row.fetchOne(db, CustomFetchRequest())!
                XCTAssertEqual(Array(row.columnNames), ["consumed"])
                XCTAssertEqual(Array(row.databaseValues), [1.databaseValue])
            }
        }
    }
    
    func testRowConvertibleFetch() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                var fetched = false
                for record in CustomRecord.fetch(db, CustomFetchRequest()) {
                    fetched = true
                    XCTAssertEqual(record.consumed, 1)
                }
                XCTAssertTrue(fetched)
            }
        }
    }
    
    func testRowConvertibleFetchAll() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                let records = CustomRecord.fetchAll(db, CustomFetchRequest())
                XCTAssertEqual(records.count, 1)
                XCTAssertEqual(records[0].consumed, 1)
            }
        }
    }
    
    func testRowConvertibleFetchOne() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                let record = CustomRecord.fetchOne(db, CustomFetchRequest())!
                XCTAssertEqual(record.consumed, 1)
            }
        }
    }
    
}

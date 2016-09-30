import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private struct CustomFetchRequest : FetchRequest {
    func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
        return try (db.makeSelectStatement("SELECT 1 AS 'produced'"), ColumnMapping(["consumed": "produced"]))
    }
}

private struct CustomRecord: RowConvertible {
    let consumed: Int
    init(row: Row) {
        consumed = row.value(named: "consumed")
    }
}

private struct CustomStruct: DatabaseValueConvertible {
    // CustomStruct that *only* conforms to DatabaseValueConvertible, *NOT* StatementColumnConvertible
    fileprivate let number: Int64
    
    /// Returns a value that can be stored in the database.
    var databaseValue: DatabaseValue {
        return number.databaseValue
    }
    
    /// Returns a String initialized from *databaseValue*, if possible.
    static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> CustomStruct? {
        guard let number = Int64.fromDatabaseValue(databaseValue) else {
            return nil
        }
        return CustomStruct(number: number)
    }
}
extension CustomStruct: Equatable {
    static func ==(lhs: CustomStruct, rhs: CustomStruct) -> Bool {
        return lhs.number == rhs.number
    }
}

class FetchRequestTests: GRDBTestCase {
    
    func testDatabaseValueConvertibleFetch() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                var fetchedValue: CustomStruct? = nil
                for i in CustomStruct.fetch(db, CustomFetchRequest()) {
                    fetchedValue = i
                }
                XCTAssertEqual(fetchedValue!, CustomStruct(number: 1))
            }
        }
    }
    
    func testDatabaseValueConvertibleFetchAll() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                let fetchedValues = CustomStruct.fetchAll(db, CustomFetchRequest())
                XCTAssertEqual(fetchedValues, [CustomStruct(number: 1)])
            }
        }
    }
    
    func testDatabaseValueConvertibleFetchOne() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                let fetchedValue = CustomStruct.fetchOne(db, CustomFetchRequest())!
                XCTAssertEqual(fetchedValue, CustomStruct(number: 1))
            }
        }
    }
    
    func testDatabaseValueConvertibleOptionalFetch() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                var fetchedValue: CustomStruct? = nil
                for i in Optional<CustomStruct>.fetch(db, CustomFetchRequest()) {
                    fetchedValue = i
                }
                XCTAssertEqual(fetchedValue!, CustomStruct(number: 1))
            }
        }
    }
    
    func testDatabaseValueConvertibleOptionalFetchAll() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                let fetchedValues = Optional<CustomStruct>.fetchAll(db, CustomFetchRequest())
                let expectedValue: CustomStruct? = CustomStruct(number: 1)
                XCTAssertEqual(fetchedValues.count, 1)
                XCTAssertEqual(fetchedValues[0], expectedValue)
            }
        }
    }
    
    func testDatabaseValueConvertibleFetchWhereStatementColumnConvertible() {
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
    
    func testDatabaseValueConvertibleFetchAllWhereStatementColumnConvertible() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                let fetchedInts = Int.fetchAll(db, CustomFetchRequest())
                XCTAssertEqual(fetchedInts, [1])
            }
        }
    }
    
    func testDatabaseValueConvertibleFetchOneWhereStatementColumnConvertible() {
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

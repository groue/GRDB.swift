import XCTest
#if SQLITE_HAS_CODEC
    import GRDBCipher
#else
    import GRDB
#endif

func insertItem(db: Database, name: String) throws {
    try db.execute("INSERT INTO items (name) VALUES (?)", arguments: [name])
}

func fetchAllItemNames(dbReader: DatabaseReader) -> [String] {
    return dbReader.read { db in
        String.fetchAll(db, "SELECT * FROM items ORDER BY name")
    }
}

private class TransactionObserver : TransactionObserverType {
    var allRecordedEvents: [DatabaseEvent] = []
    
    func reset() {
        allRecordedEvents.removeAll()
    }
    
    func databaseDidChangeWithEvent(event: DatabaseEvent) {
        allRecordedEvents.append(event.copy())
    }
    
    func databaseWillCommit() throws {
    }
    
    func databaseDidCommit(db: Database) {
    }
    
    func databaseDidRollback(db: Database) {
    }
}

class SavepointTests: GRDBTestCase {
    
    override func setUpDatabase(dbWriter: DatabaseWriter) throws {
        try dbWriter.write { db in
            try db.execute("CREATE TABLE items (name TEXT)")
        }
    }

    func testReleaseTopLevelSavepointFromDatabaseWithDefaultDeferredTransactions() {
        assertNoError {
            dbConfiguration.defaultTransactionKind = .Deferred
            let dbQueue = try makeDatabaseQueue()
            let observer = TransactionObserver()
            dbQueue.addTransactionObserver(observer)
            sqlQueries.removeAll()
            try dbQueue.inDatabase { db in
                try insertItem(db, name: "item1")
                try db.inSavepoint(named: "foo") {
                    XCTAssertTrue(db.isInsideTransaction)
                    try insertItem(db, name: "item2")
                    return .Commit
                }
                XCTAssertFalse(db.isInsideTransaction)
                try insertItem(db, name: "item3")
            }
            
            XCTAssertEqual(sqlQueries, [
                "INSERT INTO items (name) VALUES ('item1')",
                "SAVEPOINT foo",
                "INSERT INTO items (name) VALUES ('item2')",
                "RELEASE SAVEPOINT foo",
                "INSERT INTO items (name) VALUES ('item3')"
                ])
            XCTAssertEqual(fetchAllItemNames(dbQueue), ["item1", "item2", "item3"])
            XCTAssertEqual(observer.allRecordedEvents.count, 3)
        }
    }
    
    func testRollbackTopLevelSavepointFromDatabaseWithDefaultDeferredTransactions() {
        assertNoError {
            dbConfiguration.defaultTransactionKind = .Deferred
            let dbQueue = try makeDatabaseQueue()
            let observer = TransactionObserver()
            dbQueue.addTransactionObserver(observer)
            sqlQueries.removeAll()
            try dbQueue.inDatabase { db in
                try insertItem(db, name: "item1")
                try db.inSavepoint(named: "foo") {
                    XCTAssertTrue(db.isInsideTransaction)
                    try insertItem(db, name: "item2")
                    return .Rollback
                }
                XCTAssertFalse(db.isInsideTransaction)
                try insertItem(db, name: "item3")
            }
            XCTAssertEqual(sqlQueries, [
                "INSERT INTO items (name) VALUES ('item1')",
                "SAVEPOINT foo",
                "INSERT INTO items (name) VALUES ('item2')",
                "ROLLBACK TRANSACTION",
                "INSERT INTO items (name) VALUES ('item3')"
                ])
            XCTAssertEqual(fetchAllItemNames(dbQueue), ["item1", "item3"])
            XCTAssertEqual(observer.allRecordedEvents.count, 2)
        }
    }
    
    func testNestedSavepointFromDatabaseWithDefaultDeferredTransactions() {
        assertNoError {
            dbConfiguration.defaultTransactionKind = .Deferred
            let dbQueue = try makeDatabaseQueue()
            let observer = TransactionObserver()
            dbQueue.addTransactionObserver(observer)
            sqlQueries.removeAll()
            try dbQueue.inDatabase { db in
                try insertItem(db, name: "item1")
                try db.inSavepoint(named: "foo") {
                    XCTAssertTrue(db.isInsideTransaction)
                    try insertItem(db, name: "item2")
                    try db.inSavepoint(named: "foo") {
                        XCTAssertTrue(db.isInsideTransaction)
                        try insertItem(db, name: "item3")
                        return .Commit
                    }
                    XCTAssertTrue(db.isInsideTransaction)
                    try insertItem(db, name: "item4")
                    return .Commit
                }
                XCTAssertFalse(db.isInsideTransaction)
                try insertItem(db, name: "item5")
            }
            XCTAssertEqual(sqlQueries, [
                "INSERT INTO items (name) VALUES ('item1')",
                "SAVEPOINT foo",
                "INSERT INTO items (name) VALUES ('item2')",
                "SAVEPOINT foo",
                "INSERT INTO items (name) VALUES ('item3')",
                "RELEASE SAVEPOINT foo",
                "INSERT INTO items (name) VALUES ('item4')",
                "RELEASE SAVEPOINT foo",
                "INSERT INTO items (name) VALUES ('item5')"
                ])
            XCTAssertEqual(fetchAllItemNames(dbQueue), ["item1", "item2", "item3", "item4", "item5"])
            XCTAssertEqual(observer.allRecordedEvents.count, 5)
            try! dbQueue.inDatabase { db in try db.execute("DELETE FROM items") }
            observer.reset()

            sqlQueries.removeAll()
            try dbQueue.inDatabase { db in
                try insertItem(db, name: "item1")
                try db.inSavepoint(named: "foo") {
                    XCTAssertTrue(db.isInsideTransaction)
                    try insertItem(db, name: "item2")
                    try db.inSavepoint(named: "foo") {
                        XCTAssertTrue(db.isInsideTransaction)
                        try insertItem(db, name: "item3")
                        return .Commit
                    }
                    XCTAssertTrue(db.isInsideTransaction)
                    try insertItem(db, name: "item4")
                    return .Rollback
                }
                XCTAssertFalse(db.isInsideTransaction)
                try insertItem(db, name: "item5")
            }
            XCTAssertEqual(sqlQueries, [
                "INSERT INTO items (name) VALUES ('item1')",
                "SAVEPOINT foo",
                "INSERT INTO items (name) VALUES ('item2')",
                "SAVEPOINT foo",
                "INSERT INTO items (name) VALUES ('item3')",
                "RELEASE SAVEPOINT foo",
                "INSERT INTO items (name) VALUES ('item4')",
                "ROLLBACK TRANSACTION",
                "INSERT INTO items (name) VALUES ('item5')"
                ])
            XCTAssertEqual(fetchAllItemNames(dbQueue), ["item1", "item5"])
            XCTAssertEqual(observer.allRecordedEvents.count, 2)
            try! dbQueue.inDatabase { db in try db.execute("DELETE FROM items") }
            observer.reset()
            
            sqlQueries.removeAll()
            try dbQueue.inDatabase { db in
                try insertItem(db, name: "item1")
                try db.inSavepoint(named: "foo") {
                    XCTAssertTrue(db.isInsideTransaction)
                    try insertItem(db, name: "item2")
                    try db.inSavepoint(named: "foo") {
                        XCTAssertTrue(db.isInsideTransaction)
                        try insertItem(db, name: "item3")
                        return .Rollback
                    }
                    XCTAssertTrue(db.isInsideTransaction)
                    try insertItem(db, name: "item4")
                    return .Commit
                }
                XCTAssertFalse(db.isInsideTransaction)
                try insertItem(db, name: "item5")
            }
            XCTAssertEqual(sqlQueries, [
                "INSERT INTO items (name) VALUES ('item1')",
                "SAVEPOINT foo",
                "INSERT INTO items (name) VALUES ('item2')",
                "SAVEPOINT foo",
                "INSERT INTO items (name) VALUES ('item3')",
                "ROLLBACK TRANSACTION TO SAVEPOINT foo",
                "RELEASE SAVEPOINT foo",
                "INSERT INTO items (name) VALUES ('item4')",
                "RELEASE SAVEPOINT foo",
                "INSERT INTO items (name) VALUES ('item5')"
                ])
            XCTAssertEqual(fetchAllItemNames(dbQueue), ["item1", "item2", "item4", "item5"])
            XCTAssertEqual(observer.allRecordedEvents.count, 4)
            try! dbQueue.inDatabase { db in try db.execute("DELETE FROM items") }
            observer.reset()
            
            sqlQueries.removeAll()
            try dbQueue.inDatabase { db in
                try insertItem(db, name: "item1")
                try db.inSavepoint(named: "foo") {
                    XCTAssertTrue(db.isInsideTransaction)
                    try insertItem(db, name: "item2")
                    try db.inSavepoint(named: "foo") {
                        XCTAssertTrue(db.isInsideTransaction)
                        try insertItem(db, name: "item3")
                        return .Rollback
                    }
                    XCTAssertTrue(db.isInsideTransaction)
                    try insertItem(db, name: "item4")
                    return .Rollback
                }
                XCTAssertFalse(db.isInsideTransaction)
                try insertItem(db, name: "item5")
            }
            XCTAssertEqual(sqlQueries, [
                "INSERT INTO items (name) VALUES ('item1')",
                "SAVEPOINT foo",
                "INSERT INTO items (name) VALUES ('item2')",
                "SAVEPOINT foo",
                "INSERT INTO items (name) VALUES ('item3')",
                "ROLLBACK TRANSACTION TO SAVEPOINT foo",
                "RELEASE SAVEPOINT foo",
                "INSERT INTO items (name) VALUES ('item4')",
                "ROLLBACK TRANSACTION",
                "INSERT INTO items (name) VALUES ('item5')"
                ])
            XCTAssertEqual(fetchAllItemNames(dbQueue), ["item1", "item5"])
            XCTAssertEqual(observer.allRecordedEvents.count, 2)
            try! dbQueue.inDatabase { db in try db.execute("DELETE FROM items") }
            observer.reset()
        }
    }
    
    func testReleaseTopLevelSavepointFromDatabaseWithDefaultImmediateTransactions() {
        assertNoError {
            dbConfiguration.defaultTransactionKind = .Immediate
            let dbQueue = try makeDatabaseQueue()
            let observer = TransactionObserver()
            dbQueue.addTransactionObserver(observer)
            sqlQueries.removeAll()
            try dbQueue.inDatabase { db in
                try insertItem(db, name: "item1")
                try db.inSavepoint(named: "foo") {
                    XCTAssertTrue(db.isInsideTransaction)
                    try insertItem(db, name: "item2")
                    return .Commit
                }
                XCTAssertFalse(db.isInsideTransaction)
                try insertItem(db, name: "item3")
            }
            XCTAssertEqual(sqlQueries, [
                "INSERT INTO items (name) VALUES ('item1')",
                "BEGIN IMMEDIATE TRANSACTION",
                "SAVEPOINT foo",
                "INSERT INTO items (name) VALUES ('item2')",
                "RELEASE SAVEPOINT foo",
                "COMMIT TRANSACTION",
                "INSERT INTO items (name) VALUES ('item3')"
                ])
            XCTAssertEqual(fetchAllItemNames(dbQueue), ["item1", "item2", "item3"])
            XCTAssertEqual(observer.allRecordedEvents.count, 3)
        }
    }
    
    func testRollbackTopLevelSavepointFromDatabaseWithDefaultImmediateTransactions() {
        assertNoError {
            dbConfiguration.defaultTransactionKind = .Immediate
            let dbQueue = try makeDatabaseQueue()
            let observer = TransactionObserver()
            dbQueue.addTransactionObserver(observer)
            sqlQueries.removeAll()
            try dbQueue.inDatabase { db in
                try insertItem(db, name: "item1")
                try db.inSavepoint(named: "foo") {
                    XCTAssertTrue(db.isInsideTransaction)
                    try insertItem(db, name: "item2")
                    return .Rollback
                }
                XCTAssertFalse(db.isInsideTransaction)
                try insertItem(db, name: "item3")
            }
            XCTAssertEqual(sqlQueries, [
                "INSERT INTO items (name) VALUES ('item1')",
                "BEGIN IMMEDIATE TRANSACTION",
                "SAVEPOINT foo",
                "INSERT INTO items (name) VALUES ('item2')",
                "ROLLBACK TRANSACTION TO SAVEPOINT foo",
                "RELEASE SAVEPOINT foo",
                "COMMIT TRANSACTION",
                "INSERT INTO items (name) VALUES ('item3')"
                ])
            XCTAssertEqual(fetchAllItemNames(dbQueue), ["item1", "item3"])
            XCTAssertEqual(observer.allRecordedEvents.count, 2)
        }
    }
    
    func testNestedSavepointFromDatabaseWithDefaultImmediateTransactions() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let observer = TransactionObserver()
            dbQueue.addTransactionObserver(observer)
            sqlQueries.removeAll()
            try dbQueue.inDatabase { db in
                try insertItem(db, name: "item1")
                try db.inSavepoint(named: "foo") {
                    XCTAssertTrue(db.isInsideTransaction)
                    try insertItem(db, name: "item2")
                    try db.inSavepoint(named: "foo") {
                        XCTAssertTrue(db.isInsideTransaction)
                        try insertItem(db, name: "item3")
                        return .Commit
                    }
                    XCTAssertTrue(db.isInsideTransaction)
                    try insertItem(db, name: "item4")
                    return .Commit
                }
                XCTAssertFalse(db.isInsideTransaction)
                try insertItem(db, name: "item5")
            }
            XCTAssertEqual(sqlQueries, [
                "INSERT INTO items (name) VALUES ('item1')",
                "BEGIN IMMEDIATE TRANSACTION",
                "SAVEPOINT foo",
                "INSERT INTO items (name) VALUES ('item2')",
                "SAVEPOINT foo",
                "INSERT INTO items (name) VALUES ('item3')",
                "RELEASE SAVEPOINT foo",
                "INSERT INTO items (name) VALUES ('item4')",
                "RELEASE SAVEPOINT foo",
                "COMMIT TRANSACTION",
                "INSERT INTO items (name) VALUES ('item5')"
                ])
            XCTAssertEqual(fetchAllItemNames(dbQueue), ["item1", "item2", "item3", "item4", "item5"])
            XCTAssertEqual(observer.allRecordedEvents.count, 5)
            try! dbQueue.inDatabase { db in try db.execute("DELETE FROM items") }
            observer.reset()
            
            sqlQueries.removeAll()
            try dbQueue.inDatabase { db in
                try insertItem(db, name: "item1")
                try db.inSavepoint(named: "foo") {
                    XCTAssertTrue(db.isInsideTransaction)
                    try insertItem(db, name: "item2")
                    try db.inSavepoint(named: "foo") {
                        XCTAssertTrue(db.isInsideTransaction)
                        try insertItem(db, name: "item3")
                        return .Commit
                    }
                    XCTAssertTrue(db.isInsideTransaction)
                    try insertItem(db, name: "item4")
                    return .Rollback
                }
                XCTAssertFalse(db.isInsideTransaction)
                try insertItem(db, name: "item5")
            }
            XCTAssertEqual(sqlQueries, [
                "INSERT INTO items (name) VALUES ('item1')",
                "BEGIN IMMEDIATE TRANSACTION",
                "SAVEPOINT foo",
                "INSERT INTO items (name) VALUES ('item2')",
                "SAVEPOINT foo",
                "INSERT INTO items (name) VALUES ('item3')",
                "RELEASE SAVEPOINT foo",
                "INSERT INTO items (name) VALUES ('item4')",
                "ROLLBACK TRANSACTION TO SAVEPOINT foo",
                "RELEASE SAVEPOINT foo",
                "COMMIT TRANSACTION",
                "INSERT INTO items (name) VALUES ('item5')"
                ])
            XCTAssertEqual(fetchAllItemNames(dbQueue), ["item1", "item5"])
            XCTAssertEqual(observer.allRecordedEvents.count, 2)
            try! dbQueue.inDatabase { db in try db.execute("DELETE FROM items") }
            observer.reset()
            
            sqlQueries.removeAll()
            try dbQueue.inDatabase { db in
                try insertItem(db, name: "item1")
                try db.inSavepoint(named: "foo") {
                    XCTAssertTrue(db.isInsideTransaction)
                    try insertItem(db, name: "item2")
                    try db.inSavepoint(named: "foo") {
                        XCTAssertTrue(db.isInsideTransaction)
                        try insertItem(db, name: "item3")
                        return .Rollback
                    }
                    XCTAssertTrue(db.isInsideTransaction)
                    try insertItem(db, name: "item4")
                    return .Commit
                }
                XCTAssertFalse(db.isInsideTransaction)
                try insertItem(db, name: "item5")
            }
            XCTAssertEqual(sqlQueries, [
                "INSERT INTO items (name) VALUES ('item1')",
                "BEGIN IMMEDIATE TRANSACTION",
                "SAVEPOINT foo",
                "INSERT INTO items (name) VALUES ('item2')",
                "SAVEPOINT foo",
                "INSERT INTO items (name) VALUES ('item3')",
                "ROLLBACK TRANSACTION TO SAVEPOINT foo",
                "RELEASE SAVEPOINT foo",
                "INSERT INTO items (name) VALUES ('item4')",
                "RELEASE SAVEPOINT foo",
                "COMMIT TRANSACTION",
                "INSERT INTO items (name) VALUES ('item5')"
                ])
            XCTAssertEqual(fetchAllItemNames(dbQueue), ["item1", "item2", "item4", "item5"])
            XCTAssertEqual(observer.allRecordedEvents.count, 4)
            try! dbQueue.inDatabase { db in try db.execute("DELETE FROM items") }
            observer.reset()
            
            sqlQueries.removeAll()
            try dbQueue.inDatabase { db in
                try insertItem(db, name: "item1")
                try db.inSavepoint(named: "foo") {
                    XCTAssertTrue(db.isInsideTransaction)
                    try insertItem(db, name: "item2")
                    try db.inSavepoint(named: "foo") {
                        XCTAssertTrue(db.isInsideTransaction)
                        try insertItem(db, name: "item3")
                        return .Rollback
                    }
                    XCTAssertTrue(db.isInsideTransaction)
                    try insertItem(db, name: "item4")
                    return .Rollback
                }
                XCTAssertFalse(db.isInsideTransaction)
                try insertItem(db, name: "item5")
            }
            XCTAssertEqual(sqlQueries, [
                "INSERT INTO items (name) VALUES ('item1')",
                "BEGIN IMMEDIATE TRANSACTION",
                "SAVEPOINT foo",
                "INSERT INTO items (name) VALUES ('item2')",
                "SAVEPOINT foo",
                "INSERT INTO items (name) VALUES ('item3')",
                "ROLLBACK TRANSACTION TO SAVEPOINT foo",
                "RELEASE SAVEPOINT foo",
                "INSERT INTO items (name) VALUES ('item4')",
                "ROLLBACK TRANSACTION TO SAVEPOINT foo",
                "RELEASE SAVEPOINT foo",
                "COMMIT TRANSACTION",
                "INSERT INTO items (name) VALUES ('item5')"
                ])
            XCTAssertEqual(fetchAllItemNames(dbQueue), ["item1", "item5"])
            XCTAssertEqual(observer.allRecordedEvents.count, 2)
            try! dbQueue.inDatabase { db in try db.execute("DELETE FROM items") }
            observer.reset()
        }
    }
}

import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
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
        #if SQLITE_ENABLE_PREUPDATE_HOOK
            allRecordedPreUpdateEvents.removeAll()
        #endif
    }
    
    #if SQLITE_ENABLE_PREUPDATE_HOOK
    var allRecordedPreUpdateEvents: [DatabasePreUpdateEvent] = []
    func databaseWillChangeWithEvent(event: DatabasePreUpdateEvent) {
        allRecordedPreUpdateEvents.append(event.copy())
    }
    #endif
    
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
                try db.inSavepoint {
                    XCTAssertTrue(db.isInsideTransaction)
                    try insertItem(db, name: "item2")
                    return .Commit
                }
                XCTAssertFalse(db.isInsideTransaction)
                try insertItem(db, name: "item3")
            }
            
            XCTAssertEqual(sqlQueries, [
                "INSERT INTO items (name) VALUES ('item1')",
                "SAVEPOINT grdb",
                "INSERT INTO items (name) VALUES ('item2')",
                "RELEASE SAVEPOINT grdb",
                "INSERT INTO items (name) VALUES ('item3')"
                ])
            XCTAssertEqual(fetchAllItemNames(dbQueue), ["item1", "item2", "item3"])
            XCTAssertEqual(observer.allRecordedEvents.count, 3)
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.allRecordedPreUpdateEvents.count, 3)
            #endif
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
                try db.inSavepoint {
                    XCTAssertTrue(db.isInsideTransaction)
                    try insertItem(db, name: "item2")
                    return .Rollback
                }
                XCTAssertFalse(db.isInsideTransaction)
                try insertItem(db, name: "item3")
            }
            XCTAssertEqual(sqlQueries, [
                "INSERT INTO items (name) VALUES ('item1')",
                "SAVEPOINT grdb",
                "INSERT INTO items (name) VALUES ('item2')",
                "ROLLBACK TRANSACTION",
                "INSERT INTO items (name) VALUES ('item3')"
                ])
            XCTAssertEqual(fetchAllItemNames(dbQueue), ["item1", "item3"])
            XCTAssertEqual(observer.allRecordedEvents.count, 2)
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.allRecordedPreUpdateEvents.count, 2)
            #endif
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
                try db.inSavepoint {
                    XCTAssertTrue(db.isInsideTransaction)
                    try insertItem(db, name: "item2")
                    try db.inSavepoint {
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
                "SAVEPOINT grdb",
                "INSERT INTO items (name) VALUES ('item2')",
                "SAVEPOINT grdb",
                "INSERT INTO items (name) VALUES ('item3')",
                "RELEASE SAVEPOINT grdb",
                "INSERT INTO items (name) VALUES ('item4')",
                "RELEASE SAVEPOINT grdb",
                "INSERT INTO items (name) VALUES ('item5')"
                ])
            XCTAssertEqual(fetchAllItemNames(dbQueue), ["item1", "item2", "item3", "item4", "item5"])
            XCTAssertEqual(observer.allRecordedEvents.count, 5)
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.allRecordedPreUpdateEvents.count, 5)
            #endif
            try! dbQueue.inDatabase { db in try db.execute("DELETE FROM items") }
            observer.reset()

            sqlQueries.removeAll()
            try dbQueue.inDatabase { db in
                try insertItem(db, name: "item1")
                try db.inSavepoint {
                    XCTAssertTrue(db.isInsideTransaction)
                    try insertItem(db, name: "item2")
                    try db.inSavepoint {
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
                "SAVEPOINT grdb",
                "INSERT INTO items (name) VALUES ('item2')",
                "SAVEPOINT grdb",
                "INSERT INTO items (name) VALUES ('item3')",
                "RELEASE SAVEPOINT grdb",
                "INSERT INTO items (name) VALUES ('item4')",
                "ROLLBACK TRANSACTION",
                "INSERT INTO items (name) VALUES ('item5')"
                ])
            XCTAssertEqual(fetchAllItemNames(dbQueue), ["item1", "item5"])
            XCTAssertEqual(observer.allRecordedEvents.count, 2)
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.allRecordedPreUpdateEvents.count, 2)
            #endif
            try! dbQueue.inDatabase { db in try db.execute("DELETE FROM items") }
            observer.reset()
            
            sqlQueries.removeAll()
            try dbQueue.inDatabase { db in
                try insertItem(db, name: "item1")
                try db.inSavepoint {
                    XCTAssertTrue(db.isInsideTransaction)
                    try insertItem(db, name: "item2")
                    try db.inSavepoint {
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
                "SAVEPOINT grdb",
                "INSERT INTO items (name) VALUES ('item2')",
                "SAVEPOINT grdb",
                "INSERT INTO items (name) VALUES ('item3')",
                "ROLLBACK TRANSACTION TO SAVEPOINT grdb",
                "RELEASE SAVEPOINT grdb",
                "INSERT INTO items (name) VALUES ('item4')",
                "RELEASE SAVEPOINT grdb",
                "INSERT INTO items (name) VALUES ('item5')"
                ])
            XCTAssertEqual(fetchAllItemNames(dbQueue), ["item1", "item2", "item4", "item5"])
            XCTAssertEqual(observer.allRecordedEvents.count, 4)
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.allRecordedPreUpdateEvents.count, 4)
            #endif
            try! dbQueue.inDatabase { db in try db.execute("DELETE FROM items") }
            observer.reset()
            
            sqlQueries.removeAll()
            try dbQueue.inDatabase { db in
                try insertItem(db, name: "item1")
                try db.inSavepoint {
                    XCTAssertTrue(db.isInsideTransaction)
                    try insertItem(db, name: "item2")
                    try db.inSavepoint {
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
                "SAVEPOINT grdb",
                "INSERT INTO items (name) VALUES ('item2')",
                "SAVEPOINT grdb",
                "INSERT INTO items (name) VALUES ('item3')",
                "ROLLBACK TRANSACTION TO SAVEPOINT grdb",
                "RELEASE SAVEPOINT grdb",
                "INSERT INTO items (name) VALUES ('item4')",
                "ROLLBACK TRANSACTION",
                "INSERT INTO items (name) VALUES ('item5')"
                ])
            XCTAssertEqual(fetchAllItemNames(dbQueue), ["item1", "item5"])
            XCTAssertEqual(observer.allRecordedEvents.count, 2)
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.allRecordedPreUpdateEvents.count, 2)
            #endif
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
                try db.inSavepoint {
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
                "INSERT INTO items (name) VALUES ('item2')",
                "COMMIT TRANSACTION",
                "INSERT INTO items (name) VALUES ('item3')"
                ])
            XCTAssertEqual(fetchAllItemNames(dbQueue), ["item1", "item2", "item3"])
            XCTAssertEqual(observer.allRecordedEvents.count, 3)
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.allRecordedPreUpdateEvents.count, 3)
            #endif
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
                try db.inSavepoint {
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
                "INSERT INTO items (name) VALUES ('item2')",
                "ROLLBACK TRANSACTION",
                "INSERT INTO items (name) VALUES ('item3')"
                ])
            XCTAssertEqual(fetchAllItemNames(dbQueue), ["item1", "item3"])
            XCTAssertEqual(observer.allRecordedEvents.count, 3)
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.allRecordedPreUpdateEvents.count, 3)
            #endif
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
                try db.inSavepoint {
                    XCTAssertTrue(db.isInsideTransaction)
                    try insertItem(db, name: "item2")
                    try db.inSavepoint {
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
                "INSERT INTO items (name) VALUES ('item2')",
                "SAVEPOINT grdb",
                "INSERT INTO items (name) VALUES ('item3')",
                "RELEASE SAVEPOINT grdb",
                "INSERT INTO items (name) VALUES ('item4')",
                "COMMIT TRANSACTION",
                "INSERT INTO items (name) VALUES ('item5')"
                ])
            XCTAssertEqual(fetchAllItemNames(dbQueue), ["item1", "item2", "item3", "item4", "item5"])
            XCTAssertEqual(observer.allRecordedEvents.count, 5)
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.allRecordedPreUpdateEvents.count, 5)
            #endif
            try! dbQueue.inDatabase { db in try db.execute("DELETE FROM items") }
            observer.reset()
            
            sqlQueries.removeAll()
            try dbQueue.inDatabase { db in
                try insertItem(db, name: "item1")
                try db.inSavepoint {
                    XCTAssertTrue(db.isInsideTransaction)
                    try insertItem(db, name: "item2")
                    try db.inSavepoint {
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
                "INSERT INTO items (name) VALUES ('item2')",
                "SAVEPOINT grdb",
                "INSERT INTO items (name) VALUES ('item3')",
                "RELEASE SAVEPOINT grdb",
                "INSERT INTO items (name) VALUES ('item4')",
                "ROLLBACK TRANSACTION",
                "INSERT INTO items (name) VALUES ('item5')"
                ])
            XCTAssertEqual(fetchAllItemNames(dbQueue), ["item1", "item5"])
            XCTAssertEqual(observer.allRecordedEvents.count, 5)
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.allRecordedPreUpdateEvents.count, 5)
            #endif
            try! dbQueue.inDatabase { db in try db.execute("DELETE FROM items") }
            observer.reset()
            
            sqlQueries.removeAll()
            try dbQueue.inDatabase { db in
                try insertItem(db, name: "item1")
                try db.inSavepoint {
                    XCTAssertTrue(db.isInsideTransaction)
                    try insertItem(db, name: "item2")
                    try db.inSavepoint {
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
                "INSERT INTO items (name) VALUES ('item2')",
                "SAVEPOINT grdb",
                "INSERT INTO items (name) VALUES ('item3')",
                "ROLLBACK TRANSACTION TO SAVEPOINT grdb",
                "RELEASE SAVEPOINT grdb",
                "INSERT INTO items (name) VALUES ('item4')",
                "COMMIT TRANSACTION",
                "INSERT INTO items (name) VALUES ('item5')"
                ])
            XCTAssertEqual(fetchAllItemNames(dbQueue), ["item1", "item2", "item4", "item5"])
            XCTAssertEqual(observer.allRecordedEvents.count, 4)
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.allRecordedPreUpdateEvents.count, 4)
            #endif
            try! dbQueue.inDatabase { db in try db.execute("DELETE FROM items") }
            observer.reset()
            
            sqlQueries.removeAll()
            try dbQueue.inDatabase { db in
                try insertItem(db, name: "item1")
                try db.inSavepoint {
                    XCTAssertTrue(db.isInsideTransaction)
                    try insertItem(db, name: "item2")
                    try db.inSavepoint {
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
                "INSERT INTO items (name) VALUES ('item2')",
                "SAVEPOINT grdb",
                "INSERT INTO items (name) VALUES ('item3')",
                "ROLLBACK TRANSACTION TO SAVEPOINT grdb",
                "RELEASE SAVEPOINT grdb",
                "INSERT INTO items (name) VALUES ('item4')",
                "ROLLBACK TRANSACTION",
                "INSERT INTO items (name) VALUES ('item5')"
                ])
            XCTAssertEqual(fetchAllItemNames(dbQueue), ["item1", "item5"])
            XCTAssertEqual(observer.allRecordedEvents.count, 4)
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.allRecordedPreUpdateEvents.count, 4)
            #endif
            try! dbQueue.inDatabase { db in try db.execute("DELETE FROM items") }
            observer.reset()
        }
    }
    
    func testSubsequentSavepoints() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let observer = TransactionObserver()
            dbQueue.addTransactionObserver(observer)
            try dbQueue.inTransaction { db in
                try db.inSavepoint {
                    try insertItem(db, name: "item1")
                    return .Rollback
                }
                
                try db.inSavepoint {
                    try insertItem(db, name: "item2")
                    return .Commit
                }
                
                return .Commit
            }
            XCTAssertEqual(fetchAllItemNames(dbQueue), ["item2"])
            XCTAssertEqual(observer.allRecordedEvents.count, 1)
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.allRecordedPreUpdateEvents.count, 1)
            #endif
        }
    }
    
    func testSubsequentSavepointsWithErrors() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let observer = TransactionObserver()
            dbQueue.addTransactionObserver(observer)
            try dbQueue.inTransaction { db in
                do {
                    try db.inSavepoint {
                        try insertItem(db, name: "item1")
                        throw DatabaseError(code: 123)
                    }
                    XCTFail()
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.code, 123)
                }
                
                try db.inSavepoint {
                    try insertItem(db, name: "item2")
                    return .Commit
                }
                
                return .Commit
            }
            XCTAssertEqual(fetchAllItemNames(dbQueue), ["item2"])
            XCTAssertEqual(observer.allRecordedEvents.count, 1)
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.allRecordedPreUpdateEvents.count, 1)
            #endif
        }
    }
}

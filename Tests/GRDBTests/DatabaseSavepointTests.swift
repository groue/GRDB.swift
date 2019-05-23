import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

func insertItem(_ db: Database, name: String) throws {
    try db.execute(sql: "INSERT INTO items (name) VALUES (?)", arguments: [name])
}

func fetchAllItemNames(_ dbReader: DatabaseReader) throws -> [String] {
    return try dbReader.read { db in
        try String.fetchAll(db, sql: "SELECT * FROM items ORDER BY name")
    }
}

private class Observer : TransactionObserver {
    var allRecordedEvents: [DatabaseEvent] = []
    
    func reset() {
        allRecordedEvents.removeAll()
        #if SQLITE_ENABLE_PREUPDATE_HOOK
            allRecordedPreUpdateEvents.removeAll()
        #endif
    }
    
    #if SQLITE_ENABLE_PREUPDATE_HOOK
    var allRecordedPreUpdateEvents: [DatabasePreUpdateEvent] = []
    func databaseWillChange(with event: DatabasePreUpdateEvent) {
        allRecordedPreUpdateEvents.append(event.copy())
    }
    #endif
    
    func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool {
        return true
    }
    
    func databaseDidChange(with event: DatabaseEvent) {
        allRecordedEvents.append(event.copy())
    }
    
    func databaseDidCommit(_ db: Database) {
    }
    
    func databaseDidRollback(_ db: Database) {
    }
}

class DatabaseSavepointTests: GRDBTestCase {
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
        try dbWriter.write { db in
            try db.execute(sql: "CREATE TABLE items (name TEXT)")
        }
    }
    
    func testIsInsideTransaction() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.writeWithoutTransaction { db in
            XCTAssertFalse(db.isInsideTransaction)
            try db.inTransaction {
                XCTAssertTrue(db.isInsideTransaction)
                return .commit
            }
            XCTAssertFalse(db.isInsideTransaction)
            
            try db.execute(sql: "BEGIN DEFERRED TRANSACTION")
            XCTAssertTrue(db.isInsideTransaction)
            try db.execute(sql: "COMMIT")    // does not trigger sqlite3_commit_hook, because transaction was not open yet.
            XCTAssertFalse(db.isInsideTransaction)
            
            try db.execute(sql: "BEGIN DEFERRED TRANSACTION")
            XCTAssertTrue(db.isInsideTransaction)
            try db.execute(sql: "ROLLBACK")  // does trigger sqlite3_rollback_hook
            XCTAssertFalse(db.isInsideTransaction)
            
            try db.execute(sql: "BEGIN IMMEDIATE TRANSACTION")
            XCTAssertTrue(db.isInsideTransaction)
            try db.execute(sql: "COMMIT")    // does trigger sqlite3_commit_hook
            XCTAssertFalse(db.isInsideTransaction)
            
            try db.execute(sql: "BEGIN IMMEDIATE TRANSACTION")
            XCTAssertTrue(db.isInsideTransaction)
            try db.execute(sql: "ROLLBACK")
            XCTAssertFalse(db.isInsideTransaction)
        }
    }

    func testIsInsideTransactionWithImplicitRollback() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.writeWithoutTransaction { db in
            try db.create(table: "test") { t in
                t.column("value", .integer).unique()
            }
            try db.execute(sql: "BEGIN TRANSACTION")
            XCTAssertTrue(db.isInsideTransaction)
            try db.execute(sql: "INSERT INTO test (value) VALUES (?)", arguments: [1])
            XCTAssertTrue(db.isInsideTransaction)
            XCTAssertThrowsError(try db.execute(sql: "INSERT OR ROLLBACK INTO test (value) VALUES (?)", arguments: [1]))
            XCTAssertFalse(db.isInsideTransaction)
            XCTAssertThrowsError(try db.execute(sql: "COMMIT"))
        }
    }

    func testReleaseTopLevelSavepointFromDatabaseWithDefaultDeferredTransactions() throws {
        dbConfiguration.defaultTransactionKind = .deferred
        let dbQueue = try makeDatabaseQueue()
        let observer = Observer()
        dbQueue.add(transactionObserver: observer)
        sqlQueries.removeAll()
        try dbQueue.writeWithoutTransaction { db in
            try insertItem(db, name: "item1")
            try db.inSavepoint {
                XCTAssertTrue(db.isInsideTransaction)
                try insertItem(db, name: "item2")
                return .commit
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
        XCTAssertEqual(try fetchAllItemNames(dbQueue), ["item1", "item2", "item3"])
        XCTAssertEqual(observer.allRecordedEvents.count, 3)
        #if SQLITE_ENABLE_PREUPDATE_HOOK
            XCTAssertEqual(observer.allRecordedPreUpdateEvents.count, 3)
        #endif
    }

    func testRollbackTopLevelSavepointFromDatabaseWithDefaultDeferredTransactions() throws {
        dbConfiguration.defaultTransactionKind = .deferred
        let dbQueue = try makeDatabaseQueue()
        let observer = Observer()
        dbQueue.add(transactionObserver: observer)
        sqlQueries.removeAll()
        try dbQueue.writeWithoutTransaction { db in
            try insertItem(db, name: "item1")
            try db.inSavepoint {
                XCTAssertTrue(db.isInsideTransaction)
                try insertItem(db, name: "item2")
                return .rollback
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
        XCTAssertEqual(try fetchAllItemNames(dbQueue), ["item1", "item3"])
        XCTAssertEqual(observer.allRecordedEvents.count, 2)
        #if SQLITE_ENABLE_PREUPDATE_HOOK
            XCTAssertEqual(observer.allRecordedPreUpdateEvents.count, 2)
        #endif
    }

    func testNestedSavepointFromDatabaseWithDefaultDeferredTransactions() throws {
        dbConfiguration.defaultTransactionKind = .deferred
        let dbQueue = try makeDatabaseQueue()
        let observer = Observer()
        dbQueue.add(transactionObserver: observer)
        sqlQueries.removeAll()
        try dbQueue.writeWithoutTransaction { db in
            try insertItem(db, name: "item1")
            try db.inSavepoint {
                XCTAssertTrue(db.isInsideTransaction)
                try insertItem(db, name: "item2")
                try db.inSavepoint {
                    XCTAssertTrue(db.isInsideTransaction)
                    try insertItem(db, name: "item3")
                    return .commit
                }
                XCTAssertTrue(db.isInsideTransaction)
                try insertItem(db, name: "item4")
                return .commit
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
        XCTAssertEqual(try fetchAllItemNames(dbQueue), ["item1", "item2", "item3", "item4", "item5"])
        XCTAssertEqual(observer.allRecordedEvents.count, 5)
        #if SQLITE_ENABLE_PREUPDATE_HOOK
            XCTAssertEqual(observer.allRecordedPreUpdateEvents.count, 5)
        #endif
        try dbQueue.inDatabase { db in try db.execute(sql: "DELETE FROM items") }
        observer.reset()
        
        sqlQueries.removeAll()
        try dbQueue.writeWithoutTransaction { db in
            try insertItem(db, name: "item1")
            try db.inSavepoint {
                XCTAssertTrue(db.isInsideTransaction)
                try insertItem(db, name: "item2")
                try db.inSavepoint {
                    XCTAssertTrue(db.isInsideTransaction)
                    try insertItem(db, name: "item3")
                    return .commit
                }
                XCTAssertTrue(db.isInsideTransaction)
                try insertItem(db, name: "item4")
                return .rollback
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
        XCTAssertEqual(try fetchAllItemNames(dbQueue), ["item1", "item5"])
        XCTAssertEqual(observer.allRecordedEvents.count, 2)
        #if SQLITE_ENABLE_PREUPDATE_HOOK
            XCTAssertEqual(observer.allRecordedPreUpdateEvents.count, 2)
        #endif
        try dbQueue.inDatabase { db in try db.execute(sql: "DELETE FROM items") }
        observer.reset()
        
        sqlQueries.removeAll()
        try dbQueue.writeWithoutTransaction { db in
            try insertItem(db, name: "item1")
            try db.inSavepoint {
                XCTAssertTrue(db.isInsideTransaction)
                try insertItem(db, name: "item2")
                try db.inSavepoint {
                    XCTAssertTrue(db.isInsideTransaction)
                    try insertItem(db, name: "item3")
                    return .rollback
                }
                XCTAssertTrue(db.isInsideTransaction)
                try insertItem(db, name: "item4")
                return .commit
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
        XCTAssertEqual(try fetchAllItemNames(dbQueue), ["item1", "item2", "item4", "item5"])
        XCTAssertEqual(observer.allRecordedEvents.count, 4)
        #if SQLITE_ENABLE_PREUPDATE_HOOK
            XCTAssertEqual(observer.allRecordedPreUpdateEvents.count, 4)
        #endif
        try dbQueue.inDatabase { db in try db.execute(sql: "DELETE FROM items") }
        observer.reset()
        
        sqlQueries.removeAll()
        try dbQueue.writeWithoutTransaction { db in
            try insertItem(db, name: "item1")
            try db.inSavepoint {
                XCTAssertTrue(db.isInsideTransaction)
                try insertItem(db, name: "item2")
                try db.inSavepoint {
                    XCTAssertTrue(db.isInsideTransaction)
                    try insertItem(db, name: "item3")
                    return .rollback
                }
                XCTAssertTrue(db.isInsideTransaction)
                try insertItem(db, name: "item4")
                return .rollback
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
        XCTAssertEqual(try fetchAllItemNames(dbQueue), ["item1", "item5"])
        XCTAssertEqual(observer.allRecordedEvents.count, 2)
        #if SQLITE_ENABLE_PREUPDATE_HOOK
            XCTAssertEqual(observer.allRecordedPreUpdateEvents.count, 2)
        #endif
        try dbQueue.inDatabase { db in try db.execute(sql: "DELETE FROM items") }
        observer.reset()
    }

    func testReleaseTopLevelSavepointFromDatabaseWithDefaultImmediateTransactions() throws {
        dbConfiguration.defaultTransactionKind = .immediate
        let dbQueue = try makeDatabaseQueue()
        let observer = Observer()
        dbQueue.add(transactionObserver: observer)
        sqlQueries.removeAll()
        try dbQueue.writeWithoutTransaction { db in
            try insertItem(db, name: "item1")
            try db.inSavepoint {
                XCTAssertTrue(db.isInsideTransaction)
                try insertItem(db, name: "item2")
                return .commit
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
        XCTAssertEqual(try fetchAllItemNames(dbQueue), ["item1", "item2", "item3"])
        XCTAssertEqual(observer.allRecordedEvents.count, 3)
        #if SQLITE_ENABLE_PREUPDATE_HOOK
            XCTAssertEqual(observer.allRecordedPreUpdateEvents.count, 3)
        #endif
    }

    func testRollbackTopLevelSavepointFromDatabaseWithDefaultImmediateTransactions() throws {
        dbConfiguration.defaultTransactionKind = .immediate
        let dbQueue = try makeDatabaseQueue()
        let observer = Observer()
        dbQueue.add(transactionObserver: observer)
        sqlQueries.removeAll()
        try dbQueue.writeWithoutTransaction { db in
            try insertItem(db, name: "item1")
            try db.inSavepoint {
                XCTAssertTrue(db.isInsideTransaction)
                try insertItem(db, name: "item2")
                return .rollback
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
        XCTAssertEqual(try fetchAllItemNames(dbQueue), ["item1", "item3"])
        XCTAssertEqual(observer.allRecordedEvents.count, 3)
        #if SQLITE_ENABLE_PREUPDATE_HOOK
            XCTAssertEqual(observer.allRecordedPreUpdateEvents.count, 3)
        #endif
    }

    func testNestedSavepointFromDatabaseWithDefaultImmediateTransactions() throws {
        dbConfiguration.defaultTransactionKind = .immediate
        let dbQueue = try makeDatabaseQueue()
        let observer = Observer()
        dbQueue.add(transactionObserver: observer)
        sqlQueries.removeAll()
        try dbQueue.writeWithoutTransaction { db in
            try insertItem(db, name: "item1")
            try db.inSavepoint {
                XCTAssertTrue(db.isInsideTransaction)
                try insertItem(db, name: "item2")
                try db.inSavepoint {
                    XCTAssertTrue(db.isInsideTransaction)
                    try insertItem(db, name: "item3")
                    return .commit
                }
                XCTAssertTrue(db.isInsideTransaction)
                try insertItem(db, name: "item4")
                return .commit
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
        XCTAssertEqual(try fetchAllItemNames(dbQueue), ["item1", "item2", "item3", "item4", "item5"])
        XCTAssertEqual(observer.allRecordedEvents.count, 5)
        #if SQLITE_ENABLE_PREUPDATE_HOOK
            XCTAssertEqual(observer.allRecordedPreUpdateEvents.count, 5)
        #endif
        try dbQueue.inDatabase { db in try db.execute(sql: "DELETE FROM items") }
        observer.reset()
        
        sqlQueries.removeAll()
        try dbQueue.writeWithoutTransaction { db in
            try insertItem(db, name: "item1")
            try db.inSavepoint {
                XCTAssertTrue(db.isInsideTransaction)
                try insertItem(db, name: "item2")
                try db.inSavepoint {
                    XCTAssertTrue(db.isInsideTransaction)
                    try insertItem(db, name: "item3")
                    return .commit
                }
                XCTAssertTrue(db.isInsideTransaction)
                try insertItem(db, name: "item4")
                return .rollback
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
        XCTAssertEqual(try fetchAllItemNames(dbQueue), ["item1", "item5"])
        XCTAssertEqual(observer.allRecordedEvents.count, 5)
        #if SQLITE_ENABLE_PREUPDATE_HOOK
            XCTAssertEqual(observer.allRecordedPreUpdateEvents.count, 5)
        #endif
        try dbQueue.inDatabase { db in try db.execute(sql: "DELETE FROM items") }
        observer.reset()
        
        sqlQueries.removeAll()
        try dbQueue.writeWithoutTransaction { db in
            try insertItem(db, name: "item1")
            try db.inSavepoint {
                XCTAssertTrue(db.isInsideTransaction)
                try insertItem(db, name: "item2")
                try db.inSavepoint {
                    XCTAssertTrue(db.isInsideTransaction)
                    try insertItem(db, name: "item3")
                    return .rollback
                }
                XCTAssertTrue(db.isInsideTransaction)
                try insertItem(db, name: "item4")
                return .commit
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
        XCTAssertEqual(try fetchAllItemNames(dbQueue), ["item1", "item2", "item4", "item5"])
        XCTAssertEqual(observer.allRecordedEvents.count, 4)
        #if SQLITE_ENABLE_PREUPDATE_HOOK
            XCTAssertEqual(observer.allRecordedPreUpdateEvents.count, 4)
        #endif
        try dbQueue.inDatabase { db in try db.execute(sql: "DELETE FROM items") }
        observer.reset()
        
        sqlQueries.removeAll()
        try dbQueue.writeWithoutTransaction { db in
            try insertItem(db, name: "item1")
            try db.inSavepoint {
                XCTAssertTrue(db.isInsideTransaction)
                try insertItem(db, name: "item2")
                try db.inSavepoint {
                    XCTAssertTrue(db.isInsideTransaction)
                    try insertItem(db, name: "item3")
                    return .rollback
                }
                XCTAssertTrue(db.isInsideTransaction)
                try insertItem(db, name: "item4")
                return .rollback
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
        XCTAssertEqual(try fetchAllItemNames(dbQueue), ["item1", "item5"])
        XCTAssertEqual(observer.allRecordedEvents.count, 4)
        #if SQLITE_ENABLE_PREUPDATE_HOOK
            XCTAssertEqual(observer.allRecordedPreUpdateEvents.count, 4)
        #endif
        try dbQueue.inDatabase { db in try db.execute(sql: "DELETE FROM items") }
        observer.reset()
    }

    func testSubsequentSavepoints() throws {
        let dbQueue = try makeDatabaseQueue()
        let observer = Observer()
        dbQueue.add(transactionObserver: observer)
        try dbQueue.inTransaction { db in
            try db.inSavepoint {
                try insertItem(db, name: "item1")
                return .rollback
            }
            
            try db.inSavepoint {
                try insertItem(db, name: "item2")
                return .commit
            }
            
            return .commit
        }
        XCTAssertEqual(try fetchAllItemNames(dbQueue), ["item2"])
        XCTAssertEqual(observer.allRecordedEvents.count, 1)
        #if SQLITE_ENABLE_PREUPDATE_HOOK
            XCTAssertEqual(observer.allRecordedPreUpdateEvents.count, 1)
        #endif
    }

    func testSubsequentSavepointsWithErrors() throws {
        let dbQueue = try makeDatabaseQueue()
        let observer = Observer()
        dbQueue.add(transactionObserver: observer)
        try dbQueue.inTransaction { db in
            do {
                try db.inSavepoint {
                    try insertItem(db, name: "item1")
                    throw DatabaseError(resultCode: ResultCode(rawValue: 123))
                }
                XCTFail()
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode.rawValue, 123)
            }
            
            try db.inSavepoint {
                try insertItem(db, name: "item2")
                return .commit
            }
            
            return .commit
        }
        XCTAssertEqual(try fetchAllItemNames(dbQueue), ["item2"])
        XCTAssertEqual(observer.allRecordedEvents.count, 1)
        #if SQLITE_ENABLE_PREUPDATE_HOOK
            XCTAssertEqual(observer.allRecordedPreUpdateEvents.count, 1)
        #endif
    }
}

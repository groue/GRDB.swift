import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private class Observer : TransactionObserver {
    var lastCommittedEvents: [DatabaseEvent] = []
    var events: [DatabaseEvent] = []
    
#if SQLITE_ENABLE_PREUPDATE_HOOK
    var preUpdateEvents: [DatabasePreUpdateEvent] = []
    func databaseWillChange(with event: DatabasePreUpdateEvent) {
        preUpdateEvents.append(event.copy())
    }
#endif
    
    func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool {
        return true
    }
    
    func databaseDidChange(with event: DatabaseEvent) {
        events.append(event.copy())
    }
    
    func databaseDidCommit(_ db: Database) {
        lastCommittedEvents = events
        events = []
    }
    
    func databaseDidRollback(_ db: Database) {
        lastCommittedEvents = []
        events = []
    }
}

class TransactionObserverSavepointsTests: GRDBTestCase {
    
    private func match(event: DatabaseEvent, kind: DatabaseEvent.Kind, tableName: String, rowId: Int64) -> Bool {
        return (event.tableName == tableName) && (event.rowID == rowId) && (event.kind == kind)
    }
    
#if SQLITE_ENABLE_PREUPDATE_HOOK
    
    private func match(preUpdateEvent event: DatabasePreUpdateEvent, kind: DatabasePreUpdateEvent.Kind, tableName: String, initialRowID: Int64?, finalRowID: Int64?, initialValues: [DatabaseValue]?, finalValues: [DatabaseValue]?, depth: CInt = 0) -> Bool {
        
        func check(_ dbValues: [DatabaseValue]?, expected: [DatabaseValue]?) -> Bool {
            if let dbValues = dbValues {
                guard let expected = expected else { return false }
                return dbValues == expected
            }
            else { return expected == nil }
        }
        
        var count : Int = 0
        if let initialValues = initialValues { count = initialValues.count }
        if let finalValues = finalValues { count = max(count, finalValues.count) }
        
        guard (event.kind == kind) else { return false }
        guard (event.tableName == tableName) else { return false }
        guard (event.count == count) else { return false }
        guard (event.depth == depth) else { return false }
        guard (event.initialRowID == initialRowID) else { return false }
        guard (event.finalRowID == finalRowID) else { return false }
        guard check(event.initialDatabaseValues, expected: initialValues) else { return false }
        guard check(event.finalDatabaseValues, expected: finalValues) else { return false }
        
        return true
    }
    
#endif
    
    
    // MARK: - Events
    func testSavepointAsTransaction() throws {
        let dbQueue = try makeDatabaseQueue()
        let observer = Observer()
        dbQueue.add(transactionObserver: observer)
        
        try dbQueue.writeWithoutTransaction { db in
            try db.execute(sql: "CREATE TABLE items1 (id INTEGER PRIMARY KEY)")
            try db.execute(sql: "CREATE TABLE items2 (id INTEGER PRIMARY KEY)")
            try db.execute(sql: "SAVEPOINT sp1")
            XCTAssertTrue(db.isInsideTransaction)
            try db.execute(sql: "INSERT INTO items1 (id) VALUES (NULL)")
            XCTAssertEqual(observer.events.count, 0)
            try db.execute(sql: "INSERT INTO items2 (id) VALUES (NULL)")
            XCTAssertEqual(observer.events.count, 0)
            try db.execute(sql: "RELEASE SAVEPOINT sp1")
            XCTAssertFalse(db.isInsideTransaction)
            
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items1"), 1)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items2"), 1)
        }
        
        XCTAssertEqual(observer.lastCommittedEvents.count, 2)
        XCTAssertTrue(match(event: observer.lastCommittedEvents[0], kind: .insert, tableName: "items1", rowId: 1))
        XCTAssertTrue(match(event: observer.lastCommittedEvents[1], kind: .insert, tableName: "items2", rowId: 1))
        
        #if SQLITE_ENABLE_PREUPDATE_HOOK
            XCTAssertEqual(observer.preUpdateEvents.count, 2)
            XCTAssertTrue(match(preUpdateEvent: observer.preUpdateEvents[0], kind: .insert, tableName: "items1", initialRowID: nil, finalRowID: 1, initialValues: nil, finalValues: [Int(1).databaseValue]))
            XCTAssertTrue(match(preUpdateEvent: observer.preUpdateEvents[1], kind: .insert, tableName: "items2", initialRowID: nil, finalRowID: 1, initialValues: nil, finalValues: [Int(1).databaseValue]))
        #endif
    }

    func testSavepointInsideTransaction() throws {
        let dbQueue = try makeDatabaseQueue()
        let observer = Observer()
        dbQueue.add(transactionObserver: observer)
        
        try dbQueue.writeWithoutTransaction { db in
            try db.execute(sql: "CREATE TABLE items1 (id INTEGER PRIMARY KEY)")
            try db.execute(sql: "CREATE TABLE items2 (id INTEGER PRIMARY KEY)")
            try db.execute(sql: "BEGIN TRANSACTION")
            try db.execute(sql: "INSERT INTO items1 (id) VALUES (NULL)")
            XCTAssertEqual(observer.events.count, 1)
            try db.execute(sql: "SAVEPOINT sp1")
            try db.execute(sql: "INSERT INTO items2 (id) VALUES (NULL)")
            XCTAssertEqual(observer.events.count, 1)
            try db.execute(sql: "COMMIT")
            
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items1"), 1)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items2"), 1)
        }
        
        XCTAssertEqual(observer.lastCommittedEvents.count, 2)
        XCTAssertTrue(match(event: observer.lastCommittedEvents[0], kind: .insert, tableName: "items1", rowId: 1))
        XCTAssertTrue(match(event: observer.lastCommittedEvents[1], kind: .insert, tableName: "items2", rowId: 1))
        
        #if SQLITE_ENABLE_PREUPDATE_HOOK
            XCTAssertEqual(observer.preUpdateEvents.count, 2)
            XCTAssertTrue(match(preUpdateEvent: observer.preUpdateEvents[0], kind: .insert, tableName: "items1", initialRowID: nil, finalRowID: 1, initialValues: nil, finalValues: [Int(1).databaseValue]))
            XCTAssertTrue(match(preUpdateEvent: observer.preUpdateEvents[1], kind: .insert, tableName: "items2", initialRowID: nil, finalRowID: 1, initialValues: nil, finalValues: [Int(1).databaseValue]))
        #endif
    }

    func testSavepointWithIdenticalName() throws {
        let dbQueue = try makeDatabaseQueue()
        let observer = Observer()
        dbQueue.add(transactionObserver: observer)
        
        try dbQueue.writeWithoutTransaction { db in
            try db.execute(sql: "CREATE TABLE items1 (id INTEGER PRIMARY KEY)")
            try db.execute(sql: "CREATE TABLE items2 (id INTEGER PRIMARY KEY)")
            try db.execute(sql: "CREATE TABLE items3 (id INTEGER PRIMARY KEY)")
            try db.execute(sql: "CREATE TABLE items4 (id INTEGER PRIMARY KEY)")
            try db.execute(sql: "BEGIN TRANSACTION")
            try db.execute(sql: "INSERT INTO items1 (id) VALUES (NULL)")
            XCTAssertEqual(observer.events.count, 1)
            try db.execute(sql: "SAVEPOINT sp1")
            try db.execute(sql: "INSERT INTO items2 (id) VALUES (NULL)")
            XCTAssertEqual(observer.events.count, 1)
            try db.execute(sql: "SAVEPOINT sp1")
            try db.execute(sql: "INSERT INTO items3 (id) VALUES (NULL)")
            XCTAssertEqual(observer.events.count, 1)
            try db.execute(sql: "RELEASE SAVEPOINT sp1")
            XCTAssertEqual(observer.events.count, 1)
            try db.execute(sql: "RELEASE SAVEPOINT sp1")
            XCTAssertEqual(observer.events.count, 3)
            try db.execute(sql: "INSERT INTO items4 (id) VALUES (NULL)")
            XCTAssertEqual(observer.events.count, 4)
            try db.execute(sql: "COMMIT")
            
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items1"), 1)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items2"), 1)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items3"), 1)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items4"), 1)
        }
        
        XCTAssertEqual(observer.lastCommittedEvents.count, 4)
        XCTAssertTrue(match(event: observer.lastCommittedEvents[0], kind: .insert, tableName: "items1", rowId: 1))
        XCTAssertTrue(match(event: observer.lastCommittedEvents[1], kind: .insert, tableName: "items2", rowId: 1))
        XCTAssertTrue(match(event: observer.lastCommittedEvents[2], kind: .insert, tableName: "items3", rowId: 1))
        XCTAssertTrue(match(event: observer.lastCommittedEvents[3], kind: .insert, tableName: "items4", rowId: 1))
        
        #if SQLITE_ENABLE_PREUPDATE_HOOK
            XCTAssertEqual(observer.preUpdateEvents.count, 4)
            XCTAssertTrue(match(preUpdateEvent: observer.preUpdateEvents[0], kind: .insert, tableName: "items1", initialRowID: nil, finalRowID: 1, initialValues: nil, finalValues: [Int(1).databaseValue]))
            XCTAssertTrue(match(preUpdateEvent: observer.preUpdateEvents[1], kind: .insert, tableName: "items2", initialRowID: nil, finalRowID: 1, initialValues: nil, finalValues: [Int(1).databaseValue]))
            XCTAssertTrue(match(preUpdateEvent: observer.preUpdateEvents[2], kind: .insert, tableName: "items3", initialRowID: nil, finalRowID: 1, initialValues: nil, finalValues: [Int(1).databaseValue]))
            XCTAssertTrue(match(preUpdateEvent: observer.preUpdateEvents[3], kind: .insert, tableName: "items4", initialRowID: nil, finalRowID: 1, initialValues: nil, finalValues: [Int(1).databaseValue]))
        #endif
    }

    func testMultipleRollbackOfSavepoint() throws {
        let dbQueue = try makeDatabaseQueue()
        let observer = Observer()
        dbQueue.add(transactionObserver: observer)
        
        try dbQueue.writeWithoutTransaction { db in
            try db.execute(sql: "CREATE TABLE items1 (id INTEGER PRIMARY KEY)")
            try db.execute(sql: "CREATE TABLE items2 (id INTEGER PRIMARY KEY)")
            try db.execute(sql: "CREATE TABLE items3 (id INTEGER PRIMARY KEY)")
            try db.execute(sql: "CREATE TABLE items4 (id INTEGER PRIMARY KEY)")
            try db.execute(sql: "BEGIN TRANSACTION")
            try db.execute(sql: "INSERT INTO items1 (id) VALUES (NULL)")
            XCTAssertEqual(observer.events.count, 1)
            try db.execute(sql: "SAVEPOINT sp1")
            try db.execute(sql: "INSERT INTO items2 (id) VALUES (NULL)")
            XCTAssertEqual(observer.events.count, 1)
            try db.execute(sql: "INSERT INTO items3 (id) VALUES (NULL)")
            XCTAssertEqual(observer.events.count, 1)
            try db.execute(sql: "ROLLBACK TO SAVEPOINT sp1")
            try db.execute(sql: "INSERT INTO items4 (id) VALUES (NULL)")
            XCTAssertEqual(observer.events.count, 1)
            try db.execute(sql: "ROLLBACK TO SAVEPOINT sp1")
            try db.execute(sql: "INSERT INTO items4 (id) VALUES (NULL)")
            XCTAssertEqual(observer.events.count, 1)
            try db.execute(sql: "COMMIT")
            
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items1"), 1)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items2"), 0)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items3"), 0)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items4"), 1)
        }
        
        XCTAssertEqual(observer.lastCommittedEvents.count, 2)
        XCTAssertTrue(match(event: observer.lastCommittedEvents[0], kind: .insert, tableName: "items1", rowId: 1))
        XCTAssertTrue(match(event: observer.lastCommittedEvents[1], kind: .insert, tableName: "items4", rowId: 1))
        
        #if SQLITE_ENABLE_PREUPDATE_HOOK
            XCTAssertEqual(observer.preUpdateEvents.count, 2)
            XCTAssertTrue(match(preUpdateEvent: observer.preUpdateEvents[0], kind: .insert, tableName: "items1", initialRowID: nil, finalRowID: 1, initialValues: nil, finalValues: [Int(1).databaseValue]))
            XCTAssertTrue(match(preUpdateEvent: observer.preUpdateEvents[1], kind: .insert, tableName: "items4", initialRowID: nil, finalRowID: 1, initialValues: nil, finalValues: [Int(1).databaseValue]))
        #endif
    }

    func testReleaseSavepoint() throws {
        let dbQueue = try makeDatabaseQueue()
        let observer = Observer()
        dbQueue.add(transactionObserver: observer)
        
        try dbQueue.writeWithoutTransaction { db in
            try db.execute(sql: "CREATE TABLE items1 (id INTEGER PRIMARY KEY)")
            try db.execute(sql: "CREATE TABLE items2 (id INTEGER PRIMARY KEY)")
            try db.execute(sql: "CREATE TABLE items3 (id INTEGER PRIMARY KEY)")
            try db.execute(sql: "CREATE TABLE items4 (id INTEGER PRIMARY KEY)")
            try db.execute(sql: "BEGIN TRANSACTION")
            try db.execute(sql: "INSERT INTO items1 (id) VALUES (NULL)")
            XCTAssertEqual(observer.events.count, 1)
            try db.execute(sql: "SAVEPOINT sp1")
            try db.execute(sql: "INSERT INTO items2 (id) VALUES (NULL)")
            try db.execute(sql: "INSERT INTO items3 (id) VALUES (NULL)")
            XCTAssertEqual(observer.events.count, 1)
            try db.execute(sql: "RELEASE SAVEPOINT sp1")
            XCTAssertEqual(observer.events.count, 3)
            try db.execute(sql: "INSERT INTO items4 (id) VALUES (NULL)")
            XCTAssertEqual(observer.events.count, 4)
            try db.execute(sql: "COMMIT")
            
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items1"), 1)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items2"), 1)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items3"), 1)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items4"), 1)
        }
        
        XCTAssertEqual(observer.lastCommittedEvents.count, 4)
        XCTAssertTrue(match(event: observer.lastCommittedEvents[0], kind: .insert, tableName: "items1", rowId: 1))
        XCTAssertTrue(match(event: observer.lastCommittedEvents[1], kind: .insert, tableName: "items2", rowId: 1))
        XCTAssertTrue(match(event: observer.lastCommittedEvents[2], kind: .insert, tableName: "items3", rowId: 1))
        XCTAssertTrue(match(event: observer.lastCommittedEvents[3], kind: .insert, tableName: "items4", rowId: 1))
        
        #if SQLITE_ENABLE_PREUPDATE_HOOK
            XCTAssertEqual(observer.preUpdateEvents.count, 4)
            XCTAssertTrue(match(preUpdateEvent: observer.preUpdateEvents[0], kind: .insert, tableName: "items1", initialRowID: nil, finalRowID: 1, initialValues: nil, finalValues: [Int(1).databaseValue]))
            XCTAssertTrue(match(preUpdateEvent: observer.preUpdateEvents[1], kind: .insert, tableName: "items2", initialRowID: nil, finalRowID: 1, initialValues: nil, finalValues: [Int(1).databaseValue]))
            XCTAssertTrue(match(preUpdateEvent: observer.preUpdateEvents[2], kind: .insert, tableName: "items3", initialRowID: nil, finalRowID: 1, initialValues: nil, finalValues: [Int(1).databaseValue]))
            XCTAssertTrue(match(preUpdateEvent: observer.preUpdateEvents[3], kind: .insert, tableName: "items4", initialRowID: nil, finalRowID: 1, initialValues: nil, finalValues: [Int(1).databaseValue]))
        #endif
    }

    func testRollbackNonNestedSavepointInsideTransaction() throws {
        let dbQueue = try makeDatabaseQueue()
        let observer = Observer()
        dbQueue.add(transactionObserver: observer)
        
        try dbQueue.writeWithoutTransaction { db in
            try db.execute(sql: "CREATE TABLE items1 (id INTEGER PRIMARY KEY)")
            try db.execute(sql: "CREATE TABLE items2 (id INTEGER PRIMARY KEY)")
            try db.execute(sql: "CREATE TABLE items3 (id INTEGER PRIMARY KEY)")
            try db.execute(sql: "CREATE TABLE items4 (id INTEGER PRIMARY KEY)")
            try db.execute(sql: "BEGIN TRANSACTION")
            try db.execute(sql: "INSERT INTO items1 (id) VALUES (NULL)")
            XCTAssertEqual(observer.events.count, 1)
            try db.execute(sql: "SAVEPOINT sp1")
            try db.execute(sql: "INSERT INTO items2 (id) VALUES (NULL)")
            XCTAssertEqual(observer.events.count, 1)
            try db.execute(sql: "SAVEPOINT sp2")
            try db.execute(sql: "INSERT INTO items3 (id) VALUES (NULL)")
            XCTAssertEqual(observer.events.count, 1)
            try db.execute(sql: "RELEASE SAVEPOINT sp2")
            XCTAssertEqual(observer.events.count, 1)
            try db.execute(sql: "ROLLBACK TO SAVEPOINT sp1")
            XCTAssertEqual(observer.events.count, 1)
            try db.execute(sql: "INSERT INTO items4 (id) VALUES (NULL)")
            XCTAssertEqual(observer.events.count, 1)
            try db.execute(sql: "COMMIT")
            
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items1"), 1)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items2"), 0)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items3"), 0)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items4"), 1)
        }
        
        XCTAssertEqual(observer.lastCommittedEvents.count, 2)
        XCTAssertTrue(match(event: observer.lastCommittedEvents[0], kind: .insert, tableName: "items1", rowId: 1))
        XCTAssertTrue(match(event: observer.lastCommittedEvents[1], kind: .insert, tableName: "items4", rowId: 1))
        
        #if SQLITE_ENABLE_PREUPDATE_HOOK
            XCTAssertEqual(observer.preUpdateEvents.count, 2)
            XCTAssertTrue(match(preUpdateEvent: observer.preUpdateEvents[0], kind: .insert, tableName: "items1", initialRowID: nil, finalRowID: 1, initialValues: nil, finalValues: [Int(1).databaseValue]))
            XCTAssertTrue(match(preUpdateEvent: observer.preUpdateEvents[1], kind: .insert, tableName: "items4", initialRowID: nil, finalRowID: 1, initialValues: nil, finalValues: [Int(1).databaseValue]))
        #endif
    }
}

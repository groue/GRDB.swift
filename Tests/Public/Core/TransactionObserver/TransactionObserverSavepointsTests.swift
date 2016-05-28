import XCTest
#if SQLITE_HAS_CODEC
    import GRDBCipher
#else
    import GRDB
#endif

private struct ObservedDatabaseEvent {
    let tableName: String
    let rowID: Int64
    let kind: DatabaseEvent.Kind
    
    init(rawEvent event: DatabaseEvent) {
        tableName = event.tableName
        rowID = event.rowID
        kind = event.kind
    }
}

private class TransactionObserver : TransactionObserverType {
    var lastCommittedEvents: [ObservedDatabaseEvent] = []
    var events: [ObservedDatabaseEvent] = []
    
    func databaseDidChangeWithEvent(event: DatabaseEvent) {
        events.append(ObservedDatabaseEvent(rawEvent: event))
    }
    
    func databaseWillCommit() throws {
    }
    
    func databaseDidCommit(db: Database) {
        lastCommittedEvents = events
        events = []
    }
    
    func databaseDidRollback(db: Database) {
        lastCommittedEvents = []
        events = []
    }
}

class TransactionObserverSavepointsTests: GRDBTestCase {
    
    private func match(event event: ObservedDatabaseEvent, kind: DatabaseEvent.Kind, tableName: String, rowId: Int64) -> Bool {
        return (event.tableName == tableName) && (event.rowID == rowId) && (event.kind == kind)
    }
    
    
    // MARK: - Events
    
    func testSavepointAsTransaction() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let observer = TransactionObserver()
            dbQueue.addTransactionObserver(observer)
            
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE items1 (id INTEGER PRIMARY KEY)")
                try db.execute("CREATE TABLE items2 (id INTEGER PRIMARY KEY)")
                try db.execute("SAVEPOINT sp1")
                try db.execute("INSERT INTO items1 (id) VALUES (NULL)")
                XCTAssertEqual(observer.events.count, 0)
                try db.execute("INSERT INTO items2 (id) VALUES (NULL)")
                XCTAssertEqual(observer.events.count, 0)
                try db.execute("RELEASE SAVEPOINT sp1")
                
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items1"), 1)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items2"), 1)
            }
            
            XCTAssertEqual(observer.lastCommittedEvents.count, 2)
            XCTAssertTrue(match(event: observer.lastCommittedEvents[0], kind: .Insert, tableName: "items1", rowId: 1))
            XCTAssertTrue(match(event: observer.lastCommittedEvents[1], kind: .Insert, tableName: "items2", rowId: 1))
        }
    }
    
    func testSavepointInsideTransaction() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let observer = TransactionObserver()
            dbQueue.addTransactionObserver(observer)
            
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE items1 (id INTEGER PRIMARY KEY)")
                try db.execute("CREATE TABLE items2 (id INTEGER PRIMARY KEY)")
                try db.execute("BEGIN TRANSACTION")
                try db.execute("INSERT INTO items1 (id) VALUES (NULL)")
                XCTAssertEqual(observer.events.count, 1)
                try db.execute("SAVEPOINT sp1")
                try db.execute("INSERT INTO items2 (id) VALUES (NULL)")
                XCTAssertEqual(observer.events.count, 1)
                try db.execute("COMMIT")
                
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items1"), 1)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items2"), 1)
            }
            
            XCTAssertEqual(observer.lastCommittedEvents.count, 2)
            XCTAssertTrue(match(event: observer.lastCommittedEvents[0], kind: .Insert, tableName: "items1", rowId: 1))
            XCTAssertTrue(match(event: observer.lastCommittedEvents[1], kind: .Insert, tableName: "items2", rowId: 1))
        }
    }
    
    func testRollbackNestedSavepoint() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let observer = TransactionObserver()
            dbQueue.addTransactionObserver(observer)
            
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE items1 (id INTEGER PRIMARY KEY)")
                try db.execute("CREATE TABLE items2 (id INTEGER PRIMARY KEY)")
                try db.execute("CREATE TABLE items3 (id INTEGER PRIMARY KEY)")
                try db.execute("CREATE TABLE items4 (id INTEGER PRIMARY KEY)")
                try db.execute("BEGIN TRANSACTION")
                try db.execute("INSERT INTO items1 (id) VALUES (NULL)")
                XCTAssertEqual(observer.events.count, 1)
                try db.execute("SAVEPOINT sp1")
                try db.execute("INSERT INTO items2 (id) VALUES (NULL)")
                XCTAssertEqual(observer.events.count, 1)
                try db.execute("INSERT INTO items3 (id) VALUES (NULL)")
                XCTAssertEqual(observer.events.count, 1)
                try db.execute("ROLLBACK TO SAVEPOINT sp1")
                try db.execute("INSERT INTO items4 (id) VALUES (NULL)")
                XCTAssertEqual(observer.events.count, 2)
                try db.execute("COMMIT")
                
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items1"), 1)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items2"), 0)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items3"), 0)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items4"), 1)
            }
            
            XCTAssertEqual(observer.lastCommittedEvents.count, 2)
            XCTAssertTrue(match(event: observer.lastCommittedEvents[0], kind: .Insert, tableName: "items1", rowId: 1))
            XCTAssertTrue(match(event: observer.lastCommittedEvents[1], kind: .Insert, tableName: "items4", rowId: 1))
        }
    }
    
    func testReleaseNestedSavepoint() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let observer = TransactionObserver()
            dbQueue.addTransactionObserver(observer)
            
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE items1 (id INTEGER PRIMARY KEY)")
                try db.execute("CREATE TABLE items2 (id INTEGER PRIMARY KEY)")
                try db.execute("CREATE TABLE items3 (id INTEGER PRIMARY KEY)")
                try db.execute("CREATE TABLE items4 (id INTEGER PRIMARY KEY)")
                try db.execute("BEGIN TRANSACTION")
                try db.execute("INSERT INTO items1 (id) VALUES (NULL)")
                XCTAssertEqual(observer.events.count, 1)
                try db.execute("SAVEPOINT sp1")
                try db.execute("INSERT INTO items2 (id) VALUES (NULL)")
                try db.execute("INSERT INTO items3 (id) VALUES (NULL)")
                XCTAssertEqual(observer.events.count, 1)
                try db.execute("RELEASE SAVEPOINT sp1")
                XCTAssertEqual(observer.events.count, 3)
                try db.execute("INSERT INTO items4 (id) VALUES (NULL)")
                XCTAssertEqual(observer.events.count, 4)
                try db.execute("COMMIT")
                
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items1"), 1)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items2"), 1)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items3"), 1)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items4"), 1)
            }
            
            XCTAssertEqual(observer.lastCommittedEvents.count, 4)
            XCTAssertTrue(match(event: observer.lastCommittedEvents[0], kind: .Insert, tableName: "items1", rowId: 1))
            XCTAssertTrue(match(event: observer.lastCommittedEvents[1], kind: .Insert, tableName: "items2", rowId: 1))
            XCTAssertTrue(match(event: observer.lastCommittedEvents[2], kind: .Insert, tableName: "items3", rowId: 1))
            XCTAssertTrue(match(event: observer.lastCommittedEvents[3], kind: .Insert, tableName: "items4", rowId: 1))
        }
    }
    
    func testRollbackNonNestedSavepointInsideTransaction() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let observer = TransactionObserver()
            dbQueue.addTransactionObserver(observer)
            
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE items1 (id INTEGER PRIMARY KEY)")
                try db.execute("CREATE TABLE items2 (id INTEGER PRIMARY KEY)")
                try db.execute("CREATE TABLE items3 (id INTEGER PRIMARY KEY)")
                try db.execute("CREATE TABLE items4 (id INTEGER PRIMARY KEY)")
                try db.execute("BEGIN TRANSACTION")
                try db.execute("INSERT INTO items1 (id) VALUES (NULL)")
                XCTAssertEqual(observer.events.count, 1)
                try db.execute("SAVEPOINT sp1")
                try db.execute("INSERT INTO items2 (id) VALUES (NULL)")
                XCTAssertEqual(observer.events.count, 1)
                try db.execute("SAVEPOINT sp2")
                try db.execute("INSERT INTO items3 (id) VALUES (NULL)")
                XCTAssertEqual(observer.events.count, 1)
                try db.execute("RELEASE SAVEPOINT sp2")
                XCTAssertEqual(observer.events.count, 1)
                try db.execute("ROLLBACK TO SAVEPOINT sp1")
                XCTAssertEqual(observer.events.count, 1)
                try db.execute("INSERT INTO items4 (id) VALUES (NULL)")
                XCTAssertEqual(observer.events.count, 2)
                try db.execute("COMMIT")
                
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items1"), 1)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items2"), 0)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items3"), 0)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items4"), 1)
            }
            
            XCTAssertEqual(observer.lastCommittedEvents.count, 2)
            XCTAssertTrue(match(event: observer.lastCommittedEvents[0], kind: .Insert, tableName: "items1", rowId: 1))
            XCTAssertTrue(match(event: observer.lastCommittedEvents[1], kind: .Insert, tableName: "items4", rowId: 2))
        }
    }
    
}

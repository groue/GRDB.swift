import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private class Observer : TransactionObserver {
    var lastCommittedEvents: [DatabaseEvent] = []
    var events: [DatabaseEvent] = []
    
    func databaseDidChange(with event: DatabaseEvent) {
        events.append(event.copy())
    }
    
    func databaseWillCommit() throws {
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
    
    
    // MARK: - Events
    
    func testSavepointAsTransaction() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let observer = Observer()
            dbQueue.add(transactionObserver: observer)
            
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE items1 (id INTEGER PRIMARY KEY)")
                try db.execute("CREATE TABLE items2 (id INTEGER PRIMARY KEY)")
                try db.execute("SAVEPOINT sp1")
                XCTAssertTrue(db.isInsideTransaction)
                try db.execute("INSERT INTO items1 (id) VALUES (NULL)")
                XCTAssertEqual(observer.events.count, 0)
                try db.execute("INSERT INTO items2 (id) VALUES (NULL)")
                XCTAssertEqual(observer.events.count, 0)
                try db.execute("RELEASE SAVEPOINT sp1")
                XCTAssertFalse(db.isInsideTransaction)
                
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items1"), 1)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items2"), 1)
            }
            
            XCTAssertEqual(observer.lastCommittedEvents.count, 2)
            XCTAssertTrue(match(event: observer.lastCommittedEvents[0], kind: .insert, tableName: "items1", rowId: 1))
            XCTAssertTrue(match(event: observer.lastCommittedEvents[1], kind: .insert, tableName: "items2", rowId: 1))
        }
    }
    
    func testSavepointInsideTransaction() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let observer = Observer()
            dbQueue.add(transactionObserver: observer)
            
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
            XCTAssertTrue(match(event: observer.lastCommittedEvents[0], kind: .insert, tableName: "items1", rowId: 1))
            XCTAssertTrue(match(event: observer.lastCommittedEvents[1], kind: .insert, tableName: "items2", rowId: 1))
        }
    }
    
    func testSavepointWithIdenticalName() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let observer = Observer()
            dbQueue.add(transactionObserver: observer)
            
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
                try db.execute("SAVEPOINT sp1")
                try db.execute("INSERT INTO items3 (id) VALUES (NULL)")
                XCTAssertEqual(observer.events.count, 1)
                try db.execute("RELEASE SAVEPOINT sp1")
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
            XCTAssertTrue(match(event: observer.lastCommittedEvents[0], kind: .insert, tableName: "items1", rowId: 1))
            XCTAssertTrue(match(event: observer.lastCommittedEvents[1], kind: .insert, tableName: "items2", rowId: 1))
            XCTAssertTrue(match(event: observer.lastCommittedEvents[2], kind: .insert, tableName: "items3", rowId: 1))
            XCTAssertTrue(match(event: observer.lastCommittedEvents[3], kind: .insert, tableName: "items4", rowId: 1))
        }
    }
    
    func testMultipleRollbackOfSavepoint() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let observer = Observer()
            dbQueue.add(transactionObserver: observer)
            
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
                XCTAssertEqual(observer.events.count, 1)
                try db.execute("ROLLBACK TO SAVEPOINT sp1")
                try db.execute("INSERT INTO items4 (id) VALUES (NULL)")
                XCTAssertEqual(observer.events.count, 1)
                try db.execute("COMMIT")
                
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items1"), 1)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items2"), 0)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items3"), 0)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items4"), 1)
            }
            
            XCTAssertEqual(observer.lastCommittedEvents.count, 2)
            XCTAssertTrue(match(event: observer.lastCommittedEvents[0], kind: .insert, tableName: "items1", rowId: 1))
            XCTAssertTrue(match(event: observer.lastCommittedEvents[1], kind: .insert, tableName: "items4", rowId: 1))
        }
    }
    
    func testReleaseSavepoint() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let observer = Observer()
            dbQueue.add(transactionObserver: observer)
            
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
            XCTAssertTrue(match(event: observer.lastCommittedEvents[0], kind: .insert, tableName: "items1", rowId: 1))
            XCTAssertTrue(match(event: observer.lastCommittedEvents[1], kind: .insert, tableName: "items2", rowId: 1))
            XCTAssertTrue(match(event: observer.lastCommittedEvents[2], kind: .insert, tableName: "items3", rowId: 1))
            XCTAssertTrue(match(event: observer.lastCommittedEvents[3], kind: .insert, tableName: "items4", rowId: 1))
        }
    }
    
    func testRollbackNonNestedSavepointInsideTransaction() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let observer = Observer()
            dbQueue.add(transactionObserver: observer)
            
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
                XCTAssertEqual(observer.events.count, 1)
                try db.execute("COMMIT")
                
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items1"), 1)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items2"), 0)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items3"), 0)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items4"), 1)
            }
            
            XCTAssertEqual(observer.lastCommittedEvents.count, 2)
            XCTAssertTrue(match(event: observer.lastCommittedEvents[0], kind: .insert, tableName: "items1", rowId: 1))
            XCTAssertTrue(match(event: observer.lastCommittedEvents[1], kind: .insert, tableName: "items4", rowId: 1))
        }
    }
    
}

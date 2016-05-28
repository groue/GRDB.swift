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
    
    func testSavepointAsTransactionEvent() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let observer = TransactionObserver()
            dbQueue.addTransactionObserver(observer)
            
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
                try db.execute("SAVEPOINT sp1")
                try db.execute("INSERT INTO items (id) VALUES (NULL)")
                try db.execute("INSERT INTO items (id) VALUES (NULL)")
                try db.execute("RELEASE SAVEPOINT sp1")
            }
            
            XCTAssertEqual(observer.lastCommittedEvents.count, 2)
            XCTAssertTrue(match(event: observer.lastCommittedEvents[0], kind: .Insert, tableName: "items", rowId: 1))
            XCTAssertTrue(match(event: observer.lastCommittedEvents[1], kind: .Insert, tableName: "items", rowId: 2))
        }
    }
    
}

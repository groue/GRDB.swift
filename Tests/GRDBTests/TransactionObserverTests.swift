import XCTest
@testable import GRDB

private class Observer : TransactionObserver {
    var lastCommittedEvents: [DatabaseEvent] = []
    var events: [DatabaseEvent] = []
    var commitError: Error?
    var deinitBlock: (() -> ())?
    var didCommitBlock: ((Database) -> ())?
    var observesBlock: (DatabaseEventKind) -> Bool
    
    init(observes observesBlock: @escaping (DatabaseEventKind) -> Bool = { _ in true }, didCommitBlock: ((Database) -> ())? = nil, deinitBlock: (() -> ())? = nil) {
        self.observesBlock = observesBlock
        self.didCommitBlock = didCommitBlock
        self.deinitBlock = deinitBlock
    }
    
    deinit {
        if let deinitBlock = deinitBlock {
            deinitBlock()
        }
    }
    
    var didChangeCount: Int = 0
    var willCommitCount: Int = 0
    var didCommitCount: Int = 0
    var didRollbackCount: Int = 0
    
    func resetCounts() {
        didChangeCount = 0
        willCommitCount = 0
        didCommitCount = 0
        didRollbackCount = 0
        #if SQLITE_ENABLE_PREUPDATE_HOOK
            willChangeCount = 0
        #endif
    }
    
    #if SQLITE_ENABLE_PREUPDATE_HOOK
    var willChangeCount: Int = 0
    var lastCommittedPreUpdateEvents: [DatabasePreUpdateEvent] = []
    var preUpdateEvents: [DatabasePreUpdateEvent] = []
    func databaseWillChange(with event: DatabasePreUpdateEvent) {
        willChangeCount += 1
        preUpdateEvents.append(event.copy())
    }
    #endif
    
    func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool {
        observesBlock(eventKind)
    }
    
    func databaseDidChange(with event: DatabaseEvent) {
        didChangeCount += 1
        events.append(event.copy())
    }
    
    func databaseWillCommit() throws {
        willCommitCount += 1
        if let commitError = commitError {
            throw commitError
        }
    }
    
    func databaseDidCommit(_ db: Database) {
        didCommitCount += 1
        lastCommittedEvents = events
        events = []
        #if SQLITE_ENABLE_PREUPDATE_HOOK
            lastCommittedPreUpdateEvents = preUpdateEvents
            preUpdateEvents = []
        #endif
        didCommitBlock?(db)
    }
    
    func databaseDidRollback(_ db: Database) {
        didRollbackCount += 1
        lastCommittedEvents = []
        events = []
        #if SQLITE_ENABLE_PREUPDATE_HOOK
            lastCommittedPreUpdateEvents = []
            preUpdateEvents = []
        #endif
    }
}

private final class Artist: Codable {
    var id: Int64?
    var name: String?
    
    init(id: Int64?, name: String?) {
        self.id = id
        self.name = name
    }
}

extension Artist : FetchableRecord, PersistableRecord {
    static let databaseTableName = "artists"
    func didInsert(with rowID: Int64, for column: String?) {
        self.id = rowID
    }
}

private final class Artwork : Codable {
    var id: Int64?
    var artistId: Int64?
    var title: String?
    
    init(id: Int64?, artistId: Int64?, title: String?) {
        self.id = id
        self.artistId = artistId
        self.title = title
    }
}

extension Artwork : FetchableRecord, PersistableRecord {
    static let databaseTableName = "artworks"
    func didInsert(with rowID: Int64, for column: String?) {
        self.id = rowID
    }
}

class TransactionObserverTests: GRDBTestCase {
    private func setupArtistDatabase(in dbWriter: DatabaseWriter) throws {
        try dbWriter.write { db in
            try db.execute(sql: """
            CREATE TABLE artists (
                id INTEGER PRIMARY KEY,
                name TEXT);
            CREATE TABLE artworks (
                id INTEGER PRIMARY KEY,
                artistId INTEGER NOT NULL REFERENCES artists(id) ON DELETE CASCADE ON UPDATE CASCADE,
                title TEXT)
            """)
        }
    }
    
    private func match(event: DatabaseEvent, kind: DatabaseEvent.Kind, tableName: String, rowId: Int64) -> Bool {
        (event.tableName == tableName) && (event.rowID == rowId) && (event.kind == kind)
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
    
    // MARK: - Transaction completion
    
    func testTransactionCompletions() throws {
        // implicit transaction
        try assertTransaction(start: "", end: "CREATE TABLE t(a)", isNotifiedAs: .commit)
        
        // explicit commit
        try assertTransaction(start: "BEGIN DEFERRED TRANSACTION", end: "COMMIT", isNotifiedAs: .commit)
        try assertTransaction(start: "BEGIN DEFERRED TRANSACTION; CREATE TABLE t(a)", end: "COMMIT", isNotifiedAs: .commit)
        try assertTransaction(start: "BEGIN IMMEDIATE TRANSACTION", end: "COMMIT", isNotifiedAs: .commit)
        try assertTransaction(start: "BEGIN IMMEDIATE TRANSACTION; CREATE TABLE t(a)", end: "COMMIT", isNotifiedAs: .commit)
        try assertTransaction(start: "BEGIN EXCLUSIVE TRANSACTION", end: "COMMIT", isNotifiedAs: .commit)
        try assertTransaction(start: "BEGIN EXCLUSIVE TRANSACTION; CREATE TABLE t(a)", end: "COMMIT", isNotifiedAs: .commit)
        try assertTransaction(start: "SAVEPOINT test", end: "COMMIT", isNotifiedAs: .commit)
        try assertTransaction(start: "SAVEPOINT test; CREATE TABLE t(a)", end: "COMMIT", isNotifiedAs: .commit)
        try assertTransaction(start: "SAVEPOINT test; ROLLBACK TRANSACTION TO SAVEPOINT test", end: "RELEASE SAVEPOINT test", isNotifiedAs: .commit)
        try assertTransaction(start: "SAVEPOINT test", end: "RELEASE SAVEPOINT test", isNotifiedAs: .commit)
        
        // These tests fail with SQLCipher 4, and Xcode 12 beta (both debug and release configuration)
        // TODO: is it GRDB or SQLCipher/SQLite?
        // try assertTransaction(start: "SAVEPOINT test; CREATE TABLE t(a); ROLLBACK TRANSACTION TO SAVEPOINT test", end: "RELEASE SAVEPOINT test", isNotifiedAs: .commit)
        // try assertTransaction(start: "SAVEPOINT test; CREATE TABLE t(a)", end: "RELEASE SAVEPOINT test", isNotifiedAs: .commit)
        
        // explicit rollback
        try assertTransaction(start: "BEGIN DEFERRED TRANSACTION", end: "ROLLBACK", isNotifiedAs: .rollback)
        try assertTransaction(start: "BEGIN DEFERRED TRANSACTION; CREATE TABLE t(a)", end: "ROLLBACK", isNotifiedAs: .rollback)
        try assertTransaction(start: "BEGIN IMMEDIATE TRANSACTION", end: "ROLLBACK", isNotifiedAs: .rollback)
        try assertTransaction(start: "BEGIN IMMEDIATE TRANSACTION; CREATE TABLE t(a)", end: "ROLLBACK", isNotifiedAs: .rollback)
        try assertTransaction(start: "BEGIN EXCLUSIVE TRANSACTION", end: "ROLLBACK", isNotifiedAs: .rollback)
        try assertTransaction(start: "BEGIN EXCLUSIVE TRANSACTION; CREATE TABLE t(a)", end: "ROLLBACK", isNotifiedAs: .rollback)
        try assertTransaction(start: "SAVEPOINT test", end: "ROLLBACK", isNotifiedAs: .rollback)
        try assertTransaction(start: "SAVEPOINT test; CREATE TABLE t(a)", end: "ROLLBACK", isNotifiedAs: .rollback)
    }
    
    private func assertTransaction(start startSQL: String, end endSQL: String, isNotifiedAs expectedCompletion: Database.TransactionCompletion) throws {
        try assertTransaction_registerBefore(start: startSQL, end: endSQL, isNotifiedAs: expectedCompletion)
        try assertTransaction_registerBetween(start: startSQL, end: endSQL, isNotifiedAs: expectedCompletion)
        try assertTransaction_extentDefault(start: startSQL, end: endSQL, isNotifiedAs: expectedCompletion)
        try assertTransaction_extentObserverLifetime(start: startSQL, end: endSQL, isNotifiedAs: expectedCompletion)
        try assertTransaction_extentUntilNextTransaction_weakObserver(start: startSQL, end: endSQL, isNotifiedAs: expectedCompletion)
        try assertTransaction_extentUntilNextTransaction_retainedObserver(start: startSQL, end: endSQL, isNotifiedAs: expectedCompletion)
        try assertTransaction_extentUntilNextTransaction_triggeredTransaction(start: startSQL, end: endSQL, isNotifiedAs: expectedCompletion)
        try assertTransaction_extentDatabaseLifeTime(start: startSQL, end: endSQL, isNotifiedAs: expectedCompletion)
        try assertTransaction_throwingObserver(start: startSQL, end: endSQL, isNotifiedAs: expectedCompletion)
    }
    
    private func assertTransaction_registerBefore(start startSQL: String, end endSQL: String, isNotifiedAs expectedCompletion: Database.TransactionCompletion) throws {
        let extents: [Database.TransactionObservationExtent] = [.observerLifetime, .databaseLifetime, .nextTransaction]
        for extent in extents {
            let dbQueue = try makeDatabaseQueue()
            let observer = Observer()
            dbQueue.add(transactionObserver: observer, extent: extent)
            try dbQueue.writeWithoutTransaction {  db in
                try db.execute(sql: startSQL)
                try db.execute(sql: endSQL)
            }
            switch expectedCompletion {
            case .commit:
                XCTAssertEqual(observer.willCommitCount, 1, "\(startSQL); \(endSQL)")
                XCTAssertEqual(observer.didCommitCount, 1, "\(startSQL); \(endSQL)")
                XCTAssertEqual(observer.didRollbackCount, 0, "\(startSQL); \(endSQL)")
            case .rollback:
                XCTAssertEqual(observer.willCommitCount, 0, "\(startSQL); \(endSQL)")
                XCTAssertEqual(observer.didCommitCount, 0, "\(startSQL); \(endSQL)")
                XCTAssertEqual(observer.didRollbackCount, 1, "\(startSQL); \(endSQL)")
            }
        }
    }
    
    private func assertTransaction_registerBetween(start startSQL: String, end endSQL: String, isNotifiedAs expectedCompletion: Database.TransactionCompletion) throws {
        let extents: [Database.TransactionObservationExtent] = [.observerLifetime, .databaseLifetime, .nextTransaction]
        for extent in extents {
            let dbQueue = try makeDatabaseQueue()
            let observer = Observer()
            try dbQueue.writeWithoutTransaction { db in
                try db.execute(sql: startSQL)
                db.add(transactionObserver: observer, extent: extent)
                try db.execute(sql: endSQL)
            }
            switch expectedCompletion {
            case .commit:
                XCTAssertEqual(observer.willCommitCount, 1, "\(startSQL); \(endSQL)")
                XCTAssertEqual(observer.didCommitCount, 1, "\(startSQL); \(endSQL)")
                XCTAssertEqual(observer.didRollbackCount, 0, "\(startSQL); \(endSQL)")
            case .rollback:
                XCTAssertEqual(observer.willCommitCount, 0, "\(startSQL); \(endSQL)")
                XCTAssertEqual(observer.didCommitCount, 0, "\(startSQL); \(endSQL)")
                XCTAssertEqual(observer.didRollbackCount, 1, "\(startSQL); \(endSQL)")
            }
        }
    }
    
    private func assertTransaction_extentDefault(start startSQL: String, end endSQL: String, isNotifiedAs expectedCompletion: Database.TransactionCompletion) throws {
        weak var weakObserver: Observer? = nil
        let dbQueue = try makeDatabaseQueue()
        do {
            let observer = Observer()
            weakObserver = observer
            dbQueue.add(transactionObserver: observer)
            try dbQueue.writeWithoutTransaction {  db in
                try db.execute(sql: startSQL)
                try db.execute(sql: endSQL)
            }
            switch expectedCompletion {
            case .commit:
                XCTAssertEqual(observer.willCommitCount, 1, "\(startSQL); \(endSQL)")
                XCTAssertEqual(observer.didCommitCount, 1, "\(startSQL); \(endSQL)")
                XCTAssertEqual(observer.didRollbackCount, 0, "\(startSQL); \(endSQL)")
            case .rollback:
                XCTAssertEqual(observer.willCommitCount, 0, "\(startSQL); \(endSQL)")
                XCTAssertEqual(observer.didCommitCount, 0, "\(startSQL); \(endSQL)")
                XCTAssertEqual(observer.didRollbackCount, 1, "\(startSQL); \(endSQL)")
            }
            try dbQueue.inTransaction { db in
                try db.execute(sql: "DROP TABLE IF EXISTS t; CREATE TABLE t(a)")
                return .commit
            }
            switch expectedCompletion {
            case .commit:
                XCTAssertEqual(observer.willCommitCount, 2, "\(startSQL); \(endSQL)")
                XCTAssertEqual(observer.didCommitCount, 2, "\(startSQL); \(endSQL)")
                XCTAssertEqual(observer.didRollbackCount, 0, "\(startSQL); \(endSQL)")
            case .rollback:
                XCTAssertEqual(observer.willCommitCount, 1, "\(startSQL); \(endSQL)")
                XCTAssertEqual(observer.didCommitCount, 1, "\(startSQL); \(endSQL)")
                XCTAssertEqual(observer.didRollbackCount, 1, "\(startSQL); \(endSQL)")
            }
        }
        XCTAssert(weakObserver == nil)
    }
    
    func assertTransaction_extentObserverLifetime(start startSQL: String, end endSQL: String, isNotifiedAs expectedCompletion: Database.TransactionCompletion) throws {
        weak var weakObserver: Observer? = nil
        let dbQueue = try makeDatabaseQueue()
        do {
            let observer = Observer()
            weakObserver = observer
            dbQueue.add(transactionObserver: observer, extent: .observerLifetime)
            try dbQueue.writeWithoutTransaction {  db in
                try db.execute(sql: startSQL)
                try db.execute(sql: endSQL)
            }
            switch expectedCompletion {
            case .commit:
                XCTAssertEqual(observer.willCommitCount, 1, "\(startSQL); \(endSQL)")
                XCTAssertEqual(observer.didCommitCount, 1, "\(startSQL); \(endSQL)")
                XCTAssertEqual(observer.didRollbackCount, 0, "\(startSQL); \(endSQL)")
            case .rollback:
                XCTAssertEqual(observer.willCommitCount, 0, "\(startSQL); \(endSQL)")
                XCTAssertEqual(observer.didCommitCount, 0, "\(startSQL); \(endSQL)")
                XCTAssertEqual(observer.didRollbackCount, 1, "\(startSQL); \(endSQL)")
            }
            try dbQueue.inTransaction { db in
                try db.execute(sql: "DROP TABLE IF EXISTS t; CREATE TABLE t(a)")
                return .commit
            }
            switch expectedCompletion {
            case .commit:
                XCTAssertEqual(observer.willCommitCount, 2, "\(startSQL); \(endSQL)")
                XCTAssertEqual(observer.didCommitCount, 2, "\(startSQL); \(endSQL)")
                XCTAssertEqual(observer.didRollbackCount, 0, "\(startSQL); \(endSQL)")
            case .rollback:
                XCTAssertEqual(observer.willCommitCount, 1, "\(startSQL); \(endSQL)")
                XCTAssertEqual(observer.didCommitCount, 1, "\(startSQL); \(endSQL)")
                XCTAssertEqual(observer.didRollbackCount, 1, "\(startSQL); \(endSQL)")
            }
        }
        XCTAssert(weakObserver == nil)
    }
    
    func assertTransaction_extentUntilNextTransaction_weakObserver(start startSQL: String, end endSQL: String, isNotifiedAs expectedCompletion: Database.TransactionCompletion) throws {
        weak var weakObserver: Observer? = nil
        let dbQueue = try makeDatabaseQueue()
        do {
            let observer = Observer()
            weakObserver = observer
            dbQueue.add(transactionObserver: observer, extent: .nextTransaction)
        }
        if let observer = weakObserver {
            try dbQueue.writeWithoutTransaction {  db in
                try db.execute(sql: startSQL)
                try db.execute(sql: endSQL)
            }
            switch expectedCompletion {
            case .commit:
                XCTAssertEqual(observer.willCommitCount, 1, "\(startSQL); \(endSQL)")
                XCTAssertEqual(observer.didCommitCount, 1, "\(startSQL); \(endSQL)")
                XCTAssertEqual(observer.didRollbackCount, 0, "\(startSQL); \(endSQL)")
            case .rollback:
                XCTAssertEqual(observer.willCommitCount, 0, "\(startSQL); \(endSQL)")
                XCTAssertEqual(observer.didCommitCount, 0, "\(startSQL); \(endSQL)")
                XCTAssertEqual(observer.didRollbackCount, 1, "\(startSQL); \(endSQL)")
            }
        } else {
            XCTFail("observer should not be deallocated until next transaction")
        }
        XCTAssert(weakObserver == nil)
    }
    
    func assertTransaction_extentUntilNextTransaction_retainedObserver(start startSQL: String, end endSQL: String, isNotifiedAs expectedCompletion: Database.TransactionCompletion) throws {
        let dbQueue = try makeDatabaseQueue()
        let observer = Observer()
        dbQueue.add(transactionObserver: observer, extent: .nextTransaction)
        
        try dbQueue.writeWithoutTransaction {  db in
            try db.execute(sql: startSQL)
            try db.execute(sql: endSQL)
        }
        switch expectedCompletion {
        case .commit:
            XCTAssertEqual(observer.willCommitCount, 1, "\(startSQL); \(endSQL)")
            XCTAssertEqual(observer.didCommitCount, 1, "\(startSQL); \(endSQL)")
            XCTAssertEqual(observer.didRollbackCount, 0, "\(startSQL); \(endSQL)")
        case .rollback:
            XCTAssertEqual(observer.willCommitCount, 0, "\(startSQL); \(endSQL)")
            XCTAssertEqual(observer.didCommitCount, 0, "\(startSQL); \(endSQL)")
            XCTAssertEqual(observer.didRollbackCount, 1, "\(startSQL); \(endSQL)")
        }
        try dbQueue.inTransaction { db in
            try db.execute(sql: "DROP TABLE IF EXISTS t; CREATE TABLE t(a)")
            return .commit
        }
        switch expectedCompletion {
        case .commit:
            XCTAssertEqual(observer.willCommitCount, 1, "\(startSQL); \(endSQL)")
            XCTAssertEqual(observer.didCommitCount, 1, "\(startSQL); \(endSQL)")
            XCTAssertEqual(observer.didRollbackCount, 0, "\(startSQL); \(endSQL)")
        case .rollback:
            XCTAssertEqual(observer.willCommitCount, 0, "\(startSQL); \(endSQL)")
            XCTAssertEqual(observer.didCommitCount, 0, "\(startSQL); \(endSQL)")
            XCTAssertEqual(observer.didRollbackCount, 1, "\(startSQL); \(endSQL)")
        }
    }
    
    func assertTransaction_extentUntilNextTransaction_triggeredTransaction(start startSQL: String, end endSQL: String, isNotifiedAs expectedCompletion: Database.TransactionCompletion) throws {
        let dbQueue = try makeDatabaseQueue()
        let witness = Observer()
        let observer = Observer(didCommitBlock: { db in
            try! db.inTransaction {
                try db.execute(sql: "DROP TABLE IF EXISTS t; CREATE TABLE t(a)")
                return .commit
            }
        })
        dbQueue.add(transactionObserver: witness)
        dbQueue.add(transactionObserver: observer, extent: .nextTransaction)
        
        try dbQueue.writeWithoutTransaction {  db in
            try db.execute(sql: startSQL)
            try db.execute(sql: endSQL)
        }
        switch expectedCompletion {
        case .commit:
            XCTAssertEqual(observer.willCommitCount, 1, "\(startSQL); \(endSQL)")
            XCTAssertEqual(observer.didCommitCount, 1, "\(startSQL); \(endSQL)")
            XCTAssertEqual(observer.didRollbackCount, 0, "\(startSQL); \(endSQL)")
            XCTAssertEqual(witness.willCommitCount, 2, "\(startSQL); \(endSQL)")
            XCTAssertEqual(witness.didCommitCount, 2, "\(startSQL); \(endSQL)")
            XCTAssertEqual(witness.didRollbackCount, 0, "\(startSQL); \(endSQL)")
        case .rollback:
            XCTAssertEqual(observer.willCommitCount, 0, "\(startSQL); \(endSQL)")
            XCTAssertEqual(observer.didCommitCount, 0, "\(startSQL); \(endSQL)")
            XCTAssertEqual(observer.didRollbackCount, 1, "\(startSQL); \(endSQL)")
            XCTAssertEqual(witness.willCommitCount, 0, "\(startSQL); \(endSQL)")
            XCTAssertEqual(witness.didCommitCount, 0, "\(startSQL); \(endSQL)")
            XCTAssertEqual(witness.didRollbackCount, 1, "\(startSQL); \(endSQL)")
        }

        try dbQueue.inTransaction { db in
            try db.execute(sql: "DROP TABLE IF EXISTS t; CREATE TABLE t(a)")
            return .commit
        }
        switch expectedCompletion {
        case .commit:
            XCTAssertEqual(observer.willCommitCount, 1, "\(startSQL); \(endSQL)")
            XCTAssertEqual(observer.didCommitCount, 1, "\(startSQL); \(endSQL)")
            XCTAssertEqual(observer.didRollbackCount, 0, "\(startSQL); \(endSQL)")
            XCTAssertEqual(witness.willCommitCount, 3, "\(startSQL); \(endSQL)")
            XCTAssertEqual(witness.didCommitCount, 3, "\(startSQL); \(endSQL)")
            XCTAssertEqual(witness.didRollbackCount, 0, "\(startSQL); \(endSQL)")
        case .rollback:
            XCTAssertEqual(observer.willCommitCount, 0, "\(startSQL); \(endSQL)")
            XCTAssertEqual(observer.didCommitCount, 0, "\(startSQL); \(endSQL)")
            XCTAssertEqual(observer.didRollbackCount, 1, "\(startSQL); \(endSQL)")
            XCTAssertEqual(witness.willCommitCount, 1, "\(startSQL); \(endSQL)")
            XCTAssertEqual(witness.didCommitCount, 1, "\(startSQL); \(endSQL)")
            XCTAssertEqual(witness.didRollbackCount, 1, "\(startSQL); \(endSQL)")
        }
    }
    
    func assertTransaction_extentDatabaseLifeTime(start startSQL: String, end endSQL: String, isNotifiedAs expectedCompletion: Database.TransactionCompletion) throws {
        // Observer deallocation happens concurrently with database deallocation:
        //
        // 1. DatabaseQueue.deinit (main queue)
        // 2. SerializedDatabase.deinit (main queue)
        // 3. DispatchQueue.deinit (main queue)
        // 4. SchedulingWatchDog.deinit (database queue)
        // 5. Database.deinit (database queue)
        // 6. Observer.deinit (database queue)
        let deinitSemaphore = DispatchSemaphore(value: 0)
        
        do {
            let dbQueue = try makeDatabaseQueue()
            weak var weakObserver: Observer? = nil
            do {
                let observer = Observer(deinitBlock: {
                    deinitSemaphore.signal()
                })
                weakObserver = observer
                dbQueue.add(transactionObserver: observer, extent: .databaseLifetime)
            }
            
            if let observer = weakObserver {
                try dbQueue.writeWithoutTransaction {  db in
                    try db.execute(sql: startSQL)
                    try db.execute(sql: endSQL)
                }
                switch expectedCompletion {
                case .commit:
                    XCTAssertEqual(observer.willCommitCount, 1, "\(startSQL); \(endSQL)")
                    XCTAssertEqual(observer.didCommitCount, 1, "\(startSQL); \(endSQL)")
                    XCTAssertEqual(observer.didRollbackCount, 0, "\(startSQL); \(endSQL)")
                case .rollback:
                    XCTAssertEqual(observer.willCommitCount, 0, "\(startSQL); \(endSQL)")
                    XCTAssertEqual(observer.didCommitCount, 0, "\(startSQL); \(endSQL)")
                    XCTAssertEqual(observer.didRollbackCount, 1, "\(startSQL); \(endSQL)")
                }
            } else {
                XCTFail("observer should not be deallocated until database is closed")
            }
            
            if let observer = weakObserver {
                try dbQueue.inTransaction { db in
                    try db.execute(sql: "DROP TABLE IF EXISTS t; CREATE TABLE t(a)")
                    return .commit
                }
                switch expectedCompletion {
                case .commit:
                    XCTAssertEqual(observer.willCommitCount, 2, "\(startSQL); \(endSQL)")
                    XCTAssertEqual(observer.didCommitCount, 2, "\(startSQL); \(endSQL)")
                    XCTAssertEqual(observer.didRollbackCount, 0, "\(startSQL); \(endSQL)")
                case .rollback:
                    XCTAssertEqual(observer.willCommitCount, 1, "\(startSQL); \(endSQL)")
                    XCTAssertEqual(observer.didCommitCount, 1, "\(startSQL); \(endSQL)")
                    XCTAssertEqual(observer.didRollbackCount, 1, "\(startSQL); \(endSQL)")
                }
            } else {
                XCTFail("observer should not be deallocated until database is closed")
            }
        } // <- DatabaseQueue.deinit ... Observer.deinit
        
        // Wait for observer deallocation
        switch deinitSemaphore.wait(timeout: .now() + .seconds(60)) {
        case .success:
            break
        case .timedOut:
            XCTFail("Observer not deallocated")
        }
    }
    
    func assertTransaction_throwingObserver(start startSQL: String, end endSQL: String, isNotifiedAs expectedCompletion: Database.TransactionCompletion) throws {
        let extents: [Database.TransactionObservationExtent] = [.observerLifetime, .databaseLifetime, .nextTransaction]
        for extent in extents {
            let dbQueue = try makeDatabaseQueue()
            let observer1 = Observer()
            let observer2 = Observer()
            let observer3 = Observer()
            struct TestError : Error { }
            observer2.commitError = TestError()
            
            dbQueue.add(transactionObserver: observer1, extent: extent)
            dbQueue.add(transactionObserver: observer2, extent: extent)
            dbQueue.add(transactionObserver: observer3, extent: extent)
            
            do {
                try dbQueue.writeWithoutTransaction {  db in
                    try db.execute(sql: startSQL)
                    try db.execute(sql: endSQL)
                }
                switch expectedCompletion {
                case .commit:
                    XCTFail("Expected Error")
                case .rollback:
                    XCTAssertEqual(observer1.willCommitCount, 0, "\(startSQL); \(endSQL)")
                    XCTAssertEqual(observer1.didCommitCount, 0, "\(startSQL); \(endSQL)")
                    XCTAssertEqual(observer1.didRollbackCount, 1, "\(startSQL); \(endSQL)")
                    
                    XCTAssertEqual(observer2.willCommitCount, 0, "\(startSQL); \(endSQL)")
                    XCTAssertEqual(observer2.didCommitCount, 0, "\(startSQL); \(endSQL)")
                    XCTAssertEqual(observer2.didRollbackCount, 1, "\(startSQL); \(endSQL)")
                    
                    XCTAssertEqual(observer3.willCommitCount, 0, "\(startSQL); \(endSQL)")
                    XCTAssertEqual(observer3.didCommitCount, 0, "\(startSQL); \(endSQL)")
                    XCTAssertEqual(observer3.didRollbackCount, 1, "\(startSQL); \(endSQL)")
                }
            } catch let error as TestError {
                switch expectedCompletion {
                case .commit:
                    XCTAssertEqual(observer1.willCommitCount, 1)
                    XCTAssertEqual(observer1.didCommitCount, 0)
                    XCTAssertEqual(observer1.didRollbackCount, 1)
                    
                    XCTAssertEqual(observer2.willCommitCount, 1)
                    XCTAssertEqual(observer2.didCommitCount, 0)
                    XCTAssertEqual(observer2.didRollbackCount, 1)
                    
                    XCTAssertEqual(observer3.willCommitCount, 0)
                    XCTAssertEqual(observer3.didCommitCount, 0)
                    XCTAssertEqual(observer3.didRollbackCount, 1)
                case .rollback:
                    throw error
                }
            }
        }
    }
    
    // MARK: - Events
    
    func testInsertEvent() throws {
        let dbQueue = try makeDatabaseQueue()
        try setupArtistDatabase(in: dbQueue)
        let observer = Observer()
        dbQueue.add(transactionObserver: observer)
        
        try dbQueue.writeWithoutTransaction { db in
            let artist = Artist(id: nil, name: "Gerhard Richter")
            
            //
            try artist.save(db)
            XCTAssertEqual(observer.lastCommittedEvents.count, 1)
            let event = observer.lastCommittedEvents.filter { event in
                self.match(event: event, kind: .insert, tableName: "artists", rowId: artist.id!)
                }.first
            XCTAssertTrue(event != nil)
            
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.lastCommittedPreUpdateEvents.count, 1)
                let preUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                    self.match(preUpdateEvent: event, kind: .insert, tableName: "artists", initialRowID: nil, finalRowID: artist.id!, initialValues: nil,
                               finalValues: [
                                artist.id!.databaseValue,
                                artist.name!.databaseValue
                        ])
                    }.first
                XCTAssertTrue(preUpdateEvent != nil)
            #endif
        }
    }

    func testInsertEventWithCursor() throws {
        let dbQueue = try makeDatabaseQueue()
        try setupArtistDatabase(in: dbQueue)
        let observer = Observer()
        dbQueue.add(transactionObserver: observer)
        
        try dbQueue.writeWithoutTransaction { db in
            let insertedName = "Gerhard Richter"
            let statement = try db.makeStatement(literal: "INSERT INTO artists (name) VALUES (\(insertedName))")
            _ = try Row.fetchCursor(statement).next()
            let insertedId = db.lastInsertedRowID
            
            XCTAssertEqual(observer.lastCommittedEvents.count, 1)
            let event = observer.lastCommittedEvents.filter { event in
                self.match(event: event, kind: .insert, tableName: "artists", rowId: insertedId)
            }.first
            XCTAssertTrue(event != nil)
            
            #if SQLITE_ENABLE_PREUPDATE_HOOK
            XCTAssertEqual(observer.lastCommittedPreUpdateEvents.count, 1)
            let preUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                self.match(preUpdateEvent: event, kind: .insert, tableName: "artists", initialRowID: nil, finalRowID: insertedId, initialValues: nil,
                           finalValues: [
                            insertedId.databaseValue,
                            insertedName.databaseValue
                           ])
            }.first
            XCTAssertTrue(preUpdateEvent != nil)
            #endif
        }
    }
    
    func testUpdateEvent() throws {
        let dbQueue = try makeDatabaseQueue()
        try setupArtistDatabase(in: dbQueue)
        let observer = Observer()
        dbQueue.add(transactionObserver: observer)
        
        try dbQueue.writeWithoutTransaction { db in
            let artist = Artist(id: nil, name: "Gerhard Richter")
            try artist.save(db)
            artist.name = "Vincent Fournier"
            
            //
            try artist.save(db)
            XCTAssertEqual(observer.lastCommittedEvents.count, 1)
            let event = observer.lastCommittedEvents.filter {
                self.match(event: $0, kind: .update, tableName: "artists", rowId: artist.id!)
                }.first
            XCTAssertTrue(event != nil)
            
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.lastCommittedPreUpdateEvents.count, 1)
                let preUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                    self.match(preUpdateEvent: event, kind: .update, tableName: "artists", initialRowID: artist.id!, finalRowID: artist.id!,
                               initialValues: [
                                artist.id!.databaseValue,
                                "Gerhard Richter".databaseValue
                        ], finalValues: [
                            artist.id!.databaseValue,
                            "Vincent Fournier".databaseValue
                        ])
                    }.first
                XCTAssertTrue(preUpdateEvent != nil)
            #endif
        }
    }

    func testDeleteEvent() throws {
        let dbQueue = try makeDatabaseQueue()
        try setupArtistDatabase(in: dbQueue)
        let observer = Observer()
        dbQueue.add(transactionObserver: observer)
        
        try dbQueue.writeWithoutTransaction { db in
            let artist = Artist(id: nil, name: "Gerhard Richter")
            try artist.save(db)
            
            //
            try artist.delete(db)
            XCTAssertEqual(observer.lastCommittedEvents.count, 1)
            let event = observer.lastCommittedEvents.filter {
                self.match(event: $0, kind: .delete, tableName: "artists", rowId: artist.id!)
                }.first
            XCTAssertTrue(event != nil)
            
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.lastCommittedPreUpdateEvents.count, 1)
                let preUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                    self.match(preUpdateEvent: event, kind: .delete, tableName: "artists", initialRowID: artist.id!, finalRowID: nil,
                               initialValues: [
                                artist.id!.databaseValue,
                                artist.name!.databaseValue
                        ], finalValues: nil)
                    }.first
                XCTAssertTrue(preUpdateEvent != nil)
            #endif
        }
    }

    func testCascadingDeleteEvents() throws {
        let dbQueue = try makeDatabaseQueue()
        try setupArtistDatabase(in: dbQueue)
        let observer = Observer()
        dbQueue.add(transactionObserver: observer)
        
        try dbQueue.writeWithoutTransaction { db in
            let artist = Artist(id: nil, name: "Gerhard Richter")
            try artist.save(db)
            let artwork1 = Artwork(id: nil, artistId: artist.id, title: "Cloud")
            try artwork1.save(db)
            let artwork2 = Artwork(id: nil, artistId: artist.id, title: "Ema (Nude on a Staircase)")
            try artwork2.save(db)
            
            //
            try artist.delete(db)
            XCTAssertEqual(observer.lastCommittedEvents.count, 3)
            let artistEvent = observer.lastCommittedEvents.filter {
                self.match(event: $0, kind: .delete, tableName: "artists", rowId: artist.id!)
                }.first
            XCTAssertTrue(artistEvent != nil)
            let artwork1Event = observer.lastCommittedEvents.filter {
                self.match(event: $0, kind: .delete, tableName: "artworks", rowId: artwork1.id!)
                }.first
            XCTAssertTrue(artwork1Event != nil)
            let artwork2Event = observer.lastCommittedEvents.filter {
                self.match(event: $0, kind: .delete, tableName: "artworks", rowId: artwork2.id!)
                }.first
            XCTAssertTrue(artwork2Event != nil)
            
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.lastCommittedPreUpdateEvents.count, 3)
                let artistPreUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                    self.match(preUpdateEvent: event, kind: .delete, tableName: "artists", initialRowID: artist.id!, finalRowID: nil,
                               initialValues: [
                                artist.id!.databaseValue,
                                artist.name!.databaseValue
                        ], finalValues: nil)
                    }.first
                XCTAssertTrue(artistPreUpdateEvent != nil)
                let artwork1PreUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                    self.match(preUpdateEvent: event, kind: .delete, tableName: "artworks", initialRowID: artwork1.id!, finalRowID: nil,
                               initialValues: [
                                artwork1.id!.databaseValue,
                                artwork1.artistId!.databaseValue,
                                artwork1.title!.databaseValue
                        ], finalValues: nil, depth: 1)
                    }.first
                XCTAssertTrue(artwork1PreUpdateEvent != nil)
                let artwork2PreUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                    self.match(preUpdateEvent: event, kind: .delete, tableName: "artworks", initialRowID: artwork2.id!, finalRowID: nil,
                               initialValues: [
                                artwork2.id!.databaseValue,
                                artwork2.artistId!.databaseValue,
                                artwork2.title!.databaseValue
                        ], finalValues: nil, depth: 1)
                    }.first
                XCTAssertTrue(artwork2PreUpdateEvent != nil)
            #endif
        }
    }


    // MARK: - Commits & Rollback

    func testImplicitTransactionCommit() throws {
        let dbQueue = try makeDatabaseQueue()
        try setupArtistDatabase(in: dbQueue)
        let observer = Observer()
        dbQueue.add(transactionObserver: observer)
        
        let artist = Artist(id: nil, name: "Gerhard Richter")
        
        try dbQueue.writeWithoutTransaction { db in
            observer.resetCounts()
            try artist.save(db)
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.willChangeCount, 1)
            #endif
            XCTAssertEqual(observer.didChangeCount, 1)
            XCTAssertEqual(observer.willCommitCount, 1)
            XCTAssertEqual(observer.didCommitCount, 1)
            XCTAssertEqual(observer.didRollbackCount, 0)
        }
    }

    func testCascadeWithImplicitTransactionCommit() throws {
        let dbQueue = try makeDatabaseQueue()
        try setupArtistDatabase(in: dbQueue)
        let observer = Observer()
        dbQueue.add(transactionObserver: observer)
        
        let artist = Artist(id: nil, name: "Gerhard Richter")
        let artwork1 = Artwork(id: nil, artistId: nil, title: "Cloud")
        let artwork2 = Artwork(id: nil, artistId: nil, title: "Ema (Nude on a Staircase)")
        
        try dbQueue.writeWithoutTransaction { db in
            try artist.save(db)
            artwork1.artistId = artist.id
            artwork2.artistId = artist.id
            try artwork1.save(db)
            try artwork2.save(db)
            
            //
            observer.resetCounts()
            try artist.delete(db)
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.willChangeCount, 3) // 3 deletes
            #endif
            XCTAssertEqual(observer.didChangeCount, 3) // 3 deletes
            XCTAssertEqual(observer.willCommitCount, 1)
            XCTAssertEqual(observer.didCommitCount, 1)
            XCTAssertEqual(observer.didRollbackCount, 0)
            
            let artistDeleteEvent = observer.lastCommittedEvents.filter {
                self.match(event: $0, kind: .delete, tableName: "artists", rowId: artist.id!)
                }.first
            XCTAssertTrue(artistDeleteEvent != nil)
            
            let artwork1DeleteEvent = observer.lastCommittedEvents.filter {
                self.match(event: $0, kind: .delete, tableName: "artworks", rowId: artwork1.id!)
                }.first
            XCTAssertTrue(artwork1DeleteEvent != nil)
            
            let artwork2DeleteEvent = observer.lastCommittedEvents.filter {
                self.match(event: $0, kind: .delete, tableName: "artworks", rowId: artwork2.id!)
                }.first
            XCTAssertTrue(artwork2DeleteEvent != nil)
            
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.lastCommittedPreUpdateEvents.count, 3)
                let artistPreUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                    self.match(preUpdateEvent: event, kind: .delete, tableName: "artists", initialRowID: artist.id!, finalRowID: nil,
                               initialValues: [
                                artist.id!.databaseValue,
                                artist.name!.databaseValue
                        ], finalValues: nil)
                    }.first
                XCTAssertTrue(artistPreUpdateEvent != nil)
                let artwork1PreUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                    self.match(preUpdateEvent: event, kind: .delete, tableName: "artworks", initialRowID: artwork1.id!, finalRowID: nil,
                               initialValues: [
                                artwork1.id!.databaseValue,
                                artwork1.artistId!.databaseValue,
                                artwork1.title!.databaseValue
                        ], finalValues: nil, depth: 1)
                    }.first
                XCTAssertTrue(artwork1PreUpdateEvent != nil)
                let artwork2PreUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                    self.match(preUpdateEvent: event, kind: .delete, tableName: "artworks", initialRowID: artwork2.id!, finalRowID: nil,
                               initialValues: [
                                artwork2.id!.databaseValue,
                                artwork2.artistId!.databaseValue,
                                artwork2.title!.databaseValue
                        ], finalValues: nil, depth: 1)
                    }.first
                XCTAssertTrue(artwork2PreUpdateEvent != nil)
            #endif
        }
    }

    func testExplicitTransactionCommit() throws {
        let dbQueue = try makeDatabaseQueue()
        try setupArtistDatabase(in: dbQueue)
        let observer = Observer()
        dbQueue.add(transactionObserver: observer)
        
        let artist = Artist(id: nil, name: "Gerhard Richter")
        let artwork1 = Artwork(id: nil, artistId: nil, title: "Cloud")
        let artwork2 = Artwork(id: nil, artistId: nil, title: "Ema (Nude on a Staircase)")
        
        try dbQueue.inTransaction { db in
            observer.resetCounts()
            try artist.save(db)
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.willChangeCount, 1)
            #endif
            XCTAssertEqual(observer.didChangeCount, 1)
            XCTAssertEqual(observer.willCommitCount, 0)
            XCTAssertEqual(observer.didCommitCount, 0)
            XCTAssertEqual(observer.didRollbackCount, 0)
            
            artwork1.artistId = artist.id
            artwork2.artistId = artist.id
            
            observer.resetCounts()
            try artwork1.save(db)
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.willChangeCount, 1)
            #endif
            XCTAssertEqual(observer.didChangeCount, 1)
            XCTAssertEqual(observer.willCommitCount, 0)
            XCTAssertEqual(observer.didCommitCount, 0)
            XCTAssertEqual(observer.didRollbackCount, 0)
            
            observer.resetCounts()
            try artwork2.save(db)
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.willChangeCount, 1)
            #endif
            XCTAssertEqual(observer.didChangeCount, 1)
            XCTAssertEqual(observer.willCommitCount, 0)
            XCTAssertEqual(observer.didCommitCount, 0)
            XCTAssertEqual(observer.didRollbackCount, 0)
            
            observer.resetCounts()
            return .commit
        }
        #if SQLITE_ENABLE_PREUPDATE_HOOK
            XCTAssertEqual(observer.willChangeCount, 0)
        #endif
        XCTAssertEqual(observer.didChangeCount, 0)
        XCTAssertEqual(observer.willCommitCount, 1)
        XCTAssertEqual(observer.didCommitCount, 1)
        XCTAssertEqual(observer.didRollbackCount, 0)
        XCTAssertEqual(observer.lastCommittedEvents.count, 3)
        
        let artistEvent = observer.lastCommittedEvents.filter {
            self.match(event: $0, kind: .insert, tableName: "artists", rowId: artist.id!)
            }.first
        XCTAssertTrue(artistEvent != nil)
        
        let artwork1Event = observer.lastCommittedEvents.filter {
            self.match(event: $0, kind: .insert, tableName: "artworks", rowId: artwork1.id!)
            }.first
        XCTAssertTrue(artwork1Event != nil)
        
        let artwork2Event = observer.lastCommittedEvents.filter {
            self.match(event: $0, kind: .insert, tableName: "artworks", rowId: artwork2.id!)
            }.first
        XCTAssertTrue(artwork2Event != nil)
        
        #if SQLITE_ENABLE_PREUPDATE_HOOK
            XCTAssertEqual(observer.lastCommittedPreUpdateEvents.count, 3)
            let artistPreUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                self.match(preUpdateEvent: event, kind: .insert, tableName: "artists", initialRowID: nil, finalRowID: artist.id!,
                           initialValues: nil, finalValues: [
                            artist.id!.databaseValue,
                            artist.name!.databaseValue
                    ])
                }.first
            XCTAssertTrue(artistPreUpdateEvent != nil)
            let artwork1PreUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                self.match(preUpdateEvent: event, kind: .insert, tableName: "artworks", initialRowID: nil, finalRowID: artwork1.id!,
                           initialValues: nil, finalValues: [
                            artwork1.id!.databaseValue,
                            artwork1.artistId!.databaseValue,
                            artwork1.title!.databaseValue
                    ])
                }.first
            XCTAssertTrue(artwork1PreUpdateEvent != nil)
            let artwork2PreUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                self.match(preUpdateEvent: event, kind: .insert, tableName: "artworks", initialRowID: nil, finalRowID: artwork2.id!,
                           initialValues: nil, finalValues: [
                            artwork2.id!.databaseValue,
                            artwork2.artistId!.databaseValue,
                            artwork2.title!.databaseValue
                    ])
                }.first
            XCTAssertTrue(artwork2PreUpdateEvent != nil)
        #endif
    }

    func testCascadeWithExplicitTransactionCommit() throws {
        let dbQueue = try makeDatabaseQueue()
        try setupArtistDatabase(in: dbQueue)
        let observer = Observer()
        dbQueue.add(transactionObserver: observer)
        
        let artist = Artist(id: nil, name: "Gerhard Richter")
        let artwork1 = Artwork(id: nil, artistId: nil, title: "Cloud")
        let artwork2 = Artwork(id: nil, artistId: nil, title: "Ema (Nude on a Staircase)")
        
        try dbQueue.inTransaction { db in
            try artist.save(db)
            artwork1.artistId = artist.id
            artwork2.artistId = artist.id
            try artwork1.save(db)
            try artwork2.save(db)
            
            //
            observer.resetCounts()
            try artist.delete(db)
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.willChangeCount, 3) // 3 deletes
            #endif
            XCTAssertEqual(observer.didChangeCount, 3) // 3 deletes
            XCTAssertEqual(observer.willCommitCount, 0)
            XCTAssertEqual(observer.didCommitCount, 0)
            XCTAssertEqual(observer.didRollbackCount, 0)
            
            observer.resetCounts()
            return .commit
        }
        #if SQLITE_ENABLE_PREUPDATE_HOOK
            XCTAssertEqual(observer.willChangeCount, 0)
        #endif
        XCTAssertEqual(observer.didChangeCount, 0)
        XCTAssertEqual(observer.willCommitCount, 1)
        XCTAssertEqual(observer.didCommitCount, 1)
        XCTAssertEqual(observer.didRollbackCount, 0)
        XCTAssertEqual(observer.lastCommittedEvents.count, 6)  // 3 inserts, and 3 deletes
        
        let artistInsertEvent = observer.lastCommittedEvents.filter {
            self.match(event: $0, kind: .insert, tableName: "artists", rowId: artist.id!)
            }.first
        XCTAssertTrue(artistInsertEvent != nil)
        
        let artwork1InsertEvent = observer.lastCommittedEvents.filter {
            self.match(event: $0, kind: .insert, tableName: "artworks", rowId: artwork1.id!)
            }.first
        XCTAssertTrue(artwork1InsertEvent != nil)
        
        let artwork2InsertEvent = observer.lastCommittedEvents.filter {
            self.match(event: $0, kind: .insert, tableName: "artworks", rowId: artwork2.id!)
            }.first
        XCTAssertTrue(artwork2InsertEvent != nil)
        
        let artistDeleteEvent = observer.lastCommittedEvents.filter {
            self.match(event: $0, kind: .delete, tableName: "artists", rowId: artist.id!)
            }.first
        XCTAssertTrue(artistDeleteEvent != nil)
        
        let artwork1DeleteEvent = observer.lastCommittedEvents.filter {
            self.match(event: $0, kind: .delete, tableName: "artworks", rowId: artwork1.id!)
            }.first
        XCTAssertTrue(artwork1DeleteEvent != nil)
        
        let artwork2DeleteEvent = observer.lastCommittedEvents.filter {
            self.match(event: $0, kind: .delete, tableName: "artworks", rowId: artwork2.id!)
            }.first
        XCTAssertTrue(artwork2DeleteEvent != nil)
        
        
        #if SQLITE_ENABLE_PREUPDATE_HOOK
            XCTAssertEqual(observer.lastCommittedPreUpdateEvents.count, 6)  // 3 inserts, and 3 deletes
            let artistInsertPreUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                self.match(preUpdateEvent: event, kind: .insert, tableName: "artists", initialRowID: nil, finalRowID: artist.id!,
                           initialValues: nil, finalValues: [
                            artist.id!.databaseValue,
                            artist.name!.databaseValue
                    ])
                }.first
            XCTAssertTrue(artistInsertPreUpdateEvent != nil)
            let artwork1InsertPreUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                self.match(preUpdateEvent: event, kind: .insert, tableName: "artworks", initialRowID: nil, finalRowID: artwork1.id!,
                           initialValues: nil, finalValues: [
                            artwork1.id!.databaseValue,
                            artwork1.artistId!.databaseValue,
                            artwork1.title!.databaseValue
                    ])
                }.first
            XCTAssertTrue(artwork1InsertPreUpdateEvent != nil)
            let artwork2InsertPreUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                self.match(preUpdateEvent: event, kind: .insert, tableName: "artworks", initialRowID: nil, finalRowID: artwork2.id!,
                           initialValues: nil, finalValues: [
                            artwork2.id!.databaseValue,
                            artwork2.artistId!.databaseValue,
                            artwork2.title!.databaseValue
                    ])
                }.first
            XCTAssertTrue(artwork2InsertPreUpdateEvent != nil)
            
            let artistDeletePreUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                self.match(preUpdateEvent: event, kind: .delete, tableName: "artists", initialRowID: artist.id!, finalRowID: nil,
                           initialValues: [
                            artist.id!.databaseValue,
                            artist.name!.databaseValue
                    ], finalValues: nil)
                }.first
            XCTAssertTrue(artistDeletePreUpdateEvent != nil)
            let artwork1DeletePreUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                self.match(preUpdateEvent: event, kind: .delete, tableName: "artworks", initialRowID: artwork1.id!, finalRowID: nil,
                           initialValues: [
                            artwork1.id!.databaseValue,
                            artwork1.artistId!.databaseValue,
                            artwork1.title!.databaseValue
                    ], finalValues: nil, depth: 1)
                }.first
            XCTAssertTrue(artwork1DeletePreUpdateEvent != nil)
            let artwork2DeletePreUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                self.match(preUpdateEvent: event, kind: .delete, tableName: "artworks", initialRowID: artwork2.id!, finalRowID: nil,
                           initialValues: [
                            artwork2.id!.databaseValue,
                            artwork2.artistId!.databaseValue,
                            artwork2.title!.databaseValue
                    ], finalValues: nil, depth: 1)
                }.first
            XCTAssertTrue(artwork2DeletePreUpdateEvent != nil)
        #endif
    }

    func testExplicitTransactionRollback() throws {
        let dbQueue = try makeDatabaseQueue()
        try setupArtistDatabase(in: dbQueue)
        let observer = Observer()
        dbQueue.add(transactionObserver: observer)
        
        let artist = Artist(id: nil, name: "Gerhard Richter")
        let artwork1 = Artwork(id: nil, artistId: nil, title: "Cloud")
        let artwork2 = Artwork(id: nil, artistId: nil, title: "Ema (Nude on a Staircase)")
        
        try dbQueue.inTransaction { db in
            try artist.save(db)
            artwork1.artistId = artist.id
            artwork2.artistId = artist.id
            try artwork1.save(db)
            try artwork2.save(db)
            
            observer.resetCounts()
            return .rollback
        }
        #if SQLITE_ENABLE_PREUPDATE_HOOK
            XCTAssertEqual(observer.willChangeCount, 0)
        #endif
        XCTAssertEqual(observer.didChangeCount, 0)
        XCTAssertEqual(observer.willCommitCount, 0)
        XCTAssertEqual(observer.didCommitCount, 0)
        XCTAssertEqual(observer.didRollbackCount, 1)
    }

    func testImplicitTransactionRollbackCausedByDatabaseError() throws {
        let dbQueue = try makeDatabaseQueue()
        try setupArtistDatabase(in: dbQueue)
        let observer = Observer()
        dbQueue.add(transactionObserver: observer)
        
        do {
            try dbQueue.writeWithoutTransaction { db in
                do {
                    try Artwork(id: nil, artistId: nil, title: "meh").save(db)
                    XCTFail("Expected Error")
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
                    #if SQLITE_ENABLE_PREUPDATE_HOOK
                        XCTAssertEqual(observer.willChangeCount, 0)
                    #endif
                    XCTAssertEqual(observer.didChangeCount, 0)
                    XCTAssertEqual(observer.willCommitCount, 0)
                    XCTAssertEqual(observer.didCommitCount, 0)
                    XCTAssertEqual(observer.didRollbackCount, 0)
                    throw error
                }
            }
            XCTFail("Expected Error")
        } catch let error as DatabaseError {
            XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.willChangeCount, 0)
            #endif
            XCTAssertEqual(observer.didChangeCount, 0)
            XCTAssertEqual(observer.willCommitCount, 0)
            XCTAssertEqual(observer.didCommitCount, 0)
            XCTAssertEqual(observer.didRollbackCount, 0)
        }
    }

    func testExplicitTransactionRollbackCausedByDatabaseError() throws {
        let dbQueue = try makeDatabaseQueue()
        try setupArtistDatabase(in: dbQueue)
        let observer = Observer()
        dbQueue.add(transactionObserver: observer)
        
        do {
            try dbQueue.inTransaction { db in
                do {
                    try Artwork(id: nil, artistId: nil, title: "meh").save(db)
                    XCTFail("Expected Error")
                } catch let error as DatabaseError {
                    // Immediate constraint check has failed.
                    XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
                    #if SQLITE_ENABLE_PREUPDATE_HOOK
                        XCTAssertEqual(observer.willChangeCount, 0)
                    #endif
                    XCTAssertEqual(observer.didChangeCount, 0)
                    XCTAssertEqual(observer.willCommitCount, 0)
                    XCTAssertEqual(observer.didCommitCount, 0)
                    XCTAssertEqual(observer.didRollbackCount, 0)
                    throw error
                }
                return .commit
            }
            XCTFail("Expected Error")
        } catch let error as DatabaseError {
            XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.willChangeCount, 0)
            #endif
            XCTAssertEqual(observer.didChangeCount, 0)
            XCTAssertEqual(observer.willCommitCount, 0)
            XCTAssertEqual(observer.didCommitCount, 0)
            XCTAssertEqual(observer.didRollbackCount, 1)
        }
    }

    func testImplicitTransactionRollbackCausedByTransactionObserver() throws {
        let dbQueue = try makeDatabaseQueue()
        try setupArtistDatabase(in: dbQueue)
        let observer = Observer()
        dbQueue.add(transactionObserver: observer)
        
        observer.commitError = NSError(domain: "foo", code: 0, userInfo: nil)
        dbQueue.writeWithoutTransaction { db in
            do {
                try Artist(id: nil, name: "Gerhard Richter").save(db)
                XCTFail("Expected Error")
            } catch let error as NSError {
                XCTAssertEqual(error.domain, "foo")
                XCTAssertEqual(error.code, 0)
                #if SQLITE_ENABLE_PREUPDATE_HOOK
                    XCTAssertEqual(observer.willChangeCount, 1)
                #endif
                XCTAssertEqual(observer.didChangeCount, 1)
                XCTAssertEqual(observer.willCommitCount, 1)
                XCTAssertEqual(observer.didCommitCount, 0)
                XCTAssertEqual(observer.didRollbackCount, 1)
            }
        }
    }

    func testExplicitTransactionRollbackCausedByTransactionObserver() throws {
        let dbQueue = try makeDatabaseQueue()
        try setupArtistDatabase(in: dbQueue)
        let observer = Observer()
        observer.commitError = NSError(domain: "foo", code: 0, userInfo: nil)
        dbQueue.add(transactionObserver: observer)
        
        do {
            try dbQueue.inTransaction { db in
                do {
                    try Artist(id: nil, name: "Gerhard Richter").save(db)
                } catch {
                    XCTFail("Unexpected Error")
                }
                return .commit
            }
            XCTFail("Expected Error")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, "foo")
            XCTAssertEqual(error.code, 0)
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.willChangeCount, 1)
            #endif
            XCTAssertEqual(observer.didChangeCount, 1)
            XCTAssertEqual(observer.willCommitCount, 1)
            XCTAssertEqual(observer.didCommitCount, 0)
            XCTAssertEqual(observer.didRollbackCount, 1)
        }
    }

    func testImplicitTransactionRollbackCausedByDatabaseErrorSuperseedTransactionObserver() throws {
        let dbQueue = try makeDatabaseQueue()
        try setupArtistDatabase(in: dbQueue)
        let observer = Observer()
        observer.commitError = NSError(domain: "foo", code: 0, userInfo: nil)
        dbQueue.add(transactionObserver: observer)
        
        do {
            try dbQueue.writeWithoutTransaction { db in
                do {
                    try Artwork(id: nil, artistId: nil, title: "meh").save(db)
                    XCTFail("Expected Error")
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
                    #if SQLITE_ENABLE_PREUPDATE_HOOK
                        XCTAssertEqual(observer.willChangeCount, 0)
                    #endif
                    XCTAssertEqual(observer.didChangeCount, 0)
                    XCTAssertEqual(observer.willCommitCount, 0)
                    XCTAssertEqual(observer.didCommitCount, 0)
                    XCTAssertEqual(observer.didRollbackCount, 0)
                    throw error
                }
            }
            XCTFail("Expected Error")
        } catch let error as DatabaseError {
            XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.willChangeCount, 0)
            #endif
            XCTAssertEqual(observer.didChangeCount, 0)
            XCTAssertEqual(observer.willCommitCount, 0)
            XCTAssertEqual(observer.didCommitCount, 0)
            XCTAssertEqual(observer.didRollbackCount, 0)
        }
    }

    func testExplicitTransactionRollbackCausedByDatabaseErrorSuperseedTransactionObserver() throws {
        let dbQueue = try makeDatabaseQueue()
        try setupArtistDatabase(in: dbQueue)
        let observer = Observer()
        observer.commitError = NSError(domain: "foo", code: 0, userInfo: nil)
        dbQueue.add(transactionObserver: observer)
        
        do {
            try dbQueue.inTransaction { db in
                do {
                    try Artwork(id: nil, artistId: nil, title: "meh").save(db)
                    XCTFail("Expected Error")
                } catch let error as DatabaseError {
                    // Immediate constraint check has failed.
                    XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
                    #if SQLITE_ENABLE_PREUPDATE_HOOK
                        XCTAssertEqual(observer.willChangeCount, 0)
                    #endif
                    XCTAssertEqual(observer.didChangeCount, 0)
                    XCTAssertEqual(observer.willCommitCount, 0)
                    XCTAssertEqual(observer.didCommitCount, 0)
                    XCTAssertEqual(observer.didRollbackCount, 0)
                    throw error
                }
                return .commit
            }
            XCTFail("Expected Error")
        } catch let error as DatabaseError {
            XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.willChangeCount, 0)
            #endif
            XCTAssertEqual(observer.didChangeCount, 0)
            XCTAssertEqual(observer.willCommitCount, 0)
            XCTAssertEqual(observer.didCommitCount, 0)
            XCTAssertEqual(observer.didRollbackCount, 1)
        }
    }

    func testMinimalRowIDUpdateObservation() throws {
        // Here we test that updating a Record made of a single primary key
        // column performs an actual UPDATE statement, even though it is
        // totally useless (UPDATE id = 1 FROM records WHERE id = 1).
        //
        // It is important to update something, so that TransactionObserver
        // can observe a change.
        //
        // The goal is to be able to write tests with minimal tables,
        // including tables made of a single primary key column. The less we
        // have exceptions, the better it is.
        let dbQueue = try makeDatabaseQueue()
        let observer = Observer()
        dbQueue.add(transactionObserver: observer)
        
        try dbQueue.writeWithoutTransaction { db in
            try MinimalRowID.setup(inDatabase: db)
            
            let record = MinimalRowID()
            try record.save(db)
            
            observer.resetCounts()
            try record.update(db)
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.willChangeCount, 1)
            #endif
            XCTAssertEqual(observer.didChangeCount, 1)
            XCTAssertEqual(observer.willCommitCount, 1)
            XCTAssertEqual(observer.didCommitCount, 1)
            XCTAssertEqual(observer.didRollbackCount, 0)
        }
    }
    
    // MARK: - Multiple observers

    func testInsertEventIsNotifiedToAllObservers() throws {
        let dbQueue = try makeDatabaseQueue()
        try setupArtistDatabase(in: dbQueue)
        let observer1 = Observer()
        let observer2 = Observer()
        dbQueue.add(transactionObserver: observer1)
        dbQueue.add(transactionObserver: observer2)
        
        try dbQueue.writeWithoutTransaction { db in
            let artist = Artist(id: nil, name: "Gerhard Richter")
            
            //
            try artist.save(db)
            
            do {
                XCTAssertEqual(observer1.lastCommittedEvents.count, 1)
                let event = observer1.lastCommittedEvents.filter { event in
                    self.match(event: event, kind: .insert, tableName: "artists", rowId: artist.id!)
                    }.first
                XCTAssertTrue(event != nil)
                
                #if SQLITE_ENABLE_PREUPDATE_HOOK
                    XCTAssertEqual(observer1.lastCommittedPreUpdateEvents.count, 1)
                    let preUpdateEvent = observer1.lastCommittedPreUpdateEvents.filter { event in
                        self.match(preUpdateEvent: event, kind: .insert, tableName: "artists", initialRowID: nil, finalRowID: artist.id!, initialValues: nil,
                                   finalValues: [
                                    artist.id!.databaseValue,
                                    artist.name!.databaseValue
                            ])
                        }.first
                    XCTAssertTrue(preUpdateEvent != nil)
                #endif
            }
            do {
                XCTAssertEqual(observer2.lastCommittedEvents.count, 1)
                let event = observer2.lastCommittedEvents.filter { event in
                    self.match(event: event, kind: .insert, tableName: "artists", rowId: artist.id!)
                    }.first
                XCTAssertTrue(event != nil)
                
                #if SQLITE_ENABLE_PREUPDATE_HOOK
                    XCTAssertEqual(observer2.lastCommittedPreUpdateEvents.count, 1)
                    let preUpdateEvent = observer2.lastCommittedPreUpdateEvents.filter { event in
                        self.match(preUpdateEvent: event, kind: .insert, tableName: "artists", initialRowID: nil, finalRowID: artist.id!, initialValues: nil,
                                   finalValues: [
                                    artist.id!.databaseValue,
                                    artist.name!.databaseValue
                            ])
                        }.first
                    XCTAssertTrue(preUpdateEvent != nil)
                #endif
            }
        }
    }
    
    func testTransactionObserverAddAndRemove() throws {
        let dbQueue = try makeDatabaseQueue()
        try setupArtistDatabase(in: dbQueue)
        let observer = Observer()
        dbQueue.add(transactionObserver: observer)
        
        try dbQueue.writeWithoutTransaction { db in
            let artist = Artist(id: nil, name: "Gerhard Richter")
            
            //
            try artist.save(db)
            XCTAssertEqual(observer.lastCommittedEvents.count, 1)
            let event = observer.lastCommittedEvents.filter { event in
                self.match(event: event, kind: .insert, tableName: "artists", rowId: artist.id!)
                }.first
            XCTAssertTrue(event != nil)
            
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.lastCommittedPreUpdateEvents.count, 1)
                let preUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                    self.match(preUpdateEvent: event, kind: .insert, tableName: "artists", initialRowID: nil, finalRowID: artist.id!, initialValues: nil,
                               finalValues: [
                                artist.id!.databaseValue,
                                artist.name!.databaseValue
                        ])
                    }.first
                XCTAssertTrue(preUpdateEvent != nil)
            #endif
        }
        
        observer.resetCounts()
        dbQueue.remove(transactionObserver: observer)
        
        try dbQueue.inTransaction { db in
            do {
                try Artist(id: nil, name: "Vincent Fournier").save(db)
            } catch {
                XCTFail("Unexpected Error")
            }
            return .commit
        }
        
        #if SQLITE_ENABLE_PREUPDATE_HOOK
            XCTAssertEqual(observer.willChangeCount, 0)
        #endif
        XCTAssertEqual(observer.didChangeCount, 0)
        XCTAssertEqual(observer.willCommitCount, 0)
        XCTAssertEqual(observer.didCommitCount, 0)
        XCTAssertEqual(observer.didRollbackCount, 0)
    }

    
    // MARK: - Filtered database events

    func testFilterDatabaseEvents() throws {
        let dbQueue = try makeDatabaseQueue()
        try setupArtistDatabase(in: dbQueue)
        
        do {
            let observer = Observer(observes: { _ in false })
            dbQueue.add(transactionObserver: observer)
            
            try dbQueue.inTransaction { db in
                let artist = Artist(id: nil, name: "Gerhard Richter")
                try artist.insert(db)
                try artist.update(db)
                try artist.delete(db)
                return .commit
            }
            
            XCTAssertEqual(observer.didChangeCount, 0)
            XCTAssertEqual(observer.willCommitCount, 1)
            XCTAssertEqual(observer.didCommitCount, 1)
            XCTAssertEqual(observer.didRollbackCount, 0)
            XCTAssertEqual(observer.lastCommittedEvents.count, 0)
        }
        
        do {
            let observer = Observer(observes: { _ in true })
            dbQueue.add(transactionObserver: observer)
            
            try dbQueue.inTransaction { db in
                let artist = Artist(id: nil, name: "Gerhard Richter")
                try artist.insert(db)
                try artist.update(db)
                try artist.delete(db)
                return .commit
            }
            
            XCTAssertEqual(observer.didChangeCount, 3)
            XCTAssertEqual(observer.willCommitCount, 1)
            XCTAssertEqual(observer.didCommitCount, 1)
            XCTAssertEqual(observer.didRollbackCount, 0)
            XCTAssertEqual(observer.lastCommittedEvents.count, 3)
        }
        
        do {
            let observer = Observer(observes: { eventKind in
                switch eventKind {
                case .insert:
                    return true
                case .update:
                    return false
                case .delete:
                    return false
                }
            })
            dbQueue.add(transactionObserver: observer)
            
            try dbQueue.inTransaction { db in
                let artist = Artist(id: nil, name: "Gerhard Richter")
                try artist.insert(db)
                try artist.update(db)
                try artist.delete(db)
                return .commit
            }
            
            XCTAssertEqual(observer.didChangeCount, 1)
            XCTAssertEqual(observer.willCommitCount, 1)
            XCTAssertEqual(observer.didCommitCount, 1)
            XCTAssertEqual(observer.didRollbackCount, 0)
            XCTAssertEqual(observer.lastCommittedEvents.count, 1)
        }
        
        do {
            let observer = Observer(observes: { eventKind in
                switch eventKind {
                case .insert:
                    return true
                case .update:
                    return true
                case .delete:
                    return false
                }
            })
            dbQueue.add(transactionObserver: observer)
            
            try dbQueue.inTransaction { db in
                let artist = Artist(id: nil, name: "Gerhard Richter")
                try artist.insert(db)
                try artist.update(db)
                try artist.delete(db)
                return .commit
            }
            
            XCTAssertEqual(observer.didChangeCount, 2)
            XCTAssertEqual(observer.willCommitCount, 1)
            XCTAssertEqual(observer.didCommitCount, 1)
            XCTAssertEqual(observer.didRollbackCount, 0)
            XCTAssertEqual(observer.lastCommittedEvents.count, 2)
        }
    }
    
    func testComplexFilteredDatabaseEvents() throws {
        // When a statement impact several tables, only filtered events are
        // notified
        do {
            let dbQueue = try makeDatabaseQueue()
            
            // Observe deletions in table b
            let observer = Observer(observes: { eventKind in
                if case .delete(tableName: let tableName) = eventKind {
                    return tableName == "b"
                }
                return false
            })
            dbQueue.add(transactionObserver: observer)
            
            // Delete from a and trigger b deletion
            try dbQueue.inTransaction { db in
                try db.execute(sql: """
                CREATE TABLE a(id INTEGER PRIMARY KEY);
                CREATE TABLE b(id INTEGER PRIMARY KEY REFERENCES a(id) ON DELETE CASCADE);
                INSERT INTO a (id) VALUES (42);
                INSERT INTO b (id) VALUES (42);
                DELETE FROM a;
                """)
                return .commit
            }
            
            XCTAssertEqual(observer.didChangeCount, 1)
            XCTAssertEqual(observer.willCommitCount, 1)
            XCTAssertEqual(observer.didCommitCount, 1)
            XCTAssertEqual(observer.didRollbackCount, 0)
            XCTAssertEqual(observer.lastCommittedEvents.count, 1)
            XCTAssertTrue(match(event: observer.lastCommittedEvents[0], kind: .delete, tableName: "b", rowId: 42))
        }
        
        do {
            let dbQueue = try makeDatabaseQueue()
            
            // Observe deletions in table b
            let observer = Observer(observes: { eventKind in
                if case .delete(tableName: let tableName) = eventKind {
                    return tableName == "b"
                }
                return false
            })
            dbQueue.add(transactionObserver: observer)
            
            // Insert into c and trigger b deletion
            try dbQueue.inTransaction { db in
                try db.execute(sql: """
                CREATE TABLE a(id INTEGER PRIMARY KEY);
                CREATE TABLE b(id INTEGER PRIMARY KEY);
                CREATE TABLE c(id INTEGER);
                INSERT INTO b (id) VALUES (42);
                CREATE TRIGGER t AFTER INSERT ON c BEGIN DELETE FROM b; END;
                INSERT INTO c (id) VALUES (1);
                """)
                return .commit
            }
            
            XCTAssertEqual(observer.didChangeCount, 1)
            XCTAssertEqual(observer.willCommitCount, 1)
            XCTAssertEqual(observer.didCommitCount, 1)
            XCTAssertEqual(observer.didRollbackCount, 0)
            XCTAssertEqual(observer.lastCommittedEvents.count, 1)
            XCTAssertTrue(match(event: observer.lastCommittedEvents[0], kind: .delete, tableName: "b", rowId: 42))
        }
    }
    
    func testStopObservingDatabaseChangesUntilNextTransaction() throws {
        let dbQueue = try makeDatabaseQueue()
        
        class Observer: TransactionObserver {
            var didChangeCount: Int = 0
            var willCommitCount: Int = 0
            var didCommitCount: Int = 0
            var didRollbackCount: Int = 0

            func resetCounts() {
                didChangeCount = 0
                willCommitCount = 0
                didCommitCount = 0
                didRollbackCount = 0
                #if SQLITE_ENABLE_PREUPDATE_HOOK
                    willChangeCount = 0
                #endif
            }
            
            #if SQLITE_ENABLE_PREUPDATE_HOOK
            var willChangeCount: Int = 0
            func databaseWillChange(with event: DatabasePreUpdateEvent) { willChangeCount += 1 }
            #endif
            
            func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool { true }
            
            func databaseDidChange(with event: DatabaseEvent) {
                didChangeCount += 1
                if event.tableName == "ignore" {
                    stopObservingDatabaseChangesUntilNextTransaction()
                }
            }
            
            func databaseWillCommit() throws { willCommitCount += 1 }
            func databaseDidCommit(_ db: Database) { didCommitCount += 1 }
            func databaseDidRollback(_ db: Database) { didRollbackCount += 1 }
        }
        
        let observer = Observer()
        dbQueue.add(transactionObserver: observer)
        
        try dbQueue.inDatabase { db in
            try db.create(table: "ignore") { t in
                // `INSERT INTO ignore DEFAULT VALUES` triggers an
                // "ignore event" for Observer.
                t.column("c").defaults(to: 1)
            }
            try db.create(table: "persons") { t in
                t.column("name", .text)
            }
        }
        
        try dbQueue.writeWithoutTransaction { db in
            // Don't ignore anything
            do {
                observer.resetCounts()
                try db.inTransaction {
                    try db.execute(sql: "INSERT INTO persons (name) VALUES ('a')")
                    try db.execute(sql: "DELETE FROM persons")
                    return .commit
                }
                
                #if SQLITE_ENABLE_PREUPDATE_HOOK
                    XCTAssertEqual(observer.willChangeCount, 2)
                #endif
                XCTAssertEqual(observer.didChangeCount, 2)
                XCTAssertEqual(observer.willCommitCount, 1)
                XCTAssertEqual(observer.didCommitCount, 1)
                XCTAssertEqual(observer.didRollbackCount, 0)
            }
            
            // Ignore 1
            do {
                observer.resetCounts()
                try db.inTransaction {
                    try db.execute(sql: "INSERT INTO ignore DEFAULT VALUES")
                    try db.execute(sql: "INSERT INTO persons (name) VALUES ('a')")
                    try db.execute(sql: "DELETE FROM persons")
                    return .commit
                }
                
                #if SQLITE_ENABLE_PREUPDATE_HOOK
                    XCTAssertEqual(observer.willChangeCount, 1)
                #endif
                XCTAssertEqual(observer.didChangeCount, 1)
                XCTAssertEqual(observer.willCommitCount, 1)
                XCTAssertEqual(observer.didCommitCount, 1)
                XCTAssertEqual(observer.didRollbackCount, 0)
            }
            
            // Ignore 2
            do {
                observer.resetCounts()
                try db.inTransaction {
                    try db.execute(sql: "INSERT INTO persons (name) VALUES ('a')")
                    try db.execute(sql: "INSERT INTO ignore DEFAULT VALUES")
                    try db.execute(sql: "DELETE FROM persons")
                    return .commit
                }
                
                #if SQLITE_ENABLE_PREUPDATE_HOOK
                    XCTAssertEqual(observer.willChangeCount, 2)
                #endif
                XCTAssertEqual(observer.didChangeCount, 2)
                XCTAssertEqual(observer.willCommitCount, 1)
                XCTAssertEqual(observer.didCommitCount, 1)
                XCTAssertEqual(observer.didRollbackCount, 0)
            }
            
            // Ignore 3
            do {
                observer.resetCounts()
                try db.inTransaction {
                    try db.execute(sql: "INSERT INTO persons (name) VALUES ('a')")
                    try db.execute(sql: "DELETE FROM persons")
                    try db.execute(sql: "INSERT INTO ignore DEFAULT VALUES")
                    return .commit
                }
                
                #if SQLITE_ENABLE_PREUPDATE_HOOK
                    XCTAssertEqual(observer.willChangeCount, 3)
                #endif
                XCTAssertEqual(observer.didChangeCount, 3)
                XCTAssertEqual(observer.willCommitCount, 1)
                XCTAssertEqual(observer.didCommitCount, 1)
                XCTAssertEqual(observer.didRollbackCount, 0)
            }
        }
    }
    
    // MARK: - Read-Only Connection
    
    func testReadOnlyConnection() throws {
        let dbQueue = try makeDatabaseQueue(filename: "database.sqlite")
        try setupArtistDatabase(in: dbQueue)
        
        dbConfiguration.readonly = true
        let readOnlyQueue = try makeDatabaseQueue(filename: "database.sqlite")
        
        let observer = Observer()
        readOnlyQueue.add(transactionObserver: observer, extent: .databaseLifetime)
        
        try readOnlyQueue.inDatabase { db in
            do {
                try db.execute(sql: """
                    BEGIN;
                    COMMIT;
                    """)
                XCTAssertEqual(observer.didChangeCount, 0)
                XCTAssertEqual(observer.willCommitCount, 0)
                XCTAssertEqual(observer.didCommitCount, 0)
                XCTAssertEqual(observer.didRollbackCount, 0)
                #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.willChangeCount, 0)
                #endif
            }
            
            do {
                try db.execute(sql: """
                    BEGIN;
                    SELECT * FROM artists;
                    COMMIT;
                    """)
                XCTAssertEqual(observer.didChangeCount, 0)
                XCTAssertEqual(observer.willCommitCount, 0)
                XCTAssertEqual(observer.didCommitCount, 0)
                XCTAssertEqual(observer.didRollbackCount, 0)
                #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.willChangeCount, 0)
                #endif
            }
        }
    }
    
    func testReadOnlyBlock() throws {
        let dbQueue = try makeDatabaseQueue()
        try setupArtistDatabase(in: dbQueue)
        
        let observer = Observer()
        dbQueue.add(transactionObserver: observer, extent: .databaseLifetime)
        
        try dbQueue.inDatabase { db in
            try db.readOnly {
                do {
                    try db.execute(sql: """
                        BEGIN;
                        COMMIT;
                        """)
                    XCTAssertEqual(observer.didChangeCount, 0)
                    XCTAssertEqual(observer.willCommitCount, 0)
                    XCTAssertEqual(observer.didCommitCount, 0)
                    XCTAssertEqual(observer.didRollbackCount, 0)
                    #if SQLITE_ENABLE_PREUPDATE_HOOK
                    XCTAssertEqual(observer.willChangeCount, 0)
                    #endif
                }
                
                do {
                    try db.execute(sql: """
                        BEGIN;
                        SELECT * FROM artists;
                        COMMIT;
                        """)
                    XCTAssertEqual(observer.didChangeCount, 0)
                    XCTAssertEqual(observer.willCommitCount, 0)
                    XCTAssertEqual(observer.didCommitCount, 0)
                    XCTAssertEqual(observer.didRollbackCount, 0)
                    #if SQLITE_ENABLE_PREUPDATE_HOOK
                    XCTAssertEqual(observer.willChangeCount, 0)
                    #endif
                }
            }
        }
    }
}

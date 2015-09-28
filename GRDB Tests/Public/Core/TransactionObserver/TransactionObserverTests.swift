import XCTest
import GRDB

class TransactionObserver : TransactionObserverType {
    var lastTransactionCompletion: TransactionCompletion! = nil
    var lastCommittedEvents: [DatabaseEvent] = []
    var events: [DatabaseEvent] = []
    var commitError: ErrorType?
    
    var didChangeCount: Int = 0
    var willCommitCount: Int = 0
    var didCommitCount: Int = 0
    var didRollbackCount: Int = 0
    
    func resetCounts() {
        didChangeCount = 0
        willCommitCount = 0
        didCommitCount = 0
        didRollbackCount = 0
    }
    
    func databaseDidChangeWithEvent(event: DatabaseEvent) {
        didChangeCount++
        events.append(event)
    }
    
    func databaseWillCommit() throws {
        willCommitCount++
        if let commitError = commitError {
            throw commitError
        }
    }
    
    func databaseDidCommit(db: Database) {
        didCommitCount++
        lastTransactionCompletion = .Commit
        lastCommittedEvents = events
        events = []
    }
    
    func databaseDidRollback(db: Database) {
        didRollbackCount++
        lastTransactionCompletion = .Rollback
        lastCommittedEvents = []
        events = []
    }
}

class Artist : Record {
    var id: Int64?
    var name: String?
    
    init(name: String?) {
        self.name = name
        super.init()
    }
    
    required init(row: Row) {
        super.init(row: row)
    }
    
    static override func databaseTableName() -> String {
        return "artists"
    }
    
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return ["id": id, "name": name]
    }
    
    override func updateFromRow(row: Row) {
        if let dbv = row["id"] { id = dbv.value() }
        if let dbv = row["name"] { name = dbv.value() }
        super.updateFromRow(row)
    }
    
    static func setupInDatabase(db: Database) throws {
        try db.execute(
            "CREATE TABLE artists (" +
                "id INTEGER PRIMARY KEY, " +
                "name TEXT" +
            ")")
    }
}

class Artwork : Record {
    var id: Int64?
    var artistId: Int64?
    var title: String?
    
    init(title: String?, artistId: Int64? = nil) {
        self.title = title
        self.artistId = artistId
        super.init()
    }
    
    required init(row: Row) {
        super.init(row: row)
    }
    
    static override func databaseTableName() -> String {
        return "artworks"
    }
    
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return ["id": id, "artistId": artistId, "title": title]
    }
    
    override func updateFromRow(row: Row) {
        if let dbv = row["id"] { id = dbv.value() }
        if let dbv = row["artistId"] { artistId = dbv.value() }
        if let dbv = row["title"] { title = dbv.value() }
        super.updateFromRow(row)
    }
    
    static func setupInDatabase(db: Database) throws {
        try db.execute(
            "CREATE TABLE artworks (" +
                "id INTEGER PRIMARY KEY, " +
                "artistId INTEGER NOT NULL REFERENCES artists(id) ON DELETE CASCADE ON UPDATE CASCADE, " +
                "title TEXT" +
            ")")
    }
}

class TransactionObserverTests: GRDBTestCase {
    var observer: TransactionObserver!
    
    override func setUp() {
        super.setUp()
        
        assertNoError {
            try dbQueue.inDatabase { db in
                try Artist.setupInDatabase(db)
                try Artwork.setupInDatabase(db)
            }
        }
    }
    
    override var dbConfiguration: Configuration {
        observer = TransactionObserver()
        var c = super.dbConfiguration
        c.transactionObserver = observer
        return c
    }
    
    func match(event event: DatabaseEvent, kind: DatabaseEvent.Kind, tableName: String, rowId: Int64) -> Bool {
        return (event.tableName == tableName) && (event.rowID == rowId) && (event.kind == kind)
    }

    func testInsertEvent() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let artist = Artist(name: "Gerhard Richter")
                
                //
                self.observer.resetCounts()
                try artist.save(db)
                XCTAssertEqual(self.observer.didChangeCount, 1)
                XCTAssertEqual(self.observer.willCommitCount, 1)
                XCTAssertEqual(self.observer.didCommitCount, 1)
                XCTAssertEqual(self.observer.didRollbackCount, 0)
                XCTAssertEqual(self.observer.lastCommittedEvents.count, 1)
                let event = self.observer.lastCommittedEvents.filter { event in
                    self.match(event: event, kind: .Insert, tableName: "artists", rowId: artist.id!)
                    }.first
                XCTAssertTrue(event != nil)
            }
        }
    }
    
    func testUpdateEvent() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let artist = Artist(name: "Gerhard Richter")
                try artist.save(db)
                artist.name = "Vincent Fournier"
                
                //
                self.observer.resetCounts()
                try artist.save(db)
                XCTAssertEqual(self.observer.didChangeCount, 1)
                XCTAssertEqual(self.observer.willCommitCount, 1)
                XCTAssertEqual(self.observer.didCommitCount, 1)
                XCTAssertEqual(self.observer.didRollbackCount, 0)
                XCTAssertEqual(self.observer.lastCommittedEvents.count, 1)
                let event = self.observer.lastCommittedEvents.filter {
                    self.match(event: $0, kind: .Update, tableName: "artists", rowId: artist.id!)
                    }.first
                XCTAssertTrue(event != nil)
            }
        }
    }
    
    func testDeleteEvent() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let artist = Artist(name: "Gerhard Richter")
                try artist.save(db)
                
                //
                self.observer.resetCounts()
                try artist.delete(db)
                XCTAssertEqual(self.observer.didChangeCount, 1)
                XCTAssertEqual(self.observer.willCommitCount, 1)
                XCTAssertEqual(self.observer.didCommitCount, 1)
                XCTAssertEqual(self.observer.didRollbackCount, 0)
                XCTAssertEqual(self.observer.lastCommittedEvents.count, 1)
                let event = self.observer.lastCommittedEvents.filter {
                    self.match(event: $0, kind: .Delete, tableName: "artists", rowId: artist.id!)
                    }.first
                XCTAssertTrue(event != nil)
            }
        }
    }
    
    func testCascadingDeleteEvents() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let artist = Artist(name: "Gerhard Richter")
                try artist.save(db)
                let artwork1 = Artwork(title: "Cloud", artistId: artist.id)
                try artwork1.save(db)
                let artwork2 = Artwork(title: "Ema (Nude on a Staircase)", artistId: artist.id)
                try artwork2.save(db)
                
                //
                self.observer.resetCounts()
                try artist.delete(db)
                XCTAssertEqual(self.observer.didChangeCount, 3)
                XCTAssertEqual(self.observer.willCommitCount, 1)
                XCTAssertEqual(self.observer.didCommitCount, 1)
                XCTAssertEqual(self.observer.didRollbackCount, 0)
                XCTAssertEqual(self.observer.lastCommittedEvents.count, 3)
                let artistEvent = self.observer.lastCommittedEvents.filter {
                    self.match(event: $0, kind: .Delete, tableName: "artists", rowId: artist.id!)
                    }.first
                XCTAssertTrue(artistEvent != nil)
                let artwork1Event = self.observer.lastCommittedEvents.filter {
                    self.match(event: $0, kind: .Delete, tableName: "artworks", rowId: artwork1.id!)
                    }.first
                XCTAssertTrue(artwork1Event != nil)
                let artwork2Event = self.observer.lastCommittedEvents.filter {
                    self.match(event: $0, kind: .Delete, tableName: "artworks", rowId: artwork2.id!)
                    }.first
                XCTAssertTrue(artwork2Event != nil)
            }
        }
    }
    
    func testTransactionCommit() {
        assertNoError {
            let artist = Artist(name: "Gerhard Richter")
            let artwork1 = Artwork(title: "Cloud")
            let artwork2 = Artwork(title: "Ema (Nude on a Staircase)")
            
            try dbQueue.inTransaction { db in
                self.observer.resetCounts()
                try artist.save(db)
                XCTAssertEqual(self.observer.didChangeCount, 1)
                XCTAssertEqual(self.observer.willCommitCount, 0)
                XCTAssertEqual(self.observer.didCommitCount, 0)
                XCTAssertEqual(self.observer.didRollbackCount, 0)
                XCTAssertEqual(self.observer.lastCommittedEvents.count, 0)
                
                artwork1.artistId = artist.id
                artwork2.artistId = artist.id
                
                self.observer.resetCounts()
                try artwork1.save(db)
                XCTAssertEqual(self.observer.didChangeCount, 1)
                XCTAssertEqual(self.observer.willCommitCount, 0)
                XCTAssertEqual(self.observer.didCommitCount, 0)
                XCTAssertEqual(self.observer.didRollbackCount, 0)
                XCTAssertEqual(self.observer.lastCommittedEvents.count, 0)
                
                self.observer.resetCounts()
                try artwork2.save(db)
                XCTAssertEqual(self.observer.didChangeCount, 1)
                XCTAssertEqual(self.observer.willCommitCount, 0)
                XCTAssertEqual(self.observer.didCommitCount, 0)
                XCTAssertEqual(self.observer.didRollbackCount, 0)
                XCTAssertEqual(self.observer.lastCommittedEvents.count, 0)
                
                self.observer.resetCounts()
                return .Commit
            }
            XCTAssertEqual(self.observer.didChangeCount, 0)
            XCTAssertEqual(self.observer.willCommitCount, 1)
            XCTAssertEqual(self.observer.didCommitCount, 1)
            XCTAssertEqual(self.observer.didRollbackCount, 0)
            XCTAssertEqual(observer.lastTransactionCompletion, TransactionCompletion.Commit)
            XCTAssertEqual(observer.lastCommittedEvents.count, 3)
            let artistEvent = observer.lastCommittedEvents.filter {
                self.match(event: $0, kind: .Insert, tableName: "artists", rowId: artist.id!)
                }.first
            XCTAssertTrue(artistEvent != nil)
            let artwork1Event = observer.lastCommittedEvents.filter {
                self.match(event: $0, kind: .Insert, tableName: "artworks", rowId: artwork1.id!)
                }.first
            XCTAssertTrue(artwork1Event != nil)
            let artwork2Event = observer.lastCommittedEvents.filter {
                self.match(event: $0, kind: .Insert, tableName: "artworks", rowId: artwork2.id!)
                }.first
            XCTAssertTrue(artwork2Event != nil)
        }
    }
    
    func testTransactionRollback() {
        assertNoError {
            let artist = Artist(name: "Gerhard Richter")
            let artwork1 = Artwork(title: "Cloud")
            let artwork2 = Artwork(title: "Ema (Nude on a Staircase)")
            
            try dbQueue.inTransaction { db in
                try artist.save(db)
                artwork1.artistId = artist.id
                artwork2.artistId = artist.id
                XCTAssertEqual(self.observer.lastCommittedEvents.count, 0)
                
                try artwork1.save(db)
                XCTAssertEqual(self.observer.lastCommittedEvents.count, 0)
                
                try artwork2.save(db)
                XCTAssertEqual(self.observer.lastCommittedEvents.count, 0)
                
                self.observer.resetCounts()
                return .Rollback
            }
            XCTAssertEqual(self.observer.didChangeCount, 0)
            XCTAssertEqual(self.observer.willCommitCount, 0)
            XCTAssertEqual(self.observer.didCommitCount, 0)
            XCTAssertEqual(self.observer.didRollbackCount, 1)
            XCTAssertEqual(observer.lastTransactionCompletion, TransactionCompletion.Rollback)
            XCTAssertEqual(observer.lastCommittedEvents.count, 0)
        }
    }
    
    func testWillCommitError() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let artist = Artist(name: "Gerhard Richter")
                try artist.save(db)
            }
            
            self.observer.commitError = NSError(domain: "foo", code: 0, userInfo: nil)
            do {
                try dbQueue.inDatabase { db in
                    let artist = Artist(name: "Gerhard Richter")
                    self.observer.resetCounts()
                    try artist.save(db)
                }
                XCTFail("Error expected")
            } catch let error as NSError {
                XCTAssertEqual(self.observer.didChangeCount, 1)
                XCTAssertEqual(self.observer.willCommitCount, 1)
                XCTAssertEqual(self.observer.didCommitCount, 0)
                XCTAssertEqual(self.observer.didRollbackCount, 1)
                XCTAssertEqual(error.domain, "foo")
                XCTAssertEqual(error.code, 0)
            }
            
            do {
                try dbQueue.inTransaction { db in
                    let artist = Artist(name: "Gerhard Richter")
                    try artist.save(db)
                    self.observer.resetCounts()
                    return .Commit
                }
                XCTFail("Error expected")
            } catch let error as NSError {
                XCTAssertEqual(self.observer.didChangeCount, 0)
                XCTAssertEqual(self.observer.willCommitCount, 1)
                XCTAssertEqual(self.observer.didCommitCount, 0)
                XCTAssertEqual(self.observer.didRollbackCount, 1)
                XCTAssertEqual(error.domain, "foo")
                XCTAssertEqual(error.code, 0)
            }
            
            self.observer.commitError = nil
            try dbQueue.inDatabase { db in
                let artist = Artist(name: "Gerhard Richter")
                try artist.save(db)
            }
            
            let artistCount = dbQueue.inDatabase { db in
                Int.fetchOne(db, "SELECT COUNT(*) FROM artists")
            }
            XCTAssertEqual(artistCount, 2)
        }
    }
}

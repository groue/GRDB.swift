import XCTest
import GRDB

class TransactionObserver : TransactionObserverType {
    var lastTransactionCompletion: TransactionCompletion! = nil
    var lastCommittedEvents: [DatabaseEvent] = []
    var events: [DatabaseEvent] = []
    
    func databaseDidChangeWithEvent(event: DatabaseEvent) {
        events.append(event)
    }
    
    func databaseDidCommit() {
        lastTransactionCompletion = .Commit
        lastCommittedEvents = events
        events = []
    }
    
    func databaseDidRollback() {
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
                try artist.save(db)
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
                try artist.save(db)
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
                try artist.delete(db)
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
                try artist.delete(db)
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
                try artist.save(db)
                artwork1.artistId = artist.id
                artwork2.artistId = artist.id
                XCTAssertEqual(self.observer.lastCommittedEvents.count, 0)
                
                try artwork1.save(db)
                XCTAssertEqual(self.observer.lastCommittedEvents.count, 0)
                
                try artwork2.save(db)
                XCTAssertEqual(self.observer.lastCommittedEvents.count, 0)
                
                return .Commit
            }
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
                
                return .Rollback
            }
            XCTAssertEqual(observer.lastTransactionCompletion, TransactionCompletion.Rollback)
            XCTAssertEqual(observer.lastCommittedEvents.count, 0)
        }
    }
}

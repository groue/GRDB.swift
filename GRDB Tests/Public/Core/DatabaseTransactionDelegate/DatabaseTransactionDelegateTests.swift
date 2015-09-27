import XCTest
import GRDB

class TransactionDelegate : DatabaseTransactionDelegate {
    var committedEvents: [DatabaseEvent] = []
    var events: [DatabaseEvent] = []
    
    func databaseDidChangeWithEvent(event: DatabaseEvent) {
        events.append(event)
    }
    
    func databaseDidCommit() {
        committedEvents = events
        events = []
    }
    
    func databaseDidRollback() {
        committedEvents = []
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
    
    init(title: String?, artistId: Int64?) {
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

class DatabaseTransactionDelegateTests: GRDBTestCase {
    
    override func setUp() {
        super.setUp()
        
        assertNoError {
            try dbQueue.inDatabase { db in
                try Artist.setupInDatabase(db)
                try Artwork.setupInDatabase(db)
            }
        }
    }
    
    func match(event event: DatabaseEvent, kind: DatabaseEvent.Kind, tableName: String, rowId: Int64) -> Bool {
        return (event.tableName == tableName) && (event.rowID == rowId) && (event.kind == kind)
    }

    func testInsertEvent() {
        let delegate = TransactionDelegate()
        assertNoError {
            try dbQueue.inDatabase { db in
                db.transactionDelegate = delegate
                let artist = Artist(name: "Gerhard Richter")
                
                //
                try artist.save(db)
                XCTAssertEqual(delegate.committedEvents.count, 1)
                let event = delegate.committedEvents.filter { event in
                    self.match(event: event, kind: .Insert, tableName: "artists", rowId: artist.id!)
                    }.first
                XCTAssertTrue(event != nil)
            }
        }
    }
    
    func testUpdateEvent() {
        let delegate = TransactionDelegate()
        assertNoError {
            try dbQueue.inDatabase { db in
                db.transactionDelegate = delegate
                let artist = Artist(name: "Gerhard Richter")
                try artist.save(db)
                artist.name = "Vincent Fournier"
                
                //
                try artist.save(db)
                XCTAssertEqual(delegate.committedEvents.count, 1)
                let event = delegate.committedEvents.filter {
                    self.match(event: $0, kind: .Update, tableName: "artists", rowId: artist.id!)
                    }.first
                XCTAssertTrue(event != nil)
            }
        }
    }
    
    func testDeleteEvent() {
        let delegate = TransactionDelegate()
        assertNoError {
            try dbQueue.inDatabase { db in
                db.transactionDelegate = delegate
                let artist = Artist(name: "Gerhard Richter")
                try artist.save(db)
                
                //
                try artist.delete(db)
                XCTAssertEqual(delegate.committedEvents.count, 1)
                let event = delegate.committedEvents.filter {
                    self.match(event: $0, kind: .Delete, tableName: "artists", rowId: artist.id!)
                    }.first
                XCTAssertTrue(event != nil)
            }
        }
    }
    
    func testCascadingDeleteEvents() {
        let delegate = TransactionDelegate()
        assertNoError {
            try dbQueue.inDatabase { db in
                db.transactionDelegate = delegate
                let artist = Artist(name: "Gerhard Richter")
                try artist.save(db)
                let artwork1 = Artwork(title: "Cloud", artistId: artist.id)
                try artwork1.save(db)
                let artwork2 = Artwork(title: "Ema (Nude on a Staircase)", artistId: artist.id)
                try artwork2.save(db)
                
                //
                try artist.delete(db)
                XCTAssertEqual(delegate.committedEvents.count, 3)
                let artistEvent = delegate.committedEvents.filter {
                    self.match(event: $0, kind: .Delete, tableName: "artists", rowId: artist.id!)
                    }.first
                XCTAssertTrue(artistEvent != nil)
                let artwork1Event = delegate.committedEvents.filter {
                    self.match(event: $0, kind: .Delete, tableName: "artworks", rowId: artwork1.id!)
                    }.first
                XCTAssertTrue(artwork1Event != nil)
                let artwork2Event = delegate.committedEvents.filter {
                    self.match(event: $0, kind: .Delete, tableName: "artworks", rowId: artwork2.id!)
                    }.first
                XCTAssertTrue(artwork2Event != nil)
            }
        }
    }
}

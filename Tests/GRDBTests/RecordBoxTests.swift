import XCTest
#if GRDBCIPHER
    import GRDBCipher
    typealias RecordBox = GRDBCipher.RecordBox // Single deprecation warning
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
    typealias RecordBox = GRDBCustomSQLite.RecordBox // Single deprecation warning
#else
    import GRDB
    typealias RecordBox = GRDB.RecordBox // Single deprecation warning
#endif

private struct Player: RowConvertible, MutablePersistable, Codable {
    static let databaseTableName = "players"
    
    var id: Int64?
    var name: String?
    var score: Int?
    var creationDate: Date?
    
    init(id: Int64? = nil, name: String? = nil, score: Int? = nil, creationDate: Date? = nil) {
        self.id = id
        self.name = name
        self.score = score
        self.creationDate = creationDate
    }
    
    mutating func insert(_ db: Database) throws {
        if creationDate == nil {
           creationDate = Date()
        }
        try performInsert(db)
    }
    
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

class RecordBoxTests: GRDBTestCase {
    override func setup(_ dbWriter: DatabaseWriter) throws {
        try dbWriter.write { db in
            try db.create(table: "players") { t in
                t.column("id", .integer).primaryKey()
                t.column("name", .text)
                t.column("score", .integer)
                t.column("creationDate", .datetime)
            }
        }
    }
    
    func testRecordIsEditedAfterInit() {
        // Create a Record. No fetch has happen, so we don't know if it is
        // identical to its eventual row in the database. So it is edited.
        let player = RecordBox<Player>(value: Player(name: "Arthur", score: 41))
        XCTAssertTrue(player.hasDatabaseChanges)
    }
    
    func testRecordIsEditedAfterInitFromRow() {
        // Create a Record from a row. The row may not come from the database.
        // So it is edited.
        let row = Row(["name": "Arthur", "score": 41])
        let player = RecordBox<Player>(row: row)
        XCTAssertTrue(player.hasDatabaseChanges)
    }
    
    func testRecordIsNotEditedAfterFullFetch() throws {
        // Fetch a record from a row that contains all the columns in
        // persistence container: An update statement, which only saves the
        // columns in persistence container would perform no change. So the
        // record is not edited.
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try RecordBox<Player>(value: Player(name: "Arthur", score: 41)).insert(db)
            let player = try RecordBox<Player>.fetchOne(db, "SELECT * FROM players")!
            XCTAssertFalse(player.hasDatabaseChanges)
        }
    }
    
    func testRecordIsNotEditedAfterWiderThanFullFetch() throws {
        // Fetch a record from a row that contains all the columns in
        // persistence container, plus extra ones: An update statement,
        // which only saves the columns in persistence container would
        // perform no change. So the record is not edited.
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try RecordBox<Player>(value: Player(name: "Arthur", score: 41)).insert(db)
            let player = try RecordBox<Player>.fetchOne(db, "SELECT *, 1 AS foo FROM players")!
            XCTAssertFalse(player.hasDatabaseChanges)
        }
    }
    
    func testRecordIsEditedAfterPartialFetch() throws {
        // Fetch a record from a row that does not contain all the columns in
        // persistence container: An update statement saves the columns in
        // persistence container, so it may perform unpredictable change.
        // So the record is edited.
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try RecordBox<Player>(value: Player(name: "Arthur", score: 41)).insert(db)
            let player = try RecordBox<Player>.fetchOne(db, "SELECT name FROM players")!
            XCTAssertTrue(player.hasDatabaseChanges)
        }
    }
    
    func testRecordIsNotEditedAfterInsert() throws {
        // After insertion, a record is not edited.
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let player = RecordBox<Player>(value: Player(name: "Arthur", score: 41))
            try player.insert(db)
            XCTAssertFalse(player.hasDatabaseChanges)
        }
    }
    
    func testRecordIsEditedAfterValueChange() throws {
        // Any change in a value exposed in persistence container yields a
        // record that is edited.
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            do {
                let player = RecordBox<Player>(value: Player(name: "Arthur"))
                try player.insert(db)
                XCTAssertTrue(player.value.name != nil)
                player.value.name = "Bobby"           // non-nil vs. non-nil
                XCTAssertTrue(player.hasDatabaseChanges)
            }
            do {
                let player = RecordBox<Player>(value: Player(name: "Arthur"))
                try player.insert(db)
                XCTAssertTrue(player.value.name != nil)
                player.value.name = nil               // non-nil vs. nil
                XCTAssertTrue(player.hasDatabaseChanges)
            }
            do {
                let player = RecordBox<Player>(value: Player(name: "Arthur"))
                try player.insert(db)
                XCTAssertTrue(player.value.score == nil)
                player.value.score = 41                 // nil vs. non-nil
                XCTAssertTrue(player.hasDatabaseChanges)
            }
        }
    }
    
    func testRecordIsNotEditedAfterSameValueChange() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            do {
                let player = RecordBox<Player>(value: Player(name: "Arthur"))
                try player.insert(db)
                XCTAssertTrue(player.value.name != nil)
                player.value.name = "Arthur"           // non-nil vs. non-nil
                XCTAssertFalse(player.hasDatabaseChanges)
            }
            do {
                let player = RecordBox<Player>(value: Player(name: "Arthur"))
                try player.insert(db)
                XCTAssertTrue(player.value.score == nil)
                player.value.score = nil                 // nil vs. nil
                XCTAssertFalse(player.hasDatabaseChanges)
            }
        }
    }
    
    func testRecordIsNotEditedAfterUpdate() throws {
        // After update, a record is not edited.
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let player = RecordBox<Player>(value: Player(name: "Arthur", score: 41))
            try player.insert(db)
            player.value.name = "Bobby"
            try player.update(db)
            XCTAssertFalse(player.hasDatabaseChanges)
        }
    }
    
    func testRecordIsNotEditedAfterSave() throws {
        // After save, a record is not edited.
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let player = RecordBox<Player>(value: Player(name: "Arthur", score: 41))
            try player.save(db)
            XCTAssertFalse(player.hasDatabaseChanges)
            player.value.name = "Bobby"
            XCTAssertTrue(player.hasDatabaseChanges)
            try player.save(db)
            XCTAssertFalse(player.hasDatabaseChanges)
        }
    }
    
    func testRecordIsEditedAfterPrimaryKeyChange() throws {
        // After reload, a record is not edited.
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let player = RecordBox<Player>(value: Player(name: "Arthur", score: 41))
            try player.insert(db)
            player.value.id = player.value.id! + 1
            XCTAssertTrue(player.hasDatabaseChanges)
        }
    }
    
    func testCopyTransfersEditedFlag() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let player = RecordBox<Player>(value: Player(name: "Arthur", score: 41))
            
            try player.insert(db)
            XCTAssertFalse(player.hasDatabaseChanges)
            XCTAssertFalse(player.copy().hasDatabaseChanges)
            
            player.value.name = "Barbara"
            XCTAssertTrue(player.hasDatabaseChanges)
            XCTAssertTrue(player.copy().hasDatabaseChanges)
            
            player.hasDatabaseChanges = false
            XCTAssertFalse(player.hasDatabaseChanges)
            XCTAssertFalse(player.copy().hasDatabaseChanges)
            
            player.hasDatabaseChanges = true
            XCTAssertTrue(player.hasDatabaseChanges)
            XCTAssertTrue(player.copy().hasDatabaseChanges)
        }
    }
    
    func testChangesAfterInit() {
        let player = RecordBox<Player>(value: Player(name: "Arthur", score: 41))
        let changes = player.databaseChanges
        XCTAssertEqual(changes.count, 4)
        for (column, old) in changes {
            switch column {
            case "id":
                XCTAssertTrue(old == nil)
            case "name":
                XCTAssertTrue(old == nil)
            case "score":
                XCTAssertTrue(old == nil)
            case "creationDate":
                XCTAssertTrue(old == nil)
            default:
                XCTFail("Unexpected column: \(column)")
            }
        }
    }
    
    func testChangesAfterInitFromRow() {
        let player = RecordBox<Player>(row: Row(["name": "Arthur", "score": 41]))
        let changes = player.databaseChanges
        XCTAssertEqual(changes.count, 4)
        for (column, old) in changes {
            switch column {
            case "id":
                XCTAssertTrue(old == nil)
            case "name":
                XCTAssertTrue(old == nil)
            case "score":
                XCTAssertTrue(old == nil)
            case "creationDate":
                XCTAssertTrue(old == nil)
            default:
                XCTFail("Unexpected column: \(column)")
            }
        }
    }
    
    func testChangesAfterFullFetch() throws {
        // Fetch a record from a row that contains all the columns in
        // persistence container: An update statement, which only saves the
        // columns in persistence container would perform no change. So the
        // record is not edited.
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try RecordBox<Player>(value: Player(name: "Arthur", score: 41)).insert(db)
            do {
                let player = try RecordBox<Player>.fetchOne(db, "SELECT * FROM players")!
                let changes = player.databaseChanges
                XCTAssertEqual(changes.count, 0)
            }
            do {
                let players = try RecordBox<Player>.fetchAll(db, "SELECT * FROM players")
                let changes = players[0].databaseChanges
                XCTAssertEqual(changes.count, 0)
            }
            do {
                let players = try RecordBox<Player>.fetchCursor(db, "SELECT * FROM players")
                let changes = try players.next()!.databaseChanges
                XCTAssertEqual(changes.count, 0)
            }
            do {
                let player = try RecordBox<Player>.fetchOne(db, "SELECT * FROM players", adapter: SuffixRowAdapter(fromIndex: 0))!
                let changes = player.databaseChanges
                XCTAssertEqual(changes.count, 0)
            }
        }
    }
    
    func testChangesAfterPartialFetch() throws {
        // Fetch a record from a row that does not contain all the columns in
        // persistence container: An update statement saves the columns in
        // persistence container, so it may perform unpredictable change.
        // So the record is edited.
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try RecordBox<Player>(value: Player(name: "Arthur", score: 41)).insert(db)
            let player = try RecordBox<Player>.fetchOne(db, "SELECT name FROM players")!
            let changes = player.databaseChanges
            XCTAssertEqual(changes.count, 3)
            for (column, old) in changes {
                switch column {
                case "id":
                    XCTAssertTrue(old == nil)
                case "score":
                    XCTAssertTrue(old == nil)
                case "creationDate":
                    XCTAssertTrue(old == nil)
                default:
                    XCTFail("Unexpected column: \(column)")
                }
            }
        }
    }
    
    func testChangesAfterInsert() throws {
        // After insertion, a record is not edited.
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let player = RecordBox<Player>(value: Player(name: "Arthur", score: 41))
            try player.insert(db)
            let changes = player.databaseChanges
            XCTAssertEqual(changes.count, 0)
        }
    }
    
    func testChangesAfterValueChange() throws {
        // Any change in a value exposed in persistence container yields a
        // record that is edited.
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let player = RecordBox<Player>(value: Player(name: "Arthur"))
            try player.insert(db)
            
            player.value.name = "Bobby"           // non-nil -> non-nil
            player.value.score = 41                 // nil -> non-nil
            player.value.creationDate = nil       // non-nil -> nil
            let changes = player.databaseChanges
            XCTAssertEqual(changes.count, 3)
            for (column, old) in changes {
                switch column {
                case "name":
                    XCTAssertEqual(old, "Arthur".databaseValue)
                case "score":
                    XCTAssertEqual(old, DatabaseValue.null)
                case "creationDate":
                    XCTAssertTrue(Date.fromDatabaseValue(old!) != nil)
                default:
                    XCTFail("Unexpected column: \(column)")
                }
            }
        }
    }
    
    func testChangesAfterUpdate() throws {
        // After update, a record is not edited.
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let player = RecordBox<Player>(value: Player(name: "Arthur", score: 41))
            try player.insert(db)
            player.value.name = "Bobby"
            try player.update(db)
            XCTAssertEqual(player.databaseChanges.count, 0)
        }
    }
    
    func testChangesAfterSave() throws {
        // After save, a record is not edited.
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let player = RecordBox<Player>(value: Player(name: "Arthur", score: 41))
            try player.save(db)
            XCTAssertEqual(player.databaseChanges.count, 0)
            
            player.value.name = "Bobby"
            let changes = player.databaseChanges
            XCTAssertEqual(changes.count, 1)
            for (column, old) in changes {
                switch column {
                case "name":
                    XCTAssertEqual(old, "Arthur".databaseValue)
                default:
                    XCTFail("Unexpected column: \(column)")
                }
            }
            try player.save(db)
            XCTAssertEqual(player.databaseChanges.count, 0)
        }
    }
    
    func testChangesAfterPrimaryKeyChange() throws {
        // After reload, a record is not edited.
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let player = RecordBox<Player>(value: Player(name: "Arthur", score: 41))
            try player.insert(db)
            player.value.id = player.value.id! + 1
            let changes = player.databaseChanges
            XCTAssertEqual(changes.count, 1)
            for (column, old) in changes {
                switch column {
                case "id":
                    XCTAssertEqual(old, (player.value.id! - 1).databaseValue)
                default:
                    XCTFail("Unexpected column: \(column)")
                }
            }
        }
    }
    
    func testCopyTransfersChanges() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let player = RecordBox<Player>(value: Player(name: "Arthur", score: 41))
            
            try player.insert(db)
            XCTAssertEqual(player.databaseChanges.count, 0)
            XCTAssertEqual(player.copy().databaseChanges.count, 0)
            
            player.value.name = "Barbara"
            XCTAssertTrue(player.databaseChanges.count > 0)            // TODO: compare actual changes
            XCTAssertEqual(player.databaseChanges.count, player.copy().databaseChanges.count)
            
            player.hasDatabaseChanges = false
            XCTAssertEqual(player.databaseChanges.count, 0)
            XCTAssertEqual(player.copy().databaseChanges.count, 0)
            
            player.hasDatabaseChanges = true
            XCTAssertTrue(player.databaseChanges.count > 0)            // TODO: compare actual changes
            XCTAssertEqual(player.databaseChanges.count, player.copy().databaseChanges.count)
        }
    }
    
    func testUpdateChanges() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let player = RecordBox<Player>(value: Player(name: "Arthur", score: 41))
            
            do {
                XCTAssertTrue(player.hasDatabaseChanges)
                try player.updateChanges(db)
                XCTFail("Expected PersistenceError")
            } catch is PersistenceError { }
            
            try player.insert(db)
            
            // Nothing to update
            let initialChangesCount = db.totalChangesCount
            XCTAssertFalse(player.hasDatabaseChanges)
            try XCTAssertFalse(player.updateChanges(db))
            XCTAssertEqual(db.totalChangesCount, initialChangesCount)
            
            // Nothing to update
            player.value.score = 41
            XCTAssertFalse(player.hasDatabaseChanges)
            try XCTAssertFalse(player.updateChanges(db))
            XCTAssertEqual(db.totalChangesCount, initialChangesCount)
            
            // Update single column
            player.value.score = 42
            XCTAssertEqual(Set(player.databaseChanges.keys), ["score"])
            try XCTAssertTrue(player.updateChanges(db))
            XCTAssertEqual(db.totalChangesCount, initialChangesCount + 1)
            XCTAssertEqual(lastSQLQuery, "UPDATE \"players\" SET \"score\"=42 WHERE \"id\"=1")
            
            // Update two columns
            player.value.name = "Barbara"
            player.value.score = 43
            XCTAssertEqual(Set(player.databaseChanges.keys), ["score", "name"])
            try XCTAssertTrue(player.updateChanges(db))
            XCTAssertEqual(db.totalChangesCount, initialChangesCount + 2)
            let fetchedPlayer = try RecordBox<Player>.fetchOne(db, key: player.value.id)!
            XCTAssertEqual(fetchedPlayer.value.name, player.value.name)
            XCTAssertEqual(fetchedPlayer.value.score, player.value.score)
        }
    }
}

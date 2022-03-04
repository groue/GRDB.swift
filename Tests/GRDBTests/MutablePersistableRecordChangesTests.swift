import XCTest
import GRDB

private struct Player: FetchableRecord, MutablePersistableRecord, Codable {
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

class MutablePersistableRecordChangesTests: GRDBTestCase {
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
    
    func testDegenerateDatabaseEqualsWithSelf() throws {
        struct DegenerateRecord: MutablePersistableRecord {
            static let databaseTableName = "degenerated"
            func encode(to container: inout PersistenceContainer) {
            }
        }
        let record = DegenerateRecord()
        XCTAssertTrue(record.databaseEquals(record))
        XCTAssertTrue(record.databaseChanges(from: record).isEmpty)
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            // table must exist
            try db.create(table: DegenerateRecord.databaseTableName) { t in
                t.autoIncrementedPrimaryKey("id")
            }
            let totalChangesCount = db.totalChangesCount
            try XCTAssertFalse(record.updateChanges(db, from: record))
            XCTAssertEqual(db.totalChangesCount, totalChangesCount)
        }
    }
    
    func testDatabaseEqualsWithSelf() throws {
        do {
            let player = Player(id: nil, name: nil, score: nil, creationDate: nil)
            XCTAssertTrue(player.databaseEquals(player))
            XCTAssertTrue(player.databaseChanges(from: player).isEmpty)
            
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let totalChangesCount = db.totalChangesCount
                try XCTAssertFalse(player.updateChanges(db, from: player))
                XCTAssertEqual(db.totalChangesCount, totalChangesCount)
            }
        }
        do {
            let player = Player(id: 1, name: "foo", score: 42, creationDate: Date())
            XCTAssertTrue(player.databaseEquals(player))
            XCTAssertTrue(player.databaseChanges(from: player).isEmpty)
            
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let totalChangesCount = db.totalChangesCount
                try XCTAssertFalse(player.updateChanges(db, from: player))
                XCTAssertEqual(db.totalChangesCount, totalChangesCount)
            }
        }
    }

    func testRecordValueChange() throws {
        let dbQueue = try makeDatabaseQueue()
        var player = Player(id: 1, name: "Arthur", score: nil, creationDate: nil)
        try dbQueue.inDatabase { db in
            try player.insert(db)
        }
        
        do {
            // non-nil vs. non-nil
            var newPlayer = player
            newPlayer.name = "Bobby"
            
            XCTAssertFalse(newPlayer.databaseEquals(player))
            let changes = newPlayer.databaseChanges(from: player)
            XCTAssertEqual(changes.count, 1)
            XCTAssertEqual(changes["name"]!, "Arthur".databaseValue)
            
            try dbQueue.inDatabase { db in
                let totalChangesCount = db.totalChangesCount
                try XCTAssertTrue(newPlayer.updateChanges(db, from: player))
                XCTAssertEqual(db.totalChangesCount, totalChangesCount + 1)
                XCTAssertEqual(lastSQLQuery, "UPDATE \"players\" SET \"name\"=\'Bobby\' WHERE \"id\"=1")
            }
        }
        do {
            // non-nil vs. nil
            var newPlayer = player
            newPlayer.name = nil
            
            XCTAssertFalse(newPlayer.databaseEquals(player))
            let changes = newPlayer.databaseChanges(from: player)
            XCTAssertEqual(changes.count, 1)
            XCTAssertEqual(changes["name"]!, "Arthur".databaseValue)
            
            try dbQueue.inDatabase { db in
                let totalChangesCount = db.totalChangesCount
                try XCTAssertTrue(newPlayer.updateChanges(db, from: player))
                XCTAssertEqual(db.totalChangesCount, totalChangesCount + 1)
                XCTAssertEqual(lastSQLQuery, "UPDATE \"players\" SET \"name\"=NULL WHERE \"id\"=1")
            }
        }
        do {
            // nil vs. non-nil
            var newPlayer = player
            newPlayer.score = 41
            
            XCTAssertFalse(newPlayer.databaseEquals(player))
            let changes = newPlayer.databaseChanges(from: player)
            XCTAssertEqual(changes.count, 1)
            XCTAssertEqual(changes["score"]!, .null)
            
            try dbQueue.inDatabase { db in
                let totalChangesCount = db.totalChangesCount
                try XCTAssertTrue(newPlayer.updateChanges(db, from: player))
                XCTAssertEqual(db.totalChangesCount, totalChangesCount + 1)
                XCTAssertEqual(lastSQLQuery, "UPDATE \"players\" SET \"score\"=41 WHERE \"id\"=1")
            }
        }
        do {
            // multiple changes
            var newPlayer = player
            newPlayer.name = "Bobby"
            newPlayer.score = 41
            
            XCTAssertFalse(newPlayer.databaseEquals(player))
            let changes = newPlayer.databaseChanges(from: player)
            XCTAssertEqual(changes.count, 2)
            XCTAssertEqual(changes["name"]!, "Arthur".databaseValue)
            XCTAssertEqual(changes["score"]!, .null)

            try dbQueue.inDatabase { db in
                let totalChangesCount = db.totalChangesCount
                try XCTAssertTrue(newPlayer.updateChanges(db, from: player))
                XCTAssertEqual(db.totalChangesCount, totalChangesCount + 1)
                let fetchedPlayer = try Player.fetchOne(db, key: player.id)
                XCTAssertEqual(fetchedPlayer?.name, newPlayer.name)
                XCTAssertEqual(fetchedPlayer?.score, newPlayer.score)
            }
        }
    }

    func testDatabaseEqualsWithDifferentTypesAndDifferentWidth() throws {
        // Mangle column case as well, for fun ;-)
        struct NarrowPlayer: MutablePersistableRecord, Codable {
            static let databaseTableName = "players"
            var ID: Int64?
            var NAME: String?
        }
        
        let dbQueue = try makeDatabaseQueue()
        
        do {
            var oldPlayer = NarrowPlayer(ID: 1, NAME: "Arthur")
            let newPlayer = Player(id: 1, name: "Arthur", score: 41, creationDate: nil)
            
            let changes = newPlayer.databaseChanges(from: oldPlayer)
            XCTAssertEqual(changes.count, 1)
            XCTAssertEqual(changes["score"]!, .null)
            
            try dbQueue.inTransaction { db in
                try oldPlayer.insert(db)
                let totalChangesCount = db.totalChangesCount
                try XCTAssertTrue(newPlayer.updateChanges(db, from: oldPlayer))
                XCTAssertEqual(db.totalChangesCount, totalChangesCount + 1)
                XCTAssertEqual(lastSQLQuery, "UPDATE \"players\" SET \"score\"=41 WHERE \"id\"=1")
                return .rollback
            }
        }
        
        do {
            var oldPlayer = NarrowPlayer(ID: 1, NAME: "Bobby")
            let newPlayer = Player(id: 1, name: "Arthur", score: 42, creationDate: nil)
            
            let changes = newPlayer.databaseChanges(from: oldPlayer)
            XCTAssertEqual(changes.count, 2)
            XCTAssertEqual(changes["name"]!, "Bobby".databaseValue)
            XCTAssertEqual(changes["score"]!, .null)
            
            try dbQueue.inTransaction { db in
                try oldPlayer.insert(db)
                let totalChangesCount = db.totalChangesCount
                try XCTAssertTrue(newPlayer.updateChanges(db, from: oldPlayer))
                XCTAssertEqual(db.totalChangesCount, totalChangesCount + 1)
                let fetchedPlayer = try Player.fetchOne(db, key: newPlayer.id)
                XCTAssertEqual(fetchedPlayer?.name, newPlayer.name)
                XCTAssertEqual(fetchedPlayer?.score, newPlayer.score)
                return .rollback
            }
        }
        
        do {
            let oldPlayer = Player(id: 1, name: "Arthur", score: 42, creationDate: nil)
            let newPlayer = NarrowPlayer(ID: 1, NAME: "Arthur")
            
            let changes = newPlayer.databaseChanges(from: oldPlayer)
            XCTAssertTrue(changes.isEmpty)
            
            try dbQueue.inTransaction { db in
                let totalChangesCount = db.totalChangesCount
                try XCTAssertFalse(newPlayer.updateChanges(db, from: oldPlayer))
                XCTAssertEqual(db.totalChangesCount, totalChangesCount)
                return .rollback
            }
        }
        
        do {
            let oldPlayer = Player(id: 1, name: "Arthur", score: nil, creationDate: nil)
            let newPlayer = NarrowPlayer(ID: 1, NAME: "Arthur")
            
            let changes = newPlayer.databaseChanges(from: oldPlayer)
            XCTAssertTrue(changes.isEmpty)
            
            try dbQueue.inTransaction { db in
                let totalChangesCount = db.totalChangesCount
                try XCTAssertFalse(newPlayer.updateChanges(db, from: oldPlayer))
                XCTAssertEqual(db.totalChangesCount, totalChangesCount)
                return .rollback
            }
        }

        do {
            var oldPlayer = Player(id: 1, name: "Arthur", score: nil, creationDate: nil)
            let newPlayer = NarrowPlayer(ID: 1, NAME: "Bobby")
            
            let changes = newPlayer.databaseChanges(from: oldPlayer)
            XCTAssertEqual(changes.count, 1)
            XCTAssertEqual(changes["NAME"]!, "Arthur".databaseValue)
            
            try dbQueue.inTransaction { db in
                try oldPlayer.insert(db)
                let totalChangesCount = db.totalChangesCount
                try XCTAssertTrue(newPlayer.updateChanges(db, from: oldPlayer))
                XCTAssertEqual(db.totalChangesCount, totalChangesCount + 1)
                XCTAssertEqual(lastSQLQuery, "UPDATE \"players\" SET \"name\"='Bobby' WHERE \"id\"=1")
                return .rollback
            }
        }
    }
    
    func testUpdateChangesWithRecord() throws {
        class MyRecord: Record {
            var id: Int64?
            var firstName: String?
            var lastName: String?
            
            init(id: Int64?, firstName: String?, lastName: String?) {
                self.id = id
                self.firstName = firstName
                self.lastName = lastName
                super.init()
            }
            
            override class var databaseTableName: String {
                "myRecord"
            }
            
            enum Columns: String, ColumnExpression {
                case id, firstName, lastName
            }
            
            required init(row: Row) throws {
                id = try row[Columns.id]
                firstName = try row[Columns.firstName]
                lastName = try row[Columns.lastName]
                try super.init(row: row)
            }
            
            override func encode(to container: inout PersistenceContainer) {
                container[Columns.id] = id
                container[Columns.firstName] = firstName
                container[Columns.lastName] = lastName
            }
            
            override func didInsert(with rowID: Int64, for column: String?) {
                id = rowID
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "myRecord") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("firstName", .text)
                t.column("lastName", .text)
            }
            
            // This `let` is part of the test
            let record = MyRecord(id: nil, firstName: "Arthur", lastName: "Smith")
            try record.insert(db)
            
            do {
                sqlQueries = []
                let modified = try record.updateChanges(db) { _ in }
                XCTAssertFalse(modified)
                XCTAssert(sqlQueries.isEmpty)
            }
            
            do {
                sqlQueries = []
                let modified = try record.updateChanges(db) {
                    $0.firstName = "Arthur"
                }
                XCTAssertFalse(modified)
                XCTAssert(sqlQueries.isEmpty)
            }
            
            do {
                sqlQueries = []
                let modified = try record.updateChanges(db) {
                    $0.firstName = nil
                }
                XCTAssertEqual(record.firstName, nil)
                XCTAssertEqual(record.lastName, "Smith")
                XCTAssertTrue(modified)
                XCTAssertEqual(lastSQLQuery, "UPDATE \"myRecord\" SET \"firstName\"=NULL WHERE \"id\"=1")
            }
            
            do {
                sqlQueries = []
                let modified = try record.updateChanges(db) {
                    $0.firstName = "Bob"
                    $0.lastName = "Johnson"
                }
                XCTAssertEqual(record.firstName, "Bob")
                XCTAssertEqual(record.lastName, "Johnson")
                XCTAssertTrue(modified)
                XCTAssertTrue([
                    "UPDATE \"myRecord\" SET \"firstName\"=\'Bob\', \"lastName\"=\'Johnson\' WHERE \"id\"=1",
                    "UPDATE \"myRecord\" SET \"lastName\"=\'Johnson\', \"firstName\"=\'Bob\' WHERE \"id\"=1"]
                    .contains(lastSQLQuery))
            }
        }
    }
    
    func testUpdateChangesWithNonRecordClass() throws {
        class MyRecord: Codable, PersistableRecord {
            var id: Int64?
            var firstName: String?
            var lastName: String?
            
            init(id: Int64?, firstName: String?, lastName: String?) {
                self.id = id
                self.firstName = firstName
                self.lastName = lastName
            }
            
            func didInsert(with rowID: Int64, for column: String?) {
                id = rowID
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "myRecord") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("firstName", .text)
                t.column("lastName", .text)
            }
            
            // This `let` is part of the test
            let record = MyRecord(id: nil, firstName: "Arthur", lastName: "Smith")
            try record.insert(db)
            
            do {
                sqlQueries = []
                let modified = try record.updateChanges(db) { _ in }
                XCTAssertFalse(modified)
                XCTAssert(sqlQueries.isEmpty)
            }
            
            do {
                sqlQueries = []
                let modified = try record.updateChanges(db) {
                    $0.firstName = "Arthur"
                }
                XCTAssertFalse(modified)
                XCTAssert(sqlQueries.isEmpty)
            }
            
            do {
                sqlQueries = []
                let modified = try record.updateChanges(db) {
                    $0.firstName = nil
                }
                XCTAssertEqual(record.firstName, nil)
                XCTAssertEqual(record.lastName, "Smith")
                XCTAssertTrue(modified)
                XCTAssertEqual(lastSQLQuery, "UPDATE \"myRecord\" SET \"firstName\"=NULL WHERE \"id\"=1")
            }
            
            do {
                sqlQueries = []
                let modified = try record.updateChanges(db) {
                    $0.firstName = "Bob"
                    $0.lastName = "Johnson"
                }
                XCTAssertEqual(record.firstName, "Bob")
                XCTAssertEqual(record.lastName, "Johnson")
                XCTAssertTrue(modified)
                XCTAssertTrue([
                    "UPDATE \"myRecord\" SET \"firstName\"=\'Bob\', \"lastName\"=\'Johnson\' WHERE \"id\"=1",
                    "UPDATE \"myRecord\" SET \"lastName\"=\'Johnson\', \"firstName\"=\'Bob\' WHERE \"id\"=1"]
                    .contains(lastSQLQuery))
            }
        }
    }
    
    func testUpdateChangesWithMutableStruct() throws {
        struct MyRecord: Codable, MutablePersistableRecord {
            var id: Int64?
            var firstName: String?
            var lastName: String?
            
            mutating func didInsert(with rowID: Int64, for column: String?) {
                id = rowID
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "myRecord") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("firstName", .text)
                t.column("lastName", .text)
            }
            
            var record = MyRecord(id: nil, firstName: "Arthur", lastName: "Smith")
            try record.insert(db)
            
            do {
                sqlQueries = []
                let modified = try record.updateChanges(db) { _ in }
                XCTAssertFalse(modified)
                XCTAssert(sqlQueries.isEmpty)
            }
            
            do {
                sqlQueries = []
                let modified = try record.updateChanges(db) {
                    $0.firstName = "Arthur"
                }
                XCTAssertFalse(modified)
                XCTAssert(sqlQueries.isEmpty)
            }
            
            do {
                sqlQueries = []
                let modified = try record.updateChanges(db) {
                    $0.firstName = nil
                }
                XCTAssertEqual(record.firstName, nil)
                XCTAssertEqual(record.lastName, "Smith")
                XCTAssertTrue(modified)
                XCTAssertEqual(lastSQLQuery, "UPDATE \"myRecord\" SET \"firstName\"=NULL WHERE \"id\"=1")
            }
            
            do {
                sqlQueries = []
                let modified = try record.updateChanges(db) {
                    $0.firstName = "Bob"
                    $0.lastName = "Johnson"
                }
                XCTAssertEqual(record.firstName, "Bob")
                XCTAssertEqual(record.lastName, "Johnson")
                XCTAssertTrue(modified)
                XCTAssertTrue([
                    "UPDATE \"myRecord\" SET \"firstName\"=\'Bob\', \"lastName\"=\'Johnson\' WHERE \"id\"=1",
                    "UPDATE \"myRecord\" SET \"lastName\"=\'Johnson\', \"firstName\"=\'Bob\' WHERE \"id\"=1"]
                    .contains(lastSQLQuery))
            }
        }
    }
    
    func testUpdateChangesWithImmutableStruct() throws {
        struct MyRecord: Codable, PersistableRecord {
            var id: Int64
            var firstName: String?
            var lastName: String?
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "myRecord") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("firstName", .text)
                t.column("lastName", .text)
            }
            
            var record = MyRecord(id: 1, firstName: "Arthur", lastName: "Smith")
            try record.insert(db)
            
            do {
                sqlQueries = []
                let modified = try record.updateChanges(db) { _ in }
                XCTAssertFalse(modified)
                XCTAssert(sqlQueries.isEmpty)
            }
            
            do {
                sqlQueries = []
                let modified = try record.updateChanges(db) {
                    $0.firstName = "Arthur"
                }
                XCTAssertFalse(modified)
                XCTAssert(sqlQueries.isEmpty)
            }
            
            do {
                sqlQueries = []
                let modified = try record.updateChanges(db) {
                    $0.firstName = nil
                }
                XCTAssertEqual(record.firstName, nil)
                XCTAssertEqual(record.lastName, "Smith")
                XCTAssertTrue(modified)
                XCTAssertEqual(lastSQLQuery, "UPDATE \"myRecord\" SET \"firstName\"=NULL WHERE \"id\"=1")
            }
            
            do {
                sqlQueries = []
                let modified = try record.updateChanges(db) {
                    $0.firstName = "Bob"
                    $0.lastName = "Johnson"
                }
                XCTAssertEqual(record.firstName, "Bob")
                XCTAssertEqual(record.lastName, "Johnson")
                XCTAssertTrue(modified)
                XCTAssertTrue([
                    "UPDATE \"myRecord\" SET \"firstName\"=\'Bob\', \"lastName\"=\'Johnson\' WHERE \"id\"=1",
                    "UPDATE \"myRecord\" SET \"lastName\"=\'Johnson\', \"firstName\"=\'Bob\' WHERE \"id\"=1"]
                    .contains(lastSQLQuery))
            }
        }
    }
}

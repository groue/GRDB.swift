import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    #if SWIFT_PACKAGE
        import CSQLite
    #else
        import SQLite3
    #endif
    import GRDB
#endif

class ValueObservationFetchTests: GRDBTestCase {
    override func setup(_ dbWriter: DatabaseWriter) throws {
        try dbWriter.write { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text)
            }
            try db.execute(sql: """
                INSERT INTO player (name) VALUES ('Arthur');
                INSERT INTO player (name) VALUES ('Barbara');
                INSERT INTO player (name) VALUES (NULL);
                """)
        }
    }
    
    func testFetchCount() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            let request = SQLRequest<Row>(sql: "SELECT * FROM player")
            let observation = ValueObservation.trackingCount(request)
            let count = try observation.fetch(db)
            XCTAssertEqual(count, 3)
        }
    }
    
    func testFetchRow() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            do {
                let request = SQLRequest<Row>(sql: "SELECT * FROM player WHERE NULL")
                let observation = ValueObservation.trackingOne(request)
                let row = try observation.fetch(db)
                XCTAssertNil(row)
            }
            do {
                let request = SQLRequest<Row>(sql: "SELECT * FROM player ORDER BY id")
                let observation = ValueObservation.trackingOne(request)
                let row = try observation.fetch(db)
                XCTAssertEqual(row, ["id": 1, "name": "Arthur"])
            }
            do {
                let request = SQLRequest<Row>(sql: "SELECT * FROM player ORDER BY id")
                let observation = ValueObservation.trackingAll(request)
                let rows = try observation.fetch(db)
                XCTAssertEqual(rows, [
                    ["id": 1, "name": "Arthur"],
                    ["id": 2, "name": "Barbara"],
                    ["id": 3, "name": nil],
                    ])
            }
        }
    }
    
    func testFetchDatabaseValueConvertible() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            do {
                let request = SQLRequest<String>(sql: "SELECT name FROM player WHERE NULL")
                let observation = ValueObservation.trackingOne(request)
                let name = try observation.fetch(db)
                XCTAssertNil(name)
            }
            do {
                let request = SQLRequest<String>(sql: "SELECT name FROM player WHERE name IS NULL")
                let observation = ValueObservation.trackingOne(request)
                let name = try observation.fetch(db)
                XCTAssertNil(name)
            }
            do {
                let request = SQLRequest<String>(sql: "SELECT name FROM player WHERE name IS NOT NULL ORDER BY id")
                let observation = ValueObservation.trackingOne(request)
                let name = try observation.fetch(db)
                XCTAssertEqual(name, "Arthur")
            }
            do {
                let request = SQLRequest<String>(sql: "SELECT name FROM player WHERE name IS NOT NULL ORDER BY id")
                let observation = ValueObservation.trackingAll(request)
                let names = try observation.fetch(db)
                XCTAssertEqual(names, ["Arthur", "Barbara"])
            }
            do {
                let request = SQLRequest<String?>(sql: "SELECT name FROM player ORDER BY id")
                let observation = ValueObservation.trackingAll(request)
                let names = try observation.fetch(db)
                XCTAssertEqual(names, ["Arthur", "Barbara", nil])
            }
        }
    }
    
    func testFetchFetchableRecord() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            struct Player: FetchableRecord, TableRecord, Equatable {
                var id: Int64
                var name: String?
                
                init(id: Int64, name: String?) {
                    self.id = id
                    self.name = name
                }
                
                init(row: Row) {
                    id = row["id"]
                    name = row["name"]
                }
            }
            do {
                let request = Player.none()
                let observation = ValueObservation.trackingOne(request)
                let player = try observation.fetch(db)
                XCTAssertNil(player)
            }
            do {
                let request = Player.orderByPrimaryKey()
                let observation = ValueObservation.trackingOne(request)
                let player = try observation.fetch(db)
                XCTAssertEqual(player, Player(id: 1, name: "Arthur"))
            }
            do {
                let request = Player.orderByPrimaryKey()
                let observation = ValueObservation.trackingAll(request)
                let players = try observation.fetch(db)
                XCTAssertEqual(players, [
                    Player(id: 1, name: "Arthur"),
                    Player(id: 2, name: "Barbara"),
                    Player(id: 3, name: nil),
                    ])
            }
        }
    }
    
    func testFetchMap() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            do {
                let request = SQLRequest<Row>(sql: "SELECT * FROM player ORDER BY id")
                let observation = ValueObservation
                    .trackingAll(request)
                    .map { rows in rows.map { row in row["id"] as Int64 } }
                let ids = try observation.fetch(db)
                XCTAssertEqual(ids, [1, 2, 3])
            }
        }
    }
    
    func testFetchCombine() throws {
        dbConfiguration.trace = { print($0) }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            struct Player: FetchableRecord, TableRecord, Equatable, Codable {
                var id: Int64
                var name: String?
            }
            do {
                let request1 = Player.filter(key: 1)
                let request2 = Player.filter(key: 2)
                let observation1 = ValueObservation.trackingOne(request1)
                let observation2 = ValueObservation.trackingOne(request2)
                let observation = ValueObservation.combine(observation1, observation2)
                let players = try observation.fetch(db)
                XCTAssertEqual(players.0, Player(id: 1, name: "Arthur"))
                XCTAssertEqual(players.1, Player(id: 2, name: "Barbara"))
            }
        }
    }
    
    func testFetchCompactMap() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            do {
                let request = SQLRequest<Row>(sql: "SELECT * FROM player ORDER BY id")
                let observation = ValueObservation
                    .trackingOne(request)
                    .compactMap { row -> Row? in nil }
                let row = try observation.fetchFirst(db)
                XCTAssertNil(row)
            }
        }
    }
}

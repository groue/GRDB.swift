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
            let count: Int = try observation.fetch(db)
            XCTAssertEqual(count, 3)
        }
    }
    
    func testFetchRow() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            do {
                let request = SQLRequest<Row>(sql: "SELECT * FROM player WHERE NULL")
                let observation = ValueObservation.trackingOne(request)
                let row: Row? = try observation.fetch(db)
                XCTAssertNil(row)
            }
            do {
                let request = SQLRequest<Row>(sql: "SELECT * FROM player ORDER BY id")
                let observation = ValueObservation.trackingOne(request)
                let row: Row? = try observation.fetch(db)
                XCTAssertEqual(row, ["id": 1, "name": "Arthur"])
            }
            do {
                let request = SQLRequest<Row>(sql: "SELECT * FROM player ORDER BY id")
                let observation = ValueObservation.trackingAll(request)
                let rows: [Row] = try observation.fetch(db)
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
                let name: String? = try observation.fetch(db)
                XCTAssertNil(name)
            }
            do {
                let request = SQLRequest<String>(sql: "SELECT name FROM player WHERE name IS NULL")
                let observation = ValueObservation.trackingOne(request)
                let name: String? = try observation.fetch(db)
                XCTAssertNil(name)
            }
            do {
                let request = SQLRequest<String>(sql: "SELECT name FROM player WHERE name IS NOT NULL ORDER BY id")
                let observation = ValueObservation.trackingOne(request)
                let name: String? = try observation.fetch(db)
                XCTAssertEqual(name, "Arthur")
            }
            do {
                let request = SQLRequest<String>(sql: "SELECT name FROM player WHERE name IS NOT NULL ORDER BY id")
                let observation = ValueObservation.trackingAll(request)
                let names: [String] = try observation.fetch(db)
                XCTAssertEqual(names, ["Arthur", "Barbara"])
            }
            do {
                let request = SQLRequest<String?>(sql: "SELECT name FROM player ORDER BY id")
                let observation = ValueObservation.trackingAll(request)
                let names: [String?] = try observation.fetch(db)
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
                let player: Player? = try observation.fetch(db)
                XCTAssertNil(player)
            }
            do {
                let request = Player.orderByPrimaryKey()
                let observation = ValueObservation.trackingOne(request)
                let player: Player? = try observation.fetch(db)
                XCTAssertEqual(player, Player(id: 1, name: "Arthur"))
            }
            do {
                let request = Player.orderByPrimaryKey()
                let observation = ValueObservation.trackingAll(request)
                let players: [Player] = try observation.fetch(db)
                XCTAssertEqual(players, [
                    Player(id: 1, name: "Arthur"),
                    Player(id: 2, name: "Barbara"),
                    Player(id: 3, name: nil),
                    ])
            }
        }
    }
}

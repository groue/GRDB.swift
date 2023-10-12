import XCTest
import GRDB

private final class TestStream: TextOutputStream {
    var output: String
    
    init() {
        output = ""
    }
    
    func write(_ string: String) {
        output.append(string)
    }
}

private struct Player: Codable, MutablePersistableRecord {
    var id: Int64?
    var name: String
    var teamId: String?
    
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

private struct Team: Codable, PersistableRecord {
    var id: String
    var name: String
    var color: String
}

final class DatabaseReaderDumpTests: GRDBTestCase {
    func test_dumpSQL() throws {
        do {
            // Default format
            let stream = TestStream()
            try makeDatabaseQueue().dumpSQL(
                """
                CREATE TABLE t(a, b);
                INSERT INTO t VALUES (1, 'foo');
                INSERT INTO t VALUES (2, 'bar');
                SELECT * FROM t ORDER BY a;
                SELECT b FROM t ORDER BY b;
                SELECT NULL WHERE NULL;
                """,
                to: stream)
            XCTAssertEqual(stream.output, """
                1|foo
                2|bar
                bar
                foo
                
                """)
        }
        do {
            // Custom format
            let stream = TestStream()
            try makeDatabaseQueue().dumpSQL(
                """
                CREATE TABLE t(a, b);
                INSERT INTO t VALUES (1, 'foo');
                INSERT INTO t VALUES (2, 'bar');
                SELECT * FROM t ORDER BY a;
                SELECT b FROM t ORDER BY b;
                SELECT NULL WHERE NULL;
                """,
                format: .json(),
                to: stream)
            XCTAssertEqual(stream.output, """
                [{"a":1,"b":"foo"},
                {"a":2,"b":"bar"}]
                [{"b":"bar"},
                {"b":"foo"}]
                []
                
                """)
        }
    }
    
    func test_dumpRequest() throws {
        do {
            // Default format
            let stream = TestStream()
            try makeRugbyDatabase().dumpRequest(Player.orderByPrimaryKey(), to: stream)
            XCTAssertEqual(stream.output, """
                1|FRA|Antoine Dupond
                2|ENG|Owen Farrell
                3||Gwendal Roué
                
                """)
        }
        do {
            // Custom format
            let stream = TestStream()
            try makeRugbyDatabase().dumpRequest(Player.orderByPrimaryKey(), format: .json(), to: stream)
            XCTAssertEqual(stream.output, """
                [{"id":1,"teamId":"FRA","name":"Antoine Dupond"},
                {"id":2,"teamId":"ENG","name":"Owen Farrell"},
                {"id":3,"teamId":null,"name":"Gwendal Roué"}]
                
                """)
        }
    }
    
    func test_dumpTables() throws {
        do {
            // Default format
            let stream = TestStream()
            try makeRugbyDatabase().dumpTables(["player", "team"], to: stream)
            XCTAssertEqual(stream.output, """
                player
                1|FRA|Antoine Dupond
                2|ENG|Owen Farrell
                3||Gwendal Roué
                
                team
                ENG|England Rugby|white
                FRA|XV de France|blue
                
                """)
        }
        do {
            // Custom format
            let stream = TestStream()
            try makeRugbyDatabase().dumpTables(["team", "player"], format: .json(), to: stream)
            XCTAssertEqual(stream.output, """
                team
                [{"id":"ENG","name":"England Rugby","color":"white"},
                {"id":"FRA","name":"XV de France","color":"blue"}]
                
                player
                [{"id":1,"teamId":"FRA","name":"Antoine Dupond"},
                {"id":2,"teamId":"ENG","name":"Owen Farrell"},
                {"id":3,"teamId":null,"name":"Gwendal Roué"}]
                
                """)
        }
    }
    
    func test_dumpContent() throws {
        do {
            // Default format
            let stream = TestStream()
            try makeRugbyDatabase().dumpContent(to: stream)
            XCTAssertEqual(stream.output, """
                sqlite_master
                CREATE TABLE "player" ("id" INTEGER PRIMARY KEY AUTOINCREMENT, "teamId" TEXT REFERENCES "team"("id"), "name" TEXT NOT NULL);
                CREATE INDEX "player_on_teamId" ON "player"("teamId");
                CREATE TABLE "team" ("id" TEXT PRIMARY KEY NOT NULL, "name" TEXT NOT NULL, "color" TEXT NOT NULL);
                
                player
                1|FRA|Antoine Dupond
                2|ENG|Owen Farrell
                3||Gwendal Roué

                team
                ENG|England Rugby|white
                FRA|XV de France|blue
                
                """)
        }
        do {
            // Custom format
            let stream = TestStream()
            try makeRugbyDatabase().dumpContent(format: .json(), to: stream)
            XCTAssertEqual(stream.output, """
                sqlite_master
                CREATE TABLE "player" ("id" INTEGER PRIMARY KEY AUTOINCREMENT, "teamId" TEXT REFERENCES "team"("id"), "name" TEXT NOT NULL);
                CREATE INDEX "player_on_teamId" ON "player"("teamId");
                CREATE TABLE "team" ("id" TEXT PRIMARY KEY NOT NULL, "name" TEXT NOT NULL, "color" TEXT NOT NULL);
                
                player
                [{"id":1,"teamId":"FRA","name":"Antoine Dupond"},
                {"id":2,"teamId":"ENG","name":"Owen Farrell"},
                {"id":3,"teamId":null,"name":"Gwendal Roué"}]
                
                team
                [{"id":"ENG","name":"England Rugby","color":"white"},
                {"id":"FRA","name":"XV de France","color":"blue"}]
                
                """)
        }
    }
    
    private func makeRugbyDatabase() throws -> DatabaseQueue {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "team") { t in
                t.primaryKey("id", .text)
                t.column("name", .text).notNull()
                t.column("color", .text).notNull()
            }
            
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.belongsTo("team")
                t.column("name", .text).notNull()
            }
            
            let england = Team(id: "ENG", name: "England Rugby", color: "white")
            let france = Team(id: "FRA", name: "XV de France", color: "blue")
            
            try england.insert(db)
            try france.insert(db)
            
            _ = try Player(name: "Antoine Dupond", teamId: france.id).inserted(db)
            _ = try Player(name: "Owen Farrell", teamId: england.id).inserted(db)
            _ = try Player(name: "Gwendal Roué", teamId: nil).inserted(db)
        }
        return dbQueue
    }
}

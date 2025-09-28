import XCTest
import GRDB

private struct Player: Codable, Identifiable, PersistableRecord, FetchableRecord, Hashable {
    var id: Int64
    var name: String
    var score: Int
    var bonus: Int
    
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let name = Column(CodingKeys.name)
        static let score = Column(CodingKeys.score)
        static let bonus = Column(CodingKeys.bonus)
    }
    
    static func createTable(_ db: Database) throws {
        try db.create(table: "player") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("name", .text)
            t.column("score", .integer)
            t.column("bonus", .integer)
        }
    }
}

private struct PlayerView: Codable, Identifiable, PersistableRecord, FetchableRecord, Hashable {
    var id: Int64
    var name: String
    var score: Int
    var bonus: Int
    
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let name = Column(CodingKeys.name)
        static let score = Column(CodingKeys.score)
        static let bonus = Column(CodingKeys.bonus)
    }
    
    static func createTable(_ db: Database) throws {
        try db.execute(sql: """
            CREATE VIEW playerView AS SELECT * FROM player;
            -- Insert trigger
            CREATE TRIGGER playerView_insert
            INSTEAD OF INSERT ON playerView
            BEGIN
              INSERT INTO player (id, name, score, bonus)
              VALUES (NEW.id, NEW.name, NEW.score, NEW.bonus);
            END;
            -- Update trigger
            CREATE TRIGGER playerView_update
            INSTEAD OF UPDATE ON playerView
            BEGIN
              UPDATE player SET name = NEW.name, score = NEW.score, bonus = NEW.bonus
              WHERE id = OLD.id;
            END;
            """)
    }
}

private struct ViewSchemaSource: DatabaseSchemaSource {
    func columnsForPrimaryKey(_ db: Database, inView view: DatabaseObjectID) throws -> [String]? {
        ["id"]
    }
}

private typealias Columns = Player.Columns

private extension QueryInterfaceRequest<Player> {
    func incrementScore(_ db: Database) throws {
        try updateAll(db) { $0.score += 1 }
    }
}

class TableRecordUpdateTests: GRDBTestCase {
    func testRequestUpdateAll_table() throws {
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            let assignment = Columns.score.set(to: 0)
            
            try Player.updateAll(db, assignment)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = 0
                """)
            
            try Player.filter { $0.name == "Arthur" }.updateAll(db, assignment)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = 0 WHERE \"name\" = 'Arthur'
                """)
            
            try Player.filter(key: 1).updateAll(db, assignment)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = 0 WHERE "id" = 1
                """)
            
            try Player.filter(keys: [1, 2]).updateAll(db, assignment)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = 0 WHERE "id" IN (1, 2)
                """)
            
            try Player.filter(id: 1).updateAll(db, assignment)
            XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "player" SET "score" = 0 WHERE "id" = 1
                    """)
            
            try Player.filter(ids: [1, 2]).updateAll(db, assignment)
            XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "player" SET "score" = 0 WHERE "id" IN (1, 2)
                    """)
            
            try Player.filter(sql: "id = 1").updateAll(db, assignment)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = 0 WHERE id = 1
                """)
            
            try Player.filter(sql: "id = 1").filter { $0.name == "Arthur" }.updateAll(db, assignment)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = 0 WHERE (id = 1) AND (\"name\" = 'Arthur')
                """)
            
            try Player.select { $0.name }.updateAll(db, assignment)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = 0
                """)
            
            try Player.order { $0.name }.updateAll(db, assignment)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = 0
                """)
            
            if try String.fetchCursor(db, sql: "PRAGMA COMPILE_OPTIONS").contains("ENABLE_UPDATE_DELETE_LIMIT") {
                try Player.limit(1).updateAll(db, assignment)
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "player" SET "score" = 0 LIMIT 1
                    """)
                
                try Player.order { $0.name }.updateAll(db, assignment)
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "player" SET "score" = 0
                    """)
                
                try Player.order { $0.name }.limit(1).updateAll(db, assignment)
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "player" SET "score" = 0 ORDER BY \"name\" LIMIT 1
                    """)
                
                try Player.order { $0.name }.limit(1, offset: 2).reversed().updateAll(db, assignment)
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "player" SET "score" = 0 ORDER BY \"name\" DESC LIMIT 1 OFFSET 2
                    """)
                
                try Player.limit(1, offset: 2).reversed().updateAll(db, assignment)
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "player" SET "score" = 0 LIMIT 1 OFFSET 2
                    """)
            }
        }
    }
    
    func testRequestUpdateAll_view() throws {
        // Views need a schema source
        dbConfiguration.schemaSource = ViewSchemaSource()
        
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            try PlayerView.createTable(db)
            let assignment = Columns.score.set(to: 0)
            
            try PlayerView.updateAll(db, assignment)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "playerView" SET "score" = 0
                """)
            
            try PlayerView.filter { $0.name == "Arthur" }.updateAll(db, assignment)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "playerView" SET "score" = 0 WHERE \"name\" = 'Arthur'
                """)
            
            try PlayerView.filter(key: 1).updateAll(db, assignment)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "playerView" SET "score" = 0 WHERE "id" = 1
                """)
            
            try PlayerView.filter(keys: [1, 2]).updateAll(db, assignment)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "playerView" SET "score" = 0 WHERE "id" IN (1, 2)
                """)
            
            try PlayerView.filter(id: 1).updateAll(db, assignment)
            XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "playerView" SET "score" = 0 WHERE "id" = 1
                    """)
            
            try PlayerView.filter(ids: [1, 2]).updateAll(db, assignment)
            XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "playerView" SET "score" = 0 WHERE "id" IN (1, 2)
                    """)
            
            try PlayerView.filter(sql: "id = 1").updateAll(db, assignment)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "playerView" SET "score" = 0 WHERE id = 1
                """)
            
            try PlayerView.filter(sql: "id = 1").filter { $0.name == "Arthur" }.updateAll(db, assignment)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "playerView" SET "score" = 0 WHERE (id = 1) AND (\"name\" = 'Arthur')
                """)
            
            try PlayerView.select { $0.name }.updateAll(db, assignment)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "playerView" SET "score" = 0
                """)
            
            try PlayerView.order { $0.name }.updateAll(db, assignment)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "playerView" SET "score" = 0
                """)
            
            if try String.fetchCursor(db, sql: "PRAGMA COMPILE_OPTIONS").contains("ENABLE_UPDATE_DELETE_LIMIT") {
                try PlayerView.limit(1).updateAll(db, assignment)
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "playerView" SET "score" = 0 LIMIT 1
                    """)
                
                try PlayerView.order { $0.name }.updateAll(db, assignment)
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "playerView" SET "score" = 0
                    """)
                
                try PlayerView.order { $0.name }.limit(1).updateAll(db, assignment)
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "playerView" SET "score" = 0 ORDER BY \"name\" LIMIT 1
                    """)
                
                try PlayerView.order { $0.name }.limit(1, offset: 2).reversed().updateAll(db, assignment)
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "playerView" SET "score" = 0 ORDER BY \"name\" DESC LIMIT 1 OFFSET 2
                    """)
                
                try PlayerView.limit(1, offset: 2).reversed().updateAll(db, assignment)
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "playerView" SET "score" = 0 LIMIT 1 OFFSET 2
                    """)
            }
        }
    }
    
    func testRequestUpdateAll_DatabaseComponents_table() throws {
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            
            try Player.updateAll(db) { $0.score.set(to: 0) }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = 0
                """)
            
            try Player.filter { $0.name == "Arthur" }.updateAll(db) { $0.score.set(to: 0) }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = 0 WHERE \"name\" = 'Arthur'
                """)
            
            try Player.filter(key: 1).updateAll(db) { $0.score.set(to: 0) }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = 0 WHERE "id" = 1
                """)
            
            try Player.filter(keys: [1, 2]).updateAll(db) { $0.score.set(to: 0) }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = 0 WHERE "id" IN (1, 2)
                """)
            
            try Player.filter(id: 1).updateAll(db) { $0.score.set(to: 0) }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = 0 WHERE "id" = 1
                """)
            
            try Player.filter(ids: [1, 2]).updateAll(db) { $0.score.set(to: 0) }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = 0 WHERE "id" IN (1, 2)
                """)
            
            try Player.filter(sql: "id = 1").updateAll(db) { $0.score.set(to: 0) }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = 0 WHERE id = 1
                """)
            
            try Player.filter(sql: "id = 1").filter { $0.name == "Arthur" }.updateAll(db) { $0.score.set(to: 0) }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = 0 WHERE (id = 1) AND (\"name\" = 'Arthur')
                """)
            
            try Player.select { $0.name }.updateAll(db) { $0.score.set(to: 0) }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = 0
                """)
            
            try Player.order { $0.name }.updateAll(db) { $0.score.set(to: 0) }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = 0
                """)
            
            if try String.fetchCursor(db, sql: "PRAGMA COMPILE_OPTIONS").contains("ENABLE_UPDATE_DELETE_LIMIT") {
                try Player.limit(1).updateAll(db) { $0.score.set(to: 0) }
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "player" SET "score" = 0 LIMIT 1
                    """)
                
                try Player.order { $0.name }.updateAll(db) { $0.score.set(to: 0) }
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "player" SET "score" = 0
                    """)
                
                try Player.order { $0.name }.limit(1).updateAll(db) { $0.score.set(to: 0) }
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "player" SET "score" = 0 ORDER BY \"name\" LIMIT 1
                    """)
                
                try Player.order { $0.name }.limit(1, offset: 2).reversed().updateAll(db) { $0.score.set(to: 0) }
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "player" SET "score" = 0 ORDER BY \"name\" DESC LIMIT 1 OFFSET 2
                    """)
                
                try Player.limit(1, offset: 2).reversed().updateAll(db) { $0.score.set(to: 0) }
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "player" SET "score" = 0 LIMIT 1 OFFSET 2
                    """)
            }
        }
    }
    
    func testRequestUpdateAll_DatabaseComponents_view() throws {
        // Views need a schema source
        dbConfiguration.schemaSource = ViewSchemaSource()
        
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            try PlayerView.createTable(db)
            
            try PlayerView.updateAll(db) { $0.score.set(to: 0) }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "playerView" SET "score" = 0
                """)
            
            try PlayerView.filter { $0.name == "Arthur" }.updateAll(db) { $0.score.set(to: 0) }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "playerView" SET "score" = 0 WHERE \"name\" = 'Arthur'
                """)
            
            try PlayerView.filter(key: 1).updateAll(db) { $0.score.set(to: 0) }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "playerView" SET "score" = 0 WHERE "id" = 1
                """)
            
            try PlayerView.filter(keys: [1, 2]).updateAll(db) { $0.score.set(to: 0) }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "playerView" SET "score" = 0 WHERE "id" IN (1, 2)
                """)
            
            try PlayerView.filter(id: 1).updateAll(db) { $0.score.set(to: 0) }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "playerView" SET "score" = 0 WHERE "id" = 1
                """)
            
            try PlayerView.filter(ids: [1, 2]).updateAll(db) { $0.score.set(to: 0) }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "playerView" SET "score" = 0 WHERE "id" IN (1, 2)
                """)
            
            try PlayerView.filter(sql: "id = 1").updateAll(db) { $0.score.set(to: 0) }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "playerView" SET "score" = 0 WHERE id = 1
                """)
            
            try PlayerView.filter(sql: "id = 1").filter { $0.name == "Arthur" }.updateAll(db) { $0.score.set(to: 0) }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "playerView" SET "score" = 0 WHERE (id = 1) AND (\"name\" = 'Arthur')
                """)
            
            try PlayerView.select { $0.name }.updateAll(db) { $0.score.set(to: 0) }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "playerView" SET "score" = 0
                """)
            
            try PlayerView.order { $0.name }.updateAll(db) { $0.score.set(to: 0) }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "playerView" SET "score" = 0
                """)
            
            if try String.fetchCursor(db, sql: "PRAGMA COMPILE_OPTIONS").contains("ENABLE_UPDATE_DELETE_LIMIT") {
                try PlayerView.limit(1).updateAll(db) { $0.score.set(to: 0) }
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "playerView" SET "score" = 0 LIMIT 1
                    """)
                
                try PlayerView.order { $0.name }.updateAll(db) { $0.score.set(to: 0) }
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "playerView" SET "score" = 0
                    """)
                
                try PlayerView.order { $0.name }.limit(1).updateAll(db) { $0.score.set(to: 0) }
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "playerView" SET "score" = 0 ORDER BY \"name\" LIMIT 1
                    """)
                
                try PlayerView.order { $0.name }.limit(1, offset: 2).reversed().updateAll(db) { $0.score.set(to: 0) }
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "playerView" SET "score" = 0 ORDER BY \"name\" DESC LIMIT 1 OFFSET 2
                    """)
                
                try PlayerView.limit(1, offset: 2).reversed().updateAll(db) { $0.score.set(to: 0) }
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "playerView" SET "score" = 0 LIMIT 1 OFFSET 2
                    """)
            }
        }
    }
    
    func testRequestUpdateAndFetchStatement_table() throws {
#if GRDBCUSTOMSQLITE || SQLITE_HAS_CODEC
        guard Database.sqliteLibVersionNumber >= 3035000 else {
            throw XCTSkip("RETURNING clause is not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("RETURNING clause is not available")
        }
#endif
        
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            let assignment = Columns.score.set(to: 0)
            
            do {
                let request = Player.all()
                let statement = try request.updateAndFetchStatement(db, [assignment], selection: [Column("score")])
                XCTAssertEqual(statement.sql, "UPDATE \"player\" SET \"score\" = ? RETURNING \"score\"")
                XCTAssertEqual(statement.arguments, [0])
                XCTAssertEqual(statement.columnNames, ["score"])
            }
            do {
                let request = Player.all()
                let statement = try request.updateAndFetchStatement(db, [assignment], selection: [.allColumns])
                XCTAssertEqual(statement.sql, "UPDATE \"player\" SET \"score\" = ? RETURNING *")
                XCTAssertEqual(statement.arguments, [0])
                XCTAssertEqual(statement.columnNames, ["id", "name", "score", "bonus"])
            }
            do {
                let request = Player.all()
                let statement = try request.updateAndFetchStatement(db, [assignment], selection: [.allColumns(excluding: ["name"])])
                XCTAssertEqual(statement.sql, "UPDATE \"player\" SET \"score\" = ? RETURNING \"id\", \"score\", \"bonus\"")
                XCTAssertEqual(statement.arguments, [0])
                XCTAssertEqual(statement.columnNames, ["id", "score", "bonus"])
            }
        }
    }
    
    func testRequestUpdateAndFetchStatement_view() throws {
#if GRDBCUSTOMSQLITE || SQLITE_HAS_CODEC
        guard Database.sqliteLibVersionNumber >= 3035000 else {
            throw XCTSkip("RETURNING clause is not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("RETURNING clause is not available")
        }
#endif
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            try PlayerView.createTable(db)
            let assignment = Columns.score.set(to: 0)
            
            do {
                let request = PlayerView.all()
                let statement = try request.updateAndFetchStatement(db, [assignment], selection: [Column("score")])
                XCTAssertEqual(statement.sql, "UPDATE \"playerView\" SET \"score\" = ? RETURNING \"score\"")
                XCTAssertEqual(statement.arguments, [0])
                XCTAssertEqual(statement.columnNames, ["score"])
            }
            do {
                let request = PlayerView.all()
                let statement = try request.updateAndFetchStatement(db, [assignment], selection: [.allColumns])
                XCTAssertEqual(statement.sql, "UPDATE \"playerView\" SET \"score\" = ? RETURNING *")
                XCTAssertEqual(statement.arguments, [0])
                XCTAssertEqual(statement.columnNames, ["id", "name", "score", "bonus"])
            }
            do {
                let request = PlayerView.all()
                let statement = try request.updateAndFetchStatement(db, [assignment], selection: [.allColumns(excluding: ["name"])])
                XCTAssertEqual(statement.sql, "UPDATE \"playerView\" SET \"score\" = ? RETURNING \"id\", \"score\", \"bonus\"")
                XCTAssertEqual(statement.arguments, [0])
                XCTAssertEqual(statement.columnNames, ["id", "score", "bonus"])
            }
        }
    }
    
    func testRequestUpdateAndFetchStatement_DatabaseComponents_table() throws {
#if GRDBCUSTOMSQLITE || SQLITE_HAS_CODEC
        guard Database.sqliteLibVersionNumber >= 3035000 else {
            throw XCTSkip("RETURNING clause is not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("RETURNING clause is not available")
        }
#endif
        
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            
            do {
                let request = Player.all()
                let statement = try request.updateAndFetchStatement(db) { [$0.score.set(to: 0)] } select: { [$0.score] }
                XCTAssertEqual(statement.sql, "UPDATE \"player\" SET \"score\" = ? RETURNING \"score\"")
                XCTAssertEqual(statement.arguments, [0])
                XCTAssertEqual(statement.columnNames, ["score"])
            }
            do {
                let request = Player.all()
                let statement = try request.updateAndFetchStatement(db) { [$0.score.set(to: 0)] } select: { _ in [.allColumns] }
                XCTAssertEqual(statement.sql, "UPDATE \"player\" SET \"score\" = ? RETURNING *")
                XCTAssertEqual(statement.arguments, [0])
                XCTAssertEqual(statement.columnNames, ["id", "name", "score", "bonus"])
            }
            do {
                let request = Player.all()
                let statement = try request.updateAndFetchStatement(db) { [$0.score.set(to: 0)] } select: { _ in [.allColumns(excluding: ["name"])] }
                XCTAssertEqual(statement.sql, "UPDATE \"player\" SET \"score\" = ? RETURNING \"id\", \"score\", \"bonus\"")
                XCTAssertEqual(statement.arguments, [0])
                XCTAssertEqual(statement.columnNames, ["id", "score", "bonus"])
            }
        }
    }

    func testRequestUpdateAndFetchStatement_DatabaseComponents_view() throws {
#if GRDBCUSTOMSQLITE || SQLITE_HAS_CODEC
        guard Database.sqliteLibVersionNumber >= 3035000 else {
            throw XCTSkip("RETURNING clause is not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("RETURNING clause is not available")
        }
#endif
        
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            try PlayerView.createTable(db)
            
            do {
                let request = PlayerView.all()
                let statement = try request.updateAndFetchStatement(db) { [$0.score.set(to: 0)] } select: { [$0.score] }
                XCTAssertEqual(statement.sql, "UPDATE \"playerView\" SET \"score\" = ? RETURNING \"score\"")
                XCTAssertEqual(statement.arguments, [0])
                XCTAssertEqual(statement.columnNames, ["score"])
            }
            do {
                let request = PlayerView.all()
                let statement = try request.updateAndFetchStatement(db) { [$0.score.set(to: 0)] } select: { _ in [.allColumns] }
                XCTAssertEqual(statement.sql, "UPDATE \"playerView\" SET \"score\" = ? RETURNING *")
                XCTAssertEqual(statement.arguments, [0])
                XCTAssertEqual(statement.columnNames, ["id", "name", "score", "bonus"])
            }
            do {
                let request = PlayerView.all()
                let statement = try request.updateAndFetchStatement(db) { [$0.score.set(to: 0)] } select: { _ in [.allColumns(excluding: ["name"])] }
                XCTAssertEqual(statement.sql, "UPDATE \"playerView\" SET \"score\" = ? RETURNING \"id\", \"score\", \"bonus\"")
                XCTAssertEqual(statement.arguments, [0])
                XCTAssertEqual(statement.columnNames, ["id", "score", "bonus"])
            }
        }
    }

    func testRequestUpdateAndFetchCursor_table() throws {
#if GRDBCUSTOMSQLITE || SQLITE_HAS_CODEC
        guard Database.sqliteLibVersionNumber >= 3035000 else {
            throw XCTSkip("RETURNING clause is not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("RETURNING clause is not available")
        }
#endif
        
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            try Player(id: 1, name: "Arthur", score: 10, bonus: 0).insert(db)
            try Player(id: 2, name: "Barbara", score: 20, bonus: 10).insert(db)
            try Player(id: 3, name: "Craig", score: 30, bonus: 20).insert(db)

            let request = Player.filter { $0.id != 2 }
            let cursor = try request.updateAndFetchCursor(db, [Columns.score += 100])
            let updatedPlayers = try Array(cursor).sorted(by: { $0.id < $1.id })
            XCTAssertEqual(updatedPlayers, [
                Player(id: 1, name: "Arthur", score: 110, bonus: 0),
                Player(id: 3, name: "Craig", score: 130, bonus: 20),
            ])
        }
    }
    
    func testRequestUpdateAndFetchCursor_view() throws {
        #warning("TODO: document this caveat")
        // Mixing INSTEAD OF triggers and RETURNING used to trigger a bug
        // that was fixed in SQLite 3.42. The SQLite test linked below
        // landed on 2023-03-28, and SQLite 3.42 shipped on 2023-05-16.
        // (iOS 17.2, macOS 14.2, tvOS 17.2, watchOS 10.2)
        // <https://sqlite.org/src/artifact/db532cde>
        guard Database.sqliteLibVersionNumber >= 3042000 else {
            throw XCTSkip("RETURNING and INSTEAD OF are buggy")
        }
        
#if !GRDBCUSTOMSQLITE && !SQLITE_HAS_CODEC
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("RETURNING clause is not available")
        }
#endif
        // Views need a schema source
        dbConfiguration.schemaSource = ViewSchemaSource()
        
        // Fail in iOS 15.5 (SQLite 3.37)
        // Fail in iOS 16.4 (SQLite 3.39)
        // Fail in iOS 17.0 (SQLite 3.39)
        // Passes in iOS 17.2 (SQLite 3.43)
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            try PlayerView.createTable(db)
            try PlayerView(id: 1, name: "Arthur", score: 10, bonus: 0).insert(db)
            try PlayerView(id: 2, name: "Barbara", score: 20, bonus: 10).insert(db)
            try PlayerView(id: 3, name: "Craig", score: 30, bonus: 20).insert(db)

            let request = PlayerView.filter { $0.id != 2 }
            let cursor = try request.updateAndFetchCursor(db, [Columns.score += 100])
            let updatedPlayers = try Array(cursor).sorted(by: { $0.id < $1.id })
            XCTAssertEqual(updatedPlayers, [
                PlayerView(id: 1, name: "Arthur", score: 110, bonus: 0),
                PlayerView(id: 3, name: "Craig", score: 130, bonus: 20),
            ])
        }
    }
    
    func testRequestUpdateAndFetchCursor_DatabaseComponents_table() throws {
#if GRDBCUSTOMSQLITE || SQLITE_HAS_CODEC
        guard Database.sqliteLibVersionNumber >= 3035000 else {
            throw XCTSkip("RETURNING clause is not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("RETURNING clause is not available")
        }
#endif
        
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            try Player(id: 1, name: "Arthur", score: 10, bonus: 0).insert(db)
            try Player(id: 2, name: "Barbara", score: 20, bonus: 10).insert(db)
            try Player(id: 3, name: "Craig", score: 30, bonus: 20).insert(db)

            let request = Player.filter { $0.id != 2 }
            let cursor = try request.updateAndFetchCursor(db) { [$0.score += 100] }
            let updatedPlayers = try Array(cursor).sorted(by: { $0.id < $1.id })
            XCTAssertEqual(updatedPlayers, [
                Player(id: 1, name: "Arthur", score: 110, bonus: 0),
                Player(id: 3, name: "Craig", score: 130, bonus: 20),
            ])
        }
    }
    
    func testRequestUpdateAndFetchCursor_DatabaseComponents_view() throws {
        // Mixing INSTEAD OF triggers and RETURNING used to trigger a bug
        // that was fixed in SQLite 3.42. The SQLite test linked below
        // landed on 2023-03-28, and SQLite 3.42 shipped on 2023-05-16.
        // (iOS 17.2, macOS 14.2, tvOS 17.2, watchOS 10.2)
        // <https://sqlite.org/src/artifact/db532cde>
        guard Database.sqliteLibVersionNumber >= 3042000 else {
            throw XCTSkip("RETURNING and INSTEAD OF are buggy")
        }
        
#if !GRDBCUSTOMSQLITE && !SQLITE_HAS_CODEC
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("RETURNING clause is not available")
        }
#endif
        // Views need a schema source
        dbConfiguration.schemaSource = ViewSchemaSource()
        
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            try PlayerView.createTable(db)
            try PlayerView(id: 1, name: "Arthur", score: 10, bonus: 0).insert(db)
            try PlayerView(id: 2, name: "Barbara", score: 20, bonus: 10).insert(db)
            try PlayerView(id: 3, name: "Craig", score: 30, bonus: 20).insert(db)

            let request = PlayerView.filter { $0.id != 2 }
            let cursor = try request.updateAndFetchCursor(db) { [$0.score += 100] }
            let updatedPlayers = try Array(cursor).sorted(by: { $0.id < $1.id })
            XCTAssertEqual(updatedPlayers, [
                PlayerView(id: 1, name: "Arthur", score: 110, bonus: 0),
                PlayerView(id: 3, name: "Craig", score: 130, bonus: 20),
            ])
        }
    }
    
    func testRequestUpdateAndFetchAll_table() throws {
#if GRDBCUSTOMSQLITE || SQLITE_HAS_CODEC
        guard Database.sqliteLibVersionNumber >= 3035000 else {
            throw XCTSkip("RETURNING clause is not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("RETURNING clause is not available")
        }
#endif
        
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            try Player(id: 1, name: "Arthur", score: 10, bonus: 0).insert(db)
            try Player(id: 2, name: "Barbara", score: 20, bonus: 10).insert(db)
            try Player(id: 3, name: "Craig", score: 30, bonus: 20).insert(db)

            let request = Player.filter { $0.id != 2 }
            let updatedPlayers = try request
                .updateAndFetchAll(db, [Columns.score += 100])
                .sorted(by: { $0.id < $1.id })
            XCTAssertEqual(updatedPlayers, [
                Player(id: 1, name: "Arthur", score: 110, bonus: 0),
                Player(id: 3, name: "Craig", score: 130, bonus: 20),
            ])
        }
    }
    
    func testRequestUpdateAndFetchAll_view() throws {
        // Mixing INSTEAD OF triggers and RETURNING used to trigger a bug
        // that was fixed in SQLite 3.42. The SQLite test linked below
        // landed on 2023-03-28, and SQLite 3.42 shipped on 2023-05-16.
        // (iOS 17.2, macOS 14.2, tvOS 17.2, watchOS 10.2)
        // <https://sqlite.org/src/artifact/db532cde>
        guard Database.sqliteLibVersionNumber >= 3042000 else {
            throw XCTSkip("RETURNING and INSTEAD OF are buggy")
        }
        
#if !GRDBCUSTOMSQLITE && !SQLITE_HAS_CODEC
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("RETURNING clause is not available")
        }
#endif
        // Views need a schema source
        dbConfiguration.schemaSource = ViewSchemaSource()
        
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            try PlayerView.createTable(db)
            try PlayerView(id: 1, name: "Arthur", score: 10, bonus: 0).insert(db)
            try PlayerView(id: 2, name: "Barbara", score: 20, bonus: 10).insert(db)
            try PlayerView(id: 3, name: "Craig", score: 30, bonus: 20).insert(db)

            let request = PlayerView.filter { $0.id != 2 }
            let updatedPlayers = try request
                .updateAndFetchAll(db, [Columns.score += 100])
                .sorted(by: { $0.id < $1.id })
            XCTAssertEqual(updatedPlayers, [
                PlayerView(id: 1, name: "Arthur", score: 110, bonus: 0),
                PlayerView(id: 3, name: "Craig", score: 130, bonus: 20),
            ])
        }
    }
    
    func testRequestUpdateAndFetchAll_DatabaseComponents_table() throws {
#if GRDBCUSTOMSQLITE || SQLITE_HAS_CODEC
        guard Database.sqliteLibVersionNumber >= 3035000 else {
            throw XCTSkip("RETURNING clause is not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("RETURNING clause is not available")
        }
#endif
        
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            try Player(id: 1, name: "Arthur", score: 10, bonus: 0).insert(db)
            try Player(id: 2, name: "Barbara", score: 20, bonus: 10).insert(db)
            try Player(id: 3, name: "Craig", score: 30, bonus: 20).insert(db)

            let request = Player.filter { $0.id != 2 }
            let updatedPlayers = try request
                .updateAndFetchAll(db) { [$0.score += 100] }
                .sorted(by: { $0.id < $1.id })
            XCTAssertEqual(updatedPlayers, [
                Player(id: 1, name: "Arthur", score: 110, bonus: 0),
                Player(id: 3, name: "Craig", score: 130, bonus: 20),
            ])
        }
    }

    func testRequestUpdateAndFetchAll_DatabaseComponents_view() throws {
        // Mixing INSTEAD OF triggers and RETURNING used to trigger a bug
        // that was fixed in SQLite 3.42. The SQLite test linked below
        // landed on 2023-03-28, and SQLite 3.42 shipped on 2023-05-16.
        // (iOS 17.2, macOS 14.2, tvOS 17.2, watchOS 10.2)
        // <https://sqlite.org/src/artifact/db532cde>
        guard Database.sqliteLibVersionNumber >= 3042000 else {
            throw XCTSkip("RETURNING and INSTEAD OF are buggy")
        }
        
#if !GRDBCUSTOMSQLITE && !SQLITE_HAS_CODEC
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("RETURNING clause is not available")
        }
#endif
        // Views need a schema source
        dbConfiguration.schemaSource = ViewSchemaSource()
        
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            try PlayerView.createTable(db)
            try PlayerView(id: 1, name: "Arthur", score: 10, bonus: 0).insert(db)
            try PlayerView(id: 2, name: "Barbara", score: 20, bonus: 10).insert(db)
            try PlayerView(id: 3, name: "Craig", score: 30, bonus: 20).insert(db)

            let request = PlayerView.filter { $0.id != 2 }
            let updatedPlayers = try request
                .updateAndFetchAll(db) { [$0.score += 100] }
                .sorted(by: { $0.id < $1.id })
            XCTAssertEqual(updatedPlayers, [
                PlayerView(id: 1, name: "Arthur", score: 110, bonus: 0),
                PlayerView(id: 3, name: "Craig", score: 130, bonus: 20),
            ])
        }
    }

    func testRequestUpdateAndFetchSet() throws {
#if GRDBCUSTOMSQLITE || SQLITE_HAS_CODEC
        guard Database.sqliteLibVersionNumber >= 3035000 else {
            throw XCTSkip("RETURNING clause is not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("RETURNING clause is not available")
        }
#endif
        
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            try Player(id: 1, name: "Arthur", score: 10, bonus: 0).insert(db)
            try Player(id: 2, name: "Barbara", score: 20, bonus: 10).insert(db)
            try Player(id: 3, name: "Craig", score: 30, bonus: 20).insert(db)

            let request = Player.filter { $0.id != 2 }
            let updatedPlayers = try request.updateAndFetchSet(db, [Columns.score += 100])
            XCTAssertEqual(updatedPlayers, [
                Player(id: 1, name: "Arthur", score: 110, bonus: 0),
                Player(id: 3, name: "Craig", score: 130, bonus: 20),
            ])
        }
    }

    func testRequestUpdateAndFetchSet_DatabaseComponents() throws {
#if GRDBCUSTOMSQLITE || SQLITE_HAS_CODEC
        guard Database.sqliteLibVersionNumber >= 3035000 else {
            throw XCTSkip("RETURNING clause is not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("RETURNING clause is not available")
        }
#endif
        
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            try Player(id: 1, name: "Arthur", score: 10, bonus: 0).insert(db)
            try Player(id: 2, name: "Barbara", score: 20, bonus: 10).insert(db)
            try Player(id: 3, name: "Craig", score: 30, bonus: 20).insert(db)

            let request = Player.filter { $0.id != 2 }
            let updatedPlayers = try request.updateAndFetchSet(db) { [$0.score += 100] }
            XCTAssertEqual(updatedPlayers, [
                Player(id: 1, name: "Arthur", score: 110, bonus: 0),
                Player(id: 3, name: "Craig", score: 130, bonus: 20),
            ])
        }
    }
    
    func testNilAssignment() throws {
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            
            try Player.updateAll(db, Columns.score.set(to: nil))
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = NULL
                """)
        }
    }
    
    func testNilAssignment_DatabaseComponents() throws {
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            
            try Player.updateAll(db) { $0.score.set(to: nil) }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = NULL
                """)
        }
    }
    
    func testComplexAssignment() throws {
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            
            try Player.updateAll(db, Columns.score.set(to: Columns.score * (Columns.bonus + 1)))
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" * ("bonus" + 1)
                """)
        }
    }
    
    func testComplexAssignment_DatabaseComponents() throws {
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            
            try Player.updateAll(db) { $0.score.set(to: $0.score * ($0.bonus + 1)) }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" * ("bonus" + 1)
                """)
        }
    }
    
    func testAssignmentSubtractAndAssign() throws {
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            
            try Player.updateAll(db, Columns.score -= 1)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" - 1
                """)
            
            try Player.updateAll(db, Columns.score -= Columns.bonus)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" - "bonus"
                """)
            
            try Player.updateAll(db, Columns.score -= -Columns.bonus)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" - (-"bonus")
                """)
            
            try Player.updateAll(db, Columns.score -= Columns.bonus * 2)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" - ("bonus" * 2)
                """)
        }
    }
    
    func testAssignmentSubtractAndAssign_DatabaseComponents() throws {
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            
            try Player.updateAll(db) { $0.score -= 1 }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" - 1
                """)
            
            try Player.updateAll(db) { $0.score -= $0.bonus }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" - "bonus"
                """)
            
            try Player.updateAll(db) { $0.score -= -$0.bonus }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" - (-"bonus")
                """)
            
            try Player.updateAll(db) { $0.score -= $0.bonus * 2 }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" - ("bonus" * 2)
                """)
        }
    }
    
    func testAssignmentAddAndAssign() throws {
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            
            try Player.updateAll(db, Columns.score += 1)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" + 1
                """)
            
            try Player.updateAll(db, Columns.score += Columns.bonus)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" + "bonus"
                """)
            
            try Player.updateAll(db, Columns.score += -Columns.bonus)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" + (-"bonus")
                """)
            
            try Player.updateAll(db, Columns.score += Columns.bonus * 2)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" + ("bonus" * 2)
                """)
        }
    }
    
    func testAssignmentAddAndAssign_DatabaseComponents() throws {
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            
            try Player.updateAll(db) { $0.score += 1 }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" + 1
                """)
            
            try Player.updateAll(db) { $0.score += $0.bonus }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" + "bonus"
                """)
            
            try Player.updateAll(db) { $0.score += -$0.bonus }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" + (-"bonus")
                """)
            
            try Player.updateAll(db) { $0.score += $0.bonus * 2 }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" + ("bonus" * 2)
                """)
        }
    }
    
    func testAssignmentMultiplyAndAssign() throws {
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            
            try Player.updateAll(db, Columns.score *= 1)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" * 1
                """)
            
            try Player.updateAll(db, Columns.score *= Columns.bonus)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" * "bonus"
                """)
            
            try Player.updateAll(db, Columns.score *= -Columns.bonus)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" * (-"bonus")
                """)
            
            try Player.updateAll(db, Columns.score *= Columns.bonus * 2)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" * ("bonus" * 2)
                """)
        }
    }
    
    func testAssignmentMultiplyAndAssign_DatabaseComponents() throws {
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            
            try Player.updateAll(db) { $0.score *= 1 }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" * 1
                """)
            
            try Player.updateAll(db) { $0.score *= $0.bonus }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" * "bonus"
                """)
            
            try Player.updateAll(db) { $0.score *= -$0.bonus }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" * (-"bonus")
                """)
            
            try Player.updateAll(db) { $0.score *= $0.bonus * 2 }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" * ("bonus" * 2)
                """)
        }
    }
    
    func testAssignmentDivideAndAssign() throws {
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            
            try Player.updateAll(db, Columns.score /= 1)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" / 1
                """)
            
            try Player.updateAll(db, Columns.score /= Columns.bonus)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" / "bonus"
                """)
            
            try Player.updateAll(db, Columns.score /= -Columns.bonus)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" / (-"bonus")
                """)
            
            try Player.updateAll(db, Columns.score /= Columns.bonus * 2)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" / ("bonus" * 2)
                """)
        }
    }
    
    func testAssignmentDivideAndAssign_DatabaseComponents() throws {
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            
            try Player.updateAll(db) { $0.score /= 1 }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" / 1
                """)
            
            try Player.updateAll(db) { $0.score /= $0.bonus }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" / "bonus"
                """)
            
            try Player.updateAll(db) { $0.score /= -$0.bonus }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" / (-"bonus")
                """)
            
            try Player.updateAll(db) { $0.score /= $0.bonus * 2 }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" / ("bonus" * 2)
                """)
        }
    }
    
    func testAssignmentBitwiseAndAssign() throws {
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            
            try Player.updateAll(db, Columns.score &= 1)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" & 1
                """)
            
            try Player.updateAll(db, Columns.score &= Columns.bonus)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" & "bonus"
                """)
            
            try Player.updateAll(db, Columns.score &= -Columns.bonus)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" & (-"bonus")
                """)
            
            try Player.updateAll(db, Columns.score &= Columns.bonus * 2)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" & ("bonus" * 2)
                """)
        }
    }
    
    func testAssignmentBitwiseAndAssign_DatabaseComponents() throws {
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            
            try Player.updateAll(db) { $0.score &= 1 }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" & 1
                """)
            
            try Player.updateAll(db) { $0.score &= $0.bonus }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" & "bonus"
                """)
            
            try Player.updateAll(db) { $0.score &= -$0.bonus }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" & (-"bonus")
                """)
            
            try Player.updateAll(db) { $0.score &= $0.bonus * 2 }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" & ("bonus" * 2)
                """)
        }
    }

    func testAssignmentBitwiseOrAssign() throws {
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            
            try Player.updateAll(db, Columns.score |= 1)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" | 1
                """)
            
            try Player.updateAll(db, Columns.score |= Columns.bonus)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" | "bonus"
                """)
            
            try Player.updateAll(db, Columns.score |= -Columns.bonus)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" | (-"bonus")
                """)
            
            try Player.updateAll(db, Columns.score |= Columns.bonus * 2)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" | ("bonus" * 2)
                """)
        }
    }
    
    func testAssignmentBitwiseOrAssign_DatabaseComponents() throws {
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            
            try Player.updateAll(db) { $0.score |= 1 }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" | 1
                """)
            
            try Player.updateAll(db) { $0.score |= $0.bonus }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" | "bonus"
                """)
            
            try Player.updateAll(db) { $0.score |= -$0.bonus }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" | (-"bonus")
                """)
            
            try Player.updateAll(db) { $0.score |= $0.bonus * 2 }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" | ("bonus" * 2)
                """)
        }
    }
    
    func testAssignmentLeftShiftAssign() throws {
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            
            try Player.updateAll(db, Columns.score <<= 1)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" << 1
                """)
            
            try Player.updateAll(db, Columns.score <<= Columns.bonus)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" << "bonus"
                """)
            
            try Player.updateAll(db, Columns.score <<= -Columns.bonus)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" << (-"bonus")
                """)
            
            try Player.updateAll(db, Columns.score <<= Columns.bonus * 2)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" << ("bonus" * 2)
                """)
        }
    }
    
    func testAssignmentLeftShiftAssign_DatabaseComponents() throws {
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            
            try Player.updateAll(db) { $0.score <<= 1 }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" << 1
                """)
            
            try Player.updateAll(db) { $0.score <<= $0.bonus }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" << "bonus"
                """)
            
            try Player.updateAll(db) { $0.score <<= -$0.bonus }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" << (-"bonus")
                """)
            
            try Player.updateAll(db) { $0.score <<= $0.bonus * 2 }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" << ("bonus" * 2)
                """)
        }
    }

    func testAssignmentRightShiftAssign() throws {
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            
            try Player.updateAll(db, Columns.score >>= 1)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" >> 1
                """)
            
            try Player.updateAll(db, Columns.score >>= Columns.bonus)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" >> "bonus"
                """)
            
            try Player.updateAll(db, Columns.score >>= -Columns.bonus)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" >> (-"bonus")
                """)
            
            try Player.updateAll(db, Columns.score >>= Columns.bonus * 2)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" >> ("bonus" * 2)
                """)
        }
    }
    
    func testAssignmentRightShiftAssign_DatabaseComponents() throws {
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            
            try Player.updateAll(db) { $0.score >>= 1 }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" >> 1
                """)
            
            try Player.updateAll(db) { $0.score >>= $0.bonus }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" >> "bonus"
                """)
            
            try Player.updateAll(db) { $0.score >>= -$0.bonus }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" >> (-"bonus")
                """)
            
            try Player.updateAll(db) { $0.score >>= $0.bonus * 2 }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" >> ("bonus" * 2)
                """)
        }
    }
    
    func testMultipleAssignments() throws {
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            
            try Player.updateAll(db, Columns.score.set(to: 0), Columns.bonus.set(to: 1))
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = 0, "bonus" = 1
                """)
            
            try Player.updateAll(db, [Columns.score.set(to: 0), Columns.bonus.set(to: 1)])
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = 0, "bonus" = 1
                """)
            
            try Player.all().updateAll(db, Columns.score.set(to: 0), Columns.bonus.set(to: 1))
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = 0, "bonus" = 1
                """)
            
            try Player.all().updateAll(db, [Columns.score.set(to: 0), Columns.bonus.set(to: 1)])
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = 0, "bonus" = 1
                """)
        }
    }
    
    func testMultipleAssignments_DatabaseComponents() throws {
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            
            try Player.updateAll(db) { [$0.score.set(to: 0), $0.bonus.set(to: 1)] }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = 0, "bonus" = 1
                """)
            
            try Player.all().updateAll(db) { [$0.score.set(to: 0), $0.bonus.set(to: 1)] }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = 0, "bonus" = 1
                """)
        }
    }

    func testUpdateAllWithoutAssignmentDoesNotAccessTheDatabase() throws {
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            clearSQLQueries()
            try XCTAssertEqual(Player.updateAll(db, []), 0)
            try XCTAssertEqual(Player.all().updateAll(db, []), 0)
            XCTAssert(sqlQueries.isEmpty)
        }
    }

    func testUpdateAllWithoutAssignmentDoesNotAccessTheDatabase_DatabaseComponents() throws {
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            clearSQLQueries()
            try XCTAssertEqual(Player.updateAll(db) { _ in [] }, 0)
            try XCTAssertEqual(Player.all().updateAll(db) { _ in [] }, 0)
            XCTAssert(sqlQueries.isEmpty)
        }
    }
    
    func testUpdateAllReturnsNumberOfUpdatedRows() throws {
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            try db.execute(sql: """
                INSERT INTO player (id, name, score, bonus) VALUES (1, 'Arthur', 0, 2);
                INSERT INTO player (id, name, score, bonus) VALUES (2, 'Barbara', 0, 1);
                INSERT INTO player (id, name, score, bonus) VALUES (3, 'Craig', 0, 0);
                INSERT INTO player (id, name, score, bonus) VALUES (4, 'Diane', 0, 3);
                """)
            
            let assignment = Columns.score += 1
            
            try XCTAssertEqual(Player.updateAll(db, assignment), 4)
            try XCTAssertEqual(Player.filter(key: 1).updateAll(db, assignment), 1)
            try XCTAssertEqual(Player.filter(key: 5).updateAll(db, assignment), 0)
            try XCTAssertEqual(Player.filter { $0.bonus > 1 }.updateAll(db, assignment), 2)
            if try String.fetchCursor(db, sql: "PRAGMA COMPILE_OPTIONS").contains("ENABLE_UPDATE_DELETE_LIMIT") {
                try XCTAssertEqual(Player.limit(1).updateAll(db, assignment), 1)
                try XCTAssertEqual(Player.limit(2).updateAll(db, assignment), 2)
                try XCTAssertEqual(Player.limit(2, offset: 3).updateAll(db, assignment), 1)
                try XCTAssertEqual(Player.limit(10).updateAll(db, assignment), 4)
            }
        }
    }
    
    func testUpdateAllReturnsNumberOfUpdatedRows_DatabaseComponents() throws {
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            try db.execute(sql: """
                INSERT INTO player (id, name, score, bonus) VALUES (1, 'Arthur', 0, 2);
                INSERT INTO player (id, name, score, bonus) VALUES (2, 'Barbara', 0, 1);
                INSERT INTO player (id, name, score, bonus) VALUES (3, 'Craig', 0, 0);
                INSERT INTO player (id, name, score, bonus) VALUES (4, 'Diane', 0, 3);
                """)
            
            try XCTAssertEqual(Player.updateAll(db) { $0.score += 1 }, 4)
            try XCTAssertEqual(Player.filter(key: 1).updateAll(db) { $0.score += 1 }, 1)
            try XCTAssertEqual(Player.filter(key: 5).updateAll(db) { $0.score += 1 }, 0)
            try XCTAssertEqual(Player.filter { $0.bonus > 1 }.updateAll(db) { $0.score += 1 }, 2)
            if try String.fetchCursor(db, sql: "PRAGMA COMPILE_OPTIONS").contains("ENABLE_UPDATE_DELETE_LIMIT") {
                try XCTAssertEqual(Player.limit(1).updateAll(db) { $0.score += 1 }, 1)
                try XCTAssertEqual(Player.limit(2).updateAll(db) { $0.score += 1 }, 2)
                try XCTAssertEqual(Player.limit(2, offset: 3).updateAll(db) { $0.score += 1 }, 1)
                try XCTAssertEqual(Player.limit(10).updateAll(db) { $0.score += 1 }, 4)
            }
        }
    }

    func testQueryInterfaceExtension() throws {
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            try db.execute(sql: """
                INSERT INTO player (id, name, score, bonus) VALUES (1, 'Arthur', 0, 0);
                INSERT INTO player (id, name, score, bonus) VALUES (2, 'Barbara', 0, 0);
                INSERT INTO player (id, name, score, bonus) VALUES (3, 'Craig', 0, 0);
                INSERT INTO player (id, name, score, bonus) VALUES (4, 'Diane', 0, 0);
                """)
            
            try Player.all().incrementScore(db)
            try XCTAssertEqual(Player.filter { $0.score == 1 }.fetchCount(db), 4)
            
            try Player.filter(key: 1).incrementScore(db)
            try XCTAssertEqual(Player.fetchOne(db, key: 1)!.score, 2)
        }
    }
    
    func testConflictPolicyAbort() throws {
        struct AbortPlayer: PersistableRecord {
            static let databaseTableName = "player"
            static let persistenceConflictPolicy = PersistenceConflictPolicy(insert: .abort, update: .abort)
            func encode(to container: inout PersistenceContainer) { }
        }
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            
            try AbortPlayer.updateAll(db, Column("score").set(to: 0))
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = 0
                """)
            
            try AbortPlayer.updateAll(db, [Column("score").set(to: 0)])
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = 0
                """)
            
            try AbortPlayer.all().updateAll(db, Column("score").set(to: 0))
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = 0
                """)
            
            try AbortPlayer.all().updateAll(db, [Column("score").set(to: 0)])
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = 0
                """)
        }
    }
    
    func testConflictPolicyAbort_DatabaseComponents() throws {
        struct AbortPlayer: PersistableRecord {
            static let databaseTableName = "player"
            static let persistenceConflictPolicy = PersistenceConflictPolicy(insert: .abort, update: .abort)
            func encode(to container: inout PersistenceContainer) { }
            typealias Columns = Player.Columns
        }
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            
            try AbortPlayer.updateAll(db) { $0.score.set(to: 0) }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = 0
                """)
            
            try AbortPlayer.all().updateAll(db) { $0.score.set(to: 0) }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = 0
                """)
        }
    }
    
    func testConflictPolicyIgnore() throws {
        struct IgnorePlayer: PersistableRecord {
            static let databaseTableName = "player"
            static let persistenceConflictPolicy = PersistenceConflictPolicy(insert: .abort, update: .ignore)
            func encode(to container: inout PersistenceContainer) { }
        }
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            
            try IgnorePlayer.updateAll(db, Column("score").set(to: 0))
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE OR IGNORE "player" SET "score" = 0
                """)
            
            try IgnorePlayer.updateAll(db, [Column("score").set(to: 0)])
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE OR IGNORE "player" SET "score" = 0
                """)
            
            try IgnorePlayer.all().updateAll(db, Column("score").set(to: 0))
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE OR IGNORE "player" SET "score" = 0
                """)
            
            try IgnorePlayer.all().updateAll(db, [Column("score").set(to: 0)])
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE OR IGNORE "player" SET "score" = 0
                """)
        }
    }
    
    func testConflictPolicyIgnore_DatabaseComponents() throws {
        struct IgnorePlayer: PersistableRecord {
            static let databaseTableName = "player"
            static let persistenceConflictPolicy = PersistenceConflictPolicy(insert: .abort, update: .ignore)
            func encode(to container: inout PersistenceContainer) { }
            typealias Columns = Player.Columns
        }
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            
            try IgnorePlayer.updateAll(db) { $0.score.set(to: 0) }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE OR IGNORE "player" SET "score" = 0
                """)
            
            try IgnorePlayer.all().updateAll(db) { $0.score.set(to: 0) }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE OR IGNORE "player" SET "score" = 0
                """)
        }
    }
    
    func testConflictPolicyIgnoreWithTable() throws {
        struct IgnorePlayer: PersistableRecord {
            static let databaseTableName = "player"
            static let persistenceConflictPolicy = PersistenceConflictPolicy(insert: .abort, update: .ignore)
            func encode(to container: inout PersistenceContainer) { }
        }
        let table = Table<IgnorePlayer>("player")
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            
            try table.updateAll(db, Column("score").set(to: 0))
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE OR IGNORE "player" SET "score" = 0
                """)
            
            try table.updateAll(db, [Column("score").set(to: 0)])
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE OR IGNORE "player" SET "score" = 0
                """)
            
            try table.all().updateAll(db, Column("score").set(to: 0))
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE OR IGNORE "player" SET "score" = 0
                """)
            
            try table.all().updateAll(db, [Column("score").set(to: 0)])
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE OR IGNORE "player" SET "score" = 0
                """)
        }
    }
    
    func testConflictPolicyIgnoreWithTable_DatabaseComponents() throws {
        struct IgnorePlayer: PersistableRecord {
            static let databaseTableName = "player"
            static let persistenceConflictPolicy = PersistenceConflictPolicy(insert: .abort, update: .ignore)
            func encode(to container: inout PersistenceContainer) { }
            typealias Columns = Player.Columns
        }
        let table = Table<IgnorePlayer>("player")
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            
            try table.updateAll(db) { $0.score.set(to: 0) }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE OR IGNORE "player" SET "score" = 0
                """)
            
            try table.all().updateAll(db) { $0.score.set(to: 0) }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE OR IGNORE "player" SET "score" = 0
                """)
        }
    }

    func testConflictPolicyCustom() throws {
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            
            try Player.updateAll(db, Column("score").set(to: 0))
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = 0
                """)
            
            try Player.updateAll(db, onConflict: .ignore, Column("score").set(to: 0))
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE OR IGNORE "player" SET "score" = 0
                """)
            
            try Player.updateAll(db, onConflict: .ignore, [Column("score").set(to: 0)])
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE OR IGNORE "player" SET "score" = 0
                """)
            
            try Player.all().updateAll(db, onConflict: .ignore, Column("score").set(to: 0))
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE OR IGNORE "player" SET "score" = 0
                """)
            
            try Player.all().updateAll(db, onConflict: .ignore, [Column("score").set(to: 0)])
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE OR IGNORE "player" SET "score" = 0
                """)
        }
    }
    
    func testConflictPolicyCustom_DatabaseComponents() throws {
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            
            try Player.updateAll(db) { $0.score.set(to: 0) }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = 0
                """)
            
            try Player.updateAll(db, onConflict: .ignore) { $0.score.set(to: 0) }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE OR IGNORE "player" SET "score" = 0
                """)
            
            try Player.all().updateAll(db, onConflict: .ignore) { $0.score.set(to: 0) }
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE OR IGNORE "player" SET "score" = 0
                """)
        }
    }
    
    // TODO: duplicate test with views?
    func testJoinedRequestUpdate() throws {
        try makeDatabaseQueue().inDatabase { db in
            struct Player: MutablePersistableRecord {
                static let team = belongsTo(Team.self)
                func encode(to container: inout PersistenceContainer) { preconditionFailure("should not be called") }
            }
            
            struct Team: MutablePersistableRecord {
                static let players = hasMany(Player.self)
                func encode(to container: inout PersistenceContainer) { preconditionFailure("should not be called") }
            }
            
            try db.create(table: "team") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("active", .boolean)
            }
            
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.belongsTo("team")
                t.column("score", .integer)
            }
            
            do {
                try Player.including(required: Player.team).updateAll(db, Column("score").set(to: 0))
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "player" SET "score" = 0 WHERE "id" IN (\
                    SELECT "player"."id" \
                    FROM "player" \
                    JOIN "team" ON "team"."id" = "player"."teamId")
                    """)
            }
            do {
                // Regression test for https://github.com/groue/GRDB.swift/issues/758
                try Player.including(required: Player.team.filter(Column("active") == 1)).updateAll(db, Column("score").set(to: 0))
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "player" SET "score" = 0 WHERE "id" IN (\
                    SELECT "player"."id" \
                    FROM "player" \
                    JOIN "team" ON ("team"."id" = "player"."teamId") AND ("team"."active" = 1))
                    """)
            }
            do {
                let alias = TableAlias(name: "p")
                try Player.aliased(alias).including(required: Player.team).updateAll(db, Column("score").set(to: 0))
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "player" SET "score" = 0 WHERE "id" IN (\
                    SELECT "p"."id" \
                    FROM "player" "p" \
                    JOIN "team" ON "team"."id" = "p"."teamId")
                    """)
            }
            do {
                try Team.having(Team.players.isEmpty).updateAll(db, Column("active").set(to: false))
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "team" SET "active" = 0 WHERE "id" IN (\
                    SELECT "team"."id" \
                    FROM "team" \
                    LEFT JOIN "player" ON "player"."teamId" = "team"."id" \
                    GROUP BY "team"."id" \
                    HAVING COUNT(DISTINCT "player"."id") = 0)
                    """)
            }
            do {
                try Team.including(all: Team.players).updateAll(db, Column("active").set(to: false))
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "team" SET "active" = 0
                    """)
            }
        }
    }
    
    // TODO: duplicate test with views?
    func testJoinedRequestUpdate_DatabaseComponents() throws {
        try makeDatabaseQueue().inDatabase { db in
            struct Player: MutablePersistableRecord {
                static let team = belongsTo(Team.self)
                func encode(to container: inout PersistenceContainer) { preconditionFailure("should not be called") }
                enum Columns {
                    static let score = Column("score")
                }
            }
            
            struct Team: MutablePersistableRecord {
                static let players = hasMany(Player.self)
                func encode(to container: inout PersistenceContainer) { preconditionFailure("should not be called") }
                enum Columns {
                    static let active = Column("active")
                }
            }
            
            try db.create(table: "team") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("active", .boolean)
            }
            
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.belongsTo("team")
                t.column("score", .integer)
            }
            
            do {
                try Player.including(required: Player.team).updateAll(db) { $0.score.set(to: 0) }
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "player" SET "score" = 0 WHERE "id" IN (\
                    SELECT "player"."id" \
                    FROM "player" \
                    JOIN "team" ON "team"."id" = "player"."teamId")
                    """)
            }
            do {
                // Regression test for https://github.com/groue/GRDB.swift/issues/758
                try Player.including(required: Player.team.filter(Column("active") == 1)).updateAll(db) { $0.score.set(to: 0) }
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "player" SET "score" = 0 WHERE "id" IN (\
                    SELECT "player"."id" \
                    FROM "player" \
                    JOIN "team" ON ("team"."id" = "player"."teamId") AND ("team"."active" = 1))
                    """)
            }
            do {
                let alias = TableAlias(name: "p")
                try Player.aliased(alias).including(required: Player.team).updateAll(db) { $0.score.set(to: 0) }
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "player" SET "score" = 0 WHERE "id" IN (\
                    SELECT "p"."id" \
                    FROM "player" "p" \
                    JOIN "team" ON "team"."id" = "p"."teamId")
                    """)
            }
            do {
                try Team.having(Team.players.isEmpty).updateAll(db) { $0.active.set(to: false) }
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "team" SET "active" = 0 WHERE "id" IN (\
                    SELECT "team"."id" \
                    FROM "team" \
                    LEFT JOIN "player" ON "player"."teamId" = "team"."id" \
                    GROUP BY "team"."id" \
                    HAVING COUNT(DISTINCT "player"."id") = 0)
                    """)
            }
            do {
                try Team.including(all: Team.players).updateAll(db) { $0.active.set(to: false) }
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "team" SET "active" = 0
                    """)
            }
        }
    }
    
    func testGroupedRequestUpdate() throws {
        try makeDatabaseQueue().inDatabase { db in
            struct Player: MutablePersistableRecord {
                func encode(to container: inout PersistenceContainer) { preconditionFailure("should not be called") }
            }
            struct Passport: MutablePersistableRecord {
                func encode(to container: inout PersistenceContainer) { preconditionFailure("should not be called") }
            }
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("score", .integer)
            }
            try db.create(table: "passport") { t in
                t.column("countryCode", .text).notNull()
                t.column("citizenId", .integer).notNull()
                t.column("active", .boolean)
                t.primaryKey(["countryCode", "citizenId"])
            }
            do {
                try Player.all().groupByPrimaryKey().updateAll(db, Column("score").set(to: 0))
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "player" SET "score" = 0 WHERE "id" IN (\
                    SELECT "id" \
                    FROM "player" \
                    GROUP BY "id")
                    """)
            }
            do {
                try Player.all().group(Column.rowID).updateAll(db, Column("score").set(to: 0))
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "player" SET "score" = 0 WHERE "id" IN (\
                    SELECT "id" \
                    FROM "player" \
                    GROUP BY "rowid")
                    """)
            }
            do {
                try Passport.all().groupByPrimaryKey().updateAll(db, Column("active").set(to: true))
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "passport" SET "active" = 1 WHERE "rowid" IN (\
                    SELECT "rowid" \
                    FROM "passport" \
                    GROUP BY "rowid")
                    """)
            }
            do {
                try Passport.all().group(Column.rowID).updateAll(db, Column("active").set(to: true))
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "passport" SET "active" = 1 WHERE "rowid" IN (\
                    SELECT "rowid" \
                    FROM "passport" \
                    GROUP BY "rowid")
                    """)
            }
        }
    }
    
    func testGroupedRequestUpdate_DatabaseComponents() throws {
        try makeDatabaseQueue().inDatabase { db in
            struct Player: MutablePersistableRecord {
                func encode(to container: inout PersistenceContainer) { preconditionFailure("should not be called") }
                enum Columns {
                    static let score = Column("score")
                }
            }
            struct Passport: MutablePersistableRecord {
                func encode(to container: inout PersistenceContainer) { preconditionFailure("should not be called") }
                enum Columns {
                    static let active = Column("active")
                }
            }
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("score", .integer)
            }
            try db.create(table: "passport") { t in
                t.column("countryCode", .text).notNull()
                t.column("citizenId", .integer).notNull()
                t.column("active", .boolean)
                t.primaryKey(["countryCode", "citizenId"])
            }
            do {
                try Player.all().groupByPrimaryKey().updateAll(db) { $0.score.set(to: 0) }
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "player" SET "score" = 0 WHERE "id" IN (\
                    SELECT "id" \
                    FROM "player" \
                    GROUP BY "id")
                    """)
            }
            do {
                try Player.all().group(Column.rowID).updateAll(db) { $0.score.set(to: 0) }
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "player" SET "score" = 0 WHERE "id" IN (\
                    SELECT "id" \
                    FROM "player" \
                    GROUP BY "rowid")
                    """)
            }
            do {
                try Passport.all().groupByPrimaryKey().updateAll(db) { $0.active.set(to: true) }
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "passport" SET "active" = 1 WHERE "rowid" IN (\
                    SELECT "rowid" \
                    FROM "passport" \
                    GROUP BY "rowid")
                    """)
            }
            do {
                try Passport.all().group(Column.rowID).updateAll(db) { $0.active.set(to: true) }
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "passport" SET "active" = 1 WHERE "rowid" IN (\
                    SELECT "rowid" \
                    FROM "passport" \
                    GROUP BY "rowid")
                    """)
            }
        }
    }
}

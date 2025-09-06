import XCTest
import GRDB

#warning("TODO: document the caveat that didInsert(with:) is unreliable due to last insert rowid not set by triggers: https://sqlite.org/c3ref/last_insert_rowid.html. See also https://sqlite.org/forum/forumpost/fb1c3b4a13")
private struct Player: Codable,
                       Equatable,
                       Identifiable,
                       FetchableRecord,
                       PersistableRecord
{
    var id: String
    var name: String
    var teamId: String?
    var isCaptain: Bool
}

private struct Team: Codable,
                     Equatable,
                     Identifiable,
                     FetchableRecord,
                     PersistableRecord
{
    var id: String
    var name: String
    
    static let captain = hasOne(Captain.self, using: Captain.teamForeignKey)
}

private struct Captain: Codable,
                        Equatable,
                        Identifiable,
                        FetchableRecord,
                        PersistableRecord
{
    var id: String
    var name: String
    var teamId: String
    
    enum Columns {
        static let teamId = Column(CodingKeys.teamId)
    }
    
    static let teamForeignKey = ForeignKey([Columns.teamId])
    static let team = belongsTo(Team.self, using: teamForeignKey)
}

private struct SchemaSource: DatabaseSchemaSource {
    func columnsForPrimaryKey(_ db: Database, inView view: DatabaseObjectID) throws -> [String]? {
        if view.name == "captain" {
            return ["id"]
        } else {
            // Do not customize
            return nil
        }
    }
}

class RecordMappedOnMutableViewTests : GRDBTestCase {
    private lazy var migrator: DatabaseMigrator = {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("Teams and players") { db in
            try db.create(table: "team") { t in
                t.primaryKey("id", .text)
                t.column("name", .text).notNull()
            }
            
            try db.create(table: "player") { t in
                t.primaryKey("id", .text)
                t.column("name", .text).notNull()
                t.belongsTo("team", onDelete: .setNull)
                t.column("isCaptain", .boolean).notNull()
            }
            
            // One unique captain per team
            try db.create(
                indexOn: "player", columns: ["teamId"],
                options: .unique,
                condition: Column("isCaptain"))
        }
        
        migrator.registerMigration("Read-only captains") { db in
            try db.execute(sql: """
                CREATE VIEW captain AS
                SELECT id, name, teamId
                FROM player
                WHERE isCaptain AND teamId IS NOT NULL;
                """)
        }
        
        migrator.registerMigration("Captain CRUD") { db in
            try db.execute(sql: """
                -- Insert trigger
                CREATE TRIGGER captain_insert
                INSTEAD OF INSERT ON captain
                BEGIN
                    -- Remove previous captain
                    UPDATE player SET isCaptain = 0
                    WHERE teamId = NEW.teamId AND isCaptain;
                    
                    -- Insert new captain
                    INSERT INTO player(id, name, teamId, isCaptain)
                    VALUES (NEW.id, NEW.name, NEW.teamId, 1);
                END;
                
                -- Update trigger
                CREATE TRIGGER captain_update
                INSTEAD OF UPDATE ON captain
                BEGIN
                    -- Remove previous captain
                    UPDATE player SET isCaptain = 0
                    WHERE teamId = NEW.teamId AND isCaptain AND id <> NEW.id;
                    
                    -- Update captain
                    UPDATE player SET name = NEW.name, teamId = NEW.teamId, isCaptain = 1
                    WHERE id = NEW.id;
                END;
                
                -- Delete trigger
                CREATE TRIGGER captain_delete
                INSTEAD OF DELETE ON captain
                BEGIN
                    DELETE FROM player WHERE id = OLD.id;
                END;
                """)
        }
        
        return migrator
    }()
    
    func test_read_only() throws {
        // No schema source, no CRUD
        let dbQueue = try makeDatabaseQueue()
        try migrator.migrate(dbQueue, upTo: "Read-only captains")
        try dbQueue.write { db in
            try Team(id: "red", name: "Red").insert(db)
            try Team(id: "blue", name: "Blue").insert(db)
            try Player(id: "alice", name: "Alice", teamId: "red", isCaptain: true).insert(db)
            try Player(id: "bob", name: "Bob", teamId: "blue", isCaptain: true).insert(db)
            try Player(id: "craig", name: "Craig", teamId: "blue", isCaptain: false).insert(db)

            let captains = try Captain.fetchAll(db)
            XCTAssertEqual(captains.count, 2)
            XCTAssert(captains.contains(Captain(id: "alice", name: "Alice", teamId: "red")))
            XCTAssert(captains.contains(Captain(id: "bob", name: "Bob", teamId: "blue")))
        }
    }
    
    func test_read_only_primary_key() throws {
        // No CRUD
        dbConfiguration.schemaSource = SchemaSource()
        let dbQueue = try makeDatabaseQueue()
        try migrator.migrate(dbQueue, upTo: "Read-only captains")
        try dbQueue.write { db in
            try Team(id: "red", name: "Red").insert(db)
            try Team(id: "blue", name: "Blue").insert(db)
            try Player(id: "alice", name: "Alice", teamId: "red", isCaptain: true).insert(db)
            try Player(id: "bob", name: "Bob", teamId: "blue", isCaptain: true).insert(db)
            try Player(id: "craig", name: "Craig", teamId: "blue", isCaptain: false).insert(db)
            
            let captains = try Captain.orderByPrimaryKey().fetchAll(db)
            XCTAssertEqual(captains, [
                Captain(id: "alice", name: "Alice", teamId: "red"),
                Captain(id: "bob", name: "Bob", teamId: "blue"),
            ])
            
            let alice = try Captain.find(db, id: "alice")
            XCTAssertEqual(alice, Captain(id: "alice", name: "Alice", teamId: "red"))
            
            try db.dumpTables(["team", "player", "captain"])
        }
    }
    
    func test_CRUD() throws {
        dbConfiguration.schemaSource = SchemaSource()
        let dbQueue = try makeDatabaseQueue()
        try migrator.migrate(dbQueue)
        try dbQueue.write { db in
            let red = Team(id: "red", name: "Red")
            try red.insert(db)
            
            let blue = Team(id: "blue", name: "Blue")
            try blue.insert(db)
            
            // Insert in view
            let alice = Captain(id: "alice", name: "Alice", teamId: red.id)
            try alice.insert(db)
            
            var bob = Captain(id: "bob", name: "Bob", teamId: blue.id)
            try bob.insert(db)
            do {
                try XCTAssertEqual(
                    Player.find(db, id: "bob"),
                    Player(id: "bob", name: "Bob", teamId: "blue", isCaptain: true))
            }
            
            // Update in view
            let modified = try bob.updateChanges(db) {
                $0.name = "Bobby"
                $0.teamId = red.id
            }
            XCTAssertTrue(modified)
            do {
                // Bob is captain of reds.
                try XCTAssertEqual(
                    Player.find(db, id: "bob"),
                    Player(id: "bob", name: "Bobby", teamId: "red", isCaptain: true))
                
                // Alice is no longer captain.
                try XCTAssertEqual(
                    Player.find(db, id: "alice"),
                    Player(id: "alice", name: "Alice", teamId: "red", isCaptain: false))
            }
            
            // Insert in view and replace caption
            let craig = Captain(id: "craig", name: "Craig", teamId: "red")
            try craig.insert(db)
            do {
                // Craig is captain of reds.
                try XCTAssertEqual(
                    Player.find(db, id: "craig"),
                    Player(id: "craig", name: "Craig", teamId: "red", isCaptain: true))
                
                // Bob is no longer captain.
                try XCTAssertEqual(
                    Player.find(db, id: "bob"),
                    Player(id: "bob", name: "Bobby", teamId: "red", isCaptain: false))
            }
            
            // Delete in view
            let deleted = try craig.delete(db)
            XCTAssertTrue(deleted)
            do {
                try XCTAssertNil(Player.fetchOne(db, id: "craig"))
            }
        }
    }
    
    func test_fetch_by_primary_key() throws {
        dbConfiguration.schemaSource = SchemaSource()
        let dbQueue = try makeDatabaseQueue()
        try migrator.migrate(dbQueue)
        try dbQueue.write { db in
            try Team(id: "red", name: "Red").insert(db)
            try Captain(id: "alice", name: "Alice", teamId: "red").insert(db)
            
            try XCTAssertEqual(
                Captain.fetchOne(db, key: "alice"),
                Captain(id: "alice", name: "Alice", teamId: "red"))
            
            try XCTAssertEqual(
                Captain.fetchOne(db, key: ["id": "alice"]),
                Captain(id: "alice", name: "Alice", teamId: "red"))
            
            try XCTAssertEqual(
                Captain.fetchOne(db, id: "alice"),
                Captain(id: "alice", name: "Alice", teamId: "red"))
            
            try XCTAssertEqual(
                Captain.find(db, id: "alice"),
                Captain(id: "alice", name: "Alice", teamId: "red"))
        }
    }
    
    func test_stable_order() throws {
        dbConfiguration.schemaSource = SchemaSource()
        let dbQueue = try makeDatabaseQueue()
        try migrator.migrate(dbQueue)
        try dbQueue.write { db in
            let request = Captain.all().withStableOrder()
            try assertEqualSQL(db, request, "SELECT * FROM \"captain\" ORDER BY \"id\"")
        }
    }
    
    func test_team_has_one_captain_request() throws {
        dbConfiguration.schemaSource = SchemaSource()
        let dbQueue = try makeDatabaseQueue()
        try migrator.migrate(dbQueue)
        try dbQueue.write { db in
            let red = Team(id: "red", name: "Red")
            try red.insert(db)
            
            let blue = Team(id: "blue", name: "Blue")
            try blue.insert(db)
            
            try Player(id: "alice", name: "Alice", teamId: "red", isCaptain: true).insert(db)
            
            do {
                let captain = try red.request(for: Team.captain).fetchOne(db)
                // This LIMIT 1 can't be removed until we know that teamId
                // is a unique key on the captain view.
                //
                // We considered using the teamId as the primary key for
                // captains, but when a captain does not know its player id:
                //
                // - Conversion between Player and Captain is uneasy
                // - We can't insert a captain because the player id is not
                //   auto-incremented (no sqlite3_last_insert_rowid
                //   from triggers)
                XCTAssertEqual(lastSQLQuery, """
                    SELECT * FROM "captain" WHERE "teamId" = 'red' LIMIT 1
                    """)
                XCTAssertEqual(captain, Captain(id: "alice", name: "Alice", teamId: "red"))
            }
            
            do {
                struct TeamWithCaptain: Decodable, Equatable, FetchableRecord {
                    var team: Team
                    var captain: Captain?
                }
                
                let teamsWithCaptain = try Team
                    .including(optional: Team.captain)
                    .asRequest(of: TeamWithCaptain.self)
                    .orderByPrimaryKey()
                    .fetchAll(db)
                
                XCTAssertEqual(lastSQLQuery, """
                    SELECT "team".*, "captain".* \ 
                    FROM "team" \
                    LEFT JOIN "captain" ON "captain"."teamId" = "team"."id" \ 
                    ORDER BY "team"."id"
                    """)
                
                XCTAssertEqual(teamsWithCaptain, [
                    TeamWithCaptain(
                        team: Team(id: "blue", name: "Blue"),
                        captain: nil),
                    TeamWithCaptain(
                        team: Team(id: "red", name: "Red"),
                        captain: Captain(id: "alice", name: "Alice", teamId: "red")),
                ])
            }
        }
    }
    
    func test_captain_belongs_to_team_request() throws {
        dbConfiguration.schemaSource = SchemaSource()
        let dbQueue = try makeDatabaseQueue()
        try migrator.migrate(dbQueue)
        try dbQueue.write { db in
            try Team(id: "red", name: "Red").insert(db)
            try Team(id: "blue", name: "Blue").insert(db)

            let alice = Captain(id: "alice", name: "Alice", teamId: "red")
            try alice.insert(db)
            try Captain(id: "bob", name: "Bob", teamId: "blue").insert(db)
            
            do {
                let team = try alice.request(for: Captain.team).fetchOne(db)
                XCTAssertEqual(lastSQLQuery, """
                    SELECT * FROM "team" WHERE "id" = 'red'
                    """)
                XCTAssertEqual(team, Team(id: "red", name: "Red"))
            }
            
            do {
                struct CaptainWithTeam: Decodable, Equatable, FetchableRecord {
                    var captain: Captain
                    var team: Team
                }
                
                let captainsWithTeam = try Captain
                    .including(required: Captain.team)
                    .asRequest(of: CaptainWithTeam.self)
                    .orderByPrimaryKey()
                    .fetchAll(db)
                
                XCTAssertEqual(lastSQLQuery, """
                    SELECT "captain".*, "team".* \
                    FROM "captain" \
                    JOIN "team" ON "team"."id" = "captain"."teamId" \
                    ORDER BY "captain"."id"
                    """)
                
                XCTAssertEqual(captainsWithTeam, [
                    CaptainWithTeam(
                        captain: Captain(id: "alice", name: "Alice", teamId: "red"),
                        team: Team(id: "red", name: "Red")),
                    CaptainWithTeam(
                        captain: Captain(id: "bob", name: "Bob", teamId: "blue"),
                        team: Team(id: "blue", name: "Blue")),
                ])
            }
        }
    }
}

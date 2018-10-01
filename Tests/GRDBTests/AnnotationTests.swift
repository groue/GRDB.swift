import XCTest
#if GRDBCIPHER
import GRDBCipher
#elseif GRDBCUSTOMSQLITE
import GRDBCustomSQLite
#else
import GRDB
#endif

private struct Team: Codable, FetchableRecord, PersistableRecord {
    static let players = hasMany(Player.self)
    var id: Int64
    var name: String
}

private struct Player: Codable, FetchableRecord, PersistableRecord {
    var id: Int64
    var teamId: Int64?
    var name: String
    var score: Int
}

class AnnotationTests: GRDBTestCase {
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
        try dbWriter.write { db in
            try db.create(table: "team") { t in
                t.column("id", .integer).primaryKey()
                t.column("name", .text)
            }
            try db.create(table: "player") { t in
                t.column("id", .integer).primaryKey()
                t.column("teamId", .integer).references("team")
                t.column("name", .text)
                t.column("score", .text)
            }
            
            try Team(id: 1, name: "Reds").insert(db)
            try Player(id: 1, teamId: 1, name: "Arthur", score: 100).insert(db)
            try Player(id: 2, teamId: 1, name: "Barbara", score: 1000).insert(db)
            try Team(id: 2, name: "Blues").insert(db)
            try Player(id: 3, teamId: 2, name: "Craig", score: 200).insert(db)
            try Player(id: 4, teamId: 2, name: "David", score: 500).insert(db)
            try Player(id: 5, teamId: 2, name: "Elise", score: 800).insert(db)
            try Team(id: 3, name: "Greens").insert(db)
        }
    }
    
    func testCount() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            let request = Team.annotated(with: Team.players.count)
            try assertEqualSQL(db, request, """
                SELECT "team".*, COUNT("player"."rowid") AS "playerCount" \
                FROM "team" \
                LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                GROUP BY "team"."id"
                """)
        }
    }
}

import XCTest
import GRDB

private struct Player: Codable, FetchableRecord, PersistableRecord {
    var id: Int64
    var name: String?
    var nickname: String?
    var score: Int
}

class SimpleFunctionTests: GRDBTestCase {

    override func setup(_ dbWriter: some DatabaseWriter) throws {
        try dbWriter.write { db in
            try db.create(table: "player") { t in
                t.primaryKey("id", .integer)
                t.column("name", .text)
                t.column("nickname", .text)
                t.column("score", .integer)
            }

            try Player(id: 1, name: "Arthur", nickname: "Artie", score: 100).insert(db)
            try Player(id: 2, name: "Jacob", nickname: nil, score: 200).insert(db)
            try Player(id: 3, name: nil, nickname: nil, score: 200).insert(db)
        }
    }

    func testCoalesce() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            do {
                let request = Player.annotated(with: coalesce([Column("nickname"), Column("name")]))
                try assertEqualSQL(db, request, """
                    SELECT *, COALESCE("nickname", "name") \
                    FROM "player"
                    """)
            }
            do {
                let request = Player.annotated(with: coalesce([Column("nickname"), Column("name")]).forKey("foo"))
                try assertEqualSQL(db, request, """
                    SELECT *, COALESCE("nickname", "name") AS "foo" \
                    FROM "player"
                    """)
            }
        }
    }
}

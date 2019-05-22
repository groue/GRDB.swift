//: To run this playground:
//:
//: - Open GRDB.xcworkspace
//: - Select the GRDBOSX scheme: menu Product > Scheme > GRDBOSX
//: - Build: menu Product > Build
//: - Select the playground in the Playgrounds Group
//: - Run the playground
//:
//: This sample code shows how to use GRDB to synchronize a database table
//: with a JSON payload. We use as few SQL queries as possible:
//:
//: - Only one SELECT query.
//: - One query per insert, delete, and update.
//: - Useless UPDATE statements are avoided.

import Foundation
import GRDB


// Open an in-memory database that logs all its SQL statements

var configuration = Configuration()
configuration.trace = { print($0) }
let dbQueue = DatabaseQueue(configuration: configuration)


// Create the database table to store the players

try dbQueue.inDatabase { db in
    try db.create(table: "player") { t in
        t.column("id", .integer).primaryKey()
        t.column("name", .text)
        t.column("score", .integer)
    }
}


// Define the Player `Codable` that is a `FetchableRecord` and `MutablePersistableRecord`.
struct Player: Codable, FetchableRecord, MutablePersistableRecord {
    var id: Int64
    var name: String
    var score: Int
    
    // Define database columns from CodingKeys
    private enum Columns {
        static let id = Column(CodingKeys.id)
        static let name = Column(CodingKeys.name)
        static let score = Column(CodingKeys.score)
    }
    
    // Update a player id after it has been inserted in the database.
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

extension Player {
    static func orderedById() -> QueryInterfaceRequest<Player> {
        return order(Columns.id)
    }
}

// This is just the container of our incoming JSON
struct PlayersToSync: Codable {
    let players: [Player]
}

// Synchronizes the players table with a JSON payload
func synchronizePlayers(with jsonString: String, in db: Database) throws {
    let jsonData = jsonString.data(using: .utf8)!
    let dataToSync = try JSONDecoder().decode(PlayersToSync.self, from: jsonData)

    // Sort new players to sync by id:
    let playersToSync = dataToSync.players.sorted { $0.id < $1.id }
    
    // Sort database players by id:
    let players = try Player.orderedById().fetchAll(db)
    
    // Now that both lists are sorted by id, we can compare them with
    // the sortedMerge() function (see https://gist.github.com/groue/7e8510849ded36f7d770).
    //
    // We'll delete, insert or update players, depending on their presence
    // in either lists.
    for mergeStep in sortedMerge(
        left: players,          // Database players
        right: playersToSync,   // PlayersToSync players (Decoded)
        leftKey: { $0.id },     // The id of a database player
        rightKey: { $0.id })    // The id of a PlayersToSync player
    {
        switch mergeStep {
        case .left(let player):
            // Delete database player without matching JSON player:
            try player.delete(db)
        case .right(var playerToSync):
            // Insert the Codable player without matching database player:
            try playerToSync.insert(db)
        case .common(let player, let playerToSync):
            // Update database player with its JSON counterpart:
            try playerToSync.updateChanges(db, from: player)
        }
    }
}

do {
    let jsonString1 = """
    {
        "players": [
            { "id": 1, "name": "Arthur", "score": 1000},
            { "id": 2, "name": "Barbara", "score": 2000},
            { "id": 3, "name": "Craig", "score": 500},
        ]
    }
    """
    print("---\nImport \(jsonString1)")
    try dbQueue.inDatabase { db in
        // SELECT * FROM player ORDER BY id
        // INSERT INTO "player" ("id", "name", "score") VALUES (1,'Arthur',1000)
        // INSERT INTO "player" ("id", "name", "score") VALUES (2,'Barbara',2000)
        // INSERT INTO "player" ("id", "name", "score") VALUES (3,'Craig',500)
        try synchronizePlayers(with: jsonString1, in: db)
    }
}

do {
    let jsonString2 = """
    {
        "players": [
            { "id": 2, "name": "Barbara", "score": 3000},
            { "id": 3, "name": "Craig", "score": 500},
            { "id": 4, "name": "Daniel", "score": 1500},
        ]
    }
    """
    print("---\nImport \(jsonString2)")
    try dbQueue.inDatabase { db in
        // SELECT * FROM player ORDER BY id
        // DELETE FROM "player" WHERE "id"=1
        // UPDATE "player" SET "score"=3000 WHERE "id"=2
        // INSERT INTO "player" ("id", "name", "score") VALUES (4,'Daniel',1500)
        try synchronizePlayers(with: jsonString2, in: db)
    }
}

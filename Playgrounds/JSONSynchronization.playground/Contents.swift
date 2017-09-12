// To run this playground, select and build the GRDBOSX scheme.
//
// This sample code shows how to use GRDB to synchronize a database table
// with a JSON payload. We use as few SQL queries as possible:
//
// - Only one SELECT query.
// - One query per insert, delete, and update.
// - Useless UPDATE statements are avoided.

import Foundation
import GRDB


// Open an in-memory database that logs all its SQL statements

var configuration = Configuration()
configuration.trace = { print($0) }
let dbQueue = DatabaseQueue(configuration: configuration)


// Create a database table

try dbQueue.inDatabase { db in
    try db.create(table: "players") { t in
        t.column("id", .integer).primaryKey()
        t.column("name", .text)
        t.column("score", .integer)
    }
}


// Define the Player subclass of GRDB's Record.
//
// Record provides change tracking that helps avoiding useless UPDATE statements.
class Player : Record {
    var id: Int64
    var name: String
    var score: Int
    
    convenience init(json: [String : Any]) {
        // For convenience, assume JSON keys are database columns, and reuse row initializer
        self.init(row: Row(json)!)
    }
    
    func update(from json: [String: Any]) {
        id = json["id"] as! Int64
        name = json["name"] as! String
        score = json["score"] as! Int
    }
    
    // Record overrides
    
    override class var databaseTableName: String {
        return "players"
    }
    
    required init(row: Row) {
        id = row["id"]
        name = row["name"]
        score = row["score"]
        super.init(row: row)
    }
    
    override func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["name"] = name
        container["score"] = score
    }
    
    override func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}


// Synchronizes the players table with a JSON payload
func synchronizePlayers(with jsonString: String, in db: Database) throws {
    let jsonData = jsonString.data(using: .utf8)!
    let json = try JSONSerialization.jsonObject(with: jsonData, options: []) as! [String: Any]
    
    // A support function that extracts an ID from a JSON player.
    func jsonPlayerId(_ jsonPlayer: [String: Any]) -> Int64 {
        return jsonPlayer["id"] as! Int64
    }
    
    // Sort JSON players by id:
    let jsonPlayers = (json["players"] as! [[String: Any]]).sorted {
        return jsonPlayerId($0) < jsonPlayerId($1)
    }
    
    // Sort database players by id:
    let players = try Player.order(Column("id")).fetchAll(db)
    
    // Now that both lists are sorted by id, we can compare them with
    // the sortedMerge() function (see https://gist.github.com/groue/7e8510849ded36f7d770).
    //
    // We'll delete, insert or update players, depending on their presence
    // in either lists.
    for mergeStep in sortedMerge(
        left: players,          // Database players
        right: jsonPlayers,     // JSON players
        leftKey: { $0.id },     // The id of a database player
        rightKey: jsonPlayerId) // The id of a JSON player
    {
        switch mergeStep {
        case .left(let player):
            // Delete database player without matching JSON player:
            try player.delete(db)
        case .right(let jsonPlayer):
            // Insert JSON player without matching database player:
            let player = Player(json: jsonPlayer)
            try player.insert(db)
        case .common(let player, let jsonPlayer):
            // Update database player with its JSON counterpart:
            player.update(from: jsonPlayer)
            try player.updateChanges(db)
        }
    }
}

do {
    let jsonString = """
    {
        "players": [
            { "id": 1, "name": "Arthur", "score": 1000},
            { "id": 2, "name": "Barbara", "score": 2000},
            { "id": 3, "name": "Craig", "score": 500},
        ]
    }
    """
    print("---\nImport \(jsonString)")
    try dbQueue.inDatabase { db in
        // SELECT * FROM players ORDER BY id
        // INSERT INTO "players" ("id", "name", "score") VALUES (1,'Arthur',1000)
        // INSERT INTO "players" ("id", "name", "score") VALUES (2,'Barbara',2000)
        // INSERT INTO "players" ("id", "name", "score") VALUES (3,'Craig',500)
        try synchronizePlayers(with: jsonString, in: db)
    }
}

do {
    let jsonString = """
    {
        "players": [
            { "id": 2, "name": "Barbara", "score": 3000},
            { "id": 3, "name": "Craig", "score": 500},
            { "id": 4, "name": "Daniel", "score": 1500},
        ]
    }
    """
    print("---\nImport \(jsonString)")
    try dbQueue.inDatabase { db in
        // SELECT * FROM players ORDER BY id
        // DELETE FROM "players" WHERE "id"=1
        // UPDATE "players" SET "score"=3000 WHERE "id"=2
        // INSERT INTO "players" ("id", "name", "score") VALUES (4,'Daniel',1500)
        try synchronizePlayers(with: jsonString, in: db)
    }
}

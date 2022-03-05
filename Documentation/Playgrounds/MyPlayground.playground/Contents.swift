// To run this playground, select and build the GRDBOSX scheme.

import GRDB

var configuration = Configuration()
configuration.prepareDatabase { db in
    db.trace { print("SQL> \($0)") }
}
let dbQueue = try DatabaseQueue(configuration: configuration)

struct Player: Codable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var name: String
    var score: Int
    
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

try dbQueue.write { db in
    try db.create(table: "player") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("name", .text).notNull()
        t.column("score", .integer).notNull()
    }
    
    do {
        var player = Player(id: nil, name: "Arthur", score: 100)
        try player.insert(db)
        player = Player(id: nil, name: "Barbara", score: 100)
        try player.insert(db)
    }
    
    do {
        let players = try Player.fetchAll(db)
        for player in players {
            print(player)
        }
    }
    
    do {
        let count = try Player.fetchCount(db)
        print(count)
    }
}

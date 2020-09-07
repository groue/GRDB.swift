// To run this playground, select and build the GRDBOSX scheme.

import GRDB

var configuration = Configuration()
configuration.prepareDatabase { db in
    db.trace { print("SQL> \($0)") }
}
let dbQueue = DatabaseQueue(configuration: configuration)

try! dbQueue.inDatabase { db in
    try db.create(table: "player") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("name", .text).notNull()
        t.column("score", .integer).notNull()
    }
    
    try db.execute(sql: "INSERT INTO player (name, score) VALUES (?, ?)", arguments: ["Arthur", 1000])
    try db.execute(sql: "INSERT INTO player (name, score) VALUES (?, ?)", arguments: ["Barbara", 1000])
    
    let names = try String.fetchAll(db, sql: "SELECT name FROM player")
    print(names)
}

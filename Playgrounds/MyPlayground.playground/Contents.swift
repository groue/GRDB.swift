// To run this playground, select and build the GRDBOSX scheme.

import GRDB


var configuration = Configuration()
configuration.trace = { print($0) }
let dbQueue = DatabaseQueue(configuration: configuration)

try! dbQueue.inDatabase { db in
    try db.create(table: "persons") { t in
        t.column("id", .integer).primaryKey()
        t.column("name", .text)
    }
    
    try db.execute(sql: "INSERT INTO persons (name) VALUES (?)", arguments: ["Arthur"])
    try db.execute(sql: "INSERT INTO persons (name) VALUES (?)", arguments: ["Barbara"])
    
    let names = try String.fetchAll(db, sql: "SELECT name FROM persons")
    print(names)
}

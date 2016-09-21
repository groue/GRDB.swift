// To run this playground, select and build the GRDBOSX scheme.

import GRDB

let path = "/tmp/database.sqlite"
var configuration = Configuration()
configuration.trace = { print($0) }
let dbQueue = try! DatabaseQueue(path: path, configuration: configuration)

try! dbQueue.inDatabase { db in
    try db.create(table: "persons", ifNotExists: true) { t in
        t.column("id", .integer).primaryKey()
        t.column("name", .text)
    }
}

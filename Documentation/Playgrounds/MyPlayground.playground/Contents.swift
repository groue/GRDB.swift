// To run this playground, select and build the GRDBOSX scheme.

import GRDB

var configuration = Configuration()
configuration.prepareDatabase { db in
    db.trace { print("SQL> \($0)") }
}
let dbQueue = DatabaseQueue(configuration: configuration)

extension SQLSpecificExpressible {
    func like(_ pattern: SQLExpressible, escape: SQLExpressible) -> SQLExpression {
        SQL("\(self) LIKE \(pattern) ESCAPE \(escape)").sqlExpression
    }
}

struct Player: Codable, FetchableRecord, PersistableRecord {
    var id: Int64
    var name: String
    var score: Int
}

try! dbQueue.inDatabase { db in
    try db.create(table: "player") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("name", .text).notNull()
        t.column("score", .integer).notNull()
    }
    
    try Player(id: 1, name: "toto 10% titi", score: 100).insert(db)
    try Player(id: 2, name: "toto", score: 100).insert(db)
    
    try Player.filter(Column("name").like("%10\\%%", escape: "\\")).fetchAll(db)
}

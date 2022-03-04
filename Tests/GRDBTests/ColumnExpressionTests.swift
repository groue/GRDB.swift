import XCTest
import GRDB

class ColumnExpressionTests: GRDBTestCase {
    
    func testRawColumnExpression() throws {
        struct Player: TableRecord, FetchableRecord, PersistableRecord {
            var id: Int64
            var name: String
            var score: Int
            
            struct Column: ColumnExpression {
                var name: String
            }
            
            enum Columns {
                static let id = Player.Column(name: "id")
                static let name = Player.Column(name: "name")
                static let score = Player.Column(name: "score")
            }
            
            // Test databaseSelection
            static let databaseSelection: [SQLSelectable] = [Columns.id, Columns.name, Columns.score]
            
            init(row: Row) throws {
                // Test row subscript
                id = try row[Columns.id]
                name = try row[Columns.name]
                score = try row[Columns.score]
            }
            
            func encode(to container: inout PersistenceContainer) {
                // Test container subscript
                container[Columns.id] = id
                container[Columns.name] = name
                container[Columns.score] = score
            }
            
            static var testRequest: QueryInterfaceRequest<Player> {
                // Test expression derivation
                return filter(Columns.name != nil).order(Columns.score.desc)
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name")
                t.column("score")
            }
            
            // Test rowId column identification
            try XCTAssertEqual(Player.filter(key: 1).databaseRegion(db).description, "player(id,name,score)[1]")
            try XCTAssertEqual(Player.filter(Player.Columns.id == 1).databaseRegion(db).description, "player(id,name,score)[1]")
            try XCTAssertEqual(Player.filter(1 == Player.Columns.id).databaseRegion(db).description, "player(id,name,score)[1]")
            try XCTAssertEqual(Player.filter(Player.Columns.id == 1 || Player.Columns.id == 2).databaseRegion(db).description, "player(id,name,score)[1,2]")
            try XCTAssertEqual(Player.filter([1, 2, 3].contains(Player.Columns.id)).databaseRegion(db).description, "player(id,name,score)[1,2,3]")
            
            // Test specific column updates
            let player = try Player(row: ["id": 1, "name": "Arthur", "score": 1000])
            try? player.update(db, columns: [Player.Columns.name, Player.Columns.score])
            XCTAssertEqual(lastSQLQuery, "UPDATE \"player\" SET \"name\"=\'Arthur\', \"score\"=1000 WHERE \"id\"=1")
            
            // Test compound expression
            let expression = Player.Columns.name == "foo"
            let request = Player.select(expression)
            try assertEqualSQL(db, request, "SELECT \"name\" = 'foo' FROM \"player\"")
        }
    }
    
    func testRawRepresentableColumnExpression() throws {
        struct Player: TableRecord, FetchableRecord, PersistableRecord {
            var id: Int64
            var name: String
            var score: Int
            
            enum Columns: String, ColumnExpression {
                case id, name, score
            }
            
            // Test databaseSelection
            static let databaseSelection: [SQLSelectable] = [Columns.id, Columns.name, Columns.score]
            
            init(row: Row) throws {
                // Test row subscript
                id = try row[Columns.id]
                name = try row[Columns.name]
                score = try row[Columns.score]
            }
            
            func encode(to container: inout PersistenceContainer) {
                // Test container subscript
                container[Columns.id] = id
                container[Columns.name] = name
                container[Columns.score] = score
            }
            
            static var testRequest: QueryInterfaceRequest<Player> {
                // Test expression derivation
                return filter(Columns.name != nil).order(Columns.score.desc)
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name")
                t.column("score")
            }
            
            // Test rowId column identification
            try XCTAssertEqual(Player.filter(key: 1).databaseRegion(db).description, "player(id,name,score)[1]")
            try XCTAssertEqual(Player.filter(Player.Columns.id == 1).databaseRegion(db).description, "player(id,name,score)[1]")
            try XCTAssertEqual(Player.filter(1 == Player.Columns.id).databaseRegion(db).description, "player(id,name,score)[1]")
            try XCTAssertEqual(Player.filter(Player.Columns.id == 1 || Player.Columns.id == 2).databaseRegion(db).description, "player(id,name,score)[1,2]")
            try XCTAssertEqual(Player.filter([1, 2, 3].contains(Player.Columns.id)).databaseRegion(db).description, "player(id,name,score)[1,2,3]")
            
            // Test specific column updates
            let player = try Player(row: ["id": 1, "name": "Arthur", "score": 1000])
            try? player.update(db, columns: [Player.Columns.name, Player.Columns.score])
            XCTAssertEqual(lastSQLQuery, "UPDATE \"player\" SET \"name\"=\'Arthur\', \"score\"=1000 WHERE \"id\"=1")
            
            // Test compound expression
            let expression = Player.Columns.name == "foo"
            let request = Player.select(expression)
            try assertEqualSQL(db, request, "SELECT \"name\" = 'foo' FROM \"player\"")
        }
    }
    
    func testColumnsDerivedFromCodingKeys() throws {
        struct Player: Codable, TableRecord, FetchableRecord, PersistableRecord {
            var id: Int64
            var name: String
            var score: Int
            
            enum CodingKeys: String, CodingKey {
                case id
                case name = "full_name"
                case score
            }
            
            enum Columns {
                static let id = Column(CodingKeys.id)
                static let name = Column(CodingKeys.name)
                static let score = Column(CodingKeys.score)
            }
            
            // Test databaseSelection
            static let databaseSelection: [SQLSelectable] = [Columns.id, Columns.name, Columns.score]
            
            static var testRequest: QueryInterfaceRequest<Player> {
                // Test expression derivation
                return filter(Columns.name != nil).order(Columns.score.desc)
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("full_name")
                t.column("score")
            }
            
            // Test rowId column identification
            try XCTAssertEqual(Player.filter(key: 1).databaseRegion(db).description, "player(full_name,id,score)[1]")
            try XCTAssertEqual(Player.filter(Player.Columns.id == 1).databaseRegion(db).description, "player(full_name,id,score)[1]")
            try XCTAssertEqual(Player.filter(1 == Player.Columns.id).databaseRegion(db).description, "player(full_name,id,score)[1]")
            try XCTAssertEqual(Player.filter(Player.Columns.id == 1 || Player.Columns.id == 2).databaseRegion(db).description, "player(full_name,id,score)[1,2]")
            try XCTAssertEqual(Player.filter([1, 2, 3].contains(Player.Columns.id)).databaseRegion(db).description, "player(full_name,id,score)[1,2,3]")
            
            // Test specific column updates
            let player = try Player(row: ["id": 1, "full_name": "Arthur", "score": 1000])
            try? player.update(db, columns: [Player.Columns.name, Player.Columns.score])
            XCTAssertEqual(lastSQLQuery, "UPDATE \"player\" SET \"full_name\"=\'Arthur\', \"score\"=1000 WHERE \"id\"=1")
            
            // Test compound expression
            let expression = Player.Columns.name == "foo"
            let request = Player.select(expression)
            try assertEqualSQL(db, request, "SELECT \"full_name\" = 'foo' FROM \"player\"")
        }
    }

    func testCodingKeysAsColumnExpression() throws {
        struct Player: Codable, TableRecord, FetchableRecord, PersistableRecord {
            var id: Int64
            var name: String
            var score: Int
            
            enum CodingKeys: String, CodingKey, ColumnExpression {
                case id
                case name = "full_name"
                case score
            }
            
            // Test databaseSelection
            static let databaseSelection: [SQLSelectable] = [CodingKeys.id, CodingKeys.name, CodingKeys.score]
            
            static var testRequest: QueryInterfaceRequest<Player> {
                // Test expression derivation
                return filter(CodingKeys.name != nil).order(CodingKeys.score.desc)
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("full_name")
                t.column("score")
            }
            
            // Test rowId column identification
            try XCTAssertEqual(Player.filter(key: 1).databaseRegion(db).description, "player(full_name,id,score)[1]")
            try XCTAssertEqual(Player.filter(Player.CodingKeys.id == 1).databaseRegion(db).description, "player(full_name,id,score)[1]")
            try XCTAssertEqual(Player.filter(1 == Player.CodingKeys.id).databaseRegion(db).description, "player(full_name,id,score)[1]")
            try XCTAssertEqual(Player.filter(Player.CodingKeys.id == 1 || Player.CodingKeys.id == 2).databaseRegion(db).description, "player(full_name,id,score)[1,2]")
            try XCTAssertEqual(Player.filter([1, 2, 3].contains(Player.CodingKeys.id)).databaseRegion(db).description, "player(full_name,id,score)[1,2,3]")
            
            // Test specific column updates
            let player = try Player(row: ["id": 1, "full_name": "Arthur", "score": 1000])
            try? player.update(db, columns: [Player.CodingKeys.name, Player.CodingKeys.score])
            XCTAssertEqual(lastSQLQuery, "UPDATE \"player\" SET \"full_name\"=\'Arthur\', \"score\"=1000 WHERE \"id\"=1")
            
            // Test compound expression
            let expression = Player.CodingKeys.name == "foo"
            let request = Player.select(expression)
            try assertEqualSQL(db, request, "SELECT \"full_name\" = 'foo' FROM \"player\"")
        }
    }
    
    func testDetachedColumn() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "t") { t in t.column("a") }
            
            // Regular columns are qualified
            do {
                let alias = TableAlias(name: "custom")
                let request = Table("t")
                    .aliased(alias)
                    .order(Column("a"))
                let sql = try request.makePreparedRequest(db).statement.sql
                XCTAssertEqual(sql, """
                    SELECT "custom".* FROM "t" "custom" ORDER BY "custom"."a"
                    """)
            }
            
            // Detached columns are NOT qualified
            do {
                let alias = TableAlias(name: "custom")
                let request = Table("t")
                    .aliased(alias)
                    .order(Column("a").detached)
                let sql = try request.makePreparedRequest(db).statement.sql
                XCTAssertEqual(sql, """
                    SELECT "custom".* FROM "t" "custom" ORDER BY "a"
                    """)
            }
            
            // Detached columns are quoted
            do {
                let alias = TableAlias(name: "custom")
                let request = Table("t")
                    .aliased(alias)
                    .select(Column("a").forKey("order"))
                    .order(Column("order").detached)
                let sql = try request.makePreparedRequest(db).statement.sql
                XCTAssertEqual(sql, """
                    SELECT "custom"."a" AS "order" FROM "t" "custom" ORDER BY "order"
                    """)
            }
        }
    }
}

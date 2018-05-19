import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

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
            
            static let databaseTableName = "players"
            // Test databaseSelection
            static let databaseSelection: [SQLSelectable] = [Columns.id, Columns.name, Columns.score]
            
            init(row: Row) {
                // Test row subscript
                id = row[Columns.id]
                name = row[Columns.name]
                score = row[Columns.score]
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
            try db.create(table: "players") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name")
                t.column("score")
            }
            
            // Test rowId column identification
            try XCTAssertEqual(Player.filter(key: 1).databaseRegion(db).description, "players(id,name,score)[1]")
            try XCTAssertEqual(Player.filter(Player.Columns.id == 1).databaseRegion(db).description, "players(id,name,score)[1]")
            try XCTAssertEqual(Player.filter(1 == Player.Columns.id).databaseRegion(db).description, "players(id,name,score)[1]")
            try XCTAssertEqual(Player.filter(Player.Columns.id == 1 || Player.Columns.id == 2).databaseRegion(db).description, "players(id,name,score)[1,2]")
            try XCTAssertEqual(Player.filter([1, 2, 3].contains(Player.Columns.id)).databaseRegion(db).description, "players(id,name,score)[1,2,3]")
            
            // Test specific column updates
            let player = Player(row: ["id": 1, "name": "Arthur", "score": 1000])
            try? player.update(db, columns: [Player.Columns.name, Player.Columns.score])
            XCTAssertEqual(lastSQLQuery, "UPDATE \"players\" SET \"name\"=\'Arthur\', \"score\"=1000 WHERE \"id\"=1")
            
            // Test FTS3 match expression
            let expression = try Player.Columns.name.match(FTS3Pattern(rawPattern: "foo"))
            let literal = expression.literal
            XCTAssertEqual(literal.sql, "(\"name\" MATCH ?)")
            XCTAssertEqual(literal.arguments, ["foo"])
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
            
            static let databaseTableName = "players"
            // Test databaseSelection
            static let databaseSelection: [SQLSelectable] = [Columns.id, Columns.name, Columns.score]
            
            init(row: Row) {
                // Test row subscript
                id = row[Columns.id]
                name = row[Columns.name]
                score = row[Columns.score]
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
            try db.create(table: "players") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name")
                t.column("score")
            }
            
            // Test rowId column identification
            try XCTAssertEqual(Player.filter(key: 1).databaseRegion(db).description, "players(id,name,score)[1]")
            try XCTAssertEqual(Player.filter(Player.Columns.id == 1).databaseRegion(db).description, "players(id,name,score)[1]")
            try XCTAssertEqual(Player.filter(1 == Player.Columns.id).databaseRegion(db).description, "players(id,name,score)[1]")
            try XCTAssertEqual(Player.filter(Player.Columns.id == 1 || Player.Columns.id == 2).databaseRegion(db).description, "players(id,name,score)[1,2]")
            try XCTAssertEqual(Player.filter([1, 2, 3].contains(Player.Columns.id)).databaseRegion(db).description, "players(id,name,score)[1,2,3]")
            
            // Test specific column updates
            let player = Player(row: ["id": 1, "name": "Arthur", "score": 1000])
            try? player.update(db, columns: [Player.Columns.name, Player.Columns.score])
            XCTAssertEqual(lastSQLQuery, "UPDATE \"players\" SET \"name\"=\'Arthur\', \"score\"=1000 WHERE \"id\"=1")
            
            // Test FTS3 match expression
            let expression = try Player.Columns.name.match(FTS3Pattern(rawPattern: "foo"))
            let literal = expression.literal
            XCTAssertEqual(literal.sql, "(\"name\" MATCH ?)")
            XCTAssertEqual(literal.arguments, ["foo"])
        }
    }
}

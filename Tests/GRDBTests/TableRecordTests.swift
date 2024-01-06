import XCTest
import GRDB

private struct RecordStruct: TableRecord { }
private struct CustomizedRecordStruct: TableRecord { static let databaseTableName = "CustomizedRecordStruct" }
private class RecordClass: TableRecord { }
private class RecordSubClass: RecordClass { }
private class CustomizedRecordClass: TableRecord { class var databaseTableName: String { "CustomizedRecordClass" } }
private class CustomizedRecordSubClass: CustomizedRecordClass { override class var databaseTableName: String { "CustomizedRecordSubClass" } }
private class CustomizedPlainRecord: Record { override class var databaseTableName: String { "CustomizedPlainRecord" } }
private enum Namespace {
    struct RecordStruct: TableRecord { }
    struct CustomizedRecordStruct: TableRecord { static let databaseTableName = "CustomizedRecordStruct" }
    class RecordClass: TableRecord { }
    class RecordSubClass: RecordClass { }
    class CustomizedRecordClass: TableRecord { class var databaseTableName: String { "CustomizedRecordClass" } }
    class CustomizedRecordSubClass: CustomizedRecordClass { override class var databaseTableName: String { "CustomizedRecordSubClass" } }
    class CustomizedPlainRecord: Record { override class var databaseTableName: String { "CustomizedPlainRecord" } }
}
private struct HTTPRequest: TableRecord { }
private struct TOEFL: TableRecord { }

class TableRecordTests: GRDBTestCase {
    
    func testDefaultDatabaseTableName() {
        struct InnerRecordStruct: TableRecord { }
        struct InnerCustomizedRecordStruct: TableRecord { static let databaseTableName = "InnerCustomizedRecordStruct" }
        class InnerRecordClass: TableRecord { }
        class InnerRecordSubClass: InnerRecordClass { }
        class InnerCustomizedRecordClass: TableRecord { class var databaseTableName: String { "InnerCustomizedRecordClass" } }
        class InnerCustomizedRecordSubClass: InnerCustomizedRecordClass { override class var databaseTableName: String { "InnerCustomizedRecordSubClass" } }
        class InnerCustomizedPlainRecord: Record { override class var databaseTableName: String { "InnerCustomizedPlainRecord" } }
        
        XCTAssertEqual(RecordStruct.databaseTableName, "recordStruct")
        XCTAssertEqual(CustomizedRecordStruct.databaseTableName, "CustomizedRecordStruct")
        XCTAssertEqual(RecordClass.databaseTableName, "recordClass")
        XCTAssertEqual(RecordSubClass.databaseTableName, "recordSubClass")
        XCTAssertEqual(CustomizedRecordClass.databaseTableName, "CustomizedRecordClass")
        XCTAssertEqual(CustomizedRecordSubClass.databaseTableName, "CustomizedRecordSubClass")
        XCTAssertEqual(CustomizedPlainRecord.databaseTableName, "CustomizedPlainRecord")
        
        XCTAssertEqual(Namespace.RecordStruct.databaseTableName, "recordStruct")
        XCTAssertEqual(Namespace.CustomizedRecordStruct.databaseTableName, "CustomizedRecordStruct")
        XCTAssertEqual(Namespace.RecordClass.databaseTableName, "recordClass")
        XCTAssertEqual(Namespace.RecordSubClass.databaseTableName, "recordSubClass")
        XCTAssertEqual(Namespace.CustomizedRecordClass.databaseTableName, "CustomizedRecordClass")
        XCTAssertEqual(Namespace.CustomizedRecordSubClass.databaseTableName, "CustomizedRecordSubClass")
        XCTAssertEqual(Namespace.CustomizedPlainRecord.databaseTableName, "CustomizedPlainRecord")

        XCTAssertEqual(InnerRecordStruct.databaseTableName, "innerRecordStruct")
        XCTAssertEqual(InnerCustomizedRecordStruct.databaseTableName, "InnerCustomizedRecordStruct")
        XCTAssertEqual(InnerRecordClass.databaseTableName, "innerRecordClass")
        XCTAssertEqual(InnerRecordSubClass.databaseTableName, "innerRecordSubClass")
        XCTAssertEqual(InnerCustomizedRecordClass.databaseTableName, "InnerCustomizedRecordClass")
        XCTAssertEqual(InnerCustomizedRecordSubClass.databaseTableName, "InnerCustomizedRecordSubClass")
        XCTAssertEqual(InnerCustomizedPlainRecord.databaseTableName, "InnerCustomizedPlainRecord")

        XCTAssertEqual(HTTPRequest.databaseTableName, "httpRequest")
        XCTAssertEqual(TOEFL.databaseTableName, "toefl")
        
        func tableName<T: TableRecord>(_ type: T.Type) -> String { T.databaseTableName }
        
        XCTAssertEqual(tableName(RecordStruct.self), "recordStruct")
        XCTAssertEqual(tableName(CustomizedRecordStruct.self), "CustomizedRecordStruct")
        XCTAssertEqual(tableName(RecordClass.self), "recordClass")
        XCTAssertEqual(tableName(RecordSubClass.self), "recordSubClass")
        XCTAssertEqual(tableName(CustomizedRecordClass.self), "CustomizedRecordClass")
        XCTAssertEqual(tableName(CustomizedRecordSubClass.self), "CustomizedRecordSubClass")
        XCTAssertEqual(tableName(CustomizedPlainRecord.self), "CustomizedPlainRecord")
        
        XCTAssertEqual(tableName(Namespace.RecordStruct.self), "recordStruct")
        XCTAssertEqual(tableName(Namespace.CustomizedRecordStruct.self), "CustomizedRecordStruct")
        XCTAssertEqual(tableName(Namespace.RecordClass.self), "recordClass")
        XCTAssertEqual(tableName(Namespace.RecordSubClass.self), "recordSubClass")
        XCTAssertEqual(tableName(Namespace.CustomizedRecordClass.self), "CustomizedRecordClass")
        XCTAssertEqual(tableName(Namespace.CustomizedRecordSubClass.self), "CustomizedRecordSubClass")
        XCTAssertEqual(tableName(Namespace.CustomizedPlainRecord.self), "CustomizedPlainRecord")
        
        XCTAssertEqual(tableName(InnerRecordStruct.self), "innerRecordStruct")
        XCTAssertEqual(tableName(InnerCustomizedRecordStruct.self), "InnerCustomizedRecordStruct")
        XCTAssertEqual(tableName(InnerRecordClass.self), "innerRecordClass")
        XCTAssertEqual(tableName(InnerRecordSubClass.self), "innerRecordSubClass")
        XCTAssertEqual(tableName(InnerCustomizedRecordClass.self), "InnerCustomizedRecordClass")
        XCTAssertEqual(tableName(InnerCustomizedRecordSubClass.self), "InnerCustomizedRecordSubClass")
        XCTAssertEqual(tableName(InnerCustomizedPlainRecord.self), "InnerCustomizedPlainRecord")
        
        XCTAssertEqual(tableName(HTTPRequest.self), "httpRequest")
        XCTAssertEqual(tableName(TOEFL.self), "toefl")
    }
    
    func testDefaultDatabaseSelection() throws {
        struct Record: TableRecord {
            static let databaseTableName = "t1"
        }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE t1(a,b,c)")
            _ = try Row.fetchAll(db, Record.all())
            XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"t1\"")
        }
    }
    
    func testExtendedDatabaseSelection() throws {
        struct Record: TableRecord {
            static let databaseTableName = "t1"
            static let databaseSelection: [any SQLSelectable] = [AllColumns(), Column.rowID]
        }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE t1(a,b,c)")
            _ = try Row.fetchAll(db, Record.all())
            XCTAssertEqual(lastSQLQuery, "SELECT *, \"rowid\" FROM \"t1\"")
        }
    }
    
    func testRestrictedDatabaseSelection() throws {
        struct Record: TableRecord {
            static let databaseTableName = "t1"
            static let databaseSelection: [any SQLSelectable] = [Column("a"), Column("b")]
        }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE t1(a,b,c)")
            _ = try Row.fetchAll(db, Record.all())
            XCTAssertEqual(lastSQLQuery, "SELECT \"a\", \"b\" FROM \"t1\"")
        }
    }
    
    func testRecordInAttachedDatabase() throws {
        #if GRDBCIPHER_USE_ENCRYPTION
        // Avoid error due to key not being provided:
        // file is not a database - while executing `ATTACH DATABASE...`
        throw XCTSkip("This test does not support encrypted databases")
        #endif
        
        struct Team: Codable, PersistableRecord, FetchableRecord, Equatable {
            var id: Int64
            var name: String
        }
        
        struct Player: Codable, PersistableRecord, FetchableRecord, Equatable {
            var id: Int64
            var teamID: Int64
            var name: String
            var email: String
        }
        
        struct PlayerInfo: Decodable, FetchableRecord, Equatable {
            var player: Player
            var team: Team
        }
        
        let db1 = try makeDatabaseQueue(filename: "db1.sqlite")
        try db1.write { db in
            try db.create(table: "team") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
            }
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("teamID", .integer).notNull().references("team")
                t.column("name", .text).notNull()
                t.column("email", .text).notNull().unique()
            }
        }
        
        let db2 = try makeDatabaseQueue(filename: "db2.sqlite")
        try db2.writeWithoutTransaction { db in
            try db.execute(literal: "ATTACH DATABASE \(db1.path) AS db1")
            try XCTAssertEqual(Player.fetchCount(db), 0)
            let team = Team(id: 1, name: "Arthur")
            let player = Player(id: 1, teamID: 1, name: "Arthur", email: "arthur@example.com")
            
            try team.insert(db)
            try player.insert(db)
            
            try XCTAssertEqual(Player.orderByPrimaryKey().fetchOne(db)?.name, "Arthur")
            try XCTAssertEqual(
                Player
                    .including(required: Player.belongsTo(Team.self))
                    .asRequest(of: PlayerInfo.self)
                    .fetchOne(db),
                PlayerInfo(player: player, team: team))
        }
    }
    
    func testCrossAttachedDatabaseAssociation() throws {
        #if GRDBCIPHER_USE_ENCRYPTION
        // Avoid error due to key not being provided:
        // file is not a database - while executing `ATTACH DATABASE...`
        throw XCTSkip("This test does not support encrypted databases")
        #endif
        
        struct Team: Codable, PersistableRecord, FetchableRecord, Equatable {
            var id: Int64
            var name: String
        }
        
        struct Player: Codable, PersistableRecord, FetchableRecord, Equatable {
            var id: Int64
            var teamID: Int64
            var name: String
            var email: String
        }
        
        struct PlayerInfo: Decodable, FetchableRecord, Equatable {
            var player: Player
            var team: Team
        }
        
        let db1 = try makeDatabaseQueue(filename: "db1.sqlite")
        try db1.write { db in
            try db.create(table: "team") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
            }
        }
        
        let db2 = try makeDatabaseQueue(filename: "db2.sqlite")
        try db2.writeWithoutTransaction { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("teamID", .integer).notNull()
                t.column("name", .text).notNull()
                t.column("email", .text).notNull().unique()
            }
            
            try db.execute(literal: "ATTACH DATABASE \(db1.path) AS db1")
            try XCTAssertEqual(Player.fetchCount(db), 0)
            let team = Team(id: 1, name: "Arthur")
            let player = Player(id: 1, teamID: 1, name: "Arthur", email: "arthur@example.com")
            
            try team.insert(db)
            try player.insert(db)
            
            try XCTAssertEqual(Player.orderByPrimaryKey().fetchOne(db)?.name, "Arthur")
            try XCTAssertEqual(
                Player
                    .including(required: Player.belongsTo(Team.self, using: ForeignKey(["teamID"])))
                    .asRequest(of: PlayerInfo.self)
                    .fetchOne(db),
                PlayerInfo(player: player, team: team))
        }
    }
}

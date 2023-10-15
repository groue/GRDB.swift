import XCTest
import GRDB

final class JSONColumnTests: GRDBTestCase {
    func test_JSONColumn_derived_from_CodingKey() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard sqlite3_libversion_number() >= 3038000 else {
            throw XCTSkip("JSON support is not available")
        }
#else
        guard #available(iOS 16, macOS 10.15, tvOS 17, watchOS 9, *) else {
            throw XCTSkip("JSON support is not available")
        }
#endif
        
        struct Player: Codable, TableRecord, FetchableRecord, PersistableRecord {
            var id: Int64
            var info: Data
            
            enum CodingKeys: String, CodingKey {
                case id
                case info = "info_json"
            }
            
            enum Columns {
                static let id = Column(CodingKeys.id)
                static let info = JSONColumn(CodingKeys.info)
            }
            
            static let databaseSelection: [any SQLSelectable] = [Columns.id, Columns.info]
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("info_json", .jsonText)
            }
            
            try assertEqualSQL(db, Player.all(), """
                SELECT "id", "info_json" FROM "player"
                """)
        }
    }
    
    func test_JSON_EXTRACT() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard sqlite3_libversion_number() >= 3038000 else {
            throw XCTSkip("JSON_EXTRACT is not available")
        }
#else
        guard #available(iOS 16, macOS 10.15, tvOS 17, watchOS 9, *) else {
            throw XCTSkip("JSON_EXTRACT is not available")
        }
#endif
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("info", .jsonText)
            }
            
            let player = Table("player")
            let info = JSONColumn("info")
            
            try assertEqualSQL(db, player.select(info.jsonExtract(atPath: "$.score")), """
                SELECT JSON_EXTRACT("info", '$.score') FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(info.jsonExtract(atPaths: ["$.score", "$.bonus"])), """
                SELECT JSON_EXTRACT("info", '$.score', '$.bonus') FROM "player"
                """)
        }
    }
    
    func test_extraction_operators() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard sqlite3_libversion_number() >= 3038000 else {
            throw XCTSkip("JSON operators are not available")
        }
#else
        guard #available(iOS 16, macOS 13.2, tvOS 17, watchOS 9, *) else {
            throw XCTSkip("JSON operators are not available")
        }
#endif
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("info", .jsonText)
            }
            
            let player = Table("player")
            let info = JSONColumn("info")
            
            try assertEqualSQL(db, player.select(info["score"]), """
                SELECT "info" ->> 'score' FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(info["$.score"]), """
                SELECT "info" ->> '$.score' FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(info.jsonRepresentation(atPath: "score")), """
                SELECT "info" -> 'score' FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(info.jsonRepresentation(atPath: "$.score")), """
                SELECT "info" -> '$.score' FROM "player"
                """)
        }
    }
}

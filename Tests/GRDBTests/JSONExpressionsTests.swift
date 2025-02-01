import XCTest
import GRDB

final class JSONExpressionsTests: GRDBTestCase {
    /// The SQL function used to build JSON expressions
    private let jsonFunction = (Database.sqliteLibVersionNumber >= 3045000) ? "JSONB" : "JSON"
    
    func test_Database_json() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3038000 else {
            throw XCTSkip("JSON support is not available")
        }
#else
        guard #available(iOS 16, tvOS 17, watchOS 9, *) else {
            throw XCTSkip("JSON support is not available")
        }
#endif
        
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.column("name", .text)
                t.column("info", .jsonText)
            }
            let player = Table("player")
            let nameColumn = Column("name")
            let infoColumn = JSONColumn("info")
            
            try assertEqualSQL(db, Database.json(#" { "a": [ "test" ] } "#), """
                JSON(' { "a": [ "test" ] } ')
                """)
            
            try assertEqualSQL(db, player.select(Database.json(nameColumn)), """
                SELECT JSON("name") FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.json(infoColumn)), """
                SELECT JSON("info") FROM "player"
                """)
        }
    }
    
    func test_Database_jsonb() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3045000 else {
            throw XCTSkip("JSONB is not available")
        }
        
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.column("name", .text)
                t.column("info", .jsonb)
            }
            let player = Table("player")
            let nameColumn = Column("name")
            let infoColumn = JSONColumn("info")
            
            try assertEqualSQL(db, Database.jsonb(#" { "a": [ "test" ] } "#), """
                JSONB(' { "a": [ "test" ] } ')
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonb(nameColumn)), """
                SELECT JSONB("name") FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonb(infoColumn)), """
                SELECT JSONB("info") FROM "player"
                """)
        }
#else
        throw XCTSkip("JSONB is not available")
#endif
    }
    
    func test_asJSON() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3038000 else {
            throw XCTSkip("JSON support is not available")
        }
#else
        guard #available(iOS 16, tvOS 17, watchOS 9, *) else {
            throw XCTSkip("JSON support is not available")
        }
#endif
        
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.column("name", .text)
                t.column("info", .jsonText)
            }
            let player = Table("player")
            let nameColumn = Column("name")
            let infoColumn = JSONColumn("info")
            
            try assertEqualSQL(db, player.select([
                #"[1, 2, 3]"#.databaseValue.asJSON,
                DatabaseValue.null.asJSON,
                nameColumn.asJSON,
                infoColumn.asJSON,
                abs(nameColumn).asJSON,
                abs(infoColumn).asJSON,
            ]), """
                SELECT \
                '[1, 2, 3]', \
                NULL, \
                "name", \
                "info", \
                ABS("name"), \
                ABS("info") \
                FROM "player"
                """)
            
            try assertEqualSQL(db, player.select([
                Database.jsonArray([
                    #"[1, 2, 3]"#.databaseValue.asJSON,
                    DatabaseValue.null.asJSON,
                    nameColumn.asJSON,
                    infoColumn.asJSON,
                    abs(nameColumn).asJSON,
                    abs(infoColumn).asJSON,
                ])
            ]), """
                SELECT JSON_ARRAY(\
                \(jsonFunction)('[1, 2, 3]'), \
                NULL, \
                \(jsonFunction)("name"), \
                \(jsonFunction)("info"), \
                \(jsonFunction)(ABS("name")), \
                \(jsonFunction)(ABS("info"))\
                ) FROM "player"
                """)
        }
    }
    
    func test_Database_jsonArray() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3038000 else {
            throw XCTSkip("JSON support is not available")
        }
#else
        guard #available(iOS 16, tvOS 17, watchOS 9, *) else {
            throw XCTSkip("JSON support is not available")
        }
#endif
        
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.column("name", .text)
                t.column("info", .jsonText)
            }
            let player = Table("player")
            let nameColumn = Column("name")
            let infoColumn = JSONColumn("info")
            
            try assertEqualSQL(db, Database.jsonArray(1...4), """
                JSON_ARRAY(1, 2, 3, 4)
                """)
            
            try assertEqualSQL(db, Database.jsonArray([1, 2, 3, 4]), """
                JSON_ARRAY(1, 2, 3, 4)
                """)
            
            try assertEqualSQL(db, Database.jsonArray([1, 2, "3", 4]), """
                JSON_ARRAY(1, 2, '3', 4)
                """)
            
            // Note: this JSON(JSON_EXTRACT(...)) is useful, when the extracted value is a string that contains JSON
            try assertEqualSQL(db, player
                .select(
                    Database.jsonArray([
                        nameColumn,
                        nameColumn.asJSON,
                        infoColumn,
                        infoColumn.jsonExtract(atPath: "address"),
                        infoColumn.jsonExtract(atPath: "address").asJSON,
                    ] as [any SQLExpressible])
                ), """
                SELECT JSON_ARRAY(\
                "name", \
                \(jsonFunction)("name"), \
                \(jsonFunction)("info"), \
                JSON_EXTRACT("info", 'address'), \
                \(jsonFunction)(JSON_EXTRACT("info", 'address'))\
                ) FROM "player"
                """)
        }
    }
    
    func test_Database_jsonArray_from_SQLJSONExpressible() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3038000 else {
            throw XCTSkip("JSON support is not available")
        }
#else
        guard #available(iOS 16, macOS 13.2, tvOS 17, watchOS 9, *) else {
            throw XCTSkip("JSON support is not available")
        }
#endif
        
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.column("name", .text)
                t.column("info", .jsonText)
            }
            let player = Table("player")
            let nameColumn = Column("name")
            let infoColumn = JSONColumn("info")
            
            // Note: this JSON(JSON_EXTRACT(...)) is useful, when the extracted value is a string that contains JSON
            try assertEqualSQL(db, player
                .select(
                    Database.jsonArray([
                        nameColumn,
                        nameColumn.asJSON,
                        infoColumn,
                        infoColumn["score"],
                        infoColumn["score"].asJSON,
                        infoColumn.jsonExtract(atPath: "address"),
                        infoColumn.jsonExtract(atPath: "address").asJSON,
                        infoColumn.jsonRepresentation(atPath: "address"),
                        infoColumn.jsonRepresentation(atPath: "address").asJSON,
                    ] as [any SQLExpressible])
                ), """
                SELECT JSON_ARRAY(\
                "name", \
                \(jsonFunction)("name"), \
                \(jsonFunction)("info"), \
                "info" ->> 'score', \
                \(jsonFunction)("info" ->> 'score'), \
                JSON_EXTRACT("info", 'address'), \
                \(jsonFunction)(JSON_EXTRACT("info", 'address')), \
                "info" -> 'address', \
                "info" -> 'address'\
                ) FROM "player"
                """)
            
            let alias = TableAlias(name: "p")
            
            try assertEqualSQL(db, player
                .aliased(alias)
                .select(
                    alias[
                        Database.jsonArray([
                            nameColumn,
                            nameColumn.asJSON,
                            infoColumn,
                            infoColumn["score"],
                            infoColumn.jsonExtract(atPath: "address"),
                            infoColumn.jsonRepresentation(atPath: "address"),
                        ] as [any SQLExpressible])
                    ]
                ), """
                SELECT JSON_ARRAY(\
                "p"."name", \
                \(jsonFunction)("p"."name"), \
                \(jsonFunction)("p"."info"), \
                "p"."info" ->> 'score', \
                JSON_EXTRACT("p"."info", 'address'), \
                "p"."info" -> 'address'\
                ) FROM "player" "p"
                """)
            
            try assertEqualSQL(db, player
                .aliased(alias)
                .select(
                    Database.jsonArray([
                        alias[nameColumn],
                        alias[nameColumn.asJSON],
                        alias[infoColumn],
                        alias[infoColumn["score"]],
                        alias[infoColumn.jsonExtract(atPath: "address")],
                        alias[infoColumn.jsonRepresentation(atPath: "address")],
                    ] as [any SQLExpressible])
                ), """
                SELECT JSON_ARRAY(\
                "p"."name", \
                \(jsonFunction)("p"."name"), \
                \(jsonFunction)("p"."info"), \
                "p"."info" ->> 'score', \
                JSON_EXTRACT("p"."info", 'address'), \
                "p"."info" -> 'address'\
                ) FROM "player" "p"
                """)
            
            try assertEqualSQL(db, player
                .aliased(alias)
                .select(
                    Database.jsonArray([
                        alias[nameColumn],
                        alias[nameColumn].asJSON,
                        alias[infoColumn],
                        alias[infoColumn]["score"],
                        alias[infoColumn].jsonExtract(atPath: "address"),
                        alias[infoColumn].jsonRepresentation(atPath: "address"),
                    ] as [any SQLExpressible])
                ), """
                SELECT JSON_ARRAY(\
                "p"."name", \
                \(jsonFunction)("p"."name"), \
                \(jsonFunction)("p"."info"), \
                "p"."info" ->> 'score', \
                JSON_EXTRACT("p"."info", 'address'), \
                "p"."info" -> 'address'\
                ) FROM "player" "p"
                """)
        }
    }
    
    func test_Database_jsonbArray() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3045000 else {
            throw XCTSkip("JSONB is not available")
        }
        
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.column("name", .text)
                t.column("info", .jsonText)
            }
            let player = Table("player")
            let nameColumn = Column("name")
            let infoColumn = JSONColumn("info")
            
            try assertEqualSQL(db, Database.jsonbArray(1...4), """
                JSONB_ARRAY(1, 2, 3, 4)
                """)
            
            try assertEqualSQL(db, Database.jsonbArray([1, 2, 3, 4]), """
                JSONB_ARRAY(1, 2, 3, 4)
                """)
            
            try assertEqualSQL(db, Database.jsonbArray([1, 2, "3", 4]), """
                JSONB_ARRAY(1, 2, '3', 4)
                """)
            
            // Note: this JSON(JSON_EXTRACT(...)) is useful, when the extracted value is a string that contains JSON
            try assertEqualSQL(db, player
                .select(
                    Database.jsonbArray([
                        nameColumn,
                        nameColumn.asJSON,
                        infoColumn,
                        infoColumn.jsonExtract(atPath: "address"),
                        infoColumn.jsonExtract(atPath: "address").asJSON,
                    ] as [any SQLExpressible])
                ), """
                SELECT JSONB_ARRAY(\
                "name", \
                JSONB("name"), \
                JSONB("info"), \
                JSON_EXTRACT("info", 'address'), \
                JSONB(JSON_EXTRACT("info", 'address'))\
                ) FROM "player"
                """)
        }
#else
        throw XCTSkip("JSONB is not available")
#endif
    }
    
    func test_Database_jsonbArray_from_SQLJSONExpressible() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3045000 else {
            throw XCTSkip("JSONB is not available")
        }
        
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.column("name", .text)
                t.column("info", .jsonText)
            }
            let player = Table("player")
            let nameColumn = Column("name")
            let infoColumn = JSONColumn("info")
            
            // Note: this JSON(JSON_EXTRACT(...)) is useful, when the extracted value is a string that contains JSON
            try assertEqualSQL(db, player
                .select(
                    Database.jsonbArray([
                        nameColumn,
                        nameColumn.asJSON,
                        infoColumn,
                        infoColumn["score"],
                        infoColumn["score"].asJSON,
                        infoColumn.jsonExtract(atPath: "address"),
                        infoColumn.jsonExtract(atPath: "address").asJSON,
                        infoColumn.jsonRepresentation(atPath: "address"),
                        infoColumn.jsonRepresentation(atPath: "address").asJSON,
                    ] as [any SQLExpressible])
                ), """
                SELECT JSONB_ARRAY(\
                "name", \
                JSONB("name"), \
                JSONB("info"), \
                "info" ->> 'score', \
                JSONB("info" ->> 'score'), \
                JSON_EXTRACT("info", 'address'), \
                JSONB(JSON_EXTRACT("info", 'address')), \
                "info" -> 'address', \
                "info" -> 'address'\
                ) FROM "player"
                """)
            
            let alias = TableAlias(name: "p")
            
            try assertEqualSQL(db, player
                .aliased(alias)
                .select(
                    alias[
                        Database.jsonbArray([
                            nameColumn,
                            nameColumn.asJSON,
                            infoColumn,
                            infoColumn["score"],
                            infoColumn.jsonExtract(atPath: "address"),
                            infoColumn.jsonRepresentation(atPath: "address"),
                        ] as [any SQLExpressible])
                    ]
                ), """
                SELECT JSONB_ARRAY(\
                "p"."name", \
                JSONB("p"."name"), \
                JSONB("p"."info"), \
                "p"."info" ->> 'score', \
                JSON_EXTRACT("p"."info", 'address'), \
                "p"."info" -> 'address'\
                ) FROM "player" "p"
                """)
            
            try assertEqualSQL(db, player
                .aliased(alias)
                .select(
                    Database.jsonbArray([
                        alias[nameColumn],
                        alias[nameColumn.asJSON],
                        alias[infoColumn],
                        alias[infoColumn["score"]],
                        alias[infoColumn.jsonExtract(atPath: "address")],
                        alias[infoColumn.jsonRepresentation(atPath: "address")],
                    ] as [any SQLExpressible])
                ), """
                SELECT JSONB_ARRAY(\
                "p"."name", \
                JSONB("p"."name"), \
                JSONB("p"."info"), \
                "p"."info" ->> 'score', \
                JSON_EXTRACT("p"."info", 'address'), \
                "p"."info" -> 'address'\
                ) FROM "player" "p"
                """)
            
            try assertEqualSQL(db, player
                .aliased(alias)
                .select(
                    Database.jsonbArray([
                        alias[nameColumn],
                        alias[nameColumn].asJSON,
                        alias[infoColumn],
                        alias[infoColumn]["score"],
                        alias[infoColumn].jsonExtract(atPath: "address"),
                        alias[infoColumn].jsonRepresentation(atPath: "address"),
                    ] as [any SQLExpressible])
                ), """
                SELECT JSONB_ARRAY(\
                "p"."name", \
                JSONB("p"."name"), \
                JSONB("p"."info"), \
                "p"."info" ->> 'score', \
                JSON_EXTRACT("p"."info", 'address'), \
                "p"."info" -> 'address'\
                ) FROM "player" "p"
                """)
        }
#else
        throw XCTSkip("JSONB is not available")
#endif
    }
    
    func test_Database_jsonArrayLength() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3038000 else {
            throw XCTSkip("JSON support is not available")
        }
#else
        guard #available(iOS 16, tvOS 17, watchOS 9, *) else {
            throw XCTSkip("JSON support is not available")
        }
#endif
        
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.column("name", .text)
                t.column("info", .jsonText)
            }
            let player = Table("player")
            let nameColumn = Column("name")
            let infoColumn = JSONColumn("info")
            
            try assertEqualSQL(db, Database.jsonArrayLength("[1,2,3,4]"), """
                JSON_ARRAY_LENGTH('[1,2,3,4]')
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonArrayLength(nameColumn)), """
                SELECT JSON_ARRAY_LENGTH("name") FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonArrayLength(infoColumn)), """
                SELECT JSON_ARRAY_LENGTH("info") FROM "player"
                """)
        }
    }
    
    func test_Database_jsonArrayLength_atPath() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3038000 else {
            throw XCTSkip("JSON support is not available")
        }
#else
        guard #available(iOS 16, tvOS 17, watchOS 9, *) else {
            throw XCTSkip("JSON support is not available")
        }
#endif
        
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.column("name", .text)
                t.column("info", .jsonText)
            }
            let player = Table("player")
            let nameColumn = Column("name")
            let infoColumn = JSONColumn("info")
            
            try assertEqualSQL(db, Database.jsonArrayLength(#"{"one":[1,2,3]}"#, atPath: "$.one"), """
                JSON_ARRAY_LENGTH('{"one":[1,2,3]}', '$.one')
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonArrayLength(nameColumn, atPath: "$.a")), """
                SELECT JSON_ARRAY_LENGTH("name", '$.a') FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonArrayLength(#"{"one":[1,2,3]}"#, atPath: nameColumn)), """
                SELECT JSON_ARRAY_LENGTH('{"one":[1,2,3]}', "name") FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonArrayLength(infoColumn, atPath: "$.a")), """
                SELECT JSON_ARRAY_LENGTH("info", '$.a') FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonArrayLength(#"{"one":[1,2,3]}"#, atPath: infoColumn)), """
                SELECT JSON_ARRAY_LENGTH('{"one":[1,2,3]}', "info") FROM "player"
                """)
        }
    }
    
    func test_Database_jsonErrorPosition() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3042000 else {
            throw XCTSkip("JSON_ERROR_JSON is not available")
        }
        
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.column("name", .text)
                t.column("info", .jsonText)
            }
            let player = Table("player")
            let nameColumn = Column("name")
            let infoColumn = JSONColumn("info")
            
            try assertEqualSQL(db, Database.jsonErrorPosition(#" { "a": [ "test" ] } "#), """
                JSON_ERROR_POSITION(' { "a": [ "test" ] } ')
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonErrorPosition(nameColumn)), """
                SELECT JSON_ERROR_POSITION("name") FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonErrorPosition(infoColumn)), """
                SELECT JSON_ERROR_POSITION("info") FROM "player"
                """)
        }
#else
        throw XCTSkip("JSON_ERROR_JSON is not available")
#endif
    }
    
    func test_Database_jsonExtract_atPath() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3038000 else {
            throw XCTSkip("JSON support is not available")
        }
#else
        guard #available(iOS 16, tvOS 17, watchOS 9, *) else {
            throw XCTSkip("JSON support is not available")
        }
#endif
        
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.column("name", .text)
                t.column("info", .jsonText)
            }
            let player = Table("player")
            let nameColumn = Column("name")
            let infoColumn = JSONColumn("info")
            
            try assertEqualSQL(db, Database.jsonExtract(#"{"a":123}"#, atPath: "$.a"), """
                JSON_EXTRACT('{"a":123}', '$.a')
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonExtract(nameColumn, atPath: "$.a")), """
                SELECT JSON_EXTRACT("name", '$.a') FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonExtract(infoColumn, atPath: "$.a")), """
                SELECT JSON_EXTRACT("info", '$.a') FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonExtract(#"{"a":123}"#, atPath: nameColumn)), """
                SELECT JSON_EXTRACT('{"a":123}', "name") FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonExtract(#"{"a":123}"#, atPath: infoColumn)), """
                SELECT JSON_EXTRACT('{"a":123}', "info") FROM "player"
                """)
        }
    }
    
    func test_Database_jsonExtract_atPaths() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3038000 else {
            throw XCTSkip("JSON support is not available")
        }
#else
        guard #available(iOS 16, tvOS 17, watchOS 9, *) else {
            throw XCTSkip("JSON support is not available")
        }
#endif
        
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.column("name", .text)
                t.column("info", .jsonText)
            }
            let player = Table("player")
            let nameColumn = Column("name")
            let infoColumn = JSONColumn("info")
            
            try assertEqualSQL(db, Database.jsonExtract(#"{"a":2,"c":[4,5]}"#, atPaths: ["$.c", "$.a"]), """
                JSON_EXTRACT('{"a":2,"c":[4,5]}', '$.c', '$.a')
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonExtract(nameColumn, atPaths: ["$.c", "$.a"])), """
                SELECT JSON_EXTRACT("name", '$.c', '$.a') FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonExtract(infoColumn, atPaths: ["$.c", "$.a"])), """
                SELECT JSON_EXTRACT("info", '$.c', '$.a') FROM "player"
                """)
        }
    }
    
    func test_Database_jsonbExtract_atPath() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3045000 else {
            throw XCTSkip("JSONB is not available")
        }
        
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.column("name", .text)
                t.column("info", .jsonText)
            }
            let player = Table("player")
            let nameColumn = Column("name")
            let infoColumn = JSONColumn("info")
            
            try assertEqualSQL(db, Database.jsonbExtract(#"{"a":123}"#, atPath: "$.a"), """
                JSONB_EXTRACT('{"a":123}', '$.a')
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonbExtract(nameColumn, atPath: "$.a")), """
                SELECT JSONB_EXTRACT("name", '$.a') FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonbExtract(infoColumn, atPath: "$.a")), """
                SELECT JSONB_EXTRACT("info", '$.a') FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonbExtract(#"{"a":123}"#, atPath: nameColumn)), """
                SELECT JSONB_EXTRACT('{"a":123}', "name") FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonbExtract(#"{"a":123}"#, atPath: infoColumn)), """
                SELECT JSONB_EXTRACT('{"a":123}', "info") FROM "player"
                """)
        }
#else
        throw XCTSkip("JSONB is not available")
#endif
    }
    
    func test_Database_jsonbExtract_atPaths() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3045000 else {
            throw XCTSkip("JSONB is not available")
        }
        
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.column("name", .text)
                t.column("info", .jsonText)
            }
            let player = Table("player")
            let nameColumn = Column("name")
            let infoColumn = JSONColumn("info")
            
            try assertEqualSQL(db, Database.jsonbExtract(#"{"a":2,"c":[4,5]}"#, atPaths: ["$.c", "$.a"]), """
                JSONB_EXTRACT('{"a":2,"c":[4,5]}', '$.c', '$.a')
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonbExtract(nameColumn, atPaths: ["$.c", "$.a"])), """
                SELECT JSONB_EXTRACT("name", '$.c', '$.a') FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonbExtract(infoColumn, atPaths: ["$.c", "$.a"])), """
                SELECT JSONB_EXTRACT("info", '$.c', '$.a') FROM "player"
                """)
        }
#else
        throw XCTSkip("JSONB is not available")
#endif
    }
    
    func test_Database_jsonInsert() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3038000 else {
            throw XCTSkip("JSON support is not available")
        }
#else
        guard #available(iOS 16, tvOS 17, watchOS 9, *) else {
            throw XCTSkip("JSON support is not available")
        }
#endif
        
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.column("name", .text)
                t.column("info", .jsonText)
            }
            let player = Table("player")
            let nameColumn = Column("name")
            let infoColumn = JSONColumn("info")
            
            try assertEqualSQL(db, Database.jsonInsert("[1,2,3,4]", ["$[#]": #"{"e":5}"#]), """
                JSON_INSERT('[1,2,3,4]', '$[#]', '{"e":5}')
                """)
            
            try assertEqualSQL(db, Database.jsonInsert("[1,2,3,4]", ["$[#]": #"{"e":5}"#.databaseValue.asJSON]), """
                JSON_INSERT('[1,2,3,4]', '$[#]', \(jsonFunction)('{"e":5}'))
                """)
            
            try assertEqualSQL(db, Database.jsonInsert("[1,2,3,4]", ["$[#]": Database.json(#"{"e":5}"#)]), """
                JSON_INSERT('[1,2,3,4]', '$[#]', JSON('{"e":5}'))
                """)
            
            try assertEqualSQL(db, Database.jsonInsert("[1,2,3,4]", ["$[#]": Database.jsonObject(["e": 5])]), """
                JSON_INSERT('[1,2,3,4]', '$[#]', JSON_OBJECT('e', 5))
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonInsert(nameColumn, ["$[#]": 99])), """
                SELECT JSON_INSERT("name", '$[#]', 99) FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonInsert(infoColumn, ["$[#]": 99])), """
                SELECT JSON_INSERT("info", '$[#]', 99) FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonInsert("[1,2,3,4]", ["$[#]": nameColumn])), """
                SELECT JSON_INSERT('[1,2,3,4]', '$[#]', "name") FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonInsert("[1,2,3,4]", ["$[#]": infoColumn])), """
                SELECT JSON_INSERT('[1,2,3,4]', '$[#]', \(jsonFunction)("info")) FROM "player"
                """)
        }
    }
    
    func test_Database_jsonbInsert() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3045000 else {
            throw XCTSkip("JSONB is not available")
        }
        
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.column("name", .text)
                t.column("info", .jsonText)
            }
            let player = Table("player")
            let nameColumn = Column("name")
            let infoColumn = JSONColumn("info")
            
            try assertEqualSQL(db, Database.jsonbInsert("[1,2,3,4]", ["$[#]": #"{"e":5}"#]), """
                JSONB_INSERT('[1,2,3,4]', '$[#]', '{"e":5}')
                """)
            
            try assertEqualSQL(db, Database.jsonbInsert("[1,2,3,4]", ["$[#]": #"{"e":5}"#.databaseValue.asJSON]), """
                JSONB_INSERT('[1,2,3,4]', '$[#]', JSONB('{"e":5}'))
                """)
            
            try assertEqualSQL(db, Database.jsonbInsert("[1,2,3,4]", ["$[#]": Database.json(#"{"e":5}"#)]), """
                JSONB_INSERT('[1,2,3,4]', '$[#]', JSON('{"e":5}'))
                """)
            
            try assertEqualSQL(db, Database.jsonbInsert("[1,2,3,4]", ["$[#]": Database.jsonb(#"{"e":5}"#)]), """
                JSONB_INSERT('[1,2,3,4]', '$[#]', JSONB('{"e":5}'))
                """)
            
            try assertEqualSQL(db, Database.jsonbInsert("[1,2,3,4]", ["$[#]": Database.jsonObject(["e": 5])]), """
                JSONB_INSERT('[1,2,3,4]', '$[#]', JSON_OBJECT('e', 5))
                """)
            
            try assertEqualSQL(db, Database.jsonbInsert("[1,2,3,4]", ["$[#]": Database.jsonbObject(["e": 5])]), """
                JSONB_INSERT('[1,2,3,4]', '$[#]', JSONB_OBJECT('e', 5))
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonbInsert(nameColumn, ["$[#]": 99])), """
                SELECT JSONB_INSERT("name", '$[#]', 99) FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonbInsert(infoColumn, ["$[#]": 99])), """
                SELECT JSONB_INSERT("info", '$[#]', 99) FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonbInsert("[1,2,3,4]", ["$[#]": nameColumn])), """
                SELECT JSONB_INSERT('[1,2,3,4]', '$[#]', "name") FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonbInsert("[1,2,3,4]", ["$[#]": infoColumn])), """
                SELECT JSONB_INSERT('[1,2,3,4]', '$[#]', JSONB("info")) FROM "player"
                """)
        }
#else
        throw XCTSkip("JSONB is not available")
#endif
    }
    
    func test_Database_jsonReplace() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3038000 else {
            throw XCTSkip("JSON support is not available")
        }
#else
        guard #available(iOS 16, tvOS 17, watchOS 9, *) else {
            throw XCTSkip("JSON support is not available")
        }
#endif
        
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.column("name", .text)
                t.column("info", .jsonText)
            }
            let player = Table("player")
            let nameColumn = Column("name")
            let infoColumn = JSONColumn("info")
            
            try assertEqualSQL(db, Database.jsonReplace(#"{"a":2,"c":4}"#, ["$.a": #"{"e":5}"#]), """
                JSON_REPLACE('{"a":2,"c":4}', '$.a', '{"e":5}')
                """)
            
            try assertEqualSQL(db, Database.jsonReplace(#"{"a":2,"c":4}"#, ["$.a": #"{"e":5}"#.databaseValue.asJSON]), """
                JSON_REPLACE('{"a":2,"c":4}', '$.a', \(jsonFunction)('{"e":5}'))
                """)
            
            try assertEqualSQL(db, Database.jsonReplace(#"{"a":2,"c":4}"#, ["$.a": Database.json(#"{"e":5}"#)]), """
                JSON_REPLACE('{"a":2,"c":4}', '$.a', JSON('{"e":5}'))
                """)
            
            try assertEqualSQL(db, Database.jsonReplace(#"{"a":2,"c":4}"#, ["$.a": Database.jsonObject(["e": 5])]), """
                JSON_REPLACE('{"a":2,"c":4}', '$.a', JSON_OBJECT('e', 5))
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonReplace(nameColumn, ["$.a": 99])), """
                SELECT JSON_REPLACE("name", '$.a', 99) FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonReplace(infoColumn, ["$.a": 99])), """
                SELECT JSON_REPLACE("info", '$.a', 99) FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonReplace(#"{"a":2,"c":4}"#, ["$.a": nameColumn])), """
                SELECT JSON_REPLACE('{"a":2,"c":4}', '$.a', "name") FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonReplace(#"{"a":2,"c":4}"#, ["$.a": infoColumn])), """
                SELECT JSON_REPLACE('{"a":2,"c":4}', '$.a', \(jsonFunction)("info")) FROM "player"
                """)
        }
    }
    
    func test_Database_jsonbReplace() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3045000 else {
            throw XCTSkip("JSONB is not available")
        }
        
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.column("name", .text)
                t.column("info", .jsonText)
            }
            let player = Table("player")
            let nameColumn = Column("name")
            let infoColumn = JSONColumn("info")
            
            try assertEqualSQL(db, Database.jsonbReplace(#"{"a":2,"c":4}"#, ["$.a": #"{"e":5}"#]), """
                JSONB_REPLACE('{"a":2,"c":4}', '$.a', '{"e":5}')
                """)
            
            try assertEqualSQL(db, Database.jsonbReplace(#"{"a":2,"c":4}"#, ["$.a": #"{"e":5}"#.databaseValue.asJSON]), """
                JSONB_REPLACE('{"a":2,"c":4}', '$.a', JSONB('{"e":5}'))
                """)
            
            try assertEqualSQL(db, Database.jsonbReplace(#"{"a":2,"c":4}"#, ["$.a": Database.json(#"{"e":5}"#)]), """
                JSONB_REPLACE('{"a":2,"c":4}', '$.a', JSON('{"e":5}'))
                """)
            
            try assertEqualSQL(db, Database.jsonbReplace(#"{"a":2,"c":4}"#, ["$.a": Database.jsonb(#"{"e":5}"#)]), """
                JSONB_REPLACE('{"a":2,"c":4}', '$.a', JSONB('{"e":5}'))
                """)
            
            try assertEqualSQL(db, Database.jsonbReplace(#"{"a":2,"c":4}"#, ["$.a": Database.jsonObject(["e": 5])]), """
                JSONB_REPLACE('{"a":2,"c":4}', '$.a', JSON_OBJECT('e', 5))
                """)
            
            try assertEqualSQL(db, Database.jsonbReplace(#"{"a":2,"c":4}"#, ["$.a": Database.jsonbObject(["e": 5])]), """
                JSONB_REPLACE('{"a":2,"c":4}', '$.a', JSONB_OBJECT('e', 5))
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonbReplace(nameColumn, ["$.a": 99])), """
                SELECT JSONB_REPLACE("name", '$.a', 99) FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonbReplace(infoColumn, ["$.a": 99])), """
                SELECT JSONB_REPLACE("info", '$.a', 99) FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonbReplace(#"{"a":2,"c":4}"#, ["$.a": nameColumn])), """
                SELECT JSONB_REPLACE('{"a":2,"c":4}', '$.a', "name") FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonbReplace(#"{"a":2,"c":4}"#, ["$.a": infoColumn])), """
                SELECT JSONB_REPLACE('{"a":2,"c":4}', '$.a', JSONB("info")) FROM "player"
                """)
        }
#else
        throw XCTSkip("JSONB is not available")
#endif
    }
    
    func test_Database_jsonSet() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3038000 else {
            throw XCTSkip("JSON support is not available")
        }
#else
        guard #available(iOS 16, tvOS 17, watchOS 9, *) else {
            throw XCTSkip("JSON support is not available")
        }
#endif
        
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.column("name", .text)
                t.column("info", .jsonText)
            }
            let player = Table("player")
            let nameColumn = Column("name")
            let infoColumn = JSONColumn("info")
            
            try assertEqualSQL(db, Database.jsonSet(#"{"a":2,"c":4}"#, ["$.a": #"{"e":5}"#]), """
                JSON_SET('{"a":2,"c":4}', '$.a', '{"e":5}')
                """)
            
            try assertEqualSQL(db, Database.jsonSet(#"{"a":2,"c":4}"#, ["$.a": #"{"e":5}"#.databaseValue.asJSON]), """
                JSON_SET('{"a":2,"c":4}', '$.a', \(jsonFunction)('{"e":5}'))
                """)
            
            try assertEqualSQL(db, Database.jsonSet(#"{"a":2,"c":4}"#, ["$.a": Database.json(#"{"e":5}"#)]), """
                JSON_SET('{"a":2,"c":4}', '$.a', JSON('{"e":5}'))
                """)
            
            try assertEqualSQL(db, Database.jsonSet(#"{"a":2,"c":4}"#, ["$.a": Database.jsonObject(["e": 5])]), """
                JSON_SET('{"a":2,"c":4}', '$.a', JSON_OBJECT('e', 5))
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonSet(nameColumn, ["$.a": 99])), """
                SELECT JSON_SET("name", '$.a', 99) FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonSet(infoColumn, ["$.a": 99])), """
                SELECT JSON_SET("info", '$.a', 99) FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonSet(#"{"a":2,"c":4}"#, ["$.a": nameColumn])), """
                SELECT JSON_SET('{"a":2,"c":4}', '$.a', "name") FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonSet(#"{"a":2,"c":4}"#, ["$.a": infoColumn])), """
                SELECT JSON_SET('{"a":2,"c":4}', '$.a', \(jsonFunction)("info")) FROM "player"
                """)
        }
    }
    
    func test_Database_jsonbSet() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3045000 else {
            throw XCTSkip("JSONB is not available")
        }
        
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.column("name", .text)
                t.column("info", .jsonText)
            }
            let player = Table("player")
            let nameColumn = Column("name")
            let infoColumn = JSONColumn("info")
            
            try assertEqualSQL(db, Database.jsonbSet(#"{"a":2,"c":4}"#, ["$.a": #"{"e":5}"#]), """
                JSONB_SET('{"a":2,"c":4}', '$.a', '{"e":5}')
                """)
            
            try assertEqualSQL(db, Database.jsonbSet(#"{"a":2,"c":4}"#, ["$.a": #"{"e":5}"#.databaseValue.asJSON]), """
                JSONB_SET('{"a":2,"c":4}', '$.a', JSONB('{"e":5}'))
                """)
            
            try assertEqualSQL(db, Database.jsonbSet(#"{"a":2,"c":4}"#, ["$.a": Database.json(#"{"e":5}"#)]), """
                JSONB_SET('{"a":2,"c":4}', '$.a', JSON('{"e":5}'))
                """)
            
            try assertEqualSQL(db, Database.jsonbSet(#"{"a":2,"c":4}"#, ["$.a": Database.jsonb(#"{"e":5}"#)]), """
                JSONB_SET('{"a":2,"c":4}', '$.a', JSONB('{"e":5}'))
                """)
            
            try assertEqualSQL(db, Database.jsonbSet(#"{"a":2,"c":4}"#, ["$.a": Database.jsonObject(["e": 5])]), """
                JSONB_SET('{"a":2,"c":4}', '$.a', JSON_OBJECT('e', 5))
                """)
            
            try assertEqualSQL(db, Database.jsonbSet(#"{"a":2,"c":4}"#, ["$.a": Database.jsonbObject(["e": 5])]), """
                JSONB_SET('{"a":2,"c":4}', '$.a', JSONB_OBJECT('e', 5))
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonbSet(nameColumn, ["$.a": 99])), """
                SELECT JSONB_SET("name", '$.a', 99) FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonbSet(infoColumn, ["$.a": 99])), """
                SELECT JSONB_SET("info", '$.a', 99) FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonbSet(#"{"a":2,"c":4}"#, ["$.a": nameColumn])), """
                SELECT JSONB_SET('{"a":2,"c":4}', '$.a', "name") FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonbSet(#"{"a":2,"c":4}"#, ["$.a": infoColumn])), """
                SELECT JSONB_SET('{"a":2,"c":4}', '$.a', JSONB("info")) FROM "player"
                """)
        }
#else
        throw XCTSkip("JSONB is not available")
#endif
    }
    
    func test_Database_jsonObject_from_Dictionary() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3038000 else {
            throw XCTSkip("JSON support is not available")
        }
#else
        guard #available(iOS 16, tvOS 17, watchOS 9, *) else {
            throw XCTSkip("JSON support is not available")
        }
#endif
        
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.column("name", .text)
                t.column("info", .jsonText)
            }
            let player = Table("player")
            let nameColumn = Column("name")
            let infoColumn = JSONColumn("info")
            
            try assertEqualSQL(
                db,
                Database.jsonObject([
                    "a": 2,
                ] as [String: Int]), """
                JSON_OBJECT('a', 2)
                """)
            
            try assertEqualSQL(
                db,
                Database.jsonObject([
                    "c": #"{"e":5}"#,
                ] as [String: any SQLExpressible]), """
                JSON_OBJECT('c', '{"e":5}')
                """)
            
            try assertEqualSQL(
                db,
                Database.jsonObject([
                    "c": #"{"e":5}"#.databaseValue.asJSON,
                ] as [String: any SQLExpressible]), """
                JSON_OBJECT('c', \(jsonFunction)('{"e":5}'))
                """)
            
            try assertEqualSQL(
                db,
                Database.jsonObject([
                    "c": Database.jsonObject(["e": 5]),
                ]), """
                JSON_OBJECT('c', JSON_OBJECT('e', 5))
                """)
            
            try assertEqualSQL(
                db,
                Database.jsonObject([
                    "c": Database.json(#"{"e":5}"#),
                ]), """
                JSON_OBJECT('c', JSON('{"e":5}'))
                """)
            
            try assertEqualSQL(
                db,
                player.select(
                    Database.jsonObject([
                        "a": nameColumn,
                    ])
                ), """
                SELECT JSON_OBJECT('a', "name") FROM "player"
                """)
            
            try assertEqualSQL(
                db,
                player.select(
                    Database.jsonObject([
                        "c": infoColumn,
                    ])
                ), """
                SELECT JSON_OBJECT('c', \(jsonFunction)("info")) FROM "player"
                """)
            
            try assertEqualSQL(
                db,
                player.select(
                    Database.jsonObject([
                        "a": Database.json(nameColumn),
                    ])
                ), """
                SELECT JSON_OBJECT('a', JSON("name")) FROM "player"
                """)
            
            try assertEqualSQL(
                db,
                player.select(
                    Database.jsonObject([
                        "c": Database.json(infoColumn),
                    ])
                ), """
                SELECT JSON_OBJECT('c', JSON("info")) FROM "player"
                """)
        }
    }
    
    func test_Database_jsonObject_from_Array() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3038000 else {
            throw XCTSkip("JSON support is not available")
        }
#else
        guard #available(iOS 16, tvOS 17, watchOS 9, *) else {
            throw XCTSkip("JSON support is not available")
        }
#endif
        
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.column("name", .text)
                t.column("info", .jsonText)
            }
            let player = Table("player")
            let nameColumn = Column("name")
            let infoColumn = JSONColumn("info")
            
            // Ordered Array
            
            try assertEqualSQL(
                db,
                Database.jsonObject([
                    (key: "a", value: 2),
                    (key: "c", value: #"{"e":5}"#),
                ] as [(key: String, value: any SQLExpressible)]), """
                JSON_OBJECT('a', 2, 'c', '{"e":5}')
                """)
            
            try assertEqualSQL(
                db,
                Database.jsonObject([
                    (key: "a", value: 2),
                    (key: "c", value: #"{"e":5}"#.databaseValue.asJSON),
                ] as [(key: String, value: any SQLExpressible)]), """
                JSON_OBJECT('a', 2, 'c', \(jsonFunction)('{"e":5}'))
                """)
            
            try assertEqualSQL(
                db,
                Database.jsonObject([
                    (key: "a", value: 2),
                    (key: "c", value: Database.jsonObject(["e": 5])),
                ] as [(key: String, value: any SQLExpressible)]), """
                JSON_OBJECT('a', 2, 'c', JSON_OBJECT('e', 5))
                """)
            
            try assertEqualSQL(
                db,
                Database.jsonObject([
                    (key: "a", value: 2),
                    (key: "c", value: Database.json(#"{"e":5}"#)),
                ] as [(key: String, value: any SQLExpressible)]), """
                JSON_OBJECT('a', 2, 'c', JSON('{"e":5}'))
                """)
            
            try assertEqualSQL(
                db,
                player.select(
                    Database.jsonObject([
                        (key: "a", value: nameColumn),
                        (key: "c", value: infoColumn),
                    ] as [(key: String, value: any SQLExpressible)])
                ), """
                SELECT JSON_OBJECT('a', "name", 'c', \(jsonFunction)("info")) FROM "player"
                """)
            
            try assertEqualSQL(
                db,
                player.select(
                    Database.jsonObject([
                        (key: "a", value: Database.json(nameColumn)),
                        (key: "c", value: Database.json(infoColumn)),
                    ] as [(key: String, value: SQLExpression)])
                ), """
                SELECT JSON_OBJECT('a', JSON("name"), 'c', JSON("info")) FROM "player"
                """)
        }
    }
    
    func test_Database_jsonObject_from_KeyValuePairs() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3038000 else {
            throw XCTSkip("JSON support is not available")
        }
#else
        guard #available(iOS 16, tvOS 17, watchOS 9, *) else {
            throw XCTSkip("JSON support is not available")
        }
#endif
        
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.column("name", .text)
                t.column("info", .jsonText)
            }
            let player = Table("player")
            let nameColumn = Column("name")
            let infoColumn = JSONColumn("info")
            
            // Ordered Array
            
            try assertEqualSQL(
                db,
                Database.jsonObject([
                    "a": 2,
                    "c": #"{"e":5}"#,
                ] as KeyValuePairs), """
                JSON_OBJECT('a', 2, 'c', '{"e":5}')
                """)
            
            try assertEqualSQL(
                db,
                Database.jsonObject([
                    "a": 2,
                    "c": #"{"e":5}"#.databaseValue.asJSON,
                ] as KeyValuePairs), """
                JSON_OBJECT('a', 2, 'c', \(jsonFunction)('{"e":5}'))
                """)
            
            try assertEqualSQL(
                db,
                Database.jsonObject([
                    "a": 2,
                    "c": Database.jsonObject(["e": 5]),
                ] as KeyValuePairs), """
                JSON_OBJECT('a', 2, 'c', JSON_OBJECT('e', 5))
                """)
            
            try assertEqualSQL(
                db,
                Database.jsonObject([
                    "a": 2,
                    "c": Database.json(#"{"e":5}"#),
                ] as KeyValuePairs), """
                JSON_OBJECT('a', 2, 'c', JSON('{"e":5}'))
                """)
            
            try assertEqualSQL(
                db,
                player.select(
                    Database.jsonObject([
                        "a": nameColumn,
                        "c": infoColumn,
                    ] as KeyValuePairs<String, any SQLExpressible>)
                ), """
                SELECT JSON_OBJECT('a', "name", 'c', \(jsonFunction)("info")) FROM "player"
                """)
            
            try assertEqualSQL(
                db,
                player.select(
                    Database.jsonObject([
                        "a": Database.json(nameColumn),
                        "c": Database.json(infoColumn),
                    ] as KeyValuePairs)
                ), """
                SELECT JSON_OBJECT('a', JSON("name"), 'c', JSON("info")) FROM "player"
                """)
        }
    }
    
    func test_Database_jsonbObject_from_Dictionary() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3045000 else {
            throw XCTSkip("JSONB is not available")
        }
        
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.column("name", .text)
                t.column("info", .jsonText)
            }
            let player = Table("player")
            let nameColumn = Column("name")
            let infoColumn = JSONColumn("info")
            
            try assertEqualSQL(
                db,
                Database.jsonbObject([
                    "a": 2,
                ] as [String: Int]), """
                JSONB_OBJECT('a', 2)
                """)
            
            try assertEqualSQL(
                db,
                Database.jsonbObject([
                    "c": #"{"e":5}"#,
                ] as [String: any SQLExpressible]), """
                JSONB_OBJECT('c', '{"e":5}')
                """)
            
            try assertEqualSQL(
                db,
                Database.jsonbObject([
                    "c": #"{"e":5}"#.databaseValue.asJSON,
                ] as [String: any SQLExpressible]), """
                JSONB_OBJECT('c', JSONB('{"e":5}'))
                """)
            
            try assertEqualSQL(
                db,
                Database.jsonbObject([
                    "c": Database.jsonObject(["e": 5]),
                ]), """
                JSONB_OBJECT('c', JSON_OBJECT('e', 5))
                """)
            
            try assertEqualSQL(
                db,
                Database.jsonbObject([
                    "c": Database.jsonbObject(["e": 5]),
                ]), """
                JSONB_OBJECT('c', JSONB_OBJECT('e', 5))
                """)
            
            try assertEqualSQL(
                db,
                Database.jsonbObject([
                    "c": Database.json(#"{"e":5}"#),
                ]), """
                JSONB_OBJECT('c', JSON('{"e":5}'))
                """)
            
            try assertEqualSQL(
                db,
                Database.jsonbObject([
                    "c": Database.jsonb(#"{"e":5}"#),
                ]), """
                JSONB_OBJECT('c', JSONB('{"e":5}'))
                """)
            
            try assertEqualSQL(
                db,
                player.select(
                    Database.jsonbObject([
                        "a": nameColumn,
                    ])
                ), """
                SELECT JSONB_OBJECT('a', "name") FROM "player"
                """)
            
            try assertEqualSQL(
                db,
                player.select(
                    Database.jsonbObject([
                        "c": infoColumn,
                    ])
                ), """
                SELECT JSONB_OBJECT('c', JSONB("info")) FROM "player"
                """)
            
            try assertEqualSQL(
                db,
                player.select(
                    Database.jsonbObject([
                        "a": Database.json(nameColumn),
                    ])
                ), """
                SELECT JSONB_OBJECT('a', JSON("name")) FROM "player"
                """)
            
            try assertEqualSQL(
                db,
                player.select(
                    Database.jsonbObject([
                        "a": Database.jsonb(nameColumn),
                    ])
                ), """
                SELECT JSONB_OBJECT('a', JSONB("name")) FROM "player"
                """)
            
            try assertEqualSQL(
                db,
                player.select(
                    Database.jsonbObject([
                        "c": Database.json(infoColumn),
                    ])
                ), """
                SELECT JSONB_OBJECT('c', JSON("info")) FROM "player"
                """)
            
            try assertEqualSQL(
                db,
                player.select(
                    Database.jsonbObject([
                        "c": Database.jsonb(infoColumn),
                    ])
                ), """
                SELECT JSONB_OBJECT('c', JSONB("info")) FROM "player"
                """)
        }
#else
        throw XCTSkip("JSONB is not available")
#endif
    }
    
    func test_Database_jsonbObject_from_Array() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3045000 else {
            throw XCTSkip("JSONB is not available")
        }
        
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.column("name", .text)
                t.column("info", .jsonText)
            }
            let player = Table("player")
            let nameColumn = Column("name")
            let infoColumn = JSONColumn("info")
            
            // Ordered Array
            
            try assertEqualSQL(
                db,
                Database.jsonbObject([
                    (key: "a", value: 2),
                    (key: "c", value: #"{"e":5}"#),
                ] as [(key: String, value: any SQLExpressible)]), """
                JSONB_OBJECT('a', 2, 'c', '{"e":5}')
                """)
            
            try assertEqualSQL(
                db,
                Database.jsonbObject([
                    (key: "a", value: 2),
                    (key: "c", value: #"{"e":5}"#.databaseValue.asJSON),
                ] as [(key: String, value: any SQLExpressible)]), """
                JSONB_OBJECT('a', 2, 'c', JSONB('{"e":5}'))
                """)
            
            try assertEqualSQL(
                db,
                Database.jsonbObject([
                    (key: "a", value: 2),
                    (key: "c", value: Database.jsonObject(["e": 5])),
                ] as [(key: String, value: any SQLExpressible)]), """
                JSONB_OBJECT('a', 2, 'c', JSON_OBJECT('e', 5))
                """)
            
            try assertEqualSQL(
                db,
                Database.jsonbObject([
                    (key: "a", value: 2),
                    (key: "c", value: Database.jsonbObject(["e": 5])),
                ] as [(key: String, value: any SQLExpressible)]), """
                JSONB_OBJECT('a', 2, 'c', JSONB_OBJECT('e', 5))
                """)
            
            try assertEqualSQL(
                db,
                Database.jsonbObject([
                    (key: "a", value: 2),
                    (key: "c", value: Database.json(#"{"e":5}"#)),
                ] as [(key: String, value: any SQLExpressible)]), """
                JSONB_OBJECT('a', 2, 'c', JSON('{"e":5}'))
                """)
            
            try assertEqualSQL(
                db,
                Database.jsonbObject([
                    (key: "a", value: 2),
                    (key: "c", value: Database.jsonb(#"{"e":5}"#)),
                ] as [(key: String, value: any SQLExpressible)]), """
                JSONB_OBJECT('a', 2, 'c', JSONB('{"e":5}'))
                """)
            
            try assertEqualSQL(
                db,
                player.select(
                    Database.jsonbObject([
                        (key: "a", value: nameColumn),
                        (key: "c", value: infoColumn),
                    ] as [(key: String, value: any SQLExpressible)])
                ), """
                SELECT JSONB_OBJECT('a', "name", 'c', JSONB("info")) FROM "player"
                """)
            
            try assertEqualSQL(
                db,
                player.select(
                    Database.jsonbObject([
                        (key: "a", value: Database.json(nameColumn)),
                        (key: "c", value: Database.json(infoColumn)),
                    ] as [(key: String, value: SQLExpression)])
                ), """
                SELECT JSONB_OBJECT('a', JSON("name"), 'c', JSON("info")) FROM "player"
                """)
            
            try assertEqualSQL(
                db,
                player.select(
                    Database.jsonbObject([
                        (key: "a", value: Database.jsonb(nameColumn)),
                        (key: "c", value: Database.jsonb(infoColumn)),
                    ] as [(key: String, value: SQLExpression)])
                ), """
                SELECT JSONB_OBJECT('a', JSONB("name"), 'c', JSONB("info")) FROM "player"
                """)
        }
#else
        throw XCTSkip("JSONB is not available")
#endif
    }
    
    func test_Database_jsonbObject_from_KeyValuePairs() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3045000 else {
            throw XCTSkip("JSONB is not available")
        }
        
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.column("name", .text)
                t.column("info", .jsonText)
            }
            let player = Table("player")
            let nameColumn = Column("name")
            let infoColumn = JSONColumn("info")
            
            // Ordered Array
            
            try assertEqualSQL(
                db,
                Database.jsonbObject([
                    "a": 2,
                    "c": #"{"e":5}"#,
                ] as KeyValuePairs), """
                JSONB_OBJECT('a', 2, 'c', '{"e":5}')
                """)
            
            try assertEqualSQL(
                db,
                Database.jsonbObject([
                    "a": 2,
                    "c": #"{"e":5}"#.databaseValue.asJSON,
                ] as KeyValuePairs), """
                JSONB_OBJECT('a', 2, 'c', JSONB('{"e":5}'))
                """)
            
            try assertEqualSQL(
                db,
                Database.jsonbObject([
                    "a": 2,
                    "c": Database.jsonObject(["e": 5]),
                ] as KeyValuePairs), """
                JSONB_OBJECT('a', 2, 'c', JSON_OBJECT('e', 5))
                """)
            
            try assertEqualSQL(
                db,
                Database.jsonbObject([
                    "a": 2,
                    "c": Database.jsonbObject(["e": 5]),
                ] as KeyValuePairs), """
                JSONB_OBJECT('a', 2, 'c', JSONB_OBJECT('e', 5))
                """)
            
            try assertEqualSQL(
                db,
                Database.jsonbObject([
                    "a": 2,
                    "c": Database.json(#"{"e":5}"#),
                ] as KeyValuePairs), """
                JSONB_OBJECT('a', 2, 'c', JSON('{"e":5}'))
                """)
            
            try assertEqualSQL(
                db,
                Database.jsonbObject([
                    "a": 2,
                    "c": Database.jsonb(#"{"e":5}"#),
                ] as KeyValuePairs), """
                JSONB_OBJECT('a', 2, 'c', JSONB('{"e":5}'))
                """)
            
            try assertEqualSQL(
                db,
                player.select(
                    Database.jsonbObject([
                        "a": nameColumn,
                        "c": infoColumn,
                    ] as KeyValuePairs<String, any SQLExpressible>)
                ), """
                SELECT JSONB_OBJECT('a', "name", 'c', JSONB("info")) FROM "player"
                """)
            
            try assertEqualSQL(
                db,
                player.select(
                    Database.jsonbObject([
                        "a": Database.json(nameColumn),
                        "c": Database.json(infoColumn),
                    ] as KeyValuePairs)
                ), """
                SELECT JSONB_OBJECT('a', JSON("name"), 'c', JSON("info")) FROM "player"
                """)
            
            try assertEqualSQL(
                db,
                player.select(
                    Database.jsonbObject([
                        "a": Database.jsonb(nameColumn),
                        "c": Database.jsonb(infoColumn),
                    ] as KeyValuePairs)
                ), """
                SELECT JSONB_OBJECT('a', JSONB("name"), 'c', JSONB("info")) FROM "player"
                """)
        }
#else
        throw XCTSkip("JSONB is not available")
#endif
    }
    
    func test_Database_jsonPatch() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3038000 else {
            throw XCTSkip("JSON support is not available")
        }
#else
        guard #available(iOS 16, tvOS 17, watchOS 9, *) else {
            throw XCTSkip("JSON support is not available")
        }
#endif
        
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.column("name", .text)
                t.column("info", .jsonText)
            }
            let player = Table("player")
            let nameColumn = Column("name")
            let infoColumn = JSONColumn("info")
            
            try assertEqualSQL(db, Database.jsonPatch(#"{"a":1,"b":2}"#, with: #"{"c":3,"d":4}"#), """
                JSON_PATCH('{"a":1,"b":2}', '{"c":3,"d":4}')
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonPatch(#"{"a":1,"b":2}"#, with: nameColumn)), """
                SELECT JSON_PATCH('{"a":1,"b":2}', "name") FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonPatch(#"{"a":1,"b":2}"#, with: infoColumn)), """
                SELECT JSON_PATCH('{"a":1,"b":2}', "info") FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonPatch(nameColumn, with: #"{"c":3,"d":4}"#)), """
                SELECT JSON_PATCH("name", '{"c":3,"d":4}') FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonPatch(infoColumn, with: #"{"c":3,"d":4}"#)), """
                SELECT JSON_PATCH("info", '{"c":3,"d":4}') FROM "player"
                """)
        }
    }
    
    func test_Database_jsonbPatch() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3045000 else {
            throw XCTSkip("JSONB is not available")
        }
        
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.column("name", .text)
                t.column("info", .jsonText)
            }
            let player = Table("player")
            let nameColumn = Column("name")
            let infoColumn = JSONColumn("info")
            
            try assertEqualSQL(db, Database.jsonbPatch(#"{"a":1,"b":2}"#, with: #"{"c":3,"d":4}"#), """
                JSONB_PATCH('{"a":1,"b":2}', '{"c":3,"d":4}')
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonbPatch(#"{"a":1,"b":2}"#, with: nameColumn)), """
                SELECT JSONB_PATCH('{"a":1,"b":2}', "name") FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonbPatch(#"{"a":1,"b":2}"#, with: infoColumn)), """
                SELECT JSONB_PATCH('{"a":1,"b":2}', "info") FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonbPatch(nameColumn, with: #"{"c":3,"d":4}"#)), """
                SELECT JSONB_PATCH("name", '{"c":3,"d":4}') FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonbPatch(infoColumn, with: #"{"c":3,"d":4}"#)), """
                SELECT JSONB_PATCH("info", '{"c":3,"d":4}') FROM "player"
                """)
        }
#else
        throw XCTSkip("JSONB is not available")
#endif
    }
    
    func test_Database_jsonRemove_atPath() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3038000 else {
            throw XCTSkip("JSON support is not available")
        }
#else
        guard #available(iOS 16, tvOS 17, watchOS 9, *) else {
            throw XCTSkip("JSON support is not available")
        }
#endif
        
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.column("name", .text)
                t.column("info", .jsonText)
            }
            let player = Table("player")
            let nameColumn = Column("name")
            let infoColumn = JSONColumn("info")
            
            try assertEqualSQL(db, Database.jsonRemove("[0,1,2,3,4]", atPath: "$[2]"), """
                JSON_REMOVE('[0,1,2,3,4]', '$[2]')
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonRemove(nameColumn, atPath: "$[2]")), """
                SELECT JSON_REMOVE("name", '$[2]') FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonRemove("[0,1,2,3,4]", atPath: nameColumn)), """
                SELECT JSON_REMOVE('[0,1,2,3,4]', "name") FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonRemove(infoColumn, atPath: "$[2]")), """
                SELECT JSON_REMOVE("info", '$[2]') FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonRemove("[0,1,2,3,4]", atPath: infoColumn)), """
                SELECT JSON_REMOVE('[0,1,2,3,4]', "info") FROM "player"
                """)
        }
    }
    
    func test_Database_jsonRemove_atPaths() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3038000 else {
            throw XCTSkip("JSON support is not available")
        }
#else
        guard #available(iOS 16, tvOS 17, watchOS 9, *) else {
            throw XCTSkip("JSON support is not available")
        }
#endif
        
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.column("name", .text)
                t.column("info", .jsonText)
            }
            let player = Table("player")
            let nameColumn = Column("name")
            let infoColumn = JSONColumn("info")
            
            try assertEqualSQL(db, Database.jsonRemove("[0,1,2,3,4]", atPaths: ["$[2]", "$[0]"]), """
                JSON_REMOVE('[0,1,2,3,4]', '$[2]', '$[0]')
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonRemove(nameColumn, atPaths: ["$[2]", "$[0]"])), """
                SELECT JSON_REMOVE("name", '$[2]', '$[0]') FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonRemove(infoColumn, atPaths: ["$[2]", "$[0]"])), """
                SELECT JSON_REMOVE("info", '$[2]', '$[0]') FROM "player"
                """)
        }
    }
    
    func test_Database_jsonbRemove_atPath() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3045000 else {
            throw XCTSkip("JSONB is not available")
        }
        
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.column("name", .text)
                t.column("info", .jsonText)
            }
            let player = Table("player")
            let nameColumn = Column("name")
            let infoColumn = JSONColumn("info")
            
            try assertEqualSQL(db, Database.jsonbRemove("[0,1,2,3,4]", atPath: "$[2]"), """
                JSONB_REMOVE('[0,1,2,3,4]', '$[2]')
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonbRemove(nameColumn, atPath: "$[2]")), """
                SELECT JSONB_REMOVE("name", '$[2]') FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonbRemove("[0,1,2,3,4]", atPath: nameColumn)), """
                SELECT JSONB_REMOVE('[0,1,2,3,4]', "name") FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonbRemove(infoColumn, atPath: "$[2]")), """
                SELECT JSONB_REMOVE("info", '$[2]') FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonbRemove("[0,1,2,3,4]", atPath: infoColumn)), """
                SELECT JSONB_REMOVE('[0,1,2,3,4]', "info") FROM "player"
                """)
        }
#else
        throw XCTSkip("JSONB is not available")
#endif
    }
    
    func test_Database_jsonbRemove_atPaths() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3045000 else {
            throw XCTSkip("JSONB is not available")
        }
        
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.column("name", .text)
                t.column("info", .jsonText)
            }
            let player = Table("player")
            let nameColumn = Column("name")
            let infoColumn = JSONColumn("info")
            
            try assertEqualSQL(db, Database.jsonbRemove("[0,1,2,3,4]", atPaths: ["$[2]", "$[0]"]), """
                JSONB_REMOVE('[0,1,2,3,4]', '$[2]', '$[0]')
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonbRemove(nameColumn, atPaths: ["$[2]", "$[0]"])), """
                SELECT JSONB_REMOVE("name", '$[2]', '$[0]') FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonbRemove(infoColumn, atPaths: ["$[2]", "$[0]"])), """
                SELECT JSONB_REMOVE("info", '$[2]', '$[0]') FROM "player"
                """)
        }
#else
        throw XCTSkip("JSONB is not available")
#endif
    }
    
    func test_Database_jsonType() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3038000 else {
            throw XCTSkip("JSON support is not available")
        }
#else
        guard #available(iOS 16, tvOS 17, watchOS 9, *) else {
            throw XCTSkip("JSON support is not available")
        }
#endif
        
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.column("name", .text)
                t.column("info", .jsonText)
            }
            let player = Table("player")
            let nameColumn = Column("name")
            let infoColumn = JSONColumn("info")
            
            try assertEqualSQL(db, Database.jsonType(#"{"a":[2,3.5,true,false,null,"x"]}"#), """
                JSON_TYPE('{"a":[2,3.5,true,false,null,"x"]}')
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonType(nameColumn)), """
                SELECT JSON_TYPE("name") FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonType(infoColumn)), """
                SELECT JSON_TYPE("info") FROM "player"
                """)
        }
    }
    
    func test_Database_jsonType_atPath() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3038000 else {
            throw XCTSkip("JSON support is not available")
        }
#else
        guard #available(iOS 16, tvOS 17, watchOS 9, *) else {
            throw XCTSkip("JSON support is not available")
        }
#endif
        
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.column("name", .text)
                t.column("info", .jsonText)
            }
            let player = Table("player")
            let nameColumn = Column("name")
            let infoColumn = JSONColumn("info")
            
            try assertEqualSQL(db, Database.jsonType(#"{"a":[2,3.5,true,false,null,"x"]}"#, atPath: "$.a"), """
                JSON_TYPE('{"a":[2,3.5,true,false,null,"x"]}', '$.a')
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonType(nameColumn, atPath: "$.a")), """
                SELECT JSON_TYPE("name", '$.a') FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonType(infoColumn, atPath: "$.a")), """
                SELECT JSON_TYPE("info", '$.a') FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonType(#"{"a":[2,3.5,true,false,null,"x"]}"#, atPath: nameColumn)), """
                SELECT JSON_TYPE('{"a":[2,3.5,true,false,null,"x"]}', "name") FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonType(#"{"a":[2,3.5,true,false,null,"x"]}"#, atPath: infoColumn)), """
                SELECT JSON_TYPE('{"a":[2,3.5,true,false,null,"x"]}', "info") FROM "player"
                """)
        }
    }
    
    func test_Database_jsonIsValid() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3038000 else {
            throw XCTSkip("JSON support is not available")
        }
#else
        guard #available(iOS 16, tvOS 17, watchOS 9, *) else {
            throw XCTSkip("JSON support is not available")
        }
#endif
        
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.column("name", .text)
                t.column("info", .jsonText)
            }
            let player = Table("player")
            let nameColumn = Column("name")
            let infoColumn = JSONColumn("info")
            
            try assertEqualSQL(db, Database.jsonIsValid(#"{"x":35""#), """
                JSON_VALID('{"x":35"')
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonIsValid(nameColumn)), """
                SELECT JSON_VALID("name") FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonIsValid(infoColumn)), """
                SELECT JSON_VALID("info") FROM "player"
                """)
        }
    }
    
    func test_Database_jsonIsValid_options() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3045000 else {
            throw XCTSkip("JSON_VALID options are not available")
        }
        
        try makeDatabaseQueue().inDatabase { db in
            try assertEqualSQL(db, Database.jsonIsValid(#"{"x":35""#, options: .json), """
                JSON_VALID('{"x":35"', 1)
                """)
            
            try assertEqualSQL(db, Database.jsonIsValid(#"{"x":35""#, options: .json5), """
                JSON_VALID('{"x":35"', 2)
                """)
            
            try assertEqualSQL(db, Database.jsonIsValid(#"{"x":35""#, options: .probablyJSONB), """
                JSON_VALID('{"x":35"', 4)
                """)
            
            try assertEqualSQL(db, Database.jsonIsValid(#"{"x":35""#, options: .jsonb), """
                JSON_VALID('{"x":35"', 8)
                """)
            
            try assertEqualSQL(db, Database.jsonIsValid(#"{"x":35""#, options: [.json, .jsonb]), """
                JSON_VALID('{"x":35"', 9)
                """)

        }
#else
        throw XCTSkip("JSON_VALID options are not available")
#endif
    }

    func test_Database_jsonQuote() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3038000 else {
            throw XCTSkip("JSON support is not available")
        }
#else
        guard #available(iOS 16, tvOS 17, watchOS 9, *) else {
            throw XCTSkip("JSON support is not available")
        }
#endif
        
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.column("name", .text)
                t.column("info", .jsonText)
            }
            let player = Table("player")
            let nameColumn = Column("name")
            let infoColumn = JSONColumn("info")
            
            try assertEqualSQL(db, Database.jsonQuote(#"{"e":5}"#), """
                JSON_QUOTE('{"e":5}')
                """)
            
            try assertEqualSQL(db, Database.jsonQuote(#"{"e":5}"#.databaseValue.asJSON), """
                JSON_QUOTE(\(jsonFunction)('{"e":5}'))
                """)
            
            try assertEqualSQL(db, Database.jsonQuote(Database.json(#"{"e":5}"#)), """
                JSON_QUOTE(JSON('{"e":5}'))
                """)
            
            try assertEqualSQL(db, Database.jsonQuote(Database.jsonObject(["e": 5])), """
                JSON_QUOTE(JSON_OBJECT('e', 5))
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonQuote(nameColumn)), """
                SELECT JSON_QUOTE("name") FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonQuote(infoColumn)), """
                SELECT JSON_QUOTE(\(jsonFunction)("info")) FROM "player"
                """)
        }
    }
    
    func test_Database_jsonGroupArray() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3038000 else {
            throw XCTSkip("JSON support is not available")
        }
#else
        guard #available(iOS 16, tvOS 17, watchOS 9, *) else {
            throw XCTSkip("JSON support is not available")
        }
#endif
        
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.column("name", .text)
                t.column("info", .jsonText)
            }
            let player = Table("player")
            let nameColumn = Column("name")
            let infoColumn = JSONColumn("info")
            
            try assertEqualSQL(db, player.select(Database.jsonGroupArray(nameColumn)), """
                SELECT JSON_GROUP_ARRAY("name") FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonGroupArray(infoColumn)), """
                SELECT JSON_GROUP_ARRAY(\(jsonFunction)("info")) FROM "player"
                """)
        }
    }
    
    func test_Database_jsonGroupArray_from_JSON() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3038000 else {
            throw XCTSkip("JSON support is not available")
        }
#else
        guard #available(iOS 16, tvOS 17, watchOS 9, *) else {
            throw XCTSkip("JSON support is not available")
        }
#endif
        
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.column("name", .text)
                t.column("info", .jsonText)
            }
            try db.execute(sql: """
                INSERT INTO player (info) VALUES ('{"foo": "bar"}')
                """)
            let player = Table("player")
            let infoColumn = JSONColumn("info")
            let request = player.select(Database.jsonGroupArray(infoColumn))
            let json = try String.fetchOne(db, request)
            XCTAssertEqual(json, #"[{"foo":"bar"}]"#)
        }
    }
    
    func test_Database_jsonGroupArray_from_JSONB() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3045000 else {
            throw XCTSkip("JSONB is not available")
        }

        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.column("name", .text)
                t.column("info", .jsonText)
            }
            try db.execute(sql: """
                INSERT INTO player (info) VALUES (JSONB('{"foo": "bar"}'))
                """)
            let player = Table("player")
            let infoColumn = JSONColumn("info")
            let request = player.select(Database.jsonGroupArray(infoColumn))
            let json = try String.fetchOne(db, request)
            XCTAssertEqual(json, #"[{"foo":"bar"}]"#)
        }
#else
        throw XCTSkip("JSONB is not available")
#endif
    }
    
    func test_Database_jsonGroupArray_filter() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3038000 else {
            throw XCTSkip("JSON support is not available")
        }
#else
        guard #available(iOS 16, tvOS 17, watchOS 9, *) else {
            throw XCTSkip("JSON support is not available")
        }
#endif
        
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.column("name", .text)
                t.column("info", .jsonText)
            }
            let player = Table("player")
            let nameColumn = Column("name")
            let infoColumn = JSONColumn("info")
            
            try assertEqualSQL(db, player.select(Database.jsonGroupArray(nameColumn, filter: length(nameColumn) > 0)), """
                SELECT JSON_GROUP_ARRAY("name") FILTER (WHERE LENGTH("name") > 0) FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonGroupArray(infoColumn, filter: length(nameColumn) > 0)), """
                SELECT JSON_GROUP_ARRAY(\(jsonFunction)("info")) FILTER (WHERE LENGTH("name") > 0) FROM "player"
                """)
        }
    }
    
    func test_Database_jsonGroupArray_order() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3044000 else {
            throw XCTSkip("JSON support is not available")
        }
        
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.column("name", .text)
                t.column("info", .jsonText)
            }
            let player = Table("player")
            let nameColumn = Column("name")
            let infoColumn = JSONColumn("info")
            
            try assertEqualSQL(db, player.select(Database.jsonGroupArray(nameColumn, orderBy: nameColumn)), """
                SELECT JSON_GROUP_ARRAY("name" ORDER BY "name") FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonGroupArray(infoColumn, orderBy: nameColumn.desc)), """
                SELECT JSON_GROUP_ARRAY(\(jsonFunction)("info") ORDER BY "name" DESC) FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonGroupArray(nameColumn, orderBy: nameColumn, filter: length(nameColumn) > 0)), """
                SELECT JSON_GROUP_ARRAY("name" ORDER BY "name") FILTER (WHERE LENGTH("name") > 0) FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonGroupArray(infoColumn, orderBy: nameColumn.desc, filter: length(nameColumn) > 0)), """
                SELECT JSON_GROUP_ARRAY(\(jsonFunction)("info") ORDER BY "name" DESC) FILTER (WHERE LENGTH("name") > 0) FROM "player"
                """)
        }
#else
        throw XCTSkip("JSON_GROUP_ARRAY(ORDER) is not available")
#endif
    }
    
    func test_Database_jsonbGroupArray() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3045000 else {
            throw XCTSkip("JSONB is not available")
        }
        
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.column("name", .text)
                t.column("info", .jsonText)
            }
            let player = Table("player")
            let nameColumn = Column("name")
            let infoColumn = JSONColumn("info")
            
            try assertEqualSQL(db, player.select(Database.jsonbGroupArray(nameColumn)), """
                SELECT JSONB_GROUP_ARRAY("name") FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonbGroupArray(infoColumn)), """
                SELECT JSONB_GROUP_ARRAY(JSONB("info")) FROM "player"
                """)
        }
#else
        throw XCTSkip("JSONB is not available")
#endif
    }
    
    func test_Database_jsonbGroupArray_filter() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3045000 else {
            throw XCTSkip("JSONB is not available")
        }
        
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.column("name", .text)
                t.column("info", .jsonText)
            }
            let player = Table("player")
            let nameColumn = Column("name")
            let infoColumn = JSONColumn("info")
            
            try assertEqualSQL(db, player.select(Database.jsonbGroupArray(nameColumn, filter: length(nameColumn) > 0)), """
                SELECT JSONB_GROUP_ARRAY("name") FILTER (WHERE LENGTH("name") > 0) FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonbGroupArray(infoColumn, filter: length(nameColumn) > 0)), """
                SELECT JSONB_GROUP_ARRAY(JSONB("info")) FILTER (WHERE LENGTH("name") > 0) FROM "player"
                """)
        }
#else
        throw XCTSkip("JSONB is not available")
#endif
    }
    
    func test_Database_jsonbGroupArray_order() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3045000 else {
            throw XCTSkip("JSONB is not available")
        }
        
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.column("name", .text)
                t.column("info", .jsonText)
            }
            let player = Table("player")
            let nameColumn = Column("name")
            let infoColumn = JSONColumn("info")
            
            try assertEqualSQL(db, player.select(Database.jsonbGroupArray(nameColumn, orderBy: nameColumn)), """
                SELECT JSONB_GROUP_ARRAY("name" ORDER BY "name") FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonbGroupArray(infoColumn, orderBy: nameColumn.desc)), """
                SELECT JSONB_GROUP_ARRAY(JSONB("info") ORDER BY "name" DESC) FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonbGroupArray(nameColumn, orderBy: nameColumn, filter: length(nameColumn) > 0)), """
                SELECT JSONB_GROUP_ARRAY("name" ORDER BY "name") FILTER (WHERE LENGTH("name") > 0) FROM "player"
                """)
            
            try assertEqualSQL(db, player.select(Database.jsonbGroupArray(infoColumn, orderBy: nameColumn.desc, filter: length(nameColumn) > 0)), """
                SELECT JSONB_GROUP_ARRAY(JSONB("info") ORDER BY "name" DESC) FILTER (WHERE LENGTH("name") > 0) FROM "player"
                """)
        }
#else
        throw XCTSkip("JSONB is not available")
#endif
    }
    
    func test_Database_jsonGroupObject() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3038000 else {
            throw XCTSkip("JSON support is not available")
        }
#else
        guard #available(iOS 16, tvOS 17, watchOS 9, *) else {
            throw XCTSkip("JSON support is not available")
        }
#endif
        
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.column("key", .text)
                t.column("value", .jsonText)
            }
            let player = Table("player")
            let keyColumn = Column("key")
            let valueColumn = JSONColumn("value")
            
            try assertEqualSQL(db, player.select(Database.jsonGroupObject(key: keyColumn, value: valueColumn)), """
                SELECT JSON_GROUP_OBJECT("key", \(jsonFunction)("value")) FROM "player"
                """)
        }
    }
    
    func test_Database_jsonGroupObject_filter() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3038000 else {
            throw XCTSkip("JSON support is not available")
        }
#else
        guard #available(iOS 16, tvOS 17, watchOS 9, *) else {
            throw XCTSkip("JSON support is not available")
        }
#endif
        
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.column("key", .text)
                t.column("value", .jsonText)
            }
            let player = Table("player")
            let keyColumn = Column("key")
            let valueColumn = JSONColumn("value")
            
            try assertEqualSQL(db, player.select(Database.jsonGroupObject(key: keyColumn, value: valueColumn, filter: length(valueColumn) > 0)), """
                SELECT JSON_GROUP_OBJECT("key", \(jsonFunction)("value")) FILTER (WHERE LENGTH("value") > 0) FROM "player"
                """)
        }
    }
    
    func test_Database_jsonbGroupObject() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3045000 else {
            throw XCTSkip("JSONB is not available")
        }
        
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.column("key", .text)
                t.column("value", .jsonText)
            }
            let player = Table("player")
            let keyColumn = Column("key")
            let valueColumn = JSONColumn("value")
            
            try assertEqualSQL(db, player.select(Database.jsonbGroupObject(key: keyColumn, value: valueColumn)), """
                SELECT JSONB_GROUP_OBJECT("key", \(jsonFunction)("value")) FROM "player"
                """)
        }
#else
        throw XCTSkip("JSONB is not available")
#endif
    }
    
    func test_Database_jsonbGroupObject_filter() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3045000 else {
            throw XCTSkip("JSONB is not available")
        }
        
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.column("key", .text)
                t.column("value", .jsonText)
            }
            let player = Table("player")
            let keyColumn = Column("key")
            let valueColumn = JSONColumn("value")
            
            try assertEqualSQL(db, player.select(Database.jsonbGroupObject(key: keyColumn, value: valueColumn, filter: length(valueColumn) > 0)), """
                SELECT JSONB_GROUP_OBJECT("key", \(jsonFunction)("value")) FILTER (WHERE LENGTH("value") > 0) FROM "player"
                """)
        }
#else
        throw XCTSkip("JSONB is not available")
#endif
    }
    
    func test_JSON_index_and_generated_columns() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3038000 else {
            throw XCTSkip("JSON support is not available")
        }
#else
        guard #available(iOS 16, macOS 12, tvOS 17, watchOS 9, *) else {
            throw XCTSkip("JSON support or generated columns are not available")
        }
        
#endif
        
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.primaryKey("id", .integer)
                t.column("address", .jsonText)
                t.column("country", .text)
                    .generatedAs(JSONColumn("address").jsonExtract(atPath: "$.country"))
                    .indexed()
            }
            
            XCTAssertEqual(Array(sqlQueries.suffix(2)), [
                """
                CREATE TABLE "player" (\
                "id" INTEGER PRIMARY KEY, \
                "address" TEXT, \
                "country" TEXT GENERATED ALWAYS AS (JSON_EXTRACT("address", '$.country')) VIRTUAL\
                )
                """,
                """
                CREATE INDEX "player_on_country" ON "player"("country")
                """,
            ])
            
            try db.create(index: "player_on_address", on: "player", expressions: [
                JSONColumn("address").jsonExtract(atPath: "$.country"),
                JSONColumn("address").jsonExtract(atPath: "$.city"),
                JSONColumn("address").jsonExtract(atPath: "$.street"),
            ])
            
            XCTAssertEqual(lastSQLQuery, """
                CREATE INDEX "player_on_address" ON "player"(\
                JSON_EXTRACT("address", '$.country'), \
                JSON_EXTRACT("address", '$.city'), \
                JSON_EXTRACT("address", '$.street')\
                )
                """)
            
            try db.execute(literal: """
                INSERT INTO player VALUES (
                  NULL,
                  '{"street": "Rue de Belleville", "city": "Paris", "country": "France"}'
                )
                """)
            
            try XCTAssertEqual(String.fetchOne(db, sql: "SELECT country FROM player"), "France")
        }
    }
    
    func test_JSONB_index_and_generated_columns() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3045000 else {
            throw XCTSkip("JSONB is not available")
        }
        
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.primaryKey("id", .integer)
                t.column("address", .jsonb)
                t.column("country", .text)
                    .generatedAs(JSONColumn("address").jsonExtract(atPath: "$.country"))
                    .indexed()
            }
            
            XCTAssertEqual(Array(sqlQueries.suffix(2)), [
                """
                CREATE TABLE "player" (\
                "id" INTEGER PRIMARY KEY, \
                "address" BLOB, \
                "country" TEXT GENERATED ALWAYS AS (JSON_EXTRACT("address", '$.country')) VIRTUAL\
                )
                """,
                """
                CREATE INDEX "player_on_country" ON "player"("country")
                """,
            ])
            
            try db.create(index: "player_on_address", on: "player", expressions: [
                JSONColumn("address").jsonExtract(atPath: "$.country"),
                JSONColumn("address").jsonExtract(atPath: "$.city"),
                JSONColumn("address").jsonExtract(atPath: "$.street"),
            ])
            
            XCTAssertEqual(lastSQLQuery, """
                CREATE INDEX "player_on_address" ON "player"(\
                JSON_EXTRACT("address", '$.country'), \
                JSON_EXTRACT("address", '$.city'), \
                JSON_EXTRACT("address", '$.street')\
                )
                """)
            
            try db.execute(literal: """
                INSERT INTO player VALUES (
                  NULL,
                  JSONB('{"street": "Rue de Belleville", "city": "Paris", "country": "France"}')
                )
                """)
            
            try XCTAssertEqual(String.fetchOne(db, sql: "SELECT country FROM player"), "France")
        }
#else
        throw XCTSkip("JSONB is not available")
#endif
    }
    
// TODO: Enable when those apis are ready.
//     func test_ColumnAssignment() throws {
// #if GRDBCUSTOMSQLITE || GRDBCIPHER
//         // Prevent SQLCipher failures
//         guard Database.sqliteLibVersionNumber >= 3038000 else {
//             throw XCTSkip("JSON support is not available")
//         }
// #else
//         guard #available(iOS 16, tvOS 17, watchOS 9, *) else {
//             throw XCTSkip("JSON support is not available")
//         }
// #endif
//
//         try makeDatabaseQueue().inDatabase { db in
//             try db.create(table: "player") { t in
//                 t.column("name", .text)
//                 t.column("info", .jsonText)
//             }
//
//             struct Player: TableRecord { }
//
//             try Player.updateAll(db, [
//                 JSONColumn("info").jsonPatch(with: Database.jsonObject(["city": "Paris"]))
//             ])
//             XCTAssertEqual(lastSQLQuery, """
//                 UPDATE "player" SET "info" = JSON_PATCH("info", JSON_OBJECT('city', 'Paris'))
//                 """)
//
//             try Player.updateAll(db, [
//                 JSONColumn("info").jsonRemove(atPath: "$.country")
//             ])
//             XCTAssertEqual(lastSQLQuery, """
//                 UPDATE "player" SET "info" = JSON_REMOVE("info", '$.country')
//                 """)
//
//             try Player.updateAll(db, [
//                 JSONColumn("info").jsonRemove(atPaths: ["$.country", "$.city"])
//             ])
//             XCTAssertEqual(lastSQLQuery, """
//                 UPDATE "player" SET "info" = JSON_REMOVE("info", '$.country', '$.city')
//                 """)
//         }
//     }
}

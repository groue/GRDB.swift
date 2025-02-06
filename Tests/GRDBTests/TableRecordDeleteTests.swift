import XCTest
import GRDB

private struct Hacker : TableRecord {
    static let databaseTableName = "hackers"
    var id: Int64? // Optional
}

extension Hacker: Identifiable { }

private struct Person : Codable, PersistableRecord, FetchableRecord, Hashable {
    static let databaseTableName = "persons"
    var id: Int64 // Non-optional
    var name: String
    var email: String
}

extension Person: Identifiable { }

private struct Citizenship : TableRecord {
    static let databaseTableName = "citizenships"
}


class TableRecordDeleteTests: GRDBTestCase {
    
    override func setup(_ dbWriter: some DatabaseWriter) throws {
        try dbWriter.write { db in
            try db.execute(sql: "CREATE TABLE hackers (name TEXT)")
            try db.execute(sql: "CREATE TABLE persons (id INTEGER PRIMARY KEY, name TEXT, email TEXT UNIQUE)")
            try db.execute(sql: "CREATE TABLE citizenships (personId INTEGER NOT NULL, countryIsoCode TEXT NOT NULL, PRIMARY KEY (personId, countryIsoCode))")
        }
    }
    
    func testImplicitRowIDPrimaryKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var deleted = try Hacker.deleteOne(db, key: 1)
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"hackers\" WHERE \"rowid\" = 1")
            XCTAssertFalse(deleted)
            
            try db.execute(sql: "INSERT INTO hackers (rowid, name) VALUES (?, ?)", arguments: [1, "Arthur"])
            deleted = try Hacker.deleteOne(db, key: 1)
            XCTAssertTrue(deleted)
            XCTAssertEqual(try Hacker.fetchCount(db), 0)
            
            try db.execute(sql: "INSERT INTO hackers (rowid, name) VALUES (?, ?)", arguments: [1, "Arthur"])
            try XCTAssertFalse(Hacker.deleteOne(db, id: nil))
            deleted = try Hacker.deleteOne(db, id: 1)
            XCTAssertTrue(deleted)
            XCTAssertEqual(try Hacker.fetchCount(db), 0)
            
            do {
                try db.execute(sql: "INSERT INTO hackers (rowid, name) VALUES (?, ?)", arguments: [1, "Arthur"])
                try db.execute(sql: "INSERT INTO hackers (rowid, name) VALUES (?, ?)", arguments: [2, "Barbara"])
                try db.execute(sql: "INSERT INTO hackers (rowid, name) VALUES (?, ?)", arguments: [3, "Craig"])
                let deletedCount = try Hacker.deleteAll(db, keys: [2, 3, 4])
                XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"hackers\" WHERE \"rowid\" IN (2, 3, 4)")
                XCTAssertEqual(deletedCount, 2)
                XCTAssertEqual(try Hacker.fetchCount(db), 1)
            }
            
            do {
                try db.execute(sql: "INSERT INTO hackers (rowid, name) VALUES (?, ?)", arguments: [2, "Barbara"])
                try db.execute(sql: "INSERT INTO hackers (rowid, name) VALUES (?, ?)", arguments: [3, "Craig"])
                let deletedCount = try Hacker.deleteAll(db, ids: [2, 3, 4])
                XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"hackers\" WHERE \"rowid\" IN (2, 3, 4)")
                XCTAssertEqual(deletedCount, 2)
                XCTAssertEqual(try Hacker.fetchCount(db), 1)
            }
        }
    }

    func testSingleColumnPrimaryKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var deleted = try Person.deleteOne(db, key: 1)
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" WHERE \"id\" = 1")
            XCTAssertFalse(deleted)
            
            try db.execute(sql: "INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [1, "Arthur", "arthur@example.com"])
            deleted = try Person.deleteOne(db, key: 1)
            XCTAssertTrue(deleted)
            XCTAssertEqual(try Person.fetchCount(db), 0)
            
            try db.execute(sql: "INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [1, "Arthur", "arthur@example.com"])
            deleted = try Person.deleteOne(db, id: 1)
            XCTAssertTrue(deleted)
            XCTAssertEqual(try Person.fetchCount(db), 0)
            
            do {
                try db.execute(sql: "INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [1, "Arthur", "arthur@example.com"])
                try db.execute(sql: "INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [2, "Barbara", "barbara@example.com"])
                try db.execute(sql: "INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [3, "Craig", "craig@example.com"])
                let deletedCount = try Person.deleteAll(db, keys: [2, 3, 4])
                XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" WHERE \"id\" IN (2, 3, 4)")
                XCTAssertEqual(deletedCount, 2)
                XCTAssertEqual(try Person.fetchCount(db), 1)
            }
            
            do {
                try db.execute(sql: "INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [2, "Barbara", "barbara@example.com"])
                try db.execute(sql: "INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [3, "Craig", "craig@example.com"])
                let deletedCount = try Person.deleteAll(db, ids: [2, 3, 4])
                XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" WHERE \"id\" IN (2, 3, 4)")
                XCTAssertEqual(deletedCount, 2)
                XCTAssertEqual(try Person.fetchCount(db), 1)
            }
        }
    }

    func testMultipleColumnPrimaryKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var deleted = try Citizenship.deleteOne(db, key: ["personId": 1, "countryIsoCode": "FR"])
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"citizenships\" WHERE (\"personId\" = 1) AND (\"countryIsoCode\" = 'FR')")
            XCTAssertFalse(deleted)
            
            try db.execute(sql: "INSERT INTO citizenships (personId, countryIsoCode) VALUES (?, ?)", arguments: [1, "FR"])
            deleted = try Citizenship.deleteOne(db, key: ["personId": 1, "countryIsoCode": "FR"])
            XCTAssertTrue(deleted)
            XCTAssertEqual(try Citizenship.fetchCount(db), 0)
            
            try db.execute(sql: "INSERT INTO citizenships (personId, countryIsoCode) VALUES (?, ?)", arguments: [1, "FR"])
            try db.execute(sql: "INSERT INTO citizenships (personId, countryIsoCode) VALUES (?, ?)", arguments: [1, "US"])
            try db.execute(sql: "INSERT INTO citizenships (personId, countryIsoCode) VALUES (?, ?)", arguments: [2, "US"])
            let deletedCount = try Citizenship.deleteAll(db, keys: [["personId": 1, "countryIsoCode": "FR"], ["personId": 1, "countryIsoCode": "US"], ["personId": 1, "countryIsoCode": "DE"]])
            XCTAssertEqual(deletedCount, 2)
            XCTAssertEqual(try Citizenship.fetchCount(db), 1)
        }
    }

    func testUniqueIndex() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var deleted = try Person.deleteOne(db, key: ["email": "arthur@example.com"])
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" WHERE \"email\" = 'arthur@example.com'")
            XCTAssertFalse(deleted)
            
            try db.execute(sql: "INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [1, "Arthur", "arthur@example.com"])
            deleted = try Person.deleteOne(db, key: ["email": "arthur@example.com"])
            XCTAssertTrue(deleted)
            XCTAssertEqual(try Person.fetchCount(db), 0)
            
            try db.execute(sql: "INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [1, "Arthur", "arthur@example.com"])
            try db.execute(sql: "INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [2, "Barbara", "barbara@example.com"])
            try db.execute(sql: "INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [3, "Craig", "craig@example.com"])
            let deletedCount = try Person.deleteAll(db, keys: [["email": "arthur@example.com"], ["email": "barbara@example.com"], ["email": "david@example.com"]])
            XCTAssertEqual(deletedCount, 2)
            XCTAssertEqual(try Person.fetchCount(db), 1)
        }
    }

    func testImplicitUniqueIndexOnSingleColumnPrimaryKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var deleted = try Person.deleteOne(db, key: ["id": 1])
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" WHERE \"id\" = 1")
            XCTAssertFalse(deleted)
            
            try db.execute(sql: "INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [1, "Arthur", "arthur@example.com"])
            deleted = try Person.deleteOne(db, key: ["id": 1])
            XCTAssertTrue(deleted)
            XCTAssertEqual(try Person.fetchCount(db), 0)
            
            try db.execute(sql: "INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [1, "Arthur", "arthur@example.com"])
            try db.execute(sql: "INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [2, "Barbara", "barbara@example.com"])
            try db.execute(sql: "INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [3, "Craig", "craig@example.com"])
            let deletedCount = try Person.deleteAll(db, keys: [["id": 2], ["id": 3], ["id": 4]])
            XCTAssertEqual(deletedCount, 2)
            XCTAssertEqual(try Person.fetchCount(db), 1)
        }
    }
    
    func testRequestDeleteAll() throws {
        let dbQueue = try makeDatabaseQueue()
        
        try dbQueue.inDatabase { db in
            try Person.deleteAll(db)
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\"")
            
            try Person.filter(Column("name") == "Arthur").deleteAll(db)
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" WHERE \"name\" = 'Arthur'")
            
            try Person.filter(key: 1).deleteAll(db)
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" WHERE \"id\" = 1")
            
            try Person.filter(keys: [1, 2]).deleteAll(db)
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" WHERE \"id\" IN (1, 2)")
            
            try Person.filter(id: 1).deleteAll(db)
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" WHERE \"id\" = 1")
            
            try Person.filter(ids: [1, 2]).deleteAll(db)
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" WHERE \"id\" IN (1, 2)")
            
            try Person.filter(sql: "id = 1").deleteAll(db)
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" WHERE id = 1")
            
            try Person.filter(sql: "id = 1").filter(Column("name") == "Arthur").deleteAll(db)
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" WHERE (id = 1) AND (\"name\" = 'Arthur')")

            try Person.select(Column("name")).deleteAll(db)
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\"")
            
            try Person.order(Column("name")).deleteAll(db)
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\"")
            
            if try String.fetchCursor(db, sql: "PRAGMA COMPILE_OPTIONS").contains("ENABLE_UPDATE_DELETE_LIMIT") {
                try Person.limit(1).deleteAll(db)
                XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" LIMIT 1")
                
                try Person.order(Column("name")).deleteAll(db)
                XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\"")
                
                try Person.order(Column("name")).limit(1).deleteAll(db)
                XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" ORDER BY \"name\" LIMIT 1")
                
                try Person.order(Column("name")).limit(1, offset: 2).reversed().deleteAll(db)
                XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" ORDER BY \"name\" DESC LIMIT 1 OFFSET 2")
                
                try Person.limit(1, offset: 2).reversed().deleteAll(db)
                XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" LIMIT 1 OFFSET 2")
            }
        }
    }
    
    func testRequestDeleteAndFetchStatement() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        guard Database.sqliteLibVersionNumber >= 3035000 else {
            throw XCTSkip("RETURNING clause is not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("RETURNING clause is not available")
        }
#endif
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            do {
                let request = Person.all()
                let statement = try request.deleteAndFetchStatement(db, selection: [Column("name")])
                XCTAssertEqual(statement.sql, "DELETE FROM \"persons\" RETURNING \"name\"")
                XCTAssertEqual(statement.columnNames, ["name"])
            }
            do {
                let request = Person.all()
                let statement = try request.deleteAndFetchStatement(db, selection: [.allColumns])
                XCTAssertEqual(statement.sql, "DELETE FROM \"persons\" RETURNING *")
                XCTAssertEqual(statement.columnNames, ["id", "name", "email"])
            }
            do {
                let request = Person.all()
                let statement = try request.deleteAndFetchStatement(db, selection: [.allColumns(excluding: ["name"])])
                XCTAssertEqual(statement.sql, "DELETE FROM \"persons\" RETURNING \"id\", \"email\"")
                XCTAssertEqual(statement.columnNames, ["id", "email"])
            }
        }
    }
    
    func testRequestDeleteAndFetchCursor() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        guard Database.sqliteLibVersionNumber >= 3035000 else {
            throw XCTSkip("RETURNING clause is not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("RETURNING clause is not available")
        }
#endif
        
        let dbQueue = try makeDatabaseQueue()
        
        try dbQueue.inDatabase { db in
            _ = try Person.all().deleteAndFetchCursor(db).next()
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" RETURNING *")
            
            _ = try Person.all().deleteAndFetchCursor(db).next()
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" RETURNING *")
            
            _ = try Person.filter(Column("name") == "Arthur").deleteAndFetchCursor(db).next()
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" WHERE \"name\" = 'Arthur' RETURNING *")
            
            _ = try Person.filter(key: 1).deleteAndFetchCursor(db).next()
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" WHERE \"id\" = 1 RETURNING *")
            
            _ = try Person.filter(keys: [1, 2]).deleteAndFetchCursor(db).next()
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" WHERE \"id\" IN (1, 2) RETURNING *")
            
#if GRDBCUSTOMSQLITE || GRDBCIPHER
            _ = try Person.filter(id: 1).deleteAndFetchCursor(db).next()
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" WHERE \"id\" = 1 RETURNING *")
            
            _ = try Person.filter(ids: [1, 2]).deleteAndFetchCursor(db).next()
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" WHERE \"id\" IN (1, 2) RETURNING *")
#else
            _ = try Person.filter(id: 1).deleteAndFetchCursor(db).next()
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" WHERE \"id\" = 1 RETURNING *")
            
            _ = try Person.filter(ids: [1, 2]).deleteAndFetchCursor(db).next()
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" WHERE \"id\" IN (1, 2) RETURNING *")
#endif
            
            _ = try Person.filter(sql: "id = 1").deleteAndFetchCursor(db).next()
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" WHERE id = 1 RETURNING *")
            
            _ = try Person.filter(sql: "id = 1").filter(Column("name") == "Arthur").deleteAndFetchCursor(db).next()
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" WHERE (id = 1) AND (\"name\" = 'Arthur') RETURNING *")

            _ = try Person.select(Column("name")).deleteAndFetchCursor(db).next()
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" RETURNING *")
            
            _ = try Person.order(Column("name")).deleteAndFetchCursor(db).next()
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" RETURNING *")
            
            // No test for LIMIT ... RETURNING ... since this is not supported by SQLite
        }
    }
    
    func testRequestDeleteAndFetchArray() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        guard Database.sqliteLibVersionNumber >= 3035000 else {
            throw XCTSkip("RETURNING clause is not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("RETURNING clause is not available")
        }
#endif
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try Person(id: 1, name: "Arthur", email: "arthur@example.com").insert(db)
            try Person(id: 2, name: "Barbara", email: "barbara@example.com").insert(db)
            try Person(id: 3, name: "Craig", email: "craig@example.com").insert(db)

            let request = Person.filter(Column("id") != 2)
            let deletePersons = try request
                .deleteAndFetchAll(db)
                .sorted(by: { $0.id < $1.id })
            XCTAssertEqual(deletePersons, [
                Person(id: 1, name: "Arthur", email: "arthur@example.com"),
                Person(id: 3, name: "Craig", email: "craig@example.com"),
            ])
        }
    }
    
    func testRequestDeleteAndFetchSet() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        guard Database.sqliteLibVersionNumber >= 3035000 else {
            throw XCTSkip("RETURNING clause is not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("RETURNING clause is not available")
        }
#endif
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try Person(id: 1, name: "Arthur", email: "arthur@example.com").insert(db)
            try Person(id: 2, name: "Barbara", email: "barbara@example.com").insert(db)
            try Person(id: 3, name: "Craig", email: "craig@example.com").insert(db)

            let request = Person.filter(Column("id") != 2)
            let deletePersons = try request.deleteAndFetchSet(db)
            XCTAssertEqual(deletePersons, [
                Person(id: 1, name: "Arthur", email: "arthur@example.com"),
                Person(id: 3, name: "Craig", email: "craig@example.com"),
            ])
        }
    }
    
    func testRequestDeleteAndFetchIds() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        guard Database.sqliteLibVersionNumber >= 3035000 else {
            throw XCTSkip("RETURNING clause is not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("RETURNING clause is not available")
        }
#endif
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try Person(id: 1, name: "Arthur", email: "arthur@example.com").insert(db)
            try Person(id: 2, name: "Barbara", email: "barbara@example.com").insert(db)
            try Person(id: 3, name: "Craig", email: "craig@example.com").insert(db)

            let request = Person.filter(Column("id") != 2)
            let deletedIds = try request.deleteAndFetchIds(db)
            XCTAssertEqual(deletedIds, [1, 3])
        }
    }
    
    func testJoinedRequestDeleteAll() throws {
        try makeDatabaseQueue().inDatabase { db in
            struct Player: MutablePersistableRecord {
                static let team = belongsTo(Team.self)
                func encode(to container: inout PersistenceContainer) { preconditionFailure("should not be called") }
            }
            
            struct Team: MutablePersistableRecord {
                static let players = hasMany(Player.self)
                func encode(to container: inout PersistenceContainer) { preconditionFailure("should not be called") }
            }
            
            try db.create(table: "team") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.belongsTo("team")
            }
            
            do {
                try Player.including(required: Player.team).deleteAll(db)
                XCTAssertEqual(self.lastSQLQuery, """
                    DELETE FROM "player" WHERE "id" IN (\
                    SELECT "player"."id" \
                    FROM "player" \
                    JOIN "team" ON "team"."id" = "player"."teamId")
                    """)
            }
            do {
                let alias = TableAlias(name: "p")
                try Player.aliased(alias).including(required: Player.team).deleteAll(db)
                XCTAssertEqual(self.lastSQLQuery, """
                    DELETE FROM "player" WHERE "id" IN (\
                    SELECT "p"."id" \
                    FROM "player" "p" \
                    JOIN "team" ON "team"."id" = "p"."teamId")
                    """)
            }
            do {
                try Team.having(Team.players.isEmpty).deleteAll(db)
                XCTAssertEqual(self.lastSQLQuery, """
                    DELETE FROM "team" WHERE "id" IN (\
                    SELECT "team"."id" \
                    FROM "team" \
                    LEFT JOIN "player" ON "player"."teamId" = "team"."id" \
                    GROUP BY "team"."id" \
                    HAVING COUNT(DISTINCT "player"."id") = 0)
                    """)
            }
            do {
                try Team.including(all: Team.players).deleteAll(db)
                XCTAssertEqual(self.lastSQLQuery, """
                    DELETE FROM "team"
                    """)
            }
        }
    }
    
    func testJoinedRequestDeleteAndFetch() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        guard Database.sqliteLibVersionNumber >= 3035000 else {
            throw XCTSkip("RETURNING clause is not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("RETURNING clause is not available")
        }
#endif
        
        try makeDatabaseQueue().inDatabase { db in
            struct Player: MutablePersistableRecord, FetchableRecord {
                static let team = belongsTo(Team.self)
                func encode(to container: inout PersistenceContainer) { preconditionFailure("should not be called") }
                init(row: Row) { preconditionFailure("should not be called") }
            }
            
            struct Team: MutablePersistableRecord, FetchableRecord {
                // Test RETURNING
                static var databaseSelection: [any SQLSelectable] { [Column("id"), Column("name")] }
                static let players = hasMany(Player.self)
                func encode(to container: inout PersistenceContainer) { preconditionFailure("should not be called") }
                init(row: Row) { preconditionFailure("should not be called") }
            }
            
            try db.create(table: "team") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text)
            }
            
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.belongsTo("team")
            }
            
            do {
                let request = Player.including(required: Player.team)
                let statement = try request.deleteAndFetchStatement(db, selection: [.allColumns])
                XCTAssertEqual(statement.sql, """
                    DELETE FROM "player" WHERE "id" IN (\
                    SELECT "player"."id" \
                    FROM "player" \
                    JOIN "team" ON "team"."id" = "player"."teamId") \
                    RETURNING *
                    """)
                XCTAssertEqual(statement.columnNames, ["id", "teamId"])
                
                _ = try request.deleteAndFetchCursor(db).next()
                XCTAssertEqual(self.lastSQLQuery, """
                    DELETE FROM "player" WHERE "id" IN (\
                    SELECT "player"."id" \
                    FROM "player" \
                    JOIN "team" ON "team"."id" = "player"."teamId") \
                    RETURNING *
                    """)
            }
            do {
                let alias = TableAlias(name: "p")
                _ = try Player.aliased(alias).including(required: Player.team).deleteAndFetchCursor(db).next()
                XCTAssertEqual(self.lastSQLQuery, """
                    DELETE FROM "player" WHERE "id" IN (\
                    SELECT "p"."id" \
                    FROM "player" "p" \
                    JOIN "team" ON "team"."id" = "p"."teamId") \
                    RETURNING *
                    """)
            }
            do {
                let request = Team.having(Team.players.isEmpty)
                let statement = try request.deleteAndFetchStatement(db, selection: [.allColumns])
                XCTAssertEqual(statement.sql, """
                    DELETE FROM "team" WHERE "id" IN (\
                    SELECT "team"."id" \
                    FROM "team" \
                    LEFT JOIN "player" ON "player"."teamId" = "team"."id" \
                    GROUP BY "team"."id" \
                    HAVING COUNT(DISTINCT "player"."id") = 0) \
                    RETURNING *
                    """)
                XCTAssertEqual(statement.columnNames, ["id", "name"])
                
                _ = try request.deleteAndFetchCursor(db).next()
                XCTAssertEqual(self.lastSQLQuery, """
                    DELETE FROM "team" WHERE "id" IN (\
                    SELECT "team"."id" \
                    FROM "team" \
                    LEFT JOIN "player" ON "player"."teamId" = "team"."id" \
                    GROUP BY "team"."id" \
                    HAVING COUNT(DISTINCT "player"."id") = 0) \
                    RETURNING "id", "name"
                    """)
            }
            do {
                _ = try Team.including(all: Team.players).deleteAndFetchCursor(db).next()
                XCTAssertEqual(self.lastSQLQuery, """
                    DELETE FROM "team" RETURNING "id", "name"
                    """)
            }
        }
    }
    
    func testGroupedRequestDeleteAll() throws {
        try makeDatabaseQueue().inDatabase { db in
            struct Player: MutablePersistableRecord {
                func encode(to container: inout PersistenceContainer) { preconditionFailure("should not be called") }
            }
            struct Passport: MutablePersistableRecord {
                func encode(to container: inout PersistenceContainer) { preconditionFailure("should not be called") }
            }
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("score", .integer)
            }
            try db.create(table: "passport") { t in
                t.column("countryCode", .text).notNull()
                t.column("citizenId", .integer).notNull()
                t.primaryKey(["countryCode", "citizenId"])
            }
            do {
                try Player.all().groupByPrimaryKey().deleteAll(db)
                XCTAssertEqual(self.lastSQLQuery, """
                    DELETE FROM "player" WHERE "id" IN (\
                    SELECT "id" \
                    FROM "player" \
                    GROUP BY "id")
                    """)
            }
            do {
                try Player.all().group(-Column("id")).deleteAll(db)
                XCTAssertEqual(self.lastSQLQuery, """
                    DELETE FROM "player" WHERE "id" IN (\
                    SELECT "id" \
                    FROM "player" \
                    GROUP BY -"id")
                    """)
            }
            do {
                try Player.all().group(Column.rowID).deleteAll(db)
                XCTAssertEqual(self.lastSQLQuery, """
                    DELETE FROM "player" WHERE "id" IN (\
                    SELECT "id" \
                    FROM "player" \
                    GROUP BY "rowid")
                    """)
            }
            do {
                try Passport.all().groupByPrimaryKey().deleteAll(db)
                XCTAssertEqual(self.lastSQLQuery, """
                    DELETE FROM "passport" WHERE "rowid" IN (\
                    SELECT "rowid" \
                    FROM "passport" \
                    GROUP BY "rowid")
                    """)
            }
            do {
                try Passport.all().group(Column.rowID).deleteAll(db)
                XCTAssertEqual(self.lastSQLQuery, """
                    DELETE FROM "passport" WHERE "rowid" IN (\
                    SELECT "rowid" \
                    FROM "passport" \
                    GROUP BY "rowid")
                    """)
            }
        }
    }
    
    func testGroupedRequestDeleteAndFetchCursor() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        guard Database.sqliteLibVersionNumber >= 3035000 else {
            throw XCTSkip("RETURNING clause is not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("RETURNING clause is not available")
        }
#endif
        
        try makeDatabaseQueue().inDatabase { db in
            struct Player: MutablePersistableRecord, FetchableRecord {
                func encode(to container: inout PersistenceContainer) { preconditionFailure("should not be called") }
                init(row: Row) { preconditionFailure("should not be called") }
            }
            struct Passport: MutablePersistableRecord, FetchableRecord {
                func encode(to container: inout PersistenceContainer) { preconditionFailure("should not be called") }
                init(row: Row) { preconditionFailure("should not be called") }
            }
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("score", .integer)
            }
            try db.create(table: "passport") { t in
                t.column("countryCode", .text).notNull()
                t.column("citizenId", .integer).notNull()
                t.primaryKey(["countryCode", "citizenId"])
            }
            do {
                _ = try Player.all().groupByPrimaryKey().deleteAndFetchCursor(db).next()
                XCTAssertEqual(self.lastSQLQuery, """
                    DELETE FROM "player" WHERE "id" IN (\
                    SELECT "id" \
                    FROM "player" \
                    GROUP BY "id") \
                    RETURNING *
                    """)
            }
            do {
                _ = try Player.all().group(-Column("id")).deleteAndFetchCursor(db).next()
                XCTAssertEqual(self.lastSQLQuery, """
                    DELETE FROM "player" WHERE "id" IN (\
                    SELECT "id" \
                    FROM "player" \
                    GROUP BY -"id") \
                    RETURNING *
                    """)
            }
            do {
                _ = try Player.all().group(Column.rowID).deleteAndFetchCursor(db).next()
                XCTAssertEqual(self.lastSQLQuery, """
                    DELETE FROM "player" WHERE "id" IN (\
                    SELECT "id" \
                    FROM "player" \
                    GROUP BY "rowid") \
                    RETURNING *
                    """)
            }
            do {
                _ = try Passport.all().groupByPrimaryKey().deleteAndFetchCursor(db).next()
                XCTAssertEqual(self.lastSQLQuery, """
                    DELETE FROM "passport" WHERE "rowid" IN (\
                    SELECT "rowid" \
                    FROM "passport" \
                    GROUP BY "rowid") \
                    RETURNING *
                    """)
            }
            do {
                _ = try Passport.all().group(Column.rowID).deleteAndFetchCursor(db).next()
                XCTAssertEqual(self.lastSQLQuery, """
                    DELETE FROM "passport" WHERE "rowid" IN (\
                    SELECT "rowid" \
                    FROM "passport" \
                    GROUP BY "rowid") \
                    RETURNING *
                    """)
            }
        }
    }
}

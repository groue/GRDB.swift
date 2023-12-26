import XCTest
import GRDB

private final class TestStream: TextOutputStream {
    var output: String
    
    init() {
        output = ""
    }
    
    func write(_ string: String) {
        output.append(string)
    }
}

final class DatabaseQueueInMemoryCopyTests: GRDBTestCase {
    private func makeSourceDatabase() throws -> DatabaseQueue {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text)
                t.column("score", .integer)
            }
            try db.execute(sql: "INSERT INTO player VALUES (NULL, 'Arthur', 500)")
            try db.execute(sql: "INSERT INTO player VALUES (NULL, 'Barbara', 1000)")
        }
        return dbQueue
    }
    
    func test_inMemoryCopy() throws {
        let source = try makeSourceDatabase()
        let dbQueue = try DatabaseQueue.inMemoryCopy(
            fromPath: source.path,
            configuration: dbConfiguration)
        
        // Test that content was faithfully copied
        let stream = TestStream()
        try dbQueue.dumpContent(format: .quote(), to: stream)
        XCTAssertEqual(stream.output, """
            sqlite_master
            CREATE TABLE "player" ("id" INTEGER PRIMARY KEY AUTOINCREMENT, "name" TEXT, "score" INTEGER);
            
            player
            1,'Arthur',500
            2,'Barbara',1000
            
            """)
    }
    
    func test_inMemoryCopy_write() throws {
        let source = try makeSourceDatabase()
        let dbQueue = try DatabaseQueue.inMemoryCopy(
            fromPath: source.path,
            configuration: dbConfiguration)
        
        // The in-memory copy is writable (necessary for testing migrations)
        try dbQueue.write { db in
            try db.execute(sql: "INSERT INTO player VALUES (NULL, 'Craig', 200)")
        }
        let stream = TestStream()
        try dbQueue.dumpContent(format: .quote(), to: stream)
        XCTAssertEqual(stream.output, """
            sqlite_master
            CREATE TABLE "player" ("id" INTEGER PRIMARY KEY AUTOINCREMENT, "name" TEXT, "score" INTEGER);
            
            player
            1,'Arthur',500
            2,'Barbara',1000
            3,'Craig',200
            
            """)
    }
    
    func test_inMemoryCopy_readOnly() throws {
        let source = try makeSourceDatabase()
        var config = dbConfiguration!
        config.readonly = true
        let dbQueue = try DatabaseQueue.inMemoryCopy(fromPath: source.path, configuration: config)
        
        // Test that the copy is read-only
        XCTAssertThrowsError(try dbQueue.write { try $0.execute(sql: "DROP TABLE player") }) { error in
            guard let dbError = error as? DatabaseError else {
                XCTFail("Expected DatabaseError")
                return
            }
            XCTAssertEqual(dbError.message, "attempt to write a readonly database")
        }
        
        // Test that the copy is still read-only after a read
        try dbQueue.read { _ in }
        XCTAssertThrowsError(try dbQueue.write { try $0.execute(sql: "DROP TABLE player") }) { error in
            guard let dbError = error as? DatabaseError else {
                XCTFail("Expected DatabaseError")
                return
            }
            XCTAssertEqual(dbError.message, "attempt to write a readonly database")
        }
        
        // Test that content was faithfully copied
        let stream = TestStream()
        try dbQueue.dumpContent(format: .quote(), to: stream)
        XCTAssertEqual(stream.output, """
            sqlite_master
            CREATE TABLE "player" ("id" INTEGER PRIMARY KEY AUTOINCREMENT, "name" TEXT, "score" INTEGER);
            
            player
            1,'Arthur',500
            2,'Barbara',1000
            
            """)
    }
    
    func test_migrations_are_testable() throws {
        // Given a migrator…
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { try $0.create(table: "team") { $0.autoIncrementedPrimaryKey("id") } }
        migrator.registerMigration("v2") { try $0.create(table: "match") { $0.autoIncrementedPrimaryKey("id") } }
        migrator.registerMigration("v3") { try $0.drop(table: "match") }
        
        // …GRDB users can test the migrator on fixtures
        let source = try makeSourceDatabase()
        let dbQueue = try DatabaseQueue.inMemoryCopy(
            fromPath: source.path,
            configuration: dbConfiguration)
        
        try migrator.migrate(dbQueue, upTo: "v2")
        do {
            let stream = TestStream()
            try dbQueue.dumpContent(format: .quote(), to: stream)
            XCTAssertEqual(stream.output, """
                sqlite_master
                CREATE TABLE "match" ("id" INTEGER PRIMARY KEY AUTOINCREMENT);
                CREATE TABLE "player" ("id" INTEGER PRIMARY KEY AUTOINCREMENT, "name" TEXT, "score" INTEGER);
                CREATE TABLE "team" ("id" INTEGER PRIMARY KEY AUTOINCREMENT);
                
                match
                
                player
                1,'Arthur',500
                2,'Barbara',1000
                
                team
                
                """)
        }
        
        try migrator.migrate(dbQueue, upTo: "v3")
        do {
            let stream = TestStream()
            try dbQueue.dumpContent(format: .quote(), to: stream)
            XCTAssertEqual(stream.output, """
                sqlite_master
                CREATE TABLE "player" ("id" INTEGER PRIMARY KEY AUTOINCREMENT, "name" TEXT, "score" INTEGER);
                CREATE TABLE "team" ("id" INTEGER PRIMARY KEY AUTOINCREMENT);
                
                player
                1,'Arthur',500
                2,'Barbara',1000
                
                team
                
                """)
        }
    }
}

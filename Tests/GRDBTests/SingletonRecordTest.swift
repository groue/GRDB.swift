import XCTest
import GRDB

private struct AppConfiguration: Codable {
    // Support for the single row guarantee
    private var id = 1
    
    // The configuration properties
    var text: String
    // ... other properties
    
    init(text: String) {
        self.text = text
    }
}

extension AppConfiguration {
    /// The default configuration
    static let `default` = AppConfiguration(text: "default")
}

// Database Access
extension AppConfiguration: FetchableRecord, PersistableRecord {
    // Customize the default PersistableRecord behavior
    func willUpdate(_ db: Database, columns: Set<String>) throws {
        // Insert the default configuration if it does not exist yet.
        if try !exists(db) {
            try AppConfiguration.default.insert(db)
        }
    }
    
    /// Returns the persisted configuration, or the default one if the
    /// database table is empty.
    static func find(_ db: Database) throws -> AppConfiguration {
        try fetchOne(db) ?? .default
    }
}

class SingletonRecordTest: GRDBTestCase {
    private func createEmptyAppConfigurationTable(_ db: Database) throws {
        // Table creation
        try db.create(table: "appConfiguration") { t in
            // Single row guarantee
            t.primaryKey("id", .integer, onConflict: .replace).check { $0 == 1 }
            
            // The configuration columns
            t.column("text", .text).notNull()
            // ... other columns
        }
    }
    
    func test_fetch_from_empty_database() throws {
        try makeDatabaseQueue().write { db in
            // Given
            try createEmptyAppConfigurationTable(db)
            // When
            let config = try AppConfiguration.find(db)
            // Then
            XCTAssertEqual(config.text, "default")
        }
    }
    
    func test_fetch_from_populated_database() throws {
        try makeDatabaseQueue().write { db in
            // Given
            try createEmptyAppConfigurationTable(db)
            try AppConfiguration(text: "initial").insert(db)
            // When
            let config = try AppConfiguration.find(db)
            // Then
            XCTAssertEqual(config.text, "initial")
        }
    }
    
    func test_insert_in_empty_database() throws {
        try makeDatabaseQueue().write { db in
            // Given
            try createEmptyAppConfigurationTable(db)
            // When
            try AppConfiguration(text: "test").insert(db)
            // Then
            try XCTAssertEqual(AppConfiguration.find(db).text, "test")
            let row = try XCTUnwrap(Row.fetchOne(db, sql: "SELECT * FROM appConfiguration"))
            XCTAssertEqual(row, ["id": 1, "text": "test"])
        }
    }
    
    func test_insert_in_populated_database() throws {
        try makeDatabaseQueue().write { db in
            // Given
            try createEmptyAppConfigurationTable(db)
            try AppConfiguration(text: "initial").insert(db)
            // When
            try AppConfiguration(text: "test").insert(db)
            // Then
            try XCTAssertEqual(AppConfiguration.find(db).text, "test")
            let row = try XCTUnwrap(Row.fetchOne(db, sql: "SELECT * FROM appConfiguration"))
            XCTAssertEqual(row, ["id": 1, "text": "test"])
        }
    }
    
    func test_update_in_empty_database() throws {
        try makeDatabaseQueue().write { db in
            // Given
            try createEmptyAppConfigurationTable(db)
            // When
            try AppConfiguration(text: "test").update(db)
            // Then
            try XCTAssertEqual(AppConfiguration.find(db).text, "test")
            let row = try XCTUnwrap(Row.fetchOne(db, sql: "SELECT * FROM appConfiguration"))
            XCTAssertEqual(row, ["id": 1, "text": "test"])
        }
    }
    
    func test_update_in_populated_database() throws {
        try makeDatabaseQueue().write { db in
            // Given
            try createEmptyAppConfigurationTable(db)
            try AppConfiguration(text: "initial").insert(db)
            // When
            try AppConfiguration(text: "test").update(db)
            // Then
            try XCTAssertEqual(AppConfiguration.find(db).text, "test")
            let row = try XCTUnwrap(Row.fetchOne(db, sql: "SELECT * FROM appConfiguration"))
            XCTAssertEqual(row, ["id": 1, "text": "test"])
        }
    }
    
    func test_update_changes_in_empty_database() throws {
        try makeDatabaseQueue().write { db in
            // Given
            try createEmptyAppConfigurationTable(db)
            // When
            var config = try AppConfiguration.find(db)
            try config.updateChanges(db) {
                $0.text = "test"
            }
            // Then
            try XCTAssertEqual(AppConfiguration.find(db).text, "test")
            let row = try XCTUnwrap(Row.fetchOne(db, sql: "SELECT * FROM appConfiguration"))
            XCTAssertEqual(row, ["id": 1, "text": "test"])
        }
    }
    
    func test_update_changes_in_populated_database() throws {
        try makeDatabaseQueue().write { db in
            // Given
            try createEmptyAppConfigurationTable(db)
            try AppConfiguration(text: "initial").insert(db)
            // When
            var config = try AppConfiguration.find(db)
            try config.updateChanges(db) {
                $0.text = "test"
            }
            // Then
            try XCTAssertEqual(AppConfiguration.find(db).text, "test")
            let row = try XCTUnwrap(Row.fetchOne(db, sql: "SELECT * FROM appConfiguration"))
            XCTAssertEqual(row, ["id": 1, "text": "test"])
        }
    }
    
    func test_save_in_empty_database() throws {
        try makeDatabaseQueue().write { db in
            // Given
            try createEmptyAppConfigurationTable(db)
            // When
            try AppConfiguration(text: "test").save(db)
            // Then
            try XCTAssertEqual(AppConfiguration.find(db).text, "test")
            let row = try XCTUnwrap(Row.fetchOne(db, sql: "SELECT * FROM appConfiguration"))
            XCTAssertEqual(row, ["id": 1, "text": "test"])
        }
    }
    
    func test_save_in_populated() throws {
        try makeDatabaseQueue().write { db in
            // Given
            try createEmptyAppConfigurationTable(db)
            try AppConfiguration(text: "initial").insert(db)
            // When
            try AppConfiguration(text: "test").save(db)
            // Then
            try XCTAssertEqual(AppConfiguration.find(db).text, "test")
            let row = try XCTUnwrap(Row.fetchOne(db, sql: "SELECT * FROM appConfiguration"))
            XCTAssertEqual(row, ["id": 1, "text": "test"])
        }
    }
    
    func test_upsert_in_empty_database() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        guard Database.sqliteLibVersionNumber >= 3035000 else {
            throw XCTSkip("UPSERT is not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("UPSERT is not available")
        }
#endif
        
        try makeDatabaseQueue().write { db in
            // Given
            try createEmptyAppConfigurationTable(db)
            // When
            try AppConfiguration(text: "test").upsert(db)
            // Then
            try XCTAssertEqual(AppConfiguration.find(db).text, "test")
            let row = try XCTUnwrap(Row.fetchOne(db, sql: "SELECT * FROM appConfiguration"))
            XCTAssertEqual(row, ["id": 1, "text": "test"])
        }
    }
    
    func test_upsert_in_populated_database() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        guard Database.sqliteLibVersionNumber >= 3035000 else {
            throw XCTSkip("UPSERT is not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("UPSERT is not available")
        }
#endif
        
        try makeDatabaseQueue().write { db in
            // Given
            try createEmptyAppConfigurationTable(db)
            try AppConfiguration(text: "initial").insert(db)
            // When
            try AppConfiguration(text: "test").upsert(db)
            // Then
            try XCTAssertEqual(AppConfiguration.find(db).text, "test")
            let row = try XCTUnwrap(Row.fetchOne(db, sql: "SELECT * FROM appConfiguration"))
            XCTAssertEqual(row, ["id": 1, "text": "test"])
        }
    }
}

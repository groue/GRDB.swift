import XCTest
import GRDB

private struct AppConfiguration: Codable {
    // Support for the single row guarantee
    private var id = 1
    
    // The stored properties
    private var storedText: String?
    // ... other properties
    
    // The public properties
    var text: String {
        get { storedText ?? "default" }
        set { storedText = newValue }
    }
    
    mutating func resetText() {
        storedText = nil
    }
}

extension AppConfiguration {
    /// The default configuration
    static let `default` = AppConfiguration()
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

class SingletonUserDefaultsTest: GRDBTestCase {
    private func createEmptyAppConfigurationTable(_ db: Database) throws {
        // Table creation
        try db.create(table: "appConfiguration") { t in
            // Single row guarantee
            t.primaryKey("id", .integer, onConflict: .replace).check { $0 == 1 }
            
            // The configuration columns
            t.column("storedText", .text)
            // ... other columns
        }
    }
    
    func test_find_in_empty_database() throws {
        try makeDatabaseQueue().write { db in
            // Given
            try createEmptyAppConfigurationTable(db)
            // When
            let config = try AppConfiguration.find(db)
            // Then
            XCTAssertEqual(config.text, "default")
        }
    }
    
    func test_find_in_populated_database_null() throws {
        try makeDatabaseQueue().write { db in
            // Given
            try createEmptyAppConfigurationTable(db)
            try AppConfiguration().insert(db)
            // When
            let config = try AppConfiguration.find(db)
            // Then
            XCTAssertEqual(config.text, "default")
        }
    }
    
    func test_find_from_populated_database_not_null() throws {
        try makeDatabaseQueue().write { db in
            // Given
            try createEmptyAppConfigurationTable(db)
            try db.execute(sql: "INSERT INTO appConfiguration(storedText) VALUES ('initial')")
            // When
            let config = try AppConfiguration.find(db)
            // Then
            XCTAssertEqual(config.text, "initial")
        }
    }
    
    func test_save_in_empty_database() throws {
        try makeDatabaseQueue().write { db in
            // Given
            try createEmptyAppConfigurationTable(db)
            // When
            var appConfiguration = try AppConfiguration.find(db)
            appConfiguration.text = "test"
            try appConfiguration.save(db)
            // Then
            try XCTAssertEqual(AppConfiguration.find(db).text, "test")
            let row = try XCTUnwrap(Row.fetchOne(db, sql: "SELECT * FROM appConfiguration"))
            XCTAssertEqual(row, ["id": 1, "storedText": "test"])
        }
    }
    
    func test_save_in_populated_database() throws {
        try makeDatabaseQueue().write { db in
            // Given
            try createEmptyAppConfigurationTable(db)
            try db.execute(sql: "INSERT INTO appConfiguration(storedText) VALUES ('initial')")
            // When
            var appConfiguration = try AppConfiguration.find(db)
            appConfiguration.text = "test"
            try appConfiguration.save(db)
            // Then
            try XCTAssertEqual(AppConfiguration.find(db).text, "test")
            let row = try XCTUnwrap(Row.fetchOne(db, sql: "SELECT * FROM appConfiguration"))
            XCTAssertEqual(row, ["id": 1, "storedText": "test"])
        }
    }
    
    func test_reset_and_save_in_populated_database() throws {
        try makeDatabaseQueue().write { db in
            // Given
            try createEmptyAppConfigurationTable(db)
            try db.execute(sql: "INSERT INTO appConfiguration(storedText) VALUES ('initial')")
            // When
            var appConfiguration = try AppConfiguration.find(db)
            appConfiguration.resetText()
            try appConfiguration.save(db)
            // Then
            try XCTAssertEqual(AppConfiguration.find(db).text, "default")
            let row = try XCTUnwrap(Row.fetchOne(db, sql: "SELECT * FROM appConfiguration"))
            XCTAssertEqual(row, ["id": 1, "storedText": nil])
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
            XCTAssertEqual(config.text, "test")
            try XCTAssertEqual(AppConfiguration.find(db).text, "test")
            let row = try XCTUnwrap(Row.fetchOne(db, sql: "SELECT * FROM appConfiguration"))
            XCTAssertEqual(row, ["id": 1, "storedText": "test"])
        }
    }
    
    func test_update_changes_in_populated_database() throws {
        try makeDatabaseQueue().write { db in
            // Given
            try createEmptyAppConfigurationTable(db)
            try db.execute(sql: "INSERT INTO appConfiguration(storedText) VALUES ('initial')")
            // When
            var config = try AppConfiguration.find(db)
            try config.updateChanges(db) {
                $0.text = "test"
            }
            // Then
            XCTAssertEqual(config.text, "test")
            try XCTAssertEqual(AppConfiguration.find(db).text, "test")
            let row = try XCTUnwrap(Row.fetchOne(db, sql: "SELECT * FROM appConfiguration"))
            XCTAssertEqual(row, ["id": 1, "storedText": "test"])
        }
    }
}

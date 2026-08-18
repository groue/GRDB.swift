import XCTest
import GRDB

/// Here we test the decoding of string columns. The other fetch tests in
/// this target use an all-INT model, and never decode a string.
class FetchStringTests: XCTestCase {
    static let expectedRowCount = 200_000
    static let personRowCount = 100_000
    static let recordFetchesPerIteration = 5
    static let fetchesPerIteration = 10

    private struct Person: Codable, FetchableRecord, PersistableRecord {
        static let databaseTableName = "person"

        var firstName: String
        var lastName: String
        var email: String
        var address: String
        var age: Int
        var height: Double
    }

    func test_shortString_fetch_performance() throws {
        try measureFetch(of: String.self, from: "short")
    }

    func test_longString_fetch_performance() throws {
        try measureFetch(of: String.self, from: "long")
    }

    func test_shortString_databaseValue_performance() throws {
        try measureFetch(of: DatabaseValue.self, from: "short")
    }

    func test_longString_databaseValue_performance() throws {
        try measureFetch(of: DatabaseValue.self, from: "long")
    }

    func test_record_fetch_performance() throws {
        let dbQueue = try makePersonDatabase()
        measure {
            try! dbQueue.read { db in
                for _ in 0..<Self.recordFetchesPerIteration {
                    let people = try Person.fetchAll(db)
                    XCTAssertEqual(people.count, Self.personRowCount)
                }
            }
        }
    }

    private func measureFetch<Value: DatabaseValueConvertible>(
        of type: Value.Type,
        from column: String) throws
    {
        let dbQueue = try makeDatabaseQueue()
        measure {
            try! dbQueue.read { db in
                for _ in 0..<Self.fetchesPerIteration {
                    let values = try Value.fetchAll(db, sql: "SELECT \(column) FROM item")
                    XCTAssertEqual(values.count, Self.expectedRowCount)
                }
            }
        }
    }

    private func makePersonDatabase() throws -> DatabaseQueue {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("GRDBPerformancePeople.sqlite")
        let dbQueue = try DatabaseQueue(path: url.path)
        try dbQueue.write { db in
            if try db.tableExists("person"),
               try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM person") == Self.personRowCount
            {
                return
            }
            try db.execute(sql: "DROP TABLE IF EXISTS person")
            try db.create(table: "person") { table in
                table.column("firstName", .text)
                table.column("lastName", .text)
                table.column("email", .text)
                table.column("address", .text)
                table.column("age", .integer)
                table.column("height", .double)
            }
            let statement = try db.makeStatement(sql: """
                INSERT INTO person (firstName, lastName, email, address, age, height)
                VALUES (?, ?, ?, ?, ?, ?)
                """)
            for index in 0..<Self.personRowCount {
                try statement.execute(arguments: [
                    "Arthur", "Dubois", "arthur.dubois@example.com",
                    "12 Rue de la Paix, 75002 Paris", 20 + index % 60, 1.60 + Double(index % 40) / 100,
                ])
            }
        }
        return dbQueue
    }

    private func makeDatabaseQueue() throws -> DatabaseQueue {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("GRDBPerformanceStrings.sqlite")
        let dbQueue = try DatabaseQueue(path: url.path)
        try dbQueue.write { db in
            if try db.tableExists("item"),
               try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM item") == Self.expectedRowCount
            {
                return
            }
            try db.execute(sql: "DROP TABLE IF EXISTS item")
            try db.execute(sql: "CREATE TABLE item (short TEXT, long TEXT)")
            let statement = try db.makeStatement(sql: "INSERT INTO item (short, long) VALUES (?, ?)")
            for _ in 0..<Self.expectedRowCount {
                try statement.execute(arguments: [ArgumentsTests.shortString, ArgumentsTests.longString])
            }
        }
        return dbQueue
    }
}

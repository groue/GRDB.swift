import XCTest
import GRDB

// Inspired by <https://github.com/groue/GRDB.swift/pull/1873>
class StatementPreparationPerformanceTests: XCTestCase {
    let iterationCount = 10_000
    
    func testStatementPreparationPerformance_wide() throws {
        let dbQueue = try makeTestDatabase()
        dbQueue.inDatabase { db in
            measure {
                for _ in 0..<iterationCount {
                    _ = try! db.makeStatement(sql: "SELECT * FROM wide")
                }
            }
        }
    }
    
    func testStatementPreparationPerformance_join() throws {
        let dbQueue = try makeTestDatabase()
        dbQueue.inDatabase { db in
            measure {
                for _ in 0..<iterationCount {
                    _ = try! db.makeStatement(sql: """
                        SELECT author.*, book.*, review.*
                        FROM author
                        JOIN book ON book.authorId = author.id
                        JOIN review ON review.bookId = book.id
                        """)
                }
            }
        }
    }
    
    func testStatementPreparationPerformance_narrow() throws {
        let dbQueue = try makeTestDatabase()
        dbQueue.inDatabase { db in
            measure {
                for _ in 0..<iterationCount {
                    _ = try! db.makeStatement(sql: "SELECT id FROM wide")
                }
            }
        }
    }
    
    private func makeTestDatabase() throws -> DatabaseQueue {
        let dbQueue = try DatabaseQueue()
        try dbQueue.write { db in
            try db.execute(sql: createTableSQL(
                table: "wide",
                columns: ["id INTEGER PRIMARY KEY"] + integerColumns(count: 119)))
            try db.execute(sql: createTableSQL(
                table: "author",
                columns: ["id INTEGER PRIMARY KEY"] + integerColumns(count: 39)))
            try db.execute(sql: createTableSQL(
                table: "book",
                columns: ["id INTEGER PRIMARY KEY", "authorId INTEGER"]
                + integerColumns(count: 38)))
            try db.execute(sql: createTableSQL(
                table: "review",
                columns: ["id INTEGER PRIMARY KEY", "bookId INTEGER"]
                + integerColumns(count: 38)))
        }
        
        return dbQueue
    }
    
    private func createTableSQL(table: String, columns: [String]) -> String {
        "CREATE TABLE \(table) (\(columns.joined(separator: ", ")))"
    }
    
    private func integerColumns(count: Int) -> [String] {
        (1...count).map { "column\($0) INTEGER" }
    }
}

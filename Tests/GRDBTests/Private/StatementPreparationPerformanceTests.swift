import Dispatch
import XCTest
@testable import GRDB

/// Measures statement preparation performance in optimized builds.
///
/// Run with:
///
/// ```sh
/// swift test -c release --filter StatementPreparationPerformanceTests
/// ```
class StatementPreparationPerformanceTests: XCTestCase {
    private let iterationCount = 1_000
    private let sampleCount = 5
    
    func testStatementPreparationPerformance() throws {
#if DEBUG
        throw XCTSkip(
            "Run with: swift test -c release --filter StatementPreparationPerformanceTests")
#else
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
            
            let benchmarks = [
                ("wide", "SELECT * FROM wide"),
                ("join", """
                    SELECT author.*, book.*, review.*
                    FROM author
                    JOIN book ON book.authorId = author.id
                    JOIN review ON review.bookId = book.id
                    """),
                ("narrow", "SELECT id FROM wide"),
            ]
            
            let sqliteVersion = try String.fetchOne(
                db,
                sql: "SELECT sqlite_version()")!
            print("Statement preparation benchmark")
            print("SQLite: \(sqliteVersion)")
            print("Iterations: \(iterationCount); samples: \(sampleCount)")
            
            for (name, sql) in benchmarks {
                let result = try benchmark(db, sql: sql)
                print(String(
                    format: "%@: %.3f ms total, %.3f us/prepare",
                    name,
                    result.totalMilliseconds,
                    result.microsecondsPerPrepare))
            }
        }
#endif
    }
    
    private func benchmark(
        _ db: Database,
        sql: String)
    throws -> (totalMilliseconds: Double, microsecondsPerPrepare: Double) {
        for _ in 0..<100 {
            _ = try db.makeStatement(sql: sql)
        }
        
        var samples: [UInt64] = []
        samples.reserveCapacity(sampleCount)
        for _ in 0..<sampleCount {
            let start = DispatchTime.now().uptimeNanoseconds
            for _ in 0..<iterationCount {
                _ = try db.makeStatement(sql: sql)
            }
            samples.append(DispatchTime.now().uptimeNanoseconds - start)
        }
        
        let medianNanoseconds = samples.sorted()[sampleCount / 2]
        let totalMilliseconds = Double(medianNanoseconds) / 1_000_000
        let microsecondsPerPrepare = Double(medianNanoseconds)
            / Double(iterationCount)
            / 1_000
        return (totalMilliseconds, microsecondsPerPrepare)
    }
    
    private func createTableSQL(table: String, columns: [String]) -> String {
        "CREATE TABLE \(table) (\(columns.joined(separator: ", ")))"
    }
    
    private func integerColumns(count: Int) -> [String] {
        (1...count).map { "column\($0) INTEGER" }
    }
}

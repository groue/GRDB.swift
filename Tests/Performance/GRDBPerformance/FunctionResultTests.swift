import XCTest
import GRDB

/// Here we test the return of string values from a custom SQL function.
class FunctionResultTests: XCTestCase {

    private let rowCount = 100_000
    private let queriesPerIteration = 20

    var dbDirectoryPath: String!
    var dbQueue: DatabaseQueue!
    
    static let echo = DatabaseFunction("echo", argumentCount: 1, pure: true) { dbValues in
        String.fromDatabaseValue(dbValues[0])
    }

    override func setUpWithError() throws {
        let dbDirectoryName = "FunctionResultTests-\(ProcessInfo.processInfo.globallyUniqueString)"
        dbDirectoryPath = (NSTemporaryDirectory() as NSString).appendingPathComponent(dbDirectoryName)
        try FileManager.default.createDirectory(atPath: dbDirectoryPath, withIntermediateDirectories: true)
        let dbPath = (dbDirectoryPath as NSString).appendingPathComponent("db.sqlite")

        var configuration = Configuration()
        configuration.prepareDatabase { db in
            db.add(function: Self.echo)
        }
        dbQueue = try DatabaseQueue(path: dbPath, configuration: configuration)
    }

    override func tearDownWithError() throws {
        dbQueue = nil
        try FileManager.default.removeItem(atPath: dbDirectoryPath)
    }

    func test_shortString_functionResult_performance() throws {
        try measureFunctionResults(over: ArgumentsTests.shortString)
    }

    func test_longString_functionResult_performance() throws {
        try measureFunctionResults(over: ArgumentsTests.longString)
    }

    private func measureFunctionResults(over string: String) throws {
        try dbQueue.write { db in
            try db.execute(sql: "CREATE TABLE t(a TEXT)")
            let statement = try db.makeStatement(sql: "INSERT INTO t(a) VALUES (?)")
            for _ in 0..<rowCount {
                try statement.execute(arguments: [string])
            }
        }

        measure {
            try! dbQueue.read { db in
                for _ in 0..<queriesPerIteration {
                    _ = try Int.fetchOne(db, sql: "SELECT COUNT(echo(a)) FROM t")
                }
            }
        }
    }
}

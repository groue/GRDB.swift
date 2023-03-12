import XCTest
import GRDB

class ArgumentsTests: XCTestCase {
    static let shortString = "foo"
    static let longString = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus consectetur felis eget nibh aliquet ullamcorper. Nam sodales, tellus a cursus tincidunt, arcu purus suscipit elit, nec congue erat ipsum a purus."
    
    var dbDirectoryPath: String!
    var dbQueue: DatabaseQueue!
    
    override func setUpWithError() throws {
        let dbDirectoryName = "ArgumentsTests-\(ProcessInfo.processInfo.globallyUniqueString)"
        dbDirectoryPath = (NSTemporaryDirectory() as NSString).appendingPathComponent(dbDirectoryName)
        try FileManager.default.createDirectory(atPath: dbDirectoryPath, withIntermediateDirectories: true)
        let dbPath = (dbDirectoryPath as NSString).appendingPathComponent("db.sqlite")
        dbQueue = try DatabaseQueue(path: dbPath)
    }
    
    override func tearDownWithError() throws {
        dbQueue = nil
        try FileManager.default.removeItem(atPath: dbDirectoryPath)
    }
    
    func test_shortString_legacy_performance_() throws {
        try dbQueue.write { db in
            try db.execute(sql: "CREATE TABLE t(a)")
            
            let statement = try db.makeStatement(sql: "INSERT INTO t(a) VALUES (?)")
            let arguments: StatementArguments = [Self.shortString]
            measure {
                for _ in 0..<1_000_000 {
                    // Simulate old implementation of statement.execute(arguments: arguments)
                    try! statement.setArguments(arguments)
                    try! statement.execute()
                }
            }
        }
    }
    
    func test_shortString_SQLITE_STATIC_performance() throws {
        try dbQueue.write { db in
            try db.execute(sql: "CREATE TABLE t(a)")
            
            let statement = try db.makeStatement(sql: "INSERT INTO t(a) VALUES (?)")
            let arguments: StatementArguments = [Self.shortString]
            measure {
                for _ in 0..<1_000_000 {
                    try! statement.execute(arguments: arguments)
                }
            }
        }
    }
    
    func test_shortString_SQLITE_TRANSIENT_performance() throws {
        try dbQueue.write { db in
            try db.execute(sql: "CREATE TABLE t(a)")
            
            let statement = try db.makeStatement(sql: "INSERT INTO t(a) VALUES (?)")
            let arguments: StatementArguments = [Self.shortString]
            try statement.setArguments(arguments)
            measure {
                for _ in 0..<1_000_000 {
                    try! statement.execute()
                }
            }
        }
    }
    
    func test_longString_legacy_performance_() throws {
        try dbQueue.write { db in
            try db.execute(sql: "CREATE TABLE t(a)")
            
            let statement = try db.makeStatement(sql: "INSERT INTO t(a) VALUES (?)")
            let arguments: StatementArguments = [Self.longString]
            measure {
                for _ in 0..<1_000_000 {
                    // Simulate old implementation of statement.execute(arguments: arguments)
                    try! statement.setArguments(arguments)
                    try! statement.execute()
                }
            }
        }
    }
    
    func test_longString_SQLITE_STATIC_performance() throws {
        try dbQueue.write { db in
            try db.execute(sql: "CREATE TABLE t(a)")
            
            let statement = try db.makeStatement(sql: "INSERT INTO t(a) VALUES (?)")
            let arguments: StatementArguments = [Self.longString]
            measure {
                for _ in 0..<1_000_000 {
                    try! statement.execute(arguments: arguments)
                }
            }
        }
    }
    
    func test_longString_SQLITE_TRANSIENT_performance() throws {
        try dbQueue.write { db in
            try db.execute(sql: "CREATE TABLE t(a)")
            
            let statement = try db.makeStatement(sql: "INSERT INTO t(a) VALUES (?)")
            let arguments: StatementArguments = [Self.longString]
            try! statement.setArguments(arguments)
            measure {
                for _ in 0..<1_000_000 {
                    try! statement.execute()
                }
            }
        }
    }
}

import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class FTS3TableBuilderTests: GRDBTestCase {
    
    func testFTS3TableBuilderWithColumns() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(virtualTable: "books", using: FTS3()) { t in
                    t.column("author")
                    t.column("title")
                    t.column("body")
                }
                XCTAssertTrue(sqlQueries.contains("CREATE VIRTUAL TABLE \"books\" USING FTS3(author, title, body)"))
            }
        }
    }
    
    func testFTS3TableBuilderWithoutColumns() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(virtualTable: "books", using: FTS3())
                print(sqlQueries)
                XCTAssertTrue(sqlQueries.contains("CREATE VIRTUAL TABLE \"books\" USING FTS3"))
            }
        }
    }
    
    func testFTS3TableBuilderWithOptions() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(virtualTable: "books", ifNotExists: true, using: FTS3())
                print(sqlQueries)
                XCTAssertTrue(sqlQueries.contains("CREATE VIRTUAL TABLE IF NOT EXISTS \"books\" USING FTS3"))
            }
        }
    }
}

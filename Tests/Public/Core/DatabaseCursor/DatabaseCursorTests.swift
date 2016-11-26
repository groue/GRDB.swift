import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class DatabaseCursorTests: GRDBTestCase {
    
    func testNextReturnsNilAfterExhaustion() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                do {
                    let cursor = try Int.fetchCursor(db, "SELECT 1 WHERE 0")
                    XCTAssert(try cursor.next() == nil) // end
                    XCTAssert(try cursor.next() == nil) // past the end
                }
                do {
                    let cursor = try Int.fetchCursor(db, "SELECT 1")
                    XCTAssertEqual(try cursor.next()!,  1)
                    XCTAssert(try cursor.next() == nil) // end
                    XCTAssert(try cursor.next() == nil) // past the end
                }
                do {
                    let cursor = try Int.fetchCursor(db, "SELECT 1 AS i UNION SELECT 2 ORDER BY i")
                    XCTAssertEqual(try cursor.next()!, 1)
                    XCTAssertEqual(try cursor.next()!, 2)
                    XCTAssert(try cursor.next() == nil) // end
                    XCTAssert(try cursor.next() == nil) // past the end
                }
            }
        }
    }
    
    func testEnumerated() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let cursor = try String.fetchCursor(db, "SELECT 'bar' AS v UNION SELECT 'foo' ORDER BY v")
                let enumerated = cursor.enumerated()
                var (n, v) = try enumerated.next()!
                XCTAssertEqual(n, 0)
                XCTAssertEqual(v, "bar")
                (n, v) = try enumerated.next()!
                XCTAssertEqual(n, 1)
                XCTAssertEqual(v, "foo")
                XCTAssert(try enumerated.next() == nil) // end
            }
        }
    }
    
    func testFilter() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let cursor = try Int.fetchCursor(db, "SELECT 1 AS i UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 ORDER BY i")
                let odds = try cursor.filter { $0 % 2 == 1 }
                XCTAssertEqual(odds, [1, 3])
            }
        }
    }
    
    func testForEach() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let cursor = try Int.fetchCursor(db, "SELECT 1 AS i UNION SELECT 2 ORDER BY i")
                var ints: [Int] = []
                try cursor.forEach { ints.append($0) }
                XCTAssertEqual(ints, [1, 2])
            }
        }
    }
    
    func testMap() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let cursor = try Int.fetchCursor(db, "SELECT 1 AS i UNION SELECT 2 ORDER BY i")
                let squares = try cursor.map { $0 * $0 }
                XCTAssertEqual(squares, [1, 4])
            }
        }
    }
    
    func testReduce() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let cursor = try Int.fetchCursor(db, "SELECT 1 AS i UNION SELECT 2 ORDER BY i")
                let squareSum = try cursor.reduce(0) { (acc, int) in acc + int * int }
                XCTAssertEqual(squareSum, 5)
            }
        }
    }
}

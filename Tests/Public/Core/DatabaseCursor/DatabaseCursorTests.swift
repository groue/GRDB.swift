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
                    let cursor = try Int.fetchCursor(db, "SELECT 1 AS i UNION ALL SELECT 2 ORDER BY i")
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
                let cursor = try String.fetchCursor(db, "SELECT 'bar' AS v UNION ALL SELECT 'foo' ORDER BY v")
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
                let cursor = try Int.fetchCursor(db, "SELECT 1 AS i UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 ORDER BY i")
                let odds = cursor.filter { $0 % 2 == 1 }
                XCTAssertEqual(try odds.next()!, 1)
                XCTAssertEqual(try odds.next()!, 3)
                XCTAssertTrue(try odds.next() == nil)
            }
        }
    }
    
    func testFlatMapOfSequence() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let cursor = try Int.fetchCursor(db, "SELECT 1 AS i UNION ALL SELECT 2 ORDER BY i")
                let ints = cursor.flatMap { AnySequence([$0, $0 + 1]) }
                XCTAssertEqual(try ints.next()!, 1)
                XCTAssertEqual(try ints.next()!, 2)
                XCTAssertEqual(try ints.next()!, 2)
                XCTAssertEqual(try ints.next()!, 3)
                XCTAssertTrue(try ints.next() == nil)
            }
        }
    }
    
    func testFlatMapOfCursor() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let cursor = try Int.fetchCursor(db, "SELECT 1 AS i UNION ALL SELECT 2 ORDER BY i")
                let ints = cursor.flatMap {
                    try Int.fetchCursor(db, "SELECT ? AS i UNION ALL SELECT ?+1 ORDER BY i", arguments: [$0, $0])
                }
                XCTAssertEqual(try ints.next()!, 1)
                XCTAssertEqual(try ints.next()!, 2)
                XCTAssertEqual(try ints.next()!, 2)
                XCTAssertEqual(try ints.next()!, 3)
                XCTAssertTrue(try ints.next() == nil)
            }
        }
    }
    
    func testSequenceFlatMapOfCursor() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let sequence = AnySequence([1, 2])
                let ints = sequence.flatMap {
                    try Int.fetchCursor(db, "SELECT ? AS i UNION ALL SELECT ?+1 ORDER BY i", arguments: [$0, $0])
                }
                XCTAssertEqual(try ints.next()!, 1)
                XCTAssertEqual(try ints.next()!, 2)
                XCTAssertEqual(try ints.next()!, 2)
                XCTAssertEqual(try ints.next()!, 3)
                XCTAssertTrue(try ints.next() == nil)
            }
        }
    }
    
    func testFlatMapOfOptional() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let cursor = try DatabaseValue.fetchCursor(db, "SELECT 'foo' UNION ALL SELECT 1")
                let ints = cursor.flatMap(Int.fromDatabaseValue)
                XCTAssertEqual(try ints.next()!, 1)
                XCTAssertTrue(try ints.next() == nil)
            }
        }
    }
    
    func testForEach() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let cursor = try Int.fetchCursor(db, "SELECT 1 AS i UNION ALL SELECT 2 ORDER BY i")
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
                let cursor = try Int.fetchCursor(db, "SELECT 1 AS i UNION ALL SELECT 2 ORDER BY i")
                let squares = cursor.map { $0 * $0 }
                XCTAssertEqual(try squares.next()!, 1)
                XCTAssertEqual(try squares.next()!, 4)
                XCTAssertTrue(try squares.next() == nil)
            }
        }
    }
    
    func testReduce() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let cursor = try Int.fetchCursor(db, "SELECT 1 AS i UNION ALL SELECT 2 ORDER BY i")
                let squareSum = try cursor.reduce(0) { (acc, int) in acc + int * int }
                XCTAssertEqual(squareSum, 5)
            }
        }
    }
}

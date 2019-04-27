import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private struct TestError : Error { }

class PrefixCursorTests: GRDBTestCase {
    
    func testPrefixCursorFromCursor() throws {
        do {
            let base = AnyCursor([1, 2, 3, 4, 5])
            let cursor = base.prefix(0)
            XCTAssertTrue(try cursor.next() == nil) // end
            XCTAssertTrue(try cursor.next() == nil) // past the end
        }
        do {
            let base = AnyCursor([1, 2, 3, 4, 5])
            let cursor = base.prefix(2)
            try XCTAssertEqual(cursor.next()!, 1)
            try XCTAssertEqual(cursor.next()!, 2)
            XCTAssertTrue(try cursor.next() == nil) // end
            XCTAssertTrue(try cursor.next() == nil) // past the end
        }
        do {
            let base = AnyCursor([1, 2, 3, 4, 5])
            let cursor = base.prefix(10)
            try XCTAssertEqual(cursor.next()!, 1)
            try XCTAssertEqual(cursor.next()!, 2)
            try XCTAssertEqual(cursor.next()!, 3)
            try XCTAssertEqual(cursor.next()!, 4)
            try XCTAssertEqual(cursor.next()!, 5)
            XCTAssertTrue(try cursor.next() == nil) // end
            XCTAssertTrue(try cursor.next() == nil) // past the end
        }
    }
    
    func testPrefixCursorFromThrowingCursor() throws {
        var i = 1
        let base: AnyCursor<Int> = AnyCursor {
            guard i < 3 else { throw TestError() }
            defer { i += 1 }
            return i
        }
        
        let cursor = base.prefix(3)
        try XCTAssertEqual(cursor.next()!, 1)
        try XCTAssertEqual(cursor.next()!, 2)
        do {
            _ = try cursor.next()
            XCTFail()
        } catch is TestError {
        } catch {
            XCTFail()
        }
    }
    
    func testPrefixCursorChain() throws {
        let base = AnyCursor([1, 2, 3, 4, 5])
        let cursor = base.prefix(2).prefix(1)
        try XCTAssertEqual(cursor.next()!, 1)
        XCTAssertTrue(try cursor.next() == nil) // end
        XCTAssertTrue(try cursor.next() == nil) // past the end
    }
}

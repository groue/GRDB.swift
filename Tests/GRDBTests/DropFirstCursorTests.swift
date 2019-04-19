import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private struct TestError : Error { }

class DropFirstCursorTests: GRDBTestCase {
    
    func testDropFirstCursorFromCursor() throws {
        do {
            let base = AnyCursor([1, 2, 3, 4, 5])
            let cursor = base.dropFirst(0)
            try XCTAssertEqual(cursor.next()!, 1)
            try XCTAssertEqual(cursor.next()!, 2)
            try XCTAssertEqual(cursor.next()!, 3)
            try XCTAssertEqual(cursor.next()!, 4)
            try XCTAssertEqual(cursor.next()!, 5)
            XCTAssertTrue(try cursor.next() == nil) // end
            XCTAssertTrue(try cursor.next() == nil) // past the end
        }
        do {
            let base = AnyCursor([1, 2, 3, 4, 5])
            let cursor = base.dropFirst(2)
            try XCTAssertEqual(cursor.next()!, 3)
            try XCTAssertEqual(cursor.next()!, 4)
            try XCTAssertEqual(cursor.next()!, 5)
            XCTAssertTrue(try cursor.next() == nil) // end
            XCTAssertTrue(try cursor.next() == nil) // past the end
        }
        do {
            let base = AnyCursor([1, 2, 3, 4, 5])
            let cursor = base.dropFirst(10)
            XCTAssertTrue(try cursor.next() == nil) // end
            XCTAssertTrue(try cursor.next() == nil) // past the end
        }
        do {
            let base = AnyCursor([1, 2, 3, 4, 5])
            let cursor = base.dropFirst()
            try XCTAssertEqual(cursor.next()!, 2)
            try XCTAssertEqual(cursor.next()!, 3)
            try XCTAssertEqual(cursor.next()!, 4)
            try XCTAssertEqual(cursor.next()!, 5)
            XCTAssertTrue(try cursor.next() == nil) // end
            XCTAssertTrue(try cursor.next() == nil) // past the end
        }
    }
    
    func testDropFirstCursorFromThrowingCursor() throws {
        var i = 1
        let base: AnyCursor<Int> = AnyCursor {
            guard i < 3 else { throw TestError() }
            defer { i += 1 }
            return i
        }

        let cursor = base.dropFirst(1)
        try XCTAssertEqual(cursor.next()!, 2)
        do {
            _ = try cursor.next()
            XCTFail()
        } catch is TestError {
        } catch {
            XCTFail()
        }
    }
    
    func testDropFirstChain() throws {
        let base = AnyCursor([1, 2, 3, 4, 5])
        let cursor = base.dropFirst(1).dropFirst(1)
        try XCTAssertEqual(cursor.next()!, 3)
        try XCTAssertEqual(cursor.next()!, 4)
        try XCTAssertEqual(cursor.next()!, 5)
        XCTAssertTrue(try cursor.next() == nil) // end
        XCTAssertTrue(try cursor.next() == nil) // past the end
    }
    
}

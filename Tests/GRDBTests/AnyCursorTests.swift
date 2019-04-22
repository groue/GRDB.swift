import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private struct TestError : Error { }

class AnyCursorTests: GRDBTestCase {
    
    func testAnyCursorFromClosure() {
        var i = 0
        let cursor: AnyCursor<Int> = AnyCursor {
            guard i < 2 else { return nil }
            defer { i += 1 }
            return i
        }
        XCTAssertEqual(try cursor.next()!, 0)
        XCTAssertEqual(try cursor.next()!, 1)
        XCTAssertTrue(try cursor.next() == nil) // end
    }
    
    func testAnyCursorFromThrowingClosure() {
        var i = 0
        let cursor: AnyCursor<Int> = AnyCursor {
            guard i < 2 else { throw TestError() }
            defer { i += 1 }
            return i
        }
        XCTAssertEqual(try cursor.next()!, 0)
        XCTAssertEqual(try cursor.next()!, 1)
        do {
            _ = try cursor.next()
            XCTFail()
        } catch is TestError {
        } catch {
            XCTFail()
        }
    }
    
    func testAnyCursorFromCursor() {
        let base = AnyCursor([0, 1])
        // This helper function makes sure AnyCursor initializer accepts any cursor,
        // and not only AnyCursor:
        func makeAnyCursor<C: Cursor>(_ cursor: C) -> AnyCursor<Int> where C.Element == Int {
            return AnyCursor(cursor)
        }
        let cursor = AnyCursor(base)
        XCTAssertEqual(try cursor.next()!, 0)
        XCTAssertEqual(try cursor.next()!, 1)
        XCTAssertTrue(try cursor.next() == nil) // end
    }
    
    func testAnyCursorFromThrowingCursor() {
        var i = 0
        let base: AnyCursor<Int> = AnyCursor {
            guard i < 2 else { throw TestError() }
            defer { i += 1 }
            return i
        }
        func makeAnyCursor<C: Cursor>(_ cursor: C) -> AnyCursor<Int> where C.Element == Int {
            return AnyCursor(cursor)
        }
        let cursor = makeAnyCursor(base)
        XCTAssertEqual(try cursor.next()!, 0)
        XCTAssertEqual(try cursor.next()!, 1)
        do {
            _ = try cursor.next()
            XCTFail()
        } catch is TestError {
        } catch {
            XCTFail()
        }
    }
    
    func testAnyCursorFromIterator() {
        let cursor = AnyCursor(iterator: [0, 1].makeIterator())
        XCTAssertEqual(try cursor.next()!, 0)
        XCTAssertEqual(try cursor.next()!, 1)
        XCTAssertTrue(try cursor.next() == nil) // end
        XCTAssertTrue(try cursor.next() == nil) // past the end
    }
    
    func testAnyCursorFromSequence() {
        let cursor = AnyCursor([0, 1])
        XCTAssertEqual(try cursor.next()!, 0)
        XCTAssertEqual(try cursor.next()!, 1)
        XCTAssertTrue(try cursor.next() == nil) // end
        XCTAssertTrue(try cursor.next() == nil) // past the end
    }
}

import XCTest
import GRDB

private struct TestError : Error { }

class EnumeratedCursorTests: GRDBTestCase {
    
    func testEnumeratedCursorFromCursor() throws {
        let base = AnyCursor(["foo", "bar"])
        let cursor = base.enumerated()
        var (n, x) = try cursor.next()!
        XCTAssertEqual(x, "foo")
        XCTAssertEqual(n, 0)
        (n, x) = try cursor.next()!
        XCTAssertEqual(x, "bar")
        XCTAssertEqual(n, 1)
        XCTAssertTrue(try cursor.next() == nil) // end
        XCTAssertTrue(try cursor.next() == nil) // past the end
    }
    
    func testEnumeratedCursorForEach() throws {
        // Test that enumerated().forEach() calls base.forEach().
        // This is important in order to prevent
        // <https://github.com/groue/GRDB.swift/issues/1124>
        class TestCursor: Cursor {
            func next() -> String? {
                fatalError("Must not be called during forEach")
            }
            
            func forEach(_ body: (String) throws -> Void) throws {
                try body("foo")
                try body("bar")
            }
        }
        
        let base = TestCursor()
        let cursor = base.enumerated()
        let elements = try Array(cursor)
        XCTAssertEqual(elements.count, 2)
        XCTAssertEqual(elements[0].0, 0)
        XCTAssertEqual(elements[0].1, "foo")
        XCTAssertEqual(elements[1].0, 1)
        XCTAssertEqual(elements[1].1, "bar")
    }
    
    func testEnumeratedCursorFromThrowingCursor() throws {
        var i = 0
        let strings = ["foo", "bar"]
        let base: AnyCursor<String> = AnyCursor {
            guard i < strings.count else { throw TestError() }
            defer { i += 1 }
            return strings[i]
        }
        let cursor = base.enumerated()
        var (n, x) = try cursor.next()!
        XCTAssertEqual(x, "foo")
        XCTAssertEqual(n, 0)
        (n, x) = try cursor.next()!
        XCTAssertEqual(x, "bar")
        XCTAssertEqual(n, 1)
        do {
            _ = try cursor.next()
            XCTFail()
        } catch is TestError {
        } catch {
            XCTFail()
        }
    }
}

import XCTest
import GRDB

private struct TestError : Error { }

class MapCursorTests: GRDBTestCase {
    
    func testMap() {
        let base = AnyCursor([1, 2])
        let cursor = base.map { $0 * $0 }
        XCTAssertEqual(try cursor.next()!, 1)
        XCTAssertEqual(try cursor.next()!, 4)
        XCTAssertTrue(try cursor.next() == nil)
    }
    
    func testMapCursorForEach() throws {
        // Test that map().forEach() calls base.forEach().
        // This is important in order to prevent
        // <https://github.com/groue/GRDB.swift/issues/1124>
        class TestCursor: Cursor {
            func next() -> Int? {
                fatalError("Must not be called during forEach")
            }
            
            func forEach(_ body: (Int) throws -> Void) throws {
                try body(1)
                try body(2)
            }
        }
        
        let base = TestCursor()
        let cursor = base.map { $0 * $0 }
        try XCTAssertEqual(Array(cursor), [1, 4])
    }
    
    func testMapThrowingCursor() {
        var i = 0
        let base: AnyCursor<Int> = AnyCursor {
            guard i < 1 else { throw TestError() }
            defer { i += 1 }
            return i
        }
        let cursor = base.map { $0 + 1 }
        XCTAssertEqual(try cursor.next()!, 1)
        do {
            _ = try cursor.next()
            XCTFail()
        } catch is TestError {
        } catch {
            XCTFail()
        }
    }
    
}

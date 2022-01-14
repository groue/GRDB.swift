import XCTest
import GRDB

private struct TestError : Error { }

class FilterCursorTests: GRDBTestCase {
    
    func testFilterCursorFromCursor() {
        let base = AnyCursor([1, 2, 3, 4])
        let cursor = base.filter { $0 % 2 == 0 }
        XCTAssertEqual(try cursor.next()!, 2)
        XCTAssertEqual(try cursor.next()!, 4)
        XCTAssertTrue(try cursor.next() == nil) // end
        XCTAssertTrue(try cursor.next() == nil) // past the end
    }
    
    func testFilterCursorForEach() throws {
        // Test that filter().forEach() calls base.forEach().
        // This is important in order to prevent
        // <https://github.com/groue/GRDB.swift/issues/1124>
        class TestCursor: Cursor {
            func next() -> Int? {
                fatalError("Must not be called during forEach")
            }
            
            func forEach(_ body: (Int) throws -> Void) throws {
                try body(1)
                try body(2)
                try body(3)
                try body(4)
            }
        }
        
        let base = TestCursor()
        let cursor = base.filter { $0 % 2 == 0 }
        try XCTAssertEqual(Array(cursor), [2, 4])
    }
    
    func testFilterCursorFromThrowingCursor() {
        var i = 0
        let base: AnyCursor<Int> = AnyCursor {
            guard i < 2 else { throw TestError() }
            defer { i += 1 }
            return i
        }
        let cursor = base.filter { $0 % 2 == 0 }
        XCTAssertEqual(try cursor.next()!, 0)
        do {
            _ = try cursor.next()
            XCTFail()
        } catch is TestError {
        } catch {
            XCTFail()
        }
    }
    
    func testThrowingFilterCursorFromCursor() {
        let base = AnyCursor([0, 1])
        let cursor = base.filter {
            if $0 > 0 { throw TestError() }
            return true
        }
        XCTAssertEqual(try cursor.next()!, 0)
        do {
            _ = try cursor.next()
            XCTFail()
        } catch is TestError {
        } catch {
            XCTFail()
        }
    }
}

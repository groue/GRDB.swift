import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

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

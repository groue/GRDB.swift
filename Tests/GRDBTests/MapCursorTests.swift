import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private struct TestError : Error { }

class MapCursorTests: GRDBTestCase {
    
    func testMap() {
        let base = AnyCursor([1, 2])
        let cursor = base.map { $0 * $0 }
        XCTAssertEqual(try cursor.next()!, 1)
        XCTAssertEqual(try cursor.next()!, 4)
        XCTAssertTrue(try cursor.next() == nil)
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

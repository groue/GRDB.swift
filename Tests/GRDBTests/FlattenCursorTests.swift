import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class FlattenCursorTests: GRDBTestCase {
    
    func testFlatMapOfSequence() {
        let cursor = AnyCursor([1, 2]).flatMap { [$0, $0+1] }
        XCTAssertEqual(try cursor.next()!, 1)
        XCTAssertEqual(try cursor.next()!, 2)
        XCTAssertEqual(try cursor.next()!, 2)
        XCTAssertEqual(try cursor.next()!, 3)
        XCTAssertTrue(try cursor.next() == nil) // end
        XCTAssertTrue(try cursor.next() == nil) // past the end
    }
    
    func testFlatMapOfCursor() {
        let cursor = AnyCursor([1, 2]).flatMap { AnyCursor([$0, $0+1]) }
        XCTAssertEqual(try cursor.next()!, 1)
        XCTAssertEqual(try cursor.next()!, 2)
        XCTAssertEqual(try cursor.next()!, 2)
        XCTAssertEqual(try cursor.next()!, 3)
        XCTAssertTrue(try cursor.next() == nil) // end
        XCTAssertTrue(try cursor.next() == nil) // past the end
    }
    
    func testSequenceFlatMapOfCursor() {
        let cursor = [1, 2].flatMap { AnyCursor([$0, $0+1]) }
        XCTAssertEqual(try cursor.next()!, 1)
        XCTAssertEqual(try cursor.next()!, 2)
        XCTAssertEqual(try cursor.next()!, 2)
        XCTAssertEqual(try cursor.next()!, 3)
        XCTAssertTrue(try cursor.next() == nil) // end
        XCTAssertTrue(try cursor.next() == nil) // past the end
    }
    
    func testJoinedSequences() {
        let cursor = AnyCursor([[1, 2], [2, 3]]).joined()
        XCTAssertEqual(try cursor.next()!, 1)
        XCTAssertEqual(try cursor.next()!, 2)
        XCTAssertEqual(try cursor.next()!, 2)
        XCTAssertEqual(try cursor.next()!, 3)
        XCTAssertTrue(try cursor.next() == nil) // end
        XCTAssertTrue(try cursor.next() == nil) // past the end
    }
    
    func testJoinedCursors() {
        let cursor = AnyCursor([AnyCursor([1, 2]), AnyCursor([2, 3])]).joined()
        XCTAssertEqual(try cursor.next()!, 1)
        XCTAssertEqual(try cursor.next()!, 2)
        XCTAssertEqual(try cursor.next()!, 2)
        XCTAssertEqual(try cursor.next()!, 3)
        XCTAssertTrue(try cursor.next() == nil) // end
        XCTAssertTrue(try cursor.next() == nil) // past the end
    }
    
}

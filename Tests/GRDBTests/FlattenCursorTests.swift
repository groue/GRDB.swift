import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class FlattenCursorTests: GRDBTestCase {
    
    func testFlatMapOfSequence() {
        let cursor = IteratorCursor([1, 2]).flatMap { [$0, $0+1] }
        XCTAssertEqual(try cursor.next()!, 1)
        XCTAssertEqual(try cursor.next()!, 2)
        XCTAssertEqual(try cursor.next()!, 2)
        XCTAssertEqual(try cursor.next()!, 3)
        XCTAssertTrue(try cursor.next() == nil) // end
        XCTAssertTrue(try cursor.next() == nil) // past the end
    }
    
    func testFlatMapOfCursor() {
        let cursor = IteratorCursor([1, 2]).flatMap { IteratorCursor([$0, $0+1]) }
        XCTAssertEqual(try cursor.next()!, 1)
        XCTAssertEqual(try cursor.next()!, 2)
        XCTAssertEqual(try cursor.next()!, 2)
        XCTAssertEqual(try cursor.next()!, 3)
        XCTAssertTrue(try cursor.next() == nil) // end
        XCTAssertTrue(try cursor.next() == nil) // past the end
    }
    
    func testSequenceFlatMapOfCursor() {
        let cursor = [1, 2].flatMap { IteratorCursor([$0, $0+1]) }
        XCTAssertEqual(try cursor.next()!, 1)
        XCTAssertEqual(try cursor.next()!, 2)
        XCTAssertEqual(try cursor.next()!, 2)
        XCTAssertEqual(try cursor.next()!, 3)
        XCTAssertTrue(try cursor.next() == nil) // end
        XCTAssertTrue(try cursor.next() == nil) // past the end
    }
    
    func testJoinedSequences() {
        let cursor = IteratorCursor([[1, 2], [2, 3]]).joined()
        XCTAssertEqual(try cursor.next()!, 1)
        XCTAssertEqual(try cursor.next()!, 2)
        XCTAssertEqual(try cursor.next()!, 2)
        XCTAssertEqual(try cursor.next()!, 3)
        XCTAssertTrue(try cursor.next() == nil) // end
        XCTAssertTrue(try cursor.next() == nil) // past the end
    }
    
    func testJoinedCursors() {
        let cursor = IteratorCursor([IteratorCursor([1, 2]), IteratorCursor([2, 3])]).joined()
        XCTAssertEqual(try cursor.next()!, 1)
        XCTAssertEqual(try cursor.next()!, 2)
        XCTAssertEqual(try cursor.next()!, 2)
        XCTAssertEqual(try cursor.next()!, 3)
        XCTAssertTrue(try cursor.next() == nil) // end
        XCTAssertTrue(try cursor.next() == nil) // past the end
    }
    
}

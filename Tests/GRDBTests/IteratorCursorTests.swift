import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class IteratorCursorTests: GRDBTestCase {
    
    func testIteratorCursorFromIterator() {
        let cursor = IteratorCursor([0, 1].makeIterator())
        XCTAssertEqual(cursor.next()!, 0)
        XCTAssertEqual(cursor.next()!, 1)
        XCTAssertTrue(cursor.next() == nil) // end
        XCTAssertTrue(cursor.next() == nil) // past the end
    }
    
    func testIteratorCursorFromSequence() {
        let cursor = IteratorCursor([0, 1])
        XCTAssertEqual(cursor.next()!, 0)
        XCTAssertEqual(cursor.next()!, 1)
        XCTAssertTrue(cursor.next() == nil) // end
        XCTAssertTrue(cursor.next() == nil) // past the end
    }
}

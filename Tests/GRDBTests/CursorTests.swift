import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private struct TestError : Error { }

class CursorTests: GRDBTestCase {
    
    func testContainsEquatable() {
        XCTAssertTrue(try IteratorCursor([1, 2]).contains(1))
        XCTAssertFalse(try IteratorCursor([1, 2]).contains(3))
    }
    
    func testContainsClosure() {
        XCTAssertTrue(try IteratorCursor([1, 2]).contains { $0 == 1 })
        XCTAssertFalse(try IteratorCursor([1, 2]).contains { $0 == 3 })
        do {
            _ = try IteratorCursor([1, 2]).contains { _ -> Bool in throw TestError() }
            XCTFail()
        } catch is TestError {
        } catch {
            XCTFail()
        }
    }
    
    func testContainsIsLazy() {
        func makeCursor() -> AnyCursor<Int> {
            var i = 0
            return AnyCursor {
                guard i < 1 else { throw TestError() }
                defer { i += 1 }
                return i
            }
        }
        XCTAssertTrue(try makeCursor().contains(0))
        do {
            _ = try makeCursor().contains(-1)
            XCTFail()
        } catch is TestError {
        } catch {
            XCTFail()
        }
    }
    
    func testFirst() {
        XCTAssertEqual(try IteratorCursor([1, 2]).first { $0 == 1 }!, 1)
        XCTAssertTrue(try IteratorCursor([1, 2]).first { $0 == 3 } == nil)
    }
    
    func testFirstIsLazy() {
        func makeCursor() -> AnyCursor<Int> {
            var i = 0
            return AnyCursor {
                guard i < 1 else { throw TestError() }
                defer { i += 1 }
                return i
            }
        }
        XCTAssertEqual(try makeCursor().first { $0 == 0 }!, 0)
        do {
            _ = try makeCursor().first { $0 == 1 }
            XCTFail()
        } catch is TestError {
        } catch {
            XCTFail()
        }
    }
    
    func testFlatMapOfOptional() {
        let cursor = IteratorCursor(["1", "foo", "2"]).flatMap { Int($0) }
        XCTAssertEqual(try cursor.next()!, 1)
        XCTAssertEqual(try cursor.next()!, 2)
        XCTAssertTrue(try cursor.next() == nil) // end
    }
    
    func testForEach() throws {
        let cursor = IteratorCursor([1, 2])
        var ints: [Int] = []
        try cursor.forEach { ints.append($0) }
        XCTAssertEqual(ints, [1, 2])
    }
    
    func testThrowingForEach() {
        var i = 0
        let cursor: AnyCursor<Int> = AnyCursor {
            guard i < 1 else { throw TestError() }
            defer { i += 1 }
            return i
        }
        var ints: [Int] = []
        do {
            try cursor.forEach { ints.append($0) }
            XCTFail()
        } catch is TestError {
            XCTAssertEqual(ints, [0])
        } catch {
            XCTFail()
        }
    }
    
    func testReduce() throws {
        let cursor = IteratorCursor([1, 2])
        let squareSum = try cursor.reduce(0) { (acc, int) in acc + int * int }
        XCTAssertEqual(squareSum, 5)
    }
}

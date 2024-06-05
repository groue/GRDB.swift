import XCTest
import GRDB

private struct TestError : Error { }

class CursorTests: GRDBTestCase {
    
    func testIsEmpty() {
        XCTAssertTrue(try AnyCursor([Int]()).isEmpty)
        XCTAssertFalse(try AnyCursor([1]).isEmpty)
    }
    
    func testContainsEquatable() {
        XCTAssertTrue(try AnyCursor([1, 2]).contains(1))
        XCTAssertTrue(try AnyCursor([1, 2]).contains(2))
        XCTAssertFalse(try AnyCursor([1, 2]).contains(3))
    }
    
    func testContainsClosure() {
        XCTAssertTrue(try AnyCursor([1, 2]).contains { $0 == 1 })
        XCTAssertTrue(try AnyCursor([1, 2]).contains { $0 == 2 })
        XCTAssertFalse(try AnyCursor([1, 2]).contains { $0 == 3 })
        do {
            _ = try AnyCursor([1, 2]).contains { _ -> Bool in throw TestError() }
            XCTFail()
        } catch is TestError {
        } catch {
            XCTFail()
        }
    }
    
    func testDropLast() {
        XCTAssertTrue(try AnyCursor([1, 2, 3, 4, 5]).dropLast(0) == [1, 2, 3, 4, 5])
        XCTAssertTrue(try AnyCursor([1, 2, 3, 4, 5]).dropLast(2) == [1, 2, 3])
        XCTAssertTrue(try AnyCursor([1, 2, 3, 4, 5]).dropLast(10) == [])
        XCTAssertTrue(try AnyCursor([1, 2, 3, 4, 5]).dropLast() == [1, 2, 3, 4])
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
        XCTAssertEqual(try AnyCursor([1, 2]).first { $0 == 1 }!, 1)
        XCTAssertTrue(try AnyCursor([1, 2]).first { $0 == 3 } == nil)
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
    
    func testCompactMap() {
        let cursor = AnyCursor(["1", "foo", "2"]).compactMap { Int($0) }
        XCTAssertEqual(try cursor.next()!, 1)
        XCTAssertEqual(try cursor.next()!, 2)
        XCTAssertTrue(try cursor.next() == nil) // end
    }
    
    func testForEach() throws {
        let cursor = AnyCursor([1, 2])
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
    
    func testJoinedWithSeparator() throws {
        do {
            let x = try AnyCursor([String]()).joined()
            XCTAssertEqual(x, "")
        }
        do {
            let x = try AnyCursor([String]()).joined(separator: "><")
            XCTAssertEqual(x, "")
        }
        do {
            let x = try AnyCursor(["foo"]).joined()
            XCTAssertEqual(x, "foo")
        }
        do {
            let x = try AnyCursor(["foo"]).joined(separator: "><")
            XCTAssertEqual(x, "foo")
        }
        do {
            let x = try AnyCursor(["foo", "bar", "baz"]).joined()
            XCTAssertEqual(x, "foobarbaz")
        }
        do {
            let x = try AnyCursor(["foo", "bar", "baz"]).joined(separator: "><")
            XCTAssertEqual(x, "foo><bar><baz")
        }
    }
    
    func testMax() {
        XCTAssertEqual(try AnyCursor([1, 2, 3]).max(), 3)
        XCTAssertEqual(try AnyCursor([1, 2, 3]).max(by: >), 1)
    }

    func testMin() {
        XCTAssertEqual(try AnyCursor([1, 2, 3]).min(), 1)
        XCTAssertEqual(try AnyCursor([1, 2, 3]).min(by: >), 3)
    }
    
    func testReduce() throws {
        let cursor = AnyCursor([1, 2])
        let squareSum = try cursor.reduce(0) { (acc, int) in acc + int * int }
        XCTAssertEqual(squareSum, 5)
    }
    
    func testReduceInto() throws {
        let cursor = AnyCursor([1, 2])
        let squareSum = try cursor.reduce(into: 0) { (acc, int) in acc += int * int }
        XCTAssertEqual(squareSum, 5)
    }

    func testSuffix() throws {
        do {
            let cursor = AnyCursor([1, 2, 3, 4, 5])
            let suffix = try cursor.suffix(0)
            XCTAssertTrue(suffix == [])
        }
        do {
            let cursor = AnyCursor([1, 2, 3, 4, 5])
            let suffix = try cursor.suffix(2)
            XCTAssertTrue(suffix == [4, 5])
        }
        do {
            let cursor = AnyCursor([1, 2, 3, 4, 5])
            let suffix = try cursor.suffix(10)
            XCTAssertTrue(suffix == [1, 2, 3, 4, 5])
        }
    }
    
    func testRangeReplaceableCollection() throws {
        func collect<Col, Cur>(_ cursor: Cur) throws -> Col
        where Col: RangeReplaceableCollection, Cur: Cursor, Col.Element == Cur.Element
        {
            try Col(cursor)
        }
        
        func collect<Col, Cur>(_ cursor: Cur, minimumCapacity: Int) throws -> Col
        where Col: RangeReplaceableCollection, Cur: Cursor, Col.Element == Cur.Element
        {
            try Col(cursor, minimumCapacity: minimumCapacity)
        }
        
        do {
            let cursor = AnyCursor([1, 2, 1, 3])
            let collection: [Int] = try collect(cursor)
            XCTAssertEqual(collection, [1, 2, 1, 3])
        }
        
        do {
            let cursor = AnyCursor([1, 2, 1, 3])
            let collection: [Int] = try collect(cursor, minimumCapacity: 100)
            XCTAssertEqual(collection, [1, 2, 1, 3])
        }
        
        do {
            let cursor = AnyCursor([1, 2, 1, 3])
            var collection = [0, 4]
            try collection.append(contentsOf: cursor)
            XCTAssertEqual(collection, [0, 4, 1, 2, 1, 3])
        }
    }
    
    func testSet() throws {
        do {
            let cursor = AnyCursor([1, 2, 1, 3])
            let set = try Set(cursor)
            XCTAssertEqual(set, [1, 2, 3])
        }
        
        do {
            let cursor = AnyCursor([1, 2, 1, 3])
            let set = try Set(cursor, minimumCapacity: 100)
            XCTAssertEqual(set, [1, 2, 3])
        }
        
        do {
            let cursor = AnyCursor([1, 2, 1, 3])
            let set: Set<Int> = [1, 4]
            try XCTAssertEqual(set.union(cursor), [1, 2, 3, 4])
        }
        
        do {
            let cursor = AnyCursor([1, 2, 1, 3])
            var set: Set<Int> = [1, 4]
            try set.formUnion(cursor)
            XCTAssertEqual(set, [1, 2, 3, 4])
        }
        
        do {
            let cursor = AnyCursor([1, 2, 1, 3])
            let set: Set<Int> = [1, 3, 4]
            try XCTAssertEqual(set.intersection(cursor), [1, 3])
        }
        
        do {
            let cursor = AnyCursor([1, 2, 1, 3])
            var set: Set<Int> = [1, 3, 4]
            try set.formIntersection(cursor)
            XCTAssertEqual(set, [1, 3])
        }
    }
    
    func testDictionaryGrouping() throws {
        do {
            let cursor = AnyCursor<Int>([])
            let dictionary = try Dictionary(grouping: cursor, by: { $0 % 2 })
            XCTAssertEqual(dictionary, [:])
        }
        do {
            let cursor = AnyCursor([1, 2, 3, 4, 5])
            let dictionary = try Dictionary(grouping: cursor, by: { $0 % 2 })
            XCTAssertEqual(dictionary, [0: [2, 4], 1: [1, 3, 5]])
        }
        do {
            let cursor = AnyCursor([5, 4, 3, 2, 1])
            let dictionary = try Dictionary(grouping: cursor, by: { $0 % 2 })
            XCTAssertEqual(dictionary, [0: [4, 2], 1: [5, 3, 1]])
        }
        do {
            let cursor = AnyCursor<Int>([1, 2, 3, 4, 5])
            let dictionary = try Dictionary(minimumCapacity: 100, grouping: cursor, by: { $0 % 2 })
            XCTAssertEqual(dictionary, [0: [2, 4], 1: [1, 3, 5]])
        }
    }
    
    func testDictionaryUniqueKeysWithValues() throws {
        do {
            let cursor = AnyCursor([(1, "a"), (2, "b"), (3, "a")])
            let dictionary = try Dictionary(uniqueKeysWithValues: cursor)
            XCTAssertEqual(dictionary, [1: "a", 2: "b", 3: "a"])
        }
        do {
            let cursor = AnyCursor([(1, "a"), (2, "b"), (3, "a")])
            let dictionary = try Dictionary(minimumCapacity: 100, uniqueKeysWithValues: cursor)
            XCTAssertEqual(dictionary, [1: "a", 2: "b", 3: "a"])
        }
    }
    
    func testArrayInitializer() throws {
        // Test that Array initializer calls `forEach`.
        // This is important in order to prevent
        // <https://github.com/groue/GRDB.swift/issues/1124>
        class TestCursor: Cursor {
            func next() -> Int? {
                fatalError("Must not be called during Array creation")
            }
            
            func forEach(_ body: (Int) throws -> Void) throws {
                try body(0)
                try body(1)
            }
        }
        
        let cursor = TestCursor()
        let elements = try Array(cursor)
        XCTAssertEqual(elements, [0, 1])
    }
}

import XCTest
@testable import GRDB

class PoolTests: XCTestCase {
    /// Returns a Pool whose elements are incremented integers: 1, 2, 3...
    private func makeCounterPool(maximumCount: Int) -> Pool<Int> {
        let countMutex = Mutex(0)
        return Pool(maximumCount: maximumCount, makeElement: { _ in
            countMutex.increment()
        })
    }
    
    func testElementsAreReused() throws {
        let pool = makeCounterPool(maximumCount: 2)
        
        // Get and release element
        let first = try pool.get()
        XCTAssertEqual(first.element, 1)
        first.release(.reuse)
        
        // Get recycled element
        let second = try pool.get()
        XCTAssertEqual(second.element, 1)
        
        // Get new element
        let third = try pool.get()
        XCTAssertEqual(third.element, 2)
        
        // Reuse elements
        second.release(.reuse)
        third.release(.reuse)
        
        // Get and release recycled elements
        let fourth = try pool.get()
        XCTAssertEqual(fourth.element, 1)
        let fifth = try pool.get()
        XCTAssertEqual(fifth.element, 2)
        fourth.release(.reuse)
        fifth.release(.reuse)
    }
    
    func testElementsCanBeDiscarded() throws {
        let pool = makeCounterPool(maximumCount: 2)
        
        // Get and release element
        let first = try pool.get()
        XCTAssertEqual(first.element, 1)
        first.release(.reuse)
        
        // Get recycled element
        let second = try pool.get()
        XCTAssertEqual(second.element, 1)
        
        // Get new element
        let third = try pool.get()
        XCTAssertEqual(third.element, 2)
        
        // Reuse second, discard third
        second.release(.reuse)
        third.release(.discard)
        
        // Get and release recycled elements
        let fourth = try pool.get()
        XCTAssertEqual(fourth.element, 1)
        let fifth = try pool.get()
        XCTAssertEqual(fifth.element, 3)
        fourth.release(.reuse)
        fifth.release(.reuse)
    }
    
    func testRemoveAll() throws {
        let pool = makeCounterPool(maximumCount: 2)
        
        // Get elements
        let first = try pool.get()
        XCTAssertEqual(first.element, 1)
        let second = try pool.get()
        XCTAssertEqual(second.element, 2)
        
        // removeAll is not locked by used elements
        pool.removeAll()
        
        // Reuse elements
        first.release(.reuse)
        second.release(.reuse)
        
        // Get and release new elements
        let third = try pool.get()
        XCTAssertEqual(third.element, 3)
        let fourth = try pool.get()
        XCTAssertEqual(fourth.element, 4)
        third.release(.reuse)
        fourth.release(.reuse)
    }
    
    func testBarrierLocksElements() throws {
        let expectation = self.expectation(description: "lock")
        expectation.isInverted = true
        
        let pool = makeCounterPool(maximumCount: 1)
        var element: Int?
        let s1 = DispatchSemaphore(value: 0)
        let s2 = DispatchSemaphore(value: 0)
        let s3 = DispatchSemaphore(value: 0)
        
        DispatchQueue.global().async {
            pool.barrier {
                s1.signal()
                s2.wait()
            }
        }
        
        DispatchQueue.global().async {
            // Wait for barrier to start
            s1.wait()
            
            let first = try! pool.get()
            element = first.element
            first.release(.reuse)
            expectation.fulfill()
            s3.signal()
        }
        
        // Assert that get() is blocked
        waitForExpectations(timeout: 1)
        
        // Reuse barrier
        s2.signal()
        
        // Wait for get() to complete
        s3.wait()
        XCTAssertEqual(element, 1)
    }
    
    func testBarrierIsLockedByOneUsedElementOutOfOne() throws {
        let expectation = self.expectation(description: "lock")
        expectation.isInverted = true
        
        let pool = makeCounterPool(maximumCount: 1)
        
        // Get element
        let first = try pool.get()
        XCTAssertEqual(first.element, 1)
        
        let s = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            pool.barrier { }
            expectation.fulfill()
            s.signal()
        }
        
        // Assert that barrier is blocked
        waitForExpectations(timeout: 1)
        
        // Reuse element
        first.release(.reuse)
        
        // Wait for barrier to complete
        s.wait()
        
        // Get and release recycled element
        let second = try pool.get()
        XCTAssertEqual(second.element, 1)
        second.release(.reuse)
    }
    
    func testBarrierIsLockedByOneUsedElementOutOfTwo() throws {
        let expectation = self.expectation(description: "lock")
        expectation.isInverted = true
        
        let pool = makeCounterPool(maximumCount: 2)
        
        // Get elements
        let first = try pool.get()
        XCTAssertEqual(first.element, 1)
        let second = try pool.get()
        XCTAssertEqual(second.element, 2)
        
        // Reuse first element
        first.release(.reuse)
        
        let s = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            pool.barrier { }
            expectation.fulfill()
            s.signal()
        }
        
        // Assert that barrier is blocked
        waitForExpectations(timeout: 1)
        
        // Reuse second element
        second.release(.reuse)
        
        // Wait for barrier to complete
        s.wait()
        
        // Get and release recycled element
        let third = try pool.get()
        XCTAssertEqual(third.element, 1)
        third.release(.reuse)
    }
    
    func testBarrierIsLockedByTwoUsedElementsOutOfTwo() throws {
        let expectation = self.expectation(description: "lock")
        expectation.isInverted = true
        
        let pool = makeCounterPool(maximumCount: 2)
        
        // Get elements
        let first = try pool.get()
        XCTAssertEqual(first.element, 1)
        let second = try pool.get()
        XCTAssertEqual(second.element, 2)
        
        let s = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            pool.barrier { }
            expectation.fulfill()
            s.signal()
        }
        
        // Assert that barrier is blocked
        waitForExpectations(timeout: 1)
        
        // Reuse elements
        first.release(.reuse)
        second.release(.reuse)
        
        // Wait for barrier to complete
        s.wait()
        
        // Get and release recycled element
        let third = try pool.get()
        XCTAssertEqual(third.element, 1)
        third.release(.reuse)
    }

    func testBarrierRemoveAll() throws {
        let expectation = self.expectation(description: "lock")
        expectation.isInverted = true
        
        let pool = makeCounterPool(maximumCount: 1)
        
        // Get element
        let first = try pool.get()
        XCTAssertEqual(first.element, 1)
        
        let s = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            // No deadlock
            pool.barrier { pool.removeAll() }
            expectation.fulfill()
            s.signal()
        }
        
        // Assert that barrier is blocked
        waitForExpectations(timeout: 1)
        
        // Reuse element
        first.release(.reuse)
        
        // Wait for barrier to complete
        s.wait()
        
        // Get and release new element
        let second = try pool.get()
        XCTAssertEqual(second.element, 2)
        second.release(.reuse)
    }
}

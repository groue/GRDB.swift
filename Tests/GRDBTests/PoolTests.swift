import XCTest
#if GRDBCUSTOMSQLITE
@testable import GRDBCustomSQLite
#else
@testable import GRDB
#endif

class PoolTests: XCTestCase {
    /// Returns a Pool whose elements are incremented integers: 1, 2, 3...
    private func makeCounterPool(maximumCount: Int) -> Pool<Int> {
        let count = ReadWriteBox(value: 0)
        return Pool(maximumCount: maximumCount, makeElement: count.increment)
    }
    
    func testElementsAreReused() throws {
        let pool = makeCounterPool(maximumCount: 2)
        
        // Get and release element
        let first = try pool.get()
        XCTAssertEqual(first.element, 1)
        first.release()
        
        // Get recycled element
        let second = try pool.get()
        XCTAssertEqual(second.element, 1)
        
        // Get new element
        let third = try pool.get()
        XCTAssertEqual(third.element, 2)
        
        // Release elements
        second.release()
        third.release()
        
        // Get and release recycled elements
        let fourth = try pool.get()
        XCTAssertEqual(fourth.element, 1)
        let fifth = try pool.get()
        XCTAssertEqual(fifth.element, 2)
        fourth.release()
        fifth.release()
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
        
        // Release elements
        first.release()
        second.release()
        
        // Get and release new elements
        let third = try pool.get()
        XCTAssertEqual(third.element, 3)
        let fourth = try pool.get()
        XCTAssertEqual(fourth.element, 4)
        third.release()
        fourth.release()
    }
    
    func testBarrierLocksElements() throws {
        if #available(OSX 10.10, *) {
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
                first.release()
                expectation.fulfill()
                s3.signal()
            }
            
            // Assert that get() is blocked
            waitForExpectations(timeout: 1)
            
            // Release barrier
            s2.signal()
            
            // Wait for get() to complete
            s3.wait()
            XCTAssertEqual(element, 1)
        }
    }
    
    func testBarrierIsLockedByOneUsedElementOutOfOne() throws {
        if #available(OSX 10.10, *) {
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
            
            // Release element
            first.release()
            
            // Wait for barrier to complete
            s.wait()
            
            // Get and release recycled element
            let second = try pool.get()
            XCTAssertEqual(second.element, 1)
            second.release()
        }
    }
    
    func testBarrierIsLockedByOneUsedElementOutOfTwo() throws {
        if #available(OSX 10.10, *) {
            let expectation = self.expectation(description: "lock")
            expectation.isInverted = true
            
            let pool = makeCounterPool(maximumCount: 2)
            
            // Get elements
            let first = try pool.get()
            XCTAssertEqual(first.element, 1)
            let second = try pool.get()
            XCTAssertEqual(second.element, 2)
            
            // Release first element
            first.release()
            
            let s = DispatchSemaphore(value: 0)
            DispatchQueue.global().async {
                pool.barrier { }
                expectation.fulfill()
                s.signal()
            }
            
            // Assert that barrier is blocked
            waitForExpectations(timeout: 1)
            
            // Release second element
            second.release()
            
            // Wait for barrier to complete
            s.wait()
            
            // Get and release recycled element
            let third = try pool.get()
            XCTAssertEqual(third.element, 1)
            third.release()
        }
    }
    
    func testBarrierIsLockedByTwoUsedElementsOutOfTwo() throws {
        if #available(OSX 10.10, *) {
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
            
            // Release elements
            first.release()
            second.release()
            
            // Wait for barrier to complete
            s.wait()
            
            // Get and release recycled element
            let third = try pool.get()
            XCTAssertEqual(third.element, 1)
            third.release()
        }
    }

    func testBarrierRemoveAll() throws {
        if #available(OSX 10.10, *) {
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
            
            // Release element
            first.release()
            
            // Wait for barrier to complete
            s.wait()
            
            // Get and release new element
            let second = try pool.get()
            XCTAssertEqual(second.element, 2)
            second.release()
        }
    }
}

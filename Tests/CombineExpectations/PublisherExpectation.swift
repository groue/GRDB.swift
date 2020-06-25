#if canImport(Combine)
import XCTest

/// A name space for publisher expectations
public enum PublisherExpectations { }

/// The base protocol for PublisherExpectation. It is an implementation detail
/// that you are not supposed to use, as shown by the underscore prefix.
public protocol _PublisherExpectationBase {
    /// Sets up an XCTestExpectation. This method is an implementation detail
    /// that you are not supposed to use, as shown by the underscore prefix.
    func _setup(_ expectation: XCTestExpectation)
}

/// The protocol for publisher expectations.
///
/// You can build publisher expectations from Recorder returned by the
/// `Publisher.record()` method.
///
/// For example:
///
///     // The expectation for all published elements until completion
///     let publisher = ["foo", "bar", "baz"].publisher
///     let recorder = publisher.record()
///     let expectation = recorder.elements
///
/// When a test grants some time for the expectation to fulfill, use the
/// XCTest `wait(for:timeout:description)` method:
///
///     // SUCCESS: no timeout, no error
///     func testArrayPublisherPublishesArrayElements() throws {
///         let publisher = ["foo", "bar", "baz"].publisher
///         let recorder = publisher.record()
///         let expectation = recorder.elements
///         let elements = try wait(for: expectation, timeout: 1)
///         XCTAssertEqual(elements, ["foo", "bar", "baz"])
///     }
///
/// On the other hand, when the expectation is supposed to be immediately
/// fulfilled, use the PublisherExpectation `get()` method in order to grab the
/// expected value:
///
///     // SUCCESS: no error
///     func testArrayPublisherSynchronouslyPublishesArrayElements() throws {
///         let publisher = ["foo", "bar", "baz"].publisher
///         let recorder = publisher.record()
///         let elements = try recorder.elements.get()
///         XCTAssertEqual(elements, ["foo", "bar", "baz"])
///     }
public protocol PublisherExpectation: _PublisherExpectationBase {
    /// The type of the expected value.
    associatedtype Output
    
    /// Returns the expected value, or throws an error if the
    /// expectation fails.
    ///
    /// For example:
    ///
    ///     // SUCCESS: no error
    ///     func testArrayPublisherSynchronouslyPublishesArrayElements() throws {
    ///         let publisher = ["foo", "bar", "baz"].publisher
    ///         let recorder = publisher.record()
    ///         let elements = try recorder.elements.get()
    ///         XCTAssertEqual(elements, ["foo", "bar", "baz"])
    ///     }
    func get() throws -> Output
}

extension XCTestCase {
    /// Waits for the publisher expectation to fulfill, and returns the
    /// expected value.
    ///
    /// For example:
    ///
    ///     // SUCCESS: no timeout, no error
    ///     func testArrayPublisherPublishesArrayElements() throws {
    ///         let publisher = ["foo", "bar", "baz"].publisher
    ///         let recorder = publisher.record()
    ///         let elements = try wait(for: recorder.elements, timeout: 1)
    ///         XCTAssertEqual(elements, ["foo", "bar", "baz"])
    ///     }
    ///
    /// - parameter publisherExpectation: The publisher expectation.
    /// - parameter timeout: The number of seconds within which the expectation
    ///   must be fulfilled.
    /// - parameter description: A string to display in the test log for the
    ///   expectation, to help diagnose failures.
    /// - throws: An error if the expectation fails.
    public func wait<R: PublisherExpectation>(
        for publisherExpectation: R,
        timeout: TimeInterval,
        description: String = "")
        throws -> R.Output
    {
        let expectation = self.expectation(description: description)
        publisherExpectation._setup(expectation)
        wait(for: [expectation], timeout: timeout)
        return try publisherExpectation.get()
    }
}
#endif

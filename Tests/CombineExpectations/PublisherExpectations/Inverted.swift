#if canImport(Combine)
import XCTest

@available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension PublisherExpectations {
    /// A publisher expectation that fails if the base expectation is fulfilled.
    ///
    /// When waiting for this expectation, you receive the same result and
    /// eventual error as the base expectation.
    ///
    /// For example:
    ///
    ///     // SUCCESS: no timeout, no error
    ///     func testPassthroughSubjectDoesNotFinish() throws {
    ///         let publisher = PassthroughSubject<String, Never>()
    ///         let recorder = publisher.record()
    ///         try wait(for: recorder.finished.inverted, timeout: 1)
    ///     }
    public struct Inverted<Base: PublisherExpectation>: PublisherExpectation {
        let base: Base
        
        public func _setup(_ expectation: XCTestExpectation) {
            base._setup(expectation)
            expectation.isInverted.toggle()
        }
        
        public func get() throws -> Base.Output {
            try base.get()
        }
    }
}
#endif

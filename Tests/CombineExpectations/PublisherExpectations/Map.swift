#if canImport(Combine)
import XCTest

@available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension PublisherExpectations {
    /// A publisher expectation that transforms the value of a base expectation.
    ///
    /// This expectation has no public initializer.
    public struct Map<Base: PublisherExpectation, Output>: PublisherExpectation {
        let base: Base
        let transform: (Base.Output) throws -> Output
        
        public func _setup(_ expectation: XCTestExpectation) {
            base._setup(expectation)
        }
        
        public func get() throws -> Output {
            try transform(base.get())
        }
    }
}

@available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension PublisherExpectation {
    /// Returns a publisher expectation that transforms the value of the
    /// base expectation.
    func map<T>(_ transform: @escaping (Output) throws -> T) -> PublisherExpectations.Map<Self, T> {
        PublisherExpectations.Map(base: self, transform: transform)
    }
}
#endif

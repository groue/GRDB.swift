/// Represents the value that identified for differentiate.
public protocol ContentIdentifiable {
    /// A type representing the identifier.
    associatedtype DifferenceIdentifier: Hashable

    /// An identifier value for difference calculation.
    var differenceIdentifier: DifferenceIdentifier { get }
}

extension ContentIdentifiable where Self: Hashable {
    /// The `self` value as an identifier for difference calculation.
    @inlinable public var differenceIdentifier: Self {
        return self
    }
}

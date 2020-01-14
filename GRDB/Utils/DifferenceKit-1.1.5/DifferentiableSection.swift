/// Represents the section of collection that can be identified and compared to whether has updated.
public protocol DifferentiableSection: Differentiable {
    /// A type representing the elements in section.
    associatedtype Collection: Swift.Collection where Collection.Element: Differentiable

    /// The collection of element in the section.
    var elements: Collection { get }

    /// Creates a new section reproducing the given source section with replacing the elements.
    ///
    /// - Parameters:
    ///   - source: A source section to reproduce.
    ///   - elements: The collection of elements for the new section.
    init<C: Swift.Collection>(source: Self, elements: C) where C.Element == Collection.Element
}

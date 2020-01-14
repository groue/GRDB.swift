/// Represents the path to a specific element in a tree of nested collections.
///
/// - Note: `Foundation.IndexPath` is disadvantageous in performance.
public struct ElementPath: Hashable {
    /// The element index (or offset) of this path.
    public var element: Int
    /// The section index (or offset) of this path.
    public var section: Int

    /// Creates a new `ElementPath`.
    ///
    /// - Parameters:
    ///   - element: The element index (or offset).
    ///   - section: The section index (or offset).
    public init(element: Int, section: Int) {
        self.element = element
        self.section = section
    }
}

extension ElementPath: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "[element: \(element), section: \(section)]"
    }
}

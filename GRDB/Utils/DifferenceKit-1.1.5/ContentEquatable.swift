/// Represents a value that can compare whether the content are equal.
public protocol ContentEquatable {
    /// Indicate whether the content of `self` is equals to the content of
    /// the given source value.
    ///
    /// - Parameters:
    ///   - source: A source value to be compared.
    ///
    /// - Returns: A Boolean value indicating whether the content of `self` is equals
    ///            to the content of the given source value.
    func isContentEqual(to source: Self) -> Bool
}

public extension ContentEquatable where Self: Equatable {
    /// Indicate whether the content of `self` is equals to the content of the given source value.
    /// Compared using `==` operator of `Equatable'.
    ///
    /// - Parameters:
    ///   - source: A source value to be compared.
    ///
    /// - Returns: A Boolean value indicating whether the content of `self` is equals
    ///            to the content of the given source value.
    @inlinable
    func isContentEqual(to source: Self) -> Bool {
        return self == source
    }
}

extension Optional: ContentEquatable where Wrapped: ContentEquatable {
    /// Indicate whether the content of `self` is equals to the content of the given source value.
    /// Returns `true` if both values compared are nil.
    /// The result of comparison between nil and non-nil values is `false`.
    ///
    /// - Parameters:
    ///   - source: An optional source value to be compared.
    ///
    /// - Returns: A Boolean value indicating whether the content of `self` is equals
    ///            to the content of the given source value.
    @inlinable
    public func isContentEqual(to source: Wrapped?) -> Bool {
        switch (self, source) {
        case let (lhs?, rhs?):
            return lhs.isContentEqual(to: rhs)

        case (.none, .none):
            return true

        case (.none, .some), (.some, .none):
            return false
        }
    }
}

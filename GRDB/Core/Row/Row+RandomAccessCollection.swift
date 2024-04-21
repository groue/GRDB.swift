extension Row: RandomAccessCollection {
    public var startIndex: Index { Index(0) }
    
    public var endIndex: Index { Index(count) }
    
    /// Returns the (column, value) pair at given index.
    public subscript(position: Index) -> (String, DatabaseValue) {
        let index = position.index
        _checkIndex(index)
        return (
            impl.columnName(atUncheckedIndex: index),
            impl.databaseValue(atUncheckedIndex: index))
    }
}

// MARK: - Index

@available(*, deprecated, renamed: "Row.Index")
typealias RowIndex = Row.Index

extension Row {
    /// An index to a (column, value) pair in a ``Row``.
    public struct Index: Sendable {
        let index: Int
        init(_ index: Int) { self.index = index }
    }
}

extension Row.Index: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.index == rhs.index
    }
}

extension Row.Index: Comparable {
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.index < rhs.index
    }
}

extension Row.Index: Strideable {
    public func distance(to other: Self) -> Int {
        other.index - index
    }
    
    public func advanced(by n: Int) -> Self {
        Row.Index(index + n)
    }
}

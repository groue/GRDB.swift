extension Array {
    /// Creates an array containing the elements of a cursor.
    ///
    ///     let cursor = try String.fetchCursor(db, "SELECT 'foo' UNION ALL SELECT 'bar'")
    ///     let strings = try Array(cursor) // ["foo", "bar"]
    public init<C: Cursor>(_ cursor: C) throws where C.Element == Element {
        self.init()
        while let element = try cursor.next() {
            append(element)
        }
    }
}

extension Set {
    /// Creates a set containing the elements of a cursor.
    ///
    ///     let cursor = try String.fetchCursor(db, "SELECT 'foo' UNION ALL SELECT 'foo'")
    ///     let strings = try Set(cursor) // ["foo"]
    public init<C: Cursor>(_ cursor: C) throws where C.Element == Element {
        self.init()
        while let element = try cursor.next() {
            insert(element)
        }
    }
}

/// A type that supplies the values of some external resource, one at a time.
///
/// ## Overview
///
/// The most common way to iterate over the elements of a cursor is to use a
/// `while` loop:
///
///     let cursor = ...
///     while let element = try cursor.next() {
///         ...
///     }
///
/// ## Relationship with standard Sequence and IteratorProtocol
///
/// Cursors share traits with lazy sequences and iterators from the Swift
/// standard library. Differences are:
///
/// - Cursor types are classes, and have a lifetime.
/// - Cursor iteration may throw errors.
/// - A cursor can not be repeated.
///
/// The protocol comes with default implementations for many operations similar
/// to those defined by Swift's LazySequenceProtocol:
///
/// - `func contains(Self.Element)`
/// - `func contains(where: (Self.Element) throws -> Bool)`
/// - `func enumerated()`
/// - `func filter((Self.Element) throws -> Bool)`
/// - `func first(where: (Self.Element) throws -> Bool)`
/// - `func flatMap<ElementOfResult>((Self.Element) throws -> ElementOfResult?)`
/// - `func flatMap<SegmentOfResult>((Self.Element) throws -> SegmentOfResult)`
/// - `func forEach((Self.Element) throws -> Void)`
/// - `func joined()`
/// - `func map<T>((Self.Element) throws -> T)`
/// - `func reduce<Result>(Result, (Result, Self.Element) throws -> Result)`
public protocol Cursor : class {
    /// The type of element traversed by the cursor.
    associatedtype Element
    
    /// Advances to the next element and returns it, or nil if no next element
    /// exists. Once nil has been returned, all subsequent calls return nil.
    func next() throws -> Element?
}

/// A type-erased cursor of Element.
///
/// This cursor forwards its next() method to an arbitrary underlying cursor
/// having the same Element type, hiding the specifics of the underlying
/// cursor.
public class AnyCursor<Element> : Cursor {
    /// Creates a cursor that wraps a base cursor but whose type depends only on
    /// the base cursor’s element type
    public init<C: Cursor>(_ base: C) where C.Element == Element {
        element = base.next
    }
    
    /// Creates a cursor that wraps the given closure in its next() method
    public init(_ body: @escaping () throws -> Element?) {
        element = body
    }
    
    /// Advances to the next element and returns it, or nil if no next
    /// element exists.
    public func next() throws -> Element? {
        return try element()
    }
    
    private let element: () throws -> Element?
}

extension Cursor {
    /// Returns a Boolean value indicating whether the cursor contains an
    /// element that satisfies the given predicate.
    ///
    /// - parameter predicate: A closure that takes an element of the cursor as
    ///   its argument and returns a Boolean value that indicates whether the
    ///   passed element represents a match.
    /// - returns: true if the cursor contains an element that satisfies
    ///   predicate; otherwise, false.
    public func contains(where predicate: (Element) throws -> Bool) throws -> Bool {
        while let element = try next() {
            if try predicate(element) {
                return true
            }
        }
        return false
    }
    
    /// Returns a cursor of pairs (n, x), where n represents a consecutive
    /// integer starting at zero, and x represents an element of the cursor.
    ///
    ///     let cursor = try String.fetchCursor(db, "SELECT 'foo' UNION ALL SELECT 'bar'")
    ///     let c = cursor.enumerated()
    ///     while let (n, x) = c.next() {
    ///         print("\(n): \(x)")
    ///     }
    ///     // Prints: "0: foo"
    ///     // Prints: "1: bar"
    public func enumerated() -> EnumeratedCursor<Self> {
        return EnumeratedCursor(self)
    }
    
    /// Returns the elements of the cursor that satisfy the given predicate.
    public func filter(_ isIncluded: @escaping (Element) throws -> Bool) -> FilterCursor<Self> {
        return FilterCursor(self, isIncluded)
    }
    
    /// Returns the first element of the cursor that satisfies the given
    /// predicate or nil if no such element is found.
    public func first(where predicate: (Element) throws -> Bool) throws -> Element? {
        while let element = try next() {
            if try predicate(element) {
                return element
            }
        }
        return nil
    }
    
    /// Returns a cursor over the concatenated non-nil results of mapping
    /// transform over this cursor.
    public func flatMap<ElementOfResult>(_ transform: @escaping (Element) throws -> ElementOfResult?) -> MapCursor<FilterCursor<MapCursor<Self, ElementOfResult?>>, ElementOfResult> {
        return map(transform).filter { $0 != nil }.map { $0! }
    }
    
    /// Returns a cursor over the concatenated results of mapping transform
    /// over self.
    public func flatMap<SegmentOfResult: Sequence>(_ transform: @escaping (Element) throws -> SegmentOfResult) -> FlattenCursor<MapCursor<Self, IteratorCursor<SegmentOfResult.Iterator>>> {
        return flatMap { try IteratorCursor(transform($0)) }
    }
    
    /// Returns a cursor over the concatenated results of mapping transform
    /// over self.
    public func flatMap<SegmentOfResult: Cursor>(_ transform: @escaping (Element) throws -> SegmentOfResult) -> FlattenCursor<MapCursor<Self, SegmentOfResult>> {
        return map(transform).joined()
    }
    
    /// Calls the given closure on each element in the cursor.
    public func forEach(_ body: (Element) throws -> Void) throws {
        while let element = try next() {
            try body(element)
        }
    }
    
    /// Returns a cursor over the results of the transform function applied to
    /// this cursor's elements.
    public func map<T>(_ transform: @escaping (Element) throws -> T) -> MapCursor<Self, T> {
        return MapCursor(self, transform)
    }
    
    /// Returns the result of calling the given combining closure with each
    /// element of this sequence and an accumulating value.
    public func reduce<Result>(_ initialResult: Result, _ nextPartialResult: (Result, Element) throws -> Result) throws -> Result {
        var result = initialResult
        while let element = try next() {
            result = try nextPartialResult(result, element)
        }
        return result
    }
}

extension Cursor where Element: Equatable {
    /// Returns a Boolean value indicating whether the cursor contains the
    /// given element.
    public func contains(_ element: Element) throws -> Bool {
        while let e = try next() {
            if e == element {
                return true
            }
        }
        return false
    }
}

extension Cursor where Element: Cursor {
    /// Returns the elements of this cursor of cursors, concatenated.
    public func joined() -> FlattenCursor<Self> {
        return FlattenCursor(self)
    }
}

extension Cursor where Element: Sequence {
    /// Returns the elements of this cursor of sequences, concatenated.
    public func joined() -> FlattenCursor<MapCursor<Self, IteratorCursor<Self.Element.Iterator>>> {
        return flatMap { $0 }
    }
}

/// An enumeration of the elements of a cursor.
///
/// To create an instance of `EnumeratedCursor`, call the `enumerated()` method
/// on a cursor:
///
///     let cursor = try String.fetchCursor(db, "SELECT 'foo' UNION ALL SELECT 'bar'")
///     let c = cursor.enumerated()
///     while let (n, x) = c.next() {
///         print("\(n): \(x)")
///     }
///     // Prints: "0: foo"
///     // Prints: "1: bar"
public final class EnumeratedCursor<Base: Cursor> : Cursor {
    init(_ base: Base) {
        self.index = 0
        self.base = base
    }
    
    /// Advances to the next element and returns it, or nil if no next
    /// element exists.
    public func next() throws -> (Int, Base.Element)? {
        guard let element = try base.next() else { return nil }
        defer { index += 1 }
        return (index, element)
    }
    
    private var index: Int
    private var base: Base
}

/// A cursor whose elements consist of the elements of some base cursor that
/// also satisfy a given predicate.
public final class FilterCursor<Base: Cursor> : Cursor {
    init(_ base: Base, _ isIncluded: @escaping (Base.Element) throws -> Bool) {
        self.base = base
        self.isIncluded = isIncluded
    }
    
    /// Advances to the next element and returns it, or nil if no next
    /// element exists.
    public func next() throws -> Base.Element? {
        while let element = try base.next() {
            if try isIncluded(element) {
                return element
            }
        }
        return nil
    }
    
    private let base: Base
    private let isIncluded: (Base.Element) throws -> Bool
}

/// A cursor consisting of all the elements contained in each segment contained
/// in some Base cursor.
///
/// See Cursor.joined(), Cursor.flatMap(_:), Sequence.flatMap(_:)
public final class FlattenCursor<Base: Cursor> : Cursor where Base.Element: Cursor {
    init(_ base: Base) {
        self.base = base
    }
    
    /// Advances to the next element and returns it, or nil if no next
    /// element exists.
    public func next() throws -> Base.Element.Element? {
        while true {
            if let element = try inner?.next() {
                return element
            }
            guard let inner = try base.next() else {
                return nil
            }
            self.inner = inner
        }
    }
    
    private var inner: Base.Element?
    private let base: Base
}

/// A Cursor whose elements consist of those in a Base Cursor passed through a
/// transform function returning Element.
///
/// See Cursor.map(_:)
public final class MapCursor<Base: Cursor, Element> : Cursor {
    init(_ base: Base, _ transform: @escaping (Base.Element) throws -> Element) {
        self.base = base
        self.transform = transform
    }
    
    /// Advances to the next element and returns it, or nil if no next
    /// element exists.
    public func next() throws -> Element? {
        guard let element = try base.next() else { return nil }
        return try transform(element)
    }
    
    private let base: Base
    private let transform: (Base.Element) throws -> Element
}

/// A Cursor whose elements are those of a sequence iterator.
public final class IteratorCursor<Base: IteratorProtocol> : Cursor {
    
    /// Creates a cursor from a sequence iterator.
    public init(_ base: Base) {
        self.base = base
    }
    
    /// Creates a cursor from a sequence.
    public init<S: Sequence>(_ s: S) where S.Iterator == Base {
        self.base = s.makeIterator()
    }
    
    /// Advances to the next element and returns it, or nil if no next
    /// element exists.
    public func next() -> Base.Element? {
        return base.next()
    }
    
    private var base: Base
}

extension Sequence {
    
    /// Returns a cursor over the concatenated results of mapping transform
    /// over self.
    public func flatMap<SegmentOfResult: Cursor>(_ transform: @escaping (Iterator.Element) throws -> SegmentOfResult) -> FlattenCursor<MapCursor<IteratorCursor<Self.Iterator>, SegmentOfResult>> {
        return IteratorCursor(self).flatMap(transform)
    }
}

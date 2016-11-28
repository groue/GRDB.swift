extension Array {
    /// TODO
    public init<C : Cursor>(_ cursor: C) throws where C.Element == Element {
        // TODO: cursors should have an underestimatedCount
        self.init()
        while let element = try cursor.next() {
            append(element)
        }
    }
}

/// A type that supplies the values of a sequence one at a time.
public protocol Cursor : class {
    // TODO: explain that Cursor is a class because it is designed to wrap an
    // external resource such as a SQLite statement.
    /// TODO
    associatedtype Element
    
    /// TODO
    func next() throws -> Element?
}

/// TODO
class AnyCursor<Element> : Cursor {
    /// TODO
    init<C : Cursor>(_ base: C) where C.Element == Element {
        element = base.next
    }
    
    /// TODO
    func next() throws -> Element? {
        return try element()
    }
    
    private let element: () throws -> Element?
}

extension Cursor {
    
    /// TODO
    public func enumerated() -> EnumeratedCursor<Self> {
        return EnumeratedCursor(self)
    }
    
    /// TODO
    public func filter(_ isIncluded: @escaping (Element) throws -> Bool) -> FilterCursor<Self> {
        return FilterCursor(self, isIncluded)
    }
    
    /// TODO
    public func flatMap<ElementOfResult>(_ transform: @escaping (Element) throws -> ElementOfResult?) -> MapCursor<FilterCursor<MapCursor<Self, ElementOfResult?>>, ElementOfResult> {
        return map(transform).filter { $0 != nil }.map { $0! }
    }
    
    /// TODO
    public func flatMap<SegmentOfResult : Sequence>(_ transform: @escaping (Element) throws -> SegmentOfResult) -> FlattenCursor<MapCursor<Self, IteratorCursor<SegmentOfResult.Iterator>>> {
        return flatMap { try IteratorCursor(transform($0).makeIterator()) }
    }
    
    /// TODO
    public func flatMap<SegmentOfResult : Cursor>(_ transform: @escaping (Element) throws -> SegmentOfResult) -> FlattenCursor<MapCursor<Self, SegmentOfResult>> {
        return FlattenCursor(map(transform))
    }
    
    /// TODO
    public func forEach(_ body: (Element) throws -> Void) throws {
        while let element = try next() {
            try body(element)
        }
    }
    
    /// TODO
    public var lazy: CursorLazySequence<Self> {
        return CursorLazySequence(self)
    }
    
    /// TODO
    public func map<T>(_ transform: @escaping (Element) throws -> T) -> MapCursor<Self, T> {
        return MapCursor(self, transform)
    }
    
    /// TODO
    public func reduce<Result>(_ initialResult: Result, _ nextPartialResult: (Result, Element) throws -> Result) throws -> Result {
        var result = initialResult
        while let element = try next() {
            result = try nextPartialResult(result, element)
        }
        return result
    }
}

/// TODO
public final class CursorLazySequence<Base : Cursor> : LazySequenceProtocol, IteratorProtocol {
    init(_ base: Base) {
        self.base = base
    }
    
    /// TODO
    public func makeIterator() -> CursorLazySequence<Base> {
        return self
    }
    
    /// TODO
    public func next() -> Base.Element? {
        return try! base.next()
    }
    
    private let base: Base
}

/// TODO
public final class EnumeratedCursor<Base : Cursor> : Cursor {
    init(_ base: Base) {
        self.index = 0
        self.base = base
    }
    
    /// TODO
    public func next() throws -> (Int, Base.Element)? {
        guard let element = try base.next() else { return nil }
        defer { index += 1 }
        return (index, element)
    }
    
    private var index: Int
    private var base: Base
}

/// TODO
public final class FilterCursor<Base : Cursor> : Cursor {
    init(_ base: Base, _ isIncluded: @escaping (Base.Element) throws -> Bool) {
        self.base = base
        self.isIncluded = isIncluded
    }
    
    /// TODO
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

/// TODO
public final class FlattenCursor<Base: Cursor> : Cursor where Base.Element: Cursor {
    init(_ base: Base) {
        self.base = base
    }
    
    /// TODO
    public func next() throws -> Base.Element.Element? {
        while true {
            if let inner = inner {
                if let element = try inner.next() {
                    return element
                }
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

/// TODO
public final class MapCursor<Base : Cursor, Element> : Cursor {
    init(_ base: Base, _ transform: @escaping (Base.Element) throws -> Element) {
        self.base = base
        self.transform = transform
    }
    
    /// TODO
    public func next() throws -> Element? {
        guard let element = try base.next() else { return nil }
        return try transform(element)
    }
    
    private let base: Base
    private let transform: (Base.Element) throws -> Element
}

/// TODO
public final class IteratorCursor<Base : IteratorProtocol> : Cursor {
    // TODO: remove this type when `extension IteratorProtocol : Cursor { }` can be written
    init(_ base: Base) {
        self.base = base
    }
    
    /// TODO
    public func next() -> Base.Element? {
        return base.next()
    }
    
    private var base: Base
}

extension Sequence {
    
    /// TODO
    public func flatMap<SegmentOfResult : Cursor>(_ transform: @escaping (Iterator.Element) throws -> SegmentOfResult) -> FlattenCursor<MapCursor<IteratorCursor<Self.Iterator>, SegmentOfResult>> {
        return IteratorCursor(makeIterator()).flatMap(transform)
    }
}

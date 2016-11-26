/// A type that supplies the values of a sequence one at a time.
public protocol Cursor {
    /// TODO
    associatedtype Element
    /// TODO
    func next() throws -> Element?
}

extension Cursor {
    
    /// TODO
    public func enumerated() -> EnumeratedCursor<Element> {
        return EnumeratedCursor(self)
    }
    
    /// TODO
    public func filter(_ isIncluded: (Element) throws -> Bool) throws -> [Element] {
        var result: [Element] = []
        while let element = try next() {
            if try isIncluded(element) {
                result.append(element)
            }
        }
        return result
    }
    
    /// TODO
    public func flatMap<ElementOfResult>(_ transform: (Element) throws -> ElementOfResult?) throws -> [ElementOfResult] {
        var result: [ElementOfResult] = []
        while let element = try next() {
            if let x = try transform(element) {
                result.append(x)
            }
        }
        return result
    }
    
    /// TODO
    public func flatMap<SegmentOfResult : Sequence>(_ transform: (Element) throws -> SegmentOfResult) throws -> [SegmentOfResult.Iterator.Element] {
        var result: [SegmentOfResult.Iterator.Element] = []
        while let element = try next() {
            try result.append(contentsOf: transform(element))
        }
        return result
    }
    
    /// TODO
    public func flatMap<SegmentOfResult : Cursor>(_ transform: (Element) throws -> SegmentOfResult) throws -> [SegmentOfResult.Element] {
        var result: [SegmentOfResult.Element] = []
        while let element1 = try next() {
            let cursor = try transform(element1)
            while let element2 = try cursor.next() {
                result.append(element2)
            }
        }
        return result
    }
    
    /// TODO
    public func forEach(_ body: (Element) throws -> Void) throws {
        while let element = try next() {
            try body(element)
        }
    }
    
    /// TODO
    public func map<T>(_ transform: (Element) throws -> T) throws -> [T] {
        // TODO: cursors should have an underestimatedCount
        var result: [T] = []
        while let element = try next() {
            try result.append(transform(element))
        }
        return result
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

extension Sequence {
    
    /// TODO
    public func flatMap<SegmentOfResult : Cursor>(_ transform: (Iterator.Element) throws -> SegmentOfResult) throws -> [SegmentOfResult.Element] {
        var result: [SegmentOfResult.Element] = []
        for element1 in self {
            let cursor = try transform(element1)
            while let element2 = try cursor.next() {
                result.append(element2)
            }
        }
        return result
    }
}


/// TODO
public struct EnumeratedCursor<Element> : Cursor {
    private var element: () throws -> (Int, Element)?
    
    init<C : Cursor>(_ cursor: C) where C.Element == Element {
        var i = 0
        element = {
            guard let elem = try cursor.next() else { return nil }
            defer { i += 1 }
            return (i, elem)
        }
    }
    
    /// TODO
    public func next() throws -> (Int, Element)? {
        return try element()
    }
}

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

public struct CursorIterator<Element> : IteratorProtocol {
    private var element: () -> Element?
    
    /// TODO
    public init<C : Cursor>(_ cursor: C) where C.Element == Element {
        element = { try! cursor.next() }
    }
    
    /// TODO
    public mutating func next() -> Element? {
        return element()
    }
}

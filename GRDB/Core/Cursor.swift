//===----------------------------------------------------------------------===//
//
// Parts of this file are derived from the Swift.org open source project:
//
// Copyright (c) 2014 - 2018 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

// MARK: - RangeReplaceableCollection, Sequence, Dictionary, Set extensions

extension RangeReplaceableCollection {
    /// Creates a collection containing the elements of a cursor.
    ///
    ///     // [String]
    ///     let cursor = try String.fetchCursor(db, ...)
    ///     let strings = try Array(cursor)
    ///
    /// - parameter cursor: The cursor whose elements feed the collection.
    @inlinable
    public init<C: Cursor>(_ cursor: C) throws where C.Element == Element {
        self.init()
        while let element = try cursor.next() {
            append(element)
        }
    }
    
    /// Creates a collection containing the elements of a cursor.
    ///
    ///     // [String]
    ///     let cursor = try String.fetchCursor(db, ...)
    ///     let strings = try Array(cursor, minimumCapacity: 100)
    ///
    /// - parameter cursor: The cursor whose elements feed the collection.
    /// - parameter minimumCapacity: Prepares the returned collection to store
    ///   the specified number of elements.
    @inlinable
    public init<C: Cursor>(_ cursor: C, minimumCapacity: Int) throws where C.Element == Element {
        self.init()
        reserveCapacity(minimumCapacity)
        while let element = try cursor.next() {
            append(element)
        }
    }
}

extension Dictionary {
    /// Creates a new dictionary whose keys are the groupings returned by the
    /// given closure and whose values are arrays of the elements that returned
    /// each key.
    ///
    ///     // [Int64: [Player]]
    ///     let cursor = try Player.fetchCursor(db)
    ///     let dictionary = try Dictionary(grouping: cursor, by: { $0.teamID })
    ///
    /// - parameter cursor: A cursor of values to group into a dictionary.
    /// - parameter keyForValue: A closure that returns a key for each element
    ///   in the cursor.
    public init<C: Cursor>(grouping cursor: C, by keyForValue: (C.Element) throws -> Key)
    throws where Value == [C.Element]
    {
        self.init()
        while let value = try cursor.next() {
            try self[keyForValue(value), default: []].append(value)
        }
    }
    
    /// Creates a new dictionary whose keys are the groupings returned by the
    /// given closure and whose values are arrays of the elements that returned
    /// each key.
    ///
    ///     // [Int64: [Player]]
    ///     let cursor = try Player.fetchCursor(db)
    ///     let dictionary = try Dictionary(
    ///         minimumCapacity: 100,
    ///         grouping: cursor,
    ///         by: { $0.teamID })
    ///
    /// - parameter minimumCapacity: The minimum number of key-value pairs that
    ///   the newly created dictionary should be able to store without
    ///   reallocating its storage buffer.
    /// - parameter cursor: A cursor of values to group into a dictionary.
    /// - parameter keyForValue: A closure that returns a key for each element
    ///   in the cursor.
    public init<C: Cursor>(minimumCapacity: Int, grouping cursor: C, by keyForValue: (C.Element) throws -> Key)
    throws where Value == [C.Element]
    {
        self.init(minimumCapacity: minimumCapacity)
        while let value = try cursor.next() {
            try self[keyForValue(value), default: []].append(value)
        }
    }
    
    /// Creates a new dictionary from the key-value pairs in the given cursor.
    ///
    /// You use this initializer to create a dictionary when you have a cursor
    /// of key-value tuples with unique keys. Passing a cursor with duplicate
    /// keys to this initializer results in a fatal error.
    ///
    ///     // [Int64: Player]
    ///     let cursor = try Player.fetchCursor(db).map { ($0.id, $0) }
    ///     let playerByID = try Dictionary(uniqueKeysWithValues: cursor)
    ///
    /// - parameter keysAndValues: A cursor of key-value pairs to use for the
    ///   new dictionary. Every key in `keysAndValues` must be unique.
    /// - precondition: The cursor must not have duplicate keys.
    public init<C: Cursor>(uniqueKeysWithValues keysAndValues: C)
    throws where C.Element == (Key, Value)
    {
        self.init()
        while let (key, value) = try keysAndValues.next() {
            if updateValue(value, forKey: key) != nil {
                fatalError("Duplicate values for key: '\(String(describing: key))'")
            }
        }
    }
    
    /// Creates a new dictionary from the key-value pairs in the given cursor.
    ///
    /// You use this initializer to create a dictionary when you have a cursor
    /// of key-value tuples with unique keys. Passing a cursor with duplicate
    /// keys to this initializer results in a fatal error.
    ///
    ///     // [Int64: Player]
    ///     let cursor = try Player.fetchCursor(db).map { ($0.id, $0) }
    ///     let playerByID = try Dictionary(
    ///         minimumCapacity: 100,
    ///         uniqueKeysWithValues: cursor)
    ///
    /// - parameter minimumCapacity: The minimum number of key-value pairs that
    ///   the newly created dictionary should be able to store without
    ///   reallocating its storage buffer.
    /// - parameter keysAndValues: A cursor of key-value pairs to use for the
    ///   new dictionary. Every key in `keysAndValues` must be unique.
    /// - precondition: The cursor must not have duplicate keys.
    public init<C: Cursor>(minimumCapacity: Int, uniqueKeysWithValues keysAndValues: C)
    throws where C.Element == (Key, Value)
    {
        self.init(minimumCapacity: minimumCapacity)
        while let (key, value) = try keysAndValues.next() {
            if updateValue(value, forKey: key) != nil {
                fatalError("Duplicate values for key: '\(String(describing: key))'")
            }
        }
    }
}

extension Set {
    /// Creates a set containing the elements of a cursor.
    ///
    ///     // Set<String>
    ///     let cursor = try String.fetchCursor(db, ...)
    ///     let strings = try Set(cursor)
    ///
    /// - parameter cursor: A cursor of values to gather into a set.
    public init<C: Cursor>(_ cursor: C) throws where C.Element == Element {
        self.init()
        while let element = try cursor.next() {
            insert(element)
        }
    }
    
    /// Creates a set containing the elements of a cursor.
    ///
    ///     // Set<String>
    ///     let cursor = try String.fetchCursor(db, ...)
    ///     let strings = try Set(cursor, minimumCapacity: 100)
    ///
    /// - parameter cursor: A cursor of values to gather into a set.
    /// - parameter minimumCapacity: The minimum number of elements that the
    ///   newly created set should be able to store without reallocating its
    ///   storage buffer.
    public init<C: Cursor>(_ cursor: C, minimumCapacity: Int) throws where C.Element == Element {
        self.init(minimumCapacity: minimumCapacity)
        while let element = try cursor.next() {
            insert(element)
        }
    }
}

extension Sequence {
    /// Returns a cursor over the concatenated results of mapping transform
    /// over self.
    public func flatMap<SegmentOfResult: Cursor>(
        _ transform: @escaping (Iterator.Element) throws -> SegmentOfResult)
    -> FlattenCursor<MapCursor<AnyCursor<Iterator.Element>, SegmentOfResult>>
    {
        AnyCursor(self).flatMap(transform)
    }
}

// MARK: - Cursor

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
/// to those defined by Swift's Sequence protocol: `contains`, `dropFirst`,
/// `dropLast`, `drop(while:)`, `enumerated`, `filter`, `first`, `flatMap`,
/// `forEach`, `joined`, `joined(separator:)`, `max`, `max(by:)`, `min`,
/// `min(by:)`, `map`, `prefix`, `prefix(while:)`, `reduce`, `reduce(into:)`,
/// `suffix`.
public protocol Cursor: AnyObject {
    /// The type of element traversed by the cursor.
    associatedtype Element
    
    /// Advances to the next element and returns it, or nil if no next element
    /// exists. Once nil has been returned, all subsequent calls return nil.
    func next() throws -> Element?
}

extension Cursor {
    /// Returns a Boolean value indicating whether the cursor contains
    /// an element.
    public func isEmpty() throws -> Bool {
        try next() == nil
    }
    
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
    ///     let cursor = try String.fetchCursor(db, sql: "SELECT 'foo' UNION ALL SELECT 'bar'")
    ///     let c = cursor.enumerated()
    ///     while let (n, x) = c.next() {
    ///         print("\(n): \(x)")
    ///     }
    ///     // Prints: "0: foo"
    ///     // Prints: "1: bar"
    public func enumerated() -> EnumeratedCursor<Self> {
        EnumeratedCursor(self)
    }
    
    /// Returns the elements of the cursor that satisfy the given predicate.
    public func filter(_ isIncluded: @escaping (Element) throws -> Bool) -> FilterCursor<Self> {
        FilterCursor(self, isIncluded)
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
    public func compactMap<ElementOfResult>(_ transform: @escaping (Element) throws -> ElementOfResult?)
    -> MapCursor<FilterCursor<MapCursor<Self, ElementOfResult?>>, ElementOfResult>
    {
        map(transform).filter { $0 != nil }.map { $0! }
    }
    
    /// Returns a cursor that skips any initial elements that satisfy
    /// `predicate`.
    ///
    /// - Parameter predicate: A closure that takes an element of the cursir as
    ///   its argument and returns `true` if the element should be skipped or
    ///   `false` otherwise. Once `predicate` returns `false` it will not be
    ///   called again.
    public func drop(while predicate: @escaping (Element) throws -> Bool) -> DropWhileCursor<Self> {
        DropWhileCursor(self, predicate: predicate)
    }
    
    /// Returns a cursor containing all but the given number of initial
    /// elements.
    ///
    /// If the number of elements to drop exceeds the number of elements in
    /// the cursor, the result is an empty cursor.
    ///
    ///     let numbers = AnyCursor([1, 2, 3, 4, 5])
    ///     try print(numbers.dropFirst(2))
    ///     // Prints "[3, 4, 5]"
    ///     try print(numbers.dropFirst(10))
    ///     // Prints "[]"
    ///
    /// - Parameter n: The number of elements to drop from the beginning of
    ///   the cursor. `n` must be greater than or equal to zero.
    /// - Returns: A cursor starting after the specified number of
    ///   elements.
    public func dropFirst(_ n: Int) -> DropFirstCursor<Self> {
        DropFirstCursor(self, limit: n)
    }
    
    /// Returns a cursor containing all but the first element of the cursor.
    ///
    /// The following example drops the first element from a cursor of integers.
    ///
    ///     let numbers = AnyCursor([1, 2, 3, 4, 5])
    ///     try print(numbers.dropFirst())
    ///     // Prints "[2, 3, 4, 5]"
    ///
    /// If the cursor has no elements, the result is an empty cursor.
    ///
    /// - Returns: A cursor starting after the first element of the cursor.
    public func dropFirst() -> DropFirstCursor<Self> {
        dropFirst(1)
    }
    
    /// Returns an array containing all but the given number of final
    /// elements.
    ///
    /// The cursor must be finite. If the number of elements to drop exceeds
    /// the number of elements in the cursor, the result is an empty array.
    ///
    ///     let numbers = AnyCursor([1, 2, 3, 4, 5])
    ///     try print(numbers.dropLast(2))
    ///     // Prints "[1, 2, 3]"
    ///     try print(numbers.dropLast(10))
    ///     // Prints "[]"
    ///
    /// - Parameter n: The number of elements to drop off the end of the
    ///   cursor. `n` must be greater than or equal to zero.
    /// - Returns: An array leaving off the specified number of elements.
    public func dropLast(_ n: Int) throws -> [Element] {
        GRDBPrecondition(n >= 0, "Can't drop a negative number of elements from a cursor")
        if n == 0 { return try Array(self) }
        
        var result: [Element] = []
        var ringBuffer: [Element] = []
        var i = ringBuffer.startIndex
        
        while let element = try next() {
            if ringBuffer.count < n {
                ringBuffer.append(element)
            } else {
                result.append(ringBuffer[i])
                ringBuffer[i] = element
                i = ringBuffer.index(after: i) % n
            }
        }
        return result
    }
    
    /// Returns an array containing all but the last element of the cursor.
    ///
    /// The following example drops the last element from a cursor of integers.
    ///
    ///     let numbers = AnyCursor([1, 2, 3, 4, 5])
    ///     try print(numbers.dropLast())
    ///     // Prints "[1, 2, 3, 4]"
    ///
    /// If the cursor has no elements, the result is an empty cursor.
    ///
    /// - Returns: An array leaving off the last element of the cursor.
    public func dropLast() throws -> [Element] {
        try dropLast(1)
    }
    
    /// Returns a cursor over the concatenated results of mapping transform
    /// over self.
    public func flatMap<SegmentOfResult>(_ transform: @escaping (Element) throws -> SegmentOfResult)
    -> FlattenCursor<MapCursor<Self, AnyCursor<SegmentOfResult.Element>>>
    where SegmentOfResult: Sequence
    {
        flatMap { try AnyCursor(transform($0)) }
    }
    
    /// Returns a cursor over the concatenated results of mapping transform
    /// over self.
    public func flatMap<SegmentOfResult>(_ transform: @escaping (Element) throws -> SegmentOfResult)
    -> FlattenCursor<MapCursor<Self, SegmentOfResult>>
    where SegmentOfResult: Cursor
    {
        map(transform).joined()
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
        MapCursor(self, transform)
    }
    
    /// Returns the maximum element in the cursor, using the given predicate as
    /// the comparison between elements.
    ///
    /// - Parameter areInIncreasingOrder: A predicate that returns `true`
    ///   if its first argument should be ordered before its second
    ///   argument; otherwise, `false`.
    /// - Returns: The cursor's maximum element, according to
    ///   `areInIncreasingOrder`. If the cursor has no elements, returns `nil`.
    public func max(by areInIncreasingOrder: (Element, Element) throws -> Bool) throws -> Element? {
        guard var result = try next() else {
            return nil
        }
        while let e = try next() {
            if try areInIncreasingOrder(result, e) {
                result = e
            }
        }
        return result
    }
    
    /// Returns the minimum element in the cursor, using the given predicate as
    /// the comparison between elements.
    ///
    /// - Parameter areInIncreasingOrder: A predicate that returns `true`
    ///   if its first argument should be ordered before its second
    ///   argument; otherwise, `false`.
    /// - Returns: The cursor's minimum element, according to
    ///   `areInIncreasingOrder`. If the cursor has no elements, returns `nil`.
    public func min(by areInIncreasingOrder: (Element, Element) throws -> Bool) throws -> Element? {
        guard var result = try next() else {
            return nil
        }
        while let e = try next() {
            if try areInIncreasingOrder(e, result) {
                result = e
            }
        }
        return result
    }
    
    /// Returns a cursor, up to the specified maximum length, containing the
    /// initial elements of the cursor.
    ///
    /// If the maximum length exceeds the number of elements in the cursor,
    /// the result contains all the elements in the cursor.
    ///
    ///     let numbers = AnyCursor([1, 2, 3, 4, 5])
    ///     try print(numbers.prefix(2))
    ///     // Prints "[1, 2]"
    ///     try print(numbers.prefix(10))
    ///     // Prints "[1, 2, 3, 4, 5]"
    ///
    /// - Parameter maxLength: The maximum number of elements to return. The
    ///   value of `maxLength` must be greater than or equal to zero.
    /// - Returns: A cursor starting at the beginning of this cursor
    ///   with at most `maxLength` elements.
    public func prefix(_ maxLength: Int) -> PrefixCursor<Self> {
        PrefixCursor(self, maxLength: maxLength)
    }
    
    /// Returns a cursor of the initial consecutive elements that satisfy
    /// `predicate`.
    ///
    /// - Parameter predicate: A closure that takes an element of the cursor as
    ///   its argument and returns `true` if the element should be included or
    ///   `false` otherwise. Once `predicate` returns `false` it will not be
    ///   called again.
    public func prefix(while predicate: @escaping (Element) throws -> Bool) -> PrefixWhileCursor<Self> {
        PrefixWhileCursor(self, predicate: predicate)
    }
    
    /// Returns the result of calling the given combining closure with each
    /// element of this cursor and an accumulating value.
    public func reduce<Result>(
        _ initialResult: Result,
        _ nextPartialResult: (Result, Element) throws -> Result)
    throws -> Result
    {
        var accumulator = initialResult
        while let element = try next() {
            accumulator = try nextPartialResult(accumulator, element)
        }
        return accumulator
    }
    
    /// Returns the result of calling the given combining closure with each
    /// element of this cursor and an accumulating value.
    public func reduce<Result>(
        into initialResult: Result,
        _ updateAccumulatingResult: (inout Result, Element) throws -> Void)
    throws -> Result
    {
        var accumulator = initialResult
        while let element = try next() {
            try updateAccumulatingResult(&accumulator, element)
        }
        return accumulator
    }
    
    /// Returns an array, up to the given maximum length, containing the
    /// final elements of the cursor.
    ///
    /// The cursor must be finite. If the maximum length exceeds the number of
    /// elements in the cursor, the result contains all the elements in the
    /// cursor.
    ///
    ///     let numbers = AnyCursor([1, 2, 3, 4, 5])
    ///     try print(numbers.suffix(2))
    ///     // Prints "[4, 5]"
    ///     try print(numbers.suffix(10))
    ///     // Prints "[1, 2, 3, 4, 5]"
    ///
    /// - Parameter maxLength: The maximum number of elements to return. The
    ///   value of `maxLength` must be greater than or equal to zero.
    public func suffix(_ maxLength: Int) throws -> [Element] {
        GRDBPrecondition(maxLength >= 0, "Can't take a suffix of negative length from a cursor")
        if maxLength == 0 {
            return []
        }
        
        var ringBuffer: [Element] = []
        ringBuffer.reserveCapacity(maxLength)
        
        var i = ringBuffer.startIndex
        
        while let element = try next() {
            if ringBuffer.count < maxLength {
                ringBuffer.append(element)
            } else {
                ringBuffer[i] = element
                i += 1
                i %= maxLength
            }
        }
        
        if i != ringBuffer.startIndex {
            let s0 = ringBuffer[i..<ringBuffer.endIndex]
            let s1 = ringBuffer[0..<i]
            return Array([s0, s1].joined())
        }
        return ringBuffer
    }
}

// MARK: Equatable elements

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

// MARK: Comparable elements

extension Cursor where Element: Comparable {
    /// Returns the maximum element in the cursor.
    ///
    /// - Parameter areInIncreasingOrder: A predicate that returns `true`
    ///   if its first argument should be ordered before its second
    ///   argument; otherwise, `false`.
    /// - Returns: The cursor's maximum element, according to
    ///   `areInIncreasingOrder`. If the cursor has no elements, returns
    ///   `nil`.
    public func max() throws -> Element? {
        try max(by: <)
    }
    
    /// Returns the minimum element in the cursor.
    ///
    /// - Parameter areInIncreasingOrder: A predicate that returns `true`
    ///   if its first argument should be ordered before its second
    ///   argument; otherwise, `false`.
    /// - Returns: The cursor's minimum element, according to
    ///   `areInIncreasingOrder`. If the cursor has no elements, returns
    ///   `nil`.
    public func min() throws -> Element? {
        try min(by: <)
    }
}

// MARK: Cursor elements

extension Cursor where Element: Cursor {
    /// Returns the elements of this cursor of cursors, concatenated.
    public func joined() -> FlattenCursor<Self> {
        FlattenCursor(self)
    }
}

// MARK: Sequence elements

extension Cursor where Element: Sequence {
    /// Returns the elements of this cursor of sequences, concatenated.
    public func joined() -> FlattenCursor<MapCursor<Self, AnyCursor<Element.Element>>> {
        flatMap { $0 }
    }
}

// MARK: String elements

extension Cursor where Element: StringProtocol {
    /// Returns the elements of this cursor of sequences, concatenated.
    public func joined(separator: String = "") throws -> String {
        if separator.isEmpty {
            var result = ""
            while let x = try next() {
                result.append(String(x))
            }
            return result
        } else {
            var result = ""
            if let first = try next() {
                result.append(String(first))
                while let next = try next() {
                    result.append(separator)
                    result.append(String(next))
                }
            }
            return result
        }
    }
}

// MARK: Specialized Cursors

/// A type-erased cursor of Element.
///
/// This cursor forwards its next() method to an arbitrary underlying cursor
/// having the same Element type, hiding the specifics of the underlying
/// cursor.
public final class AnyCursor<Element>: Cursor {
    private let element: () throws -> Element?
    
    /// Creates a cursor that wraps a base cursor but whose type depends only on
    /// the base cursor’s element type
    public init<C: Cursor>(_ base: C) where C.Element == Element {
        element = base.next
    }
    
    /// Creates a cursor that wraps a base iterator but whose type depends only
    /// on the base iterator’s element type
    public convenience init<I: IteratorProtocol>(iterator: I) where I.Element == Element {
        var iterator = iterator
        self.init { iterator.next() }
    }
    
    /// Creates a cursor that wraps a base sequence but whose type depends only
    /// on the base sequence’s element type
    public convenience init<S: Sequence>(_ s: S) where S.Element == Element {
        self.init(iterator: s.makeIterator())
    }
    
    /// Creates a cursor that wraps the given closure in its next() method
    public init(_ body: @escaping () throws -> Element?) {
        element = body
    }
    
    public func next() throws -> Element? {
        try element()
    }
}

/// :nodoc:
public final class DropFirstCursor<Base: Cursor>: Cursor {
    private let base: Base
    private let limit: Int
    private var dropped: Int = 0
    
    init(_ base: Base, limit: Int) {
        GRDBPrecondition(limit >= 0, "Can't drop a negative number of elements from a cursor")
        self.base = base
        self.limit = limit
    }
    
    public func next() throws -> Base.Element? {
        while dropped < limit {
            if try base.next() == nil {
                dropped = limit
                return nil
            }
            dropped += 1
        }
        return try base.next()
    }
}

/// A cursor whose elements consist of the elements that follow the initial
/// consecutive elements of some base cursor that satisfy a given predicate.
///
/// :nodoc:
public final class DropWhileCursor<Base: Cursor>: Cursor {
    private let base: Base
    private let predicate: (Base.Element) throws -> Bool
    private var predicateHasFailed = false
    
    init(_ base: Base, predicate: @escaping (Base.Element) throws -> Bool) {
        self.base = base
        self.predicate = predicate
    }
    
    public func next() throws -> Base.Element? {
        if predicateHasFailed {
            return try base.next()
        }
        
        while let nextElement = try base.next() {
            if try !predicate(nextElement) {
                predicateHasFailed = true
                return nextElement
            }
        }
        return nil
    }
}

/// An enumeration of the elements of a cursor.
///
/// To create an instance of `EnumeratedCursor`, call the `enumerated()` method
/// on a cursor:
///
///     let cursor = try String.fetchCursor(db, sql: "SELECT 'foo' UNION ALL SELECT 'bar'")
///     let c = cursor.enumerated()
///     while let (n, x) = c.next() {
///         print("\(n): \(x)")
///     }
///     // Prints: "0: foo"
///     // Prints: "1: bar"
///
/// :nodoc:
public final class EnumeratedCursor<Base: Cursor>: Cursor {
    private let base: Base
    private var index: Int
    
    init(_ base: Base) {
        self.base = base
        self.index = 0
    }
    
    public func next() throws -> (Int, Base.Element)? {
        guard let element = try base.next() else { return nil }
        defer { index += 1 }
        return (index, element)
    }
}

/// A cursor whose elements consist of the elements of some base cursor that
/// also satisfy a given predicate.
///
/// :nodoc:
public final class FilterCursor<Base: Cursor>: Cursor {
    private let base: Base
    private let isIncluded: (Base.Element) throws -> Bool
    
    init(_ base: Base, _ isIncluded: @escaping (Base.Element) throws -> Bool) {
        self.base = base
        self.isIncluded = isIncluded
    }
    
    public func next() throws -> Base.Element? {
        while let element = try base.next() {
            if try isIncluded(element) {
                return element
            }
        }
        return nil
    }
}

/// A cursor consisting of all the elements contained in each segment contained
/// in some Base cursor.
///
/// See Cursor.joined(), Cursor.flatMap(_:), Sequence.flatMap(_:)
///
/// :nodoc:
public final class FlattenCursor<Base: Cursor>: Cursor where Base.Element: Cursor {
    private let base: Base
    private var inner: Base.Element?
    
    init(_ base: Base) {
        self.base = base
    }
    
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
}

/// A Cursor whose elements consist of those in a Base Cursor passed through a
/// transform function returning Element.
///
/// See Cursor.map(_:)
///
/// :nodoc:
public final class MapCursor<Base: Cursor, Element>: Cursor {
    private let base: Base
    private let transform: (Base.Element) throws -> Element
    
    init(_ base: Base, _ transform: @escaping (Base.Element) throws -> Element) {
        self.base = base
        self.transform = transform
    }
    
    public func next() throws -> Element? {
        guard let element = try base.next() else { return nil }
        return try transform(element)
    }
}

/// A cursor that only consumes up to `n` elements from an underlying
/// `Base` cursor.
///
/// :nodoc:
public final class PrefixCursor<Base: Cursor>: Cursor {
    private let base: Base
    private let maxLength: Int
    private var taken = 0
    
    init(_ base: Base, maxLength: Int) {
        self.base = base
        self.maxLength = maxLength
    }
    
    public func next() throws -> Base.Element? {
        if taken >= maxLength { return nil }
        taken += 1
        
        if let next = try base.next() {
            return next
        }
        
        taken = maxLength
        return nil
    }
}

/// A cursor whose elements consist of the initial consecutive elements of
/// some base cursor that satisfy a given predicate.
///
/// :nodoc:
public final class PrefixWhileCursor<Base: Cursor>: Cursor {
    private let base: Base
    private let predicate: (Base.Element) throws -> Bool
    private var predicateHasFailed = false
    
    init(_ base: Base, predicate: @escaping (Base.Element) throws -> Bool) {
        self.base = base
        self.predicate = predicate
    }
    
    public func next() throws -> Base.Element? {
        if !predicateHasFailed, let nextElement = try base.next() {
            if try predicate(nextElement) {
                return nextElement
            } else {
                predicateHasFailed = true
            }
        }
        return nil
    }
}

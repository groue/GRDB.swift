/// A dictionary with guaranteed keys ordering.
///
///     var dict = OrderedDictionary<String, Int>()
///     dict.append(1, forKey: "foo")
///     dict.append(2, forKey: "bar")
///
///     dict["foo"] // 1
///     dict["bar"] // 2
///     dict["qux"] // nil
///     dict.map { $0.key } // ["foo", "bar"], in this order.
@usableFromInline
struct OrderedDictionary<Key: Hashable, Value> {
    @usableFromInline /* private(set) */ var keys: [Key]
    @usableFromInline /* private(set) */ var dictionary: [Key: Value]
    
    var values: [Value] {
        return keys.map { dictionary[$0]! }
    }
    
    /// Creates an empty ordered dictionary.
    init() {
        keys = []
        dictionary = [:]
    }
    
    /// Creates an empty ordered dictionary.
    init(minimumCapacity: Int) {
        keys = []
        keys.reserveCapacity(minimumCapacity)
        dictionary = Dictionary(minimumCapacity: minimumCapacity)
    }

    /// Returns the value associated with key, or nil.
    @inlinable
    subscript(_ key: Key) -> Value? {
        get { return dictionary[key] }
        set {
            if let value = newValue {
                updateValue(value, forKey: key)
            } else {
                removeValue(forKey: key)
            }
        }
    }
    
    /// Appends the given value for the given key.
    ///
    /// - precondition: There is no value associated with key yet.
    mutating func appendValue(_ value: Value, forKey key: Key) {
        guard updateValue(value, forKey: key) == nil else {
            fatalError("key is already defined")
        }
    }
    
    /// Updates the value stored in the dictionary for the given key, or
    /// appnds a new key-value pair if the key does not exist.
    ///
    /// Use this method instead of key-based subscripting when you need to know
    /// whether the new value supplants the value of an existing key. If the
    /// value of an existing key is updated, updateValue(_:forKey:) returns the
    /// original value. If the given key is not present in the dictionary, this
    /// method appends the key-value pair and returns nil.
    @discardableResult
    @inlinable
    mutating func updateValue(_ value: Value, forKey key: Key) -> Value? {
        if let oldValue = dictionary.updateValue(value, forKey: key) {
            return oldValue
        }
        keys.append(key)
        return nil
    }
    
    /// Removes the value associated with key.
    @discardableResult
    @usableFromInline
    mutating func removeValue(forKey key: Key) -> Value? {
        guard let value = dictionary.removeValue(forKey: key) else {
            return nil
        }
        let index = keys.firstIndex { $0 == key }!
        keys.remove(at: index)
        return value
    }
    
    /// Returns a new ordered dictionary containing the keys of this dictionary
    /// with the values transformed by the given closure.
    func mapValues<T>(_ transform: (Value) throws -> T) rethrows -> OrderedDictionary<Key, T> {
        return try reduce(into: OrderedDictionary<Key, T>()) { dict, pair in
            dict.appendValue(try transform(pair.value), forKey: pair.key)
        }
    }
    
    /// Returns a new ordered dictionary containing the key-value pairs of the
    /// dictionary that satisfy the given predicate.
    ///
    /// - Parameter isIncluded: A closure that takes a key-value pair as its
    ///   argument and returns a Boolean value indicating whether the pair
    ///   should be included in the returned dictionary.
    /// - Returns: A dictionary of the key-value pairs that `isIncluded` allows.
    func filter(_ isIncluded: (Element) throws -> Bool) rethrows -> OrderedDictionary<Key, Value> {
        var result = OrderedDictionary<Key, Value>()
        for element in self {
            if try isIncluded(element) {
                result.updateValue(element.value, forKey: element.key)
            }
        }
        return result
    }

    /// Returns a new ordered dictionary containing the keys of this dictionary
    /// with the values transformed by the given closure.
    ///
    /// - Parameter transform: A closure that transforms a value. `transform`
    ///   accepts each value of the dictionary as its parameter and returns a
    ///   transformed value of the same or of a different type.
    /// - Returns: A dictionary containing the keys and transformed values of
    ///   this dictionary.
    func compactMapValues<T>(_ transform: (Value) throws -> T?) rethrows -> OrderedDictionary<Key, T> {
        return try reduce(into: OrderedDictionary<Key, T>(), { dict, pair in
            if let value = try transform(pair.value) {
                dict[pair.key] = value
            }
        })
    }
}

extension OrderedDictionary: Collection {
    @usableFromInline typealias Index = Int
    
    @usableFromInline var startIndex: Int {
        return 0
    }
    
    @usableFromInline var endIndex: Int {
        return keys.count
    }
    
    @usableFromInline func index(after i: Int) -> Int {
        return i + 1
    }
    
    @usableFromInline  subscript(position: Int) -> (key: Key, value: Value) {
        let key = keys[position]
        return (key: key, value: dictionary[key]!)
    }
}

extension OrderedDictionary: ExpressibleByDictionaryLiteral {
    @usableFromInline init(dictionaryLiteral elements: (Key, Value)...) {
        self.keys = elements.map { $0.0 }
        self.dictionary = Dictionary(uniqueKeysWithValues: elements)
    }
}

extension Dictionary {
    init(_ orderedDictionary: OrderedDictionary<Key, Value>) {
        self = orderedDictionary.dictionary
    }
}

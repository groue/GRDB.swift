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
struct OrderedDictionary<Key: Hashable, Value> {
    private var keys: [Key]
    private var values: [Key: Value]
    
    /// Creates an empty ordered dictionary.
    init() {
        self.keys = []
        self.values = [:]
    }
    
    /// Returns the value associated with key, or nil.
    subscript(_ key: Key) -> Value? {
        return values[key]
    }
    
    /// Appends the given value for the given key.
    ///
    /// - precondition: There is no value associated with key yet.
    mutating func append(value: Value, forKey key: Key) {
        guard values.updateValue(value, forKey: key) == nil else {
            fatalError("key is already defined")
        }
        keys.append(key)
    }
    
    /// Removes the value associated with key.
    @discardableResult
    mutating func removeValue(forKey key: Key) -> Value? {
        guard let value = values.removeValue(forKey: key) else {
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
            dict.append(value: try transform(pair.value), forKey: pair.key)
        }
    }
}

extension OrderedDictionary: Collection {
    typealias Index = Int
    
    var startIndex: Int {
        return 0
    }
    
    var endIndex: Int {
        return keys.count
    }
    
    func index(after i: Int) -> Int {
        return i + 1
    }
    
    subscript(position: Int) -> (key: Key, value: Value) {
        let key = keys[position]
        return (key: key, value: values[key]!)
    }
}

extension OrderedDictionary: ExpressibleByDictionaryLiteral {
    init(dictionaryLiteral elements: (Key, Value)...) {
        self.keys = elements.map { $0.0 }
        self.values = Dictionary(uniqueKeysWithValues: elements)
    }
}

//
//  OrderedDictionary.swift
//  GRDB
//
//  Created by Gwendal Roué on 29/09/2018.
//  Copyright © 2018 Gwendal Roué. All rights reserved.
//

struct OrderedDictionary<Key: Hashable, Value> {
    private var keys: [Key]
    private var values: [Key: Value]
    
    init() {
        self.keys = []
        self.values = [:]
    }
    
    subscript(_ key: Key) -> Value? {
        return values[key]
    }
    
    mutating func append(value: Value, forKey key: Key) {
        guard values.updateValue(value, forKey: key) == nil else {
            fatalError("key is already defined")
        }
        keys.append(key)
    }
    
    @discardableResult
    mutating func removeValue(forKey key: Key) -> Value? {
        guard let value = values.removeValue(forKey: key) else {
            return nil
        }
        let index = keys.index { $0 == key }!
        keys.remove(at: index)
        return value
    }
    
    func mapValues<T>(_ transform: (Value) throws -> T) rethrows -> OrderedDictionary<Key, T> {
        var result = OrderedDictionary<Key, T>()
        for key in keys {
            let value = values[key]!
            try result.append(value: transform(value), forKey: key)
        }
        return result
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

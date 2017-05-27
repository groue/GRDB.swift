struct PersistableKeyedEncodingContainer<Key: CodingKey> : KeyedEncodingContainerProtocol {
    let encode: (_ value: DatabaseValueConvertible?, _ key: String) -> Void
    
    init(encode: @escaping (_ value: DatabaseValueConvertible?, _ key: String) -> Void) {
        self.encode = encode
    }
    
    /// The path of coding keys taken to get to this point in encoding.
    /// A `nil` value indicates an unkeyed container.
    var codingPath: [CodingKey?] { return [] }
    
    /// Encodes the given value for the given key.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encode(_ value: Bool, forKey key: Key) throws { encode(value, key.stringValue) }
    mutating func encode(_ value: Int, forKey key: Key) throws { encode(value, key.stringValue) }
    mutating func encode(_ value: Int8, forKey key: Key) throws { encode(value, key.stringValue) }
    mutating func encode(_ value: Int16, forKey key: Key) throws { encode(value, key.stringValue) }
    mutating func encode(_ value: Int32, forKey key: Key) throws { encode(value, key.stringValue) }
    mutating func encode(_ value: Int64, forKey key: Key) throws { encode(value, key.stringValue) }
    mutating func encode(_ value: UInt, forKey key: Key) throws { encode(value, key.stringValue) }
    mutating func encode(_ value: UInt8, forKey key: Key) throws { encode(value, key.stringValue) }
    mutating func encode(_ value: UInt16, forKey key: Key) throws { encode(value, key.stringValue) }
    mutating func encode(_ value: UInt32, forKey key: Key) throws { encode(value, key.stringValue) }
    mutating func encode(_ value: UInt64, forKey key: Key) throws { encode(value, key.stringValue) }
    mutating func encode(_ value: Float, forKey key: Key) throws { encode(value, key.stringValue) }
    mutating func encode(_ value: Double, forKey key: Key) throws { encode(value, key.stringValue) }
    mutating func encode(_ value: String, forKey key: Key) throws { encode(value, key.stringValue) }
    
    /// Encodes the given value for the given key.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encode<T>(_ value: T, forKey key: Key) throws where T : Encodable {
        if T.self is DatabaseValueConvertible.Type {
            encode((value as! DatabaseValueConvertible), key.stringValue)
        } else {
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: codingPath, debugDescription: "value does not adopt DatabaseValueConvertible"))
        }
    }
    
    /// Encodes the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encodeIfPresent(_ value: Bool?, forKey key: Key) throws { encode(value, key.stringValue) }
    mutating func encodeIfPresent(_ value: Int?, forKey key: Key) throws { encode(value, key.stringValue) }
    mutating func encodeIfPresent(_ value: Int8?, forKey key: Key) throws { encode(value, key.stringValue) }
    mutating func encodeIfPresent(_ value: Int16?, forKey key: Key) throws { encode(value, key.stringValue) }
    mutating func encodeIfPresent(_ value: Int32?, forKey key: Key) throws { encode(value, key.stringValue) }
    mutating func encodeIfPresent(_ value: Int64?, forKey key: Key) throws { encode(value, key.stringValue) }
    mutating func encodeIfPresent(_ value: UInt?, forKey key: Key) throws { encode(value, key.stringValue) }
    mutating func encodeIfPresent(_ value: UInt8?, forKey key: Key) throws { encode(value, key.stringValue) }
    mutating func encodeIfPresent(_ value: UInt16?, forKey key: Key) throws { encode(value, key.stringValue) }
    mutating func encodeIfPresent(_ value: UInt32?, forKey key: Key) throws { encode(value, key.stringValue) }
    mutating func encodeIfPresent(_ value: UInt64?, forKey key: Key) throws { encode(value, key.stringValue) }
    mutating func encodeIfPresent(_ value: Float?, forKey key: Key) throws { encode(value, key.stringValue) }
    mutating func encodeIfPresent(_ value: Double?, forKey key: Key) throws { encode(value, key.stringValue) }
    mutating func encodeIfPresent(_ value: String?, forKey key: Key) throws { encode(value, key.stringValue) }
    
    /// Encodes the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    mutating func encodeIfPresent<T>(_ value: T?, forKey key: Key) throws where T : Encodable {
        if T.self is DatabaseValueConvertible.Type {
            encode(value.map { $0 as! DatabaseValueConvertible }, key.stringValue)
        } else {
            throw EncodingError.invalidValue(value as Any, EncodingError.Context(codingPath: codingPath, debugDescription: "value does not adopt DatabaseValueConvertible"))
        }
    }
    
    /// Stores a keyed encoding container for the given key and returns it.
    ///
    /// - parameter keyType: The key type to use for the container.
    /// - parameter key: The key to encode the container for.
    /// - returns: A new keyed encoding container.
    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
        fatalError("Not implemented")
    }
    
    /// Stores an unkeyed encoding container for the given key and returns it.
    ///
    /// - parameter key: The key to encode the container for.
    /// - returns: A new unkeyed encoding container.
    mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        fatalError("Not implemented")
    }
    
    /// Stores a new nested container for the default `super` key and returns a new `Encoder` instance for encoding `super` into that container.
    ///
    /// Equivalent to calling `superEncoder(forKey:)` with `Key(stringValue: "super", intValue: 0)`.
    ///
    /// - returns: A new `Encoder` to pass to `super.encode(to:)`.
    mutating func superEncoder() -> Encoder {
        fatalError("Not implemented")
    }
    
    /// Stores a new nested container for the given key and returns a new `Encoder` instance for encoding `super` into that container.
    ///
    /// - parameter key: The key to encode `super` for.
    /// - returns: A new `Encoder` to pass to `super.encode(to:)`.
    mutating func superEncoder(forKey key: Key) -> Encoder {
        fatalError("Not implemented")
    }
}

struct PersistableEncoder : Encoder {
    /// The path of coding keys taken to get to this point in encoding.
    /// A `nil` value indicates an unkeyed container.
    var codingPath: [CodingKey?] { return [] }
    
    /// Any contextual information set by the user for encoding.
    var userInfo: [CodingUserInfoKey : Any] = [:]
    
    let encode: (_ value: DatabaseValueConvertible?, _ key: String) -> Void
    
    init(encode: @escaping (_ value: DatabaseValueConvertible?, _ key: String) -> Void) {
        self.encode = encode
    }
    
    /// Returns an encoding container appropriate for holding multiple values keyed by the given key type.
    ///
    /// - parameter type: The key type to use for the container.
    /// - returns: A new keyed encoding container.
    /// - precondition: May not be called after a prior `self.unkeyedContainer()` call.
    /// - precondition: May not be called after a value has been encoded through a previous `self.singleValueContainer()` call.
    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        return KeyedEncodingContainer(PersistableKeyedEncodingContainer<Key>(encode: encode))
    }
    
    /// Returns an encoding container appropriate for holding multiple unkeyed values.
    ///
    /// - returns: A new empty unkeyed container.
    /// - precondition: May not be called after a prior `self.container(keyedBy:)` call.
    /// - precondition: May not be called after a value has been encoded through a previous `self.singleValueContainer()` call.
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        fatalError("unkeyed encoding is not supported")
    }
    
    /// Returns an encoding container appropriate for holding a single primitive value.
    ///
    /// - returns: A new empty single value container.
    /// - precondition: May not be called after a prior `self.container(keyedBy:)` call.
    /// - precondition: May not be called after a prior `self.unkeyedContainer()` call.
    /// - precondition: May not be called after a value has been encoded through a previous `self.singleValueContainer()` call.
    func singleValueContainer() -> SingleValueEncodingContainer {
        fatalError("single value encoding is not supported")
    }
}

extension MutablePersistable where Self: Encodable {
    /// TODO
    public var persistentDictionary: [String: DatabaseValueConvertible?] {
        var persistentDictionary: [String: DatabaseValueConvertible?] = [:]
        let encoder = PersistableEncoder(encode: { (value, key) in persistentDictionary.updateValue(value, forKey: key) })
        try! self.encode(to: encoder)
        return persistentDictionary
    }
}

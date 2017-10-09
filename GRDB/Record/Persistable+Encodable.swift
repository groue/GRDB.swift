private struct PersistableKeyedEncodingContainer<Key: CodingKey> : KeyedEncodingContainerProtocol {
    let encode: (_ value: DatabaseValueConvertible?, _ key: String) -> Void
    
    init(encode: @escaping (_ value: DatabaseValueConvertible?, _ key: String) -> Void) {
        self.encode = encode
    }
    
    /// The path of coding keys taken to get to this point in encoding.
    /// A `nil` value indicates an unkeyed container.
    var codingPath: [CodingKey] { return [] }
    
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
            // Prefer DatabaseValueConvertible encoding over Decodable.
            // This allows us to encode Date as String, for example.
            encode((value as! DatabaseValueConvertible), key.stringValue)
        } else {
            try value.encode(to: PersistableEncoder(codingPath: [key], encode: encode))
        }
    }
    
    // Provide explicit encoding of optionals, because default implementation does not encode nil values.
    mutating func encodeNil(forKey key: Key) throws { encode(nil, key.stringValue) }
    mutating func encodeIfPresent(_ value: Bool?, forKey key: Key) throws { if let value = value { try encode(value, forKey: key) } else { try encodeNil(forKey: key) } }
    mutating func encodeIfPresent(_ value: Int?, forKey key: Key) throws { if let value = value { try encode(value, forKey: key) } else { try encodeNil(forKey: key) } }
    mutating func encodeIfPresent(_ value: Int8?, forKey key: Key) throws { if let value = value { try encode(value, forKey: key) } else { try encodeNil(forKey: key) } }
    mutating func encodeIfPresent(_ value: Int16?, forKey key: Key) throws { if let value = value { try encode(value, forKey: key) } else { try encodeNil(forKey: key) } }
    mutating func encodeIfPresent(_ value: Int32?, forKey key: Key) throws { if let value = value { try encode(value, forKey: key) } else { try encodeNil(forKey: key) } }
    mutating func encodeIfPresent(_ value: Int64?, forKey key: Key) throws { if let value = value { try encode(value, forKey: key) } else { try encodeNil(forKey: key) } }
    mutating func encodeIfPresent(_ value: UInt?, forKey key: Key) throws { if let value = value { try encode(value, forKey: key) } else { try encodeNil(forKey: key) } }
    mutating func encodeIfPresent(_ value: UInt8?, forKey key: Key) throws { if let value = value { try encode(value, forKey: key) } else { try encodeNil(forKey: key) } }
    mutating func encodeIfPresent(_ value: UInt16?, forKey key: Key) throws { if let value = value { try encode(value, forKey: key) } else { try encodeNil(forKey: key) } }
    mutating func encodeIfPresent(_ value: UInt32?, forKey key: Key) throws { if let value = value { try encode(value, forKey: key) } else { try encodeNil(forKey: key) } }
    mutating func encodeIfPresent(_ value: UInt64?, forKey key: Key) throws { if let value = value { try encode(value, forKey: key) } else { try encodeNil(forKey: key) } }
    mutating func encodeIfPresent(_ value: Float?, forKey key: Key) throws { if let value = value { try encode(value, forKey: key) } else { try encodeNil(forKey: key) } }
    mutating func encodeIfPresent(_ value: Double?, forKey key: Key) throws { if let value = value { try encode(value, forKey: key) } else { try encodeNil(forKey: key) } }
    mutating func encodeIfPresent(_ value: String?, forKey key: Key) throws { if let value = value { try encode(value, forKey: key) } else { try encodeNil(forKey: key) } }
    mutating func encodeIfPresent<T>(_ value: T?, forKey key: Key) throws where T : Encodable { if let value = value { try encode(value, forKey: key) } else { try encodeNil(forKey: key) } }
    
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

private struct DatabaseValueEncodingContainer : SingleValueEncodingContainer {
    let key: CodingKey
    let encode: (_ value: DatabaseValueConvertible?, _ key: String) -> Void

    var codingPath: [CodingKey] { return [key] }
    
    /// Encodes a null value.
    ///
    /// - throws: `EncodingError.invalidValue` if a null value is invalid in the current context for this format.
    /// - precondition: May not be called after a previous `self.encode(_:)` call.
    func encodeNil() throws { encode(nil, key.stringValue) }
    
    /// Encodes a single value of the given type.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    /// - precondition: May not be called after a previous `self.encode(_:)` call.
    func encode(_ value: Bool) throws { encode(value, key.stringValue) }
    func encode(_ value: Int) throws { encode(value, key.stringValue) }
    func encode(_ value: Int8) throws { encode(value, key.stringValue) }
    func encode(_ value: Int16) throws { encode(value, key.stringValue) }
    func encode(_ value: Int32) throws { encode(value, key.stringValue) }
    func encode(_ value: Int64) throws { encode(value, key.stringValue) }
    func encode(_ value: UInt) throws { encode(value, key.stringValue) }
    func encode(_ value: UInt8) throws { encode(value, key.stringValue) }
    func encode(_ value: UInt16) throws { encode(value, key.stringValue) }
    func encode(_ value: UInt32) throws { encode(value, key.stringValue) }
    func encode(_ value: UInt64) throws { encode(value, key.stringValue) }
    func encode(_ value: Float) throws { encode(value, key.stringValue) }
    func encode(_ value: Double) throws { encode(value, key.stringValue) }
    func encode(_ value: String) throws { encode(value, key.stringValue) }
    
    /// Encodes a single value of the given type.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    /// - precondition: May not be called after a previous `self.encode(_:)` call.
    func encode<T>(_ value: T) throws where T : Encodable {
        if let dbValueConvertible = value as? DatabaseValueConvertible {
            // Prefer DatabaseValueConvertible encoding over Decodable.
            // This allows us to encode Date as String, for example.
            encode(dbValueConvertible.databaseValue, key.stringValue)
        } else {
            try value.encode(to: PersistableEncoder(codingPath: [key], encode: encode))
        }
    }
}

private struct PersistableEncoder : Encoder {
    /// The path of coding keys taken to get to this point in encoding.
    /// A `nil` value indicates an unkeyed container.
    var codingPath: [CodingKey]
    
    /// Any contextual information set by the user for encoding.
    var userInfo: [CodingUserInfoKey : Any] = [:]
    
    let encode: (_ value: DatabaseValueConvertible?, _ key: String) -> Void
    
    init(codingPath: [CodingKey], encode: @escaping (_ value: DatabaseValueConvertible?, _ key: String) -> Void) {
        self.codingPath = codingPath
        self.encode = encode
    }
    
    /// Returns an encoding container appropriate for holding multiple values keyed by the given key type.
    ///
    /// - parameter type: The key type to use for the container.
    /// - returns: A new keyed encoding container.
    /// - precondition: May not be called after a prior `self.unkeyedContainer()` call.
    /// - precondition: May not be called after a value has been encoded through a previous `self.singleValueContainer()` call.
    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        // Asked for a keyed type: top level required
        guard codingPath.isEmpty else {
            fatalError("unkeyed encoding is not supported")
        }
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
        return DatabaseValueEncodingContainer(key: codingPath.last!, encode: encode)
    }
}

extension MutablePersistable where Self: Encodable {
    public func encode(to container: inout PersistenceContainer) {
        // The inout container parameter won't enter an escaping closure since
        // SE-0035: https://github.com/apple/swift-evolution/blob/master/proposals/0035-limit-inout-capture.md
        //
        // So let's use it in a non-escaping closure:
        func encode(_ encode: (_ value: DatabaseValueConvertible?, _ key: String) -> Void) {
            withoutActuallyEscaping(encode) { escapableEncode in
                let encoder = PersistableEncoder(codingPath: [], encode: escapableEncode)
                try! self.encode(to: encoder)
            }
        }
        encode { (value, key) in
            container[key] = value
        }
    }
}

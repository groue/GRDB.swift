import Foundation

// MARK: - RecordEncoder

/// The encoder that encodes a record into GRDB's PersistenceContainer
private class RecordEncoder<Record: MutablePersistableRecord>: Encoder {
    var codingPath: [CodingKey] { return [] }
    var userInfo: [CodingUserInfoKey: Any] { return Record.databaseEncodingUserInfo }
    private var _persistenceContainer: PersistenceContainer
    var persistenceContainer: PersistenceContainer { return _persistenceContainer }
    
    init() {
        _persistenceContainer = PersistenceContainer()
    }
    
    /// Helper method
    @inline(__always)
    fileprivate func encode(_ value: DatabaseValueConvertible?, forKey key: CodingKey) {
        _persistenceContainer[key.stringValue] = value
    }
    
    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        let container = KeyedContainer<Key>(recordEncoder: self)
        return KeyedEncodingContainer(container)
    }
    
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        fatalError("unkeyed encoding is not supported")
    }
    
    func singleValueContainer() -> SingleValueEncodingContainer {
        fatalError("single value encoding is not supported")
    }
    
    struct KeyedContainer<Key: CodingKey> : KeyedEncodingContainerProtocol {
        var recordEncoder: RecordEncoder
        var userInfo: [CodingUserInfoKey: Any] { return Record.databaseEncodingUserInfo }
        
        init(recordEncoder: RecordEncoder) {
            self.recordEncoder = recordEncoder
        }
        
        var codingPath: [CodingKey] { return [] }
        
        func encode(_ value: Bool,   forKey key: Key) throws { recordEncoder.encode(value, forKey: key) }
        func encode(_ value: Int,    forKey key: Key) throws { recordEncoder.encode(value, forKey: key) }
        func encode(_ value: Int8,   forKey key: Key) throws { recordEncoder.encode(value, forKey: key) }
        func encode(_ value: Int16,  forKey key: Key) throws { recordEncoder.encode(value, forKey: key) }
        func encode(_ value: Int32,  forKey key: Key) throws { recordEncoder.encode(value, forKey: key) }
        func encode(_ value: Int64,  forKey key: Key) throws { recordEncoder.encode(value, forKey: key) }
        func encode(_ value: UInt,   forKey key: Key) throws { recordEncoder.encode(value, forKey: key) }
        func encode(_ value: UInt8,  forKey key: Key) throws { recordEncoder.encode(value, forKey: key) }
        func encode(_ value: UInt16, forKey key: Key) throws { recordEncoder.encode(value, forKey: key) }
        func encode(_ value: UInt32, forKey key: Key) throws { recordEncoder.encode(value, forKey: key) }
        func encode(_ value: UInt64, forKey key: Key) throws { recordEncoder.encode(value, forKey: key) }
        func encode(_ value: Float,  forKey key: Key) throws { recordEncoder.encode(value, forKey: key) }
        func encode(_ value: Double, forKey key: Key) throws { recordEncoder.encode(value, forKey: key) }
        func encode(_ value: String, forKey key: Key) throws { recordEncoder.encode(value, forKey: key) }
        
        func encode<T>(_ value: T, forKey key: Key) throws where T : Encodable {
            if let value = value as? DatabaseValueConvertible {
                // Prefer DatabaseValueConvertible encoding over Decodable.
                // This allows us to encode Date as String, for example.
                recordEncoder.encode(value.databaseValue, forKey: key)
            } else {
                do {
                    // This encoding will fail for types that encode into keyed
                    // or unkeyed containers, because we're encoding a single
                    // value here (string, int, double, data, null). If such an
                    // error happens, we'll switch to JSON encoding.
                    let encoder = ColumnEncoder(recordEncoder: recordEncoder, key: key)
                    try value.encode(to: encoder)
                } catch is JSONRequiredError {
                    // Encode to JSON
                    let jsonData = try Record.databaseJSONEncoder(for: key.stringValue).encode(value)
                    
                    // Store JSON String in the database for easier debugging and
                    // database inspection. Thanks to SQLite weak typing, we won't
                    // have any trouble decoding this string into data when we
                    // eventually perform JSON decoding.
                    // TODO: possible optimization: avoid this conversion to string, and store raw data bytes as an SQLite string
                    let jsonString = String(data: jsonData, encoding: .utf8)! // force unwrap because json data is guaranteed to convert to String
                    recordEncoder.encode(jsonString, forKey: key)
                }
            }
        }
        
        func encodeNil(forKey key: Key) throws { recordEncoder.encode(nil, forKey: key) }
        
        func encodeIfPresent(_ value: Bool?,   forKey key: Key) throws { recordEncoder.encode(value, forKey: key) }
        func encodeIfPresent(_ value: Int?,    forKey key: Key) throws { recordEncoder.encode(value, forKey: key) }
        func encodeIfPresent(_ value: Int8?,   forKey key: Key) throws { recordEncoder.encode(value, forKey: key) }
        func encodeIfPresent(_ value: Int16?,  forKey key: Key) throws { recordEncoder.encode(value, forKey: key) }
        func encodeIfPresent(_ value: Int32?,  forKey key: Key) throws { recordEncoder.encode(value, forKey: key) }
        func encodeIfPresent(_ value: Int64?,  forKey key: Key) throws { recordEncoder.encode(value, forKey: key) }
        func encodeIfPresent(_ value: UInt?,   forKey key: Key) throws { recordEncoder.encode(value, forKey: key) }
        func encodeIfPresent(_ value: UInt8?,  forKey key: Key) throws { recordEncoder.encode(value, forKey: key) }
        func encodeIfPresent(_ value: UInt16?, forKey key: Key) throws { recordEncoder.encode(value, forKey: key) }
        func encodeIfPresent(_ value: UInt32?, forKey key: Key) throws { recordEncoder.encode(value, forKey: key) }
        func encodeIfPresent(_ value: UInt64?, forKey key: Key) throws { recordEncoder.encode(value, forKey: key) }
        func encodeIfPresent(_ value: Float?,  forKey key: Key) throws { recordEncoder.encode(value, forKey: key) }
        func encodeIfPresent(_ value: Double?, forKey key: Key) throws { recordEncoder.encode(value, forKey: key) }
        func encodeIfPresent(_ value: String?, forKey key: Key) throws { recordEncoder.encode(value, forKey: key) }
        
        func encodeIfPresent<T>(_ value: T?, forKey key: Key) throws where T : Encodable {
            if let value = value {
                try encode(value, forKey: key)
            } else {
                recordEncoder.encode(nil, forKey: key)
            }
        }
        
        func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
            fatalError("Not implemented")
        }
        
        func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
            fatalError("Not implemented")
        }
        
        func superEncoder() -> Encoder {
            fatalError("Not implemented")
        }
        
        func superEncoder(forKey key: Key) -> Encoder {
            fatalError("Not implemented")
        }
    }
}

// MARK: - ColumnEncoder

/// The encoder that encodes into a database column
private struct ColumnEncoder<Record: MutablePersistableRecord>: Encoder {
    var recordEncoder: RecordEncoder<Record>
    var key: CodingKey
    var codingPath: [CodingKey] { return [key] }
    var userInfo: [CodingUserInfoKey: Any] { return Record.databaseEncodingUserInfo }
    
    init(recordEncoder: RecordEncoder<Record>, key: CodingKey) {
        self.recordEncoder = recordEncoder
        self.key = key
    }
    
    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
        // Keyed values require JSON encoding: we need to throw
        // JSONRequiredError. Since we can't throw right from here, let's
        // delegate the job to a dedicated container.
        let container = JSONRequiredEncoder<Record>.KeyedContainer<Key>(codingPath: codingPath)
        return KeyedEncodingContainer(container)
    }
    
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        // Keyed values require JSON encoding: we need to throw
        // JSONRequiredError. Since we can't throw right from here, let's
        // delegate the job to a dedicated container.
        return JSONRequiredEncoder<Record>(codingPath: codingPath)
    }
    
    func singleValueContainer() -> SingleValueEncodingContainer {
        return self
    }
}

extension ColumnEncoder: SingleValueEncodingContainer {
    func encodeNil() throws { recordEncoder.encode(nil, forKey: key) }
    
    func encode(_ value: Bool  ) throws { recordEncoder.encode(value, forKey: key) }
    func encode(_ value: Int   ) throws { recordEncoder.encode(value, forKey: key) }
    func encode(_ value: Int8  ) throws { recordEncoder.encode(value, forKey: key) }
    func encode(_ value: Int16 ) throws { recordEncoder.encode(value, forKey: key) }
    func encode(_ value: Int32 ) throws { recordEncoder.encode(value, forKey: key) }
    func encode(_ value: Int64 ) throws { recordEncoder.encode(value, forKey: key) }
    func encode(_ value: UInt  ) throws { recordEncoder.encode(value, forKey: key) }
    func encode(_ value: UInt8 ) throws { recordEncoder.encode(value, forKey: key) }
    func encode(_ value: UInt16) throws { recordEncoder.encode(value, forKey: key) }
    func encode(_ value: UInt32) throws { recordEncoder.encode(value, forKey: key) }
    func encode(_ value: UInt64) throws { recordEncoder.encode(value, forKey: key) }
    func encode(_ value: Float ) throws { recordEncoder.encode(value, forKey: key) }
    func encode(_ value: Double) throws { recordEncoder.encode(value, forKey: key) }
    func encode(_ value: String) throws { recordEncoder.encode(value, forKey: key) }
    
    func encode<T>(_ value: T) throws where T : Encodable {
        if let value = value as? DatabaseValueConvertible {
            // Prefer DatabaseValueConvertible encoding over Decodable.
            // This allows us to encode Date as String, for example.
            recordEncoder.encode(value.databaseValue, forKey: key)
        } else {
            do {
                // This encoding will fail for types that encode into keyed
                // or unkeyed containers, because we're encoding a single
                // value here (string, int, double, data, null). If such an
                // error happens, we'll switch to JSON encoding.
                let encoder = ColumnEncoder(recordEncoder: recordEncoder, key: key)
                try value.encode(to: encoder)
            } catch is JSONRequiredError {
                // Encode to JSON
                let jsonData = try Record.databaseJSONEncoder(for: key.stringValue).encode(value)
                
                // Store JSON String in the database for easier debugging and
                // database inspection. Thanks to SQLite weak typing, we won't
                // have any trouble decoding this string into data when we
                // eventually perform JSON decoding.
                // TODO: possible optimization: avoid this conversion to string, and store raw data bytes as an SQLite string
                let jsonString = String(data: jsonData, encoding: .utf8)! // force unwrap because json data is guaranteed to convert to String
                recordEncoder.encode(jsonString, forKey: key)
            }
        }
    }
}

// MARK: - JSONRequiredEncoder

/// The error that triggers JSON encoding
private struct JSONRequiredError: Error { }

/// The encoder that always ends up with a JSONRequiredError
private struct JSONRequiredEncoder<Record: MutablePersistableRecord>: Encoder {
    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any] { return Record.databaseEncodingUserInfo }
    
    init(codingPath: [CodingKey]) {
        self.codingPath = codingPath
    }
    
    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
        let container = KeyedContainer<Key>(codingPath: codingPath)
        return KeyedEncodingContainer(container)
    }
    
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        return self
    }
    
    func singleValueContainer() -> SingleValueEncodingContainer {
        return self
    }
    
    struct KeyedContainer<KeyType: CodingKey>: KeyedEncodingContainerProtocol {
        var codingPath: [CodingKey]
        var userInfo: [CodingUserInfoKey: Any] { return Record.databaseEncodingUserInfo }
        
        func encodeNil(forKey key: KeyType) throws { throw JSONRequiredError() }
        func encode(_ value: Bool,   forKey key: KeyType) throws { throw JSONRequiredError() }
        func encode(_ value: Int,    forKey key: KeyType) throws { throw JSONRequiredError() }
        func encode(_ value: Int8,   forKey key: KeyType) throws { throw JSONRequiredError() }
        func encode(_ value: Int16,  forKey key: KeyType) throws { throw JSONRequiredError() }
        func encode(_ value: Int32,  forKey key: KeyType) throws { throw JSONRequiredError() }
        func encode(_ value: Int64,  forKey key: KeyType) throws { throw JSONRequiredError() }
        func encode(_ value: UInt,   forKey key: KeyType) throws { throw JSONRequiredError() }
        func encode(_ value: UInt8,  forKey key: KeyType) throws { throw JSONRequiredError() }
        func encode(_ value: UInt16, forKey key: KeyType) throws { throw JSONRequiredError() }
        func encode(_ value: UInt32, forKey key: KeyType) throws { throw JSONRequiredError() }
        func encode(_ value: UInt64, forKey key: KeyType) throws { throw JSONRequiredError() }
        func encode(_ value: Float,  forKey key: KeyType) throws { throw JSONRequiredError() }
        func encode(_ value: Double, forKey key: KeyType) throws { throw JSONRequiredError() }
        func encode(_ value: String, forKey key: KeyType) throws { throw JSONRequiredError() }
        func encode<T>(_ value: T, forKey key: KeyType) throws where T : Encodable { throw JSONRequiredError() }
        
        func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: KeyType) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
            let container = KeyedContainer<NestedKey>(codingPath: codingPath + [key])
            return KeyedEncodingContainer(container)
        }
        
        func nestedUnkeyedContainer(forKey key: KeyType) -> UnkeyedEncodingContainer {
            return JSONRequiredEncoder(codingPath: codingPath)
        }
        
        func superEncoder() -> Encoder {
            return JSONRequiredEncoder(codingPath: codingPath)
        }
        
        func superEncoder(forKey key: KeyType) -> Encoder {
            return JSONRequiredEncoder(codingPath: codingPath)
        }
    }
}

extension JSONRequiredEncoder: SingleValueEncodingContainer {
    func encodeNil() throws { throw JSONRequiredError() }
    func encode(_ value: Bool  ) throws { throw JSONRequiredError() }
    func encode(_ value: Int   ) throws { throw JSONRequiredError() }
    func encode(_ value: Int8  ) throws { throw JSONRequiredError() }
    func encode(_ value: Int16 ) throws { throw JSONRequiredError() }
    func encode(_ value: Int32 ) throws { throw JSONRequiredError() }
    func encode(_ value: Int64 ) throws { throw JSONRequiredError() }
    func encode(_ value: UInt  ) throws { throw JSONRequiredError() }
    func encode(_ value: UInt8 ) throws { throw JSONRequiredError() }
    func encode(_ value: UInt16) throws { throw JSONRequiredError() }
    func encode(_ value: UInt32) throws { throw JSONRequiredError() }
    func encode(_ value: UInt64) throws { throw JSONRequiredError() }
    func encode(_ value: Float ) throws { throw JSONRequiredError() }
    func encode(_ value: Double) throws { throw JSONRequiredError() }
    func encode(_ value: String) throws { throw JSONRequiredError() }
    func encode<T>(_ value: T) throws where T : Encodable { throw JSONRequiredError() }
}

extension JSONRequiredEncoder: UnkeyedEncodingContainer {
    var count: Int { return 0 }
    
    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        let container = KeyedContainer<NestedKey>(codingPath: codingPath)
        return KeyedEncodingContainer(container)
    }
    
    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        return self
    }
    
    mutating func superEncoder() -> Encoder {
        return self
    }
}

extension MutablePersistableRecord where Self: Encodable {
    public func encode(to container: inout PersistenceContainer) {
        let encoder = RecordEncoder<Self>()
        try! encode(to: encoder)
        container = encoder.persistenceContainer
    }
}

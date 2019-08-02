import Foundation

extension EncodableRecord where Self: Encodable {
    public func encode(to container: inout PersistenceContainer) {
        let encoder = RecordEncoder<Self>(persistenceContainer: container)
        try! encode(to: encoder)
        container = encoder.persistenceContainer
    }
}

// MARK: - RecordEncoder

/// The encoder that encodes a record into GRDB's PersistenceContainer
private class RecordEncoder<Record: EncodableRecord>: Encoder {
    var codingPath: [CodingKey] { return [] }
    var userInfo: [CodingUserInfoKey: Any] { return Record.databaseEncodingUserInfo }
    private var _persistenceContainer: PersistenceContainer
    var persistenceContainer: PersistenceContainer { return _persistenceContainer }
    
    init(persistenceContainer: PersistenceContainer) {
        _persistenceContainer = persistenceContainer
    }
    
    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        let container = KeyedContainer<Key>(recordEncoder: self)
        return KeyedEncodingContainer(container)
    }
    
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        fatalError("unkeyed encoding is not supported")
    }
    
    func singleValueContainer() -> SingleValueEncodingContainer {
        // @itaiferber on https://forums.swift.org/t/how-to-encode-objects-of-unknown-type/12253/11
        //
        // > Encoding a value into a single-value container is equivalent to
        // > encoding the value directly into the encoder, with the primary
        // > difference being the above: encoding into the encoder writes the
        // > contents of a type into the encoder, while encoding to a
        // > single-value container gives the encoder a chance to intercept the
        // > type as a whole.
        //
        // Wait for somebody hitting this fatal error so that we can write a
        // meaningful regression test.
        fatalError("single value encoding is not supported")
    }
    
    private struct KeyedContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
        var recordEncoder: RecordEncoder
        var userInfo: [CodingUserInfoKey: Any] { return Record.databaseEncodingUserInfo }
        
        init(recordEncoder: RecordEncoder) {
            self.recordEncoder = recordEncoder
        }
        
        var codingPath: [CodingKey] { return [] }
        
        // swiftlint:disable comma
        func encode(_ value: Bool,   forKey key: Key) throws { recordEncoder.persist(value, forKey: key) }
        func encode(_ value: Int,    forKey key: Key) throws { recordEncoder.persist(value, forKey: key) }
        func encode(_ value: Int8,   forKey key: Key) throws { recordEncoder.persist(value, forKey: key) }
        func encode(_ value: Int16,  forKey key: Key) throws { recordEncoder.persist(value, forKey: key) }
        func encode(_ value: Int32,  forKey key: Key) throws { recordEncoder.persist(value, forKey: key) }
        func encode(_ value: Int64,  forKey key: Key) throws { recordEncoder.persist(value, forKey: key) }
        func encode(_ value: UInt,   forKey key: Key) throws { recordEncoder.persist(value, forKey: key) }
        func encode(_ value: UInt8,  forKey key: Key) throws { recordEncoder.persist(value, forKey: key) }
        func encode(_ value: UInt16, forKey key: Key) throws { recordEncoder.persist(value, forKey: key) }
        func encode(_ value: UInt32, forKey key: Key) throws { recordEncoder.persist(value, forKey: key) }
        func encode(_ value: UInt64, forKey key: Key) throws { recordEncoder.persist(value, forKey: key) }
        func encode(_ value: Float,  forKey key: Key) throws { recordEncoder.persist(value, forKey: key) }
        func encode(_ value: Double, forKey key: Key) throws { recordEncoder.persist(value, forKey: key) }
        func encode(_ value: String, forKey key: Key) throws { recordEncoder.persist(value, forKey: key) }
        // swiftlint:enable comma
        
        func encode<T>(_ value: T, forKey key: Key) throws where T: Encodable {
            try recordEncoder.encode(value, forKey: key)
        }
        
        func encodeNil(forKey key: Key) throws { recordEncoder.persist(nil, forKey: key) }
        
        // swiftlint:disable comma
        func encodeIfPresent(_ value: Bool?,   forKey key: Key) throws { recordEncoder.persist(value, forKey: key) }
        func encodeIfPresent(_ value: Int?,    forKey key: Key) throws { recordEncoder.persist(value, forKey: key) }
        func encodeIfPresent(_ value: Int8?,   forKey key: Key) throws { recordEncoder.persist(value, forKey: key) }
        func encodeIfPresent(_ value: Int16?,  forKey key: Key) throws { recordEncoder.persist(value, forKey: key) }
        func encodeIfPresent(_ value: Int32?,  forKey key: Key) throws { recordEncoder.persist(value, forKey: key) }
        func encodeIfPresent(_ value: Int64?,  forKey key: Key) throws { recordEncoder.persist(value, forKey: key) }
        func encodeIfPresent(_ value: UInt?,   forKey key: Key) throws { recordEncoder.persist(value, forKey: key) }
        func encodeIfPresent(_ value: UInt8?,  forKey key: Key) throws { recordEncoder.persist(value, forKey: key) }
        func encodeIfPresent(_ value: UInt16?, forKey key: Key) throws { recordEncoder.persist(value, forKey: key) }
        func encodeIfPresent(_ value: UInt32?, forKey key: Key) throws { recordEncoder.persist(value, forKey: key) }
        func encodeIfPresent(_ value: UInt64?, forKey key: Key) throws { recordEncoder.persist(value, forKey: key) }
        func encodeIfPresent(_ value: Float?,  forKey key: Key) throws { recordEncoder.persist(value, forKey: key) }
        func encodeIfPresent(_ value: Double?, forKey key: Key) throws { recordEncoder.persist(value, forKey: key) }
        func encodeIfPresent(_ value: String?, forKey key: Key) throws { recordEncoder.persist(value, forKey: key) }
        // swiftlint:disable comma
        
        func encodeIfPresent<T>(_ value: T?, forKey key: Key) throws where T: Encodable {
            if let value = value {
                try recordEncoder.encode(value, forKey: key)
            } else {
                recordEncoder.persist(nil, forKey: key)
            }
        }
        
        func nestedContainer<NestedKey>(
            keyedBy keyType: NestedKey.Type,
            forKey key: Key)
            -> KeyedEncodingContainer<NestedKey>
        {
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
    
    /// Helper methods
    @inline(__always)
    fileprivate func persist(_ value: DatabaseValueConvertible?, forKey key: CodingKey) {
        _persistenceContainer[key.stringValue] = value
    }
    
    @inline(__always)
    fileprivate func encode<T>(_ value: T, forKey key: CodingKey) throws where T: Encodable {
        if let date = value as? Date {
            persist(Record.databaseDateEncodingStrategy.encode(date), forKey: key)
        } else if let uuid = value as? UUID {
            persist(Record.databaseUUIDEncodingStrategy.encode(uuid), forKey: key)
        } else if let value = value as? DatabaseValueConvertible {
            // Prefer DatabaseValueConvertible encoding over Decodable.
            persist(value.databaseValue, forKey: key)
        } else {
            do {
                // This encoding will fail for types that encode into keyed
                // or unkeyed containers, because we're encoding a single
                // value here (string, int, double, data, null). If such an
                // error happens, we'll switch to JSON encoding.
                let encoder = ColumnEncoder(recordEncoder: self, key: key)
                try value.encode(to: encoder)
                if encoder.requiresJSON {
                    // Here we handle empty arrays and dictionaries.
                    throw JSONRequiredError()
                }
            } catch is JSONRequiredError {
                // Encode to JSON
                let jsonData = try Record.databaseJSONEncoder(for: key.stringValue).encode(value)
                
                // Store JSON String in the database for easier debugging and
                // database inspection. Thanks to SQLite weak typing, we won't
                // have any trouble decoding this string into data when we
                // eventually perform JSON decoding.
                // TODO: possible optimization: avoid this conversion to string,
                // and store raw data bytes as an SQLite string
                let jsonString = String(data: jsonData, encoding: .utf8)!
                persist(jsonString, forKey: key)
            }
        }
    }
}

// MARK: - ColumnEncoder

/// The encoder that encodes into a database column
private class ColumnEncoder<Record: EncodableRecord>: Encoder {
    var recordEncoder: RecordEncoder<Record>
    var key: CodingKey
    var codingPath: [CodingKey] { return [key] }
    var userInfo: [CodingUserInfoKey: Any] { return Record.databaseEncodingUserInfo }
    var requiresJSON = false
    
    init(recordEncoder: RecordEncoder<Record>, key: CodingKey) {
        self.recordEncoder = recordEncoder
        self.key = key
    }
    
    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key: CodingKey {
        // Keyed values require JSON encoding: we need to throw
        // JSONRequiredError. Since we can't throw right from here, let's
        // delegate the job to a dedicated container.
        requiresJSON = true
        let container = JSONRequiredEncoder<Record>.KeyedContainer<Key>(codingPath: codingPath)
        return KeyedEncodingContainer(container)
    }
    
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        // Keyed values require JSON encoding: we need to throw
        // JSONRequiredError. Since we can't throw right from here, let's
        // delegate the job to a dedicated container.
        requiresJSON = true
        return JSONRequiredEncoder<Record>(codingPath: codingPath)
    }
    
    func singleValueContainer() -> SingleValueEncodingContainer {
        return self
    }
}

extension ColumnEncoder: SingleValueEncodingContainer {
    func encodeNil() throws { recordEncoder.persist(nil, forKey: key) }
    
    func encode(_ value: Bool  ) throws { recordEncoder.persist(value, forKey: key) }
    func encode(_ value: Int   ) throws { recordEncoder.persist(value, forKey: key) }
    func encode(_ value: Int8  ) throws { recordEncoder.persist(value, forKey: key) }
    func encode(_ value: Int16 ) throws { recordEncoder.persist(value, forKey: key) }
    func encode(_ value: Int32 ) throws { recordEncoder.persist(value, forKey: key) }
    func encode(_ value: Int64 ) throws { recordEncoder.persist(value, forKey: key) }
    func encode(_ value: UInt  ) throws { recordEncoder.persist(value, forKey: key) }
    func encode(_ value: UInt8 ) throws { recordEncoder.persist(value, forKey: key) }
    func encode(_ value: UInt16) throws { recordEncoder.persist(value, forKey: key) }
    func encode(_ value: UInt32) throws { recordEncoder.persist(value, forKey: key) }
    func encode(_ value: UInt64) throws { recordEncoder.persist(value, forKey: key) }
    func encode(_ value: Float ) throws { recordEncoder.persist(value, forKey: key) }
    func encode(_ value: Double) throws { recordEncoder.persist(value, forKey: key) }
    func encode(_ value: String) throws { recordEncoder.persist(value, forKey: key) }
    
    func encode<T>(_ value: T) throws where T: Encodable {
        try recordEncoder.encode(value, forKey: key)
    }
}

// MARK: - JSONRequiredEncoder

/// The error that triggers JSON encoding
private struct JSONRequiredError: Error { }

/// The encoder that always ends up with a JSONRequiredError
private struct JSONRequiredEncoder<Record: EncodableRecord>: Encoder {
    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any] { return Record.databaseEncodingUserInfo }
    
    init(codingPath: [CodingKey]) {
        self.codingPath = codingPath
    }
    
    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key: CodingKey {
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
        func encode<T>(_ value: T, forKey key: KeyType) throws where T: Encodable { throw JSONRequiredError() }
        
        func nestedContainer<NestedKey>(
            keyedBy keyType: NestedKey.Type,
            forKey key: KeyType)
            -> KeyedEncodingContainer<NestedKey>
            where NestedKey: CodingKey
        {
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
    func encode<T>(_ value: T) throws where T: Encodable { throw JSONRequiredError() }
}

extension JSONRequiredEncoder: UnkeyedEncodingContainer {
    var count: Int { return 0 }
    
    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type)
        -> KeyedEncodingContainer<NestedKey>
        where NestedKey: CodingKey
    {
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

@available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
private var iso8601Formatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = .withInternetDateTime
    return formatter
}()

extension DatabaseDateEncodingStrategy {
    @inline(__always)
    fileprivate func encode(_ date: Date) -> DatabaseValueConvertible? {
        switch self {
        case .deferredToDate:
            return date.databaseValue
        case .timeIntervalSinceReferenceDate:
            return date.timeIntervalSinceReferenceDate
        case .timeIntervalSince1970:
            return date.timeIntervalSince1970
        case .millisecondsSince1970:
            return Int64(floor(1000.0 * date.timeIntervalSince1970))
        case .secondsSince1970:
            return Int64(floor(date.timeIntervalSince1970))
        case .iso8601:
            if #available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *) {
                return iso8601Formatter.string(from: date)
            } else {
                fatalError("ISO8601DateFormatter is unavailable on this platform.")
            }
        case .formatted(let formatter):
            return formatter.string(from: date)
        case .custom(let format):
            return format(date)
        }
    }
}

extension DatabaseUUIDEncodingStrategy {
    @inline(__always)
    fileprivate func encode(_ uuid: UUID) -> DatabaseValueConvertible? {
        switch self {
        case .deferredToUUID:
            return uuid.databaseValue
        case .string:
            return uuid.uuidString
        }
    }
}

import Foundation

extension EncodableRecord where Self: Encodable {
    /// Encodes the record into the provided persistence container, using the
    /// `Encodable` conformance.
    public func encode(to container: inout PersistenceContainer) throws {
        let encoder = RecordEncoder<Self>(persistenceContainer: container)
        try encode(to: encoder)
        container = encoder.persistenceContainer
    }
}

// MARK: - RecordEncoder

/// The encoder that encodes a record into GRDB's PersistenceContainer
private class RecordEncoder<Record: EncodableRecord>: Encoder {
    var codingPath: [any CodingKey] { [] }
    var userInfo: [CodingUserInfoKey: Any] { Record.databaseEncodingUserInfo }
    private var _persistenceContainer: PersistenceContainer
    var persistenceContainer: PersistenceContainer { _persistenceContainer }
    var keyEncodingStrategy: DatabaseColumnEncodingStrategy { Record.databaseColumnEncodingStrategy }
    
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
        self
    }
    
    private struct KeyedContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
        var recordEncoder: RecordEncoder
        var userInfo: [CodingUserInfoKey: Any] { Record.databaseEncodingUserInfo }
        var codingPath: [any CodingKey] { [] }
        
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
        // swiftlint:enable comma
        
        func encodeIfPresent<T>(_ value: T?, forKey key: Key) throws where T: Encodable {
            if let value {
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
            recordEncoder
        }
        
        func superEncoder(forKey key: Key) -> Encoder {
            recordEncoder
        }
    }
    
    /// Helper methods
    fileprivate func persist(_ value: (any DatabaseValueConvertible)?, forKey key: any CodingKey) {
        _persistenceContainer[keyEncodingStrategy.column(forKey: key)] = value
    }
    
    fileprivate func encode<T>(_ value: T, forKey key: any CodingKey) throws where T: Encodable {
        if let data = value as? Data {
            let column = keyEncodingStrategy.column(forKey: key)
            let dbValue = try Record.databaseDataEncodingStrategy(for: column).encode(data)
            _persistenceContainer[column] = dbValue
        } else if let date = value as? Date {
            let column = keyEncodingStrategy.column(forKey: key)
            let dbValue = Record.databaseDateEncodingStrategy(for: column).encode(date)
            _persistenceContainer[column] = dbValue
        } else if let uuid = value as? UUID {
            let column = keyEncodingStrategy.column(forKey: key)
            let dbValue = Record.databaseUUIDEncodingStrategy(for: column).encode(uuid)
            _persistenceContainer[column] = dbValue
        } else if let value = value as? any DatabaseValueConvertible {
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
                try autoreleasepool {
                    
                    let jsonData = try Record.databaseJSONEncoder(for: key.stringValue).encode(value)
                    
                    // Store JSON String in the database for easier debugging and
                    // database inspection. Thanks to SQLite weak typing, we won't
                    // have any trouble decoding this string into data when we
                    // eventually perform JSON decoding.
                    // TODO: possible optimization: avoid this conversion to string,
                    // and store raw data bytes as an SQLite string
                    let jsonString = String(decoding: jsonData, as: UTF8.self)
                    persist(jsonString, forKey: key)
                }
            }
        }
    }
}

extension RecordEncoder: SingleValueEncodingContainer {
    private func unsupportedSingleValueEncoding() {
        fatalError("Can't encode a single value in a database row.")
    }
    
    func encodeNil() throws {
        unsupportedSingleValueEncoding()
    }
    
    func encode(_ value: Bool) throws {
        unsupportedSingleValueEncoding()
    }
    
    func encode(_ value: String) throws {
        unsupportedSingleValueEncoding()
    }
    
    func encode(_ value: Double) throws {
        unsupportedSingleValueEncoding()
    }
    
    func encode(_ value: Float) throws {
        unsupportedSingleValueEncoding()
    }
    
    func encode(_ value: Int) throws {
        unsupportedSingleValueEncoding()
    }
    
    func encode(_ value: Int8) throws {
        unsupportedSingleValueEncoding()
    }
    
    func encode(_ value: Int16) throws {
        unsupportedSingleValueEncoding()
    }
    
    func encode(_ value: Int32) throws {
        unsupportedSingleValueEncoding()
    }
    
    func encode(_ value: Int64) throws {
        unsupportedSingleValueEncoding()
    }
    
    func encode(_ value: UInt) throws {
        unsupportedSingleValueEncoding()
    }
    
    func encode(_ value: UInt8) throws {
        unsupportedSingleValueEncoding()
    }
    
    func encode(_ value: UInt16) throws {
        unsupportedSingleValueEncoding()
    }
    
    func encode(_ value: UInt32) throws {
        unsupportedSingleValueEncoding()
    }
    
    func encode(_ value: UInt64) throws {
        unsupportedSingleValueEncoding()
    }
    
    func encode<T>(_ value: T) throws where T: Encodable {
        if let record = value as? EncodableRecord {
            try record.encode(to: &_persistenceContainer)
        } else {
            try value.encode(to: self)
        }
    }
}

// MARK: - ColumnEncoder

/// The encoder that encodes into a database column
private class ColumnEncoder<Record: EncodableRecord>: Encoder {
    var recordEncoder: RecordEncoder<Record>
    var key: any CodingKey
    var codingPath: [any CodingKey] { [key] }
    var userInfo: [CodingUserInfoKey: Any] { Record.databaseEncodingUserInfo }
    var requiresJSON = false
    
    init(recordEncoder: RecordEncoder<Record>, key: some CodingKey) {
        self.recordEncoder = recordEncoder
        self.key = key
    }
    
    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key: CodingKey {
        // We need to perform JSON encoding. Unfortunately we can't access the
        // inner container of Foundation's JSONEncoder. At this point we must
        // throw an error so that the caller can retry encoding from scratch.
        // Unfortunately (bis), we can't throw right from here, so let's
        // return a JSONRequiredEncoder that will throw as soon as possible.
        requiresJSON = true
        let container = JSONRequiredEncoder.KeyedContainer<Key>(codingPath: codingPath)
        return KeyedEncodingContainer(container)
    }
    
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        // We need to perform JSON encoding. Unfortunately we can't access the
        // inner container of Foundation's JSONEncoder. At this point we must
        // throw an error so that the caller can retry encoding from scratch.
        // Unfortunately (bis), we can't throw right from here, so let's
        // return a JSONRequiredEncoder that will throw as soon as possible.
        requiresJSON = true
        return JSONRequiredEncoder(codingPath: codingPath)
    }
    
    func singleValueContainer() -> SingleValueEncodingContainer { self }
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

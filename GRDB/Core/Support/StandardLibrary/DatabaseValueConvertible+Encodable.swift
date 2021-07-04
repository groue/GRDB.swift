import Foundation

private struct DatabaseValueEncodingContainer: SingleValueEncodingContainer {
    let encode: (DatabaseValue) -> Void
    
    var codingPath: [CodingKey] { [] }
    
    /// Encodes a null value.
    ///
    /// - throws: `EncodingError.invalidValue` if a null value is invalid in the current context for this format.
    /// - precondition: May not be called after a previous `self.encode(_:)` call.
    mutating func encodeNil() throws { encode(.null) }
    
    /// Encodes a single value of the given type.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    /// - precondition: May not be called after a previous `self.encode(_:)` call.
    mutating func encode(_ value: Bool) throws { encode(value.databaseValue) }
    mutating func encode(_ value: Int) throws { encode(value.databaseValue) }
    mutating func encode(_ value: Int8) throws { encode(value.databaseValue) }
    mutating func encode(_ value: Int16) throws { encode(value.databaseValue) }
    mutating func encode(_ value: Int32) throws { encode(value.databaseValue) }
    mutating func encode(_ value: Int64) throws { encode(value.databaseValue) }
    mutating func encode(_ value: UInt) throws { encode(value.databaseValue) }
    mutating func encode(_ value: UInt8) throws { encode(value.databaseValue) }
    mutating func encode(_ value: UInt16) throws { encode(value.databaseValue) }
    mutating func encode(_ value: UInt32) throws { encode(value.databaseValue) }
    mutating func encode(_ value: UInt64) throws { encode(value.databaseValue) }
    mutating func encode(_ value: Float) throws { encode(value.databaseValue) }
    mutating func encode(_ value: Double) throws { encode(value.databaseValue) }
    mutating func encode(_ value: String) throws { encode(value.databaseValue) }
    
    /// Encodes a single value of the given type.
    ///
    /// - parameter value: The value to encode.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in the current context for this format.
    /// - precondition: May not be called after a previous `self.encode(_:)` call.
    mutating func encode<T>(_ value: T) throws where T: Encodable {
        if let dbValueConvertible = value as? DatabaseValueConvertible {
            // Prefer DatabaseValueConvertible encoding over Decodable.
            // This allows us to encode Date as String, for example.
            encode(dbValueConvertible.databaseValue)
        } else {
            try DatabaseValueEncoder(encode: encode).encode(value)
        }
    }
}

private class DatabaseValueEncoder: Encoder {
    let encode: (DatabaseValue) -> Void
    var requiresJSON = false
    
    init(encode: @escaping (DatabaseValue) -> Void) {
        self.encode = encode
    }
    
    /// The path of coding keys taken to get to this point in encoding.
    /// A `nil` value indicates an unkeyed container.
    var codingPath: [CodingKey] { [] }
    
    /// Any contextual information set by the user for encoding.
    var userInfo: [CodingUserInfoKey: Any] = [:]
    
    /// Returns an encoding container appropriate for holding multiple values keyed by the given key type.
    ///
    /// - parameter type: The key type to use for the container.
    /// - returns: A new keyed encoding container.
    /// - precondition: May not be called after a prior `self.unkeyedContainer()` call.
    /// - precondition: May not be called after a value has been encoded through
    ///   a previous `self.singleValueContainer()` call.
    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        // We need to perform JSON encoding. Unfortunately we can't access the
        // inner container of Foundation's JSONEncoder. At this point we must
        // throw an error so that the caller can retry encoding from scratch.
        // Unfortunately (bis), we can't throw right from here, so let's
        // return a JSONRequiredEncoder that will throw as soon as possible.
        requiresJSON = true
        let container = JSONRequiredEncoder.KeyedContainer<Key>(codingPath: codingPath)
        return KeyedEncodingContainer(container)
    }
    
    /// Returns an encoding container appropriate for holding multiple unkeyed values.
    ///
    /// - returns: A new empty unkeyed container.
    /// - precondition: May not be called after a prior `self.container(keyedBy:)` call.
    /// - precondition: May not be called after a value has been encoded through
    ///   a previous `self.singleValueContainer()` call.
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        // We need to perform JSON encoding. Unfortunately we can't access the
        // inner container of Foundation's JSONEncoder. At this point we must
        // throw an error so that the caller can retry encoding from scratch.
        // Unfortunately (bis), we can't throw right from here, so let's
        // return a JSONRequiredEncoder that will throw as soon as possible.
        requiresJSON = true
        return JSONRequiredEncoder(codingPath: codingPath)
    }
    
    /// Returns an encoding container appropriate for holding a single primitive value.
    ///
    /// - returns: A new empty single value container.
    /// - precondition: May not be called after a prior `self.container(keyedBy:)` call.
    /// - precondition: May not be called after a prior `self.unkeyedContainer()` call.
    /// - precondition: May not be called after a value has been encoded through
    ///   a previous `self.singleValueContainer()` call.
    func singleValueContainer() -> SingleValueEncodingContainer {
        DatabaseValueEncodingContainer(encode: encode)
    }
    
    func encode<T: Encodable>(_ value: T) throws {
        do {
            try value.encode(to: self)
            if requiresJSON {
                // Here we handle empty arrays and dictionaries.
                throw JSONRequiredError()
            }
        } catch is JSONRequiredError {
            let encoder = JSONEncoder()
            encoder.dataEncodingStrategy = .base64
            encoder.dateEncodingStrategy = .millisecondsSince1970
            encoder.nonConformingFloatEncodingStrategy = .throw
            if #available(watchOS 4.0, OSX 10.13, iOS 11.0, tvOS 11.0, *) {
                // guarantee some stability in order to ease value comparison
                encoder.outputFormatting = .sortedKeys
            }
            let jsonData = try encoder.encode(value)
            
            // Store JSON String in the database for easier debugging and
            // database inspection. Thanks to SQLite weak typing, we won't
            // have any trouble decoding this string into data when we
            // eventually perform JSON decoding.
            // TODO: possible optimization: avoid this conversion to string,
            // and store raw data bytes as an SQLite string
            let jsonString = String(data: jsonData, encoding: .utf8)!
            try jsonString.encode(to: self)
        }
    }
}

extension DatabaseValueConvertible where Self: Encodable {
    public var databaseValue: DatabaseValue {
        var dbValue: DatabaseValue! = nil
        try! DatabaseValueEncoder(encode: { dbValue = $0 }).encode(self)
        return dbValue
    }
}

extension DatabaseValueConvertible where Self: Encodable & RawRepresentable, Self.RawValue: DatabaseValueConvertible {
    public var databaseValue: DatabaseValue {
        // Preserve custom database encoding
        return rawValue.databaseValue
    }
}

import Foundation

private struct DatabaseValueDecodingContainer: SingleValueDecodingContainer {
    let dbValue: DatabaseValue
    let codingPath: [CodingKey]
    
    /// Decodes a null value.
    ///
    /// - returns: Whether the encountered value was null.
    func decodeNil() -> Bool { dbValue.isNull }
    
    /// Decodes a single value of the given type.
    ///
    /// - parameter type: The type to decode as.
    /// - returns: A value of the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   cannot be converted to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value is null.
    func decode(_ type: Bool.Type) throws -> Bool {
        if let result = Bool.fromDatabaseValue(dbValue) {
            return result
        } else {
            throw DecodingError.dataCorruptedError(in: self, debugDescription: "value mismatch")
        }
    }
    
    func decode(_ type: Int.Type) throws -> Int {
        if let result = Int.fromDatabaseValue(dbValue) {
            return result
        } else {
            throw DecodingError.dataCorruptedError(in: self, debugDescription: "value mismatch")
        }
    }
    
    func decode(_ type: Int8.Type) throws -> Int8 {
        if let result = Int8.fromDatabaseValue(dbValue) {
            return result
        } else {
            throw DecodingError.dataCorruptedError(in: self, debugDescription: "value mismatch")
        }
    }
    
    func decode(_ type: Int16.Type) throws -> Int16 {
        if let result = Int16.fromDatabaseValue(dbValue) {
            return result
        } else {
            throw DecodingError.dataCorruptedError(in: self, debugDescription: "value mismatch")
        }
    }
    
    func decode(_ type: Int32.Type) throws -> Int32 {
        if let result = Int32.fromDatabaseValue(dbValue) {
            return result
        } else {
            throw DecodingError.dataCorruptedError(in: self, debugDescription: "value mismatch")
        }
    }
    
    func decode(_ type: Int64.Type) throws -> Int64 {
        if let result = Int64.fromDatabaseValue(dbValue) {
            return result
        } else {
            throw DecodingError.dataCorruptedError(in: self, debugDescription: "value mismatch")
        }
    }
    
    func decode(_ type: UInt.Type) throws -> UInt {
        if let result = UInt.fromDatabaseValue(dbValue) {
            return result
        } else {
            throw DecodingError.dataCorruptedError(in: self, debugDescription: "value mismatch")
        }
    }
    
    func decode(_ type: UInt8.Type) throws -> UInt8 {
        if let result = UInt8.fromDatabaseValue(dbValue) {
            return result
        } else {
            throw DecodingError.dataCorruptedError(in: self, debugDescription: "value mismatch")
        }
    }
    
    func decode(_ type: UInt16.Type) throws -> UInt16 {
        if let result = UInt16.fromDatabaseValue(dbValue) {
            return result
        } else {
            throw DecodingError.dataCorruptedError(in: self, debugDescription: "value mismatch")
        }
    }
    
    func decode(_ type: UInt32.Type) throws -> UInt32 {
        if let result = UInt32.fromDatabaseValue(dbValue) {
            return result
        } else {
            throw DecodingError.dataCorruptedError(in: self, debugDescription: "value mismatch")
        }
    }
    
    func decode(_ type: UInt64.Type) throws -> UInt64 {
        if let result = UInt64.fromDatabaseValue(dbValue) {
            return result
        } else {
            throw DecodingError.dataCorruptedError(in: self, debugDescription: "value mismatch")
        }
    }
    
    func decode(_ type: Float.Type) throws -> Float {
        if let result = Float.fromDatabaseValue(dbValue) {
            return result
        } else {
            throw DecodingError.dataCorruptedError(in: self, debugDescription: "value mismatch")
        }
    }
    
    func decode(_ type: Double.Type) throws -> Double {
        if let result = Double.fromDatabaseValue(dbValue) {
            return result
        } else {
            throw DecodingError.dataCorruptedError(in: self, debugDescription: "value mismatch")
        }
    }
    
    func decode(_ type: String.Type) throws -> String {
        if let result = String.fromDatabaseValue(dbValue) {
            return result
        } else {
            throw DecodingError.dataCorruptedError(in: self, debugDescription: "value mismatch")
        }
    }
    
    /// Decodes a single value of the given type.
    ///
    /// - parameter type: The type to decode as.
    /// - returns: A value of the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   cannot be converted to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value is null.
    func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        if let type = T.self as? DatabaseValueConvertible.Type {
            // Prefer DatabaseValueConvertible decoding over Decodable.
            // This allows custom database decoding, such as decoding Date from
            // String, for example.
            if let result = type.fromDatabaseValue(dbValue) {
                return result as! T
            } else {
                throw DecodingError.dataCorruptedError(in: self, debugDescription: "value mismatch")
            }
        } else {
            return try T(from: DatabaseValueDecoder(dbValue: dbValue, codingPath: codingPath))
        }
    }
}

private struct DatabaseValueDecoder: Decoder {
    let dbValue: DatabaseValue
    let codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any] { [:] }
    
    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        // We need to switch to JSON decoding
        throw JSONRequiredError()
    }
    
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        // We need to switch to JSON decoding
        throw JSONRequiredError()
    }
    
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        DatabaseValueDecodingContainer(dbValue: dbValue, codingPath: codingPath)
    }
}

extension DatabaseValueConvertible where Self: Decodable {
    public static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> Self? {
        do {
            return try self.init(from: DatabaseValueDecoder(dbValue: databaseValue, codingPath: []))
        } catch is JSONRequiredError {
            guard let data = Data.fromDatabaseValue(databaseValue) else {
                return nil
            }
            let decoder = JSONDecoder()
            decoder.dataDecodingStrategy = .base64
            decoder.dateDecodingStrategy = .millisecondsSince1970
            decoder.nonConformingFloatDecodingStrategy = .throw
            return try? decoder.decode(Self.self, from: data)
        } catch {
            return nil
        }
    }
}

extension DatabaseValueConvertible where Self: Decodable & RawRepresentable, Self.RawValue: DatabaseValueConvertible {
    public static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> Self? {
        // Preserve custom database decoding
        return RawValue.fromDatabaseValue(databaseValue).flatMap { self.init(rawValue: $0) }
    }
}

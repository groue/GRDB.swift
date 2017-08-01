private struct DatabaseValueDecodingContainer: SingleValueDecodingContainer {
    let dbValue: DatabaseValue
    let codingPath: [CodingKey]
    
    /// Decodes a null value.
    ///
    /// - returns: Whether the encountered value was null.
    func decodeNil() -> Bool {
        return dbValue.isNull
    }
    
    /// Decodes a single value of the given type.
    ///
    /// - parameter type: The type to decode as.
    /// - returns: A value of the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value cannot be converted to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value is null.
    func decode(_ type: Bool.Type) throws -> Bool { return dbValue.losslessConvert() }
    func decode(_ type: Int.Type) throws -> Int { return dbValue.losslessConvert() }
    func decode(_ type: Int8.Type) throws -> Int8 { return dbValue.losslessConvert() }
    func decode(_ type: Int16.Type) throws -> Int16 { return dbValue.losslessConvert() }
    func decode(_ type: Int32.Type) throws -> Int32 { return dbValue.losslessConvert() }
    func decode(_ type: Int64.Type) throws -> Int64 { return dbValue.losslessConvert() }
    func decode(_ type: UInt.Type) throws -> UInt { return dbValue.losslessConvert() }
    func decode(_ type: UInt8.Type) throws -> UInt8 { return dbValue.losslessConvert() }
    func decode(_ type: UInt16.Type) throws -> UInt16 { return dbValue.losslessConvert() }
    func decode(_ type: UInt32.Type) throws -> UInt32 { return dbValue.losslessConvert() }
    func decode(_ type: UInt64.Type) throws -> UInt64 { return dbValue.losslessConvert() }
    func decode(_ type: Float.Type) throws -> Float { return dbValue.losslessConvert() }
    func decode(_ type: Double.Type) throws -> Double { return dbValue.losslessConvert() }
    func decode(_ type: String.Type) throws -> String { return dbValue.losslessConvert() }
    
    /// Decodes a single value of the given type.
    ///
    /// - parameter type: The type to decode as.
    /// - returns: A value of the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value cannot be converted to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value is null.
    func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
        if let type = T.self as? DatabaseValueConvertible.Type {
            // Prefer DatabaseValueConvertible decoding over Decodable.
            // This allows custom database decoding, such as decoding Date from
            // String, for example.
            return type.fromDatabaseValue(dbValue) as! T
        } else {
            return try T(from: DatabaseValueDecoder(dbValue: dbValue, codingPath: codingPath))
        }
    }
}

private struct DatabaseValueDecoder: Decoder {
    let dbValue: DatabaseValue
    
    init(dbValue: DatabaseValue, codingPath: [CodingKey]) {
        self.dbValue = dbValue
        self.codingPath = codingPath
    }
    
    // Decoder
    let codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey : Any] { return [:] }
    
    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        throw DecodingError.typeMismatch(
            type,
            DecodingError.Context(codingPath: codingPath, debugDescription: "keyed decoding is not supported"))
    }
    
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        throw DecodingError.typeMismatch(
            UnkeyedDecodingContainer.self,
            DecodingError.Context(codingPath: codingPath, debugDescription: "unkeyed decoding is not supported"))
    }
    
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return DatabaseValueDecodingContainer(dbValue: dbValue, codingPath: codingPath)
    }
}

public extension DatabaseValueConvertible where Self: Decodable {
    public static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> Self? {
        return try? self.init(from: DatabaseValueDecoder(dbValue: databaseValue, codingPath: []))
    }
}

public extension DatabaseValueConvertible where Self: Decodable & RawRepresentable, Self.RawValue: DatabaseValueConvertible {
    public static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> Self? {
        // Preserve custom database decoding
        return RawValue.fromDatabaseValue(databaseValue).flatMap { self.init(rawValue: $0) }
    }
}

private struct RowKeyedDecodingContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let decoder: RowDecoder
    
    init(decoder: RowDecoder) {
        self.decoder = decoder
    }
    
    var codingPath: [CodingKey] { return decoder.codingPath }
    
    /// All the keys the `Decoder` has for this container.
    ///
    /// Different keyed containers from the same `Decoder` may return different keys here; it is possible to encode with multiple key types which are not convertible to one another. This should report all keys present which are convertible to the requested type.
    var allKeys: [Key] {
        let row = decoder.row
        let columnNames = Set(row.columnNames)
        let scopeNames = Set(row.scopesTree.names)
        return columnNames.union(scopeNames).compactMap { Key(stringValue: $0) }
    }
    
    /// Returns whether the `Decoder` contains a value associated with the given key.
    ///
    /// The value associated with the given key may be a null value as appropriate for the data format.
    ///
    /// - parameter key: The key to search for.
    /// - returns: Whether the `Decoder` has an entry for the given key.
    func contains(_ key: Key) -> Bool {
        let row = decoder.row
        return row.hasColumn(key.stringValue) || (row.scopesTree[key.stringValue] != nil)
    }
    
    /// Decodes a null value for the given key.
    ///
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: Whether the encountered value was null.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry for the given key.
    func decodeNil(forKey key: Key) throws -> Bool {
        let row = decoder.row
        return row[key.stringValue] == nil && (row.scopesTree[key.stringValue] == nil)
    }
    
    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for the given key.
    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool { return decoder.row[key.stringValue] }
    func decode(_ type: Int.Type, forKey key: Key) throws -> Int { return decoder.row[key.stringValue] }
    func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 { return decoder.row[key.stringValue] }
    func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 { return decoder.row[key.stringValue] }
    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 { return decoder.row[key.stringValue] }
    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 { return decoder.row[key.stringValue] }
    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt { return decoder.row[key.stringValue] }
    func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 { return decoder.row[key.stringValue] }
    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 { return decoder.row[key.stringValue] }
    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 { return decoder.row[key.stringValue] }
    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 { return decoder.row[key.stringValue] }
    func decode(_ type: Float.Type, forKey key: Key) throws -> Float { return decoder.row[key.stringValue] }
    func decode(_ type: Double.Type, forKey key: Key) throws -> Double { return decoder.row[key.stringValue] }
    func decode(_ type: String.Type, forKey key: Key) throws -> String { return decoder.row[key.stringValue] }
    
    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns nil if the container does not have a value
    /// associated with key, or if the value is null. The difference between
    /// these states can be distinguished with a contains(_:) call.
    func decodeIfPresent<T>(_ type: T.Type, forKey key: Key) throws -> T? where T : Decodable {
        let row = decoder.row
        
        // Column?
        if row.hasColumn(key.stringValue) {
            let dbValue: DatabaseValue = row[key.stringValue]
            if let type = T.self as? DatabaseValueConvertible.Type {
                // Prefer DatabaseValueConvertible decoding over Decodable.
                // This allows decoding Date from String, or DatabaseValue from NULL.
                return type.fromDatabaseValue(dbValue) as! T?
            } else if dbValue.isNull {
                return nil
            } else {
                return try T(from: RowDecoder(row: row, codingPath: codingPath + [key]))
            }
        }
        
        // Scope?
        if let scopedRow = row.scopesTree[key.stringValue], scopedRow.containsNonNullValue {
            if let type = T.self as? FetchableRecord.Type {
                // Prefer FetchableRecord decoding over Decodable.
                // This allows custom row decoding
                return (type.init(row: scopedRow) as! T)
            } else {
                return try T(from: RowDecoder(row: scopedRow, codingPath: codingPath + [key]))
            }
        }
        
        return nil
    }
    
    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for the given key.
    func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T : Decodable {
        let row = decoder.row
        
        // Column?
        if row.hasColumn(key.stringValue) {
            let dbValue: DatabaseValue = row[key.stringValue]
            if let type = T.self as? DatabaseValueConvertible.Type {
                // Prefer DatabaseValueConvertible decoding over Decodable.
                // This allows decoding Date from String, or DatabaseValue from NULL.
                return type.fromDatabaseValue(dbValue) as! T
            } else {
                return try T(from: RowDecoder(row: row, codingPath: codingPath + [key]))
            }
        }
        
        // Scope?
        if let scopedRow = row.scopesTree[key.stringValue] {
            if let type = T.self as? FetchableRecord.Type {
                // Prefer FetchableRecord decoding over Decodable.
                // This allows custom row decoding
                return type.init(row: scopedRow) as! T
            } else {
                return try T(from: RowDecoder(row: scopedRow, codingPath: codingPath + [key]))
            }
        }
        
        // Base row
        if let type = T.self as? FetchableRecord.Type {
            // Prefer FetchableRecord decoding over Decodable.
            // This allows custom row decoding
            return type.init(row: row) as! T
        } else {
            return try T(from: RowDecoder(row: row, codingPath: codingPath + [key]))
        }
    }
    
    /// Returns the data stored for the given key as represented in a container keyed by the given key type.
    ///
    /// - parameter type: The key type to use for the container.
    /// - parameter key: The key that the nested container is associated with.
    /// - returns: A keyed decoding container view into `self`.
    /// - throws: `DecodingError.typeMismatch` if the encountered stored value is not a keyed container.
    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        fatalError("not implemented")
    }
    
    /// Returns the data stored for the given key as represented in an unkeyed container.
    ///
    /// - parameter key: The key that the nested container is associated with.
    /// - returns: An unkeyed decoding container view into `self`.
    /// - throws: `DecodingError.typeMismatch` if the encountered stored value is not an unkeyed container.
    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        throw DecodingError.typeMismatch(
            UnkeyedDecodingContainer.self,
            DecodingError.Context(codingPath: codingPath, debugDescription: "unkeyed decoding is not supported"))
    }
    
    /// Returns a `Decoder` instance for decoding `super` from the container associated with the default `super` key.
    ///
    /// Equivalent to calling `superDecoder(forKey:)` with `Key(stringValue: "super", intValue: 0)`.
    ///
    /// - returns: A new `Decoder` to pass to `super.init(from:)`.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry for the default `super` key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for the default `super` key.
    public func superDecoder() throws -> Decoder {
        return decoder
    }
    
    /// Returns a `Decoder` instance for decoding `super` from the container associated with the given key.
    ///
    /// - parameter key: The key to decode `super` for.
    /// - returns: A new `Decoder` to pass to `super.init(from:)`.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for the given key.
    public func superDecoder(forKey key: Key) throws -> Decoder {
        return decoder
    }
}

private struct RowSingleValueDecodingContainer: SingleValueDecodingContainer {
    let row: Row
    var codingPath: [CodingKey]
    let column: CodingKey
    
    /// Decodes a null value.
    ///
    /// - returns: Whether the encountered value was null.
    func decodeNil() -> Bool {
        return row[column.stringValue] == nil
    }

    /// Decodes a single value of the given type.
    ///
    /// - parameter type: The type to decode as.
    /// - returns: A value of the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value cannot be converted to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value is null.
    func decode(_ type: Bool.Type) throws -> Bool { return row[column.stringValue] }
    func decode(_ type: Int.Type) throws -> Int { return row[column.stringValue] }
    func decode(_ type: Int8.Type) throws -> Int8 { return row[column.stringValue] }
    func decode(_ type: Int16.Type) throws -> Int16 { return row[column.stringValue] }
    func decode(_ type: Int32.Type) throws -> Int32 { return row[column.stringValue] }
    func decode(_ type: Int64.Type) throws -> Int64 { return row[column.stringValue] }
    func decode(_ type: UInt.Type) throws -> UInt { return row[column.stringValue] }
    func decode(_ type: UInt8.Type) throws -> UInt8 { return row[column.stringValue] }
    func decode(_ type: UInt16.Type) throws -> UInt16 { return row[column.stringValue] }
    func decode(_ type: UInt32.Type) throws -> UInt32 { return row[column.stringValue] }
    func decode(_ type: UInt64.Type) throws -> UInt64 { return row[column.stringValue] }
    func decode(_ type: Float.Type) throws -> Float { return row[column.stringValue] }
    func decode(_ type: Double.Type) throws -> Double { return row[column.stringValue] }
    func decode(_ type: String.Type) throws -> String { return row[column.stringValue] }

    /// Decodes a single value of the given type.
    ///
    /// - parameter type: The type to decode as.
    /// - returns: A value of the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value cannot be converted to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value is null.
    func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
        if let type = T.self as? DatabaseValueConvertible.Type {
            // Prefer DatabaseValueConvertible decoding over Decodable.
            // This allows decoding Date from String, or DatabaseValue from NULL.
            return type.fromDatabaseValue(row[column.stringValue]) as! T
        } else {
            return try T(from: RowDecoder(row: row, codingPath: [column]))
        }
    }
}

private struct RowDecoder: Decoder {
    let row: Row
    
    init(row: Row, codingPath: [CodingKey]) {
        self.row = row
        self.codingPath = codingPath
    }
    
    // Decoder
    let codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey : Any] { return [:] }
    
    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        return KeyedDecodingContainer(RowKeyedDecodingContainer<Key>(decoder: self))
    }
    
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        throw DecodingError.typeMismatch(
            UnkeyedDecodingContainer.self,
            DecodingError.Context(codingPath: codingPath, debugDescription: "unkeyed decoding is not supported"))
    }
    
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        // Asked for a value type: column name required
        guard let codingKey = codingPath.last else {
            throw DecodingError.typeMismatch(
                RowDecoder.self,
                DecodingError.Context(codingPath: codingPath, debugDescription: "single value decoding requires a coding key"))
        }
        return RowSingleValueDecodingContainer(row: row, codingPath: codingPath, column: codingKey)
    }
}

extension FetchableRecord where Self: Decodable {
    /// Initializes a record from `row`.
    public init(row: Row) {
        try! self.init(from: RowDecoder(row: row, codingPath: []))
    }
}

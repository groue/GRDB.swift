import Foundation

private struct RowKeyedDecodingContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let decoder: RowDecoder
    var codingPath: [CodingKey] { return decoder.codingPath }

    init(decoder: RowDecoder) {
        self.decoder = decoder
    }
    
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
        let keyName = key.stringValue

        // Column?
        if let index = row.index(ofColumn: keyName) {
            // Prefer DatabaseValueConvertible decoding over Decodable.
            // This allows decoding Date from String, or DatabaseValue from NULL.
            if let type = T.self as? (DatabaseValueConvertible & StatementColumnConvertible).Type {
                return type.fastDecodeIfPresent(from: row, atUncheckedIndex: index) as! T?
            } else if let type = T.self as? DatabaseValueConvertible.Type {
                return type.decodeIfPresent(from: row, atUncheckedIndex: index) as! T?
            } else if row.impl.hasNull(atUncheckedIndex: index) {
                return nil
            } else {
                do {
                    // This decoding will fail for types that decode from keyed
                    // or unkeyed containers, because we're decoding a single
                    // value here (string, int, double, data, null). If such an
                    // error happens, we'll switch to JSON decoding.
                    let singleValueDecoder = RowSingleValueDecoder(
                        row: row,
                        columnIndex: index,
                        codingPath: codingPath + [key],
                        userInfo: decoder.userInfo)
                    return try T(from: singleValueDecoder)
                } catch is JSONRequiredError {
                    guard let data = row.dataNoCopy(atIndex: index) else {
                        fatalConversionError(to: T.self, from: row[index], conversionContext: ValueConversionContext(row).atColumn(index))
                    }
                    return try makeJSONDecoder().decode(type.self, from: data)
                }
            }
        }
        
        // Scope?
        if let scopedRow = row.scopesTree[keyName], scopedRow.containsNonNullValue {
            if let type = T.self as? FetchableRecord.Type {
                // Prefer FetchableRecord decoding over Decodable.
                // This allows custom row decoding
                return (type.init(row: scopedRow) as! T)
            } else {
                let scopedDecoder = RowDecoder(
                    row: scopedRow,
                    codingPath: codingPath + [key],
                    userInfo: decoder.userInfo,
                    JSONUserInfo: decoder.JSONUserInfo)
                return try T(from: scopedDecoder)
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
        let keyName = key.stringValue

        // Column?
        if let index = row.index(ofColumn: keyName) {
            // Prefer DatabaseValueConvertible decoding over Decodable.
            // This allows decoding Date from String, or DatabaseValue from NULL.
            if let type = T.self as? (DatabaseValueConvertible & StatementColumnConvertible).Type {
                return type.fastDecode(from: row, atUncheckedIndex: index) as! T
            } else if let type = T.self as? DatabaseValueConvertible.Type {
                return type.decode(from: row, atUncheckedIndex: index) as! T
            } else {
                do {
                    // This decoding will fail for types that decode from keyed
                    // or unkeyed containers, because we're decoding a single
                    // value here (string, int, double, data, null). If such an
                    // error happens, we'll switch to JSON decoding.
                    let singleValueDecoder = RowSingleValueDecoder(
                        row: row,
                        columnIndex: index,
                        codingPath: codingPath + [key],
                        userInfo: decoder.userInfo)
                    return try T(from: singleValueDecoder)
                } catch is JSONRequiredError {
                    guard let data = row.dataNoCopy(atIndex: index) else {
                        fatalConversionError(to: T.self, from: row[index], conversionContext: ValueConversionContext(row).atColumn(index))
                    }
                    return try makeJSONDecoder().decode(type.self, from: data)
                }
            }
        }

        // Scope?
        if let scopedRow = row.scopesTree[keyName] {
            if let type = T.self as? FetchableRecord.Type {
                // Prefer FetchableRecord decoding over Decodable.
                // This allows custom row decoding
                return type.init(row: scopedRow) as! T
            } else {
                let scopedDecoder = RowDecoder(
                    row: scopedRow,
                    codingPath: codingPath + [key],
                    userInfo: decoder.userInfo,
                    JSONUserInfo: decoder.JSONUserInfo)
                return try T(from: scopedDecoder)
            }
        }
        
        // Base row
        if let type = T.self as? FetchableRecord.Type {
            // Prefer FetchableRecord decoding over Decodable.
            // This allows custom row decoding
            return type.init(row: row) as! T
        } else {
            let baseDecoder = RowDecoder(
                row: row,
                codingPath: codingPath + [key],
                userInfo: decoder.userInfo,
                JSONUserInfo: decoder.JSONUserInfo)
            return try T(from: baseDecoder)
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

    private func makeJSONDecoder() -> JSONDecoder {
        let encoder = JSONDecoder()
        encoder.dataDecodingStrategy = .base64
        encoder.dateDecodingStrategy = .millisecondsSince1970
        encoder.nonConformingFloatDecodingStrategy = .throw
        encoder.userInfo = decoder.JSONUserInfo
        return encoder
    }
}

private struct RowSingleValueDecodingContainer: SingleValueDecodingContainer {
    var row: Row
    var columnIndex: Int
    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any]

    /// Decodes a null value.
    ///
    /// - returns: Whether the encountered value was null.
    func decodeNil() -> Bool {
        return row.hasNull(atIndex: columnIndex)
    }

    /// Decodes a single value of the given type.
    ///
    /// - parameter type: The type to decode as.
    /// - returns: A value of the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value cannot be converted to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value is null.
    func decode(_ type: Bool.Type) throws -> Bool { return row[columnIndex] }
    func decode(_ type: Int.Type) throws -> Int { return row[columnIndex] }
    func decode(_ type: Int8.Type) throws -> Int8 { return row[columnIndex] }
    func decode(_ type: Int16.Type) throws -> Int16 { return row[columnIndex] }
    func decode(_ type: Int32.Type) throws -> Int32 { return row[columnIndex] }
    func decode(_ type: Int64.Type) throws -> Int64 { return row[columnIndex] }
    func decode(_ type: UInt.Type) throws -> UInt { return row[columnIndex] }
    func decode(_ type: UInt8.Type) throws -> UInt8 { return row[columnIndex] }
    func decode(_ type: UInt16.Type) throws -> UInt16 { return row[columnIndex] }
    func decode(_ type: UInt32.Type) throws -> UInt32 { return row[columnIndex] }
    func decode(_ type: UInt64.Type) throws -> UInt64 { return row[columnIndex] }
    func decode(_ type: Float.Type) throws -> Float { return row[columnIndex] }
    func decode(_ type: Double.Type) throws -> Double { return row[columnIndex] }
    func decode(_ type: String.Type) throws -> String { return row[columnIndex] }

    /// Decodes a single value of the given type.
    ///
    /// - parameter type: The type to decode as.
    /// - returns: A value of the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value cannot be converted to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value is null.
    func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
        // Prefer DatabaseValueConvertible decoding over Decodable.
        // This allows decoding Date from String, or DatabaseValue from NULL.
        if let type = T.self as? (DatabaseValueConvertible & StatementColumnConvertible).Type {
            return type.fastDecode(from: row, atUncheckedIndex: columnIndex) as! T
        } else if let type = T.self as? DatabaseValueConvertible.Type {
            return type.decode(from: row, atUncheckedIndex: columnIndex) as! T
        } else {
            let singleValueDecoder = RowSingleValueDecoder(
                row: row,
                columnIndex: columnIndex,
                codingPath: codingPath,
                userInfo: userInfo)
            return try T(from: singleValueDecoder)
        }
    }
}

private struct RowDecoder: Decoder {
    var row: Row
    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any]
    var JSONUserInfo: [CodingUserInfoKey: Any]
    
    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        return KeyedDecodingContainer(RowKeyedDecodingContainer<Key>(decoder: self))
    }
    
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        throw JSONRequiredError()
    }
    
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        throw JSONRequiredError()
    }
}

private struct RowSingleValueDecoder: Decoder {
    var row: Row
    var columnIndex: Int
    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any]
    
    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        throw JSONRequiredError()
    }
    
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        throw JSONRequiredError()
    }
    
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return RowSingleValueDecodingContainer(
            row: row,
            columnIndex: columnIndex,
            codingPath: codingPath,
            userInfo: userInfo)
    }
}

/// The error that triggers JSON decoding
private struct JSONRequiredError: Error { }

extension FetchableRecord where Self: Decodable {
    /// Initializes a record from `row`.
    public init(row: Row) {
        let decoder = RowDecoder(
            row: row,
            codingPath: [],
            userInfo: Self.decodingUserInfo,
            JSONUserInfo: Self.JSONDecodingUserInfo)
        try! self.init(from: decoder)
    }
}

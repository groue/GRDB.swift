import Foundation

// MARK: - RowDecoder

/// The decoder that decodes a record from a database row
private struct RowDecoder<Record: FetchableRecord>: Decoder {
    var row: Row
    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any] { return Record.databaseDecodingUserInfo }
    
    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        return KeyedDecodingContainer(KeyedContainer<Key>(decoder: self))
    }
    
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        fatalError("unkeyed decoding from database row is not supported")
    }
    
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        fatalError("single value decoding from database row is not supported")
    }
    
    struct KeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
        let decoder: RowDecoder
        var codingPath: [CodingKey] { return decoder.codingPath }
        
        init(decoder: RowDecoder) {
            self.decoder = decoder
        }
        
        var allKeys: [Key] {
            let row = decoder.row
            let columnNames = Set(row.columnNames)
            let scopeNames = Set(row.scopesTree.names)
            return columnNames.union(scopeNames).compactMap { Key(stringValue: $0) }
        }
        
        func contains(_ key: Key) -> Bool {
            let row = decoder.row
            return row.hasColumn(key.stringValue) || (row.scopesTree[key.stringValue] != nil)
        }
        
        func decodeNil(forKey key: Key) throws -> Bool {
            let row = decoder.row
            return row[key.stringValue] == nil && (row.scopesTree[key.stringValue] == nil)
        }
        
        func decode(_ type: Bool.Type,   forKey key: Key) throws -> Bool   { return decoder.row[key.stringValue] }
        func decode(_ type: Int.Type,    forKey key: Key) throws -> Int    { return decoder.row[key.stringValue] }
        func decode(_ type: Int8.Type,   forKey key: Key) throws -> Int8   { return decoder.row[key.stringValue] }
        func decode(_ type: Int16.Type,  forKey key: Key) throws -> Int16  { return decoder.row[key.stringValue] }
        func decode(_ type: Int32.Type,  forKey key: Key) throws -> Int32  { return decoder.row[key.stringValue] }
        func decode(_ type: Int64.Type,  forKey key: Key) throws -> Int64  { return decoder.row[key.stringValue] }
        func decode(_ type: UInt.Type,   forKey key: Key) throws -> UInt   { return decoder.row[key.stringValue] }
        func decode(_ type: UInt8.Type,  forKey key: Key) throws -> UInt8  { return decoder.row[key.stringValue] }
        func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 { return decoder.row[key.stringValue] }
        func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 { return decoder.row[key.stringValue] }
        func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 { return decoder.row[key.stringValue] }
        func decode(_ type: Float.Type,  forKey key: Key) throws -> Float  { return decoder.row[key.stringValue] }
        func decode(_ type: Double.Type, forKey key: Key) throws -> Double { return decoder.row[key.stringValue] }
        func decode(_ type: String.Type, forKey key: Key) throws -> String { return decoder.row[key.stringValue] }
        
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
                    return try decode(type, fromColumnAtIndex: index, key: key)
                }
            }
            
            // Scope? (beware left joins, and check if scoped row contains non-null values)
            if let scopedRow = row.scopesTree[keyName], scopedRow.containsNonNullValue {
                return try decode(type, fromRow: scopedRow, codingPath: codingPath + [key])
            }
            
            // Key is not a column, and not a scope.
            return nil
        }
        
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
                    return try decode(type, fromColumnAtIndex: index, key: key)
                }
            }
            
            // Scope?
            if let scopedRow = row.scopesTree[keyName] {
                return try decode(type, fromRow: scopedRow, codingPath: codingPath + [key])
            }
            
            // Key is not a column, and not a scope.
            //
            // Should be throw an error? Well... The use case is the following:
            //
            //      // SELECT book.*, author.* FROM book
            //      // JOIN author ON author.id = book.authorId
            //      let request = Book.including(required: Book.author)
            //
            // Rows loaded from this request don't have any "book" key:
            //
            //      let row = try Row.fetchOne(db, request)!
            //      print(row.debugDescription)
            //      // ▿ [id:1 title:"Moby-Dick" authorId:2]
            //      //   unadapted: [id:1 title:"Moby-Dick" authorId:2 id:2 name:"Melville"]
            //      //   author: [id:2 name:"Melville"]
            //
            // And yet we have to decode the "book" key when we decode the
            // BookInfo type below:
            //
            //      struct BookInfo {
            //          var book: Book // <- decodes from the "book" key
            //          var author: Author
            //      }
            //      let infos = try BookInfos.fetchAll(db, request)
            //
            // Our current strategy is to assume that a missing key (such as
            // "book", which is not the name of a column, and not the name of a
            // scope) has to be decoded right from the base row.
            //
            // Yeah, there may be better ways to handle this.
            return try decode(type, fromRow: row, codingPath: codingPath + [key])
        }
        
        func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
            fatalError("not implemented")
        }
        
        func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
            throw DecodingError.typeMismatch(
                UnkeyedDecodingContainer.self,
                DecodingError.Context(codingPath: codingPath, debugDescription: "unkeyed decoding is not supported"))
        }
        
        func superDecoder() throws -> Decoder {
            // Not sure
            return decoder
        }
        
        func superDecoder(forKey key: Key) throws -> Decoder {
            fatalError("not implemented")
        }
        
        // Helper methods
        
        @inline(__always)
        private func decode<T>(_ type: T.Type, fromRow row: Row, codingPath: [CodingKey]) throws -> T where T: Decodable {
            if let type = T.self as? FetchableRecord.Type {
                // Prefer FetchableRecord decoding over Decodable.
                return type.init(row: row) as! T
            } else {
                let decoder = RowDecoder(row: row, codingPath: codingPath)
                return try T(from: decoder)
            }
        }
        
        @inline(__always)
        private func decode<T>(_ type: T.Type, fromColumnAtIndex index: Int, key: Key) throws -> T where T: Decodable {
            let row = decoder.row
            do {
                // This decoding will fail for types that decode from keyed
                // or unkeyed containers, because we're decoding a single
                // value here (string, int, double, data, null). If such an
                // error happens, we'll switch to JSON decoding.
                let columnDecoder = ColumnDecoder<Record>(
                    row: row,
                    columnIndex: index,
                    codingPath: codingPath + [key])
                return try T(from: columnDecoder)
            } catch is JSONRequiredError {
                // Decode from JSON
                guard let data = row.dataNoCopy(atIndex: index) else {
                    fatalConversionError(to: T.self, from: row[index], conversionContext: ValueConversionContext(row).atColumn(index))
                }
                return try Record
                    .databaseJSONDecoder(for: key.stringValue)
                    .decode(type.self, from: data)
            }
        }
    }
}

// MARK: - ColumnDecoder

/// The decoder that decodes from a database column
private struct ColumnDecoder<Record: FetchableRecord>: Decoder {
    var row: Row
    var columnIndex: Int
    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any] { return Record.databaseDecodingUserInfo }
    
    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        // We need to switch to JSON decoding
        throw JSONRequiredError()
    }
    
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        // We need to switch to JSON decoding
        throw JSONRequiredError()
    }
    
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return self
    }
}

extension ColumnDecoder: SingleValueDecodingContainer {
    func decodeNil() -> Bool {
        return row.hasNull(atIndex: columnIndex)
    }
    
    func decode(_ type: Bool.Type  ) throws -> Bool   { return row[columnIndex] }
    func decode(_ type: Int.Type   ) throws -> Int    { return row[columnIndex] }
    func decode(_ type: Int8.Type  ) throws -> Int8   { return row[columnIndex] }
    func decode(_ type: Int16.Type ) throws -> Int16  { return row[columnIndex] }
    func decode(_ type: Int32.Type ) throws -> Int32  { return row[columnIndex] }
    func decode(_ type: Int64.Type ) throws -> Int64  { return row[columnIndex] }
    func decode(_ type: UInt.Type  ) throws -> UInt   { return row[columnIndex] }
    func decode(_ type: UInt8.Type ) throws -> UInt8  { return row[columnIndex] }
    func decode(_ type: UInt16.Type) throws -> UInt16 { return row[columnIndex] }
    func decode(_ type: UInt32.Type) throws -> UInt32 { return row[columnIndex] }
    func decode(_ type: UInt64.Type) throws -> UInt64 { return row[columnIndex] }
    func decode(_ type: Float.Type ) throws -> Float  { return row[columnIndex] }
    func decode(_ type: Double.Type) throws -> Double { return row[columnIndex] }
    func decode(_ type: String.Type) throws -> String { return row[columnIndex] }
    
    func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
        // Prefer DatabaseValueConvertible decoding over Decodable.
        // This allows decoding Date from String, or DatabaseValue from NULL.
        if let type = T.self as? (DatabaseValueConvertible & StatementColumnConvertible).Type {
            return type.fastDecode(from: row, atUncheckedIndex: columnIndex) as! T
        } else if let type = T.self as? DatabaseValueConvertible.Type {
            return type.decode(from: row, atUncheckedIndex: columnIndex) as! T
        } else {
            return try T(from: self)
        }
    }
}

/// The error that triggers JSON decoding
private struct JSONRequiredError: Error { }

extension FetchableRecord where Self: Decodable {
    /// Initializes a record from `row`.
    public init(row: Row) {
        let decoder = RowDecoder<Self>(row: row, codingPath: [])
        try! self.init(from: decoder)
    }
}

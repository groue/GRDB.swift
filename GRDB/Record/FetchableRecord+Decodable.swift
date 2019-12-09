import Foundation
#if SWIFT_PACKAGE
import CSQLite
#elseif GRDBCIPHER
import SQLCipher
#elseif !GRDBCUSTOMSQLITE && !GRDBCIPHER
import SQLite3
#endif

extension FetchableRecord where Self: Decodable {
    public init(row: Row) {
        // Intended force-try. FetchableRecord is designed for records that
        // reliably decode from rows.
        self = try! RowDecoder().decode(from: row)
    }
}

// For testability. Not intended to become public as long as FetchableRecord has
// a non-throwing row initializer, since this would open an undesired door.
class RowDecoder {
    init() { }
    
    func decode<T: FetchableRecord & Decodable>(_ type: T.Type = T.self, from row: Row) throws -> T {
        let decoder = _RowDecoder<T>(row: row, codingPath: [])
        return try T(from: decoder)
    }
}

// MARK: - _RowDecoder

/// The decoder that decodes a record from a database row
private struct _RowDecoder<R: FetchableRecord>: Decoder {
    var row: Row
    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any] { return R.databaseDecodingUserInfo }
    
    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        return KeyedDecodingContainer(KeyedContainer<Key>(decoder: self))
    }
    
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        guard let codingKey = codingPath.last else {
            fatalError("unkeyed decoding from database row is not supported")
        }
        let keys = row.prefetchedRows.keys
        let debugDescription: String
        if keys.isEmpty {
            debugDescription = "No available prefetched rows"
        } else {
            debugDescription = "Available keys for prefetched rows: \(keys.sorted())"
        }
        throw DecodingError.keyNotFound(
            codingKey,
            DecodingError.Context(
                codingPath: Array(codingPath.dropLast()),   // TODO: remove Array initializer when Swift >= 5
                debugDescription: debugDescription))
    }
    
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        guard let key = codingPath.last else {
            fatalError("single value decoding from database row is not supported")
        }
        guard let index = row.index(ofColumn: key.stringValue) else {
            // Don't use DecodingError.keyNotFound:
            // We need to specifically recognize missing columns in order to
            // provide correct feedback.
            throw MissingColumnError(column: key.stringValue)
        }
        // TODO: test
        // See DatabaseValueConversionErrorTests.testDecodableFetchableRecord2
        return ColumnDecoder<R>(row: row, columnIndex: index, codingPath: codingPath)
    }
    
    class KeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
        let decoder: _RowDecoder
        var codingPath: [CodingKey] { return decoder.codingPath }
        var decodedRootKey: CodingKey?
        
        init(decoder: _RowDecoder) {
            self.decoder = decoder
        }
        
        var allKeys: [Key] {
            let row = decoder.row
            return Set(row.columnNames)
                .union(Set(row.scopesTree.names))
                .union(Set(row.prefetchedRows.keys))
                .compactMap { Key(stringValue: $0) }
        }
        
        func contains(_ key: Key) -> Bool {
            let row = decoder.row
            return row.hasColumn(key.stringValue) || (row.scopesTree[key.stringValue] != nil)
        }
        
        func decodeNil(forKey key: Key) throws -> Bool {
            let row = decoder.row
            return row[key.stringValue] == nil && (row.scopesTree[key.stringValue] == nil)
        }
        
        // swiftlint:disable comma
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
        // swiftlint:enable comma
        
        func decodeIfPresent<T>(_ type: T.Type, forKey key: Key) throws -> T? where T: Decodable {
            let row = decoder.row
            let keyName = key.stringValue
            
            // Column?
            if let index = row.index(ofColumn: keyName) {
                // Prefer DatabaseValueConvertible decoding over Decodable.
                // This allows decoding Date from String, or DatabaseValue from NULL.
                if type == Date.self {
                    return R.databaseDateDecodingStrategy.decodeIfPresent(fromRow: row, columnAtIndex: index) as! T?
                } else if let type = T.self as? (DatabaseValueConvertible & StatementColumnConvertible).Type {
                    return type.fastDecodeIfPresent(from: row, atUncheckedIndex: index) as! T?
                } else if let type = T.self as? DatabaseValueConvertible.Type {
                    return type.decodeIfPresent(from: row, atUncheckedIndex: index) as! T?
                } else if row.impl.hasNull(atUncheckedIndex: index) {
                    return nil
                } else {
                    return try decode(type, fromRow: row, columnAtIndex: index, key: key)
                }
            }
            
            // Scope? (beware left joins: check if scoped row contains non-null values)
            if let scopedRow = row.scopesTree[keyName], scopedRow.containsNonNullValue {
                return try decode(type, fromRow: scopedRow, codingPath: codingPath + [key])
            }
            
            // Key is not a column, and not a scope.
            return nil
        }
        
        func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T: Decodable {
            let row = decoder.row
            let keyName = key.stringValue
            
            // Column?
            if let index = row.index(ofColumn: keyName) {
                // Prefer DatabaseValueConvertible decoding over Decodable.
                // This allows decoding Date from String, or DatabaseValue from NULL.
                if type == Date.self {
                    return R.databaseDateDecodingStrategy.decode(fromRow: row, columnAtIndex: index) as! T
                } else if let type = T.self as? (DatabaseValueConvertible & StatementColumnConvertible).Type {
                    return type.fastDecode(from: row, atUncheckedIndex: index) as! T
                } else if let type = T.self as? DatabaseValueConvertible.Type {
                    return type.decode(from: row, atUncheckedIndex: index) as! T
                } else {
                    return try decode(type, fromRow: row, columnAtIndex: index, key: key)
                }
            }
            
            // Scope?
            if let scopedRow = row.scopesTree[keyName] {
                return try decode(type, fromRow: scopedRow, codingPath: codingPath + [key])
            }
            
            // Prefetched Rows?
            if let prefetchedRows = row.prefetchedRows[keyName] {
                let decoder = PrefetchedRowsDecoder<R>(rows: prefetchedRows, codingPath: codingPath)
                return try T(from: decoder)
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
            if let decodedRootKey = decodedRootKey {
                throw DecodingError.keyNotFound(decodedRootKey, DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "No such key: \(decodedRootKey.stringValue)")) // TODO: better error message
            }
            decodedRootKey = key
            return try decode(type, fromRow: row, codingPath: codingPath + [key])
        }
        
        func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key)
            throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey
        {
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
        private func decode<T>(
            _ type: T.Type,
            fromRow row: Row,
            codingPath: [CodingKey])
            throws -> T
            where T: Decodable
        {
            if let type = T.self as? FetchableRecord.Type {
                // Prefer FetchableRecord decoding over Decodable.
                return type.init(row: row) as! T
            } else {
                do {
                    let decoder = _RowDecoder(row: row, codingPath: codingPath)
                    return try T(from: decoder)
                } catch let error as MissingColumnError {
                    // Support for DatabaseValueConversionErrorTests.testDecodableFetchableRecord2
                    fatalConversionError(
                        to: type,
                        from: nil,
                        conversionContext: ValueConversionContext(row).atColumn(error.column))
                }
            }
        }
        
        @inline(__always)
        private func decode<T>(
            _ type: T.Type,
            fromRow row: Row,
            columnAtIndex index: Int,
            key: Key)
            throws -> T
            where T: Decodable
        {
            do {
                // This decoding will fail for types that decode from keyed
                // or unkeyed containers, because we're decoding a single
                // value here (string, int, double, data, null). If such an
                // error happens, we'll switch to JSON decoding.
                let columnDecoder = ColumnDecoder<R>(
                    row: row,
                    columnIndex: index,
                    codingPath: codingPath + [key])
                return try T(from: columnDecoder)
            } catch is JSONRequiredError {
                // Decode from JSON
                guard let data = row.dataNoCopy(atIndex: index) else {
                    fatalConversionError(
                        to: T.self,
                        from: row[index],
                        conversionContext: ValueConversionContext(row).atColumn(index))
                }
                return try R
                    .databaseJSONDecoder(for: key.stringValue)
                    .decode(type.self, from: data)
            }
        }
    }
}

// MARK: - PrefetchedRowsDecoder

private struct PrefetchedRowsDecoder<R: FetchableRecord>: Decoder {
    var rows: [Row]
    var codingPath: [CodingKey]
    var currentIndex: Int
    var userInfo: [CodingUserInfoKey: Any] { return R.databaseDecodingUserInfo }
    
    init(rows: [Row], codingPath: [CodingKey]) {
        self.rows = rows
        self.codingPath = codingPath
        self.currentIndex = 0
    }
    
    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key: CodingKey {
        fatalError("keyed decoding from prefetched rows is not supported")
    }
    
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        return self
    }
    
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        fatalError("single value decoding from prefetched rows is not supported")
    }
}

extension PrefetchedRowsDecoder: UnkeyedDecodingContainer {
    var count: Int? {
        return rows.count
    }
    
    var isAtEnd: Bool {
        return currentIndex >= rows.count
    }
    
    mutating func decodeNil() throws -> Bool {
        return false
    }
    
    mutating func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        defer { currentIndex += 1 }
        let decoder = _RowDecoder<R>(row: rows[currentIndex], codingPath: codingPath)
        return try T(from: decoder)
    }
    
    mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type)
        throws -> KeyedDecodingContainer<NestedKey>
        where NestedKey: CodingKey
    {
        fatalError("not implemented")
    }
    
    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        fatalError("not implemented")
    }
    
    mutating func superDecoder() throws -> Decoder {
        fatalError("not implemented")
    }
}

// MARK: - ColumnDecoder

/// The decoder that decodes from a database column
private struct ColumnDecoder<R: FetchableRecord>: Decoder {
    var row: Row
    var columnIndex: Int
    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any] { return R.databaseDecodingUserInfo }
    
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
    
    func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        // Prefer DatabaseValueConvertible decoding over Decodable.
        // This allows decoding Date from String, or DatabaseValue from NULL.
        if type == Date.self {
            return R.databaseDateDecodingStrategy.decode(fromRow: row, columnAtIndex: columnIndex) as! T
        } else if let type = T.self as? (DatabaseValueConvertible & StatementColumnConvertible).Type {
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

/// The error for missing columns
private struct MissingColumnError: Error {
    var column: String
}

@available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
private var iso8601Formatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = .withInternetDateTime
    return formatter
}()

extension DatabaseDateDecodingStrategy {
    @inline(__always)
    fileprivate func decodeIfPresent(fromRow row: Row, columnAtIndex index: Int) -> Date? {
        if let sqliteStatement = row.sqliteStatement {
            return decodeIfPresent(
                sqliteStatement: sqliteStatement,
                index: Int32(index))
        } else {
            return decodeIfPresent(
                from: row[index],
                conversionContext: ValueConversionContext(row).atColumn(index))
        }
    }
    
    @inline(__always)
    fileprivate func decode(fromRow row: Row, columnAtIndex index: Int) -> Date {
        if let sqliteStatement = row.sqliteStatement {
            return decode(
                sqliteStatement: sqliteStatement,
                index: Int32(index))
        } else {
            return decode(
                from: row[index],
                conversionContext: ValueConversionContext(row).atColumn(index))
        }
    }
    
    @inline(__always)
    fileprivate func decode(sqliteStatement: SQLiteStatement, index: Int32) -> Date {
        switch self {
        case .deferredToDate:
            return Date(sqliteStatement: sqliteStatement, index: index)
        case .timeIntervalSinceReferenceDate:
            let timeInterval = TimeInterval(sqliteStatement: sqliteStatement, index: index)
            return Date(timeIntervalSinceReferenceDate: timeInterval)
        case .timeIntervalSince1970:
            let timeInterval = TimeInterval(sqliteStatement: sqliteStatement, index: index)
            return Date(timeIntervalSince1970: timeInterval)
        case .millisecondsSince1970:
            let timeInterval = TimeInterval(sqliteStatement: sqliteStatement, index: index)
            return Date(timeIntervalSince1970: timeInterval / 1000.0)
        case .iso8601:
            if #available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *) {
                let string = String(sqliteStatement: sqliteStatement, index: index)
                guard let date = iso8601Formatter.date(from: string) else {
                    fatalConversionError(to: Date.self, sqliteStatement: sqliteStatement, index: index)
                }
                return date
            } else {
                fatalError("ISO8601DateFormatter is unavailable on this platform.")
            }
        case .formatted(let formatter):
            let string = String(sqliteStatement: sqliteStatement, index: index)
            guard let date = formatter.date(from: string) else {
                fatalConversionError(to: Date.self, sqliteStatement: sqliteStatement, index: index)
            }
            return date
        case .custom(let format):
            let dbValue = DatabaseValue(sqliteStatement: sqliteStatement, index: index)
            guard let date = format(dbValue) else {
                fatalConversionError(to: Date.self, sqliteStatement: sqliteStatement, index: index)
            }
            return date
        }
    }
    
    @inline(__always)
    fileprivate func decodeIfPresent(sqliteStatement: SQLiteStatement, index: Int32) -> Date? {
        if sqlite3_column_type(sqliteStatement, index) == SQLITE_NULL {
            return nil
        }
        return decode(sqliteStatement: sqliteStatement, index: index)
    }
    
    @inline(__always)
    fileprivate func decode(
        from dbValue: DatabaseValue,
        conversionContext: @autoclosure () -> ValueConversionContext?)
        -> Date
    {
        if let date = dateFromDatabaseValue(dbValue) {
            return date
        } else {
            fatalConversionError(to: Date.self, from: dbValue, conversionContext: conversionContext())
        }
    }
    
    @inline(__always)
    fileprivate func decodeIfPresent(
        from dbValue: DatabaseValue,
        conversionContext: @autoclosure () -> ValueConversionContext?)
        -> Date?
    {
        if dbValue.isNull {
            return nil
        } else if let date = dateFromDatabaseValue(dbValue) {
            return date
        } else {
            fatalConversionError(to: Date.self, from: dbValue, conversionContext: conversionContext())
        }
    }
    
    // Returns nil if decoding fails
    @inline(__always)
    private func dateFromDatabaseValue(_ dbValue: DatabaseValue) -> Date? {
        switch self {
        case .deferredToDate:
            return Date.fromDatabaseValue(dbValue)
        case .timeIntervalSinceReferenceDate:
            return TimeInterval
                .fromDatabaseValue(dbValue)
                .map { Date(timeIntervalSinceReferenceDate: $0) }
        case .timeIntervalSince1970:
            return TimeInterval
                .fromDatabaseValue(dbValue)
                .map { Date(timeIntervalSince1970: $0) }
        case .millisecondsSince1970:
            return TimeInterval
                .fromDatabaseValue(dbValue)
                .map { Date(timeIntervalSince1970: $0 / 1000.0) }
        case .iso8601:
            if #available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *) {
                return String
                    .fromDatabaseValue(dbValue)
                    .flatMap { iso8601Formatter.date(from: $0) }
            } else {
                fatalError("ISO8601DateFormatter is unavailable on this platform.")
            }
        case .formatted(let formatter):
            return String
                .fromDatabaseValue(dbValue)
                .flatMap { formatter.date(from: $0) }
        case .custom(let format):
            return format(dbValue)
        }
    }
}

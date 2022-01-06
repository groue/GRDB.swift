import Foundation

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
        let decoder = _RowDecoder<T>(row: row, codingPath: [], columnDecodingStrategy: T.databaseColumnDecodingStrategy)
        return try T(from: decoder)
    }
}

// MARK: - _RowDecoder

/// The decoder that decodes a record from a database row
private struct _RowDecoder<R: FetchableRecord>: Decoder {
    var row: Row
    var codingPath: [CodingKey]
    var columnDecodingStrategy: DatabaseColumnDecodingStrategy
    var userInfo: [CodingUserInfoKey: Any] { R.databaseDecodingUserInfo }
    
    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        KeyedDecodingContainer(KeyedContainer<Key>(decoder: self))
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
                codingPath: Array(codingPath.dropLast()),
                debugDescription: debugDescription))
    }
    
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        guard let key = codingPath.last else {
            // Decoding an array of scalars from rows: pick the first column
            return ColumnDecoder<R>(row: row, columnIndex: 0, codingPath: codingPath)
        }
        guard let index = row.index(forColumn: key.stringValue) else {
            // Don't use DecodingError.keyNotFound:
            // We need to specifically recognize missing columns in order to
            // provide correct feedback.
            throw RowDecodingError.columnNotFound(key.stringValue, context: RowDecodingContext(row: row))
        }
        // TODO: test
        // See DatabaseValueConversionErrorTests.testDecodableFetchableRecord2
        return ColumnDecoder<R>(row: row, columnIndex: index, codingPath: codingPath)
    }
    
    class KeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
        private let decoder: _RowDecoder
        var codingPath: [CodingKey] { decoder.codingPath }
        private var decodedRootKey: CodingKey?
        // Not nil iff decoder has a columnDecodingStrategy
        private let _columnForKey: [String: String]?
        
        init(decoder: _RowDecoder) {
            self.decoder = decoder
            switch decoder.columnDecodingStrategy {
            case .useDefaultKeys:
                _columnForKey = nil
            default:
                var columnForKey: [String: String] = [:]
                for column in decoder.row.columnNames {
                    if let key: Key = decoder.columnDecodingStrategy.key(forColumn: column) {
                        columnForKey[key.stringValue] = column
                    }
                }
                _columnForKey = columnForKey
            }
        }
        
        lazy var allKeys: [Key] = {
            let row = decoder.row
            var keys = _columnForKey.map { Set($0.keys) } ?? Set(row.columnNames)
            keys.formUnion(row.scopesTree.names)
            keys.formUnion(row.prefetchedRows.keys)
            return keys.compactMap(Key.init(stringValue:))
        }()
        
        func contains(_ key: Key) -> Bool {
            let row = decoder.row
            if let _columnForKey = _columnForKey {
                if let column = _columnForKey[key.stringValue] {
                    assert(row.hasColumn(column))
                    return true
                }
            } else if row.hasColumn(key.stringValue) {
                return true
            }
            if row.scopesTree[key.stringValue] != nil {
                return true
            }
            if row.prefetchedRows[key.stringValue] != nil {
                return true
            }
            return false
        }
        
        func decodeNil(forKey key: Key) throws -> Bool {
            // Nil is only possible for columns and scopes (optional
            // associations), not for prefetched rows.
            let row = decoder.row
            if let column = try? decodeColumn(forKey: key), row[column] != nil {
                return false
            }
            if row.scopesTree[key.stringValue] != nil {
                return false
            }
            return true
        }
        
        // swiftlint:disable comma
        // swiftlint:disable line_length
        func decode(_ type: Bool.Type,   forKey key: Key) throws -> Bool   { try decoder.row.decode(forKey: decodeColumn(forKey: key)) }
        func decode(_ type: Int.Type,    forKey key: Key) throws -> Int    { try decoder.row.decode(forKey: decodeColumn(forKey: key)) }
        func decode(_ type: Int8.Type,   forKey key: Key) throws -> Int8   { try decoder.row.decode(forKey: decodeColumn(forKey: key)) }
        func decode(_ type: Int16.Type,  forKey key: Key) throws -> Int16  { try decoder.row.decode(forKey: decodeColumn(forKey: key)) }
        func decode(_ type: Int32.Type,  forKey key: Key) throws -> Int32  { try decoder.row.decode(forKey: decodeColumn(forKey: key)) }
        func decode(_ type: Int64.Type,  forKey key: Key) throws -> Int64  { try decoder.row.decode(forKey: decodeColumn(forKey: key)) }
        func decode(_ type: UInt.Type,   forKey key: Key) throws -> UInt   { try decoder.row.decode(forKey: decodeColumn(forKey: key)) }
        func decode(_ type: UInt8.Type,  forKey key: Key) throws -> UInt8  { try decoder.row.decode(forKey: decodeColumn(forKey: key)) }
        func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 { try decoder.row.decode(forKey: decodeColumn(forKey: key)) }
        func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 { try decoder.row.decode(forKey: decodeColumn(forKey: key)) }
        func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 { try decoder.row.decode(forKey: decodeColumn(forKey: key)) }
        func decode(_ type: Float.Type,  forKey key: Key) throws -> Float  { try decoder.row.decode(forKey: decodeColumn(forKey: key)) }
        func decode(_ type: Double.Type, forKey key: Key) throws -> Double { try decoder.row.decode(forKey: decodeColumn(forKey: key)) }
        func decode(_ type: String.Type, forKey key: Key) throws -> String { try decoder.row.decode(forKey: decodeColumn(forKey: key)) }
        // swiftlint:enable line_length
        // swiftlint:enable comma
        
        private func decodeColumn(forKey key: Key) throws -> String {
            guard let _columnForKey = _columnForKey else {
                return key.stringValue
            }
            
            guard let column = _columnForKey[key.stringValue] else {
                let errorDescription: String
                switch decoder.columnDecodingStrategy {
                case .convertFromSnakeCase:
                    // In this case we can attempt to recover the original value
                    // by reversing the transform
                    let original = key.stringValue
                    let converted = DatabaseColumnEncodingStrategy._convertToSnakeCase(original)
                    let roundtrip = DatabaseColumnDecodingStrategy._convertFromSnakeCase(converted)
                    if converted == original {
                        errorDescription = "\(key) (\"\(original)\")"
                    } else if roundtrip == original {
                        errorDescription = """
                            \(key) (\"\(original)\"), \
                            converted to \(converted)
                            """
                    } else {
                        errorDescription = """
                            \(key) (\"\(original)\"), \
                            with divergent representation \(roundtrip), \
                            converted to \(converted)
                            """
                    }
                default:
                    // Otherwise, just report the converted string
                    errorDescription = "\(key) (\"\(key.stringValue)\")"
                }
                
                // TODO: this is not quite correct: key IS NOT a column name.
                // So we shouldn't use RowKey.columnName. Yet this only impacts
                // internal types, so the damage is limited.
                throw RowDecodingError.keyNotFound(
                    .columnName(key.stringValue), // <- See above TODO
                    RowDecodingError.Context(
                        decodingContext: RowDecodingContext(row: decoder.row),
                        debugDescription: "key not found: \(errorDescription)"))
            }
            
            return column
        }
        
        func decodeIfPresent<T>(_ type: T.Type, forKey key: Key) throws -> T? where T: Decodable {
            let row = decoder.row
            
            // Column?
            if let column = try? decodeColumn(forKey: key),
               let index = row.index(forColumn: column)
            {
                // Prefer DatabaseValueConvertible decoding over Decodable.
                // This allows decoding Date from String, or DatabaseValue from NULL.
                if type == Date.self {
                    return try R.databaseDateDecodingStrategy.decodeIfPresent(
                        fromRow: row,
                        atUncheckedIndex: index) as! T?
                } else if let type = T.self as? (DatabaseValueConvertible & StatementColumnConvertible).Type {
                    return try type.fastDecodeIfPresent(fromRow: row, atUncheckedIndex: index) as! T?
                } else if let type = T.self as? DatabaseValueConvertible.Type {
                    return try type.decodeIfPresent(fromRow: row, atUncheckedIndex: index) as! T?
                } else if row.impl.hasNull(atUncheckedIndex: index) {
                    return nil
                } else {
                    return try decode(type, fromRow: row, columnAtIndex: index, key: key)
                }
            }
            
            // Scope? (beware left joins: check if scoped row contains non-null values)
            if let scopedRow = row.scopesTree[key.stringValue], scopedRow.containsNonNullValue {
                return try decode(type, fromRow: scopedRow, codingPath: codingPath + [key])
            }
            
            // Prefetched Rows?
            if let prefetchedRows = row.prefetchedRows[key.stringValue] {
                let decoder = PrefetchedRowsDecoder<R>(rows: prefetchedRows, codingPath: codingPath)
                return try T(from: decoder)
            }
            
            // Key is not a column, and not a scope.
            return nil
        }
        
        func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T: Decodable {
            let row = decoder.row
            
            // Column?
            if let column = try? decodeColumn(forKey: key),
               let index = row.index(forColumn: column)
            {
                // Prefer DatabaseValueConvertible decoding over Decodable.
                // This allows decoding Date from String, or DatabaseValue from NULL.
                if type == Date.self {
                    return try R.databaseDateDecodingStrategy.decode(fromRow: row, atUncheckedIndex: index) as! T
                } else if let type = T.self as? (DatabaseValueConvertible & StatementColumnConvertible).Type {
                    return try type.fastDecode(fromRow: row, atUncheckedIndex: index) as! T
                } else if let type = T.self as? DatabaseValueConvertible.Type {
                    return try type.decode(fromRow: row, atUncheckedIndex: index) as! T
                } else {
                    return try decode(type, fromRow: row, columnAtIndex: index, key: key)
                }
            }
            
            // Scope?
            if let scopedRow = row.scopesTree[key.stringValue] {
                return try decode(type, fromRow: scopedRow, codingPath: codingPath + [key])
            }
            
            // Prefetched Rows?
            if let prefetchedRows = row.prefetchedRows[key.stringValue] {
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
            if let decodedRootKey = decodedRootKey {
                let keys = [decodedRootKey.stringValue, key.stringValue].sorted()
                throw DecodingError.keyNotFound(key, DecodingError.Context(
                                                    codingPath: codingPath,
                                                    debugDescription: "No such key: \(keys.joined(separator: " or "))"))
            } else {
                decodedRootKey = key
                return try decode(type, fromRow: row, codingPath: codingPath + [key])
            }
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
            decoder
        }
        
        func superDecoder(forKey key: Key) throws -> Decoder {
            decoder
        }
        
        // Helper methods
        
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
                let decoder = _RowDecoder(row: row, codingPath: codingPath, columnDecodingStrategy: .useDefaultKeys)
                return try T(from: decoder)
            }
        }
        
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
                let data = try row.decodeDataNoCopy(atIndex: index)
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
    var userInfo: [CodingUserInfoKey: Any] { R.databaseDecodingUserInfo }
    
    init(rows: [Row], codingPath: [CodingKey]) {
        self.rows = rows
        self.codingPath = codingPath
        self.currentIndex = 0
    }
    
    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key: CodingKey {
        fatalError("keyed decoding from prefetched rows is not supported")
    }
    
    func unkeyedContainer() throws -> UnkeyedDecodingContainer { self }
    
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        fatalError("single value decoding from prefetched rows is not supported")
    }
}

extension PrefetchedRowsDecoder: UnkeyedDecodingContainer {
    var count: Int? { rows.count }
    
    var isAtEnd: Bool { currentIndex >= rows.count }
    
    mutating func decodeNil() throws -> Bool { false }
    
    mutating func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        defer { currentIndex += 1 }
        
        let columnDecodingStrategy: DatabaseColumnDecodingStrategy
        if let type = T.self as? FetchableRecord.Type {
            columnDecodingStrategy = type.databaseColumnDecodingStrategy
        } else {
            columnDecodingStrategy = .useDefaultKeys
        }
        
        let decoder = _RowDecoder<R>(
            row: rows[currentIndex],
            codingPath: codingPath,
            columnDecodingStrategy: columnDecodingStrategy)
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
    var userInfo: [CodingUserInfoKey: Any] { R.databaseDecodingUserInfo }
    
    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        // We need to switch to JSON decoding
        throw JSONRequiredError()
    }
    
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        // We need to switch to JSON decoding
        throw JSONRequiredError()
    }
    
    func singleValueContainer() throws -> SingleValueDecodingContainer { self }
}

extension ColumnDecoder: SingleValueDecodingContainer {
    func decodeNil() -> Bool {
        row.hasNull(atIndex: columnIndex)
    }
    
    func decode(_ type: Bool.Type  ) throws -> Bool   { try row.decode(atIndex: columnIndex) }
    func decode(_ type: Int.Type   ) throws -> Int    { try row.decode(atIndex: columnIndex) }
    func decode(_ type: Int8.Type  ) throws -> Int8   { try row.decode(atIndex: columnIndex) }
    func decode(_ type: Int16.Type ) throws -> Int16  { try row.decode(atIndex: columnIndex) }
    func decode(_ type: Int32.Type ) throws -> Int32  { try row.decode(atIndex: columnIndex) }
    func decode(_ type: Int64.Type ) throws -> Int64  { try row.decode(atIndex: columnIndex) }
    func decode(_ type: UInt.Type  ) throws -> UInt   { try row.decode(atIndex: columnIndex) }
    func decode(_ type: UInt8.Type ) throws -> UInt8  { try row.decode(atIndex: columnIndex) }
    func decode(_ type: UInt16.Type) throws -> UInt16 { try row.decode(atIndex: columnIndex) }
    func decode(_ type: UInt32.Type) throws -> UInt32 { try row.decode(atIndex: columnIndex) }
    func decode(_ type: UInt64.Type) throws -> UInt64 { try row.decode(atIndex: columnIndex) }
    func decode(_ type: Float.Type ) throws -> Float  { try row.decode(atIndex: columnIndex) }
    func decode(_ type: Double.Type) throws -> Double { try row.decode(atIndex: columnIndex) }
    func decode(_ type: String.Type) throws -> String { try row.decode(atIndex: columnIndex) }
    
    func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        // Prefer DatabaseValueConvertible decoding over Decodable.
        // This allows decoding Date from String, or DatabaseValue from NULL.
        if type == Date.self {
            return try R.databaseDateDecodingStrategy.decode(fromRow: row, atUncheckedIndex: columnIndex) as! T
        } else if let type = T.self as? (DatabaseValueConvertible & StatementColumnConvertible).Type {
            return try type.fastDecode(fromRow: row, atUncheckedIndex: columnIndex) as! T
        } else if let type = T.self as? DatabaseValueConvertible.Type {
            return try type.decode(fromRow: row, atUncheckedIndex: columnIndex) as! T
        } else {
            return try T(from: self)
        }
    }
}

@available(macOS 10.12, watchOS 3.0, tvOS 10.0, *)
private let iso8601Formatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = .withInternetDateTime
    return formatter
}()

extension DatabaseDateDecodingStrategy {
    fileprivate func decodeIfPresent(fromRow row: Row, atUncheckedIndex index: Int) throws -> Date? {
        if let sqliteStatement = row.sqliteStatement {
            return try decodeIfPresent(
                fromStatement: sqliteStatement,
                atUncheckedIndex: Int32(index),
                context: RowDecodingContext(row: row, key: .columnIndex(index)))
        } else {
            return try decodeIfPresent(
                fromDatabaseValue: row[index],
                context: RowDecodingContext(row: row, key: .columnIndex(index)))
        }
    }
    
    fileprivate func decode(fromRow row: Row, atUncheckedIndex index: Int) throws -> Date {
        if let sqliteStatement = row.sqliteStatement {
            return try decode(
                fromStatement: sqliteStatement,
                atUncheckedIndex: Int32(index),
                context: RowDecodingContext(row: row, key: .columnIndex(index)))
        } else {
            return try decode(
                fromDatabaseValue: row[index],
                context: RowDecodingContext(row: row, key: .columnIndex(index)))
        }
    }
    
    fileprivate func decode(
        fromStatement sqliteStatement: SQLiteStatement,
        atUncheckedIndex index: Int32,
        context: @autoclosure () -> RowDecodingContext)
    throws -> Date
    {
        switch self {
        case .deferredToDate:
            guard let date = Date(sqliteStatement: sqliteStatement, index: index) else {
                throw RowDecodingError.valueMismatch(
                    Date.self,
                    context: context(),
                    databaseValue: DatabaseValue(sqliteStatement: sqliteStatement, index: index))
            }
            return date
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
            if #available(macOS 10.12, watchOS 3.0, tvOS 10.0, *) {
                let string = String(sqliteStatement: sqliteStatement, index: index)
                guard let date = iso8601Formatter.date(from: string) else {
                    throw RowDecodingError.valueMismatch(
                        Date.self,
                        context: context(),
                        databaseValue: DatabaseValue(sqliteStatement: sqliteStatement, index: index))
                }
                return date
            } else {
                fatalError("ISO8601DateFormatter is unavailable on this platform.")
            }
        case .formatted(let formatter):
            let string = String(sqliteStatement: sqliteStatement, index: index)
            guard let date = formatter.date(from: string) else {
                throw RowDecodingError.valueMismatch(
                    Date.self,
                    context: context(),
                    databaseValue: DatabaseValue(sqliteStatement: sqliteStatement, index: index))
            }
            return date
        case .custom(let format):
            let dbValue = DatabaseValue(sqliteStatement: sqliteStatement, index: index)
            guard let date = format(dbValue) else {
                throw RowDecodingError.valueMismatch(
                    Date.self,
                    context: context(),
                    databaseValue: DatabaseValue(sqliteStatement: sqliteStatement, index: index))
            }
            return date
        }
    }
    
    fileprivate func decodeIfPresent(
        fromStatement sqliteStatement: SQLiteStatement,
        atUncheckedIndex index: Int32,
        context: @autoclosure () -> RowDecodingContext)
    throws -> Date?
    {
        if sqlite3_column_type(sqliteStatement, index) == SQLITE_NULL {
            return nil
        }
        return try decode(fromStatement: sqliteStatement, atUncheckedIndex: index, context: context())
    }
    
    fileprivate func decode(
        fromDatabaseValue dbValue: DatabaseValue,
        context: @autoclosure () -> RowDecodingContext)
    throws -> Date
    {
        if let date = dateFromDatabaseValue(dbValue) {
            return date
        } else {
            throw RowDecodingError.valueMismatch(Date.self, context: context(), databaseValue: dbValue)
        }
    }
    
    fileprivate func decodeIfPresent(
        fromDatabaseValue dbValue: DatabaseValue,
        context: @autoclosure () -> RowDecodingContext)
    throws -> Date?
    {
        if dbValue.isNull {
            return nil
        } else if let date = dateFromDatabaseValue(dbValue) {
            return date
        } else {
            throw RowDecodingError.valueMismatch(Date.self, context: context(), databaseValue: dbValue)
        }
    }
    
    // Returns nil if decoding fails
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
            if #available(macOS 10.12, watchOS 3.0, tvOS 10.0, *) {
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

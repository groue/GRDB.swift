import Foundation

extension FetchableRecord where Self: Decodable {
    /// Creates a record from `row`, using the `Decodable` conformance.
    public init(row: Row) throws {
        self = try FetchableRecordDecoder().decode(Self.self, from: row)
    }
}

/// An object that decodes fetchable records from database rows.
///
/// The example below shows how to decode an instance of a simple `Player`
/// type, that conforms to both ``FetchableRecord`` and `Decodable`, from a
/// database row.
///
/// ```swift
/// struct Player: FetchableRecord, Decodable {
///     var id: Int64
///     var name: String
///     var score: Int
/// }
///
/// try dbQueue.read { db in
///     if let row = try Row.fetchOne(db, sql: "SELECT * FROM player WHERE id = 42") {
///         let decoder = FetchableRecordDecoder()
///         let player = try decoder.decode(Player.self, from: row)
///         print(player.name)
///     }
/// }
/// ```
///
/// You will generally not need to create an instance of
/// `FetchableRecordDecoder`. The above sample code is correct, but you will
/// generally write instead:
///
/// ```swift
/// try dbQueue.read { db in
///     // Prefer the init(row:) initializer:
///     if let row = try Row.fetchOne(db, sql: "SELECT * FROM player WHERE id = 42") {
///         let player = try Player(row: row)
///         print(player.name)
///     }
///
///     // OR just directly fetch a player:
///     if let player = try Player.fetchOne(db, sql: "SELECT * FROM player WHERE id = 42") {
///         print(player.name)
///     }
/// }
/// ```
///
/// The behavior of the decoder depends on the decoded type. See:
///
/// - ``FetchableRecord/databaseColumnDecodingStrategy-6uefz``
/// - ``FetchableRecord/databaseDataDecodingStrategy-71bh1``
/// - ``FetchableRecord/databaseDateDecodingStrategy-78y03``
/// - ``FetchableRecord/databaseDecodingUserInfo-77jim``
/// - ``FetchableRecord/databaseJSONDecoder(for:)-7lmxd``
public class FetchableRecordDecoder {
    /// Creates a decoder for fetchable records.
    public init() { }
    
    /// Returns a record of the type you specify, decoded from a
    /// database row.
    ///
    /// - Parameters:
    ///   - type: The type of the record to decode from the supplied
    ///     database row.
    ///   - row: The database row to decode.
    /// - Returns: An instance of the specified record type, if the decoder
    ///   can parse the database row.
    public func decode<T: FetchableRecord & Decodable>(_ type: T.Type, from row: Row) throws -> T {
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
            if let _columnForKey {
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
            let row = decoder.row
            if let column = try? decodeColumn(forKey: key), row[column] != nil {
                return false
            }
            if row.scopesTree[key.stringValue] != nil {
                return false
            }
            if row.prefetchedRows[key.stringValue] != nil {
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
            guard let _columnForKey else {
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
                if type == Data.self {
                    return try R.databaseDataDecodingStrategy.decodeIfPresent(
                        fromRow: row,
                        atUncheckedIndex: index) as! T?
                } else if type == Date.self {
                    return try R.databaseDateDecodingStrategy.decodeIfPresent(
                        fromRow: row,
                        atUncheckedIndex: index) as! T?
                } else if let type = T.self as? any (DatabaseValueConvertible & StatementColumnConvertible).Type {
                    return try type.fastDecodeIfPresent(fromRow: row, atUncheckedIndex: index) as! T?
                } else if let type = T.self as? any DatabaseValueConvertible.Type {
                    return try type.decodeIfPresent(fromRow: row, atUncheckedIndex: index) as! T?
                } else if row.impl.hasNull(atUncheckedIndex: index) {
                    return nil
                } else {
                    return try decode(type, fromRow: row, columnAtIndex: index, key: key)
                }
            }
            
            // Scope?
            if let scopedRow = row.scopesTree[key.stringValue] {
                // Beware left joins: check if scoped row contains non-null
                // values before decoding
                if scopedRow.containsNonNullValue {
                    return try decode(type, fromRow: scopedRow, codingPath: codingPath + [key])
                } else {
                    return nil
                }
            }
            
            // Prefetched Rows?
            if let prefetchedRows = row.prefetchedRows[key.stringValue] {
                let decoder = PrefetchedRowsDecoder<R>(rows: prefetchedRows, codingPath: codingPath)
                return try T(from: decoder)
            }
            
            // Unknown key
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
                if type == Data.self {
                    return try R.databaseDataDecodingStrategy.decode(fromRow: row, atUncheckedIndex: index) as! T
                } else if type == Date.self {
                    return try R.databaseDateDecodingStrategy.decode(fromRow: row, atUncheckedIndex: index) as! T
                } else if let type = T.self as? any (DatabaseValueConvertible & StatementColumnConvertible).Type {
                    return try type.fastDecode(fromRow: row, atUncheckedIndex: index) as! T
                } else if let type = T.self as? any DatabaseValueConvertible.Type {
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
            
            // Unknown key
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
            // scope) has to be decoded right from the base row. But this can
            // happen only once.
            if let decodedRootKey {
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
            if let type = T.self as? any FetchableRecord.Type {
                // Prefer FetchableRecord decoding over Decodable.
                return try type.init(row: row) as! T
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
                return try row.withUnsafeData(atIndex: index) { data in
                    guard let data else {
                        throw DecodingError.valueNotFound(Data.self, DecodingError.Context(
                            codingPath: codingPath + [key],
                            debugDescription: "Missing Data"))
                    }
                    return try R
                        .databaseJSONDecoder(for: key.stringValue)
                        .decode(type.self, from: data)
                }
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
        if let type = T.self as? any FetchableRecord.Type {
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
        // TODO: not tested
        if type == Data.self {
            return try R.databaseDataDecodingStrategy.decode(fromRow: row, atUncheckedIndex: columnIndex) as! T
        } else if type == Date.self {
            return try R.databaseDateDecodingStrategy.decode(fromRow: row, atUncheckedIndex: columnIndex) as! T
        } else if let type = T.self as? any (DatabaseValueConvertible & StatementColumnConvertible).Type {
            return try type.fastDecode(fromRow: row, atUncheckedIndex: columnIndex) as! T
        } else if let type = T.self as? any DatabaseValueConvertible.Type {
            return try type.decode(fromRow: row, atUncheckedIndex: columnIndex) as! T
        } else {
            return try T(from: self)
        }
    }
}

private let iso8601Formatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = .withInternetDateTime
    return formatter
}()

extension DatabaseDataDecodingStrategy {
    fileprivate func decodeIfPresent(fromRow row: Row, atUncheckedIndex index: Int) throws -> Data? {
        if let sqliteStatement = row.sqliteStatement {
            return try decodeIfPresent(
                fromStatement: sqliteStatement,
                atUncheckedIndex: CInt(index),
                context: RowDecodingContext(row: row, key: .columnIndex(index)))
        } else {
            return try decodeIfPresent(
                fromDatabaseValue: row[index],
                context: RowDecodingContext(row: row, key: .columnIndex(index)))
        }
    }
    
    fileprivate func decode(fromRow row: Row, atUncheckedIndex index: Int) throws -> Data {
        if let sqliteStatement = row.sqliteStatement {
            return try decode(
                fromStatement: sqliteStatement,
                atUncheckedIndex: CInt(index),
                context: RowDecodingContext(row: row, key: .columnIndex(index)))
        } else {
            return try decode(
                fromDatabaseValue: row[index],
                context: RowDecodingContext(row: row, key: .columnIndex(index)))
        }
    }
    
    /// - precondition: value is not NULL
    fileprivate func decode(
        fromStatement sqliteStatement: SQLiteStatement,
        atUncheckedIndex index: CInt,
        context: @autoclosure () -> RowDecodingContext)
    throws -> Data
    {
        assert(sqlite3_column_type(sqliteStatement, index) != SQLITE_NULL, "unexpected NULL value")
        switch self {
        case .deferredToData:
            return Data(sqliteStatement: sqliteStatement, index: index)
        case .custom(let format):
            let dbValue = DatabaseValue(sqliteStatement: sqliteStatement, index: index)
            guard let data = format(dbValue) else {
                throw RowDecodingError.valueMismatch(
                    Data.self,
                    context: context(),
                    databaseValue: DatabaseValue(sqliteStatement: sqliteStatement, index: index))
            }
            return data
        }
    }
    
    fileprivate func decodeIfPresent(
        fromStatement sqliteStatement: SQLiteStatement,
        atUncheckedIndex index: CInt,
        context: @autoclosure () -> RowDecodingContext)
    throws -> Data?
    {
        if sqlite3_column_type(sqliteStatement, index) == SQLITE_NULL {
            return nil
        }
        return try decode(fromStatement: sqliteStatement, atUncheckedIndex: index, context: context())
    }
    
    fileprivate func decode(
        fromDatabaseValue dbValue: DatabaseValue,
        context: @autoclosure () -> RowDecodingContext)
    throws -> Data
    {
        if let data = dataFromDatabaseValue(dbValue) {
            return data
        } else {
            throw RowDecodingError.valueMismatch(Data.self, context: context(), databaseValue: dbValue)
        }
    }
    
    fileprivate func decodeIfPresent(
        fromDatabaseValue dbValue: DatabaseValue,
        context: @autoclosure () -> RowDecodingContext)
    throws -> Data?
    {
        if dbValue.isNull {
            return nil
        } else if let data = dataFromDatabaseValue(dbValue) {
            return data
        } else {
            throw RowDecodingError.valueMismatch(Data.self, context: context(), databaseValue: dbValue)
        }
    }
    
    // Returns nil if decoding fails
    private func dataFromDatabaseValue(_ dbValue: DatabaseValue) -> Data? {
        switch self {
        case .deferredToData:
            return Data.fromDatabaseValue(dbValue)
        case .custom(let format):
            return format(dbValue)
        }
    }
}

extension DatabaseDateDecodingStrategy {
    fileprivate func decodeIfPresent(fromRow row: Row, atUncheckedIndex index: Int) throws -> Date? {
        if let sqliteStatement = row.sqliteStatement {
            return try decodeIfPresent(
                fromStatement: sqliteStatement,
                atUncheckedIndex: CInt(index),
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
                atUncheckedIndex: CInt(index),
                context: RowDecodingContext(row: row, key: .columnIndex(index)))
        } else {
            return try decode(
                fromDatabaseValue: row[index],
                context: RowDecodingContext(row: row, key: .columnIndex(index)))
        }
    }
    
    /// - precondition: value is not NULL
    fileprivate func decode(
        fromStatement sqliteStatement: SQLiteStatement,
        atUncheckedIndex index: CInt,
        context: @autoclosure () -> RowDecodingContext)
    throws -> Date
    {
        assert(sqlite3_column_type(sqliteStatement, index) != SQLITE_NULL, "unexpected NULL value")
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
            let string = String(sqliteStatement: sqliteStatement, index: index)
            guard let date = iso8601Formatter.date(from: string) else {
                throw RowDecodingError.valueMismatch(
                    Date.self,
                    context: context(),
                    databaseValue: DatabaseValue(sqliteStatement: sqliteStatement, index: index))
            }
            return date
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
        atUncheckedIndex index: CInt,
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
            return String
                .fromDatabaseValue(dbValue)
                .flatMap { iso8601Formatter.date(from: $0) }
        case .formatted(let formatter):
            return String
                .fromDatabaseValue(dbValue)
                .flatMap { formatter.date(from: $0) }
        case .custom(let format):
            return format(dbValue)
        }
    }
}

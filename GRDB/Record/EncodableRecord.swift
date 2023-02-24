import Foundation // For JSONEncoder

/// A type that can encode itself in a database row.
///
/// To conform to `EncodableRecord`, provide an implementation for the
/// ``encode(to:)-k9pf`` method. This implementation is ready-made for
/// `Encodable` types.
///
/// Most of the time, your record types will get `EncodableRecord` conformance
/// through the ``MutablePersistableRecord`` or ``PersistableRecord`` protocols,
/// which provide persistence methods.
///
/// ## Topics
///
/// ### Encoding a Database Row
///
/// - ``encode(to:)-k9pf``
/// - ``PersistenceContainer``
///
/// ### Configuring Persistence for the Standard Encodable Protocol
///
/// - ``databaseColumnEncodingStrategy-5sx4v``
/// - ``databaseDateEncodingStrategy-2gtc1``
/// - ``databaseEncodingUserInfo-8upii``
/// - ``databaseJSONEncoder(for:)-6x62c``
/// - ``databaseUUIDEncodingStrategy-2t96q``
/// - ``DatabaseColumnEncodingStrategy``
/// - ``DatabaseDateEncodingStrategy``
/// - ``DatabaseUUIDEncodingStrategy``
///
/// ### Converting a Record to a Dictionary
///
/// - ``databaseDictionary``
///
/// ### Comparing Records
///
/// - ``databaseChanges(from:)``
/// - ``databaseChanges(modify:)``
/// - ``databaseEquals(_:)``
public protocol EncodableRecord {
    /// Encodes the record into the provided persistence container.
    ///
    /// In your implementation of this method, store in the `container` argument
    /// all values that should be stored in database columns.
    ///
    /// Primary key columns, if any, must be included.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: EncodableRecord {
    ///     var id: Int64?
    ///     var name: String?
    ///
    ///     func encode(to container: inout PersistenceContainer) {
    ///         container["id"] = id
    ///         container["name"] = name
    ///     }
    /// }
    /// ```
    ///
    /// It is undefined behavior to set different values for the same column.
    /// Column names are case insensitive, so defining both "name" and "NAME"
    /// is considered undefined behavior.
    ///
    /// - throws: An error is thrown if the record can't be encoded to its
    ///   database representation.
    func encode(to container: inout PersistenceContainer) throws
    
    // MARK: - Customizing the Format of Database Columns
    
    /// Contextual information made available to the
    /// `Encodable.encode(to:)` method.
    ///
    /// This property is dedicated to ``EncodableRecord`` types that also
    /// conform to the standard `Encodable` protocol and use the default
    /// ``encode(to:)-1mrt`` implementation.
    ///
    /// The returned dictionary is returned by `Encoder.userInfo` when the
    /// record is encoded.
    ///
    /// For example:
    ///
    /// ```swift
    /// // A key that holds a encoder's name
    /// let encoderName = CodingUserInfoKey(rawValue: "encoderName")!
    ///
    /// struct Player: PersistableRecord, Encodable {
    ///     // Customize the encoder name when encoding a database row
    ///     static let databaseEncodingUserInfo: [CodingUserInfoKey: Any] = [encoderName: "Database"]
    ///
    ///     func encode(to encoder: Encoder) throws {
    ///         // Print the encoder name
    ///         print(encoder.userInfo[encoderName])
    ///         ...
    ///     }
    /// }
    ///
    /// let player = Player(...)
    ///
    /// // prints "Database"
    /// try player.insert(db)
    ///
    /// // prints "JSON"
    /// let encoder = JSONEncoder()
    /// encoder.userInfo = [encoderName: "JSON"]
    /// let data = try encoder.encode(player)
    /// ```
    static var databaseEncodingUserInfo: [CodingUserInfoKey: Any] { get }
    
    /// Returns the `JSONEncoder` that encodes the value for a given column.
    ///
    /// This method is dedicated to ``EncodableRecord`` types that also conform
    /// to the standard `Encodable` protocol and use the default
    /// ``encode(to:)-1mrt`` implementation.
    static func databaseJSONEncoder(for column: String) -> JSONEncoder
    
    /// The strategy for encoding `Date` columns.
    ///
    /// This property is dedicated to ``EncodableRecord`` types that also
    /// conform to the standard `Encodable` protocol and use the default
    /// ``encode(to:)-1mrt`` implementation.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: EncodableRecord, Encodable {
    ///     static let databaseDateEncodingStrategy = DatabaseDateEncodingStrategy.timeIntervalSince1970
    ///
    ///     // Encoded as an epoch timestamp
    ///     var creationDate: Date
    /// }
    /// ```
    static var databaseDateEncodingStrategy: DatabaseDateEncodingStrategy { get }
    
    /// The strategy for encoding `UUID` columns.
    ///
    /// This property is dedicated to ``EncodableRecord`` types that also
    /// conform to the standard `Encodable` protocol and use the default
    /// ``encode(to:)-1mrt`` implementation.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: EncodableRecord, Encodable {
    ///     static let databaseUUIDEncodingStrategy = DatabaseUUIDEncodingStrategy.uppercaseString
    ///
    ///     // Encoded in a string like "E621E1F8-C36C-495A-93FC-0C247A3E6E5F"
    ///     var uuid: UUID
    /// }
    /// ```
    static var databaseUUIDEncodingStrategy: DatabaseUUIDEncodingStrategy { get }
    
    /// The strategy for converting coding keys to column names.
    ///
    /// This property is dedicated to ``EncodableRecord`` types that also
    /// conform to the standard `Encodable` protocol and use the default
    /// ``encode(to:)-1mrt`` implementation.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: EncodableProtocol, Encodable {
    ///     static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    ///
    ///     // Encoded in the 'player_id' column
    ///     var playerID: String
    /// }
    /// ```
    static var databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy { get }
}

extension EncodableRecord {
    /// Contextual information made available to the
    /// `Encodable.encode(to:)` method.
    ///
    /// The default implementation returns an empty dictionary.
    public static var databaseEncodingUserInfo: [CodingUserInfoKey: Any] {
        [:]
    }
    
    /// Returns the `JSONEncoder` that encodes the value for a given column.
    ///
    /// The default implementation returns a `JSONEncoder` with the
    /// following properties:
    ///
    /// - `dataEncodingStrategy`: `.base64`
    /// - `dateEncodingStrategy`: `.millisecondsSince1970`
    /// - `nonConformingFloatEncodingStrategy`: `.throw`
    /// - `outputFormatting`: `.sortedKeys`
    public static func databaseJSONEncoder(for column: String) -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dataEncodingStrategy = .base64
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.nonConformingFloatEncodingStrategy = .throw
        // guarantee some stability in order to ease record comparison
        encoder.outputFormatting = .sortedKeys
        encoder.userInfo = databaseEncodingUserInfo
        return encoder
    }
    
    /// Returns the default strategy for encoding `Date` columns:
    /// ``DatabaseDateEncodingStrategy/deferredToDate``.
    public static var databaseDateEncodingStrategy: DatabaseDateEncodingStrategy {
        .deferredToDate
    }
    
    /// Returns the default strategy for encoding `UUID` columns:
    /// ``DatabaseUUIDEncodingStrategy/deferredToUUID``.
    public static var databaseUUIDEncodingStrategy: DatabaseUUIDEncodingStrategy {
        .deferredToUUID
    }
    
    /// Returns the default strategy for converting coding keys to column names:
    /// ``DatabaseColumnEncodingStrategy/useDefaultKeys``.
    public static var databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy {
        .useDefaultKeys
    }
}

extension EncodableRecord {
    /// A dictionary whose keys are the columns encoded in the
    /// <doc:/documentation/GRDB/EncodableRecord/encode(to:)-k9pf> method.
    ///
    /// - throws: An error is thrown if the record can't be encoded to its
    ///   database representation.
    public var databaseDictionary: [String: DatabaseValue] {
        get throws {
            try Dictionary(PersistenceContainer(self).storage).mapValues { $0?.databaseValue ?? .null }
        }
    }
}

extension EncodableRecord {
    
    // MARK: - Record Comparison
    
    /// Returns a boolean indicating whether this record and the other record
    /// have the same database representation.
    public func databaseEquals(_ record: Self) -> Bool {
        do {
            return try PersistenceContainer(self).changesIterator(from: PersistenceContainer(record)).next() == nil
        } catch {
            // one record can't be encoded: they can't be identical in the database
            return false
        }
    }
    
    /// Returns a dictionary of values changed from the other record.
    ///
    /// The keys of the dictionary are the column names for which record do not
    /// share the same value. Values are the database values from the
    /// `other` record.
    ///
    /// Note that the `other` record does not have to have the same type of the
    /// receiver record. When the two records don't define the same set of
    /// columns in their <doc:/documentation/GRDB/EncodableRecord/encode(to:)-k9pf>
    /// method, only the columns defined by the receiver are considered.
    ///
    /// - throws: An error is thrown if one record can't be encoded to its
    ///   database representation.
    public func databaseChanges(from record: some EncodableRecord)
    throws -> [String: DatabaseValue]
    {
        let changes = try PersistenceContainer(self).changesIterator(from: PersistenceContainer(record))
        return Dictionary(uniqueKeysWithValues: changes)
    }
    
    /// Modifies the record according to the provided `modify` closure, and
    /// returns a dictionary of changed values.
    ///
    /// The keys of the dictionary are the changed column names. Values are
    /// the database values from the initial version record.
    ///
    /// For example:
    ///
    /// ```swift
    /// var player = Player(id: 1, score: 1000, hasAward: false)
    /// let changes = try player.databaseChanges {
    ///     $0.score = 1000
    ///     $0.hasAward = true
    /// }
    ///
    /// player.hasAward     // true (changed)
    ///
    /// changes["score"]    // nil (not changed)
    /// changes["hasAward"] // false (old value)
    /// ```
    ///
    /// - parameter modify: A closure that modifies the record.
    public mutating func databaseChanges(modify: (inout Self) throws -> Void)
    throws -> [String: DatabaseValue]
    {
        let container = try PersistenceContainer(self)
        try modify(&self)
        let changes = try PersistenceContainer(self).changesIterator(from: container)
        return Dictionary(uniqueKeysWithValues: changes)
    }
}

// MARK: - PersistenceContainer

/// A container for database values to store in a database row.
///
/// `PersistenceContainer` is the argument of the
/// ``EncodableRecord/encode(to:)-k9pf`` method.
public struct PersistenceContainer {
    // fileprivate for Row(_:PersistenceContainer)
    // The ordering of the OrderedDictionary helps generating always the same
    // SQL queries, and hit the statement cache.
    fileprivate var storage: OrderedDictionary<String, (any DatabaseValueConvertible)?>
    
    /// The value associated with the given column.
    public subscript(_ column: String) -> (any DatabaseValueConvertible)? {
        get { self[caseInsensitive: column] }
        set { storage.updateValue(newValue, forKey: column) }
    }
    
    /// The value associated with the given column.
    public subscript(_ column: some ColumnExpression) -> (any DatabaseValueConvertible)? {
        get { self[column.name] }
        set { self[column.name] = newValue }
    }
    
    init() {
        storage = OrderedDictionary()
    }
    
    init(minimumCapacity: Int) {
        storage = OrderedDictionary(minimumCapacity: minimumCapacity)
    }
    
    /// Convenience initializer from a record
    init<Record: EncodableRecord>(_ record: Record) throws {
        self.init()
        try record.encode(to: &self)
    }
    
    /// Convenience initializer from a database connection and a record
    @usableFromInline
    init(_ db: Database, _ record: some EncodableRecord & TableRecord) throws {
        let databaseTableName = type(of: record).databaseTableName
        let columnCount = try db.columns(in: databaseTableName).count
        self.init(minimumCapacity: columnCount) // Optimization
        try record.encode(to: &self)
    }
    
    /// Columns stored in the container, ordered like values.
    var columns: [String] { Array(storage.keys) }
    
    /// Values stored in the container, ordered like columns.
    var values: [(any DatabaseValueConvertible)?] { Array(storage.values) }
    
    /// Accesses the value associated with the given column, in a
    /// case-insensitive fashion.
    subscript(caseInsensitive column: String) -> (any DatabaseValueConvertible)? {
        get {
            if let value = storage[column] {
                return value
            }
            let lowercaseColumn = column.lowercased()
            for (key, value) in storage where key.lowercased() == lowercaseColumn {
                return value
            }
            return nil
        }
        set {
            if storage[column] != nil {
                storage[column] = newValue
                return
            }
            let lowercaseColumn = column.lowercased()
            for key in storage.keys where key.lowercased() == lowercaseColumn {
                storage[key] = newValue
                return
            }
            
            storage[column] = newValue
        }
    }
    
    // Returns nil if column is not defined
    func value(forCaseInsensitiveColumn column: String) -> DatabaseValue? {
        let lowercaseColumn = column.lowercased()
        for (key, value) in storage where key.lowercased() == lowercaseColumn {
            return value?.databaseValue ?? .null
        }
        return nil
    }
    
    var isEmpty: Bool { storage.isEmpty }
    
    /// An iterator over the (column, value) pairs
    func makeIterator() -> IndexingIterator<OrderedDictionary<String, (any DatabaseValueConvertible)?>> {
        storage.makeIterator()
    }
    
    @usableFromInline
    func changesIterator(from container: PersistenceContainer) -> AnyIterator<(String, DatabaseValue)> {
        var newValueIterator = makeIterator()
        return AnyIterator {
            // Loop until we find a change, or exhaust columns:
            while let (column, newValue) = newValueIterator.next() {
                let oldValue = container[caseInsensitive: column]
                let oldDbValue = oldValue?.databaseValue ?? .null
                let newDbValue = newValue?.databaseValue ?? .null
                if newDbValue != oldDbValue {
                    return (column, oldDbValue)
                }
            }
            return nil
        }
    }
}

extension Row {
    convenience init<Record: EncodableRecord>(_ record: Record) throws {
        try self.init(PersistenceContainer(record))
    }
    
    convenience init(_ container: PersistenceContainer) {
        self.init(Dictionary(container.storage))
    }
}

// MARK: - DatabaseDateEncodingStrategy

/// `DatabaseDateEncodingStrategy` specifies how `EncodableRecord` types that
/// also adopt the standard `Encodable` protocol encode their `Date` properties
/// in the default <doc:/documentation/GRDB/EncodableRecord/encode(to:)-1mrt>
/// implementation.
///
/// For example:
///
/// ```swift
/// struct Player: EncodableRecord, Encodable {
///     static let databaseDateEncodingStrategy = DatabaseDateEncodingStrategy.timeIntervalSince1970
///
///     // Encoded as an epoch timestamp
///     var creationDate: Date
/// }
/// ```
public enum DatabaseDateEncodingStrategy {
    /// The strategy that uses formatting from the Date structure.
    ///
    /// It encodes dates using the format "YYYY-MM-DD HH:MM:SS.SSS" in the
    /// UTC time zone.
    case deferredToDate
    
    /// Encodes a Double: the number of seconds between the date and
    /// midnight UTC on 1 January 2001
    case timeIntervalSinceReferenceDate
    
    /// Encodes a Double: the number of seconds between the date and
    /// midnight UTC on 1 January 1970
    case timeIntervalSince1970
    
    /// Encodes an Int64: the number of seconds between the date and
    /// midnight UTC on 1 January 1970
    case secondsSince1970
    
    /// Encodes an Int64: the number of milliseconds between the date and
    /// midnight UTC on 1 January 1970
    case millisecondsSince1970
    
    /// Encodes dates according to the ISO 8601 and RFC 3339 standards
    case iso8601
    
    /// Encodes a String, according to the provided formatter
    case formatted(DateFormatter)
    
    /// Encodes the result of the user-provided function
    case custom((Date) -> (any DatabaseValueConvertible)?)
    
    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = .withInternetDateTime
        return formatter
    }()
    
    func encode(_ date: Date) -> DatabaseValue {
        switch self {
        case .deferredToDate:
            return date.databaseValue
        case .timeIntervalSinceReferenceDate:
            return date.timeIntervalSinceReferenceDate.databaseValue
        case .timeIntervalSince1970:
            return date.timeIntervalSince1970.databaseValue
        case .millisecondsSince1970:
            return Int64(floor(1000.0 * date.timeIntervalSince1970)).databaseValue
        case .secondsSince1970:
            return Int64(floor(date.timeIntervalSince1970)).databaseValue
        case .iso8601:
            return Self.iso8601Formatter.string(from: date).databaseValue
        case .formatted(let formatter):
            return formatter.string(from: date).databaseValue
        case .custom(let format):
            return format(date)?.databaseValue ?? .null
        }
    }
}

// MARK: - DatabaseUUIDEncodingStrategy

/// `DatabaseUUIDEncodingStrategy` specifies how `EncodableRecord` types that
/// also adopt the standard `Encodable` protocol encode their `UUID` properties
/// in the default <doc:/documentation/GRDB/EncodableRecord/encode(to:)-1mrt>
/// implementation.
///
/// For example:
///
/// ```swift
/// struct Player: EncodableRecord, Encodable {
///     static let databaseUUIDEncodingStrategy = DatabaseUUIDEncodingStrategy.uppercaseString
///
///     // Encoded in a string like "E621E1F8-C36C-495A-93FC-0C247A3E6E5F"
///     var uuid: UUID
/// }
/// ```
public enum DatabaseUUIDEncodingStrategy {
    /// The strategy that uses formatting from the UUID type.
    ///
    /// It encodes UUIDs as 16-bytes data blobs.
    case deferredToUUID
    
    /// Encodes UUIDs as uppercased strings such as "E621E1F8-C36C-495A-93FC-0C247A3E6E5F"
    case uppercaseString
    
    /// Encodes UUIDs as lowercased strings such as "e621e1f8-c36c-495a-93fc-0c247a3e6e5f"
    case lowercaseString
    
    func encode(_ uuid: UUID) -> DatabaseValue {
        switch self {
        case .deferredToUUID:
            return uuid.databaseValue
        case .uppercaseString:
            return uuid.uuidString.databaseValue
        case .lowercaseString:
            return uuid.uuidString.lowercased().databaseValue
        }
    }
}

// MARK: - DatabaseColumnEncodingStrategy

/// `DatabaseColumnEncodingStrategy` specifies how `EncodableRecord` types that
/// also adopt the standard `Encodable` protocol encode their coding keys into
/// database columns in the default <doc:/documentation/GRDB/EncodableRecord/encode(to:)-1mrt>
/// implementation.
///
/// For example:
///
/// ```swift
/// struct Player: EncodableProtocol, Encodable {
///     static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
///
///     // Encoded in the 'player_id' column
///     var playerID: String
/// }
/// ```
public enum DatabaseColumnEncodingStrategy {
    /// A key encoding strategy that doesn’t change key names during encoding.
    case useDefaultKeys
    
    /// A key encoding strategy that converts camel-case keys to snake-case keys.
    case convertToSnakeCase
    
    /// A key encoding strategy defined by the closure you supply.
    case custom((any CodingKey) -> String)
    
    func column(forKey key: some CodingKey) -> String {
        switch self {
        case .useDefaultKeys:
            return key.stringValue
        case .convertToSnakeCase:
            return Self._convertToSnakeCase(key.stringValue)
        case let .custom(column):
            return column(key)
        }
    }
    
    // Copied straight from
    // https://github.com/apple/swift-corelibs-foundation/blob/8d6398d76eaf886a214e0bb2bd7549d968f7b40e/Sources/Foundation/JSONEncoder.swift#L127
    static func _convertToSnakeCase(_ stringKey: String) -> String {
        //===----------------------------------------------------------------------===//
        //
        // This function is part of the Swift.org open source project
        //
        // Copyright (c) 2014 - 2020 Apple Inc. and the Swift project authors
        // Licensed under Apache License v2.0 with Runtime Library Exception
        //
        // See https://swift.org/LICENSE.txt for license information
        // See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
        //
        //===----------------------------------------------------------------------===//
        guard !stringKey.isEmpty else { return stringKey }

        var words: [Range<String.Index>] = []
        // The general idea of this algorithm is to split words on transition
        // from lower to upper case, then on transition of >1 upper case
        // characters to lowercase
        //
        // myProperty -> my_property
        // myURLProperty -> my_url_property
        //
        // We assume, per Swift naming conventions, that the first character of
        // the key is lowercase.
        var wordStart = stringKey.startIndex
        var searchRange = stringKey.index(after: wordStart)..<stringKey.endIndex

        // Find next uppercase character
        while let upperCaseRange = stringKey.rangeOfCharacter(
                from: CharacterSet.uppercaseLetters,
                options: [], range: searchRange)
        {
            let untilUpperCase = wordStart..<upperCaseRange.lowerBound
            words.append(untilUpperCase)

            // Find next lowercase character
            searchRange = upperCaseRange.lowerBound..<searchRange.upperBound
            guard let lowerCaseRange = stringKey.rangeOfCharacter(
                    from: CharacterSet.lowercaseLetters,
                    options: [],
                    range: searchRange)
            else {
                // There are no more lower case letters. Just end here.
                wordStart = searchRange.lowerBound
                break
            }

            // Is the next lowercase letter more than 1 after the uppercase? If
            // so, we encountered a group of uppercase letters that we should
            // treat as its own word
            let nextCharacterAfterCapital = stringKey.index(after: upperCaseRange.lowerBound)
            if lowerCaseRange.lowerBound == nextCharacterAfterCapital {
                // The next character after capital is a lower case character
                // and therefore not a word boundary.
                // Continue searching for the next upper case for the boundary.
                wordStart = upperCaseRange.lowerBound
            } else {
                // There was a range of >1 capital letters. Turn those into a
                // word, stopping at the capital before the lower case character.
                let beforeLowerIndex = stringKey.index(before: lowerCaseRange.lowerBound)
                words.append(upperCaseRange.lowerBound..<beforeLowerIndex)

                // Next word starts at the capital before the lowercase we just found
                wordStart = beforeLowerIndex
            }
            searchRange = lowerCaseRange.upperBound..<searchRange.upperBound
        }
        words.append(wordStart..<searchRange.upperBound)
        let result = words
            .map { (range) in stringKey[range].lowercased() }
            .joined(separator: "_")
        return result
    }
}

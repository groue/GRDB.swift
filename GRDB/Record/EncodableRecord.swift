import Foundation // For JSONEncoder

/// Types that adopt `EncodableRecord` can be encoded into the database.
public protocol EncodableRecord {
    /// Encodes the record into database values.
    ///
    /// Store in the *container* argument all values that should be stored in
    /// the columns of the database table (see databaseTableName()).
    ///
    /// Primary key columns, if any, must be included.
    ///
    ///     struct Player: EncodableRecord {
    ///         var id: Int64?
    ///         var name: String?
    ///
    ///         func encode(to container: inout PersistenceContainer) {
    ///             container["id"] = id
    ///             container["name"] = name
    ///         }
    ///     }
    ///
    /// It is undefined behavior to set different values for the same column.
    /// Column names are case insensitive, so defining both "name" and "NAME"
    /// is considered undefined behavior.
    func encode(to container: inout PersistenceContainer)
    
    // MARK: - Customizing the Format of Database Columns
    
    /// When the EncodableRecord type also adopts the standard Encodable
    /// protocol, you can use this dictionary to customize the encoding process
    /// into database rows.
    ///
    /// For example:
    ///
    ///     // A key that holds a encoder's name
    ///     let encoderName = CodingUserInfoKey(rawValue: "encoderName")!
    ///
    ///     struct Player: PersistableRecord, Encodable {
    ///         // Customize the encoder name when encoding a database row
    ///         static let databaseEncodingUserInfo: [CodingUserInfoKey: Any] = [encoderName: "Database"]
    ///
    ///         func encode(to encoder: Encoder) throws {
    ///             // Print the encoder name
    ///             print(encoder.userInfo[encoderName])
    ///             ...
    ///         }
    ///     }
    ///
    ///     let player = Player(...)
    ///
    ///     // prints "Database"
    ///     try player.insert(db)
    ///
    ///     // prints "JSON"
    ///     let encoder = JSONEncoder()
    ///     encoder.userInfo = [encoderName: "JSON"]
    ///     let data = try encoder.encode(player)
    static var databaseEncodingUserInfo: [CodingUserInfoKey: Any] { get }
    
    /// When the EncodableRecord type also adopts the standard Encodable
    /// protocol, this method controls the encoding process of nested properties
    /// into JSON database columns.
    ///
    /// The default implementation returns a JSONEncoder with the
    /// following properties:
    ///
    /// - dataEncodingStrategy: .base64
    /// - dateEncodingStrategy: .millisecondsSince1970
    /// - nonConformingFloatEncodingStrategy: .throw
    /// - outputFormatting: .sortedKeys (iOS 11.0+, macOS 10.13+, tvOS 11.0+, watchOS 4.0+)
    ///
    /// You can override those defaults:
    ///
    ///     struct Achievement: Encodable {
    ///         var name: String
    ///         var date: Date
    ///     }
    ///
    ///     struct Player: Encodable, PersistableRecord {
    ///         // stored in a JSON column
    ///         var achievements: [Achievement]
    ///
    ///         static func databaseJSONEncoder(for column: String) -> JSONEncoder {
    ///             let encoder = JSONEncoder()
    ///             encoder.dateEncodingStrategy = .iso8601
    ///             return encoder
    ///         }
    ///     }
    static func databaseJSONEncoder(for column: String) -> JSONEncoder
    
    /// When the EncodableRecord type also adopts the standard Encodable
    /// protocol, this property controls the encoding of date properties.
    ///
    /// Default value is .deferredToDate
    ///
    /// For example:
    ///
    ///     struct Player: PersistableRecord, Encodable {
    ///         static let databaseDateEncodingStrategy: DatabaseDateEncodingStrategy = .timeIntervalSince1970
    ///
    ///         var name: String
    ///         var registrationDate: Date // encoded as an epoch timestamp
    ///     }
    static var databaseDateEncodingStrategy: DatabaseDateEncodingStrategy { get }
    
    /// When the EncodableRecord type also adopts the standard Encodable
    /// protocol, this property controls the encoding of UUID properties.
    ///
    /// Default value is .deferredToUUID
    ///
    /// For example:
    ///
    ///     struct Player: PersistableProtocol, Encodable {
    ///         static let databaseUUIDEncodingStrategy: DatabaseUUIDEncodingStrategy = .uppercaseString
    ///
    ///         // encoded in a string like "E621E1F8-C36C-495A-93FC-0C247A3E6E5F"
    ///         var uuid: UUID
    ///     }
    static var databaseUUIDEncodingStrategy: DatabaseUUIDEncodingStrategy { get }
    
    /// When the EncodableRecord type also adopts the standard Encodable
    /// protocol, this property controls the key encoding strategy.
    ///
    /// Default value is .useDefaultKeys
    ///
    /// For example:
    ///
    ///     struct Player: PersistableProtocol, Encodable {
    ///         static let databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy = .convertToSnakeCase
    ///
    ///         // encoded as player_id
    ///         var playerID: String
    ///     }
    static var databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy { get }
}

extension EncodableRecord {
    public static var databaseEncodingUserInfo: [CodingUserInfoKey: Any] {
        [:]
    }
    
    public static func databaseJSONEncoder(for column: String) -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dataEncodingStrategy = .base64
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.nonConformingFloatEncodingStrategy = .throw
        if #available(watchOS 4.0, OSX 10.13, iOS 11.0, tvOS 11.0, *) {
            // guarantee some stability in order to ease record comparison
            encoder.outputFormatting = .sortedKeys
        }
        encoder.userInfo = databaseEncodingUserInfo
        return encoder
    }
    
    public static var databaseDateEncodingStrategy: DatabaseDateEncodingStrategy {
        .deferredToDate
    }
    
    public static var databaseUUIDEncodingStrategy: DatabaseUUIDEncodingStrategy {
        .deferredToUUID
    }
    
    public static var databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy {
        .useDefaultKeys
    }
}

extension EncodableRecord {
    /// A dictionary whose keys are the columns encoded in the `encode(to:)` method.
    public var databaseDictionary: [String: DatabaseValue] {
        Dictionary(PersistenceContainer(self).storage).mapValues { $0?.databaseValue ?? .null }
    }
}

extension EncodableRecord {
    
    // MARK: - Record Comparison
    
    /// Returns a boolean indicating whether this record and the other record
    /// have the same database representation.
    public func databaseEquals(_ record: Self) -> Bool {
        PersistenceContainer(self).changesIterator(from: PersistenceContainer(record)).next() == nil
    }
    
    /// A dictionary of values changed from the other record.
    ///
    /// Its keys are column names. Its values come from the other record.
    ///
    /// Note that this method is not symmetrical, not only in terms of values,
    /// but also in terms of columns. When the two records don't define the
    /// same set of columns in their `encode(to:)` method, only the columns
    /// defined by the receiver record are considered.
    public func databaseChanges<Record: EncodableRecord>(from record: Record) -> [String: DatabaseValue] {
        let changes = PersistenceContainer(self).changesIterator(from: PersistenceContainer(record))
        return Dictionary(uniqueKeysWithValues: changes)
    }
}

// MARK: - PersistenceContainer

/// Use persistence containers in the `encode(to:)` method of your
/// encodable records:
///
///     struct Player: EncodableRecord {
///         var id: Int64?
///         var name: String?
///
///         func encode(to container: inout PersistenceContainer) {
///             container["id"] = id
///             container["name"] = name
///         }
///     }
public struct PersistenceContainer {
    // fileprivate for Row(_:PersistenceContainer)
    // The ordering of the OrderedDictionary helps generating always the same
    // SQL queries, and hit the statement cache.
    fileprivate var storage: OrderedDictionary<String, DatabaseValueConvertible?>
    
    /// Accesses the value associated with the given column.
    ///
    /// It is undefined behavior to set different values for the same column.
    /// Column names are case insensitive, so defining both "name" and "NAME"
    /// is considered undefined behavior.
    public subscript(_ column: String) -> DatabaseValueConvertible? {
        get { storage[column] ?? nil }
        set { storage.updateValue(newValue, forKey: column) }
    }
    
    /// Accesses the value associated with the given column.
    ///
    /// It is undefined behavior to set different values for the same column.
    /// Column names are case insensitive, so defining both "name" and "NAME"
    /// is considered undefined behavior.
    public subscript<Column: ColumnExpression>(_ column: Column) -> DatabaseValueConvertible? {
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
    init<Record: EncodableRecord>(_ record: Record) {
        self.init()
        record.encode(to: &self)
    }
    
    /// Columns stored in the container, ordered like values.
    var columns: [String] { Array(storage.keys) }
    
    /// Values stored in the container, ordered like columns.
    var values: [DatabaseValueConvertible?] { Array(storage.values) }
    
    /// Accesses the value associated with the given column, in a
    /// case-insensitive fashion.
    ///
    /// :nodoc:
    subscript(caseInsensitive column: String) -> DatabaseValueConvertible? {
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
    func makeIterator() -> IndexingIterator<OrderedDictionary<String, DatabaseValueConvertible?>> {
        storage.makeIterator()
    }
    
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
    convenience init<Record: EncodableRecord>(_ record: Record) {
        self.init(PersistenceContainer(record))
    }
    
    convenience init(_ container: PersistenceContainer) {
        self.init(Dictionary(container.storage))
    }
}

// MARK: - DatabaseDateEncodingStrategy

/// `DatabaseDateEncodingStrategy` specifies how `EncodableRecord` types that
/// also adopt the standard `Encodable` protocol encode their `Date` properties.
///
/// For example:
///
///     struct Player: EncodableRecord, Encodable {
///         static let databaseDateEncodingStrategy = DatabaseDateEncodingStrategy.timeIntervalSince1970
///
///         var name: String
///         var registrationDate: Date // encoded as an epoch timestamp
///     }
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
    @available(macOS 10.12, watchOS 3.0, tvOS 10.0, *)
    case iso8601
    
    /// Encodes a String, according to the provided formatter
    case formatted(DateFormatter)
    
    /// Encodes the result of the user-provided function
    case custom((Date) -> DatabaseValueConvertible?)
    
    @available(macOS 10.12, watchOS 3.0, tvOS 10.0, *)
    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = .withInternetDateTime
        return formatter
    }()
    
    func encode(_ date: Date) -> DatabaseValueConvertible? {
        switch self {
        case .deferredToDate:
            return date.databaseValue
        case .timeIntervalSinceReferenceDate:
            return date.timeIntervalSinceReferenceDate
        case .timeIntervalSince1970:
            return date.timeIntervalSince1970
        case .millisecondsSince1970:
            return Int64(floor(1000.0 * date.timeIntervalSince1970))
        case .secondsSince1970:
            return Int64(floor(date.timeIntervalSince1970))
        case .iso8601:
            if #available(macOS 10.12, watchOS 3.0, tvOS 10.0, *) {
                return Self.iso8601Formatter.string(from: date)
            } else {
                fatalError("ISO8601DateFormatter is unavailable on this platform.")
            }
        case .formatted(let formatter):
            return formatter.string(from: date)
        case .custom(let format):
            return format(date)
        }
    }
}

// MARK: - DatabaseUUIDEncodingStrategy

/// `DatabaseUUIDEncodingStrategy` specifies how `EncodableRecord` types that
/// also adopt the standard `Encodable` protocol encode their `UUID` properties.
///
/// For example:
///
///     struct Player: EncodableProtocol, Encodable {
///         static let databaseUUIDEncodingStrategy = DatabaseUUIDEncodingStrategy.uppercaseString
///
///         // encoded in a string like "E621E1F8-C36C-495A-93FC-0C247A3E6E5F"
///         var uuid: UUID
///     }
public enum DatabaseUUIDEncodingStrategy {
    /// The strategy that uses formatting from the UUID type.
    ///
    /// It encodes UUIDs as 16-bytes data blobs.
    case deferredToUUID
    
    /// Encodes UUIDs as uppercased strings such as "E621E1F8-C36C-495A-93FC-0C247A3E6E5F"
    case uppercaseString
    
    /// Encodes UUIDs as lowercased strings such as "e621e1f8-c36c-495a-93fc-0c247a3e6e5f"
    case lowercaseString
    
    /// Encodes UUIDs as uppercased strings such as "E621E1F8-C36C-495A-93FC-0C247A3E6E5F"
    @available(*, deprecated, renamed: "uppercaseString")
    public static var string: Self { .uppercaseString }
    
    func encode(_ uuid: UUID) -> DatabaseValueConvertible {
        switch self {
        case .deferredToUUID:
            return uuid.databaseValue
        case .uppercaseString:
            return uuid.uuidString
        case .lowercaseString:
            return uuid.uuidString.lowercased()
        }
    }
}

// MARK: - DatabaseColumnEncodingStrategy

/// `DatabaseColumnEncodingStrategy` specifies how `EncodableRecord` types that
/// also adopt the standard `Encodable` protocol encode their coding keys into
/// database columns.
///
/// For example:
///
///     struct Player: EncodableProtocol, Encodable {
///         static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
///
///         // Encoded in the player_id column
///         var playerID: String
///     }
public enum DatabaseColumnEncodingStrategy {
    /// A key encoding strategy that doesn’t change key names during encoding.
    case useDefaultKeys
    
    /// A key encoding strategy that converts camel-case keys to snake-case keys.
    case convertToSnakeCase
    
    /// A key encoding strategy defined by the closure you supply.
    case custom((CodingKey) -> String)
    
    func column(forKey key: CodingKey) -> String {
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
        let result = words.map({ (range) in
            return stringKey[range].lowercased()
        }).joined(separator: "_")
        return result
    }
}

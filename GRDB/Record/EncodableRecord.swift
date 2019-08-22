import Foundation // For JSONEncoder

/// Types that adopt EncodableRecord can be encoded into the database.
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
    ///         static let databaseUUIDEncodingStrategy: DatabaseUUIDEncodingStrategy = .string
    ///
    ///         // encoded in a string like "E621E1F8-C36C-495A-93FC-0C247A3E6E5F"
    ///         var uuid: UUID
    ///     }
    static var databaseUUIDEncodingStrategy: DatabaseUUIDEncodingStrategy { get }
}

extension EncodableRecord {
    public static var databaseEncodingUserInfo: [CodingUserInfoKey: Any] {
        return [:]
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
        return encoder
    }
    
    public static var databaseDateEncodingStrategy: DatabaseDateEncodingStrategy {
        return .deferredToDate
    }
    
    public static var databaseUUIDEncodingStrategy: DatabaseUUIDEncodingStrategy {
        return .deferredToUUID
    }
}

extension EncodableRecord {
    /// A dictionary whose keys are the columns encoded in the `encode(to:)` method.
    public var databaseDictionary: [String: DatabaseValue] {
        return Dictionary(PersistenceContainer(self).storage).mapValues { $0?.databaseValue ?? .null }
    }
}

extension EncodableRecord {
    
    // MARK: - Record Comparison
    
    /// Returns a boolean indicating whether this record and the other record
    /// have the same database representation.
    public func databaseEquals(_ record: Self) -> Bool {
        return PersistenceContainer(self).changesIterator(from: PersistenceContainer(record)).next() == nil
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
    @usableFromInline var storage: OrderedDictionary<String, DatabaseValueConvertible?>
    
    /// Accesses the value associated with the given column.
    ///
    /// It is undefined behavior to set different values for the same column.
    /// Column names are case insensitive, so defining both "name" and "NAME"
    /// is considered undefined behavior.
    @inlinable
    public subscript(_ column: String) -> DatabaseValueConvertible? {
        get { return storage[column] ?? nil }
        set { storage.updateValue(newValue, forKey: column) }
    }
    
    /// Accesses the value associated with the given column.
    ///
    /// It is undefined behavior to set different values for the same column.
    /// Column names are case insensitive, so defining both "name" and "NAME"
    /// is considered undefined behavior.
    @inlinable
    public subscript<Column: ColumnExpression>(_ column: Column) -> DatabaseValueConvertible? {
        get { return self[column.name] }
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
    var columns: [String] {
        return Array(storage.keys)
    }
    
    /// Values stored in the container, ordered like columns.
    var values: [DatabaseValueConvertible?] {
        return Array(storage.values)
    }
    
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
    
    var isEmpty: Bool {
        return storage.isEmpty
    }
    
    /// An iterator over the (column, value) pairs
    func makeIterator() -> IndexingIterator<OrderedDictionary<String, DatabaseValueConvertible?>> {
        return storage.makeIterator()
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

/// DatabaseDateEncodingStrategy specifies how EncodableRecord types that also
/// adopt the standard Encodable protocol encode their date properties.
///
/// For example:
///
///     struct Player: EncodableRecord, Encodable {
///         static let databaseDateEncodingStrategy: DatabaseDateEncodingStrategy = .timeIntervalSince1970
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
    @available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
    case iso8601
    
    /// Encodes a String, according to the provided formatter
    case formatted(DateFormatter)
    
    /// Encodes the result of the user-provided function
    case custom((Date) -> DatabaseValueConvertible?)
}

// MARK: - DatabaseUUIDEncodingStrategy

/// DatabaseUUIDEncodingStrategy specifies how EncodableRecord types that also
/// adopt the standard Encodable protocol encode their UUID properties.
///
/// For example:
///
///     struct Player: EncodableProtocol, Encodable {
///         static let databaseUUIDEncodingStrategy: DatabaseUUIDEncodingStrategy = .string
///
///         // encoded in a string like "E621E1F8-C36C-495A-93FC-0C247A3E6E5F"
///         var uuid: UUID
///     }
public enum DatabaseUUIDEncodingStrategy {
    /// The strategy that uses formatting from the UUID type.
    ///
    /// It encodes UUIDs as 16-bytes data blobs.
    case deferredToUUID
    
    /// Encodes UUIDs as strings such as "E621E1F8-C36C-495A-93FC-0C247A3E6E5F"
    case string
}

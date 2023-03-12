import Foundation

/// A type that builds database queries with the Swift language instead of SQL.
///
/// A `TableRecord` type is tied to one database table, and can build SQL
/// queries on that table.
///
/// To build SQL queries that involve several tables, define some ``Association``
/// between two `TableRecord` types.
///
/// Most of the time, your record types will get `TableRecord` conformance
/// through the ``MutablePersistableRecord`` or ``PersistableRecord`` protocols,
/// which provide persistence methods.
///
/// ## Topics
///
/// ### Configuring the Generated SQL
///
/// - ``databaseTableName-3tcw2``
/// - ``databaseSelection-7iphs``
/// - ``numberOfSelectedColumns(_:)``
///
/// ### Counting Records
///
/// - ``fetchCount(_:)``
///
/// ### Testing for Record Existence
///
/// - ``exists(_:id:)``
/// - ``exists(_:key:)-60hf2``
/// - ``exists(_:key:)-6ha6``
///
/// ### Throwing Record Not Found Errors
///
/// - ``recordNotFound(_:id:)``
/// - ``recordNotFound(_:key:)``
/// - ``recordNotFound(key:)``
///
/// ### Deleting Records
///
/// - ``deleteAll(_:)``
/// - ``deleteAll(_:ids:)``
/// - ``deleteAll(_:keys:)-jbkm``
/// - ``deleteAll(_:keys:)-5s1jg``
/// - ``deleteOne(_:id:)``
/// - ``deleteOne(_:key:)-413u8``
/// - ``deleteOne(_:key:)-5pdh5``
///
/// ### Updating Records
///
/// - ``updateAll(_:onConflict:_:)-7vv9x``
/// - ``updateAll(_:onConflict:_:)-7atfw``
///
/// ### Building Query Interface Requests
///
/// `TableRecord` provide convenience access to most ``DerivableRequest`` and
/// ``QueryInterfaceRequest`` methods as static methods on the type itself.
///
/// - ``aliased(_:)``
/// - ``all()``
/// - ``annotated(with:)-3zi1n``
/// - ``annotated(with:)-4xoen``
/// - ``annotated(with:)-8ce7u``
/// - ``annotated(with:)-79389``
/// - ``annotated(withOptional:)``
/// - ``annotated(withRequired:)``
/// - ``filter(_:)``
/// - ``filter(id:)``
/// - ``filter(ids:)``
/// - ``filter(key:)-9ey53``
/// - ``filter(key:)-34lau``
/// - ``filter(keys:)-4hq8y``
/// - ``filter(keys:)-7skw1``
/// - ``filter(literal:)``
/// - ``filter(sql:arguments:)``
/// - ``having(_:)``
/// - ``including(all:)``
/// - ``including(optional:)``
/// - ``including(required:)``
/// - ``joining(optional:)``
/// - ``joining(required:)``
/// - ``limit(_:offset:)``
/// - ``matching(_:)-22m4o``
/// - ``matching(_:)-1t8ph``
/// - ``none()``
/// - ``order(_:)-9rc11``
/// - ``order(_:)-2033k``
/// - ``order(literal:)``
/// - ``order(sql:arguments:)``
/// - ``orderByPrimaryKey()``
/// - ``request(for:)``
/// - ``select(_:)-1gvtj``
/// - ``select(_:)-5oylt``
/// - ``select(_:as:)-1puz3``
/// - ``select(_:as:)-tjh0``
/// - ``select(literal:)``
/// - ``select(literal:as:)``
/// - ``select(sql:arguments:)``
/// - ``select(sql:arguments:as:)``
/// - ``selectPrimaryKey(as:)``
/// - ``with(_:)``
///
/// ### Defining Associations
///
/// - ``association(to:)``
/// - ``association(to:on:)``
/// - ``belongsTo(_:key:using:)-13t5r``
/// - ``belongsTo(_:key:using:)-81six``
/// - ``hasMany(_:key:using:)-45axo``
/// - ``hasMany(_:key:using:)-10d4k``
/// - ``hasMany(_:through:using:key:)``
/// - ``hasOne(_:key:using:)-4g9tm``
/// - ``hasOne(_:key:using:)-4v5xa``
/// - ``hasOne(_:through:using:key:)``
public protocol TableRecord {
    /// The name of the database table used to build SQL queries.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: TableRecord {
    ///     static var databaseTableName = "player"
    /// }
    ///
    /// // SELECT * FROM player
    /// try Player.fetchAll(db)
    /// ```
    static var databaseTableName: String { get }
    
    /// The columns selected by the record.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: TableRecord {
    ///     static let databaseSelection: [any SQLSelectable] = [AllColumns()]
    /// }
    ///
    /// struct PartialPlayer: TableRecord {
    ///     static let databaseTableName = "player"
    ///     static let databaseSelection: [any SQLSelectable] = [
    ///         Column("id"),
    ///         Column("name"),
    ///     ]
    /// }
    ///
    /// // SELECT * FROM player
    /// try Player.fetchAll(db)
    ///
    /// // SELECT id, name FROM player
    /// try PartialPlayer.fetchAll(db)
    /// ```
    ///
    /// > Important: Make sure the `databaseSelection` property is
    /// > explicitly declared as `[any SQLSelectable]`. If it is not, the
    /// > Swift compiler may silently miss the protocol requirement,
    /// > resulting in sticky `SELECT *` requests.
    static var databaseSelection: [any SQLSelectable] { get }
}

extension TableRecord {
    
    /// The default name of the database table used to build requests.
    ///
    /// - Player -> "player"
    /// - Place -> "place"
    /// - PostalAddress -> "postalAddress"
    /// - HTTPRequest -> "httpRequest"
    /// - TOEFL -> "toefl"
    static var defaultDatabaseTableName: String {
        if let cached = defaultDatabaseTableNameCache.object(forKey: "\(Self.self)" as NSString) {
            return cached as String
        }
        let typeName = "\(Self.self)".replacingOccurrences(of: "(.)\\b.*$", with: "$1", options: [.regularExpression])
        let initial = typeName.replacingOccurrences(of: "^([A-Z]+).*$", with: "$1", options: [.regularExpression])
        let tableName: String
        switch initial.count {
        case typeName.count:
            tableName = initial.lowercased()
        case 0:
            tableName = typeName
        case 1:
            tableName = initial.lowercased() + typeName.dropFirst()
        default:
            tableName = initial.dropLast().lowercased() + typeName.dropFirst(initial.count - 1)
        }
        defaultDatabaseTableNameCache.setObject(tableName as NSString, forKey: "\(Self.self)" as NSString)
        return tableName
    }
    
    /// The default name of the database table is derived from the name of
    /// the type.
    ///
    /// - `Player` -> "player"
    /// - `Place` -> "place"
    /// - `PostalAddress` -> "postalAddress"
    /// - `HTTPRequest` -> "httpRequest"
    /// - `TOEFL` -> "toefl"
    public static var databaseTableName: String {
        defaultDatabaseTableName
    }
    
    /// The default selection is all columns: `[AllColumns()]`.
    public static var databaseSelection: [any SQLSelectable] {
        [AllColumns()]
    }
}

extension TableRecord {
    
    // MARK: - Counting All
    
    /// Returns the number of records in the database table.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: TableRecord { }
    ///
    /// try dbQueue.read { db in
    ///     // SELECT COUNT(*) FROM player
    ///     let count = try Player.fetchCount(db)
    /// }
    /// ```
    ///
    /// - parameter db: A database connection.
    public static func fetchCount(_ db: Database) throws -> Int {
        try all().fetchCount(db)
    }
}

extension TableRecord {
    
    // MARK: - SQL Generation
    
    /// Returns the number of selected columns.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: TableRecord { }
    ///
    /// struct PartialPlayer: TableRecord {
    ///     static let databaseTableName = "player"
    ///     static let databaseSelection = [Column("id"), Column("name")]
    /// }
    ///
    /// try dbQueue.write { db in
    ///     try db.create(table: "player") { t in
    ///         t.autoIncrementedPrimaryKey("id")
    ///         t.column("name", .text)
    ///         t.column("score", .integer)
    ///     }
    ///
    ///     try Player.numberOfSelectedColumns(db)        // 3
    ///     try PartialPlayer.numberOfSelectedColumns(db) // 2
    /// }
    /// ```
    public static func numberOfSelectedColumns(_ db: Database) throws -> Int {
        // The alias makes it possible to count the columns in `SELECT *`:
        let alias = TableAlias(tableName: databaseTableName)
        let context = SQLGenerationContext(db)
        return try databaseSelection
            .map { $0.sqlSelection.qualified(with: alias) }
            .columnCount(context)
    }
}

// MARK: - Batch Delete

extension TableRecord {

    /// Deletes all records, and returns the number of deleted records.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: TableRecord { }
    ///
    /// try dbQueue.write { db in
    ///     // DELETE FROM player
    ///     let count = try Player.deleteAll(db)
    /// }
    /// ```
    ///
    /// - parameter db: A database connection.
    /// - returns: The number of deleted records.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    @discardableResult
    public static func deleteAll(_ db: Database) throws -> Int {
        try all().deleteAll(db)
    }
}

// MARK: - Check Existence by Single-Column Primary Key

extension TableRecord {
    /// Returns whether a record exists for this primary key.
    ///
    /// All single-column primary keys are supported:
    ///
    /// ```swift
    /// struct Player: TableRecord { }
    /// struct Country: TableRecord { }
    ///
    /// try dbQueue.read { db in
    ///     let playerExists = try Player.exists(db, key: 1)
    ///     let countryExists = try Country.exists(db, key: "FR")
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - key: A primary key value.
    /// - returns: Whether a record exists for this primary key.
    public static func exists(_ db: Database, key: some DatabaseValueConvertible) throws -> Bool {
        try !filter(key: key).isEmpty(db)
    }
}

@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
extension TableRecord where Self: Identifiable, ID: DatabaseValueConvertible {
    /// Returns whether a record exists for this primary key.
    ///
    /// All single-column primary keys are supported:
    ///
    /// ```swift
    /// struct Player: TableRecord, Identifiable {
    ///     var id: Int64
    /// }
    /// struct Country: TableRecord, Identifiable {
    ///     var id: String
    /// }
    ///
    /// try dbQueue.read { db in
    ///     let playerExists = try Player.exists(db, id: 1)
    ///     let countryExists = try Country.exists(db, id: "FR")
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - id: A primary key value.
    /// - returns: Whether a record exists for this primary key.
    public static func exists(_ db: Database, id: ID) throws -> Bool {
        if id.databaseValue.isNull {
            // Don't hit the database
            return false
        }
        return try !filter(id: id).isEmpty(db)
    }
}

// MARK: - Check Existence by Key

extension TableRecord {
    /// Returns whether a record exists for this primary or unique key.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: TableRecord { }
    /// struct Citizenship: TableRecord { }
    ///
    /// try dbQueue.read { db in
    ///     let playerExists = Player.exists(db, key: ["id": 1])
    ///     let playerExists = Player.exists(db, key: ["email": "arthur@example.com"])
    ///     let citizenshipExists = Citizenship.exists(db, key: [
    ///         "citizenId": 1,
    ///         "countryCode": "FR",
    ///     ])
    /// }
    /// ```
    ///
    /// A fatal error is raised if no unique index exists on a subset of the
    /// key columns.
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - key: A key dictionary.
    /// - returns: Whether a record exists for this key.
    public static func exists(_ db: Database, key: [String: (any DatabaseValueConvertible)?]) throws -> Bool {
        try !filter(key: key).isEmpty(db)
    }
}

// MARK: - Deleting by Single-Column Primary Key

extension TableRecord {
    /// Deletes records identified by their primary keys, and returns the number
    /// of deleted records.
    ///
    /// All single-column primary keys are supported:
    ///
    /// ```swift
    /// struct Player: TableRecord { }
    /// struct Country: TableRecord { }
    ///
    /// try dbQueue.write { db in
    ///     // DELETE FROM player WHERE id IN (1, 2, 3)
    ///     try Player.deleteAll(db, keys: [1, 2, 3])
    ///
    ///     // DELETE FROM country WHERE code IN ('FR', 'US')
    ///     try Country.deleteAll(db, keys: ["FR", "US"])
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - keys: A sequence of primary keys.
    /// - returns: The number of deleted records.
    @discardableResult
    public static func deleteAll<Keys>(_ db: Database, keys: Keys)
    throws -> Int
    where Keys: Sequence, Keys.Element: DatabaseValueConvertible
    {
        let keys = Array(keys)
        if keys.isEmpty {
            // Avoid hitting the database
            return 0
        }
        return try filter(keys: keys).deleteAll(db)
    }
    
    /// Deletes the record identified by its primary key, and returns whether a
    /// record was deleted.
    ///
    /// All single-column primary keys are supported:
    ///
    /// ```swift
    /// struct Player: TableRecord { }
    /// struct Country: TableRecord { }
    ///
    /// try dbQueue.write { db in
    ///     // DELETE FROM player WHERE id = 1
    ///     try Player.deleteOne(db, key: 1)
    ///
    ///     // DELETE FROM country WHERE code = 'FR'
    ///     try Country.deleteOne(db, key: "FR")
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - key: A primary key value.
    /// - returns: Whether a record was deleted.
    @discardableResult
    public static func deleteOne(_ db: Database, key: some DatabaseValueConvertible) throws -> Bool {
        if key.databaseValue.isNull {
            // Don't hit the database
            return false
        }
        return try deleteAll(db, keys: [key]) > 0
    }
}

@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
extension TableRecord where Self: Identifiable, ID: DatabaseValueConvertible {
    /// Deletes records identified by their primary keys, and returns the number
    /// of deleted records.
    ///
    /// All single-column primary keys are supported:
    ///
    /// ```swift
    /// struct Player: TableRecord, Identifiable {
    ///     var id: Int64
    /// }
    /// struct Country: TableRecord, Identifiable {
    ///     var id: String
    /// }
    ///
    /// try dbQueue.write { db in
    ///     // DELETE FROM player WHERE id IN (1, 2, 3)
    ///     try Player.deleteAll(db, ids: [1, 2, 3])
    ///
    ///     // DELETE FROM country WHERE code IN ('FR', 'US')
    ///     try Country.deleteAll(db, ids: ["FR", "US"])
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - ids: A collection of primary keys.
    /// - returns: The number of deleted records.
    @discardableResult
    public static func deleteAll<IDS>(_ db: Database, ids: IDS) throws -> Int
    where IDS: Collection, IDS.Element == ID
    {
        if ids.isEmpty {
            // Avoid hitting the database
            return 0
        }
        return try filter(ids: ids).deleteAll(db)
    }
    
    /// Deletes the record identified by its primary key, and returns whether a
    /// record was deleted.
    ///
    /// All single-column primary keys are supported:
    ///
    /// ```swift
    /// struct Player: TableRecord, Identifiable {
    ///     var id: Int64
    /// }
    /// struct Country: TableRecord, Identifiable {
    ///     var id: String
    /// }
    ///
    /// try dbQueue.write { db in
    ///     // DELETE FROM player WHERE id = 1
    ///     try Player.deleteOne(db, id: 1)
    ///
    ///     // DELETE FROM country WHERE code = 'FR'
    ///     try Country.deleteOne(db, id: "FR")
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - id: A primary key value.
    /// - returns: Whether a record was deleted.
    @discardableResult
    public static func deleteOne(_ db: Database, id: ID) throws -> Bool {
        try deleteAll(db, ids: [id]) > 0
    }
}

// MARK: - Deleting by Key

extension TableRecord {
    /// Deletes records identified by their primary or unique keys, and returns
    /// the number of deleted records.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: TableRecord { }
    /// struct Citizenship: TableRecord { }
    ///
    /// try dbQueue.write { db in
    ///     // DELETE FROM player WHERE id = 1
    ///     try Player.deleteAll(db, keys: [["id": 1]])
    ///     
    ///     // DELETE FROM player WHERE email = 'arthur@example.com'
    ///     try Player.deleteAll(db, keys: [["email": "arthur@example.com"]])
    ///
    ///     // DELETE FROM citizenship WHERE citizenId = 1 AND countryCode = 'FR'
    ///     try Citizenship.deleteAll(db, keys: [
    ///         ["citizenId": 1, "countryCode": "FR"],
    ///     ])
    /// }
    /// ```
    ///
    /// A fatal error is raised if no unique index exists on a subset of the
    /// key columns.
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - keys: An array of key dictionaries.
    /// - returns: The number of deleted records.
    @discardableResult
    public static func deleteAll(_ db: Database, keys: [[String: (any DatabaseValueConvertible)?]]) throws -> Int {
        if keys.isEmpty {
            // Avoid hitting the database
            return 0
        }
        return try filter(keys: keys).deleteAll(db)
    }
    
    /// Deletes the record identified by its primary or unique key, and returns
    /// whether a record was deleted.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: TableRecord { }
    /// struct Citizenship: TableRecord { }
    ///
    /// try dbQueue.write { db in
    ///     // DELETE FROM player WHERE id = 1
    ///     try Player.deleteOne(db, key: ["id": 1])
    ///
    ///     // DELETE FROM player WHERE email = 'arthur@example.com'
    ///     try Player.deleteOne(db, key: ["email": "arthur@example.com"])
    ///
    ///     // DELETE FROM citizenship WHERE citizenId = 1 AND countryCode = 'FR'
    ///     try Citizenship.deleteOne(db, key: [
    ///         "citizenId": 1,
    ///         "countryCode": "FR",
    ///     ])
    /// }
    /// ```
    ///
    /// A fatal error is raised if no unique index exists on a subset of the
    /// key columns.
    /// - parameters:
    ///     - db: A database connection.
    ///     - key: A key dictionary.
    /// - returns: Whether a record was deleted.
    @discardableResult
    public static func deleteOne(_ db: Database, key: [String: (any DatabaseValueConvertible)?]) throws -> Bool {
        try deleteAll(db, keys: [key]) > 0
    }
}

// MARK: - Batch Update

extension TableRecord {
    
    /// Updates all records, and returns the number of updated records.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: TableRecord { }
    ///
    /// try dbQueue.write { db in
    ///     // UPDATE player SET score = 0
    ///     try Player.updateAll(db, [Column("score").set(to: 0)])
    /// }
    /// ```
    ///
    /// - parameter db: A database connection.
    /// - parameter conflictResolution: A policy for conflict resolution,
    ///   defaulting to the record's persistenceConflictPolicy.
    /// - parameter assignments: An array of column assignments.
    /// - returns: The number of updated records.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    @discardableResult
    public static func updateAll(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution? = nil,
        _ assignments: [ColumnAssignment])
    throws -> Int
    {
        try all().updateAll(db, onConflict: conflictResolution, assignments)
    }
    
    /// Updates all records, and returns the number of updated records.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: TableRecord { }
    /// 
    /// try dbQueue.write { db in
    ///     // UPDATE player SET score = 0
    ///     try Player.updateAll(db, Column("score").set(to: 0))
    /// }
    /// ```
    ///
    /// - parameter db: A database connection.
    /// - parameter conflictResolution: A policy for conflict resolution,
    ///   defaulting to the record's persistenceConflictPolicy.
    /// - parameter assignments: Column assignments.
    /// - returns: The number of updated records.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    @discardableResult
    public static func updateAll(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution? = nil,
        _ assignments: ColumnAssignment...)
    throws -> Int
    {
        try updateAll(db, onConflict: conflictResolution, assignments)
    }
}

// MARK: - RecordError

/// A record error.
///
/// `RecordError` is thrown by ``MutablePersistableRecord`` types when an
/// `update` method could not find any row to update:
///
/// ```swift
/// do {
///     try player.update(db)
/// } catch let RecordError.recordNotFound(databaseTableName: table, key: key) {
///     print("Key \(key) was not found in table \(table).")
/// }
/// ```
///
/// `RecordError` is also thrown by ``FetchableRecord`` types when a
/// `find` method does not find any record:
///
/// ```swift
/// do {
///     let player = try Player.find(db, id: 42)
/// } catch let RecordError.recordNotFound(databaseTableName: table, key: key) {
///     print("Key \(key) was not found in table \(table).")
/// }
/// ```
///
/// You can create `RecordError` instances with the
/// ``TableRecord/recordNotFound(_:id:)`` method and its variants.
public enum RecordError: Error {
    /// A record does not exist in the database.
    ///
    /// - parameters:
    ///     - databaseTableName: The table of the missing record.
    ///     - key: The key of the missing record (column and values).
    case recordNotFound(databaseTableName: String, key: [String: DatabaseValue])
}

extension RecordError: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .recordNotFound(databaseTableName: databaseTableName, key: key):
            let row = Row(key) // For nice output
            return "Key not found in table \(databaseTableName): \(row.description)"
        }
    }
}

extension TableRecord {
    /// Returns an error for a record that does not exist in the database.
    ///
    /// - returns: ``RecordError/recordNotFound(databaseTableName:key:)``, or
    ///   any error that prevented the `RecordError` from being constructed.
    public static func recordNotFound(_ db: Database, key: some DatabaseValueConvertible) -> any Error {
        do {
            let primaryKey = try db.primaryKey(databaseTableName)
            GRDBPrecondition(
                primaryKey.columns.count == 1,
                "Requesting by key requires a single-column primary key in the table \(databaseTableName)")
            return RecordError.recordNotFound(
                databaseTableName: databaseTableName,
                key: [primaryKey.columns[0]: key.databaseValue])
        } catch {
            return error
        }
    }
    
    /// Returns an error for a record that does not exist in the database.
    public static func recordNotFound(key: [String: (any DatabaseValueConvertible)?]) -> RecordError {
        RecordError.recordNotFound(
            databaseTableName: databaseTableName,
            key: key.mapValues { $0?.databaseValue ?? .null })
    }
}

@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
extension TableRecord where Self: Identifiable, ID: DatabaseValueConvertible {
    /// Returns an error for a record that does not exist in the database.
    ///
    /// - returns: ``RecordError/recordNotFound(databaseTableName:key:)``, or
    ///   any error that prevented the `RecordError` from being constructed.
    public static func recordNotFound(_ db: Database, id: Self.ID) -> any Error {
        recordNotFound(db, key: id)
    }
}

@available(*, deprecated, renamed: "RecordError")
public typealias PersistenceError = RecordError

/// Calculating `defaultDatabaseTableName` is somewhat expensive due to the regular expression evaluation
///
/// This cache mitigates the cost of the calculation by storing the name for later retrieval
private let defaultDatabaseTableNameCache = NSCache<NSString, NSString>()

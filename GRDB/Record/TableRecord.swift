import Foundation

/// Types that adopt `TableRecord` declare a particular relationship with
/// a database table.
///
/// Types that adopt both `TableRecord` and `FetchableRecord` are granted with
/// built-in methods that allow to fetch instances identified by key:
///
///     try Player.fetchOne(db, key: 123)  // Player?
///     try Citizenship.fetchOne(db, key: ["citizenId": 12, "countryId": 45]) // Citizenship?
public protocol TableRecord {
    /// The name of the database table used to build requests.
    ///
    ///     struct Player : TableRecord {
    ///         static var databaseTableName = "player"
    ///     }
    ///
    ///     // SELECT * FROM player
    ///     try Player.fetchAll(db)
    static var databaseTableName: String { get }
    
    /// The default request selection.
    ///
    /// Unless said otherwise, requests select all columns:
    ///
    ///     // SELECT * FROM player
    ///     try Player.fetchAll(db)
    ///
    /// You can provide a custom implementation and provide an explicit list
    /// of columns:
    ///
    ///     struct RestrictedPlayer : TableRecord {
    ///         static var databaseTableName = "player"
    ///         static var databaseSelection = [Column("id"), Column("name")]
    ///     }
    ///
    ///     // SELECT id, name FROM player
    ///     try RestrictedPlayer.fetchAll(db)
    ///
    /// You can also add extra columns such as the `rowid` column:
    ///
    ///     struct ExtendedPlayer : TableRecord {
    ///         static var databaseTableName = "player"
    ///         static let databaseSelection: [SQLSelectable] = [AllColumns(), Column.rowID]
    ///     }
    ///
    ///     // SELECT *, rowid FROM player
    ///     try ExtendedPlayer.fetchAll(db)
    static var databaseSelection: [SQLSelectable] { get }
}

extension TableRecord {
    
    /// The default name of the database table used to build requests.
    ///
    /// - Player -> "player"
    /// - Place -> "place"
    /// - PostalAddress -> "postalAddress"
    /// - HTTPRequest -> "httpRequest"
    /// - TOEFL -> "toefl"
    internal static var defaultDatabaseTableName: String {
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
    
    /// The default name of the database table used to build requests.
    ///
    /// - Player -> "player"
    /// - Place -> "place"
    /// - PostalAddress -> "postalAddress"
    /// - HTTPRequest -> "httpRequest"
    /// - TOEFL -> "toefl"
    public static var databaseTableName: String {
        defaultDatabaseTableName
    }
    
    /// Default value: `[AllColumns()]`.
    public static var databaseSelection: [SQLSelectable] {
        [AllColumns()]
    }
}

extension TableRecord {
    
    // MARK: - Counting All
    
    /// The number of records.
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
    ///     struct Player: TableRecord {
    ///         static let databaseTableName = "player"
    ///     }
    ///
    ///     try dbQueue.write { db in
    ///         try db.create(table: "player") { t in
    ///             t.autoIncrementedPrimaryKey("id")
    ///             t.column("name", .text)
    ///             t.column("score", .integer)
    ///         }
    ///
    ///         // 3
    ///         try Player.numberOfSelectedColumns(db)
    ///     }
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

    /// Deletes all records; returns the number of deleted rows.
    ///
    /// - parameter db: A database connection.
    /// - returns: The number of deleted rows
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    @discardableResult
    public static func deleteAll(_ db: Database) throws -> Int {
        try all().deleteAll(db)
    }
}

// MARK: - Check Existence by Single-Column Primary Key

extension TableRecord {
    /// Returns whether a row exists for this primary key.
    ///
    ///     try Player.exists(db, key: 123)
    ///     try Country.exists(db, key: "FR")
    ///
    /// When the table has no explicit primary key, GRDB uses the hidden
    /// "rowid" column:
    ///
    ///     try Document.exists(db, key: 1)
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - key: A primary key value.
    /// - returns: Whether a row exists for this primary key.
    public static func exists<PrimaryKeyType>(_ db: Database, key: PrimaryKeyType)
    throws -> Bool
    where PrimaryKeyType: DatabaseValueConvertible
    {
        try !filter(key: key).isEmpty(db)
    }
}

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6, *)
extension TableRecord where Self: Identifiable, ID: DatabaseValueConvertible {
    /// Returns whether a row exists for this primary key.
    ///
    ///     try Player.deleteOne(db, id: 123)
    ///     try Country.deleteOne(db, id: "FR")
    ///
    /// When the table has no explicit primary key, GRDB uses the hidden
    /// "rowid" column:
    ///
    ///     try Document.deleteOne(db, id: 1)
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - id: A primary key value.
    /// - returns: Whether a row exists for this primary key.
    public static func exists(_ db: Database, id: ID) throws -> Bool {
        try !filter(id: id).isEmpty(db)
    }
}

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6, *)
extension TableRecord
where Self: Identifiable,
      ID: _OptionalProtocol,
      ID.Wrapped: DatabaseValueConvertible
{
    /// Returns whether a row exists for this primary key.
    ///
    ///     try Player.deleteOne(db, id: 123)
    ///     try Country.deleteOne(db, id: "FR")
    ///
    /// When the table has no explicit primary key, GRDB uses the hidden
    /// "rowid" column:
    ///
    ///     try Document.deleteOne(db, id: 1)
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - id: A primary key value.
    /// - returns: Whether a row exists for this primary key.
    public static func exists(_ db: Database, id: ID.Wrapped) throws -> Bool {
        try !filter(id: id).isEmpty(db)
    }
}

// MARK: - Check Existence by Key

extension TableRecord {
    /// Returns whether a row exists for this unique key (primary key or any key
    /// with a unique index on it).
    ///
    ///     try Player.exists(db, key: ["name": Arthur"])
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - key: A dictionary of values.
    /// - returns: Whether a row exists for this key.
    public static func exists(_ db: Database, key: [String: DatabaseValueConvertible?]) throws -> Bool {
        try !filter(key: key).isEmpty(db)
    }
}

// MARK: - Deleting by Single-Column Primary Key

extension TableRecord {
    
    /// Delete records identified by their primary keys; returns the number of
    /// deleted rows.
    ///
    ///     // DELETE FROM player WHERE id IN (1, 2, 3)
    ///     try Player.deleteAll(db, keys: [1, 2, 3])
    ///
    ///     // DELETE FROM country WHERE code IN ('FR', 'US', 'DE')
    ///     try Country.deleteAll(db, keys: ["FR", "US", "DE"])
    ///
    /// When the table has no explicit primary key, GRDB uses the hidden
    /// "rowid" column:
    ///
    ///     // DELETE FROM document WHERE rowid IN (1, 2, 3)
    ///     try Document.deleteAll(db, keys: [1, 2, 3])
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - keys: A sequence of primary keys.
    /// - returns: The number of deleted rows
    @discardableResult
    public static func deleteAll<Sequence>(_ db: Database, keys: Sequence)
    throws -> Int
    where Sequence: Swift.Sequence, Sequence.Element: DatabaseValueConvertible
    {
        let keys = Array(keys)
        if keys.isEmpty {
            // Avoid hitting the database
            return 0
        }
        return try filter(keys: keys).deleteAll(db)
    }
    
    /// Delete a record, identified by its primary key; returns whether a
    /// database row was deleted.
    ///
    ///     // DELETE FROM player WHERE id = 123
    ///     try Player.deleteOne(db, key: 123)
    ///
    ///     // DELETE FROM country WHERE code = 'FR'
    ///     try Country.deleteOne(db, key: "FR")
    ///
    /// When the table has no explicit primary key, GRDB uses the hidden
    /// "rowid" column:
    ///
    ///     // DELETE FROM document WHERE rowid = 1
    ///     try Document.deleteOne(db, key: 1)
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - key: A primary key value.
    /// - returns: Whether a database row was deleted.
    @discardableResult
    public static func deleteOne<PrimaryKeyType>(_ db: Database, key: PrimaryKeyType?)
    throws -> Bool
    where PrimaryKeyType: DatabaseValueConvertible
    {
        guard let key = key else {
            // Avoid hitting the database
            return false
        }
        return try deleteAll(db, keys: [key]) > 0
    }
}

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6, *)
extension TableRecord where Self: Identifiable, ID: DatabaseValueConvertible {
    /// Delete records identified by their primary keys; returns the number of
    /// deleted rows.
    ///
    ///     // DELETE FROM player WHERE id IN (1, 2, 3)
    ///     try Player.deleteAll(db, ids: [1, 2, 3])
    ///
    ///     // DELETE FROM country WHERE code IN ('FR', 'US', 'DE')
    ///     try Country.deleteAll(db, ids: ["FR", "US", "DE"])
    ///
    /// When the table has no explicit primary key, GRDB uses the hidden
    /// "rowid" column:
    ///
    ///     // DELETE FROM document WHERE rowid IN (1, 2, 3)
    ///     try Document.deleteAll(db, ids: [1, 2, 3])
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - ids: A collection of primary keys.
    /// - returns: The number of deleted rows
    @discardableResult
    public static func deleteAll<Collection>(_ db: Database, ids: Collection)
    throws -> Int
    where Collection: Swift.Collection, Collection.Element == ID
    {
        if ids.isEmpty {
            // Avoid hitting the database
            return 0
        }
        return try filter(ids: ids).deleteAll(db)
    }
    
    /// Delete a record, identified by its primary key; returns whether a
    /// database row was deleted.
    ///
    ///     // DELETE FROM player WHERE id = 123
    ///     try Player.deleteOne(db, id: 123)
    ///
    ///     // DELETE FROM country WHERE code = 'FR'
    ///     try Country.deleteOne(db, id: "FR")
    ///
    /// When the table has no explicit primary key, GRDB uses the hidden
    /// "rowid" column:
    ///
    ///     // DELETE FROM document WHERE rowid = 1
    ///     try Document.deleteOne(db, id: 1)
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - id: A primary key value.
    /// - returns: Whether a database row was deleted.
    @discardableResult
    public static func deleteOne(_ db: Database, id: ID) throws -> Bool {
        try deleteAll(db, ids: [id]) > 0
    }
}

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6, *)
extension TableRecord
where Self: Identifiable,
      ID: _OptionalProtocol,
      ID.Wrapped: DatabaseValueConvertible
{
    /// Delete records identified by their primary keys; returns the number of
    /// deleted rows.
    ///
    ///     // DELETE FROM player WHERE id IN (1, 2, 3)
    ///     try Player.deleteAll(db, ids: [1, 2, 3])
    ///
    ///     // DELETE FROM country WHERE code IN ('FR', 'US', 'DE')
    ///     try Country.deleteAll(db, ids: ["FR", "US", "DE"])
    ///
    /// When the table has no explicit primary key, GRDB uses the hidden
    /// "rowid" column:
    ///
    ///     // DELETE FROM document WHERE rowid IN (1, 2, 3)
    ///     try Document.deleteAll(db, ids: [1, 2, 3])
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - ids: A collection of primary keys.
    /// - returns: The number of deleted rows
    @discardableResult
    public static func deleteAll<Collection>(_ db: Database, ids: Collection)
    throws -> Int
    where Collection: Swift.Collection, Collection.Element == ID.Wrapped
    {
        if ids.isEmpty {
            // Avoid hitting the database
            return 0
        }
        return try filter(ids: ids).deleteAll(db)
    }
    
    /// Delete a record, identified by its primary key; returns whether a
    /// database row was deleted.
    ///
    ///     // DELETE FROM player WHERE id = 123
    ///     try Player.deleteOne(db, id: 123)
    ///
    ///     // DELETE FROM country WHERE code = 'FR'
    ///     try Country.deleteOne(db, id: "FR")
    ///
    /// When the table has no explicit primary key, GRDB uses the hidden
    /// "rowid" column:
    ///
    ///     // DELETE FROM document WHERE rowid = 1
    ///     try Document.deleteOne(db, id: 1)
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - id: A primary key value.
    /// - returns: Whether a database row was deleted.
    @discardableResult
    public static func deleteOne(_ db: Database, id: ID.Wrapped) throws -> Bool {
        try deleteAll(db, ids: [id]) > 0
    }
}

// MARK: - Deleting by Key

extension TableRecord {
    /// Delete records identified by the provided unique keys (primary key or
    /// any key with a unique index on it); returns the number of deleted rows.
    ///
    ///     try Player.deleteAll(db, keys: [["email": "a@example.com"], ["email": "b@example.com"]])
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - keys: An array of key dictionaries.
    /// - returns: The number of deleted rows
    @discardableResult
    public static func deleteAll(_ db: Database, keys: [[String: DatabaseValueConvertible?]]) throws -> Int {
        if keys.isEmpty {
            // Avoid hitting the database
            return 0
        }
        return try filter(keys: keys).deleteAll(db)
    }
    
    /// Delete a record, identified by a unique key (the primary key or any key
    /// with a unique index on it); returns whether a database row was deleted.
    ///
    ///     Player.deleteOne(db, key: ["name": Arthur"])
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - key: A dictionary of values.
    /// - returns: Whether a database row was deleted.
    @discardableResult
    public static func deleteOne(_ db: Database, key: [String: DatabaseValueConvertible?]) throws -> Bool {
        try deleteAll(db, keys: [key]) > 0
    }
}

// MARK: - Batch Update

extension TableRecord {
    
    /// Updates all records; returns the number of updated records.
    ///
    /// For example:
    ///
    ///     try dbQueue.write { db in
    ///         // UPDATE player SET score = 0
    ///         try Player.updateAll(db, [Column("score").set(to: 0)])
    ///     }
    ///
    /// - parameter db: A database connection.
    /// - parameter conflictResolution: A policy for conflict resolution,
    ///   defaulting to the record's persistenceConflictPolicy.
    /// - parameter assignments: An array of column assignments.
    /// - returns: The number of updated rows.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    @discardableResult
    public static func updateAll(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution? = nil,
        _ assignments: [ColumnAssignment])
    throws -> Int
    {
        try all().updateAll(db, onConflict: conflictResolution, assignments)
    }
    
    /// Updates all records; returns the number of updated records.
    ///
    /// For example:
    ///
    ///     try dbQueue.write { db in
    ///         // UPDATE player SET score = 0
    ///         try Player.updateAll(db, Column("score").set(to: 0))
    ///     }
    ///
    /// - parameter db: A database connection.
    /// - parameter conflictResolution: A policy for conflict resolution,
    ///   defaulting to the record's persistenceConflictPolicy.
    /// - parameter assignment: A column assignment.
    /// - parameter otherAssignments: Eventual other column assignments.
    /// - returns: The number of updated rows.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    @discardableResult
    public static func updateAll(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution? = nil,
        _ assignment: ColumnAssignment,
        _ otherAssignments: ColumnAssignment...)
    throws -> Int
    {
        try updateAll(db, onConflict: conflictResolution, [assignment] + otherAssignments)
    }
}

/// Calculating `defaultDatabaseTableName` is somewhat expensive due to the regular expression evaluation
///
/// This cache mitigates the cost of the calculation by storing the name for later retrieval
private let defaultDatabaseTableNameCache = NSCache<NSString, NSString>()

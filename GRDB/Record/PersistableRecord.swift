import Foundation

extension Database.ConflictResolution {
    var invalidatesLastInsertedRowID: Bool {
        switch self {
        case .abort, .fail, .rollback, .replace:
            return false
        case .ignore:
            // Statement may have succeeded without inserting any row
            return true
        }
    }
}

// MARK: - PersistenceError

/// An error thrown by a type that adopts PersistableRecord.
public enum PersistenceError: Error, CustomStringConvertible {
    
    /// Thrown by MutablePersistableRecord.update() when no matching row could be
    /// found in the database.
    case recordNotFound(MutablePersistableRecord)
}

// CustomStringConvertible
extension PersistenceError {
    /// :nodoc:
    public var description: String {
        switch self {
        case .recordNotFound(let record):
            return "Not found: \(record)"
        }
    }
}

// MARK: - PersistenceContainer

/// Use persistence containers in the `encode(to:)` method of your
/// encodable records:
///
///     struct Player : MutablePersistableRecord {
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
    fileprivate var storage: [String: DatabaseValueConvertible?]
    
    /// Accesses the value associated with the given column.
    ///
    /// It is undefined behavior to set different values for the same column.
    /// Column names are case insensitive, so defining both "name" and "NAME"
    /// is considered undefined behavior.
    public subscript(_ column: String) -> DatabaseValueConvertible? {
        get { return storage[column] ?? nil }
        set { storage.updateValue(newValue, forKey: column) }
    }
    
    /// Accesses the value associated with the given column.
    ///
    /// It is undefined behavior to set different values for the same column.
    /// Column names are case insensitive, so defining both "name" and "NAME"
    /// is considered undefined behavior.
    public subscript(_ column: ColumnExpression) -> DatabaseValueConvertible? {
        get { return self[column.name] }
        set { self[column.name] = newValue }
    }
    
    init() {
        storage = [:]
    }
    
    /// Convenience initializer from a record
    ///
    ///     // Sweet
    ///     let container = PersistenceContainer(record)
    ///
    ///     // Meh
    ///     var container = PersistenceContainer()
    ///     record.encode(to: container)
    init(_ record: MutablePersistableRecord) {
        storage = [:]
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
    func makeIterator() -> DictionaryIterator<String, DatabaseValueConvertible?> {
        return storage.makeIterator()
    }
}

extension Row {
    convenience init(_ record: MutablePersistableRecord) {
        self.init(PersistenceContainer(record))
    }

    convenience init(_ container: PersistenceContainer) {
        self.init(container.storage)
    }
}

// MARK: - MutablePersistableRecord

/// The MutablePersistableRecord protocol uses this type in order to handle SQLite
/// conflicts when records are inserted or updated.
///
/// See `MutablePersistableRecord.persistenceConflictPolicy`.
///
/// See https://www.sqlite.org/lang_conflict.html
public struct PersistenceConflictPolicy {
    /// The conflict resolution algorithm for insertions
    public let conflictResolutionForInsert: Database.ConflictResolution
    
    /// The conflict resolution algorithm for updates
    public let conflictResolutionForUpdate: Database.ConflictResolution
    
    /// Creates a policy
    public init(insert: Database.ConflictResolution = .abort, update: Database.ConflictResolution = .abort) {
        self.conflictResolutionForInsert = insert
        self.conflictResolutionForUpdate = update
    }
}

/// Types that adopt MutablePersistableRecord can be inserted, updated, and deleted.
public protocol MutablePersistableRecord : TableRecord {
    /// The policy that handles SQLite conflicts when records are inserted
    /// or updated.
    ///
    /// This property is optional: its default value uses the ABORT policy
    /// for both insertions and updates, and has GRDB generate regular
    /// INSERT and UPDATE queries.
    ///
    /// If insertions are resolved with .ignore policy, the
    /// `didInsert(with:for:)` method is not called upon successful insertion,
    /// even if a row was actually inserted without any conflict.
    ///
    /// See https://www.sqlite.org/lang_conflict.html
    static var persistenceConflictPolicy: PersistenceConflictPolicy { get }
    
    /// Defines the values persisted in the database.
    ///
    /// Store in the *container* argument all values that should be stored in
    /// the columns of the database table (see databaseTableName()).
    ///
    /// Primary key columns, if any, must be included.
    ///
    ///     struct Player : MutablePersistableRecord {
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
    
    /// Notifies the record that it was succesfully inserted.
    ///
    /// Do not call this method directly: it is called for you, in a protected
    /// dispatch queue, with the inserted RowID and the eventual
    /// INTEGER PRIMARY KEY column name.
    ///
    /// This method is optional: the default implementation does nothing.
    ///
    ///     struct Player : MutablePersistableRecord {
    ///         var id: Int64?
    ///         var name: String?
    ///
    ///         mutating func didInsert(with rowID: Int64, for column: String?) {
    ///             self.id = rowID
    ///         }
    ///     }
    ///
    /// - parameters:
    ///     - rowID: The inserted rowID.
    ///     - column: The name of the eventual INTEGER PRIMARY KEY column.
    mutating func didInsert(with rowID: Int64, for column: String?)
    
    // MARK: - CRUD
    
    /// Executes an INSERT statement.
    ///
    /// This method is guaranteed to have inserted a row in the database if it
    /// returns without error.
    ///
    /// Upon successful insertion, the didInsert(with:for:) method
    /// is called with the inserted RowID and the eventual INTEGER PRIMARY KEY
    /// column name.
    ///
    /// This method has a default implementation, so your adopting types don't
    /// have to implement it. Yet your types can provide their own
    /// implementation of insert(). In their implementation, it is recommended
    /// that they invoke the performInsert() method.
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    mutating func insert(_ db: Database) throws
    
    /// Executes an UPDATE statement.
    ///
    /// This method is guaranteed to have updated a row in the database if it
    /// returns without error.
    ///
    /// This method has a default implementation, so your adopting types don't
    /// have to implement it. Yet your types can provide their own
    /// implementation of update(). In their implementation, it is recommended
    /// that they invoke the performUpdate() method.
    ///
    /// - parameter db: A database connection.
    /// - parameter columns: The columns to update.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    ///   PersistenceError.recordNotFound is thrown if the primary key does not
    ///   match any row in the database.
    func update(_ db: Database, columns: Set<String>) throws
    
    /// Executes an INSERT or an UPDATE statement so that `self` is saved in
    /// the database.
    ///
    /// If the receiver has a non-nil primary key and a matching row in the
    /// database, this method performs an update.
    ///
    /// Otherwise, performs an insert.
    ///
    /// This method is guaranteed to have inserted or updated a row in the
    /// database if it returns without error.
    ///
    /// This method has a default implementation, so your adopting types don't
    /// have to implement it. Yet your types can provide their own
    /// implementation of save(). In their implementation, it is recommended
    /// that they invoke the performSave() method.
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError whenever an SQLite error occurs, or errors
    ///   thrown by update().
    mutating func save(_ db: Database) throws
    
    /// Executes a DELETE statement.
    ///
    /// This method has a default implementation, so your adopting types don't
    /// have to implement it. Yet your types can provide their own
    /// implementation of delete(). In their implementation, it is recommended
    /// that they invoke the performDelete() method.
    ///
    /// - parameter db: A database connection.
    /// - returns: Whether a database row was deleted.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    @discardableResult
    func delete(_ db: Database) throws -> Bool
    
    /// Returns true if and only if the primary key matches a row in
    /// the database.
    ///
    /// This method has a default implementation, so your adopting types don't
    /// have to implement it. Yet your types can provide their own
    /// implementation of exists(). In their implementation, it is recommended
    /// that they invoke the performExists() method.
    ///
    /// - parameter db: A database connection.
    /// - returns: Whether the primary key matches a row in the database.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    func exists(_ db: Database) throws -> Bool
    
    // MARK: - Customizing the Format of Database Columns
    
    /// When the PersistableRecord type also adopts the standard Encodable
    /// protocol, you can use this dictionary to customize the encoding process
    /// into database rows.
    ///
    /// For example:
    ///
    ///     // A key that holds a encoder's name
    ///     let encoderName = CodingUserInfoKey(rawValue: "encoderName")!
    ///
    ///     // A PersistableRecord + Encodable record
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
    
    /// When the PersistableRecord type also adopts the standard Encodable
    /// protocol, this method controls the encoding process of nested properties
    /// into JSON database columns.
    ///
    /// The default implementation returns a JSONEncoder with the
    /// following properties:
    ///
    /// - dataEncodingStrategy: .base64
    /// - dateEncodingStrategy: .millisecondsSince1970
    /// - nonConformingFloatEncodingStrategy: .throw
    /// - outputFormatting: .sortedKeys (iOS 11.0+, macOS 10.13+, watchOS 4.0+)
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
    
    /// When the PersistableRecord type also adopts the standard Encodable
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
    
    /// When the PersistableRecord type also adopts the standard Encodable
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

extension MutablePersistableRecord {
    public static var databaseEncodingUserInfo: [CodingUserInfoKey: Any] {
        return [:]
    }
    
    public static func databaseJSONEncoder(for column: String) -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dataEncodingStrategy = .base64
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.nonConformingFloatEncodingStrategy = .throw
        if #available(watchOS 4.0, OSX 10.13, iOS 11.0, *) {
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

extension MutablePersistableRecord {
    /// A dictionary whose keys are the columns encoded in the `encode(to:)` method.
    public var databaseDictionary: [String: DatabaseValue] {
        return PersistenceContainer(self).storage.mapValues { $0?.databaseValue ?? .null }
    }
}

extension MutablePersistableRecord {
    /// Describes the conflict policy for insertions and updates.
    ///
    /// The default value specifies ABORT policy for both insertions and
    /// updates, which has GRDB generate regular INSERT and UPDATE queries.
    public static var persistenceConflictPolicy: PersistenceConflictPolicy {
        return PersistenceConflictPolicy(insert: .abort, update: .abort)
    }
    
    /// Notifies the record that it was succesfully inserted.
    ///
    /// The default implementation does nothing.
    public mutating func didInsert(with rowID: Int64, for column: String?) {
    }
    
    // MARK: - CRUD
    
    /// Executes an INSERT statement.
    ///
    /// The default implementation for insert() invokes performInsert().
    public mutating func insert(_ db: Database) throws {
        try performInsert(db)
    }
    
    /// Executes an UPDATE statement.
    ///
    /// - parameter db: A database connection.
    /// - parameter columns: The columns to update.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    ///   PersistenceError.recordNotFound is thrown if the primary key does not
    ///   match any row in the database.
    public func update(_ db: Database, columns: Set<String>) throws {
        try performUpdate(db, columns: columns)
    }
    
    /// Executes an UPDATE statement.
    ///
    /// - parameter db: A database connection.
    /// - parameter columns: The columns to update.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    ///   PersistenceError.recordNotFound is thrown if the primary key does not
    ///   match any row in the database.
    public func update<Sequence: Swift.Sequence>(_ db: Database, columns: Sequence) throws where Sequence.Element: ColumnExpression {
        try update(db, columns: Set(columns.map { $0.name }))
    }
    
    /// Executes an UPDATE statement.
    ///
    /// - parameter db: A database connection.
    /// - parameter columns: The columns to update.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    ///   PersistenceError.recordNotFound is thrown if the primary key does not
    ///   match any row in the database.
    public func update<Sequence: Swift.Sequence>(_ db: Database, columns: Sequence) throws where Sequence.Element == String {
        try update(db, columns: Set(columns))
    }
    
    /// Executes an UPDATE statement that updates all table columns.
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    ///   PersistenceError.recordNotFound is thrown if the primary key does not
    ///   match any row in the database.
    public func update(_ db: Database) throws {
        let databaseTableName = type(of: self).databaseTableName
        let columns = try db.columns(in: databaseTableName)
        try update(db, columns: Set(columns.map { $0.name }))
    }
    
    /// If the record has differences from the other record, executes an UPDATE
    /// statement so that those changes and only those changes are saved in
    /// the database.
    ///
    /// This method is guaranteed to have saved the eventual changes in the
    /// database if it returns without error.
    ///
    /// - parameter db: A database connection.
    /// - parameter columns: The columns to update.
    /// - returns: Whether the record had changes.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    ///   PersistenceError.recordNotFound is thrown if the primary key does not
    ///   match any row in the database and record could not be updated.
    @discardableResult
    public func updateChanges(_ db: Database, from record: MutablePersistableRecord) throws -> Bool {
        let changedColumns = Set(databaseChanges(from: record).keys)
        if changedColumns.isEmpty {
            return false
        } else {
            try update(db, columns: changedColumns)
            return true
        }
    }

    /// Executes an INSERT or an UPDATE statement so that `self` is saved in
    /// the database.
    ///
    /// The default implementation for save() invokes performSave().
    public mutating func save(_ db: Database) throws {
        try performSave(db)
    }
    
    /// Executes a DELETE statement.
    ///
    /// The default implementation for delete() invokes performDelete().
    @discardableResult
    public func delete(_ db: Database) throws -> Bool {
        return try performDelete(db)
    }
    
    /// Returns true if and only if the primary key matches a row in
    /// the database.
    ///
    /// The default implementation for exists() invokes performExists().
    public func exists(_ db: Database) throws -> Bool {
        return try performExists(db)
    }
    
    // MARK: - Record Comparison
    
    /// Returns a boolean indicating whether this record and the other record
    /// have the same database representation.
    public func databaseEquals(_ record: Self) -> Bool {
        return databaseChangesIterator(from: record).next() == nil
    }

    /// A dictionary of values changed from the other record.
    ///
    /// Its keys are column names. Its values come from the other record.
    ///
    /// Note that this method is not symmetrical, not only in terms of values,
    /// but also in terms of columns. When the two records don't define the
    /// same set of columns in their `encode(to:)` method, only the columns
    /// defined by the receiver record are considered.
    public func databaseChanges(from record: MutablePersistableRecord) -> [String: DatabaseValue] {
        return Dictionary(uniqueKeysWithValues: databaseChangesIterator(from: record))
    }
    
    fileprivate func databaseChangesIterator(from record: MutablePersistableRecord) -> AnyIterator<(String, DatabaseValue)> {
        let oldContainer = PersistenceContainer(record)
        var newValueIterator = PersistenceContainer(self).makeIterator()
        return AnyIterator {
            // Loop until we find a change, or exhaust columns:
            while let (column, newValue) = newValueIterator.next() {
                let oldValue = oldContainer[caseInsensitive: column]
                let oldDbValue = oldValue?.databaseValue ?? .null
                let newDbValue = newValue?.databaseValue ?? .null
                if newDbValue != oldDbValue {
                    return (column, oldDbValue)
                }
            }
            return nil
        }
    }
    
    // MARK: - CRUD Internals
    
    /// Return true if record has a non-null primary key
    fileprivate func canUpdate(_ db: Database) throws -> Bool {
        let databaseTableName = type(of: self).databaseTableName
        let primaryKey = try db.primaryKey(databaseTableName)
        let container = PersistenceContainer(self)
        for column in primaryKey.columns {
            if let value = container[caseInsensitive: column], !value.databaseValue.isNull {
                return true
            }
        }
        return false
    }
    
    /// Don't invoke this method directly: it is an internal method for types
    /// that adopt MutablePersistableRecord.
    ///
    /// performInsert() provides the default implementation for insert(). Types
    /// that adopt MutablePersistableRecord can invoke performInsert() in their
    /// implementation of insert(). They should not provide their own
    /// implementation of performInsert().
    public mutating func performInsert(_ db: Database) throws {
        let conflictResolutionForInsert = type(of: self).persistenceConflictPolicy.conflictResolutionForInsert
        let dao = try DAO(db, self)
        try dao.insertStatement(onConflict: conflictResolutionForInsert).execute()
        
        if !conflictResolutionForInsert.invalidatesLastInsertedRowID {
            didInsert(with: db.lastInsertedRowID, for: dao.primaryKey.rowIDColumn)
        }
    }
    
    /// Don't invoke this method directly: it is an internal method for types
    /// that adopt MutablePersistableRecord.
    ///
    /// performUpdate() provides the default implementation for update(). Types
    /// that adopt MutablePersistableRecord can invoke performUpdate() in their
    /// implementation of update(). They should not provide their own
    /// implementation of performUpdate().
    ///
    /// - parameter db: A database connection.
    /// - parameter columns: The columns to update.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    ///   PersistenceError.recordNotFound is thrown if the primary key does not
    ///   match any row in the database.
    public func performUpdate(_ db: Database, columns: Set<String>) throws {
        guard let statement = try DAO(db, self).updateStatement(db, columns: columns, onConflict: type(of: self).persistenceConflictPolicy.conflictResolutionForUpdate) else {
            // Nil primary key
            throw PersistenceError.recordNotFound(self)
        }
        try statement.execute()
        if db.changesCount == 0 {
            throw PersistenceError.recordNotFound(self)
        }
    }
    
    /// Don't invoke this method directly: it is an internal method for types
    /// that adopt MutablePersistableRecord.
    ///
    /// performSave() provides the default implementation for save(). Types
    /// that adopt MutablePersistableRecord can invoke performSave() in their
    /// implementation of save(). They should not provide their own
    /// implementation of performSave().
    ///
    /// This default implementation forwards the job to `update` or `insert`.
    public mutating func performSave(_ db: Database) throws {
        // Make sure we call self.insert and self.update so that classes
        // that override insert or save have opportunity to perform their
        // custom job.
        
        if try canUpdate(db) {
            do {
                try update(db)
            } catch PersistenceError.recordNotFound {
                // TODO: check that the not persisted objet is self
                //
                // Why? Adopting types could override update() and update
                // another object which may be the one throwing this error.
                try insert(db)
            }
        } else {
            try insert(db)
        }
    }
    
    /// Don't invoke this method directly: it is an internal method for types
    /// that adopt MutablePersistableRecord.
    ///
    /// performDelete() provides the default implementation for deelte(). Types
    /// that adopt MutablePersistableRecord can invoke performDelete() in
    /// their implementation of delete(). They should not provide their own
    /// implementation of performDelete().
    public func performDelete(_ db: Database) throws -> Bool {
        guard let statement = try DAO(db, self).deleteStatement() else {
            // Nil primary key
            return false
        }
        try statement.execute()
        return db.changesCount > 0
    }
    
    /// Don't invoke this method directly: it is an internal method for types
    /// that adopt MutablePersistableRecord.
    ///
    /// performExists() provides the default implementation for exists(). Types
    /// that adopt MutablePersistableRecord can invoke performExists() in
    /// their implementation of exists(). They should not provide their own
    /// implementation of performExists().
    public func performExists(_ db: Database) throws -> Bool {
        guard let statement = try DAO(db, self).existsStatement() else {
            // Nil primary key
            return false
        }
        return try Row.fetchOne(statement) != nil
    }
    
}

extension MutablePersistableRecord {
    
    // MARK: - Deleting All
    
    /// Deletes all records; returns the number of deleted rows.
    ///
    /// - parameter db: A database connection.
    /// - returns: The number of deleted rows
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    @discardableResult
    public static func deleteAll(_ db: Database) throws -> Int {
        return try all().deleteAll(db)
    }
}

extension MutablePersistableRecord {
    
    // MARK: - Deleting by Single-Column Primary Key
    
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
    public static func deleteAll<Sequence: Swift.Sequence>(_ db: Database, keys: Sequence) throws -> Int where Sequence.Element: DatabaseValueConvertible {
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
    public static func deleteOne<PrimaryKeyType: DatabaseValueConvertible>(_ db: Database, key: PrimaryKeyType?) throws -> Bool {
        guard let key = key else {
            // Avoid hitting the database
            return false
        }
        return try deleteAll(db, keys: [key]) > 0
    }
}

extension MutablePersistableRecord {
    
    // MARK: - Deleting by Key
    
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
        return try deleteAll(db, keys: [key]) > 0
    }
}

// MARK: - PersistableRecord

/// Types that adopt PersistableRecord can be inserted, updated, and deleted.
///
/// This protocol is intented for types that don't have an INTEGER PRIMARY KEY.
///
/// Unlike MutablePersistableRecord, the insert() and save() methods are not
/// mutating methods.
public protocol PersistableRecord : MutablePersistableRecord {
    
    /// Notifies the record that it was succesfully inserted.
    ///
    /// Do not call this method directly: it is called for you, in a protected
    /// dispatch queue, with the inserted RowID and the eventual
    /// INTEGER PRIMARY KEY column name.
    ///
    /// This method is optional: the default implementation does nothing.
    ///
    /// If you need a mutating variant of this method, adopt the
    /// MutablePersistableRecord protocol instead.
    ///
    /// - parameters:
    ///     - rowID: The inserted rowID.
    ///     - column: The name of the eventual INTEGER PRIMARY KEY column.
    func didInsert(with rowID: Int64, for column: String?)
    
    /// Executes an INSERT statement.
    ///
    /// This method is guaranteed to have inserted a row in the database if it
    /// returns without error.
    ///
    /// Upon successful insertion, the didInsert(with:for:) method
    /// is called with the inserted RowID and the eventual INTEGER PRIMARY KEY
    /// column name.
    ///
    /// This method has a default implementation, so your adopting types don't
    /// have to implement it. Yet your types can provide their own
    /// implementation of insert(). In their implementation, it is recommended
    /// that they invoke the performInsert() method.
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    func insert(_ db: Database) throws
    
    /// Executes an INSERT or an UPDATE statement so that `self` is saved in
    /// the database.
    ///
    /// If the receiver has a non-nil primary key and a matching row in the
    /// database, this method performs an update.
    ///
    /// Otherwise, performs an insert.
    ///
    /// This method is guaranteed to have inserted or updated a row in the
    /// database if it returns without error.
    ///
    /// This method has a default implementation, so your adopting types don't
    /// have to implement it. Yet your types can provide their own
    /// implementation of save(). In their implementation, it is recommended
    /// that they invoke the performSave() method.
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError whenever an SQLite error occurs, or errors
    ///   thrown by update().
    func save(_ db: Database) throws
}

extension PersistableRecord {
    
    /// Notifies the record that it was succesfully inserted.
    ///
    /// The default implementation does nothing.
    public func didInsert(with rowID: Int64, for column: String?) {
    }
    
    // MARK: - Immutable CRUD
    
    /// Executes an INSERT statement.
    ///
    /// The default implementation for insert() invokes performInsert().
    public func insert(_ db: Database) throws {
        try performInsert(db)
    }
    
    /// Executes an INSERT or an UPDATE statement so that `self` is saved in
    /// the database.
    ///
    /// The default implementation for save() invokes performSave().
    public func save(_ db: Database) throws {
        try performSave(db)
    }
    
    
    // MARK: - Immutable CRUD Internals
    
    /// Don't invoke this method directly: it is an internal method for types
    /// that adopt PersistableRecord.
    ///
    /// performInsert() provides the default implementation for insert(). Types
    /// that adopt PersistableRecord can invoke performInsert() in their
    /// implementation of insert(). They should not provide their own
    /// implementation of performInsert().
    public func performInsert(_ db: Database) throws {
        let conflictResolutionForInsert = type(of: self).persistenceConflictPolicy.conflictResolutionForInsert
        let dao = try DAO(db, self)
        try dao.insertStatement(onConflict: conflictResolutionForInsert).execute()
        
        if !conflictResolutionForInsert.invalidatesLastInsertedRowID {
            didInsert(with: db.lastInsertedRowID, for: dao.primaryKey.rowIDColumn)
        }
    }
    
    /// Don't invoke this method directly: it is an internal method for types
    /// that adopt PersistableRecord.
    ///
    /// performSave() provides the default implementation for save(). Types
    /// that adopt PersistableRecord can invoke performSave() in their
    /// implementation of save(). They should not provide their own
    /// implementation of performSave().
    ///
    /// This default implementation forwards the job to `update` or `insert`.
    public func performSave(_ db: Database) throws {
        // Make sure we call self.insert and self.update so that classes that
        // override insert or save have opportunity to perform their custom job.
        
        if try canUpdate(db) {
            do {
                try update(db)
            } catch PersistenceError.recordNotFound {
                // TODO: check that the not persisted objet is self
                //
                // Why? Adopting types could override update() and update another
                // object which may be the one throwing this error.
                try insert(db)
            }
        } else {
            try insert(db)
        }
    }
}


// MARK: - DatabaseDateEncodingStrategy

/// DatabaseDateEncodingStrategy specifies how PersistableRecord types that also
/// adopt the standard Encodable protocol encode their date properties.
///
/// For example:
///
///     struct Player: PersistableRecord, Encodable {
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

/// DatabaseUUIDEncodingStrategy specifies how FetchableRecord types that also
/// adopt the standard Encodable protocol encode their UUID properties.
///
/// For example:
///
///     struct Player: PersistableProtocol, Encodable {
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

// MARK: - DAO

/// DAO takes care of PersistableRecord CRUD
final class DAO {
    
    /// The database
    let db: Database
    
    /// The record
    let record: MutablePersistableRecord
    
    /// DAO keeps a copy the record's persistenceContainer, so that this
    /// dictionary is built once whatever the database operation. It is
    /// guaranteed to have at least one (key, value) pair.
    let persistenceContainer: PersistenceContainer
    
    /// The table name
    let databaseTableName: String
    
    /// The table primary key
    let primaryKey: PrimaryKeyInfo
    
    init(_ db: Database, _ record: MutablePersistableRecord) throws {
        let databaseTableName = type(of: record).databaseTableName
        let primaryKey = try db.primaryKey(databaseTableName)
        let persistenceContainer = PersistenceContainer(record)
        
        GRDBPrecondition(!persistenceContainer.isEmpty, "\(type(of: record)): invalid empty persistence container")
        
        self.db = db
        self.record = record
        self.persistenceContainer = persistenceContainer
        self.databaseTableName = databaseTableName
        self.primaryKey = primaryKey
    }
    
    func insertStatement(onConflict: Database.ConflictResolution) throws -> UpdateStatement {
        let query = InsertQuery(
            onConflict: onConflict,
            tableName: databaseTableName,
            insertedColumns: persistenceContainer.columns)
        let statement = try db.internalCachedUpdateStatement(query.sql)
        statement.unsafeSetArguments(StatementArguments(persistenceContainer.values))
        return statement
    }
    
    /// Returns nil if and only if primary key is nil
    func updateStatement(_ db: Database, columns: Set<String>, onConflict: Database.ConflictResolution) throws -> UpdateStatement? {
        // Fail early if primary key does not resolve to a database row.
        let primaryKeyColumns = primaryKey.columns
        let primaryKeyValues = primaryKeyColumns.map {
            persistenceContainer[caseInsensitive: $0]?.databaseValue ?? .null
        }
        guard primaryKeyValues.contains(where: { !$0.isNull }) else { return nil }
        
        // Don't update columns not present in columns
        // Don't update columns not present in the persistenceContainer
        // Don't update primary key columns
        let lowercaseUpdatedColumns = Set(columns.map { $0.lowercased() })
            .intersection(persistenceContainer.columns.map { $0.lowercased() })
            .subtracting(primaryKeyColumns.map { $0.lowercased() })
        
        var updatedColumns: [String] = try db
            .columns(in: databaseTableName)
            .map { $0.name }
            .filter { lowercaseUpdatedColumns.contains($0.lowercased()) }
        
        if updatedColumns.isEmpty {
            // IMPLEMENTATION NOTE
            //
            // It is important to update something, so that
            // TransactionObserver can observe a change even though this
            // change is useless.
            //
            // The goal is to be able to write tests with minimal tables,
            // including tables made of a single primary key column.
            updatedColumns = primaryKeyColumns
        }
        
        let updatedValues = updatedColumns.map {
            persistenceContainer[caseInsensitive: $0]?.databaseValue ?? .null
        }
        
        let query = UpdateQuery(
            onConflict: onConflict,
            tableName: databaseTableName,
            updatedColumns: updatedColumns,
            conditionColumns: primaryKeyColumns)
        let statement = try db.internalCachedUpdateStatement(query.sql)
        statement.unsafeSetArguments(StatementArguments(updatedValues + primaryKeyValues))
        return statement
    }
    
    /// Returns nil if and only if primary key is nil
    func deleteStatement() throws -> UpdateStatement? {
        // Fail early if primary key does not resolve to a database row.
        let primaryKeyColumns = primaryKey.columns
        let primaryKeyValues = primaryKeyColumns.map {
            persistenceContainer[caseInsensitive: $0]?.databaseValue ?? .null
        }
        guard primaryKeyValues.contains(where: { !$0.isNull }) else { return nil }
        
        let query = DeleteQuery(
            tableName: databaseTableName,
            conditionColumns: primaryKeyColumns)
        let statement = try db.internalCachedUpdateStatement(query.sql)
        statement.unsafeSetArguments(StatementArguments(primaryKeyValues))
        return statement
    }
    
    /// Returns nil if and only if primary key is nil
    func existsStatement() throws -> SelectStatement? {
        // Fail early if primary key does not resolve to a database row.
        let primaryKeyColumns = primaryKey.columns
        let primaryKeyValues = primaryKeyColumns.map {
            persistenceContainer[caseInsensitive: $0]?.databaseValue ?? .null
        }
        guard primaryKeyValues.contains(where: { !$0.isNull }) else { return nil }
        
        let query = ExistsQuery(
            tableName: databaseTableName,
            conditionColumns: primaryKeyColumns)
        let statement = try db.internalCachedSelectStatement(query.sql)
        statement.unsafeSetArguments(StatementArguments(primaryKeyValues))
        return statement
    }
}


// MARK: - InsertQuery

private struct InsertQuery: Hashable {
    let onConflict: Database.ConflictResolution
    let tableName: String
    let insertedColumns: [String]
    
    #if !swift(>=4.2)
    var hashValue: Int { return tableName.hashValue }
    #endif
}

extension InsertQuery {
    static let sqlCache = ReadWriteBox([InsertQuery: String]())
    var sql: String {
        if let sql = InsertQuery.sqlCache.read({ $0[self] }) {
            return sql
        }
        let columnsSQL = insertedColumns.map { $0.quotedDatabaseIdentifier }.joined(separator: ", ")
        let valuesSQL = databaseQuestionMarks(count: insertedColumns.count)
        let sql: String
        switch onConflict {
        case .abort:
            sql = "INSERT INTO \(tableName.quotedDatabaseIdentifier) (\(columnsSQL)) VALUES (\(valuesSQL))"
        default:
            sql = "INSERT OR \(onConflict.rawValue) INTO \(tableName.quotedDatabaseIdentifier) (\(columnsSQL)) VALUES (\(valuesSQL))"
        }
        InsertQuery.sqlCache.write { $0[self] = sql }
        return sql
    }
}


// MARK: - UpdateQuery

private struct UpdateQuery: Hashable {
    let onConflict: Database.ConflictResolution
    let tableName: String
    let updatedColumns: [String]
    let conditionColumns: [String]
    
    #if !swift(>=4.2)
    var hashValue: Int { return tableName.hashValue }
    #endif
}

extension UpdateQuery {
    static let sqlCache = ReadWriteBox([UpdateQuery: String]())
    var sql: String {
        if let sql = UpdateQuery.sqlCache.read({ $0[self] }) {
            return sql
        }
        let updateSQL = updatedColumns.map { "\($0.quotedDatabaseIdentifier)=?" }.joined(separator: ", ")
        let whereSQL = conditionColumns.map { "\($0.quotedDatabaseIdentifier)=?" }.joined(separator: " AND ")
        let sql: String
        switch onConflict {
        case .abort:
            sql = "UPDATE \(tableName.quotedDatabaseIdentifier) SET \(updateSQL) WHERE \(whereSQL)"
        default:
            sql = "UPDATE OR \(onConflict.rawValue) \(tableName.quotedDatabaseIdentifier) SET \(updateSQL) WHERE \(whereSQL)"
        }
        UpdateQuery.sqlCache.write { $0[self] = sql }
        return sql
    }
}


// MARK: - DeleteQuery

private struct DeleteQuery {
    let tableName: String
    let conditionColumns: [String]
}

extension DeleteQuery {
    var sql: String {
        let whereSQL = conditionColumns.map { "\($0.quotedDatabaseIdentifier)=?" }.joined(separator: " AND ")
        return "DELETE FROM \(tableName.quotedDatabaseIdentifier) WHERE \(whereSQL)"
    }
}


// MARK: - ExistsQuery

private struct ExistsQuery {
    let tableName: String
    let conditionColumns: [String]
}

extension ExistsQuery {
    var sql: String {
        let whereSQL = conditionColumns.map { "\($0.quotedDatabaseIdentifier)=?" }.joined(separator: " AND ")
        return "SELECT 1 FROM \(tableName.quotedDatabaseIdentifier) WHERE \(whereSQL)"
    }
}

/// Types that adopt `MutablePersistableRecord` can be inserted, updated,
/// and deleted.
public protocol MutablePersistableRecord: EncodableRecord, TableRecord {
    /// The policy that handles SQLite conflicts when records are inserted
    /// or updated.
    ///
    /// The default implementation uses the ABORT policy for both insertions and
    /// updates, and has GRDB generate regular INSERT and UPDATE queries.
    ///
    /// See <https://www.sqlite.org/lang_conflict.html>
    static var persistenceConflictPolicy: PersistenceConflictPolicy { get }
    
    // MARK: Insertion Callbacks
    
    /// Persistence callback called before the record is inserted.
    ///
    /// Default implementation does nothing.
    ///
    /// - parameter db: A database connection.
    mutating func willInsert(_ db: Database) throws
    
    /// Persistence callback called around the record insertion.
    ///
    /// If you provide a custom implementation of this method, you must call
    /// the `insert` parameter at some point in your implementation, and you
    /// must rethrow its eventual error.
    ///
    /// For example:
    ///
    ///     struct Player: MutablePersistableRecord {
    ///         func aroundInsert(_ db: Database, insert: () throws -> InsertionSuccess) throws {
    ///             print("Player will insert")
    ///             _ = try insert()
    ///             print("Player did insert")
    ///         }
    ///     }
    ///
    /// - parameter db: A database connection.
    /// - parameter insert: A function that inserts the record, and returns
    ///   information about the inserted row.
    func aroundInsert(_ db: Database, insert: () throws -> InsertionSuccess) throws
    
    /// Persistence callback called upon successful insertion.
    ///
    /// The default implementation does nothing.
    ///
    /// You can provide a custom implementation in order to grab the
    /// auto-incremented id:
    ///
    ///     struct Player: MutablePersistableRecord {
    ///         var id: Int64?
    ///         var name: String
    ///
    ///         mutating func didInsert(_ inserted: InsertionSuccess) {
    ///             id = inserted.rowID
    ///         }
    ///     }
    ///
    /// - parameter inserted: Information about the inserted row.
    mutating func didInsert(_ inserted: InsertionSuccess)
    
    // MARK: Update Callbacks
    
    /// Persistence callback called before the record is updated.
    ///
    /// Default implementation does nothing.
    ///
    /// - parameter db: A database connection.
    func willUpdate(_ db: Database, columns: Set<String>) throws
    
    // swiftlint:disable line_length
    /// Persistence callback called around the record update.
    ///
    /// If you provide a custom implementation of this method, you must call
    /// the `update` parameter at some point in your implementation, and you
    /// must rethrow its eventual error.
    ///
    /// For example:
    ///
    ///     struct Player: MutablePersistableRecord {
    ///         func aroundUpdate(_ db: Database, columns: Set<String>, update: () throws -> PersistenceSuccess) throws {
    ///             print("Player will update")
    ///             _ = try update()
    ///             print("Player did update")
    ///         }
    ///     }
    ///
    /// - parameter db: A database connection.
    /// - parameter columns: The updated columns.
    /// - parameter update: A function that updates the record. Its result is
    ///   reserved for GRDB usage.
    func aroundUpdate(_ db: Database, columns: Set<String>, update: () throws -> PersistenceSuccess) throws
    // swiftlint:enable line_length
    
    /// Persistence callback called upon successful update.
    ///
    /// Default implementation does nothing.
    ///
    /// - parameter updated: Reserved for GRDB usage.
    func didUpdate(_ updated: PersistenceSuccess)
    
    // MARK: Save Callbacks
    
    /// Persistence callback called before the record is updated or inserted.
    ///
    /// Default implementation does nothing.
    ///
    /// - parameter db: A database connection.
    func willSave(_ db: Database) throws
    
    /// Persistence callback called around the record update or insertion.
    ///
    /// If you provide a custom implementation of this method, you must call
    /// the `save` parameter at some point in your implementation, and you
    /// must rethrow its eventual error.
    ///
    /// For example:
    ///
    ///     struct Player: MutablePersistableRecord {
    ///         func aroundSave(_ db: Database, save: () throws -> PersistenceSuccess) throws {
    ///             print("Player will save")
    ///             _ = try save()
    ///             print("Player did save")
    ///         }
    ///     }
    ///
    /// - parameter db: A database connection.
    /// - parameter update: A function that updates the record. Its result is
    ///   reserved for GRDB usage.
    func aroundSave(_ db: Database, save: () throws -> PersistenceSuccess) throws
    
    /// Persistence callback called upon successful update or insertion.
    ///
    /// Default implementation does nothing.
    ///
    /// - parameter saved: Reserved for GRDB usage.
    func didSave(_ saved: PersistenceSuccess)
    
    // MARK: Deletion Callbacks
    
    /// Persistence callback called before the record is deleted.
    ///
    /// Default implementation does nothing.
    ///
    /// - parameter db: A database connection.
    func willDelete(_ db: Database) throws
    
    /// Persistence callback called around the destruction of the record.
    ///
    /// If you provide a custom implementation of this method, you must call
    /// the `delete` parameter at some point in your implementation, and you
    /// must rethrow its eventual error.
    ///
    /// For example:
    ///
    ///     struct Player: MutablePersistableRecord {
    ///         func aroundDelete(_ db: Database, delete: () throws -> Bool) throws {
    ///             print("Player will delete")
    ///             _ = try delete()
    ///             print("Player did delete")
    ///         }
    ///     }
    ///
    /// - parameter db: A database connection.
    /// - parameter delete: A function that deletes the record and returns
    ///   whether a row was deleted in the database.
    func aroundDelete(_ db: Database, delete: () throws -> Bool) throws
    
    /// Persistence callback called upon successful deletion.
    ///
    /// Default implementation does nothing.
    ///
    /// - parameter deleted: Whether a row was deleted in the database.
    func didDelete(deleted: Bool)
}

extension MutablePersistableRecord {
    public static var persistenceConflictPolicy: PersistenceConflictPolicy {
        PersistenceConflictPolicy(insert: .abort, update: .abort)
    }
    
    /// Call for programmer errors from the `aroundXxx` callbacks.
    @usableFromInline
    func persistenceCallbackMisuse(_ callbackName: String) throws -> Never {
        let message = """
            Incorrect implementation of the `\(Self.self).\(callbackName)` persistence callback: \
            the action function was not called, or its error was not rethrown.
            """
        // This is a programmer error, but we must not crash, because it can
        // only be detected in case of database errors, which happen
        // infrequently. That's why we gently throw SQLITE_MISUSE.
        throw DatabaseError(
            resultCode: .SQLITE_MISUSE,
            message: message)
    }
}

// MARK: - Existence Check

extension MutablePersistableRecord {
    /// Returns true if and only if the primary key matches a row in
    /// the database.
    ///
    /// - parameter db: A database connection.
    /// - returns: Whether the primary key matches a row in the database.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func exists(_ db: Database) throws -> Bool {
        guard let statement = try DAO(db, self).existsStatement() else {
            // Nil primary key
            return false
        }
        return try Bool.fetchOne(statement)!
    }
}

/// An error thrown by a type that adopts `MutablePersistableRecord`.
public enum PersistenceError: Error {
    
    /// Thrown by `MutablePersistableRecord.update(_:)` methods when no matching
    /// row could be found in the database.
    ///
    /// - `databaseTableName`: the table of the unfound record
    /// - `key`: the key of the unfound record (column and values)
    case recordNotFound(databaseTableName: String, key: [String: DatabaseValue])
}

extension PersistenceError: CustomStringConvertible {
    /// :nodoc:
    public var description: String {
        switch self {
        case let .recordNotFound(databaseTableName: databaseTableName, key: key):
            let row = Row(key) // For nice output
            return "Key not found in table \(databaseTableName): \(row.description)"
        }
    }
}

/// The `MutablePersistableRecord` protocol uses this type in order to handle
/// SQLite conflicts when records are inserted or updated.
///
/// See `MutablePersistableRecord.persistenceConflictPolicy`.
///
/// See <https://www.sqlite.org/lang_conflict.html>
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

/// The result of a successful record insertion.
///
/// `InsertionSuccess` gives the auto-incremented id after a successful
/// record insertion:
///
///     struct Player: Encodable, MutablePersistableRecord {
///         var id: Int64?
///         var name: String
///
///         mutating func didInsert(_ inserted: InsertionSuccess) {
///             id = inserted.rowID
///         }
///     }
///
///     try dbQueue.write { db in
///         var player = Player(id: nil, name: "Alice")
///         try player.insert(db)
///         print(player.id) // The inserted id
///     }
public struct InsertionSuccess {
    /// The rowid of the inserted record.
    ///
    /// For example:
    ///
    ///     struct Player: Encodable, MutablePersistableRecord {
    ///         var id: Int64?
    ///         var name: String
    ///
    ///         mutating func didInsert(_ inserted: InsertionSuccess) {
    ///             id = inserted.rowID
    ///         }
    ///     }
    ///
    /// To learn about rowids, see <https://www.sqlite.org/lang_createtable.html#rowids_and_the_integer_primary_key>.
    public var rowID: Int64
    
    /// The name of the eventual INTEGER PRIMARY KEY column.
    public var rowIDColumn: String?
    
    // Used by the Record class in order to manage its `hasDatabaseChanges` flag.
    /// The persistence container that was inserted.
    ///
    /// If the database table has a rowid column, the persistence container
    /// contains the rowid of the inserted record.
    public var persistenceContainer: PersistenceContainer
}

/// The result of a successful record persistence (insert or update).
public struct PersistenceSuccess {
    // Used by the Record class in order to manage its `hasDatabaseChanges` flag.
    /// The persistence container that was saved.
    ///
    /// After an insert, and if the database table has a rowid column, the
    /// persistence container contains the rowid of the inserted record.
    public var persistenceContainer: PersistenceContainer
    
    init(persistenceContainer: PersistenceContainer) {
        self.persistenceContainer = persistenceContainer
    }
    
    @usableFromInline
    init(_ inserted: InsertionSuccess) {
        self.init(persistenceContainer: inserted.persistenceContainer)
    }
}

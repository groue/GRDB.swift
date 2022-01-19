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

/// An error thrown by a type that adopts `MutablePersistableRecord`.
public enum PersistenceError: Error, CustomStringConvertible {
    
    /// Thrown by `MutablePersistableRecord.update(_:)` methods when no matching
    /// row could be found in the database.
    ///
    /// - `databaseTableName`: the table of the unfound record
    /// - `key`: the key of the unfound record (column and values)
    case recordNotFound(databaseTableName: String, key: [String: DatabaseValue])
}

// CustomStringConvertible
extension PersistenceError {
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

/// Types that adopt `MutablePersistableRecord` can be inserted, updated,
/// and deleted.
public protocol MutablePersistableRecord: EncodableRecord, TableRecord {
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
    /// See <https://www.sqlite.org/lang_conflict.html>
    static var persistenceConflictPolicy: PersistenceConflictPolicy { get }
    
    /// Notifies the record that it was successfully inserted.
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
}

extension MutablePersistableRecord {
    /// Describes the conflict policy for insertions and updates.
    ///
    /// The default value specifies ABORT policy for both insertions and
    /// updates, which has GRDB generate regular INSERT and UPDATE queries.
    public static var persistenceConflictPolicy: PersistenceConflictPolicy {
        PersistenceConflictPolicy(insert: .abort, update: .abort)
    }
    
    /// Notifies the record that it was successfully inserted.
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
    
    /// Executes an INSERT statement so that `self` is saved in the database,
    /// and return the inserted record.
    ///
    /// Usage:
    ///
    ///     let player = Player(id: nil, name: "Arthur")
    ///     let insertedPlayer = try dbQueue.write { db in
    ///         try player.inserted(db)
    ///     }
    ///     print(player.id)         // nil
    ///     print(insertedPlayer.id) // some id
    public func inserted(_ db: Database) throws -> Self {
        var result = self
        try result.insert(db)
        return result
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
    public func update<Sequence>(_ db: Database, columns: Sequence)
    throws
    where Sequence: Swift.Sequence, Sequence.Element: ColumnExpression
    {
        try update(db, columns: Set(columns.map(\.name)))
    }
    
    /// Executes an UPDATE statement.
    ///
    /// - parameter db: A database connection.
    /// - parameter columns: The columns to update.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    ///   PersistenceError.recordNotFound is thrown if the primary key does not
    ///   match any row in the database.
    public func update<Sequence>(_ db: Database, columns: Sequence)
    throws
    where Sequence: Swift.Sequence, Sequence.Element == String
    {
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
        try update(db, columns: Set(columns.map(\.name)))
    }
    
    /// If the record has any difference from the other record, executes an
    /// UPDATE statement so that those differences and only those difference are
    /// saved in the database.
    ///
    /// This method is guaranteed to have saved the eventual differences in the
    /// database if it returns without error.
    ///
    /// For example:
    ///
    ///     if let oldPlayer = try Player.fetchOne(db, key: 42) {
    ///         var newPlayer = oldPlayer
    ///         newPlayer.score += 10
    ///         newPlayer.hasAward = true
    ///         try newPlayer.updateChanges(db, from: oldRecord)
    ///     }
    ///
    /// - parameter db: A database connection.
    /// - parameter record: The comparison record.
    /// - returns: Whether the record had changes.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    ///   PersistenceError.recordNotFound is thrown if the primary key does not
    ///   match any row in the database and record could not be updated.
    /// - SeeAlso: updateChanges(_:with:)
    @discardableResult
    public func updateChanges<Record: MutablePersistableRecord>(_ db: Database, from record: Record) throws -> Bool {
        try updateChanges(db, from: PersistenceContainer(db, record))
    }
    
    /// Mutates the record according to the provided closure, and then, if the
    /// record has any difference from its previous version, executes an
    /// UPDATE statement so that those differences and only those difference are
    /// saved in the database.
    ///
    /// This method is guaranteed to have saved the eventual differences in the
    /// database if it returns without error.
    ///
    /// For example:
    ///
    ///     if var player = try Player.fetchOne(db, key: 42) {
    ///         try player.updateChanges(db) {
    ///             $0.score += 10
    ///             $0.hasAward = true
    ///         }
    ///     }
    ///
    /// - parameter db: A database connection.
    /// - parameter change: A closure that modifies the record.
    /// - returns: Whether the record had changes.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    ///   PersistenceError.recordNotFound is thrown if the primary key does not
    ///   match any row in the database and record could not be updated.
    @discardableResult
    public mutating func updateChanges(_ db: Database, with change: (inout Self) throws -> Void) throws -> Bool {
        let container = try PersistenceContainer(db, self)
        try change(&self)
        return try updateChanges(db, from: container)
    }
    
    /// Executes an INSERT or an UPDATE statement so that `self` is saved in
    /// the database.
    ///
    /// The default implementation for save() invokes performSave().
    public mutating func save(_ db: Database) throws {
        try performSave(db)
    }
    
    /// Executes an INSERT or an UPDATE statement so that `self` is saved in
    /// the database, and return the saved record.
    ///
    /// Usage:
    ///
    ///     let player = Player(id: nil, name: "Arthur")
    ///     let savedPlayer = try dbQueue.write { db in
    ///         try player.saved(db)
    ///     }
    ///     print(player.id)      // nil
    ///     print(savedPlayer.id) // some id
    public func saved(_ db: Database) throws -> Self {
        var result = self
        try result.save(db)
        return result
    }
    
    /// Executes a DELETE statement.
    ///
    /// The default implementation for delete() invokes performDelete().
    @discardableResult
    public func delete(_ db: Database) throws -> Bool {
        try performDelete(db)
    }
    
    /// Returns true if and only if the primary key matches a row in
    /// the database.
    ///
    /// The default implementation for exists() invokes performExists().
    public func exists(_ db: Database) throws -> Bool {
        try performExists(db)
    }
    
    // MARK: - Record Comparison
    
    @discardableResult
    fileprivate func updateChanges(_ db: Database, from container: PersistenceContainer) throws -> Bool {
        let changes = try PersistenceContainer(db, self).changesIterator(from: container)
        let changedColumns: Set<String> = changes.reduce(into: []) { $0.insert($1.0) }
        if changedColumns.isEmpty {
            return false
        }
        try update(db, columns: changedColumns)
        return true
    }
    
    // MARK: - CRUD Internals
    
    /// Return a non-nil dictionary if record has a non-null primary key
    func primaryKey(_ db: Database) throws -> [String: DatabaseValue]? {
        let databaseTableName = type(of: self).databaseTableName
        let primaryKeyInfo = try db.primaryKey(databaseTableName)
        let container = try PersistenceContainer(db, self)
        let primaryKey = Dictionary(uniqueKeysWithValues: primaryKeyInfo.columns.map {
            ($0, container[caseInsensitive: $0]?.databaseValue ?? .null)
        })
        if primaryKey.allSatisfy({ $0.value.isNull }) {
            return nil
        }
        return primaryKey
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
        let dao = try DAO(db, self)
        guard let statement = try dao.updateStatement(
                columns: columns,
                onConflict: type(of: self).persistenceConflictPolicy.conflictResolutionForUpdate)
        else {
            // Nil primary key
            throw dao.makeRecordNotFoundError()
        }
        try statement.execute()
        if db.changesCount == 0 {
            throw dao.makeRecordNotFoundError()
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
        // Call self.insert and self.update so that we support classes that
        // override those methods.
        if let key = try primaryKey(db) {
            do {
                try update(db)
            } catch PersistenceError.recordNotFound(databaseTableName: type(of: self).databaseTableName, key: key) {
                try insert(db)
            }
        } else {
            try insert(db)
        }
    }
    
    /// Don't invoke this method directly: it is an internal method for types
    /// that adopt MutablePersistableRecord.
    ///
    /// performDelete() provides the default implementation for delete(). Types
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

extension MutablePersistableRecord where Self: AnyObject {
    
    // MARK: - Record Comparison
    
    /// Mutates the record according to the provided closure, and then, if the
    /// record has any difference from its previous version, executes an
    /// UPDATE statement so that those differences and only those difference are
    /// saved in the database.
    ///
    /// This method is guaranteed to have saved the eventual differences in the
    /// database if it returns without error.
    ///
    /// For example:
    ///
    ///     if let player = try Player.fetchOne(db, key: 42) {
    ///         try player.updateChanges(db) {
    ///             $0.score += 10
    ///             $0.hasAward = true
    ///         }
    ///     }
    ///
    /// - parameter db: A database connection.
    /// - parameter change: A closure that modifies the record.
    /// - returns: Whether the record had changes.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    ///   PersistenceError.recordNotFound is thrown if the primary key does not
    ///   match any row in the database and record could not be updated.
    @discardableResult
    public func updateChanges(_ db: Database, with change: (Self) throws -> Void) throws -> Bool {
        let container = try PersistenceContainer(db, self)
        try change(self)
        return try updateChanges(db, from: container)
    }
}

// MARK: - PersistableRecord

/// Types that adopt `PersistableRecord` can be inserted, updated, and deleted.
///
/// Unlike `MutablePersistableRecord`, the `insert(_:)` and `save(_:)` methods
/// are not mutating methods.
public protocol PersistableRecord: MutablePersistableRecord {
    
    /// Notifies the record that it was successfully inserted.
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
    
    /// Notifies the record that it was successfully inserted.
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
        // Call self.insert and self.update so that we support classes that
        // override those methods.
        if let key = try primaryKey(db) {
            do {
                try update(db)
            } catch PersistenceError.recordNotFound(databaseTableName: type(of: self).databaseTableName, key: key) {
                try insert(db)
            }
        } else {
            try insert(db)
        }
    }
}

// MARK: - DAO

extension PersistenceContainer {
    /// Convenience initializer from a database connection and a record
    init<Record: EncodableRecord & TableRecord>(_ db: Database, _ record: Record) throws {
        let databaseTableName = type(of: record).databaseTableName
        let columnCount = try db.columns(in: databaseTableName).count
        self.init(minimumCapacity: columnCount)
        record.encode(to: &self)
    }
}

/// DAO takes care of PersistableRecord CRUD
final class DAO<Record: MutablePersistableRecord> {
    /// The database
    let db: Database
    
    /// DAO keeps a copy the record's persistenceContainer, so that this
    /// dictionary is built once whatever the database operation. It is
    /// guaranteed to have at least one (key, value) pair.
    let persistenceContainer: PersistenceContainer
    
    /// The table name
    let databaseTableName: String
    
    /// The table primary key info
    let primaryKey: PrimaryKeyInfo
    
    init(_ db: Database, _ record: Record) throws {
        self.db = db
        databaseTableName = type(of: record).databaseTableName
        primaryKey = try db.primaryKey(databaseTableName)
        persistenceContainer = try PersistenceContainer(db, record)
        GRDBPrecondition(!persistenceContainer.isEmpty, "\(type(of: record)): invalid empty persistence container")
    }
    
    func insertStatement(onConflict: Database.ConflictResolution) throws -> Statement {
        let query = InsertQuery(
            onConflict: onConflict,
            tableName: databaseTableName,
            insertedColumns: persistenceContainer.columns)
        let statement = try db.internalCachedStatement(sql: query.sql)
        statement.setUncheckedArguments(StatementArguments(persistenceContainer.values))
        return statement
    }
    
    /// Returns nil if and only if primary key is nil
    func updateStatement(columns: Set<String>, onConflict: Database.ConflictResolution) throws -> Statement? {
        // Fail early if primary key does not resolve to a database row.
        let primaryKeyColumns = primaryKey.columns
        let primaryKeyValues = primaryKeyColumns.map {
            persistenceContainer[caseInsensitive: $0]?.databaseValue ?? .null
        }
        if primaryKeyValues.allSatisfy({ $0.isNull }) {
            return nil
        }
        
        // Don't update columns not present in columns
        // Don't update columns not present in the persistenceContainer
        // Don't update primary key columns
        let lowercaseUpdatedColumns = Set(columns.map { $0.lowercased() })
            .intersection(persistenceContainer.columns.map { $0.lowercased() })
            .subtracting(primaryKeyColumns.map { $0.lowercased() })
        
        var updatedColumns: [String] = try db
            .columns(in: databaseTableName)
            .map(\.name)
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
        let statement = try db.internalCachedStatement(sql: query.sql)
        statement.setUncheckedArguments(StatementArguments(updatedValues + primaryKeyValues))
        return statement
    }
    
    /// Returns nil if and only if primary key is nil
    func deleteStatement() throws -> Statement? {
        // Fail early if primary key does not resolve to a database row.
        let primaryKeyColumns = primaryKey.columns
        let primaryKeyValues = primaryKeyColumns.map {
            persistenceContainer[caseInsensitive: $0]?.databaseValue ?? .null
        }
        if primaryKeyValues.allSatisfy({ $0.isNull }) {
            return nil
        }
        
        let query = DeleteQuery(
            tableName: databaseTableName,
            conditionColumns: primaryKeyColumns)
        let statement = try db.internalCachedStatement(sql: query.sql)
        statement.setUncheckedArguments(StatementArguments(primaryKeyValues))
        return statement
    }
    
    /// Returns nil if and only if primary key is nil
    func existsStatement() throws -> Statement? {
        // Fail early if primary key does not resolve to a database row.
        let primaryKeyColumns = primaryKey.columns
        let primaryKeyValues = primaryKeyColumns.map {
            persistenceContainer[caseInsensitive: $0]?.databaseValue ?? .null
        }
        if primaryKeyValues.allSatisfy({ $0.isNull }) {
            return nil
        }
        
        let query = ExistsQuery(
            tableName: databaseTableName,
            conditionColumns: primaryKeyColumns)
        let statement = try db.internalCachedStatement(sql: query.sql)
        statement.setUncheckedArguments(StatementArguments(primaryKeyValues))
        return statement
    }
    
    /// Throws a PersistenceError.recordNotFound error
    func makeRecordNotFoundError() -> Error {
        let key = Dictionary(uniqueKeysWithValues: primaryKey.columns.map {
            ($0, persistenceContainer[caseInsensitive: $0]?.databaseValue ?? .null)
        })
        return PersistenceError.recordNotFound(
            databaseTableName: databaseTableName,
            key: key)
    }
}


// MARK: - InsertQuery

private struct InsertQuery: Hashable {
    let onConflict: Database.ConflictResolution
    let tableName: String
    let insertedColumns: [String]
}

extension InsertQuery {
    @ReadWriteBox private static var sqlCache: [InsertQuery: String] = [:]
    var sql: String {
        if let sql = Self.sqlCache[self] {
            return sql
        }
        let columnsSQL = insertedColumns.map(\.quotedDatabaseIdentifier).joined(separator: ", ")
        let valuesSQL = databaseQuestionMarks(count: insertedColumns.count)
        let sql: String
        switch onConflict {
        case .abort:
            sql = """
            INSERT INTO \(tableName.quotedDatabaseIdentifier) (\(columnsSQL)) \
            VALUES (\(valuesSQL))
            """
        default:
            sql = """
            INSERT OR \(onConflict.rawValue) \
            INTO \(tableName.quotedDatabaseIdentifier) (\(columnsSQL)) \
            VALUES (\(valuesSQL))
            """
        }
        Self.sqlCache[self] = sql
        return sql
    }
}


// MARK: - UpdateQuery

private struct UpdateQuery: Hashable {
    let onConflict: Database.ConflictResolution
    let tableName: String
    let updatedColumns: [String]
    let conditionColumns: [String]
}

extension UpdateQuery {
    @ReadWriteBox private static var sqlCache: [UpdateQuery: String] = [:]
    var sql: String {
        if let sql = Self.sqlCache[self] {
            return sql
        }
        let updateSQL = updatedColumns.map { "\($0.quotedDatabaseIdentifier)=?" }.joined(separator: ", ")
        let whereSQL = conditionColumns.map { "\($0.quotedDatabaseIdentifier)=?" }.joined(separator: " AND ")
        let sql: String
        switch onConflict {
        case .abort:
            sql = """
                UPDATE \(tableName.quotedDatabaseIdentifier) \
                SET \(updateSQL) \
                WHERE \(whereSQL)
                """
        default:
            sql = """
                UPDATE OR \(onConflict.rawValue) \(tableName.quotedDatabaseIdentifier) \
                SET \(updateSQL) \
                WHERE \(whereSQL)
                """
        }
        Self.sqlCache[self] = sql
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

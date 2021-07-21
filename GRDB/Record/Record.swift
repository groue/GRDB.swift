// MARK: - Record

/// Record is a class that wraps a table row, or the result of any query. It is
/// designed to be subclassed.
open class Record: FetchableRecord, TableRecord, PersistableRecord {
    
    // MARK: - Initializers
    
    /// Creates a Record.
    public init() {
    }
    
    /// Creates a Record from a row.
    public required init(row: Row) {
        if row.isFetched {
            // Take care of the hasDatabaseChanges flag.
            //
            // Row may be a reused row which will turn invalid as soon as the
            // SQLite statement is iterated. We need to store an
            // immutable copy.
            referenceRow = row.copy()
        }
    }
    
    
    // MARK: - Core methods
    
    /// The name of a database table.
    ///
    /// This table name is required by the insert, update, save, delete,
    /// and exists methods.
    ///
    ///     class Player : Record {
    ///         override class var databaseTableName: String {
    ///             return "player"
    ///         }
    ///     }
    ///
    /// The implementation of the base class Record raises a fatal error.
    ///
    /// - returns: The name of a database table.
    open class var databaseTableName: String {
        // Programmer error
        fatalError("subclass must override")
    }
    
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
    open class var persistenceConflictPolicy: PersistenceConflictPolicy {
        PersistenceConflictPolicy(insert: .abort, update: .abort)
    }
    
    /// The default request selection.
    ///
    /// Unless this method is overriden, requests select all columns:
    ///
    ///     // SELECT * FROM player
    ///     try Player.fetchAll(db)
    ///
    /// You can override this property and provide an explicit list
    /// of columns:
    ///
    ///     class RestrictedPlayer : Record {
    ///         override static var databaseSelection: [SQLSelectable] {
    ///             return [Column("id"), Column("name")]
    ///         }
    ///     }
    ///
    ///     // SELECT id, name FROM player
    ///     try RestrictedPlayer.fetchAll(db)
    ///
    /// You can also add extra columns such as the `rowid` column:
    ///
    ///     class ExtendedPlayer : Player {
    ///         override static var databaseSelection: [SQLSelectable] {
    ///             return [AllColumns(), Column.rowID]
    ///         }
    ///     }
    ///
    ///     // SELECT *, rowid FROM player
    ///     try ExtendedPlayer.fetchAll(db)
    open class var databaseSelection: [SQLSelectable] {
        [AllColumns()]
    }
    
    
    /// Defines the values persisted in the database.
    ///
    /// Store in the *container* argument all values that should be stored in
    /// the columns of the database table (see Record.databaseTableName()).
    ///
    /// Primary key columns, if any, must be included.
    ///
    ///     class Player : Record {
    ///         var id: Int64?
    ///         var name: String?
    ///
    ///         override func encode(to container: inout PersistenceContainer) {
    ///             container["id"] = id
    ///             container["name"] = name
    ///         }
    ///     }
    ///
    /// The implementation of the base class Record does not store any value in
    /// the container.
    open func encode(to container: inout PersistenceContainer) {
    }
    
    /// Notifies the record that it was successfully inserted.
    ///
    /// Do not call this method directly: it is called for you, in a protected
    /// dispatch queue, with the inserted RowID and the eventual
    /// INTEGER PRIMARY KEY column name.
    ///
    /// The implementation of the base Record class does nothing.
    ///
    ///     class Player : Record {
    ///         var id: Int64?
    ///         var name: String?
    ///
    ///         func didInsert(with rowID: Int64, for column: String?) {
    ///             id = rowID
    ///         }
    ///     }
    ///
    /// - parameters:
    ///     - rowID: The inserted rowID.
    ///     - column: The name of the eventual INTEGER PRIMARY KEY column.
    open func didInsert(with rowID: Int64, for column: String?) {
    }
    
    
    // MARK: - Copy
    
    /// Returns a copy of `self`, initialized from all values encoded in the
    /// `encode(to:)` method.
    ///
    /// The eventual primary key is copied, as well as the
    /// `hasDatabaseChanges` flag.
    ///
    /// - returns: A copy of self.
    open func copy() -> Self {
        let copy = type(of: self).init(row: Row(self))
        copy.referenceRow = referenceRow
        return copy
    }
    
    
    // MARK: - Compare with Previous Versions
    
    /// A boolean that indicates whether the record has changes that have not
    /// been saved.
    ///
    /// This flag is purely informative, and does not prevent insert(),
    /// update(), and save() from performing their database queries.
    ///
    /// A record is *edited* if has been changed since last database
    /// synchronization (fetch, update, insert). Comparison
    /// is performed between *values* (values stored in the `encode(to:)`
    /// method, and values loaded from the database). Property setters do not
    /// trigger this flag.
    ///
    /// You can rely on the Record base class to compute this flag for you, or
    /// you may set it to true or false when you know better. Setting it to
    /// false does not prevent it from turning true on subsequent modifications
    /// of the record.
    public var hasDatabaseChanges: Bool {
        get { databaseChangesIterator().next() != nil }
        set { referenceRow = newValue ? nil : Row(self) }
    }
    
    /// A dictionary of changes that have not been saved.
    ///
    /// Its keys are column names, and values the old values that have been
    /// changed since last fetching or saving of the record.
    ///
    /// Unless the record has actually been fetched or saved, the old values
    /// are nil.
    ///
    /// See `hasDatabaseChanges` for more information.
    public var databaseChanges: [String: DatabaseValue?] {
        Dictionary(uniqueKeysWithValues: databaseChangesIterator())
    }
    
    // A change iterator that is used by both hasDatabaseChanges and
    // persistentChangedValues properties.
    private func databaseChangesIterator() -> AnyIterator<(String, DatabaseValue?)> {
        let oldRow = referenceRow
        var newValueIterator = PersistenceContainer(self).makeIterator()
        return AnyIterator {
            // Loop until we find a change, or exhaust columns:
            while let (column, newValue) = newValueIterator.next() {
                let newDbValue = newValue?.databaseValue ?? .null
                guard let oldRow = oldRow, let oldDbValue: DatabaseValue = oldRow[column] else {
                    return (column, nil)
                }
                if newDbValue != oldDbValue {
                    return (column, oldDbValue)
                }
            }
            return nil
        }
    }
    
    
    /// Reference row for the *hasDatabaseChanges* property.
    var referenceRow: Row?
    
    
    // MARK: - CRUD
    
    /// Executes an INSERT statement.
    ///
    /// On success, this method sets the *hasDatabaseChanges* flag to false.
    ///
    /// This method is guaranteed to have inserted a row in the database if it
    /// returns without error.
    ///
    /// Records whose primary key is declared as "INTEGER PRIMARY KEY" have
    /// their id automatically set after successful insertion, if it was nil
    /// before the insertion.
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    open func insert(_ db: Database) throws {
        let conflictResolutionForInsert = type(of: self).persistenceConflictPolicy.conflictResolutionForInsert
        let dao = try DAO(db, self)
        var persistenceContainer = dao.persistenceContainer
        try dao.insertStatement(onConflict: conflictResolutionForInsert).execute()
        
        if !conflictResolutionForInsert.invalidatesLastInsertedRowID {
            let rowID = db.lastInsertedRowID
            let rowIDColumn = dao.primaryKey.rowIDColumn
            didInsert(with: rowID, for: rowIDColumn)
            
            // Update persistenceContainer with inserted id, so that we can
            // set hasDatabaseChanges to false:
            if let rowIDColumn = rowIDColumn {
                persistenceContainer[caseInsensitive: rowIDColumn] = rowID
            }
        }
        
        // Set hasDatabaseChanges to false
        referenceRow = Row(persistenceContainer)
    }
    
    /// Executes an UPDATE statement.
    ///
    /// On success, this method sets the *hasDatabaseChanges* flag to false.
    ///
    /// This method is guaranteed to have updated a row in the database if it
    /// returns without error.
    ///
    /// - parameter db: A database connection.
    /// - parameter columns: The columns to update.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    ///   PersistenceError.recordNotFound is thrown if the primary key does not
    ///   match any row in the database and record could not be updated.
    open func update(_ db: Database, columns: Set<String>) throws {
        // The simplest code would be:
        //
        //     try performUpdate(db, columns: columns)
        //     hasDatabaseChanges = false
        //
        // But this would trigger two calls to `encode(to:)`.
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
        
        // Set hasDatabaseChanges to false
        referenceRow = Row(dao.persistenceContainer)
    }
    
    /// If the record has been changed, executes an UPDATE statement so that
    /// those changes and only those changes are saved in the database.
    ///
    /// On success, this method sets the *hasDatabaseChanges* flag to false.
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
    public final func updateChanges(_ db: Database) throws -> Bool {
        let changedColumns = Set(databaseChanges.keys)
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
    /// If the record has a non-nil primary key and a matching row in the
    /// database, this method performs an update.
    ///
    /// Otherwise, performs an insert.
    ///
    /// On success, this method sets the *hasDatabaseChanges* flag to false.
    ///
    /// This method is guaranteed to have inserted or updated a row in the
    /// database if it returns without error.
    ///
    /// You can't override this method. Instead, override `insert(_:)`
    /// or `update(_:columns:)`.
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError whenever an SQLite error occurs, or errors
    ///   thrown by update().
    public final func save(_ db: Database) throws {
        try performSave(db)
    }
    
    /// Executes a DELETE statement.
    ///
    /// On success, this method sets the *hasDatabaseChanges* flag to true.
    ///
    /// - parameter db: A database connection.
    /// - returns: Whether a database row was deleted.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    @discardableResult
    open func delete(_ db: Database) throws -> Bool {
        defer {
            // Future calls to update() will throw NotFound. Make the user
            // a favor and make sure this error is thrown even if she checks the
            // hasDatabaseChanges flag:
            hasDatabaseChanges = true
        }
        return try performDelete(db)
    }
}

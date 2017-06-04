// MARK: - Record

/// Record is a class that wraps a table row, or the result of any query. It is
/// designed to be subclassed.
open class Record : RowConvertible, TableMapping, Persistable {
    
    // MARK: - Initializers
    
    /// Creates a Record.
    public init() {
    }
    
    /// Creates a Record from a row.
    required public init(row: Row) {
        if row.isFetched {
            // Take care of the hasPersistentChangedValues flag.
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
    ///     class Person : Record {
    ///         override class var databaseTableName: String {
    ///             return "persons"
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
    /// See https://www.sqlite.org/lang_conflict.html
    open class var persistenceConflictPolicy: PersistenceConflictPolicy {
        return PersistenceConflictPolicy(insert: .abort, update: .abort)
    }
    
    /// This flag tells whether the hidden "rowid" column should be fetched
    /// with other columns.
    ///
    /// Its default value is false:
    ///
    ///     // SELECT * FROM persons
    ///     try Person.fetchAll(db)
    ///
    /// When true, the rowid column is fetched:
    ///
    ///     // SELECT *, rowid FROM persons
    ///     try Person.fetchAll(db)
    open class var selectsRowID: Bool {
        return false
    }
    

    /// Defines the values persisted in the database.
    ///
    /// Store in the *container* argument all values that should be stored in
    /// the columns of the database table (see Record.databaseTableName()).
    ///
    /// Primary key columns, if any, must be included.
    ///
    ///     class Person : Record {
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
    
    /// Notifies the record that it was succesfully inserted.
    ///
    /// Do not call this method directly: it is called for you, in a protected
    /// dispatch queue, with the inserted RowID and the eventual
    /// INTEGER PRIMARY KEY column name.
    ///
    /// The implementation of the base Record class does nothing.
    ///
    ///     class Person : Record {
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
    /// `hasPersistentChangedValues` flag.
    ///
    /// - returns: A copy of self.
    open func copy() -> Self {
        let row: Row
        #if swift(>=3.1)
            row = Row(self)
        #else
            // workaround weird Swift 3.0 glitch
            row = Row(self as! MutablePersistable)
        #endif
        let copy = type(of: self).init(row: row)
        copy.referenceRow = referenceRow
        return copy
    }
    
    
    // MARK: - Changes Tracking
    
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
    public var hasPersistentChangedValues: Bool {
        get { return makePersistentChangedValuesIterator().next() != nil }
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
    /// See `hasPersistentChangedValues` for more information.
    public var persistentChangedValues: [String: DatabaseValue?] {
        var persistentChangedValues: [String: DatabaseValue?] = [:]
        
        for (key, value) in makePersistentChangedValuesIterator() {
            persistentChangedValues[key] = value
        }
        return persistentChangedValues    
    }
    
    // A change iterator that is used by both hasPersistentChangedValues and
    // persistentChangedValues properties.
    private func makePersistentChangedValuesIterator() -> AnyIterator<(column: String, old: DatabaseValue?)> {
        let oldRow = referenceRow
        var newValueIterator = PersistenceContainer(self).makeIterator()
        return AnyIterator {
            // Loop until we find a change, or exhaust columns:
            while let (column, newValue) = newValueIterator.next() {
                let new = newValue?.databaseValue ?? .null
                guard let oldRow = oldRow, let old: DatabaseValue = oldRow.value(named: column) else {
                    return (column: column, old: nil)
                }
                if new != old {
                    return (column: column, old: old)
                }
            }
            return nil
        }
    }
    
    
    /// Reference row for the *hasPersistentChangedValues* property.
    var referenceRow: Row?
    

    // MARK: - CRUD
    
    /// Executes an INSERT statement.
    ///
    /// On success, this method sets the *hasPersistentChangedValues* flag
    /// to false.
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
            // set hasPersistentChangedValues to false:
            if let rowIDColumn = rowIDColumn {
                persistenceContainer[caseInsensitive: rowIDColumn] = rowID
            }
        }
        
        // Set hasPersistentChangedValues to false
        referenceRow = Row(persistenceContainer)
    }
    
    /// Executes an UPDATE statement.
    ///
    /// On success, this method sets the *hasPersistentChangedValues* flag
    /// to false.
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
        //     hasPersistentChangedValues = false
        //
        // But this would trigger two calls to `encode(to:)`.
        let dao = try DAO(db, self)
        guard let statement = try dao.updateStatement(columns: columns, onConflict: type(of: self).persistenceConflictPolicy.conflictResolutionForUpdate) else {
            // Nil primary key
            throw PersistenceError.recordNotFound(self)
        }
        try statement.execute()
        if db.changesCount == 0 {
            throw PersistenceError.recordNotFound(self)
        }
        
        // Set hasPersistentChangedValues to false
        referenceRow = Row(dao.persistenceContainer)
    }
    
    /// Executes an INSERT or an UPDATE statement so that `self` is saved in
    /// the database.
    ///
    /// If the record has a non-nil primary key and a matching row in the
    /// database, this method performs an update.
    ///
    /// Otherwise, performs an insert.
    ///
    /// On success, this method sets the *hasPersistentChangedValues* flag
    /// to false.
    ///
    /// This method is guaranteed to have inserted or updated a row in the
    /// database if it returns without error.
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError whenever an SQLite error occurs, or errors
    ///   thrown by update().
    final public func save(_ db: Database) throws {
        try performSave(db)
    }
    
    /// Executes a DELETE statement.
    ///
    /// On success, this method sets the *hasPersistentChangedValues* flag
    /// to true.
    ///
    /// - parameter db: A database connection.
    /// - returns: Whether a database row was deleted.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    @discardableResult
    open func delete(_ db: Database) throws -> Bool {
        defer {
            // Future calls to update() will throw NotFound. Make the user
            // a favor and make sure this error is thrown even if she checks the
            // hasPersistentChangedValues flag:
            hasPersistentChangedValues = true
        }
        return try performDelete(db)
    }
}

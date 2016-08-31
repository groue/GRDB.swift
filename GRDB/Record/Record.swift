// MARK: - Record

/// Record is a class that wraps a table row, or the result of any query. It is
/// designed to be subclassed.
public class Record : RowConvertible, TableMapping, Persistable {
    
    // MARK: - Initializers
    
    /// Initializes a Record.
    ///
    /// The returned record is *edited*.
    public init() {
    }
    
    /// Initializes a Record from a row.
    ///
    /// The returned record is *edited*.
    ///
    /// The input row may not come straight from the database. When you want to
    /// complete your initialization after being fetched, override
    /// awakeFromFetch(row:).
    required public init(_ row: Row) {
    }
    
    /// Do not call this method directly.
    ///
    /// This method is called in an arbitrary dispatch queue, after a record
    /// has been fetched from the database.
    ///
    /// Record subclasses have an opportunity to complete their initialization.
    ///
    /// *Important*: subclasses must invoke super's implementation.
    public func awakeFromFetch(row row: Row) {
        // Take care of the hasPersistentChangedValues flag. If the row does not
        /// contain all needed columns, the record turns edited.
        //
        // Row may be a metal row which will turn invalid as soon as the SQLite
        // statement is iterated. We need to store an immutable and safe copy.
        referenceRow = row.copy()
    }
    
    
    // MARK: - Core methods
    
    /// Returns the name of a database table.
    ///
    /// This table name is required by the insert, update, save, delete,
    /// and exists methods.
    ///
    ///     class Person : Record {
    ///         override class func databaseTableName() -> String {
    ///             return "persons"
    ///         }
    ///     }
    ///
    /// The implementation of the base class Record raises a fatal error.
    ///
    /// - returns: The name of a database table.
    public class func databaseTableName() -> String {
        fatalError("subclass must override")
    }
    
    /// Returns the values that should be stored in the database.
    ///
    /// Keys of the returned dictionary must match the column names of the
    /// target database table (see Record.databaseTableName()).
    ///
    /// In particular, primary key columns, if any, must be included.
    ///
    ///     class Person : Record {
    ///         var id: Int64?
    ///         var name: String?
    ///
    ///         override var persistentDictionary: [String: DatabaseValueConvertible?] {
    ///             return ["id": id, "name": name]
    ///         }
    ///     }
    ///
    /// The implementation of the base class Record returns an empty dictionary.
    public var persistentDictionary: [String: DatabaseValueConvertible?] {
        return [:]
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
    ///         func didInsertWithRowID(rowID: Int64, forColumn column: String?) {
    ///             id = rowID
    ///         }
    ///     }
    ///
    /// - parameters:
    ///     - rowID: The inserted rowID.
    ///     - column: The name of the eventual INTEGER PRIMARY KEY column.
    public func didInsertWithRowID(rowID: Int64, forColumn column: String?) {
    }
    
    
    // MARK: - Copy
    
    /// Returns a copy of `self`, initialized from the values of
    /// persistentDictionary.
    ///
    /// Note that the eventual primary key is copied, as well as the
    /// hasPersistentChangedValues flag.
    ///
    /// - returns: A copy of self.
    @warn_unused_result
    public func copy() -> Self {
        let copy = self.dynamicType.init(Row(persistentDictionary))
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
    /// A record is *edited* if its *persistentDictionary* has been changed
    /// since last database synchronization (fetch, update, insert). Comparison
    /// is performed on *values*: setting a property to the same value does not
    /// trigger the edited flag.
    ///
    /// You can rely on the Record base class to compute this flag for you, or
    /// you may set it to true or false when you know better. Setting it to
    /// false does not prevent it from turning true on subsequent modifications
    /// of the record.
    public var hasPersistentChangedValues: Bool {
        get { return generatePersistentChangedValues().next() != nil }
        set { referenceRow = newValue ? nil : Row(persistentDictionary) }
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
        
        for (key, value) in generatePersistentChangedValues() {
            persistentChangedValues[key] = value
        }
        return persistentChangedValues    
    }
    
    // A change generator that is used by both hasPersistentChangedValues and
    // persistentChangedValues properties.
    private func generatePersistentChangedValues() -> AnyGenerator<(column: String, old: DatabaseValue?)> {
        let oldRow = referenceRow
        var newValueGenerator = persistentDictionary.generate()
        return AnyGenerator {
            // Loop until we find a change, or exhaust columns:
            while let (column, newValue) = newValueGenerator.next() {
                let new = newValue?.databaseValue ?? .Null
                guard let old = oldRow?.databaseValue(named: column) else {
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
    public func insert(db: Database) throws {
        // The simplest code would be:
        //
        //     try performInsert(db)
        //     hasPersistentChangedValues = false
        //
        // But this triggers two calls to persistentDictionary, and this is both
        // costly, and ambiguous. Costly because persistentDictionary is slow.
        // Ambiguous because persistentDictionary may return a different value.
        //
        // So let's provide our custom implementation of insert, which uses the
        // same persistentDictionary for both insertion, and change tracking.
        
        let dao = DAO(db, self)
        var persistentDictionary = dao.persistentDictionary
        try dao.insertStatement().execute()
        let rowID = db.lastInsertedRowID
        let rowIDColumn = dao.primaryKey?.rowIDColumn
        didInsertWithRowID(rowID, forColumn: rowIDColumn)
        
        // Update persistentDictionary with inserted id, so that we can
        // set hasPersistentChangedValues to false:
        if let rowIDColumn = rowIDColumn {
            if persistentDictionary[rowIDColumn] != nil {
                persistentDictionary[rowIDColumn] = rowID
            } else {
                let rowIDColumn = rowIDColumn.lowercaseString
                for column in persistentDictionary.keys where column.lowercaseString == rowIDColumn {
                    persistentDictionary[column] = rowID
                    break
                }
            }
        }
        
        // Set hasPersistentChangedValues to false
        referenceRow = Row(persistentDictionary)
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
    ///   PersistenceError.NotFound is thrown if the primary key does not
    ///   match any row in the database.
    public func update(db: Database, columns: Set<String>) throws {
        // The simplest code would be:
        //
        //     try performUpdate(db, columns: columns)
        //     hasPersistentChangedValues = false
        //
        // But this triggers two calls to persistentDictionary, and this is both
        // costly, and ambiguous. Costly because persistentDictionary is slow.
        // Ambiguous because persistentDictionary may return a different value.
        //
        // So let's provide our custom implementation of insert, which uses the
        // same persistentDictionary for both update, and change tracking.
        let dao = DAO(db, self)
        guard let statement = dao.updateStatement(columns: columns) else {
            // Nil primary key
            throw PersistenceError.NotFound(self)
        }
        try statement.execute()
        if db.changesCount == 0 {
            throw PersistenceError.NotFound(self)
        }
        
        // Set hasPersistentChangedValues to false
        referenceRow = Row(dao.persistentDictionary)
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
    final public func save(db: Database) throws {
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
    public func delete(db: Database) throws -> Bool {
        defer {
            // Future calls to update() will throw NotFound. Make the user
            // a favor and make sure this error is thrown even if she checks the
            // hasPersistentChangedValues flag:
            hasPersistentChangedValues = true
        }
        return try performDelete(db)
    }
}

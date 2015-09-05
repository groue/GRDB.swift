// MARK: - RowModel

/**
RowModel is a class that wraps a table row, or the result of any query. It is
designed to be subclassed.

Subclasses opt in RowModel features by overriding all or part of the core
methods that define their relationship with the database:

- updateFromRow(_)
- databaseTable
- storedDatabaseDictionary
*/
public class RowModel {
    
    /// The result of the RowModel.delete() method
    public enum DeletionResult {
        /// A row was deleted.
        case RowDeleted
        
        /// No row was deleted.
        case NoRowDeleted
    }
    
    
    // MARK: - Initializers
    
    /**
    Initializes a RowModel.
    
    The returned rowModel is *edited*.
    */
    public init() {
        // IMPLEMENTATION NOTE
        //
        // This initializer is defined so that a subclass can be defined
        // without any custom initializer.
    }
    
    /**
    Initializes a RowModel from a row.
    
    The returned rowModel is *edited*.
    
    - parameter row: A Row
    */
    required public init(row: Row) {
        // IMPLEMENTATION NOTE
        //
        // Swift requires a required initializer so that we can fetch RowModels
        // in SelectStatement.fetch<RowModel: GRDB.RowModel>(type: RowModel.Type, arguments: StatementArguments? = nil) -> AnySequence<RowModel>
        //
        // This required initializer *can not* be the simple init(), because it
        // would prevent subclasses to provide handy initializers made of
        // optional arguments like init(firstName: String? = nil, lastName: String? = nil).
        // See rdar://22554816 for more information.
        //
        // OK so the only initializer that we can require in init(row:Row).
        //
        // IMPLEMENTATION NOTE
        //
        // This initializer returns an edited model because the row may not
        // come from the database.
        
        updateFromRow(row)
    }
    
    
    // MARK: - Core methods
    
    /**
    Returns a table definition.
    
    The insert, update, save, delete and reload methods require it: they raise
    a fatal error if databaseTableName is nil.
    
    The implementation of the base class RowModel returns nil.
    */
    public class func databaseTableName() -> String? {
        return nil
    }
    
    /**
    Returns the values that should be stored in the database.
    
    Subclasses must include primary key columns, if any, in the returned
    dictionary.
    
    The implementation of the base class RowModel returns an empty dictionary.
    */
    public var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return [:]
    }
    
    /**
    Updates self from a row.
    
    *Important*: subclasses must invoke super's implementation.
    */
    public func updateFromRow(row: Row) {
    }
    
    
    // MARK: - Events
    
    /**
    Called after a RowModel has been fetched or reloaded.
    
    *Important*: subclasses must invoke super's implementation.
    */
    public func didFetch() {
    }
    
    
    // MARK: - Copy
    
    /**
    Updates `self` from `other.storedDatabaseDictionary`.
    */
    public func copyDatabaseValuesFrom(other: RowModel) {
        updateFromRow(Row(dictionary: other.storedDatabaseDictionary))
    }
    
    
    // MARK: - Changes
    
    /**
    A boolean that indicates whether the row model has changes that have not
    been saved.
    
    This flag is purely informative, and does not prevent insert(), update(),
    save() and reload() to perform their database queries. Yet you can prevent
    queries that are known to be pointless, as in the following example:
        
        let json = ...
    
        // Fetches or create a new person given its ID:
        let person = Person.fetchOne(db, primaryKey: json["id"]) ?? Person()
    
        // Apply json payload:
        person.updateFromJSON(json)
                 
        // Saves the person if it is edited (fetched then modified, or created):
        if person.databaseEdited {
            person.save(db) // inserts or updates
        }
    
    Precisely speaking, a row model is edited if its *storedDatabaseDictionary*
    has been changed since last database synchronization (fetch, update,
    insert). Comparison is performed on *values*: setting a property to the same
    value does not trigger the edited flag.
    
    You can rely on the RowModel base class to compute this flag for you, or you
    may set it to true or false when you know better. Setting it to false does
    not prevent it from turning true on subsequent modifications of the row model.
    */
    public var databaseEdited: Bool {
        get {
            guard let referenceRow = referenceRow else {
                // No reference row => edited
                return true
            }
            
            // All stored database values must match reference database values
            for (column, storedValue) in storedDatabaseDictionary {
                guard let referenceDatabaseValue = referenceRow[column] else {
                    return true
                }
                let storedDatabaseValue = storedValue?.databaseValue ?? .Null
                if storedDatabaseValue != referenceDatabaseValue {
                    return true
                }
            }
            return false
        }
        set {
            if newValue {
                referenceRow = nil
            } else {
                referenceRow = Row(dictionary: storedDatabaseDictionary)
            }
        }
    }
    
    /// Reference row for the *databaseEdited* property.
    var referenceRow: Row?
    

    // MARK: - CRUD
    
    /**
    Executes an INSERT statement to insert the row model.
    
    On success, this method sets the *databaseEdited* flag to false.
    
    This method is guaranteed to have inserted a row in the database if it
    returns without error.
    
    - parameter db: A Database.
    - throws: A DatabaseError whenever a SQLite error occurs.
    */
    public func insert(db: Database) throws {
        let dataMapper = DataMapper(db, self)
        let changes = try dataMapper.insertStatement().execute()
        
        // Update RowID column if needed
        if case .Managed(let managedColumn) = dataMapper.primaryKey {
            guard let rowID = dataMapper.storedDatabaseDictionary[managedColumn] else {
                fatalError("\(self.dynamicType).storedDatabaseDictionary must return the value for the primary key `(managedColumn)`")
            }
            if rowID == nil {
                updateFromRow(Row(dictionary: [managedColumn: changes.insertedRowID]))
            }
        }
        
        databaseEdited = false
    }
    
    /**
    Executes an UPDATE statement to update the row model.
    
    On success, this method sets the *databaseEdited* flag to false.
    
    This method is guaranteed to have updated a row in the database if it
    returns without error.
    
    - parameter db: A Database.
    - throws: A DatabaseError is thrown whenever a SQLite error occurs.
              RowModelError.RowModelNotFound is thrown if the primary key does
              not match any row in the database and row model could not be
              updated.
    */
    public func update(db: Database) throws {
        // We'll throw RowModelError.RowModelNotFound if rowModel does not exist.
        let exists: Bool
        
        if let statement = try DataMapper(db, self).updateStatement() {
            let changes = try statement.execute()
            exists = changes.changedRowCount > 0
        } else {
            // No statement means that there is no column to update.
            //
            // I remember opening rdar://problem/10236982 because CoreData
            // was crashing with entities without any attribute. So let's
            // accept RowModel that don't have any column to update.
            exists = self.exists(db)
        }
        
        if !exists {
            throw RowModelError.RowModelNotFound(self)
        }
        
        databaseEdited = false
    }
    
    /**
    Saves the row model in the database.
    
    If the row model has a non-nil primary key and a matching row in the
    database, this method performs an update.
    
    Otherwise, performs an insert.
    
    On success, this method sets the *databaseEdited* flag to false.
    
    This method is guaranteed to have inserted or updated a row in the database
    if it returns without error.
    
    - parameter db: A Database.
    - throws: A DatabaseError whenever a SQLite error occurs, or errors thrown
              by update().
    */
    final public func save(db: Database) throws {
        // Make sure we call self.insert and self.update so that classes that
        // override insert or save have opportunity to perform their custom job.
        
        if DataMapper(db, self).resolvingPrimaryKeyDictionary == nil {
            return try insert(db)
        }
        
        do {
            try update(db)
        } catch RowModelError.RowModelNotFound {
            return try insert(db)
        }
    }
    
    /**
    Executes a DELETE statement to delete the row model.
    
    On success, this method sets the *databaseEdited* flag to true.
    
    - parameter db: A Database.
    - returns: Whether a row was deleted or not.
    - throws: A DatabaseError is thrown whenever a SQLite error occurs.
    */
    public func delete(db: Database) throws -> DeletionResult {
        let changes = try DataMapper(db, self).deleteStatement().execute()
        
        // Future calls to update will throw RowModelNotFound. Make the user
        // a favor and make sure this error is thrown even if she checks the
        // databaseEdited flag:
        databaseEdited = true
        
        if changes.changedRowCount > 0 {
            return .RowDeleted
        } else {
            return .NoRowDeleted
        }
    }
    
    /**
    Executes a SELECT statetement to reload the row model.
    
    On success, this method sets the *databaseEdited* flag to false.
    
    - parameter db: A Database.
    - throws: RowModelError.RowModelNotFound is thrown if the primary key does
              not match any row in the database and row model could not be
              reloaded.
    */
    final public func reload(db: Database) throws {
        let statement = DataMapper(db, self).reloadStatement()
        if let row = Row.fetchOne(statement) {
            updateFromRow(row)
            referenceRow = row
            didFetch()
        } else {
            throw RowModelError.RowModelNotFound(self)
        }
    }
    
    /**
    Returns true if and only if the primary key matches a row in the database.
    
    - parameter db: A Database.
    - returns: Whether the primary key matches a row in the database.
    */
    final public func exists(db: Database) -> Bool {
        return (Row.fetchOne(DataMapper(db, self).existsStatement()) != nil)
    }
}


// MARK: - RowConvertible, DatabaseTableMapping

/// RowModel adopts RowConvertible, DatabaseTableMapping and DatabaseStorable.
extension RowModel: RowConvertible, DatabaseTableMapping, DatabaseStorable {
    public func awakeFromFetchedRow(row: Row) {
        referenceRow = row
        didFetch()
    }
}


// MARK: - CustomStringConvertible

/// RowModel adopts CustomStringConvertible.
extension RowModel : CustomStringConvertible {
    /// A textual representation of `self`.
    public var description: String {
        return "<\(self.dynamicType)"
            + storedDatabaseDictionary.map { (key, value) in
                if let value = value {
                    return " \(key):\(String(reflecting: value))"
                } else {
                    return " \(key):nil"
                }
                }.joinWithSeparator("")
            + ">"
    }
}


// MARK: - RowModelError

/// A RowModel-specific error
public enum RowModelError: ErrorType {
    
    /// No matching row could be found in the database.
    case RowModelNotFound(RowModel)
}

extension RowModelError : CustomStringConvertible {
    /// A textual representation of `self`.
    public var description: String {
        switch self {
        case .RowModelNotFound(let rowModel):
            return "RowModel not found: \(rowModel)"
        }
    }
}

//
// GRDB.swift
// https://github.com/groue/GRDB.swift
// Copyright (c) 2015 Gwendal Roué
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.


// MARK: - RowModel

/**
RowModel is a class that wraps a table row, or the result of any query. It is
designed to be subclassed.

Subclasses opt in RowModel features by overriding all or part of the core
methods that define their relationship with the database:

- setDatabaseValue(_:forColumn:)
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
    
    /// A primary key. See RowModel.databaseTable and Table type.
    public enum PrimaryKey {
        
        /// A primary key managed by SQLite. Associated string is a column name.
        case RowID(String)
        
        /// A primary key not managed by SQLite. Associated string is a column name.
        case Column(String)
        
        /// A primary key that spans accross several columns. Associated strings
        /// are column names.
        case Columns([String])
    }
    
    /// A table definition returned by RowModel.databaseTable.
    public struct Table {
        
        /// The table name
        public let name: String
        
        /// The eventual primary key
        public let primaryKey: PrimaryKey?
        
        /// Creates a Table given its name and primary key (default nil, meaning
        /// that the table has no primary key.
        public init(named name: String, primaryKey: PrimaryKey? = nil) {
            self.name = name
            self.primaryKey = primaryKey
        }
    }
    
    
    // MARK: - Core methods
    
    /**
    Returns a table definition.
    
    The insert, update, save, delete and reload methods require it: they raise
    a fatal error if databaseTable is nil.
    
    The implementation of the base class RowModel returns nil.
    */
    public class var databaseTable: Table? {
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
    Updates `self` with a database value.
    
    The implementation of the base class RowModel does nothing.
    
    - parameter dbv: A DatabaseValue.
    - parameter column: A column name.
    */
    public func setDatabaseValue(dbv: DatabaseValue, forColumn column: String) {
    }
    
    
    // MARK: - Initializers
    
    /**
    Initializes a RowModel.
    
    This initializer is not used for fetched models (see `init(row:)`).
    
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
    
    This initializer is used for all fetched models.
    
    The returned rowModel is *edited*. Fetched models are post-processed so that
    their *edited* flag is false when the row contains enough columns.
    
    - parameter row: A Row
    */
    required public init(row: Row) {
        // IMPLEMENTATION NOTE
        //
        // This initializer is defined so that subclasses can distinguish
        // the simple init() from init(row: Row), and perform distinct
        // initialization for fetched models.
        
        for (column, databaseValue) in row {
            setDatabaseValue(databaseValue, forColumn: column)
        }
    }
    
    
    // MARK: - Copy
    
    /**
    Updates `self` with another row model by repeatedly calling the
    `setDatabaseValue(_:forColumn:)` with all values from
    `other.storedDatabaseDictionary`.
    */
    public func copyDatabaseValuesFrom(other: RowModel) {
        for (column, value) in other.storedDatabaseDictionary {
            setDatabaseValue(value?.databaseValue ?? .Null, forColumn: column)
        }
        
        // Primary key may have been updated: row model may be edited.
        edited = true
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
        let person = db.fetchOne(Person.self, primaryKey: json["id"]) ?? Person()
    
        // Apply json payload:
        person.updateFromJSON(json)
                 
        // Saves the person if it is edited (fetched then modified, or created):
        if person.edited {
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
    public var edited: Bool {
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
    
    /// Reference row for the *edited* property.
    private var referenceRow: Row?
    

    // MARK: - CRUD
    
    /**
    Executes an INSERT statement to insert the row model.
    
    On successful insert, this method sets the *edited* flag to false.
    
    This method is guaranteed to have inserted a row in the database if it
    returns without error.
    
    - parameter db: A Database.
    - throws: A DatabaseError whenever a SQLite error occurs.
    */
    public func insert(db: Database) throws {
        let dataMapper = DataMapper(self)
        let changes = try dataMapper.insertStatement(db).execute()
        
        // Update RowID column if needed
        if let primaryKey = self.dynamicType.databaseTable?.primaryKey, case .RowID(let rowIDColumn) = primaryKey {
            guard let rowID = dataMapper.storedDatabaseDictionary[rowIDColumn] else {
                fatalError("\(self.dynamicType).storedDatabaseDictionary must return the value for the primary key `(rowIDColumn)`")
            }
            if rowID == nil {
                setDatabaseValue(DatabaseValue.Integer(changes.insertedRowID!), forColumn: rowIDColumn)
            }
        }
        
        edited = false
    }
    
    /**
    Executes an UPDATE statement to update the row model.
    
    On successful update, this method sets the *edited* flag to false.
    
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
        
        if let statement = try DataMapper(self).updateStatement(db) {
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
        
        edited = false
    }
    
    /**
    Saves the row model in the database.
    
    If the row model has a non-nil primary key and a matching row in the
    database, this method performs an update.
    
    Otherwise, performs an insert.
    
    On successful saving, this method sets the *edited* flag to false.
    
    This method is guaranteed to have inserted or updated a row in the database
    if it returns without error.
    
    - parameter db: A Database.
    - throws: A DatabaseError whenever a SQLite error occurs, or errors thrown
              by update().
    */
    final public func save(db: Database) throws {
        // Make sure we call self.insert and self.update so that classes that
        // override insert or save have opportunity to perform their custom job.
        
        if DataMapper(self).strongPrimaryKeyDictionary == nil {
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
    
    On successful deletion, this method sets the *edited* flag to true.
    
    - parameter db: A Database.
    - returns: Whether a row was deleted or not.
    - throws: A DatabaseError is thrown whenever a SQLite error occurs.
    */
    public func delete(db: Database) throws -> DeletionResult {
        let changes = try DataMapper(self).deleteStatement(db).execute()
        
        // Future calls to update will throw RowModelNotFound. Make the user
        // a favor and make sure this error is thrown even if she checks the
        // edited flag:
        edited = true
        
        if changes.changedRowCount > 0 {
            return .RowDeleted
        } else {
            return .NoRowDeleted
        }
    }
    
    /**
    Executes a SELECT statetement to reload the row model.
    
    On successful reloading, this method sets the *edited* flag to false.
    
    - parameter db: A Database.
    - throws: RowModelError.RowModelNotFound is thrown if the primary key does
              not match any row in the database and row model could not be
              reloaded.
    */
    public func reload(db: Database) throws {
        let statement = DataMapper(self).reloadStatement(db)
        if let row = statement.fetchOneRow() {
            for (column, databaseValue) in row {
                setDatabaseValue(databaseValue, forColumn: column)
            }
            referenceRow = row
        } else {
            throw RowModelError.RowModelNotFound(self)
        }
    }
    
    /**
    Returns true if and only if the primary key matches a row in the database.
    
    - parameter db: A Database.
    - returns: Whether the primary key matches a row in the database.
    */
    public func exists(db: Database) -> Bool {
        return (DataMapper(self).existsStatement(db).fetchOneRow() != nil)
    }
    
    
    // MARK: - DataMapper
    
    /// DataMapper takes care of RowModel CRUD
    private final class DataMapper {
        
        /// The rowModel type
        let rowModel: RowModelType
        
        /// DataMapper keeps a copy the rowModel's storedDatabaseDictionary, so
        /// that this dictionary is built once whatever the database operation.
        /// It is guaranteed to have at least one (key, value) pair.
        let storedDatabaseDictionary: [String: DatabaseValueConvertible?]
        
        /// The table definition
        let databaseTable: RowModel.Table
        
        
        // MARK: - Primary Key
        
        /**
        A dictionary of primary key columns that may or not identify a row in
        the database because its values may all be nil. Hence its "weak" name.
        
        It is nil when rowModel has no primary key. Its values come from the
        storedDatabaseDictionary.
        */
        lazy var weakPrimaryKeyDictionary: [String: DatabaseValueConvertible?]? = { [unowned self] in
            guard let primaryKey = self.databaseTable.primaryKey else {
                return nil
            }
            switch primaryKey {
            case .RowID(let column):
                if let value = self.storedDatabaseDictionary[column] {
                    return [column: value]
                } else {
                    return [column: nil]
                }
                
            case .Column(let column):
                if let value = self.storedDatabaseDictionary[column] {
                    return [column: value]
                } else {
                    return [column: nil]
                }
                
            case .Columns(let columns):
                let storedDatabaseDictionary = self.storedDatabaseDictionary
                var primaryKeyDictionary = [String: DatabaseValueConvertible?]()
                for column in columns {
                    if let value = storedDatabaseDictionary[column] {
                        primaryKeyDictionary[column] = value
                    } else {
                        primaryKeyDictionary[column] = nil
                    }
                }
                return primaryKeyDictionary
            }
            }()
        
        /**
        A dictionary of primary key columns that surely identifies a row in the
        database because not all its values are nil. Hence its "strong" name.
        
        It is nil when the weakPrimaryKey is nil or only contains nil values.
        */
        lazy var strongPrimaryKeyDictionary: [String: DatabaseValueConvertible?]? = { [unowned self] in
            guard let dictionary = self.weakPrimaryKeyDictionary else {
                return nil
            }
            for case let value? in dictionary.values {
                return dictionary // At least one non-nil value in the primary key dictionary is OK.
            }
            return nil
            }()
        
        
        // MARK: - Initializer
        
        init(_ rowModel: RowModelType) {
            // Fail early if databaseTable is nil (not overriden)
            guard let databaseTable = rowModel.dynamicType.databaseTable else {
                fatalError("Nil Table returned from \(rowModel.dynamicType).databaseTable")
            }
            
            // Fail early if storedDatabaseDictionary is empty (not overriden)
            let storedDatabaseDictionary = rowModel.storedDatabaseDictionary
            guard storedDatabaseDictionary.count > 0 else {
                fatalError("Invalid empty dictionary returned from \(rowModel.dynamicType).storedDatabaseDictionary")
            }
            
            self.rowModel = rowModel
            self.storedDatabaseDictionary = storedDatabaseDictionary
            self.databaseTable = databaseTable
        }
        
        
        // MARK: - CRUD
        
        /// INSERT
        func insertStatement(db: Database) throws -> UpdateStatement {
            // INSERT
            let insertStatement = try DataMapper.insertStatement(db, tableName: databaseTable.name, insertedColumns: Array(storedDatabaseDictionary.keys))
            insertStatement.arguments = QueryArguments(storedDatabaseDictionary.values)
            return insertStatement
        }
        
        /// UPDATE. Returns nil if there is no column to update
        func updateStatement(db: Database) throws -> UpdateStatement? {
            guard let primaryKeyDictionary = strongPrimaryKeyDictionary else {
                fatalError("Invalid primary key in \(rowModel)")
            }
            
            // Don't update primary key columns
            var updatedDictionary = storedDatabaseDictionary
            for column in primaryKeyDictionary.keys {
                updatedDictionary.removeValueForKey(column)
            }
            
            // We need something to update.
            guard updatedDictionary.count > 0 else {
                return nil
            }
            
            // Update
            let updateStatement = try DataMapper.updateStatement(db, tableName: databaseTable.name, updatedColumns: Array(updatedDictionary.keys), conditionColumns: Array(primaryKeyDictionary.keys))
            updateStatement.arguments = QueryArguments(Array(updatedDictionary.values) + Array(primaryKeyDictionary.values))
            return updateStatement
        }
        
        /// DELETE
        func deleteStatement(db: Database) throws -> UpdateStatement {
            guard let primaryKeyDictionary = strongPrimaryKeyDictionary else {
                fatalError("Invalid primary key in \(rowModel)")
            }
            
            // Delete
            let deleteStatement = try DataMapper.deleteStatement(db, tableName: databaseTable.name, conditionColumns: Array(primaryKeyDictionary.keys))
            deleteStatement.arguments = QueryArguments(primaryKeyDictionary.values)
            return deleteStatement
        }
        
        /// SELECT
        func reloadStatement(db: Database) -> SelectStatement {
            guard let primaryKeyDictionary = strongPrimaryKeyDictionary else {
                fatalError("Invalid primary key in \(rowModel)")
            }
            
            // Fetch
            let selectStatement = DataMapper.selectStatement(db, tableName: databaseTable.name, conditionColumns: Array(primaryKeyDictionary.keys))
            selectStatement.arguments = QueryArguments(primaryKeyDictionary.values)
            return selectStatement
        }
        
        /// SELECT statement that returns a row if and only if the primary key
        /// matchs a row in the database.
        func existsStatement(db: Database) -> SelectStatement {
            guard let primaryKeyDictionary = strongPrimaryKeyDictionary else {
                fatalError("Invalid primary key in \(rowModel)")
            }
            
            // Fetch
            let existsStatement = DataMapper.existsStatement(db, tableName: databaseTable.name, conditionColumns: Array(primaryKeyDictionary.keys))
            existsStatement.arguments = QueryArguments(primaryKeyDictionary.values)
            return existsStatement
        }
        
        
        // MARK: - SQL statements
        
        private class func insertStatement(db: Database, tableName: String, insertedColumns: [String]) throws -> UpdateStatement {
            // INSERT INTO table (id, name) VALUES (?, ?)
            let columnSQL = ",".join(insertedColumns.map { $0.quotedDatabaseIdentifier })
            let valuesSQL = ",".join([String](count: insertedColumns.count, repeatedValue: "?"))
            let sql = "INSERT INTO \(tableName.quotedDatabaseIdentifier) (\(columnSQL)) VALUES (\(valuesSQL))"
            return try db.updateStatement(sql)
        }
        
        private class func updateStatement(db: Database, tableName: String, updatedColumns: [String], conditionColumns: [String]) throws -> UpdateStatement {
            // "UPDATE table SET name = ? WHERE id = ?"
            let updateSQL = ",".join(updatedColumns.map { "\($0.quotedDatabaseIdentifier)=?" })
            let conditionSQL = " AND ".join(conditionColumns.map { "\($0.quotedDatabaseIdentifier)=?" })
            let sql = "UPDATE \(tableName.quotedDatabaseIdentifier) SET \(updateSQL) WHERE \(conditionSQL)"
            return try db.updateStatement(sql)
        }
        
        private class func deleteStatement(db: Database, tableName: String, conditionColumns: [String]) throws -> UpdateStatement {
            // "DELETE FROM table WHERE id = ?"
            let conditionSQL = " AND ".join(conditionColumns.map { "\($0.quotedDatabaseIdentifier)=?" })
            let sql = "DELETE FROM \(tableName.quotedDatabaseIdentifier) WHERE \(conditionSQL)"
            return try db.updateStatement(sql)
        }
        
        private class func existsStatement(db: Database, tableName: String, conditionColumns: [String]) -> SelectStatement {
            // "SELECT 1 FROM table WHERE id = ?"
            let conditionSQL = " AND ".join(conditionColumns.map { "\($0.quotedDatabaseIdentifier)=?" })
            let sql = "SELECT 1 FROM \(tableName.quotedDatabaseIdentifier) WHERE \(conditionSQL)"
            return db.selectStatement(sql)
        }

        private class func selectStatement(db: Database, tableName: String, conditionColumns: [String]) -> SelectStatement {
            // "SELECT * FROM table WHERE id = ?"
            let conditionSQL = " AND ".join(conditionColumns.map { "\($0.quotedDatabaseIdentifier)=?" })
            let sql = "SELECT * FROM \(tableName.quotedDatabaseIdentifier) WHERE \(conditionSQL)"
            return db.selectStatement(sql)
        }
    }
}


// MARK: - RowModelType

/// An immutable view to RowModel
protocol RowModelType {
    static var databaseTable: RowModel.Table? { get }
    var storedDatabaseDictionary: [String: DatabaseValueConvertible?] { get }
}

extension RowModel : RowModelType { }


// MARK: - CustomStringConvertible

extension RowModel : CustomStringConvertible {
    /// A textual representation of `self`.
    public var description: String {
        return "<\(self.dynamicType)" + "".join(storedDatabaseDictionary.map { (key, value) in
            if let value = value {
                return " \(key):\(String(reflecting: value))"
            } else {
                return " \(key):nil"
            }}) + ">"
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


// MARK: - Fetching Row Models

/**
The Database methods that fetch RowModels.
*/
extension Database {
    
    /**
    Fetches a lazy sequence of RowModels.

        let persons = db.fetch(Person.self, "SELECT * FROM persons")

    - parameter type:     The type of fetched row models. It must be a subclass
                          of RowModel.
    - parameter sql:      An SQL query.
    - parameter arguments: Optional query arguments.
    
    - returns: A lazy sequence of row models.
    */
    public func fetch<RowModel: GRDB.RowModel>(type: RowModel.Type, _ sql: String, arguments: QueryArguments? = nil) -> AnySequence<RowModel> {
        return selectStatement(sql).fetch(type, arguments: arguments)
    }

    /**
    Fetches an array sequence of RowModels.

        let persons = db.fetchAll(Person.self, "SELECT * FROM persons")

    - parameter type:     The type of fetched row models. It must be a subclass
                          of RowModel.
    - parameter sql:      An SQL query.
    - parameter arguments: Optional query arguments.
    
    - returns: An array of row models.
    */
    public func fetchAll<RowModel: GRDB.RowModel>(type: RowModel.Type, _ sql: String, arguments: QueryArguments? = nil) -> [RowModel] {
        return Array(fetch(type, sql, arguments: arguments))
    }

    /**
    Fetches a single RowModel.

        let person = db.fetchOne(Person.self, "SELECT * FROM persons")

    - parameter type:     The type of fetched row model. It must be a subclass
                          of RowModel.
    - parameter sql:      An SQL query.
    - parameter arguments: Optional query arguments.
    
    - returns: An optional row model.
    */
    public func fetchOne<RowModel: GRDB.RowModel>(type: RowModel.Type, _ sql: String, arguments: QueryArguments? = nil) -> RowModel? {
        if let first = fetch(type, sql, arguments: arguments).generate().next() {
            // one row containing an optional value
            return first
        } else {
            // no row
            return nil
        }
    }

    /**
    Fetches a single RowModel by primary key.

        let person = db.fetchOne(Person.self, primaryKey: 123)

    - parameter type:       The type of fetched row model. It must be a subclass
                            of RowModel.
    - parameter primaryKey: A value.
    - returns: An optional row model.
    */
    public func fetchOne<RowModel: GRDB.RowModel>(type: RowModel.Type, primaryKey: DatabaseValueConvertible?) -> RowModel? {
        guard let primaryKey = primaryKey else {
            return nil
        }
        
        // Select methods crash when there is an issue
        guard let table = type.databaseTable else {
            fatalError("Nil Table returned from \(type).databaseTable")
        }
        
        guard let tablePrimaryKey = table.primaryKey else {
            fatalError("Nil Primary Key in \(type).databaseTable")
        }
        
        let sql: String
        switch tablePrimaryKey {
        case .RowID(let column):
            sql = "SELECT * FROM \(table.name.quotedDatabaseIdentifier) WHERE \(column.quotedDatabaseIdentifier) = ?"
        case .Column(let column):
            sql = "SELECT * FROM \(table.name.quotedDatabaseIdentifier) WHERE \(column.quotedDatabaseIdentifier) = ?"
        case .Columns(let columns):
            guard columns.count == 1 else {
                fatalError("Primary key columns count mismatch in \(type).databaseTable")
            }
            sql = "SELECT * FROM \(table.name.quotedDatabaseIdentifier) WHERE \(columns.first!.quotedDatabaseIdentifier) = ?"
        }
        
        return selectStatement(sql).fetchOne(type, arguments: [primaryKey])
    }
    
    /**
    Fetches a single RowModel given a key.

        let person = db.fetchOne(Person.self, key: ["name": Arthur"])

    - parameter type: The type of fetched row model. It must be a subclass of
                      RowModel.
    - parameter key:  A dictionary of values.
    - returns: An optional row model.
    */
    public func fetchOne<RowModel: GRDB.RowModel>(type: RowModel.Type, key dictionary: [String: DatabaseValueConvertible?]?) -> RowModel? {
        guard let dictionary = dictionary else {
            return nil
        }
        
        // Select methods crash when there is an issue
        guard let table = type.databaseTable else {
            fatalError("Nil Table returned from \(type).databaseTable")
        }
        
        let whereSQL = " AND ".join(dictionary.keys.map { column in "\(column.quotedDatabaseIdentifier)=?" })
        let sql = "SELECT * FROM \(table.name.quotedDatabaseIdentifier) WHERE \(whereSQL)"
        return selectStatement(sql).fetchOne(type, arguments: QueryArguments(dictionary.values))
    }
}


/**
The SelectStatement methods that fetch RowModels.
*/
extension SelectStatement {
    
    /**
    Fetches a lazy sequence of RowModels.
        
        let statement = db.selectStatement("SELECT * FROM persons")
        let persons = statement.fetch(Person.self)

    - parameter type:     The type of fetched row models. It must be a subclass
                          of RowModel.
    - parameter arguments: Optional query arguments.
    
    - returns: A lazy sequence of row models.
    */
    public func fetch<RowModel: GRDB.RowModel>(type: RowModel.Type, arguments: QueryArguments? = nil) -> AnySequence<RowModel> {
        let rowSequence = fetchRows(arguments: arguments)
        return AnySequence { () -> AnyGenerator<RowModel> in
            let rowGenerator = rowSequence.generate()
            return anyGenerator { () -> RowModel? in
                guard let row = rowGenerator.next() else {
                    return nil
                }
                
                // Build rowModel
                let rowModel = RowModel.init(row: row)
                
                // RowModel is not edited, unless the row misses columns present
                // in storedDatabaseDictionary.
                rowModel.referenceRow = row
                
                return rowModel
            }
        }
    }
    
    /**
    Fetches an array of RowModels.
        
        let statement = db.selectStatement("SELECT * FROM persons")
        let persons = statement.fetchAll(Person.self)

    - parameter type:     The type of fetched row models. It must be a subclass
                          of RowModel.
    - parameter arguments: Optional query arguments.
    
    - returns: An array of row models.
    */
    public func fetchAll<RowModel: GRDB.RowModel>(type: RowModel.Type, arguments: QueryArguments? = nil) -> [RowModel] {
        return Array(fetch(type, arguments: arguments))
    }
    
    /**
    Fetches a single RowModel.
        
        let statement = db.selectStatement("SELECT * FROM persons")
        let persons = statement.fetchOne(Person.self)

    - parameter type:     The type of fetched row models. It must be a subclass
                          of RowModel.
    - parameter arguments: Optional query arguments.
    
    - returns: An optional row model.
    */
    public func fetchOne<RowModel: GRDB.RowModel>(type: RowModel.Type, arguments: QueryArguments? = nil) -> RowModel? {
        if let first = fetch(type, arguments: arguments).generate().next() {
            // one row containing an optional value
            return first
        } else {
            // no row
            return nil
        }
    }
}


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
    
    /// A primary key.
    public enum PrimaryKey {
        
        /// A primary key managed by SQLite.
        case RowID(String)
        
        /// A primary key not managed by SQLite.
        case Column(String)
        
        /// A primary key that spans accross several columns.
        case Columns([String])
    }
    
    /// A table definition.
    public struct Table {
        
        /// The table name
        public let name: String
        
        /// The primary key
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
    Returns an optional table definition.
    
    This definition is required by the insert, update, save, delete and reload
    methods: they throw RowModelError.UnspecifiedTable if databaseTable is nil.
    
    The implementation of the base class RowModel returns nil.
    */
    public class var databaseTable: Table? {
        return nil
    }
    
    /**
    Returns the values that should be stored in the database.
    
    Subclasses that define a primary key must include that column(s) in the
    returned dictionary.
    
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
    
    The returned RowModel is flagged as *edited*.
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
    
    The returned RowModel is flagged as *not edited* if and only if the row
    contains all columns of storedDatabaseDictionary.
    
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
        
        // For isEdited
        referenceRow = row
    }
    
    
    // MARK: - Copy
    
    /**
    Updates `self` with another row model.
    */
    public func copyDatabaseValuesFrom(other: RowModel) {
        for (column, value) in other.storedDatabaseDictionary {
            if let value = value {
                setDatabaseValue(value.databaseValue, forColumn: column)
            } else {
                setDatabaseValue(.Null, forColumn: column)
            }
        }
        
        // Primary key may have been updated: row model may be edited.
        setEdited()
    }
    
    
    // MARK: - Changes
    
    /**
    A boolean that indicates whether the `self` has changes that have not been
    saved.
    */
    public var isEdited: Bool {
        guard let referenceRow = referenceRow else {
            // No reference row => edited
            return true
        }
        
        let currentRow = Row(dictionary: storedDatabaseDictionary)
        return referenceRow.containsSameColumnsAndValuesAsRow(currentRow)
    }
    
    /// Flags `self` as edited.
    public func setEdited() {
        referenceRow = nil
    }
    
    /// Reference row for isEdited.
    private var referenceRow: Row?
    

    // MARK: - CRUD
    
    /**
    Executes an INSERT statement to insert the row model.
    
    - parameter db: A Database.
    */
    public func insert(db: Database) throws {
        let version = Version(self)
        let insertionResult = try version.insert(db)
        
        // Update RowID column if needed
        if let (rowIDColumn, insertedRowID) = insertionResult {
            setDatabaseValue(DatabaseValue.Integer(insertedRowID), forColumn: rowIDColumn)
        }
        
        // Not edited any longer
        referenceRow = Row(dictionary: storedDatabaseDictionary)
    }
    
    /**
    Executes an UPDATE statement to update the row model.
    
    - parameter db: A Database.
    */
    public func update(db: Database) throws {
        let version = Version(self)
        try version.update(db)
        
        // Not edited any longer
        referenceRow = Row(dictionary: storedDatabaseDictionary)
    }
    
    /**
    Updates if row model has a primary key with at least one non-nil value, or
    inserts otherwise.
    
    - parameter db: A Database.
    */
    final public func save(db: Database) throws {
        let insertionResult = try Version(self).save(db)
        if let (rowIDColumn, insertedRowID) = insertionResult {
            setDatabaseValue(DatabaseValue.Integer(insertedRowID), forColumn: rowIDColumn)
        }
    }
    
    /**
    Executes a DELETE statement to delete the row model.
    
    - parameter db: A Database.
    */
    public func delete(db: Database) throws {
        try Version(self).delete(db)
        
        // Future calls to update and save MUST throw RowModelNotFound.
        // A way to achieve this is to set rowModel dirty.
        setEdited()
    }
    
    /**
    Executes a SELECT statetement to reload the row model.

    - parameter db: A Database.
    */
    public func reload(db: Database) throws {
        if let row = try Version(self).fetchOneRow(db) {
            for (column, databaseValue) in row {
                setDatabaseValue(databaseValue, forColumn: column)
            }
            
            // Not edited any longer
            referenceRow = Row(dictionary: storedDatabaseDictionary)
        } else {
            throw RowModelError.RowModelNotFound(self)
        }
    }
    
    
    // MARK: - Version
    
    private class Version {
        /// Version will NEVER change the rowModel.
        let rowModel: RowModel
        
        let storedDatabaseDictionary: [String: DatabaseValueConvertible?]
        
        lazy var databaseTable: Table? = self.rowModel.dynamicType.databaseTable
        
        // A primary key dictionary. Its values may be nil.
        lazy var weakPrimaryKeyDictionary: [String: DatabaseValueConvertible?]? = {
            guard let primaryKey = self.databaseTable?.primaryKey else {
                return nil
            }
            switch primaryKey {
            case .RowID(let column):
                if let value = self.storedDatabaseDictionary[column] {
                    return [column: value]
                } else {
                    return nil
                }
                
            case .Column(let column):
                if let value = self.storedDatabaseDictionary[column] {
                    return [column: value]
                } else {
                    return nil
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
        
        // A primary key dictionary. At least one of its values is not nil.
        lazy var strongPrimaryKeyDictionary: [String: DatabaseValueConvertible?]? = {
            guard let dictionary = self.weakPrimaryKeyDictionary else {
                return nil
            }
            for case let value? in dictionary.values {
                return dictionary // At least one non-nil value in the primary key dictionary is OK.
            }
            return nil
        }()
        
        init(_ rowModel: RowModel) {
            self.rowModel = rowModel
            storedDatabaseDictionary = rowModel.storedDatabaseDictionary
        }
        
        /// Returns an optional (rowIDColumn, insertedRowID) if and only if the
        /// row model should be updated.
        func insert(db: Database) throws -> (String, Int64)? {
            // Fail early if databaseTable is nil (not overriden)
            guard let table = databaseTable else {
                throw RowModelError.UnspecifiedTable(rowModel.dynamicType)
            }
            
            // We need something to insert
            let insertedDic = storedDatabaseDictionary
            guard insertedDic.count > 0 else {
                throw RowModelError.InvalidDatabaseDictionary(rowModel)
            }
            
            // INSERT INTO table (id, name) VALUES (:id, :name)
            let columnNames = insertedDic.keys
            let columnSQL = ",".join(columnNames.map { $0.quotedDatabaseIdentifier })
            let valuesSQL = ",".join([String](count: columnNames.count, repeatedValue: "?"))
            let sql = "INSERT INTO \(table.name.quotedDatabaseIdentifier) (\(columnSQL)) VALUES (\(valuesSQL))"
            let changes = try db.execute(sql, bindings: Bindings(insertedDic.values))
            
            // Update RowID column if needed
            guard let primaryKey = table.primaryKey else {
                return nil
            }
            switch primaryKey {
            case .RowID(let column):
                guard let currentID = storedDatabaseDictionary[column] else {
                    fatalError("\(rowModel.dynamicType).storedDatabaseDictionary must return the value for the primary key `(column)`")
                }
                if let _ = currentID {
                    // RowID is already set.
                    return nil
                } else {
                    // RowID is not set yet.
                    let insertedRowID = changes.insertedRowID!
                    
                    // Tell RowModel
                    return (column, insertedRowID)
                }
            default:
                return nil
            }
        }

        func update(db: Database) throws {
            // Fail early if databaseTable is nil (not overriden)
            guard let table = databaseTable else {
                throw RowModelError.UnspecifiedTable(rowModel.dynamicType)
            }
            
            // Fail early if storedDatabaseDictionary is empty (not overriden)
            guard storedDatabaseDictionary.count > 0 else {
                throw RowModelError.InvalidDatabaseDictionary(rowModel)
            }
            
            // Update requires strongPrimaryKeyDictionary
            guard let primaryKeyDictionary = strongPrimaryKeyDictionary else {
                throw RowModelError.InvalidPrimaryKey(rowModel)
            }
            
            // Don't update primary key columns
            var updatedDictionary = storedDatabaseDictionary
            for column in primaryKeyDictionary.keys {
                updatedDictionary.removeValueForKey(column)
            }
            
            // We need something to update
            guard updatedDictionary.count > 0 else {
                throw RowModelError.InvalidDatabaseDictionary(rowModel)
            }
            
            // "UPDATE table SET name = ? WHERE id = ?"
            let updateSQL = ",".join(updatedDictionary.keys.map { column in "\(column.quotedDatabaseIdentifier)=?" })
            let whereSQL = " AND ".join(primaryKeyDictionary.keys.map { column in "\(column.quotedDatabaseIdentifier)=?" })
            let bindings = Bindings(Array(updatedDictionary.values) + Array(primaryKeyDictionary.values))
            let sql = "UPDATE \(table.name.quotedDatabaseIdentifier) SET \(updateSQL) WHERE \(whereSQL)"
            let changedRowCount = try db.execute(sql, bindings: bindings).changedRowCount
            
            // Check is some row was actually changed
            if changedRowCount == 0 {
                throw RowModelError.RowModelNotFound(rowModel)
            }
        }
        
        func save(db: Database) throws -> (String, Int64)? {
            if let _ = strongPrimaryKeyDictionary {
                try update(db)
                return nil
            } else {
                return try insert(db)
            }
        }
        
        func delete(db: Database) throws {
            // Fail early if databaseTable is nil (not overriden)
            guard let table = databaseTable else {
                throw RowModelError.UnspecifiedTable(rowModel.dynamicType)
            }
            
            // Fail early if storedDatabaseDictionary is empty (not overriden)
            guard storedDatabaseDictionary.count > 0 else {
                throw RowModelError.InvalidDatabaseDictionary(rowModel)
            }
            
            // Delete requires strongPrimaryKeyDictionary
            guard let primaryKeyDictionary = strongPrimaryKeyDictionary else {
                throw RowModelError.InvalidPrimaryKey(rowModel)
            }
            
            // "DELETE FROM table WHERE id = ?"
            let whereSQL = " AND ".join(primaryKeyDictionary.keys.map { column in "\(column.quotedDatabaseIdentifier)=?" })
            let bindings = Bindings(Array(primaryKeyDictionary.values))
            let sql = "DELETE FROM \(table.name.quotedDatabaseIdentifier) WHERE \(whereSQL)"
            try db.execute(sql, bindings: bindings)
        }

        func fetchOneRow(db: Database) throws -> Row? {
            // Fail early if databaseTable is nil (not overriden)
            guard databaseTable != nil else {
                throw RowModelError.UnspecifiedTable(rowModel.dynamicType)
            }
            
            // Fail early if storedDatabaseDictionary is empty (not overriden)
            guard storedDatabaseDictionary.count > 0 else {
                throw RowModelError.InvalidDatabaseDictionary(rowModel)
            }
            
            // fetchOneRow requires strongPrimaryKeyDictionary
            guard let primaryKeyDictionary = strongPrimaryKeyDictionary else {
                throw RowModelError.InvalidPrimaryKey(rowModel)
            }
            
            // Fetch
            return db.selectStatement(rowModel.dynamicType, dictionary: primaryKeyDictionary).fetchOneRow()
        }
    }
}


// MARK: - CustomStringConvertible

extension RowModel : CustomStringConvertible {
    /// A textual representation of `self`.
    public var description: String {
        return "<\(reflect(self.dynamicType).summary)" + "".join(storedDatabaseDictionary.map { (key, value) in
            if let string = value as? String {
                let escapedString = string
                    .stringByReplacingOccurrencesOfString("\\", withString: "\\\\")
                    .stringByReplacingOccurrencesOfString("\n", withString: "\\n")
                    .stringByReplacingOccurrencesOfString("\r", withString: "\\r")
                    .stringByReplacingOccurrencesOfString("\t", withString: "\\t")
                    .stringByReplacingOccurrencesOfString("\"", withString: "\\\"")
                return " \(key):\"\(escapedString)\""
            } else if let value = value {
                return " \(key):\(value)"
            } else {
                return " \(key):nil"
            }}) + ">"
    }
}


// MARK: - RowModelError

/// A RowModel-specific error
public enum RowModelError: ErrorType {
    
    /// RowModel.databaseTable returns nil
    case UnspecifiedTable(RowModel.Type)
    
    /// RowModel.databaseDictionary returns an invalid dictionary.
    case InvalidDatabaseDictionary(RowModel)
    
    /// Primary key does not uniquely identifies a database row.
    case InvalidPrimaryKey(RowModel)
    
    /// No matching row could be found in the database.
    case RowModelNotFound(RowModel)
}

extension RowModelError : CustomStringConvertible {
    /// A textual representation of `self`.
    public var description: String {
        switch self {
        case .UnspecifiedTable(let type):
            return "Nil Table returned from \(type).databaseTable"
        case .InvalidDatabaseDictionary(let rowModel):
            return "Invalid database dictionary returned from \(rowModel.dynamicType).storedDatabaseDictionary"
        case .InvalidPrimaryKey(let rowModel):
            return "Invalid primary key in \(rowModel)"
        case .RowModelNotFound(let rowModel):
            return "RowModel not found: \(rowModel)"
        }
    }
}


// MARK: - Fetching Row Models

/**
The Database methods that build RowModel select statements.
*/
extension Database {
    
    func selectStatement<RowModel: GRDB.RowModel>(type: RowModel.Type, dictionary: [String: DatabaseValueConvertible?]) -> SelectStatement {
        // Select methods crash when there is an issue
        guard let table = type.databaseTable else {
            fatalError("Missing databaseTable.")
        }
        
        let whereSQL = " AND ".join(dictionary.keys.map { column in "\(column.quotedDatabaseIdentifier)=?" })
        let sql = "SELECT * FROM \(table.name.quotedDatabaseIdentifier) WHERE \(whereSQL)"
        return selectStatement(sql, bindings: Bindings(dictionary.values))
    }
    
    func selectStatement<RowModel: GRDB.RowModel>(type: RowModel.Type, primaryKey: DatabaseValueConvertible) -> SelectStatement {
        // Select methods crash when there is an issue
        guard let table = type.databaseTable else {
            fatalError("Missing databaseTable.")
        }
        
        guard let tablePrimaryKey = table.primaryKey else {
            fatalError("Missing primary key")
        }
        
        let sql: String
        switch tablePrimaryKey {
        case .RowID(let column):
            sql = "SELECT * FROM \(table.name.quotedDatabaseIdentifier) WHERE \(column.quotedDatabaseIdentifier) = ?"
        case .Column(let column):
            sql = "SELECT * FROM \(table.name.quotedDatabaseIdentifier) WHERE \(column.quotedDatabaseIdentifier) = ?"
        case .Columns(let columns):
            if columns.count == 1 {
                sql = "SELECT * FROM \(table.name.quotedDatabaseIdentifier) WHERE \(columns.first!.quotedDatabaseIdentifier) = ?"
            } else {
                fatalError("Primary key columns count mismatch.")
            }
        }
        
        return selectStatement(sql, bindings: [primaryKey])
    }
}

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
    - parameter bindings: Optional bindings for query parameters.
    
    - returns: A lazy sequence of row models.
    */
    public func fetch<RowModel: GRDB.RowModel>(type: RowModel.Type, _ sql: String, bindings: Bindings? = nil) -> AnySequence<RowModel> {
        return selectStatement(sql, bindings: bindings).fetch(type)
    }

    /**
    Fetches an array sequence of RowModels.

        let persons = db.fetchAll(Person.self, "SELECT * FROM persons")

    - parameter type:     The type of fetched row models. It must be a subclass
                          of RowModel.
    - parameter sql:      An SQL query.
    - parameter bindings: Optional bindings for query parameters.
    
    - returns: An array of row models.
    */
    public func fetchAll<RowModel: GRDB.RowModel>(type: RowModel.Type, _ sql: String, bindings: Bindings? = nil) -> [RowModel] {
        return Array(fetch(type, sql, bindings: bindings))
    }

    /**
    Fetches a single RowModel.

        let person = db.fetchOne(Person.self, "SELECT * FROM persons")

    - parameter type:     The type of fetched row model. It must be a subclass
                          of RowModel.
    - parameter sql:      An SQL query.
    - parameter bindings: Optional bindings for query parameters.
    
    - returns: An optional row model.
    */
    public func fetchOne<RowModel: GRDB.RowModel>(type: RowModel.Type, _ sql: String, bindings: Bindings? = nil) -> RowModel? {
        if let first = fetch(type, sql, bindings: bindings).generate().next() {
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
        return selectStatement(type, primaryKey: primaryKey).fetchOne(type)
    }
    
    /**
    Fetches a single RowModel given a key.

        let person = db.fetchOne(Person.self, key: ["name": Arthur"])

    - parameter type: The type of fetched row model. It must be a subclass of
                      RowModel.
    - parameter key:  A dictionary of value.
    - returns: An optional row model.
    */
    public func fetchOne<RowModel: GRDB.RowModel>(type: RowModel.Type, key dictionary: [String: DatabaseValueConvertible?]?) -> RowModel? {
        guard let dictionary = dictionary else {
            return nil
        }
        return selectStatement(type, dictionary: dictionary).fetchOne(type)
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
    - parameter bindings: Optional bindings for query parameters.
    
    - returns: A lazy sequence of row models.
    */
    public func fetch<RowModel: GRDB.RowModel>(type: RowModel.Type, bindings: Bindings? = nil) -> AnySequence<RowModel> {
        let rowSequence = fetchRows(bindings: bindings)
        return AnySequence { () -> AnyGenerator<RowModel> in
            let rowGenerator = rowSequence.generate()
            return anyGenerator { () -> RowModel? in
                if let row = rowGenerator.next() {
                    return RowModel.init(row: row)
                } else {
                    return nil
                }
            }
        }
    }
    
    /**
    Fetches an array of RowModels.
        
        let statement = db.selectStatement("SELECT * FROM persons")
        let persons = statement.fetchAll(Person.self)

    - parameter type:     The type of fetched row models. It must be a subclass
                          of RowModel.
    - parameter bindings: Optional bindings for query parameters.
    
    - returns: An array of row models.
    */
    public func fetchAll<RowModel: GRDB.RowModel>(type: RowModel.Type, bindings: Bindings? = nil) -> [RowModel] {
        return Array(fetch(type, bindings: bindings))
    }
    
    /**
    Fetches a single RowModel.
        
        let statement = db.selectStatement("SELECT * FROM persons")
        let persons = statement.fetchOne(Person.self)

    - parameter type:     The type of fetched row models. It must be a subclass
                          of RowModel.
    - parameter bindings: Optional bindings for query parameters.
    
    - returns: An optional row model.
    */
    public func fetchOne<RowModel: GRDB.RowModel>(type: RowModel.Type, bindings: Bindings? = nil) -> RowModel? {
        if let first = fetch(type, bindings: bindings).generate().next() {
            // one row containing an optional value
            return first
        } else {
            // no row
            return nil
        }
    }
}


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

public class RowModel {
    
    /// A primary key
    public enum PrimaryKey {
        /// A primary key managed by SQLite.
        case RowID(String)
        
        /// A primary key not managed by SQLite.
        case Column(String)
        
        /// A primary key that spans accross several columns.
        case Columns([String])
    }
    
    /// A table used by the insert, update, save, delete and reload methods.
    public struct Table {
        /// The table name
        public let name: String
        
        /// The primary key
        public let primaryKey: PrimaryKey?
        
        /// Creates a Table given its name and primary key (default nil)
        public init(named name: String, primaryKey: PrimaryKey? = nil) {
            self.name = name
            self.primaryKey = primaryKey
        }
    }
    
    
    // MARK: - Core methods
    
    /// The table used by the insert, update, save, delete and reload methods.
    /// The base class RowModel returns nil, which means that those methods
    /// are not available.
    public class var databaseTable: Table? {
        return nil
    }
    
    /// The values stored by insert, update, and save methods.
    /// The base class RowModel returns an empty dictionary.
    public var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return [:]
    }
    
    public func setDatabaseValue(dbv: DatabaseValue, forColumn column: String) {
    }
    
    
    // MARK: - Initializers
    
    /// Initializes a RowModel.
    public init() {
        // IMPLEMENTATION NOTE
        //
        // This initializer is defined so that a subclass can be defined
        // without any custom initializer.
    }
    
    /// Initializes a RowModel from a row. Used by all fetching methods.
    required public init(row: Row) {
        // IMPLEMENTATION NOTE
        //
        // This initializer is defined so that subclasses can distinguish
        // the simple init() from init(row: Row), and perform distinct
        // initialization for fetched models.
        
        for (column, databaseValue) in row {
            setDatabaseValue(databaseValue, forColumn: column)
        }
        
        // Not dirty
        cleanRow = row
    }
    
    
    // MARK: - Copy
    
    /// Updates a RowModel from another one.
    public func copyDatabaseValuesFrom(other: RowModel) {
        for (column, value) in other.storedDatabaseDictionary {
            if let value = value {
                setDatabaseValue(value.databaseValue, forColumn: column)
            } else {
                setDatabaseValue(.Null, forColumn: column)
            }
        }
        
        // Primary key may have been updated: set dirty.
        setDirty()
    }
    
    
    // MARK: - Dirty
    
    /// Return false if the stored database dictionary is known to be not been
    /// modified since last synchronization with the database (save or reload).
    public var isDirty: Bool {
        guard let cleanRow = cleanRow else {
            // No known clean row => dirty
            return true
        }
        
        return cleanRow.containsSameColumnsAndValuesAsRow(Row(dictionary: storedDatabaseDictionary))
    }
    
    /// Forces the dirty flag
    public func setDirty() {
        cleanRow = nil
    }
    
    /// Reference row for isDirty.
    private var cleanRow: Row?
    

    // MARK: - CRUD
    
    /// An enum that specifies an alternative constraint conflict resolution
    /// algorithm to use during INSERT and UPDATE commands.
    /// See https://www.sqlite.org/lang_insert.html & https://www.sqlite.org/lang_update.html
    public enum ConflictResolution {
        case Replace
        case Rollback
        case Abort
        case Fail
        case Ignore
    }
    
    /// Inserts
    public func insert(db: Database, conflictResolution: ConflictResolution? = nil) throws {
        let version = Version(self)
        let insertionResult = try version.insert(db, conflictResolution: conflictResolution)
        
        // Update RowID column if needed
        if let (rowIDColumn, insertedRowID) = insertionResult {
            setDatabaseValue(DatabaseValue.Integer(insertedRowID), forColumn: rowIDColumn)
        }
        
        // Not dirty any longer
        cleanRow = Row(dictionary: storedDatabaseDictionary)
    }
    
    /// Throws an error if the model has no table name, or no primary key.
    /// Returns true if the model still exists in the database and has been updated.
    /// See https://www.sqlite.org/lang_update.html
    public func update(db: Database, conflictResolution: ConflictResolution? = nil) throws {
        guard isDirty else {
            return
        }
        
        let version = Version(self)
        try version.update(db, conflictResolution: conflictResolution)
        
        // Not dirty any longer
        cleanRow = Row(dictionary: storedDatabaseDictionary)
    }
    
    /// Updates if model has a primary key with at least one non-nil value,
    /// or inserts.
    ///
    /// Returns true if the model has been inserted, or if it still exists in
    /// the database and has been updated.
    final public func save(db: Database, conflictResolution: ConflictResolution? = nil) throws {
        guard isDirty else {
            return
        }
        
        let insertionResult = try Version(self).save(db, conflictResolution: conflictResolution)
        if let (rowIDColumn, insertedRowID) = insertionResult {
            setDatabaseValue(DatabaseValue.Integer(insertedRowID), forColumn: rowIDColumn)
        }
    }
    
    /// Throws an error if the model has no table name, or no primary key
    public func delete(db: Database) throws {
        try Version(self).delete(db)
        
        // Future calls to update and save MUST throw RowModelNotFound.
        // A way to achieve this is to set rowModel dirty.
        setDirty()
    }
    
    /// Throws an error if the model has no table name, or no primary key.
    /// Returns true if the model still exists in the database and has been reloaded.
    public func reload(db: Database) throws {
        if let row = try Version(self).fetchOneRow(db) {
            for (column, databaseValue) in row {
                setDatabaseValue(databaseValue, forColumn: column)
            }
            
            // Not dirty any longer
            cleanRow = Row(dictionary: storedDatabaseDictionary)
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
        func insert(db: Database, conflictResolution: ConflictResolution?) throws -> (String, Int64)? {
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
            let verb: String
            if let conflictResolution = conflictResolution {
                switch conflictResolution {
                case .Replace:
                    verb = "INSERT OR REPLACE"
                case .Rollback:
                    verb = "INSERT OR ROLLBACK"
                case .Abort:
                    verb = "INSERT OR ABORT"
                case .Fail:
                    verb = "INSERT OR FAIL"
                case .Ignore:
                    verb = "INSERT OR IGNORE"
                }
            } else {
                verb = "INSERT"
            }
            let sql = "\(verb) INTO \(table.name.quotedDatabaseIdentifier) (\(columnSQL)) VALUES (\(valuesSQL))"
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

        func update(db: Database, conflictResolution: ConflictResolution? = nil) throws {
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
            let verb: String
            if let conflictResolution = conflictResolution {
                switch conflictResolution {
                case .Replace:
                    verb = "UPDATE OR REPLACE"
                case .Rollback:
                    verb = "UPDATE OR ROLLBACK"
                case .Abort:
                    verb = "UPDATE OR ABORT"
                case .Fail:
                    verb = "UPDATE OR FAIL"
                case .Ignore:
                    verb = "UPDATE OR IGNORE"
                }
            } else {
                verb = "UPDATE"
            }
            let sql = "\(verb) \(table.name.quotedDatabaseIdentifier) SET \(updateSQL) WHERE \(whereSQL)"
            let changedRowCount = try db.execute(sql, bindings: bindings).changedRowCount
            
            // Check is some row was actually changed
            if changedRowCount == 0 {
                throw RowModelError.RowModelNotFound(rowModel)
            }
        }
        
        func save(db: Database, conflictResolution: ConflictResolution? = nil) throws -> (String, Int64)? {
            if let _ = strongPrimaryKeyDictionary {
                try update(db, conflictResolution: conflictResolution)
                return nil
            } else {
                return try insert(db, conflictResolution: conflictResolution)
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


// MARK: - Feching Row Models

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
The Database methods that fetch rows.
*/
extension Database {
    
    // let persons = db.fetch(Person.self, "SELECT ...", bindings: ...)
    public func fetch<RowModel: GRDB.RowModel>(type: RowModel.Type, _ sql: String, bindings: Bindings? = nil) -> AnySequence<RowModel> {
        return selectStatement(sql, bindings: bindings).fetch(type)
    }

    // let persons = db.fetchAll(Person.self, "SELECT ...", bindings: ...)
    public func fetchAll<RowModel: GRDB.RowModel>(type: RowModel.Type, _ sql: String, bindings: Bindings? = nil) -> [RowModel] {
        return Array(fetch(type, sql, bindings: bindings))
    }

    // let person = db.fetchOne(Person.self, "SELECT ...", bindings: ...)
    public func fetchOne<RowModel: GRDB.RowModel>(type: RowModel.Type, _ sql: String, bindings: Bindings? = nil) -> RowModel? {
        if let first = fetch(type, sql, bindings: bindings).generate().next() {
            // one row containing an optional value
            return first
        } else {
            // no row
            return nil
        }
    }
    
    // let person = db.fetchOne(Person.self, primaryKey: ...)
    public func fetchOne<RowModel: GRDB.RowModel>(type: RowModel.Type, primaryKey: DatabaseValueConvertible) -> RowModel? {
        return selectStatement(type, primaryKey: primaryKey).fetchOne(type)
    }
    
    // let person = db.fetchOne(Person.self, key: ...)
    public func fetchOne<RowModel: GRDB.RowModel>(type: RowModel.Type, key dictionary: [String: DatabaseValueConvertible?]) -> RowModel? {
        return selectStatement(type, dictionary: dictionary).fetchOne(type)
    }
}


/**
The SelectStatement methods that fetch rows.
*/
extension SelectStatement {
    
    // let persons = statement.fetch(Person.self, bindings: ...)
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
    
    // let persons = statement.fetchAll(Person.self, bindings: ...)
    public func fetchAll<RowModel: GRDB.RowModel>(type: RowModel.Type, bindings: Bindings? = nil) -> [RowModel] {
        return Array(fetch(type, bindings: bindings))
    }
    
    // let person = statement.fetchOne(Person.self, bindings: ...)
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


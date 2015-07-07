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
    
    // MARK: - Core methods
    
    /// The type of the primary key
    public enum PrimaryKey {
        /// No primary key.
        case None
        
        /// A primary key managed by SQLite.
        case RowID(String)
        
        /// A primary key not managed by SQLite.
        case Column(String)
        
        /// A primary key that spans accross several columns.
        case Columns([String])
    }
    
    /// The table name used by insert, update, save, delete and reload methods.
    /// The base class RowModel returns nil.
    public class var databaseTableName : String? {
        return nil
    }
    
    /// The primary key used by insert, update, save, delete and reload methods.
    /// The base class RowModel returns PrimaryKey.None (no primary key).
    public class var databasePrimaryKey: PrimaryKey {
        return .None
    }
    
    /// The values stored by insert, update, and save methods.
    /// The base class RowModel returns an empty dictionary.
    public var databaseDictionary: [String: SQLiteValueConvertible?] {
        return [:]
    }
    
    /// Updates the RowModel from a Row.
    /// The implementation of the base class RowModel does nothing.
    public func updateFromDatabaseRow(row: Row) {
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
        
        updateFromDatabaseRow(row)
    }
    
    
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
        let insertionResult = try Version(self).insert(db, conflictResolution: conflictResolution)
        
        if let (column, insertedRowID) = insertionResult {
            let row = Row(sqliteDictionary: [column: SQLiteValue.Integer(insertedRowID)])
            updateFromDatabaseRow(row)
        }
    }
    
    /// Throws an error if the model has no table name, or no primary key.
    /// Returns true if the model still exists in the database and has been updated.
    /// See https://www.sqlite.org/lang_update.html
    public func update(db: Database, conflictResolution: ConflictResolution? = nil) throws {
        return try Version(self).update(db, conflictResolution: conflictResolution)
    }
    
    /// Updates if model has a primary key with at least one non-nil value,
    /// or inserts.
    ///
    /// Returns true if the model has been inserted, or if it still exists in
    /// the database and has been updated.
    final public func save(db: Database, conflictResolution: ConflictResolution? = nil) throws {
        if let (column, insertedRowID) = try Version(self).save(db, conflictResolution: conflictResolution) {
            let row = Row(sqliteDictionary: [column: SQLiteValue.Integer(insertedRowID)])
            updateFromDatabaseRow(row)
        }
    }
    
    /// Throws an error if the model has no table name, or no primary key
    final public func delete(db: Database) throws {
        try Version(self).delete(db)
    }
    
    /// Throws an error if the model has no table name, or no primary key.
    /// Returns true if the model still exists in the database and has been reloaded.
    final public func reload(db: Database) throws {
        let row = try Version(self).fetchRow(db)
        updateFromDatabaseRow(row)
    }
    
    
    // MARK: - Version
    
    private class Version {
        /// Version makes the promise that it will NEVER change the rowModel.
        let rowModel: RowModel
        
        lazy var databaseTableName: String? = self.rowModel.dynamicType.databaseTableName
        lazy var databasePrimaryKey: PrimaryKey = self.rowModel.dynamicType.databasePrimaryKey
        lazy var databaseDictionary: [String: SQLiteValueConvertible?] = self.rowModel.databaseDictionary
        
        // A primary key dictionary. Its values may be nil.
        lazy var weakPrimaryKeyDictionary: [String: SQLiteValueConvertible?]? = {
            switch self.databasePrimaryKey {
            case .None:
                return nil
                
            case .RowID(let column):
                let databaseDictionary = self.databaseDictionary
                if let value = databaseDictionary[column] {
                    return [column: value]
                } else {
                    return nil
                }
                
            case .Column(let column):
                let databaseDictionary = self.databaseDictionary
                if let value = databaseDictionary[column] {
                    return [column: value]
                } else {
                    return nil
                }
                
            case .Columns(let columns):
                let databaseDictionary = self.databaseDictionary
                var primaryKeyDictionary = [String: SQLiteValueConvertible?]()
                for column in columns {
                    if let value = databaseDictionary[column] {
                        primaryKeyDictionary[column] = value
                    } else {
                        primaryKeyDictionary[column] = nil
                    }
                }
                return primaryKeyDictionary
            }
        }()
        
        // A primary key dictionary. At least one of its values is not nil.
        lazy var strongPrimaryKeyDictionary: [String: SQLiteValueConvertible?]? = {
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
        }
        
        /// Returns an optional (columnName, insertedRowID) if and only if the
        /// row model should be updated.
        func insert(db: Database, conflictResolution: ConflictResolution?) throws -> (String, Int64)? {
            guard let tableName = databaseTableName else {
                fatalError("Override databaseTableName and return a table name.")
            }
            
            
            // INSERT INTO table (id, name) VALUES (:id, :name)
            
            let insertedDic = databaseDictionary
            let columnNames = insertedDic.keys
            let columnSQL = ",".join(columnNames.map { $0.sqliteQuotedIdentifier })
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
            let sql = "\(verb) INTO \(tableName.sqliteQuotedIdentifier) (\(columnSQL)) VALUES (\(valuesSQL))"
            let changes = try db.execute(sql, bindings: Bindings(insertedDic.values))
            
            
            // Update RowID column if needed
            
            switch databasePrimaryKey {
            case .RowID(let column):
                if let optionalValue = databaseDictionary[column] {
                    if optionalValue == nil {   // ID was not set
                        return (column, changes.insertedRowID!)
                    } else {
                        return nil
                    }
                } else {
                    fatalError("databaseDictionary must return the value for the primary key `(column)`")
                }
            default:
                return nil
            }
        }

        func update(db: Database, conflictResolution: ConflictResolution? = nil) throws {
            guard let tableName = databaseTableName else {
                fatalError("Override databaseTableName and return a table name.")
            }
            
            guard let primaryKeyDictionary = strongPrimaryKeyDictionary else {
                throw RowModelError.InvalidPrimaryKey
            }
            
            
            // Don't update primary key columns
            
            var updatedDictionary = databaseDictionary
            for column in primaryKeyDictionary.keys {
                updatedDictionary.removeValueForKey(column)
            }
            
            
            // "UPDATE table SET name = ? WHERE id = ?"
            
            let updateSQL = ",".join(updatedDictionary.keys.map { column in "\(column.sqliteQuotedIdentifier)=?" })
            let whereSQL = " AND ".join(primaryKeyDictionary.keys.map { column in "\(column.sqliteQuotedIdentifier)=?" })
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
            let sql = "\(verb) \(tableName.sqliteQuotedIdentifier) SET \(updateSQL) WHERE \(whereSQL)"
            let changedRowCount = try db.execute(sql, bindings: bindings).changedRowCount
            
            
            if changedRowCount == 0 {
                throw RowModelError.NotFound
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
            guard let tableName = databaseTableName else {
                fatalError("Override databaseTableName and return a table name.")
            }
            
            guard let primaryKeyDictionary = strongPrimaryKeyDictionary else {
                throw RowModelError.InvalidPrimaryKey
            }
            
            
            // "DELETE FROM table WHERE id = ?"
            
            let whereSQL = " AND ".join(primaryKeyDictionary.keys.map { column in "\(column.sqliteQuotedIdentifier)=?" })
            let bindings = Bindings(Array(primaryKeyDictionary.values))
            let sql = "DELETE FROM \(tableName.sqliteQuotedIdentifier) WHERE \(whereSQL)"
            try db.execute(sql, bindings: bindings)
        }

        func fetchRow(db: Database) throws -> Row {
            guard let tableName = databaseTableName else {
                fatalError("Override databaseTableName and return a table name.")
            }
            
            guard let primaryKeyDictionary = strongPrimaryKeyDictionary else {
                throw RowModelError.InvalidPrimaryKey
            }
            
            
            // "SELECT * FROM table WHERE id = ?"
            
            let whereSQL = " AND ".join(primaryKeyDictionary.keys.map { column in "\(column.sqliteQuotedIdentifier)=?" })
            let bindings = Bindings(Array(primaryKeyDictionary.values))
            let sql = "SELECT * FROM \(tableName.sqliteQuotedIdentifier) WHERE \(whereSQL)"
            if let row = db.fetchOneRow(sql, bindings: bindings) {
                return row
            } else {
                throw RowModelError.NotFound
            }
        }
    }
    
    // Attempts to build a primary key dictionary [String: SQLiteValueConvertible?].
    //
    // Result values come from the *dictionary* argument.
    // Result keys come from the *primaryKey* argument.
    //
    // The result is nil if:
    // - *primaryKey* is not .None
    // - and *dictionary* contains a non-nil value for at least one primary key.
    //
    // Otherwise the result is nil.
    private class func primaryKeyDictionary(dictionary: [String: SQLiteValueConvertible?]) -> [String: SQLiteValueConvertible?]? {
        switch databasePrimaryKey {
        case .None:
            return nil
            
        case .RowID(let column):
            if let optionalValue = dictionary[column], let value = optionalValue {
                return [column: value]
            } else {
                return nil
            }
            
        case .Column(let column):
            if let optionalValue = dictionary[column], let value = optionalValue {
                return [column: value]
            } else {
                return nil
            }
            
        case .Columns(let columns):
            var primaryKeyDictionary = [String: SQLiteValueConvertible?]()
            var oneValueIsNotNil = false
            for column in columns {
                if let optionalValue = dictionary[column], let value = optionalValue {
                    oneValueIsNotNil = true
                    primaryKeyDictionary[column] = value
                } else {
                    primaryKeyDictionary[column] = nil
                }
            }
            if oneValueIsNotNil {
                return primaryKeyDictionary
            } else {
                return nil
            }
        }
    }
}


// MARK: - CustomStringConvertible

extension RowModel : CustomStringConvertible {
    public var description: String {
        return "<\(reflect(self.dynamicType).summary)" + "".join(databaseDictionary.map { (key, value) in
            if var string = value as? String {
                string = string.stringByReplacingOccurrencesOfString("\\", withString: "\\\\")
                string = string.stringByReplacingOccurrencesOfString("\n", withString: "\\n")
                string = string.stringByReplacingOccurrencesOfString("\r", withString: "\\r")
                string = string.stringByReplacingOccurrencesOfString("\t", withString: "\\t")
                string = string.stringByReplacingOccurrencesOfString("\"", withString: "\\\"")
                return " \(key):\"\(string)\""
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
    /// RowModel could not be identified: either the databaseTableName class
    /// method return .None, or the RowModel has nil primary key.
    case InvalidPrimaryKey
    
    /// Failed update or reload because the RowModel could not be found in the
    /// database.
    case NotFound
}

extension RowModelError : CustomStringConvertible {
    /// A textual representation of `self`.
    public var description: String {
        switch self {
        case .InvalidPrimaryKey:
            return "Invalid primary key"
        case .NotFound:
            return "RowModel not found"
        }
    }
}


// MARK: - Feching Row Models

/**
The Database methods that fetch rows.
*/
extension Database {

    // let persons = db.fetch(Person.self, "SELECT ...", bindings: ...)
    public func fetch<RowModel: GRDB.RowModel>(type: RowModel.Type, _ sql: String, bindings: Bindings? = nil) -> AnySequence<RowModel> {
        let rowSequence = fetchRows(sql, bindings: bindings)
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
    public func fetchOne<RowModel: GRDB.RowModel>(type: RowModel.Type, primaryKey: SQLiteValueConvertible) -> RowModel? {
        guard let tableName = RowModel.databaseTableName else {
            fatalError("Override databaseTableName and return a table name.")
        }
        
        let sql: String
        switch RowModel.databasePrimaryKey {
        case .None:
            fatalError("Missing primary key")
        case .RowID(let column):
            sql = "SELECT * FROM \(tableName.sqliteQuotedIdentifier) WHERE \(column.sqliteQuotedIdentifier) = ?"
        case .Column(let column):
            sql = "SELECT * FROM \(tableName.sqliteQuotedIdentifier) WHERE \(column.sqliteQuotedIdentifier) = ?"
        case .Columns(let columns):
            if columns.count == 1 {
                sql = "SELECT * FROM \(tableName.sqliteQuotedIdentifier) WHERE \(columns.first!.sqliteQuotedIdentifier) = ?"
            } else {
                fatalError("Primary key columns count mismatch.")
            }
        }
        
        return fetchOne(type, sql, bindings: [primaryKey])
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


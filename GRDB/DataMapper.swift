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


// MARK: - RowModelType

/// An immutable view to RowModel
protocol RowModelType {
    static var databaseTable: RowModel.Table? { get }
    var storedDatabaseDictionary: [String: DatabaseValueConvertible?] { get }
}


// MARK: - DataMapper

/// DataMapper takes care of RowModel CRUD
final class DataMapper {
    
    /// The rowModel. We use RowModelType instead of RowModel to make sure that
    /// we use an immutable interface to RowModel.
    let rowModel: RowModelType
    
    /// DataMapper keeps a copy the rowModel's storedDatabaseDictionary, so that
    /// this dictionary is built once whatever the database operation.
    private let storedDatabaseDictionary: [String: DatabaseValueConvertible?]
    
    /// The table definition
    private let databaseTable: RowModel.Table?
    
    
    // MARK: - Primary Key
    
    /**
    A dictionary of primary key columns that may identify a row in the
    database. Hence its "weak" name.
    
    It is nil when rowModel has no primary key. Its values come from the
    storedDatabaseDictionary and may be nil.
    */
    private lazy var weakPrimaryKeyDictionary: [String: DatabaseValueConvertible?]? = {
        guard let primaryKey = self.databaseTable?.primaryKey else {
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
    database. Hence its "strong" name.
    
    It is nil when the weakPrimaryKey is nil or only contains nil values.
    */
    private lazy var strongPrimaryKeyDictionary: [String: DatabaseValueConvertible?]? = {
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
        self.rowModel = rowModel
        storedDatabaseDictionary = rowModel.storedDatabaseDictionary
        databaseTable = self.rowModel.dynamicType.databaseTable
    }
    
    
    // MARK: - CRUD
    
    /// INSERT
    ///
    /// Returns (rowIDColumn, insertedRowID) if the row model has a currently
    /// nil RowID primary key, and nil otherwise.
    func insert(db: Database) throws -> (String, Int64)? {
        // Fail early if databaseTable is nil (not overriden)
        guard let table = databaseTable else {
            fatalError("Nil Table returned from \(rowModel.dynamicType).databaseTable")
        }
        
        // Fail early if storedDatabaseDictionary is empty (not overriden)
        guard storedDatabaseDictionary.count > 0 else {
            fatalError("Invalid empty dictionary returned from \(rowModel.dynamicType).storedDatabaseDictionary")
        }
        
        // INSERT
        let insertStatement = try DataMapper.insertStatement(db, tableName: table.name, insertedColumns: Array(storedDatabaseDictionary.keys))
        let bindings = Bindings(storedDatabaseDictionary.values)
        let changes = try insertStatement.execute(bindings: bindings)
        
        // Return inserted RowID column if needed: currently nil RowID primary key.
        if let primaryKey = table.primaryKey, case .RowID(let rowIDColumn) = primaryKey {
            guard let rowID = storedDatabaseDictionary[rowIDColumn] else {
                fatalError("\(rowModel.dynamicType).storedDatabaseDictionary must return the value for the primary key `(rowIDColumn)`")
            }
            if rowID == nil {
                // RowID is not set yet: tell RowModel
                return (rowIDColumn, changes.insertedRowID!)
            } else {
                // RowID is already set: no need for RowID.
                return nil
            }
        } else {
            // No RowID primary Key: no need for RowID
            return nil
        }
    }
    
    /// UPDATE
    func update(db: Database) throws {
        // Fail early if databaseTable is nil (not overriden)
        guard let table = databaseTable else {
            fatalError("Nil Table returned from \(rowModel.dynamicType).databaseTable")
        }
        
        // Fail early if storedDatabaseDictionary is empty (not overriden)
        guard storedDatabaseDictionary.count > 0 else {
            fatalError("Invalid empty dictionary returned from \(rowModel.dynamicType).storedDatabaseDictionary")
        }
        
        // Update requires strongPrimaryKeyDictionary
        guard let primaryKeyDictionary = strongPrimaryKeyDictionary else {
            throw DataMapperError.InvalidPrimaryKey
        }
        
        // Don't update primary key columns
        var updatedDictionary = storedDatabaseDictionary
        for column in primaryKeyDictionary.keys {
            updatedDictionary.removeValueForKey(column)
        }
        
        // We need something to update.
        guard updatedDictionary.count > 0 else {
            // The RowModel is made of a primary key, without any other
            // column: we can't update anything.
            //
            // Three options:
            //
            // 1. throw some RowModelError, assuming this error is
            //    recoverable.
            // 2. fatalError, assuming it is a programmer error to "forget"
            //    keys from storedDatabaseDictionary.
            // 3. do nothing.
            //
            // Option 1 is not OK, because this error couldn't be recovered
            // at runtime: the implementation of storedDatabaseDictionary
            // must be changed.
            //
            // I remember opening rdar://problem/10236982, based on a Core
            // Data entity without any attribute. It was for testing
            // purpose, and the test did not require any attribute, so the
            // Core Data entity had no attribute. So let's choose option 3,
            // and do nothing.
            //
            // But that's not quite ended: update() is supposed to throw
            // RowNotFound when there is no matching row in the
            // database. I mean, consistency is important. So:
            
            let existsStatement = DataMapper.existsStatement(db, tableName: table.name, conditionColumns: Array(primaryKeyDictionary.keys))
            let row = existsStatement.fetchOneRow(bindings: Bindings(primaryKeyDictionary.values))
            guard row != nil else {
                throw DataMapperError.RowNotFound
            }
            return
        }
        
        // Update
        let updateStatement = try DataMapper.updateStatement(db, tableName: table.name, updatedColumns: Array(updatedDictionary.keys), conditionColumns: Array(primaryKeyDictionary.keys))
        let bindings = Bindings(Array(updatedDictionary.values) + Array(primaryKeyDictionary.values))
        let changes = try updateStatement.execute(bindings: bindings)
        
        // Check is some row was actually changed
        if changes.changedRowCount == 0 {
            throw DataMapperError.RowNotFound
        }
    }
    
    /// UPDATE or INSERT
    func save(db: Database) throws -> (String, Int64)? {
        if strongPrimaryKeyDictionary == nil {
            return try insert(db)
        }
        
        do {
            try update(db)
            return nil
        } catch DataMapperError.RowNotFound {
            return try insert(db)
        }
    }
    
    /// DELETE
    func delete(db: Database) throws {
        // Fail early if databaseTable is nil (not overriden)
        guard let table = databaseTable else {
            fatalError("Nil Table returned from \(rowModel.dynamicType).databaseTable")
        }
        
        // Fail early if storedDatabaseDictionary is empty (not overriden)
        guard storedDatabaseDictionary.count > 0 else {
            fatalError("Invalid empty dictionary returned from \(rowModel.dynamicType).storedDatabaseDictionary")
        }
        
        // Delete requires strongPrimaryKeyDictionary
        guard let primaryKeyDictionary = strongPrimaryKeyDictionary else {
            throw DataMapperError.InvalidPrimaryKey
        }
        
        // Delete
        let deleteStatement = try DataMapper.deleteStatement(db, tableName: table.name, conditionColumns: Array(primaryKeyDictionary.keys))
        let bindings = Bindings(Array(primaryKeyDictionary.values))
        try deleteStatement.execute(bindings: bindings)
    }
    
    /// SELECT
    func reloadStatement(db: Database) throws -> SelectStatement {
        // Fail early if databaseTable is nil (not overriden)
        guard let table = databaseTable else {
            fatalError("Nil Table returned from \(rowModel.dynamicType).databaseTable")
        }
        
        // Fail early if storedDatabaseDictionary is empty (not overriden)
        guard storedDatabaseDictionary.count > 0 else {
            fatalError("Invalid empty dictionary returned from \(rowModel.dynamicType).storedDatabaseDictionary")
        }
        
        // fetchOneRow requires strongPrimaryKeyDictionary
        guard let primaryKeyDictionary = strongPrimaryKeyDictionary else {
            throw DataMapperError.InvalidPrimaryKey
        }
        
        // Fetch
        let selectStatement = DataMapper.selectStatement(db, tableName: table.name, conditionColumns: Array(primaryKeyDictionary.keys))
        selectStatement.bindings = Bindings(primaryKeyDictionary.values)
        return selectStatement
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


// MARK: - DataMapperError

enum DataMapperError : ErrorType {
    case InvalidPrimaryKey
    case RowNotFound
}


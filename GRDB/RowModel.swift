//
//  RowModel.swift
//  GRDB
//
//  Created by Gwendal Roué on 01/07/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

import Cocoa

public class RowModel {
    
    public enum PrimaryKey {
        case None
        case SQLiteRowID(String)
        case Single(String)
        case Multiple([String])
    }
    
    public class var databaseTableName : String? {
        return nil
    }
    
    public class var databasePrimaryKey: PrimaryKey {
        return .None
    }
    
    public var databaseDictionary: [String: SQLiteValueConvertible?] {
        return [:]
    }
    
    public func updateFromDatabaseRow(row: Row) {
    }
    
    public init() {
    }
    
    required public init(row: Row) {
        updateFromDatabaseRow(row)
    }
    
    
    public func insert(db: Database) throws {
        // TODO: validation
        // TODO: dirty
        // TODO?: table modification notification
        
        guard let tableName = self.dynamicType.databaseTableName else {
            fatalError("Missing table name")
        }
        
        
        // The inserted values, and the primary key
        
        var insertedDic = databaseDictionary
        let primaryKey = self.dynamicType.databasePrimaryKey
        
        
        // Should we include the primary key in the insert statement?
        // We do, unless the key is a SQLite RowID, without any value.
        
        let rowIDColumn: String?
        switch primaryKey {
        case .SQLiteRowID(let column):
            if let _ = insertedDic[column]! {
                rowIDColumn = nil
            } else {
                insertedDic.removeValueForKey(column)
                rowIDColumn = column
            }
        default:
            rowIDColumn = nil
        }
        
        
        // If there is nothing to insert, and primary key is not managed,
        // something is wrong.
        
        guard insertedDic.count > 0 || rowIDColumn != nil else {
            fatalError("Nothing to insert")
        }
        
        
        // INSERT INTO table ([id, ]name) VALUES ([:id, ]:name)
        
        let columns = insertedDic.keys
        let columnSQL = ",".join(columns)
        let valuesSQL = ",".join([String](count: columns.count, repeatedValue: "?"))
        let sql = "INSERT INTO \(tableName) (\(columnSQL)) VALUES (\(valuesSQL))"
        try db.execute(sql, bindings: Bindings(insertedDic.values))
        
        
        // Update RowID column
        
        if let rowIDColumn = rowIDColumn, let lastInsertedRowID = db.lastInsertedRowID {
            let row = Row(sqliteDictionary: [rowIDColumn: SQLiteValue.Integer(lastInsertedRowID)])
            updateFromDatabaseRow(row)
        }
    }
    
    
    public func update(db: Database) throws {
        // TODO: validation
        // TODO: dirty
        // TODO?: table modification notification
        
        guard let tableName = self.dynamicType.databaseTableName else {
            fatalError("Missing table name")
        }
        
        
        // The updated values
        
        var updatedDictionary = databaseDictionary
        
        
        // Extract primary key values
        
        let primaryKey = self.dynamicType.databasePrimaryKey
        guard let primaryKeyDictionary = RowModel.primaryKeyDictionary(primaryKey, dictionary: updatedDictionary) else {
            fatalError("Missing primaryKey")
        }
        
        
        // Don't update primary key columns
        
        for column in primaryKeyDictionary.keys {
            updatedDictionary.removeValueForKey(column)
        }
        
        
        // If there is nothing to update, something is wrong.
        
        guard updatedDictionary.count > 0 else {
            fatalError("Nothing to update")
        }
        
        
        // "UPDATE table SET name = ? WHERE id = ?"
        
        let updateSQL = ",".join(updatedDictionary.keys.map { column in "\(column)=?" })
        let whereSQL = " AND ".join(primaryKeyDictionary.keys.map { column in "\(column)=?" })
        let bindings = Bindings(Array(updatedDictionary.values) + Array(primaryKeyDictionary.values))
        let sql = "UPDATE \(tableName) SET \(updateSQL) WHERE \(whereSQL)"
        try db.execute(sql, bindings: bindings)
    }
    
    
    final public func save(db: Database) throws {
        
        guard let tableName = self.dynamicType.databaseTableName else {
            fatalError("Missing table name")
        }
        
        let saveIsUpdate: Bool
        pk: switch self.dynamicType.databasePrimaryKey {
        case .None:
            // No primary key? Insert.
            saveIsUpdate = false
            
        case .SQLiteRowID(let column):
            if let value = databaseDictionary[column]!
            {
                // Update if and only if the primary key exists in the database.
                saveIsUpdate = db.fetchOne(Bool.self, "SELECT 1 FROM \(tableName) WHERE \(column) = ?", bindings: [value])!
            }
            else
            {
                // Primary key not set? Insert.
                saveIsUpdate = false
            }
            
        case .Single(let column):
            if let value = databaseDictionary[column]!
            {
                // Update if and only if the primary key exists in the database.
                saveIsUpdate = db.fetchOne(Bool.self, "SELECT 1 FROM \(tableName) WHERE \(column) = ?", bindings: [value])!
            }
            else
            {
                // Primary key not set? Insert.
                saveIsUpdate = false
            }
            
        case .Multiple(let columns):
            let databaseDictionary = self.databaseDictionary
            for column in columns {
                if databaseDictionary[column]! == nil {
                    // One item of the primary key is not set? Insert.
                    saveIsUpdate = false
                    break pk
                }
            }
            
            // Update if and only if the primary key exists in the database.
            let whereSQL = " AND ".join(columns.map { column in "\(column)=?" })
            let bindings = Bindings(columns.map { column in databaseDictionary[column]! })
            saveIsUpdate = db.fetchOne(Bool.self, "SELECT 1 FROM \(tableName) WHERE \(whereSQL)", bindings: bindings)!
        }
        
        if saveIsUpdate {
            try update(db)
        } else {
            try insert(db)
        }
    }
    
    
    final public func delete(db: Database) throws {
        
        guard let tableName = self.dynamicType.databaseTableName else {
            fatalError("Missing table name")
        }
        
        // Extract primary key values, and remove primary key columns from the updated columns
        
        let primaryKey = self.dynamicType.databasePrimaryKey
        guard let primaryKeyDictionary = RowModel.primaryKeyDictionary(primaryKey, dictionary: databaseDictionary) else {
            fatalError("Missing primaryKey")
        }
        
        // "DELETE FROM table WHERE id = ?"
        let whereSQL = " AND ".join(primaryKeyDictionary.keys.map { column in "\(column)=?" })
        let bindings = Bindings(Array(primaryKeyDictionary.values))
        let sql = "DELETE FROM \(tableName) WHERE \(whereSQL)"
        try db.execute(sql, bindings: bindings)
    }
    
    
    private static func primaryKeyDictionary(primaryKey: PrimaryKey, dictionary: [String: SQLiteValueConvertible?]) -> [String: SQLiteValueConvertible?]? {
        switch primaryKey {
        case .None:
            return nil
        case .SQLiteRowID(let column):
            return [column: dictionary[column]!]
        case .Single(let column):
            return [column: dictionary[column]!]
        case .Multiple(let columns):
            var dic = [String: SQLiteValueConvertible?]()
            for column in columns {
                dic[column] = dictionary[column]!
            }
            return dic
        }
    }
}

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
}

extension Database {
    
    // let person = db.fetchOne(Person.self, primaryKey: ...)
    public func fetchOne<RowModel: GRDB.RowModel>(type: RowModel.Type, primaryKey bindings: Bindings) -> RowModel? {
        guard let tableName = RowModel.databaseTableName else {
            fatalError("Missing table name")
        }
        
        let keyDictionary: [String: SQLiteValueConvertible?]
        switch RowModel.databasePrimaryKey {
        case .None:
            keyDictionary = bindings.dictionary(defaultColumnNames: nil)
        case .SQLiteRowID(let column):
            keyDictionary = bindings.dictionary(defaultColumnNames: [column])
        case .Single(let column):
            keyDictionary = bindings.dictionary(defaultColumnNames: [column])
        case .Multiple(let columns):
            keyDictionary = bindings.dictionary(defaultColumnNames: columns)
        }
        
        let whereSQL = " AND ".join(keyDictionary.keys.map { column in "\(column)=?" })
        let bindings = Bindings(Array(keyDictionary.values))
        let sql = "SELECT * FROM \(tableName) WHERE \(whereSQL)"
        return fetchOne(type, sql, bindings: bindings)
    }
    
    // let person = db.fetchOne(Person.self, primaryKey: ...)
    public func fetchOne<RowModel: GRDB.RowModel>(type: RowModel.Type, primaryKey: SQLiteValueConvertible) -> RowModel? {
        guard let tableName = RowModel.databaseTableName else {
            fatalError("Missing table name")
        }
        
        let sql: String
        switch RowModel.databasePrimaryKey {
        case .None:
            fatalError("Missing primary key")
        case .SQLiteRowID(let column):
            sql = "SELECT * FROM \(tableName) WHERE \(column) = ?"
        case .Single(let column):
            sql = "SELECT * FROM \(tableName) WHERE \(column) = ?"
        case .Multiple(let columns):
            if columns.count == 1 {
                sql = "SELECT * FROM \(tableName) WHERE \(columns.first!) = ?"
            } else {
                fatalError("Primary key columns count mismatch.")
            }
        }
        
        return fetchOne(type, sql, bindings: [primaryKey])
    }
}

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


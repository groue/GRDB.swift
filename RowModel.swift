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
    
    public var databaseDictionary: [String: DatabaseValue?] {
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
            if let _ = insertedDic[column]! {    // unwrap double optional
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
    
    final public func update(db: Database) throws {
        // TODO: validation
        // TODO: dirty
        // TODO?: table modification notification
        
        guard let tableName = self.dynamicType.databaseTableName else {
            fatalError("Missing table name")
        }
        
        
        // The updated values, and the primary key
        
        var updatedDic = databaseDictionary
        let primaryKey = self.dynamicType.databasePrimaryKey
        
        
        // Extract primary keys from updatedDic into primaryKeyDic
        
        let primaryKeyDic: [String: DatabaseValue?]
        switch primaryKey {
        case .None:
            fatalError("Missing primary key")
        case .SQLiteRowID(let column):
            primaryKeyDic = [column: updatedDic[column]!]
            updatedDic.removeValueForKey(column)
        case .Single(let column):
            primaryKeyDic = [column: updatedDic[column]!]
            updatedDic.removeValueForKey(column)
        case .Multiple(let columns):
            var dic = [String: DatabaseValue?]()
            for column in columns {
                dic[column] = updatedDic[column]!
                updatedDic.removeValueForKey(column)
            }
            primaryKeyDic = dic
        }
        
        
        // If there is nothing to update, something is wrong.
        
        guard updatedDic.count > 0 else {
            fatalError("Nothing to update")
        }
        
        
        // "UPDATE table SET name = ? WHERE id = ?"
        
        let updateSQL = ",".join(updatedDic.keys.map { column in "\(column)=?" })
        let whereSQL = " AND ".join(primaryKeyDic.keys.map { column in "\(column)=?" })
        let bindings = Bindings(Array(updatedDic.values) + Array(primaryKeyDic.values))
        let sql = "UPDATE \(tableName) SET \(updateSQL) WHERE \(whereSQL)"
        try db.execute(sql, bindings: bindings)
    }
    
    final public func save(db: Database) throws {
        
        guard let tableName = self.dynamicType.databaseTableName else {
            fatalError("Missing table name")
        }
        
        let needUpdate: Bool
        pk: switch self.dynamicType.databasePrimaryKey {
        case .None:
            needUpdate = false
        case .SQLiteRowID(let column):
            if let value = databaseDictionary[column]! {    // unwrap double optional
                needUpdate = db.fetchOne(Bool.self, "SELECT 1 FROM \(tableName) WHERE \(column) = ?", bindings: [value])!
            } else {
                needUpdate = false
            }
        case .Single(let column):
            if let value = databaseDictionary[column]! {    // unwrap double optional
                needUpdate = db.fetchOne(Bool.self, "SELECT 1 FROM \(tableName) WHERE \(column) = ?", bindings: [value])!
            } else {
                needUpdate = false
            }
        case .Multiple(let columns):
            let dic = databaseDictionary
            for column in columns {
                if dic[column]! == nil {    // unwrap double optional
                    needUpdate = false
                    break pk
                }
            }
            let whereSQL = " AND ".join(columns.map { column in "\(column)=?" })
            let bindings = Bindings(columns.map { column in dic[column]! })
            needUpdate = db.fetchOne(Bool.self, "SELECT 1 FROM \(tableName) WHERE \(whereSQL)", bindings: bindings)!
        }
        
        if needUpdate {
            try update(db)
        } else {
            try insert(db)
        }
    }
}

extension Database {
    public func fetchGenerator<T: RowModel>(type: T.Type, _ sql: String, bindings: Bindings? = nil) -> AnyGenerator<T> {
        let rowGenerator = fetchRowGenerator(sql, bindings: bindings)
        return anyGenerator {
            if let row = rowGenerator.next() {
                return T.init(row: row)
            } else {
                return nil
            }
        }
    }

    public func fetch<T: RowModel>(type: T.Type, _ sql: String, bindings: Bindings? = nil) -> AnySequence<T> {
        return AnySequence { self.fetchGenerator(type, sql, bindings: bindings) }
    }

    public func fetchAll<T: RowModel>(type: T.Type, _ sql: String, bindings: Bindings? = nil) -> [T] {
        return Array(fetch(type, sql, bindings: bindings))
    }

    public func fetchOne<T: RowModel>(type: T.Type, _ sql: String, bindings: Bindings? = nil) -> T? {
        if let first = fetchGenerator(type, sql, bindings: bindings).next() {
            // one row containing an optional value
            return first
        } else {
            // no row
            return nil
        }
    }
    
    public func fetchOne<T: RowModel>(type: T.Type, primaryKey: DatabaseValue) -> T? {
        guard let tableName = T.databaseTableName else {
            fatalError("Missing table name")
        }
        
        let sql: String
        switch T.databasePrimaryKey {
        case .None:
            fatalError("Missing primary key")
        case .SQLiteRowID(let column):
            sql = "SELECT * FROM \(tableName) WHERE \(column) = ?"
        case .Single(let column):
            sql = "SELECT * FROM \(tableName) WHERE \(column) = ?"
        case .Multiple:
            fatalError("Multiple primary key")
        }
        
        return fetchOne(type, sql, bindings: [primaryKey])
    }
}


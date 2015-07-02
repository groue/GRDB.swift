//
//  RowModel.swift
//  GRDB
//
//  Created by Gwendal Roué on 01/07/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

import Cocoa

public class RowModel {
    
    public var tableName: String? {
        return nil
    }
    
    public var databaseDictionary : [String: DatabaseValue?] {
        return [:]
    }
    
    public var databasePrimaryKey : [String: DatabaseValue?] {
        return [:]
    }
    
    public func updateFromDatabaseRow(row: Row) {
    }
    
    final public func insert(db: Database) throws {
        // TODO: validation
        // TODO: dirty
        // TODO?: table modification notification
        
        guard let tableName = self.tableName else {
            fatalError("Missing table name")
        }
        
        var insertedDic = databaseDictionary
        let primaryKey = databasePrimaryKey
        
        // TODO: assert primaryKey and insertedDic have no common key
        
        // If primary key is made of a single column, and this column is not
        // set, assume it is managed by SQLite.
        let managedPrimaryKeyName: String?
        if primaryKey.count == 1 && primaryKey.first!.1 == nil {
            managedPrimaryKeyName = primaryKey.first!.0
        } else {
            managedPrimaryKeyName = nil
        }
        
        // If primary key is not managed, add it to the inserted values:
        if managedPrimaryKeyName == nil {
            for (key, value) in primaryKey {
                insertedDic[key] = value
            }
        }
        
        // If there is nothing to insert, and primary key is not managed,
        // somthing is wrong.
        guard insertedDic.count > 0 || managedPrimaryKeyName != nil else {
            fatalError("Nothing to insert")
        }
        
        // INSERT INTO table ([id, ]name) VALUES ([:id, ]:name)
        let columnNames = insertedDic.keys
        let columnList = ",".join(columnNames)
        let questionMarks = ",".join([String](count: columnNames.count, repeatedValue: "?"))
        let sql = "INSERT INTO \(tableName) (\(columnList)) VALUES (\(questionMarks))"
        try db.execute(sql, bindings: Bindings(insertedDic.values))
        
        // Update managed primary key
        if let managedPrimaryKeyName = managedPrimaryKeyName, let lastInsertedRowID = db.lastInsertedRowID {
            let row = Row(sqliteDictionary: [managedPrimaryKeyName: SQLiteValue.Integer(lastInsertedRowID)])
            updateFromDatabaseRow(row)
        }
    }
    
    public init () {
    }
    required public init (row: Row) {
        updateFromDatabaseRow(row)
    }
}

public func fetchModelGenerator<T: RowModel>(type: T.Type, db: Database, sql: String, bindings: Bindings? = nil) -> AnyGenerator<T?> {
    let rowGenerator = db.fetchRowGenerator(sql, bindings: bindings)
    return anyGenerator {
        if let row = rowGenerator.next() {
            return T.init(row: row)
        } else {
            return nil
        }
    }
}

public func fetchModels<T: RowModel>(type: T.Type, db: Database, sql: String, bindings: Bindings? = nil) -> AnySequence<T?> {
    return AnySequence { fetchModelGenerator(type, db: db, sql: sql, bindings: bindings) }
}

public func fetchAllModels<T: RowModel>(type: T.Type, db: Database, sql: String, bindings: Bindings? = nil) -> [T?] {
    return fetchModels(type, db: db, sql: sql, bindings: bindings).map { $0 }
}

public func fetchOneModel<T: RowModel>(type: T.Type, db: Database, sql: String, bindings: Bindings? = nil) -> T? {
    if let first = fetchModelGenerator(type, db: db, sql: sql, bindings: bindings).next() {
        // one row containing an optional value
        return first
    } else {
        // no row
        return nil
    }
}

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
        
        var dic = databaseDictionary
        let pk = databasePrimaryKey
        
        // If primary key is made of a single column, and this column is not
        // set, assume it is managed by SQLite.
        let managedPrimaryKeyName: String?
        if pk.count == 1 && pk.first!.1 == nil {
            managedPrimaryKeyName = pk.first!.0
        } else {
            managedPrimaryKeyName = nil
        }
        
        // Don't insert managedPrimaryKeyName:
        if let managedPrimaryKeyName = managedPrimaryKeyName {
            dic.removeValueForKey(managedPrimaryKeyName)
        }
        
        guard dic.count > 0 || managedPrimaryKeyName != nil else {
            fatalError("Nothing to insert")
        }
        
        // INSERT INTO table ([id, ]name) VALUES ([:id, ]:name)
        let columnNames = dic.keys
        let columnList = ",".join(columnNames)
        let questionMarks = ",".join([String](count: columnNames.count, repeatedValue: "?"))
        let sql = "INSERT INTO \(tableName) (\(columnList)) VALUES (\(questionMarks))"
        try db.execute(sql, bindings: Bindings(dic.values))
        
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
    let rowGenerator = fetchRowGenerator(db, sql: sql, bindings: bindings)
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

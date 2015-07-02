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
    
    public func insert(db: Database) throws {
        guard let tableName = self.tableName else {
            fatalError("Missing table name")
        }
//        if !validateForInsert(error: error) {
//            return false
//        }
        
        // "INSERT INTO table ([id, ]name) VALUES ([:id, ]:name)"
        
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
        
        let columnNames = dic.keys
        let columnList = ",".join(columnNames)
        let questionMarks = ",".join([String](count: columnNames.count, repeatedValue: "?"))
        let insertQuery = "INSERT INTO \(tableName) (\(columnList)) VALUES (\(questionMarks))"
        
        try db.execute(insertQuery, bindings: Array(dic.values))
//        if db.changes() > 0 {
//            ModelDatabase.tableDidChange(table.name)
//        }
        
        if let managedPrimaryKeyName = managedPrimaryKeyName, let lastInsertedRowID = db.lastInsertedRowID {
            let row = Row(cellDictionary: [managedPrimaryKeyName: DatabaseCell.Integer(lastInsertedRowID)])
            updateFromDatabaseRow(row)
        }
        
//        // Not dirty any longer
//        nonDirtyDictionary = dictionaryWithValuesForKeys(table.columnNames)
    }
    
    public init () {
        
    }
}

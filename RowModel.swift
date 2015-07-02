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

func fetchGenerator<T: RowModel>(db: Database, type: T.Type, sql: String) -> AnyGenerator<T> {
    let statement = try! db.selectStatement(sql)
    let rows = statement.fetchRows()
    let rowGenerator = rows.generate()
    return anyGenerator {
        if let row = rowGenerator.next() {
            return T.init(row: row)
        } else {
            return nil
        }
    }
}

func fetch<T: RowModel>(db: Database, type: T.Type, sql: String) -> AnySequence<T> {
    return AnySequence { fetchGenerator(db, type: type, sql: sql) }
}

func fetchAll<T: RowModel>(db: Database, type: T.Type, sql: String) -> [T] {
    return fetch(db, type: type, sql: sql).map { $0 }
}

func fetchOne<T: RowModel>(db: Database, type: T.Type, sql: String) -> T? {
    return fetchGenerator(db, type: type, sql: sql).next()
}

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
    
    final public func insert(db: Database) throws {
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
        
        let rowIDColumnName: String?
        switch primaryKey {
        case .SQLiteRowID(let columName):
            if let _ = insertedDic[columName]! {    // unwrap double optional
                rowIDColumnName = nil
            } else {
                insertedDic.removeValueForKey(columName)
                rowIDColumnName = columName
            }
        default:
            rowIDColumnName = nil
        }
        
        
        // If there is nothing to insert, and primary key is not managed,
        // somthing is wrong.
        guard insertedDic.count > 0 || rowIDColumnName != nil else {
            fatalError("Nothing to insert")
        }
        
        
        // INSERT INTO table ([id, ]name) VALUES ([:id, ]:name)
        
        let columnNames = insertedDic.keys
        let columnList = ",".join(columnNames)
        let questionMarks = ",".join([String](count: columnNames.count, repeatedValue: "?"))
        let sql = "INSERT INTO \(tableName) (\(columnList)) VALUES (\(questionMarks))"
        try db.execute(sql, bindings: Bindings(insertedDic.values))
        
        
        // Update RowID column
        
        if let rowIDColumnName = rowIDColumnName, let lastInsertedRowID = db.lastInsertedRowID {
            let row = Row(sqliteDictionary: [rowIDColumnName: SQLiteValue.Integer(lastInsertedRowID)])
            updateFromDatabaseRow(row)
        }
    }
    
    public init () {
    }
    
    required public init (row: Row) {
        updateFromDatabaseRow(row)
    }
}

extension Database {
    public func fetchModelGenerator<T: RowModel>(sql: String, bindings: Bindings? = nil, type: T.Type) -> AnyGenerator<T> {
        let rowGenerator = fetchRowGenerator(sql, bindings: bindings)
        return anyGenerator {
            if let row = rowGenerator.next() {
                return T.init(row: row)
            } else {
                return nil
            }
        }
    }

    public func fetchModels<T: RowModel>(sql: String, bindings: Bindings? = nil, type: T.Type) -> AnySequence<T> {
        return AnySequence { self.fetchModelGenerator(sql, bindings: bindings, type: type) }
    }

    public func fetchAllModels<T: RowModel>(sql: String, bindings: Bindings? = nil, type: T.Type) -> [T] {
        return Array(fetchModels(sql, bindings: bindings, type: type))
    }

    public func fetchOneModel<T: RowModel>(sql: String, bindings: Bindings? = nil, type: T.Type) -> T? {
        if let first = fetchModelGenerator(sql, bindings: bindings, type: type).next() {
            // one row containing an optional value
            return first
        } else {
            // no row
            return nil
        }
    }
    
    public func fetchOneModel<T: RowModel>(primaryKey primaryKey: DatabaseValue, type: T.Type) -> T? {
        guard let tableName = T.databaseTableName else {
            fatalError("Missing table name")
        }
        
        let sql: String
        switch T.databasePrimaryKey {
        case .None:
            fatalError("Missing primary key")
        case .SQLiteRowID(let columnName):
            sql = "SELECT * FROM \(tableName) WHERE \(columnName) = ?"
        case .Single(let columnName):
            sql = "SELECT * FROM \(tableName) WHERE \(columnName) = ?"
        case .Multiple:
            fatalError("Multiple primary key")
        }
        
        return fetchOneModel(sql, bindings: [primaryKey], type: type)
    }
}


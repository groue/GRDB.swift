//
//  Database.swift
//  GRDB
//
//  Created by Gwendal Roué on 30/06/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

typealias CConnection = COpaquePointer

public class Database {
    
    public enum TransactionType {
        case Deferred
        case Immediate
        case Exclusive
    }
    
    public let configuration: DatabaseConfiguration
    let cConnection = CConnection()
    
    public init(path: String, configuration: DatabaseConfiguration = DatabaseConfiguration()) throws {
        self.configuration = configuration
        // See https://www.sqlite.org/c3ref/open.html
        let code = path.nulTerminatedUTF8.withUnsafeBufferPointer { codeUnits in
            return sqlite3_open(UnsafePointer<Int8>(codeUnits.baseAddress), &cConnection)
        }
        try Error.checkCResultCode(code, cConnection: cConnection)
        
        if configuration.foreignKeysEnabled {
            try execute("PRAGMA foreign_keys = ON")
        }
    }
    
    deinit {
        if cConnection != nil {
            sqlite3_close(cConnection)
        }
    }
    
    public func selectStatement(sql: String, arguments: [DBValue?]? = nil) throws -> SelectStatement {
        let statement = try SelectStatement(database: self, sql: sql)
        if let arguments = arguments {
            statement.bind(arguments)
        }
        return statement
    }
    
    public func fetchRows(sql: String, arguments: [DBValue?]? = nil) throws -> AnySequence<Row> {
        let statement = try selectStatement(sql, arguments: arguments)
        return statement.fetchRows()
    }
    
    public func fetchValues<T: DBValue>(type: T.Type, sql: String, arguments: [DBValue?]? = nil) throws -> AnySequence<T?> {
        let statement = try selectStatement(sql, arguments: arguments)
        return statement.fetchValues(type)
    }
    
    public func updateStatement(sql: String, arguments: [DBValue?]? = nil) throws -> UpdateStatement {
        let statement = try UpdateStatement(database: self, sql: sql)
        if let arguments = arguments {
            statement.bind(arguments)
        }
        return statement
    }
    
    public func execute(sql: String, arguments: [DBValue?]? = nil) throws {
        let statement = try updateStatement(sql, arguments: arguments)
        try statement.execute()
    }
    
    public func inTransaction(type: TransactionType = .Exclusive, block: () throws -> Void) throws {
        try beginTransaction(type)
        do {
            try block()
            try commit()
        } catch {
            try rollback()
            throw error
        }
    }
    
    public func tableExist(tableName: String) -> Bool {
        let statement = try! selectStatement("SELECT [sql] FROM sqlite_master WHERE [type] = 'table' AND LOWER(name) = ?")
        statement.bind(tableName.lowercaseString, atIndex: 1)
        for _ in statement.fetchRows() {
            return true
        }
        return false
    }

    private func beginTransaction(type: TransactionType = .Exclusive) throws {
        switch type {
        case .Deferred:
            try execute("BEGIN DEFERRED TRANSACTION")
        case .Immediate:
            try execute("BEGIN IMMEDIATE TRANSACTION")
        case .Exclusive:
            try execute("BEGIN EXCLUSIVE TRANSACTION")
        }
    }
    
    private func rollback() throws {
        try execute("ROLLBACK TRANSACTION")
    }
    
    private func commit() throws {
        try execute("COMMIT TRANSACTION")
    }
    
}

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
    
    // MARK: - selectStatement
    
    public func selectStatement(sql: String) throws -> SelectStatement {
        let statement = try SelectStatement(database: self, sql: sql)
        return statement
    }
    
    public func selectStatement(sql: String, bindings: [DatabaseValue?]?) throws -> SelectStatement {
        let statement = try SelectStatement(database: self, sql: sql)
        if let bindings = bindings {
            statement.bind(bindings)
        }
        return statement
    }
    
    public func selectStatement(sql: String, bindings: [String: DatabaseValue?]?) throws -> SelectStatement {
        let statement = try SelectStatement(database: self, sql: sql)
        if let bindings = bindings {
            statement.bind(bindings)
        }
        return statement
    }
    
    
    // MARK: - fetchRows
    
    public func fetchRows(sql: String) throws -> AnySequence<Row> {
        let statement = try selectStatement(sql)
        return statement.fetchRows()
    }
    
    public func fetchRows(sql: String, bindings: [DatabaseValue?]?) throws -> AnySequence<Row> {
        let statement = try selectStatement(sql, bindings: bindings)
        return statement.fetchRows()
    }
    
    public func fetchRows(sql: String, bindings: [String: DatabaseValue?]?) throws -> AnySequence<Row> {
        let statement = try selectStatement(sql, bindings: bindings)
        return statement.fetchRows()
    }
    
    
    // MARK: - fetchFirstRow
    
    public func fetchFirstRow(sql: String) throws -> Row? {
        let statement = try selectStatement(sql)
        return statement.fetchFirstRow()
    }
    
    public func fetchFirstRow(sql: String, bindings: [DatabaseValue?]?) throws -> Row? {
        let statement = try selectStatement(sql, bindings: bindings)
        return statement.fetchFirstRow()
    }
    
    public func fetchFirstRow(sql: String, bindings: [String: DatabaseValue?]?) throws -> Row? {
        let statement = try selectStatement(sql, bindings: bindings)
        return statement.fetchFirstRow()
    }
    
    
    // MARK: - fetchValues
    
    public func fetchValues<T: DatabaseValue>(sql: String, type: T.Type) throws -> AnySequence<T?> {
        let statement = try selectStatement(sql)
        return statement.fetchValues(type: type)
    }
    
    public func fetchValues<T: DatabaseValue>(sql: String, bindings: [DatabaseValue?]?, type: T.Type) throws -> AnySequence<T?> {
        let statement = try selectStatement(sql, bindings: bindings)
        return statement.fetchValues(type: type)
    }
    
    public func fetchValues<T: DatabaseValue>(sql: String, bindings: [String: DatabaseValue?]?, type: T.Type) throws -> AnySequence<T?> {
        let statement = try selectStatement(sql, bindings: bindings)
        return statement.fetchValues(type: type)
    }
    
    
    // MARK: - fetchFirstValue
    
    public func fetchFirstValue<T: DatabaseValue>(sql: String) throws -> T? {
        let statement = try selectStatement(sql)
        return statement.fetchFirstValue()
    }
    
    public func fetchFirstValue<T: DatabaseValue>(sql: String, bindings: [DatabaseValue?]?) throws -> T? {
        let statement = try selectStatement(sql, bindings: bindings)
        return statement.fetchFirstValue()
    }
    
    public func fetchFirstValue<T: DatabaseValue>(sql: String, bindings: [String: DatabaseValue?]?) throws -> T? {
        let statement = try selectStatement(sql, bindings: bindings)
        return statement.fetchFirstValue()
    }
    
    
    // MARK: - updateStatement
    
    public func updateStatement(sql: String) throws -> UpdateStatement {
        let statement = try UpdateStatement(database: self, sql: sql)
        return statement
    }
    
    public func updateStatement(sql: String, bindings: [DatabaseValue?]?) throws -> UpdateStatement {
        let statement = try UpdateStatement(database: self, sql: sql)
        if let bindings = bindings {
            statement.bind(bindings)
        }
        return statement
    }
    
    public func updateStatement(sql: String, bindings: [String: DatabaseValue?]?) throws -> UpdateStatement {
        let statement = try UpdateStatement(database: self, sql: sql)
        if let bindings = bindings {
            statement.bind(bindings)
        }
        return statement
    }
    
    
    // MARK: - execute
    
    public func execute(sql: String) throws {
        let statement = try updateStatement(sql)
        try statement.execute()
    }
    
    public func execute(sql: String, bindings: [DatabaseValue?]?) throws {
        let statement = try updateStatement(sql, bindings: bindings)
        try statement.execute()
    }
    
    public func execute(sql: String, bindings: [String: DatabaseValue?]?) throws {
        let statement = try updateStatement(sql, bindings: bindings)
        try statement.execute()
    }
    
    
    // MARK: - transactions
    
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
    
    
    // MARK: -
    
    public func tableExist(tableName: String) -> Bool {
        let statement = try! selectStatement("SELECT [sql] FROM sqlite_master WHERE [type] = 'table' AND LOWER(name) = ?")
        statement.bind(tableName.lowercaseString, atIndex: 1)
        for _ in statement.fetchRows() {
            return true
        }
        return false
    }
}

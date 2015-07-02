//
//  Database.swift
//  GRDB
//
//  Created by Gwendal Roué on 30/06/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

public class Database {
    
    public enum TransactionType {
        case Deferred
        case Immediate
        case Exclusive
    }
    
    public let configuration: DatabaseConfiguration
    let sqliteConnection = SQLiteConnection()
    
    init(path: String, configuration: DatabaseConfiguration = DatabaseConfiguration()) throws {
        self.configuration = configuration
        // See https://www.sqlite.org/c3ref/open.html
        let code = sqlite3_open(path, &sqliteConnection)
        try SQLiteError.checkCResultCode(code, sqliteConnection: sqliteConnection)
        
        if configuration.foreignKeysEnabled {
            try execute("PRAGMA foreign_keys = ON")
        }
    }
    
    deinit {
        if sqliteConnection != nil {
            sqlite3_close(sqliteConnection)
        }
    }
    
    // MARK: - selectStatement
    
    public func selectStatement(sql: String, bindings: Bindings? = nil, unsafe: Bool = false) throws -> SelectStatement {
        return try SelectStatement(database: self, sql: sql, bindings: bindings, unsafe: unsafe)
    }
    
    
    // MARK: - updateStatement
    
    public func updateStatement(sql: String, bindings: Bindings? = nil) throws -> UpdateStatement {
        return try UpdateStatement(database: self, sql: sql, bindings: bindings)
    }
    
    
    // MARK: - execute
    
    public func execute(sql: String, bindings: Bindings? = nil) throws {
        return try updateStatement(sql, bindings: bindings).execute()
    }
    
    
    // MARK: - transactions
    
    public enum TransactionCompletion {
        case Commit
        case Rollback
    }
    
    public func inTransaction(type: TransactionType = .Exclusive, block: () throws -> TransactionCompletion) throws {
        var completion: TransactionCompletion = .Rollback
        var dbError: ErrorType? = nil
        
        try beginTransaction(type)
        
        do {
            completion = try block()
        } catch {
            completion = .Rollback
            dbError = error
        }
        
        do {
            switch completion {
            case .Commit:
                try commit()
            case .Rollback:
                try rollback()
            }
        } catch {
            if dbError == nil {
                dbError = error
            }
        }
        
        if let dbError = dbError {
            throw dbError
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
    
    public var lastInsertedRowID: Int64? {
        let rowid = sqlite3_last_insert_rowid(sqliteConnection)
        return rowid == 0 ? nil : rowid
    }

    
    // MARK: -
    
    public func tableExists(tableName: String) -> Bool {
        let statement = try! selectStatement("SELECT [sql] FROM sqlite_master WHERE [type] = 'table' AND LOWER(name) = ?")
        statement.bind(tableName.lowercaseString, atIndex: 1)
        for _ in statement.fetchRows() {
            return true
        }
        return false
    }
}

extension Database {
    public func fetchRowGenerator(sql: String, bindings: Bindings? = nil) -> AnyGenerator<Row> {
        let statement = try! selectStatement(sql, bindings: bindings)
        return statement.fetchRowGenerator()
    }
    
    public func fetchRows(sql: String, bindings: Bindings? = nil) -> AnySequence<Row> {
        return AnySequence { self.fetchRowGenerator(sql, bindings: bindings) }
    }
    
    public func fetchAllRows(sql: String, bindings: Bindings? = nil) -> [Row] {
        return fetchRows(sql, bindings: bindings).map { $0 }
    }
    
    public func fetchOneRow(sql: String, bindings: Bindings? = nil) -> Row? {
        return fetchRowGenerator(sql, bindings: bindings).next()
    }
    
    public func fetchValueGenerator<T: DatabaseValue>(sql: String, bindings: Bindings? = nil, type: T.Type) -> AnyGenerator<T?> {
        let statement = try! selectStatement(sql, bindings: bindings)
        return statement.fetchValueGenerator(type)
    }
    
    public func fetchValues<T: DatabaseValue>(sql: String, bindings: Bindings? = nil, type: T.Type) -> AnySequence<T?> {
        return AnySequence { self.fetchValueGenerator(sql, bindings: bindings, type: type) }
    }
    
    public func fetchAllValues<T: DatabaseValue>(sql: String, bindings: Bindings? = nil, type: T.Type) -> [T?] {
        return fetchValues(sql, bindings: bindings, type: type).map { $0 }
    }
    
    public func fetchOne<T: DatabaseValue>(sql: String, bindings: Bindings? = nil, type: T.Type) -> T? {
        if let first = fetchValueGenerator(sql, bindings: bindings, type: type).next() {
            // one row containing an optional value
            return first
        } else {
            // no row
            return nil
        }
    }
}


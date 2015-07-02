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

func failOnError<R>(@noescape block: (Void) throws -> R) -> R {
    do {
        return try block()
    } catch let error as SQLiteError {
        switch (error.sql, error.message) {
        case (nil, nil):
            fatalError("SQLite error code \(error.code)")
        case (nil, let message):
            fatalError("SQLite error code \(error.code): \(message)")
        case (let sql, nil):
            fatalError("SQLite error code \(error.code) executing `\(sql)`")
        case (let sql, let message):
            fatalError("SQLite error code \(error.code) executing `\(sql)`: \(message)")
        }
    } catch {
        fatalError("error: \(error)")
    }
}

extension Database {
    
    public func fetchRowGenerator(sql: String, bindings: Bindings? = nil) -> AnyGenerator<Row> {
        return failOnError {
            let statement = try selectStatement(sql, bindings: bindings)
            return statement.fetchRowGenerator()
        }
    }
    
    public func fetchRows(sql: String, bindings: Bindings? = nil) -> AnySequence<Row> {
        return AnySequence { self.fetchRowGenerator(sql, bindings: bindings) }
    }
    
    public func fetchAllRows(sql: String, bindings: Bindings? = nil) -> [Row] {
        return Array(fetchRows(sql, bindings: bindings))
    }
    
    public func fetchOneRow(sql: String, bindings: Bindings? = nil) -> Row? {
        return fetchRowGenerator(sql, bindings: bindings).next()
    }
}

extension Database {
    
    public func fetchGenerator<T: DatabaseValue>(type: T.Type, _ sql: String, bindings: Bindings? = nil) -> AnyGenerator<T?> {
        return failOnError {
            let statement = try selectStatement(sql, bindings: bindings)
            return statement.fetchGenerator(type)
        }
    }
    
    public func fetch<T: DatabaseValue>(type: T.Type, _ sql: String, bindings: Bindings? = nil) -> AnySequence<T?> {
        return AnySequence { self.fetchGenerator(type, sql, bindings: bindings) }
    }
    
    public func fetchAll<T: DatabaseValue>(type: T.Type, _ sql: String, bindings: Bindings? = nil) -> [T?] {
        return Array(fetch(type, sql, bindings: bindings))
    }
    
    public func fetchOne<T: DatabaseValue>(type: T.Type, _ sql: String, bindings: Bindings? = nil) -> T? {
        if let first = fetchGenerator(type, sql, bindings: bindings).next() {
            // one row containing an optional value
            return first
        } else {
            // no row
            return nil
        }
    }
}


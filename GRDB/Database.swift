//
// GRDB.swift
// https://github.com/groue/GRDB.swift
// Copyright (c) 2015 Gwendal Roué
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.


public class Database {
    
    public enum TransactionType {
        case Deferred
        case Immediate
        case Exclusive
    }
    
    public let configuration: Configuration
    let sqliteConnection = SQLiteConnection()
    
    init(path: String, configuration: Configuration) throws {
        self.configuration = configuration
        
        // See https://www.sqlite.org/c3ref/open.html
        let code = sqlite3_open_v2(path, &sqliteConnection, configuration.sqliteOpenFlags, nil)
        try SQLiteError.checkCResultCode(code, sqliteConnection: sqliteConnection)
        
        if configuration.foreignKeysEnabled {
            try execute("PRAGMA foreign_keys = ON")
        }
    }
    
    convenience init(configuration: Configuration) {
        try! self.init(path: ":memory:", configuration: configuration)
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

func failOnError<Result>(@noescape block: (Void) throws -> Result) -> Result {
    do {
        return try block()
    } catch let error as SQLiteError {
        fatalError(error.description)
    } catch {
        fatalError("error: \(error)")
    }
}

extension Database {
    
    // let rows = db.fetchRows("SELECT ...", bindings: ...)
    public func fetchRows(sql: String, bindings: Bindings? = nil) -> AnySequence<Row> {
        return failOnError {
            let statement = try selectStatement(sql, bindings: bindings)
            return statement.fetchRows()
        }
    }
    
    // let rows = db.fetchAllRows("SELECT ...", bindings: ...)
    public func fetchAllRows(sql: String, bindings: Bindings? = nil) -> [Row] {
        return Array(fetchRows(sql, bindings: bindings))
    }
    
    // let row = db.fetchOneRows("SELECT ...", bindings: ...)
    public func fetchOneRow(sql: String, bindings: Bindings? = nil) -> Row? {
        return fetchRows(sql, bindings: bindings).generate().next()
    }
}

extension Database {
    
    // let names = db.fetch(String.self, "SELECT name ...", bindings: ...)
    public func fetch<Value: SQLiteValueConvertible>(type: Value.Type, _ sql: String, bindings: Bindings? = nil) -> AnySequence<Value?> {
        return failOnError {
            let statement = try selectStatement(sql, bindings: bindings)
            return statement.fetch(type)
        }
    }
    
    // let names = db.fetchAll(String.self, "SELECT name ...", bindings: ...)
    public func fetchAll<Value: SQLiteValueConvertible>(type: Value.Type, _ sql: String, bindings: Bindings? = nil) -> [Value?] {
        return Array(fetch(type, sql, bindings: bindings))
    }
    
    // let name = db.fetchOne(String.self, "SELECT name ...", bindings: ...)
    public func fetchOne<Value: SQLiteValueConvertible>(type: Value.Type, _ sql: String, bindings: Bindings? = nil) -> Value? {
        if let first = fetch(type, sql, bindings: bindings).generate().next() {
            // one row containing an optional value
            return first
        } else {
            // no row
            return nil
        }
    }
}


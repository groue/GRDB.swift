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
    
    let cConnection = CConnection()
    
    public init(path: String) throws {
        // See https://www.sqlite.org/c3ref/open.html
        let code = path.nulTerminatedUTF8.withUnsafeBufferPointer { codeUnits in
            return sqlite3_open(UnsafePointer<Int8>(codeUnits.baseAddress), &cConnection)
        }
        try Error.checkCResultCode(code, cConnection: cConnection)
    }
    
    deinit {
        if cConnection != nil {
            sqlite3_close(cConnection)
        }
    }
    
    public func selectStatement(sql: String) throws -> SelectStatement {
        return try SelectStatement(database: self, sql: sql)
    }
    
    public func updateStatement(sql: String) throws -> UpdateStatement {
        return try UpdateStatement(database: self, sql: sql)
    }
    
    public func execute(sql: String) throws {
        let statement = try updateStatement(sql)
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

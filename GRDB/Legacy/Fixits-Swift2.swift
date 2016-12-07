//
//  Fixits-Swift2.swift
//  GRDB
//
//  Created by Swiftlyfalling.
//
//  Provides automatic renaming Fix-Its for many of the Swift 2.x -> Swift 3 GRDB API changes.
//  Consult the CHANGELOG.md and documentation for details on all of the changes.
//

import Foundation
#if os(iOS)
    import UIKit
#endif

// Database Connections

@available(*, unavailable, renamed:"Database.BusyMode")
public typealias BusyMode = Database.BusyMode

@available(*, unavailable, renamed:"Database.CheckpointMode")
public typealias CheckpointMode = Database.CheckpointMode

@available(*, unavailable, renamed:"Database.TransactionKind")
public typealias TransactionKind = Database.TransactionKind

@available(*, unavailable, renamed:"Database.TransactionCompletion")
public typealias TransactionCompletion = Database.TransactionCompletion

@available(*, unavailable, renamed:"Database.BusyCallback")
public typealias BusyCallback = Database.BusyCallback

extension DatabasePool {
#if os(iOS)
    @available(*, unavailable, renamed:"setupMemoryManagement(in:)")
    public func setupMemoryManagement(application: UIApplication) { }
#endif
#if SQLITE_HAS_CODEC
    @available(*, unavailable, renamed:"change(passphrase:)")
    public func changePassphrase(_ passphrase: String) throws { }
#endif
}

extension DatabaseQueue {
#if os(iOS)
    @available(*, unavailable, renamed:"setupMemoryManagement(in:)")
    public func setupMemoryManagement(application: UIApplication) { }
#endif
#if SQLITE_HAS_CODEC
    @available(*, unavailable, renamed:"change(passphrase:)")
    public func changePassphrase(_ passphrase: String) throws { }
#endif
}

// SQL Functions

extension Database {
    @available(*, unavailable, renamed:"add(function:)")
    public func addFunction(_ function: DatabaseFunction) { }
    
    @available(*, unavailable, renamed:"remove(function:)")
    public func removeFunction(_ function: DatabaseFunction) { }
}

extension DatabasePool {
    @available(*, unavailable, renamed:"add(function:)")
    public func addFunction(_ function: DatabaseFunction) { }
    
    @available(*, unavailable, renamed:"remove(function:)")
    public func removeFunction(_ function: DatabaseFunction) { }
}

extension DatabaseQueue {
    @available(*, unavailable, renamed:"add(function:)")
    public func addFunction(_ function: DatabaseFunction) { }
    
    @available(*, unavailable, renamed:"remove(function:)")
    public func removeFunction(_ function: DatabaseFunction) { }
}

extension DatabaseReader {
    @available(*, unavailable, renamed:"add(function:)")
    public func addFunction(_ function: DatabaseFunction) { }
    
    @available(*, unavailable, renamed:"remove(function:)")
    public func removeFunction(_ function: DatabaseFunction) { }
}

extension DatabaseFunction {
    @available(*, unavailable, renamed:"capitalize")
    public static let capitalizedString = capitalize
    
    @available(*, unavailable, renamed:"lowercase")
    public static let lowercaseString = lowercase
    
    @available(*, unavailable, renamed:"uppercase")
    public static let uppercaseString = uppercase
}

@available(iOS 9.0, OSX 10.11, watchOS 3.0, *)
extension DatabaseFunction {
    @available(*, unavailable, renamed:"localizedCapitalize")
    public static let localizedCapitalizedString = localizedCapitalize
    
    @available(*, unavailable, renamed:"localizedLowercase")
    public static let localizedLowercaseString = localizedLowercase
    
    @available(*, unavailable, renamed:"localizedUppercase")
    public static let localizedUppercaseString = localizedUppercase
}

// SQL Collations

extension Database {
    @available(*, unavailable, renamed:"add(collation:)")
    public func addCollation(_ collation: DatabaseCollation) { }
    
    @available(*, unavailable, renamed:"remove(collation:)")
    public func removeCollation(_ collation: DatabaseCollation) { }
}

extension DatabasePool {
    @available(*, unavailable, renamed:"add(collation:)")
    public func addCollation(_ collation: DatabaseCollation) { }
    
    @available(*, unavailable, renamed:"remove(collation:)")
    public func removeCollation(_ collation: DatabaseCollation) { }
}

extension DatabaseQueue {
    @available(*, unavailable, renamed:"add(collation:)")
    public func addCollation(_ collation: DatabaseCollation) { }
    
    @available(*, unavailable, renamed:"remove(collation:)")
    public func removeCollation(_ collation: DatabaseCollation) { }
}

extension DatabaseReader {
    @available(*, unavailable, renamed:"add(collation:)")
    public func addCollation(_ collation: DatabaseCollation) { }
    
    @available(*, unavailable, renamed:"remove(collation:)")
    public func removeCollation(_ collation: DatabaseCollation) { }
}

// Prepared Statements

extension Database {
    @available(*, unavailable, renamed:"makeSelectStatement(_:)")
    func selectStatement(_ sql: String) throws -> SelectStatement { preconditionFailure() }
    
    @available(*, unavailable, renamed:"makeUpdateStatement(_:)")
    func updateStatement(_ sql: String) throws -> UpdateStatement { preconditionFailure() }
}

extension Statement {
    @available(*, unavailable, renamed:"validate(arguments:)")
    public func validateArguments(_ arguments: StatementArguments) throws { }
}

// Transaction Observers

extension Database {
    @available(*, unavailable, message:"Use add(transactionObserver:) instead. Database events filtering is now performed by transaction observers themselves.")
    public func addTransactionObserver(_ transactionObserver: TransactionObserver, forDatabaseEvents filter: ((DatabaseEventKind) -> Bool)? = nil) { }
    
    @available(*, unavailable, renamed:"remove(transactionObserver:)")
    public func removeTransactionObserver(_ transactionObserver: TransactionObserver) { }
}

extension DatabaseWriter {
    @available(*, unavailable, message:"Use add(transactionObserver:) instead. Database events filtering is now performed by transaction observers themselves.")
    public func addTransactionObserver(_ transactionObserver: TransactionObserver, forDatabaseEvents filter: ((DatabaseEventKind) -> Bool)? = nil) { }
    
    @available(*, unavailable, renamed:"remove(transactionObserver:)")
    public func removeTransactionObserver(_ transactionObserver: TransactionObserver) { }
}

@available(*, unavailable, renamed:"TransactionObserver")
public typealias TransactionObserverType = TransactionObserver

// Query Interface

@available(*, unavailable, renamed:"Column")
public typealias SQLColumn = Column

extension SQLSpecificExpressible {
    @available(*, unavailable, renamed:"capitalized")
    public var capitalizedString: SQLExpression { get { return capitalized } }
    
    @available(*, unavailable, renamed:"lowercased")
    public var lowercaseString: SQLExpression { get { return lowercased } }
    
    @available(*, unavailable, renamed:"uppercased")
    public var uppercaseString: SQLExpression { get { return uppercased } }
}

@available(iOS 9.0, OSX 10.11, watchOS 3.0, *)
extension SQLSpecificExpressible {
    @available(*, unavailable, renamed:"localizedCapitalized")
    public var localizedCapitalizedString: SQLExpression { get { return localizedCapitalized } }
    
    @available(*, unavailable, renamed:"localizedLowercased")
    public var localizedLowercaseString: SQLExpression { get { return localizedLowercased } }
    
    @available(*, unavailable, renamed:"localizedUppercased")
    public var localizedUppercaseString: SQLExpression { get { return localizedUppercased } }
}

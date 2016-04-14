import CoreGraphics
import Foundation
import GRDB.GRDB_Bridging
import GRDB
import GRDB.Swift
import SQLiteMacOSX

public var GRDB_VersionNumber: Double
extension ClosedInterval where Bound : _SQLExpressionType {
    public func contains(element: _SQLDerivedExpressionType) -> GRDB._SQLExpression
}

extension ClosedInterval where Bound : _SQLExpressionType {
    public func contains(element: GRDB._SQLCollatedExpression) -> GRDB._SQLExpression
}

extension Double : DatabaseValueConvertible, StatementColumnConvertible {
    public init(sqliteStatement: GRDB.SQLiteStatement, index: Int32)
    public var databaseValue: GRDB.DatabaseValue { get }
    public static func fromDatabaseValue(databaseValue: GRDB.DatabaseValue) -> Double?
}

extension NSString : DatabaseValueConvertible {
    public var databaseValue: GRDB.DatabaseValue { get }
    public class func fromDatabaseValue(databaseValue: GRDB.DatabaseValue) -> Self?
}

extension NSURL : DatabaseValueConvertible {
    public var databaseValue: GRDB.DatabaseValue { get }
    public class func fromDatabaseValue(databaseValue: GRDB.DatabaseValue) -> Self?
}

extension Int32 : DatabaseValueConvertible, StatementColumnConvertible {
    public init(sqliteStatement: GRDB.SQLiteStatement, index: Int32)
    public var databaseValue: GRDB.DatabaseValue { get }
    public static func fromDatabaseValue(databaseValue: GRDB.DatabaseValue) -> Int32?
}

extension Range where Element : protocol<_SQLExpressionType, BidirectionalIndexType> {
    public func contains(element: _SQLDerivedExpressionType) -> GRDB._SQLExpression
}

extension Int : DatabaseValueConvertible, StatementColumnConvertible {
    public init(sqliteStatement: GRDB.SQLiteStatement, index: Int32)
    public var databaseValue: GRDB.DatabaseValue { get }
    public static func fromDatabaseValue(databaseValue: GRDB.DatabaseValue) -> Int?
}

extension Optional where Wrapped : DatabaseValueConvertible {
    @warn_unused_result
    public static func fetch(statement: GRDB.SelectStatement, arguments: GRDB.StatementArguments? = default) -> GRDB.DatabaseSequence<Wrapped?>
    @warn_unused_result
    public static func fetchAll(statement: GRDB.SelectStatement, arguments: GRDB.StatementArguments? = default) -> [Wrapped?]
    @warn_unused_result
    public static func fetch(db: GRDB.Database, _ sql: String, arguments: GRDB.StatementArguments? = default) -> GRDB.DatabaseSequence<Wrapped?>
    @warn_unused_result
    public static func fetchAll(db: GRDB.Database, _ sql: String, arguments: GRDB.StatementArguments? = default) -> [Wrapped?]
}

extension Optional where Wrapped : DatabaseValueConvertible {
    @warn_unused_result
    public static func fetch<T>(db: GRDB.Database, _ request: GRDB.FetchRequest<T>) -> GRDB.DatabaseSequence<Wrapped?>
    @warn_unused_result
    public static func fetchAll<T>(db: GRDB.Database, _ request: GRDB.FetchRequest<T>) -> [Wrapped?]
}

extension NSDate : DatabaseValueConvertible {
    public var databaseValue: GRDB.DatabaseValue { get }
    public class func fromDatabaseValue(databaseValue: GRDB.DatabaseValue) -> Self?
}

extension NSData : DatabaseValueConvertible {
    public var databaseValue: GRDB.DatabaseValue { get }
    public class func fromDatabaseValue(databaseValue: GRDB.DatabaseValue) -> Self?
}

extension NSNull : DatabaseValueConvertible {
    public var databaseValue: GRDB.DatabaseValue { get }
    public class func fromDatabaseValue(databaseValue: GRDB.DatabaseValue) -> Self?
}

extension String : DatabaseValueConvertible, StatementColumnConvertible {
    public init(sqliteStatement: GRDB.SQLiteStatement, index: Int32)
    public var databaseValue: GRDB.DatabaseValue { get }
    public static func fromDatabaseValue(databaseValue: GRDB.DatabaseValue) -> String?
}

extension String {
    public var quotedDatabaseIdentifier: String { get }
}

extension Int64 : DatabaseValueConvertible, StatementColumnConvertible {
    public init(sqliteStatement: GRDB.SQLiteStatement, index: Int32)
    public var databaseValue: GRDB.DatabaseValue { get }
    public static func fromDatabaseValue(databaseValue: GRDB.DatabaseValue) -> Int64?
}

extension HalfOpenInterval where Bound : _SQLExpressionType {
    public func contains(element: _SQLDerivedExpressionType) -> GRDB._SQLExpression
}

extension HalfOpenInterval where Bound : _SQLExpressionType {
    public func contains(element: GRDB._SQLCollatedExpression) -> GRDB._SQLExpression
}

extension CGFloat : DatabaseValueConvertible {
    public var databaseValue: GRDB.DatabaseValue { get }
    public static func fromDatabaseValue(databaseValue: GRDB.DatabaseValue) -> CGFloat?
}

extension RawRepresentable where Self : DatabaseValueConvertible, Self.RawValue : DatabaseValueConvertible {
    public var databaseValue: GRDB.DatabaseValue { get }
    public static func fromDatabaseValue(databaseValue: GRDB.DatabaseValue) -> Self?
}

extension Bool : DatabaseValueConvertible, StatementColumnConvertible {
    public init(sqliteStatement: GRDB.SQLiteStatement, index: Int32)
    public var databaseValue: GRDB.DatabaseValue { get }
    public static func fromDatabaseValue(databaseValue: GRDB.DatabaseValue) -> Bool?
}

extension NSNumber : DatabaseValueConvertible {
    public var databaseValue: GRDB.DatabaseValue { get }
    public class func fromDatabaseValue(databaseValue: GRDB.DatabaseValue) -> Self?
}

extension SequenceType where Self.Generator.Element : _SQLExpressionType {
    public func contains(element: _SQLDerivedExpressionType) -> GRDB._SQLExpression
}

extension SequenceType where Self.Generator.Element : _SQLExpressionType {
    public func contains(element: GRDB._SQLCollatedExpression) -> GRDB._SQLExpression
}

extension Float : DatabaseValueConvertible, StatementColumnConvertible {
    public init(sqliteStatement: GRDB.SQLiteStatement, index: Int32)
    public var databaseValue: GRDB.DatabaseValue { get }
    public static func fromDatabaseValue(databaseValue: GRDB.DatabaseValue) -> Float?
}

prefix public func !(value: _SQLDerivedExpressionType) -> GRDB._SQLExpression

public func !=(lhs: _SQLDerivedExpressionType, rhs: _SQLDerivedExpressionType) -> GRDB._SQLExpression

public func !=(lhs: protocol<_SQLExpressionType, BooleanType>?, rhs: _SQLDerivedExpressionType) -> GRDB._SQLExpression

public func !=(lhs: _SQLExpressionType?, rhs: _SQLDerivedExpressionType) -> GRDB._SQLExpression

public func !=(lhs: _SQLDerivedExpressionType, rhs: protocol<_SQLExpressionType, BooleanType>?) -> GRDB._SQLExpression

public func !=(lhs: _SQLDerivedExpressionType, rhs: _SQLExpressionType?) -> GRDB._SQLExpression

public func !=(lhs: _SQLExpressionType?, rhs: GRDB._SQLCollatedExpression) -> GRDB._SQLExpression

public func !=(lhs: GRDB._SQLCollatedExpression, rhs: _SQLExpressionType?) -> GRDB._SQLExpression

public func !==(lhs: GRDB._SQLCollatedExpression, rhs: _SQLExpressionType?) -> GRDB._SQLExpression

public func !==(lhs: _SQLDerivedExpressionType, rhs: _SQLDerivedExpressionType) -> GRDB._SQLExpression

public func !==(lhs: _SQLExpressionType?, rhs: _SQLDerivedExpressionType) -> GRDB._SQLExpression

public func !==(lhs: _SQLDerivedExpressionType, rhs: _SQLExpressionType?) -> GRDB._SQLExpression

public func !==(lhs: _SQLExpressionType?, rhs: GRDB._SQLCollatedExpression) -> GRDB._SQLExpression

public func &&(lhs: _SQLDerivedExpressionType, rhs: _SQLExpressionType) -> GRDB._SQLExpression

public func &&(lhs: _SQLExpressionType, rhs: _SQLDerivedExpressionType) -> GRDB._SQLExpression

public func &&(lhs: _SQLDerivedExpressionType, rhs: _SQLDerivedExpressionType) -> GRDB._SQLExpression

public func *(lhs: _SQLDerivedExpressionType, rhs: _SQLDerivedExpressionType) -> GRDB._SQLExpression

public func *(lhs: _SQLExpressionType, rhs: _SQLDerivedExpressionType) -> GRDB._SQLExpression

public func *(lhs: _SQLDerivedExpressionType, rhs: _SQLExpressionType) -> GRDB._SQLExpression

public func +(lhs: _SQLDerivedExpressionType, rhs: _SQLDerivedExpressionType) -> GRDB._SQLExpression

public func +(lhs: _SQLExpressionType, rhs: _SQLDerivedExpressionType) -> GRDB._SQLExpression

public func +(lhs: _SQLDerivedExpressionType, rhs: _SQLExpressionType) -> GRDB._SQLExpression

prefix public func -(value: _SQLDerivedExpressionType) -> GRDB._SQLExpression

public func -(lhs: _SQLDerivedExpressionType, rhs: _SQLExpressionType) -> GRDB._SQLExpression

public func -(lhs: _SQLExpressionType, rhs: _SQLDerivedExpressionType) -> GRDB._SQLExpression

public func -(lhs: _SQLDerivedExpressionType, rhs: _SQLDerivedExpressionType) -> GRDB._SQLExpression

public func /(lhs: _SQLDerivedExpressionType, rhs: _SQLExpressionType) -> GRDB._SQLExpression

public func /(lhs: _SQLExpressionType, rhs: _SQLDerivedExpressionType) -> GRDB._SQLExpression

public func /(lhs: _SQLDerivedExpressionType, rhs: _SQLDerivedExpressionType) -> GRDB._SQLExpression

public func <(lhs: _SQLDerivedExpressionType, rhs: _SQLExpressionType) -> GRDB._SQLExpression

public func <(lhs: GRDB._SQLCollatedExpression, rhs: _SQLExpressionType) -> GRDB._SQLExpression

public func <(lhs: _SQLExpressionType, rhs: GRDB._SQLCollatedExpression) -> GRDB._SQLExpression

public func <(lhs: _SQLExpressionType, rhs: _SQLDerivedExpressionType) -> GRDB._SQLExpression

public func <(lhs: _SQLDerivedExpressionType, rhs: _SQLDerivedExpressionType) -> GRDB._SQLExpression

public func <=(lhs: _SQLDerivedExpressionType, rhs: _SQLExpressionType) -> GRDB._SQLExpression

public func <=(lhs: _SQLDerivedExpressionType, rhs: _SQLDerivedExpressionType) -> GRDB._SQLExpression

public func <=(lhs: _SQLExpressionType, rhs: _SQLDerivedExpressionType) -> GRDB._SQLExpression

public func <=(lhs: _SQLExpressionType, rhs: GRDB._SQLCollatedExpression) -> GRDB._SQLExpression

public func <=(lhs: GRDB._SQLCollatedExpression, rhs: _SQLExpressionType) -> GRDB._SQLExpression

public func ==(lhs: GRDB.Row, rhs: GRDB.Row) -> Bool

public func ==(lhs: GRDB.RowIndex, rhs: GRDB.RowIndex) -> Bool

public func ==(lhs: _SQLDerivedExpressionType, rhs: _SQLExpressionType?) -> GRDB._SQLExpression

public func ==(lhs: GRDB.DatabaseValue, rhs: GRDB.DatabaseValue) -> Bool

public func ==(lhs: _SQLExpressionType?, rhs: GRDB._SQLCollatedExpression) -> GRDB._SQLExpression

public func ==(lhs: GRDB._SQLCollatedExpression, rhs: _SQLExpressionType?) -> GRDB._SQLExpression

public func ==(lhs: GRDB.DatabaseCollation, rhs: GRDB.DatabaseCollation) -> Bool

public func ==(lhs: _SQLDerivedExpressionType, rhs: protocol<_SQLExpressionType, BooleanType>?) -> GRDB._SQLExpression

public func ==(lhs: GRDB.DatabaseFunction, rhs: GRDB.DatabaseFunction) -> Bool

public func ==(lhs: _SQLDerivedExpressionType, rhs: _SQLDerivedExpressionType) -> GRDB._SQLExpression

public func ==(lhs: protocol<_SQLExpressionType, BooleanType>?, rhs: _SQLDerivedExpressionType) -> GRDB._SQLExpression

public func ==(lhs: _SQLExpressionType?, rhs: _SQLDerivedExpressionType) -> GRDB._SQLExpression

public func ===(lhs: _SQLDerivedExpressionType, rhs: _SQLDerivedExpressionType) -> GRDB._SQLExpression

public func ===(lhs: GRDB._SQLCollatedExpression, rhs: _SQLExpressionType?) -> GRDB._SQLExpression

public func ===(lhs: _SQLExpressionType?, rhs: GRDB._SQLCollatedExpression) -> GRDB._SQLExpression

public func ===(lhs: _SQLDerivedExpressionType, rhs: _SQLExpressionType?) -> GRDB._SQLExpression

public func ===(lhs: _SQLExpressionType?, rhs: _SQLDerivedExpressionType) -> GRDB._SQLExpression

public func >(lhs: GRDB._SQLCollatedExpression, rhs: _SQLExpressionType) -> GRDB._SQLExpression

public func >(lhs: _SQLExpressionType, rhs: GRDB._SQLCollatedExpression) -> GRDB._SQLExpression

public func >(lhs: _SQLDerivedExpressionType, rhs: _SQLExpressionType) -> GRDB._SQLExpression

public func >(lhs: _SQLExpressionType, rhs: _SQLDerivedExpressionType) -> GRDB._SQLExpression

public func >(lhs: _SQLDerivedExpressionType, rhs: _SQLDerivedExpressionType) -> GRDB._SQLExpression

public func >=(lhs: GRDB._SQLCollatedExpression, rhs: _SQLExpressionType) -> GRDB._SQLExpression

public func >=(lhs: _SQLExpressionType, rhs: GRDB._SQLCollatedExpression) -> GRDB._SQLExpression

public func >=(lhs: _SQLDerivedExpressionType, rhs: _SQLExpressionType) -> GRDB._SQLExpression

public func >=(lhs: _SQLExpressionType, rhs: _SQLDerivedExpressionType) -> GRDB._SQLExpression

public func >=(lhs: _SQLDerivedExpressionType, rhs: _SQLDerivedExpressionType) -> GRDB._SQLExpression

public func ??(lhs: _SQLDerivedExpressionType, rhs: _SQLExpressionType) -> GRDB._SQLExpression

public func ??(lhs: _SQLExpressionType?, rhs: _SQLDerivedExpressionType) -> GRDB._SQLExpression

public typealias BusyCallback = (numberOfTries: Int) -> Bool

public enum BusyMode {
    case ImmediateError
    case Timeout(NSTimeInterval)
    case Callback(GRDB.BusyCallback)
}

public enum CheckpointMode : Int32 {
    case Passive
    case Full
    case Restart
    case Truncate
}

public struct Configuration {
    public var foreignKeysEnabled: Bool
    public var readonly: Bool
    public var trace: GRDB.TraceFunction?
    public var fileAttributes: [String : AnyObject]?
    public var defaultTransactionKind: GRDB.TransactionKind
    public var busyMode: GRDB.BusyMode
    public init()
}

final public class Database {
    public let configuration: GRDB.Configuration
    public let sqliteConnection: GRDB.SQLiteConnection
}

extension Database {
    @warn_unused_result
    public func selectStatement(sql: String) throws -> GRDB.SelectStatement
    @warn_unused_result
    public func updateStatement(sql: String) throws -> GRDB.UpdateStatement
    public func execute(sql: String, arguments: GRDB.StatementArguments? = default) throws -> GRDB.DatabaseChanges
}

extension Database {
    public func addFunction(function: GRDB.DatabaseFunction)
    public func removeFunction(function: GRDB.DatabaseFunction)
}

extension Database {
    public func addCollation(collation: GRDB.DatabaseCollation)
    public func removeCollation(collation: GRDB.DatabaseCollation)
}

extension Database {
    public func clearSchemaCache()
    public func tableExists(tableName: String) -> Bool
}

extension Database {
    public func inTransaction(kind: GRDB.TransactionKind? = default, @noescape _ block: () throws -> GRDB.TransactionCompletion) throws
    public func addTransactionObserver(transactionObserver: TransactionObserverType)
    public func removeTransactionObserver(transactionObserver: TransactionObserverType)
}

public struct DatabaseChanges {
    public let changedRowCount: Int
    public let insertedRowID: Int64?
}

public struct DatabaseCoder : DatabaseValueConvertible {
    public let object: AnyObject
    public init?(_ object: AnyObject?)
    public var databaseValue: GRDB.DatabaseValue { get }
    public static func fromDatabaseValue(databaseValue: GRDB.DatabaseValue) -> GRDB.DatabaseCoder?
}

final public class DatabaseCollation {
    public let name: String
    public init(_ name: String, function: (String, String) -> NSComparisonResult)
}

extension DatabaseCollation : Hashable {
    public var hashValue: Int { get }
}

extension DatabaseCollation {
    public class let unicodeCompare: GRDB.DatabaseCollation
    public class let caseInsensitiveCompare: GRDB.DatabaseCollation
    public class let localizedCaseInsensitiveCompare: GRDB.DatabaseCollation
    public class let localizedCompare: GRDB.DatabaseCollation
    public class let localizedStandardCompare: GRDB.DatabaseCollation
}

public struct DatabaseDateComponents : DatabaseValueConvertible {
    public enum Format : String {
        case YMD
        case YMD_HM
        case YMD_HMS
        case YMD_HMSS
        case HM
        case HMS
        case HMSS
    }
    public let dateComponents: NSDateComponents
    public let format: GRDB.DatabaseDateComponents.Format
    public init?(_ dateComponents: NSDateComponents?, format: GRDB.DatabaseDateComponents.Format)
    public var databaseValue: GRDB.DatabaseValue { get }
    public static func fromDatabaseValue(databaseValue: GRDB.DatabaseValue) -> GRDB.DatabaseDateComponents?
}

public struct DatabaseError : ErrorType {
    public let code: Int32
    public let message: String?
    public let sql: String?
    public init(code: Int32 = default, message: String? = default, sql: String? = default, arguments: GRDB.StatementArguments? = default)
}

extension DatabaseError : CustomStringConvertible {
    public var description: String { get }
}

public struct DatabaseEvent {
    public enum Kind : Int32 {
        case Insert
        case Delete
        case Update
    }
    public let kind: GRDB.DatabaseEvent.Kind
    public var databaseName: String { get }
    public var tableName: String { get }
    public let rowID: Int64
}

final public class DatabaseFunction {
    public let name: String
    public init(_ name: String, argumentCount: Int32? = default, pure: Bool = default, function: [GRDB.DatabaseValue] throws -> DatabaseValueConvertible?)
}

extension DatabaseFunction {
    public func apply(arguments: _SQLExpressionType...) -> GRDB._SQLExpression
}

extension DatabaseFunction : Hashable {
    public var hashValue: Int { get }
}

extension DatabaseFunction {
    public class let capitalizedString: GRDB.DatabaseFunction
    public class let lowercaseString: GRDB.DatabaseFunction
    public class let uppercaseString: GRDB.DatabaseFunction
}

extension DatabaseFunction {
    public class let localizedCapitalizedString: GRDB.DatabaseFunction
    public class let localizedLowercaseString: GRDB.DatabaseFunction
    public class let localizedUppercaseString: GRDB.DatabaseFunction
}

public class DatabaseGenerator<Element> : GeneratorType {
    @warn_unused_result
    public func next() -> Element?
}

public struct DatabaseMigrator {
    public init()
    public mutating func registerMigration(identifier: String, withDisabledForeignKeyChecks disabledForeignKeyChecks: Bool = default, migrate: (GRDB.Database) throws -> Void)
    public func migrate(db: DatabaseWriter) throws
}

final public class DatabasePool {
    public init(path: String, configuration: GRDB.Configuration = default, maximumReaderCount: Int = default) throws
    public var path: String { get }
    public func checkpoint(kind: GRDB.CheckpointMode = default) throws
    public func releaseMemory()
}

extension DatabasePool : DatabaseReader {
    public func read<T>(block: (db: GRDB.Database) throws -> T) rethrows -> T
    public func nonIsolatedRead<T>(block: (db: GRDB.Database) throws -> T) rethrows -> T
    public func addFunction(function: GRDB.DatabaseFunction)
    public func removeFunction(function: GRDB.DatabaseFunction)
    public func addCollation(collation: GRDB.DatabaseCollation)
    public func removeCollation(collation: GRDB.DatabaseCollation)
}

extension DatabasePool : DatabaseWriter {
    public func write<T>(block: (db: GRDB.Database) throws -> T) rethrows -> T
    public func writeInTransaction(kind: GRDB.TransactionKind? = default, _ block: (db: GRDB.Database) throws -> GRDB.TransactionCompletion) throws
    public func readFromWrite(block: (db: GRDB.Database) -> Void)
}

final public class DatabaseQueue {
    public init(path: String, configuration: GRDB.Configuration = default) throws
    public init(configuration: GRDB.Configuration = default)
    public var configuration: GRDB.Configuration { get }
    public var path: String! { get }
    public func inDatabase<T>(block: (db: GRDB.Database) throws -> T) rethrows -> T
    public func inTransaction(kind: GRDB.TransactionKind? = default, _ block: (db: GRDB.Database) throws -> GRDB.TransactionCompletion) throws
    public func releaseMemory()
}

extension DatabaseQueue : DatabaseReader {
    public func read<T>(block: (db: GRDB.Database) throws -> T) rethrows -> T
    public func nonIsolatedRead<T>(block: (db: GRDB.Database) throws -> T) rethrows -> T
    public func addFunction(function: GRDB.DatabaseFunction)
    public func removeFunction(function: GRDB.DatabaseFunction)
    public func addCollation(collation: GRDB.DatabaseCollation)
    public func removeCollation(collation: GRDB.DatabaseCollation)
}

extension DatabaseQueue : DatabaseWriter {
    public func write<T>(block: (db: GRDB.Database) throws -> T) rethrows -> T
    public func readFromWrite(block: (db: GRDB.Database) -> Void)
}

public protocol DatabaseReader : class {
    public func read<T>(block: (db: GRDB.Database) throws -> T) rethrows -> T
    public func nonIsolatedRead<T>(block: (db: GRDB.Database) throws -> T) rethrows -> T
    public func addFunction(function: GRDB.DatabaseFunction)
    public func removeFunction(function: GRDB.DatabaseFunction)
    public func addCollation(collation: GRDB.DatabaseCollation)
    public func removeCollation(collation: GRDB.DatabaseCollation)
}

public struct DatabaseSequence<Element> : SequenceType {
    @warn_unused_result
    public func generate() -> GRDB.DatabaseGenerator<Element>
}

public struct DatabaseValue {
    public enum Storage {
        case Null
        case Int64(Int64)
        case Double(Double)
        case String(String)
        case Blob(NSData)
    }
    public let storage: GRDB.DatabaseValue.Storage
    public static let Null: GRDB.DatabaseValue
    public var isNull: Bool { get }
    public func value() -> DatabaseValueConvertible?
    @warn_unused_result
    public func value<Value : DatabaseValueConvertible>() -> Value?
    @warn_unused_result
    public func value<Value : DatabaseValueConvertible>() -> Value
    @warn_unused_result
    public func failableValue<Value : DatabaseValueConvertible>() -> Value?
}

extension DatabaseValue : Hashable {
    public var hashValue: Int { get }
}

extension DatabaseValue : DatabaseValueConvertible {
    public var databaseValue: GRDB.DatabaseValue { get }
    public static func fromDatabaseValue(databaseValue: GRDB.DatabaseValue) -> GRDB.DatabaseValue?
}

extension DatabaseValue : StatementColumnConvertible {
    public init(sqliteStatement: GRDB.SQLiteStatement, index: Int32)
}

extension DatabaseValue : CustomStringConvertible {
    public var description: String { get }
}

extension DatabaseValue {
    public init?(object: AnyObject)
    public func toAnyObject() -> AnyObject
}

public protocol DatabaseValueConvertible : _SQLExpressionType {
    public var databaseValue: GRDB.DatabaseValue { get }
    public static func fromDatabaseValue(databaseValue: GRDB.DatabaseValue) -> Self?
}

extension DatabaseValueConvertible {
    @warn_unused_result
    public static func fetch<T>(db: GRDB.Database, _ request: GRDB.FetchRequest<T>) -> GRDB.DatabaseSequence<Self>
    @warn_unused_result
    public static func fetchAll<T>(db: GRDB.Database, _ request: GRDB.FetchRequest<T>) -> [Self]
    @warn_unused_result
    public static func fetchOne<T>(db: GRDB.Database, _ request: GRDB.FetchRequest<T>) -> Self?
}

extension DatabaseValueConvertible where Self : StatementColumnConvertible {
    @warn_unused_result
    public static func fetch<T>(db: GRDB.Database, _ request: GRDB.FetchRequest<T>) -> GRDB.DatabaseSequence<Self>
    @warn_unused_result
    public static func fetchAll<T>(db: GRDB.Database, _ request: GRDB.FetchRequest<T>) -> [Self]
    @warn_unused_result
    public static func fetchOne<T>(db: GRDB.Database, _ request: GRDB.FetchRequest<T>) -> Self?
}

extension DatabaseValueConvertible {
    @warn_unused_result
    public static func fetch(statement: GRDB.SelectStatement, arguments: GRDB.StatementArguments? = default) -> GRDB.DatabaseSequence<Self>
    @warn_unused_result
    public static func fetchAll(statement: GRDB.SelectStatement, arguments: GRDB.StatementArguments? = default) -> [Self]
    @warn_unused_result
    public static func fetchOne(statement: GRDB.SelectStatement, arguments: GRDB.StatementArguments? = default) -> Self?
    @warn_unused_result
    public static func fetch(db: GRDB.Database, _ sql: String, arguments: GRDB.StatementArguments? = default) -> GRDB.DatabaseSequence<Self>
    @warn_unused_result
    public static func fetchAll(db: GRDB.Database, _ sql: String, arguments: GRDB.StatementArguments? = default) -> [Self]
    @warn_unused_result
    public static func fetchOne(db: GRDB.Database, _ sql: String, arguments: GRDB.StatementArguments? = default) -> Self?
}

extension DatabaseValueConvertible {
    public var sqlExpression: GRDB._SQLExpression { get }
}

extension DatabaseValueConvertible where Self : StatementColumnConvertible {
    @warn_unused_result
    public static func fetch(statement: GRDB.SelectStatement, arguments: GRDB.StatementArguments? = default) -> GRDB.DatabaseSequence<Self>
    @warn_unused_result
    public static func fetchAll(statement: GRDB.SelectStatement, arguments: GRDB.StatementArguments? = default) -> [Self]
    @warn_unused_result
    public static func fetchOne(statement: GRDB.SelectStatement, arguments: GRDB.StatementArguments? = default) -> Self?
    @warn_unused_result
    public static func fetch(db: GRDB.Database, _ sql: String, arguments: GRDB.StatementArguments? = default) -> GRDB.DatabaseSequence<Self>
    @warn_unused_result
    public static func fetchAll(db: GRDB.Database, _ sql: String, arguments: GRDB.StatementArguments? = default) -> [Self]
    @warn_unused_result
    public static func fetchOne(db: GRDB.Database, _ sql: String, arguments: GRDB.StatementArguments? = default) -> Self?
}

public protocol DatabaseWriter : DatabaseReader {
    public func write<T>(block: (db: GRDB.Database) throws -> T) rethrows -> T
    public func readFromWrite(block: (db: GRDB.Database) -> Void)
}

extension DatabaseWriter {
    public func addTransactionObserver(transactionObserver: TransactionObserverType)
    public func removeTransactionObserver(transactionObserver: TransactionObserverType)
}

public struct FetchRequest<T> {
    public init(tableName: String)
    @warn_unused_result
    public func selectStatement(database: GRDB.Database) throws -> GRDB.SelectStatement
}

extension FetchRequest {
    @warn_unused_result
    public func select(selection: _SQLSelectable...) -> GRDB.FetchRequest<T>
    @warn_unused_result
    public func select(selection: [_SQLSelectable]) -> GRDB.FetchRequest<T>
    @warn_unused_result
    public func select(sql sql: String) -> GRDB.FetchRequest<T>
    public var distinct: GRDB.FetchRequest<T> { get }
    @warn_unused_result
    public func filter(predicate: _SQLExpressionType) -> GRDB.FetchRequest<T>
    @warn_unused_result
    public func filter(sql sql: String) -> GRDB.FetchRequest<T>
    @warn_unused_result
    public func group(expressions: _SQLExpressionType...) -> GRDB.FetchRequest<T>
    @warn_unused_result
    public func group(expressions: [_SQLExpressionType]) -> GRDB.FetchRequest<T>
    @warn_unused_result
    public func group(sql sql: String) -> GRDB.FetchRequest<T>
    @warn_unused_result
    public func having(predicate: _SQLExpressionType) -> GRDB.FetchRequest<T>
    @warn_unused_result
    public func having(sql sql: String) -> GRDB.FetchRequest<T>
    @warn_unused_result
    public func order(sortDescriptors: _SQLSortDescriptorType...) -> GRDB.FetchRequest<T>
    @warn_unused_result
    public func order(sortDescriptors: [_SQLSortDescriptorType]) -> GRDB.FetchRequest<T>
    @warn_unused_result
    public func order(sql sql: String) -> GRDB.FetchRequest<T>
    @warn_unused_result
    public func reverse() -> GRDB.FetchRequest<T>
    @warn_unused_result
    public func limit(limit: Int, offset: Int? = default) -> GRDB.FetchRequest<T>
}

extension FetchRequest {
    @warn_unused_result
    public func fetchCount(db: GRDB.Database) -> Int
}

extension FetchRequest {
    public func contains(element: _SQLExpressionType) -> GRDB._SQLExpression
    public var exists: GRDB._SQLExpression { get }
}

extension FetchRequest where T : RowConvertible {
    @warn_unused_result
    public func fetch(db: GRDB.Database) -> GRDB.DatabaseSequence<T>
    @warn_unused_result
    public func fetchAll(db: GRDB.Database) -> [T]
    @warn_unused_result
    public func fetchOne(db: GRDB.Database) -> T?
}

public func LogSQL(sql: String)

public protocol MutablePersistable : TableMapping {
    public var persistentDictionary: [String : DatabaseValueConvertible?] { get }
    public mutating func didInsertWithRowID(rowID: Int64, forColumn column: String?)
    public mutating func insert(db: GRDB.Database) throws
    public func update(db: GRDB.Database) throws
    public mutating func save(db: GRDB.Database) throws
    public func delete(db: GRDB.Database) throws -> Bool
    public func exists(db: GRDB.Database) -> Bool
}

extension MutablePersistable {
    public mutating func didInsertWithRowID(rowID: Int64, forColumn column: String?)
    public mutating func insert(db: GRDB.Database) throws
    public func update(db: GRDB.Database) throws
    public mutating func save(db: GRDB.Database) throws
    public func delete(db: GRDB.Database) throws -> Bool
    public func exists(db: GRDB.Database) -> Bool
    public mutating func performInsert(db: GRDB.Database) throws
    public func performUpdate(db: GRDB.Database) throws
    public mutating func performSave(db: GRDB.Database) throws
    public func performDelete(db: GRDB.Database) throws -> Bool
    public func performExists(db: GRDB.Database) -> Bool
}

public protocol Persistable : MutablePersistable {
    public func didInsertWithRowID(rowID: Int64, forColumn column: String?)
    public func insert(db: GRDB.Database) throws
    public func save(db: GRDB.Database) throws
}

extension Persistable {
    public func didInsertWithRowID(rowID: Int64, forColumn column: String?)
    public func insert(db: GRDB.Database) throws
    public func save(db: GRDB.Database) throws
    public func performInsert(db: GRDB.Database) throws
    public func performSave(db: GRDB.Database) throws
}

public enum PersistenceError : ErrorType {
    case NotFound(MutablePersistable)
}

extension PersistenceError : CustomStringConvertible {
    public var description: String { get }
}

public class Record : RowConvertible, TableMapping, Persistable {
    public init()
    required public init(_ row: GRDB.Row)
    public func awakeFromFetch(row row: GRDB.Row)
    public class func databaseTableName() -> String
    public var persistentDictionary: [String : DatabaseValueConvertible?] { get }
    public func didInsertWithRowID(rowID: Int64, forColumn column: String?)
    @warn_unused_result
    public func copy() -> Self
    public var hasPersistentChangedValues: Bool
    public var persistentChangedValues: [String : GRDB.DatabaseValue?] { get }
    public func insert(db: GRDB.Database) throws
    public func update(db: GRDB.Database) throws
    final public func save(db: GRDB.Database) throws
    public func delete(db: GRDB.Database) throws -> Bool
}

extension Record : CustomStringConvertible {
    public var description: String { get }
}

final public class Row {
    public init()
    public init(_ dictionary: [String : DatabaseValueConvertible?])
    @warn_unused_result
    public func copy() -> GRDB.Row
}

extension Row {
    @warn_unused_result
    public class func fetch<T>(db: GRDB.Database, _ request: GRDB.FetchRequest<T>) -> GRDB.DatabaseSequence<GRDB.Row>
    @warn_unused_result
    public class func fetchAll<T>(db: GRDB.Database, _ request: GRDB.FetchRequest<T>) -> [GRDB.Row]
    @warn_unused_result
    public class func fetchOne<T>(db: GRDB.Database, _ request: GRDB.FetchRequest<T>) -> GRDB.Row?
}

extension Row {
    public convenience init?(_ dictionary: NSDictionary)
    public func toNSDictionary() -> NSDictionary
}

extension Row {
    public var columnNames: LazyMapCollection<GRDB.Row, String> { get }
    public func hasColumn(columnName: String) -> Bool
}

extension Row {
    @warn_unused_result
    public func value(atIndex index: Int) -> DatabaseValueConvertible?
    @warn_unused_result
    public func value<Value : DatabaseValueConvertible>(atIndex index: Int) -> Value?
    @warn_unused_result
    public func value<Value : protocol<DatabaseValueConvertible, StatementColumnConvertible>>(atIndex index: Int) -> Value?
    @warn_unused_result
    public func value<Value : DatabaseValueConvertible>(atIndex index: Int) -> Value
    @warn_unused_result
    public func value<Value : protocol<DatabaseValueConvertible, StatementColumnConvertible>>(atIndex index: Int) -> Value
    @warn_unused_result
    public func value(named columnName: String) -> DatabaseValueConvertible?
    @warn_unused_result
    public func value<Value : DatabaseValueConvertible>(named columnName: String) -> Value?
    @warn_unused_result
    public func value<Value : protocol<DatabaseValueConvertible, StatementColumnConvertible>>(named columnName: String) -> Value?
    @warn_unused_result
    public func value<Value : DatabaseValueConvertible>(named columnName: String) -> Value
    @warn_unused_result
    public func value<Value : protocol<DatabaseValueConvertible, StatementColumnConvertible>>(named columnName: String) -> Value
    @warn_unused_result
    public func dataNoCopy(atIndex index: Int) -> NSData?
    @warn_unused_result
    public func dataNoCopy(named columnName: String) -> NSData?
    @warn_unused_result
    public func databaseValue(atIndex index: Int) -> GRDB.DatabaseValue
    @warn_unused_result
    public func databaseValue(named columnName: String) -> GRDB.DatabaseValue
}

extension Row {
    public subscript (columnName: String) -> GRDB.DatabaseValue? { get }
    public var databaseValues: LazyMapCollection<GRDB.Row, GRDB.DatabaseValue> { get }
}

extension Row {
    @warn_unused_result
    public class func fetch(statement: GRDB.SelectStatement, arguments: GRDB.StatementArguments? = default) -> GRDB.DatabaseSequence<GRDB.Row>
    @warn_unused_result
    public class func fetchAll(statement: GRDB.SelectStatement, arguments: GRDB.StatementArguments? = default) -> [GRDB.Row]
    @warn_unused_result
    public class func fetchOne(statement: GRDB.SelectStatement, arguments: GRDB.StatementArguments? = default) -> GRDB.Row?
    @warn_unused_result
    public class func fetch(db: GRDB.Database, _ sql: String, arguments: GRDB.StatementArguments? = default) -> GRDB.DatabaseSequence<GRDB.Row>
    @warn_unused_result
    public class func fetchAll(db: GRDB.Database, _ sql: String, arguments: GRDB.StatementArguments? = default) -> [GRDB.Row]
    @warn_unused_result
    public class func fetchOne(db: GRDB.Database, _ sql: String, arguments: GRDB.StatementArguments? = default) -> GRDB.Row?
}

extension Row : CollectionType {
    public var count: Int { get }
    public func generate() -> IndexingGenerator<GRDB.Row>
    public var startIndex: GRDB.RowIndex { get }
    public var endIndex: GRDB.RowIndex { get }
    public subscript (index: GRDB.RowIndex) -> (String, GRDB.DatabaseValue) { get }
}

extension Row : Equatable {
}

extension Row : CustomStringConvertible {
    public var description: String { get }
}

public protocol RowConvertible {
    public init(_ row: GRDB.Row)
    public mutating func awakeFromFetch(row row: GRDB.Row)
}

extension RowConvertible {
    @warn_unused_result
    public static func fetch<T>(db: GRDB.Database, _ request: GRDB.FetchRequest<T>) -> GRDB.DatabaseSequence<Self>
    @warn_unused_result
    public static func fetchAll<T>(db: GRDB.Database, _ request: GRDB.FetchRequest<T>) -> [Self]
    @warn_unused_result
    public static func fetchOne<T>(db: GRDB.Database, _ request: GRDB.FetchRequest<T>) -> Self?
}

extension RowConvertible where Self : TableMapping {
    @warn_unused_result
    public static func fetch(db: GRDB.Database) -> GRDB.DatabaseSequence<Self>
    @warn_unused_result
    public static func fetchAll(db: GRDB.Database) -> [Self]
    @warn_unused_result
    public static func fetchOne(db: GRDB.Database) -> Self?
}

extension RowConvertible where Self : TableMapping {
    @warn_unused_result
    public static func fetch<Sequence : SequenceType where Sequence.Generator.Element : DatabaseValueConvertible>(db: GRDB.Database, keys: Sequence) -> GRDB.DatabaseSequence<Self>
    @warn_unused_result
    public static func fetchAll<Sequence : SequenceType where Sequence.Generator.Element : DatabaseValueConvertible>(db: GRDB.Database, keys: Sequence) -> [Self]
    @warn_unused_result
    public static func fetchOne<PrimaryKeyType : DatabaseValueConvertible>(db: GRDB.Database, key: PrimaryKeyType?) -> Self?
    @warn_unused_result
    public static func fetch(db: GRDB.Database, keys: [[String : DatabaseValueConvertible?]]) -> GRDB.DatabaseSequence<Self>
    @warn_unused_result
    public static func fetchAll(db: GRDB.Database, keys: [[String : DatabaseValueConvertible?]]) -> [Self]
    @warn_unused_result
    public static func fetchOne(db: GRDB.Database, key: [String : DatabaseValueConvertible?]) -> Self?
}

extension RowConvertible {
    public func awakeFromFetch(row row: GRDB.Row)
    @warn_unused_result
    public static func fetch(statement: GRDB.SelectStatement, arguments: GRDB.StatementArguments? = default) -> GRDB.DatabaseSequence<Self>
    @warn_unused_result
    public static func fetchAll(statement: GRDB.SelectStatement, arguments: GRDB.StatementArguments? = default) -> [Self]
    @warn_unused_result
    public static func fetchOne(statement: GRDB.SelectStatement, arguments: GRDB.StatementArguments? = default) -> Self?
    @warn_unused_result
    public static func fetch(db: GRDB.Database, _ sql: String, arguments: GRDB.StatementArguments? = default) -> GRDB.DatabaseSequence<Self>
    @warn_unused_result
    public static func fetchAll(db: GRDB.Database, _ sql: String, arguments: GRDB.StatementArguments? = default) -> [Self]
    @warn_unused_result
    public static func fetchOne(db: GRDB.Database, _ sql: String, arguments: GRDB.StatementArguments? = default) -> Self?
}

public struct RowIndex : ForwardIndexType, BidirectionalIndexType, RandomAccessIndexType {
    public func successor() -> GRDB.RowIndex
    public func predecessor() -> GRDB.RowIndex
    public func distanceTo(other: GRDB.RowIndex) -> Int
    public func advancedBy(n: Int) -> GRDB.RowIndex
}

public struct SQLColumn {
    public let name: String
    public init(_ name: String)
}

extension SQLColumn : _SQLDerivedExpressionType {
    public var sqlExpression: GRDB._SQLExpression { get }
}

public typealias SQLiteConnection = COpaquePointer

public typealias SQLiteStatement = COpaquePointer

final public class SelectStatement : GRDB.Statement {
    lazy public var columnCount: Int
    lazy public var columnNames: [String]
}

public class Statement {
    public let sqliteStatement: GRDB.SQLiteStatement
    public let sql: String
    public var arguments: GRDB.StatementArguments
    public func validateArguments(arguments: GRDB.StatementArguments) throws
    public func unsafeSetArguments(arguments: GRDB.StatementArguments)
}

public struct StatementArguments {
    public var isEmpty: Bool { get }
    public init<Sequence : SequenceType where Sequence.Generator.Element == DatabaseValueConvertible?>(_ sequence: Sequence)
    public init<Sequence : SequenceType where Sequence.Generator.Element : DatabaseValueConvertible>(_ sequence: Sequence)
    public init<Sequence : SequenceType where Sequence.Generator.Element == (String, DatabaseValueConvertible?)>(_ sequence: Sequence)
    public init<Sequence : SequenceType, Value : DatabaseValueConvertible where Sequence.Generator.Element == (String, Value)>(_ sequence: Sequence)
}

extension StatementArguments {
    public init?(_ array: NSArray)
    public init?(_ dictionary: NSDictionary)
}

extension StatementArguments : ArrayLiteralConvertible {
    public init(arrayLiteral elements: DatabaseValueConvertible?...)
}

extension StatementArguments : DictionaryLiteralConvertible {
    public init(dictionaryLiteral elements: (String, DatabaseValueConvertible?)...)
}

extension StatementArguments : CustomStringConvertible {
    public var description: String { get }
}

public protocol StatementColumnConvertible {
    public init(sqliteStatement: GRDB.SQLiteStatement, index: Int32)
}

public protocol TableMapping {
    public static func databaseTableName() -> String
}

extension TableMapping {
    @warn_unused_result
    public static func all() -> GRDB.FetchRequest<Self>
    @warn_unused_result
    public static func select(selection: _SQLSelectable...) -> GRDB.FetchRequest<Self>
    @warn_unused_result
    public static func select(selection: [_SQLSelectable]) -> GRDB.FetchRequest<Self>
    @warn_unused_result
    public static func select(sql sql: String) -> GRDB.FetchRequest<Self>
    @warn_unused_result
    public static func filter(predicate: _SQLExpressionType) -> GRDB.FetchRequest<Self>
    @warn_unused_result
    public static func filter(sql sql: String) -> GRDB.FetchRequest<Self>
    @warn_unused_result
    public static func order(sortDescriptors: _SQLSortDescriptorType...) -> GRDB.FetchRequest<Self>
    @warn_unused_result
    public static func order(sortDescriptors: [_SQLSortDescriptorType]) -> GRDB.FetchRequest<Self>
    @warn_unused_result
    public static func order(sql sql: String) -> GRDB.FetchRequest<Self>
    @warn_unused_result
    public static func limit(limit: Int, offset: Int? = default) -> GRDB.FetchRequest<Self>
}

extension TableMapping {
    @warn_unused_result
    public static func fetchCount(db: GRDB.Database) -> Int
}

public typealias TraceFunction = (String) -> Void

public enum TransactionCompletion {
    case Commit
    case Rollback
}

public enum TransactionKind {
    case Deferred
    case Immediate
    case Exclusive
}

public protocol TransactionObserverType : class {
    public func databaseDidChangeWithEvent(event: GRDB.DatabaseEvent)
    public func databaseWillCommit() throws
    public func databaseDidCommit(db: GRDB.Database)
    public func databaseDidRollback(db: GRDB.Database)
}

final public class UpdateStatement : GRDB.Statement {
    public func execute(arguments arguments: GRDB.StatementArguments? = default) throws -> GRDB.DatabaseChanges
}

public struct _SQLCollatedExpression {
}

extension _SQLCollatedExpression : _SQLExpressionType {
    public var sqlExpression: GRDB._SQLExpression { get }
}

extension _SQLCollatedExpression : _SQLSortDescriptorType {
    public var reversedSortDescriptor: GRDB._SQLSortDescriptor { get }
    public var asc: GRDB._SQLSortDescriptor { get }
    public var desc: GRDB._SQLSortDescriptor { get }
    public func orderingSQL(db: GRDB.Database, inout _ bindings: [DatabaseValueConvertible?]) throws -> String
}

public protocol _SQLDerivedExpressionType : _SQLExpressionType, _SQLSortDescriptorType, _SQLSelectable {
}

extension _SQLDerivedExpressionType {
    public func collating(collationName: String) -> GRDB._SQLCollatedExpression
    public func collating(collation: GRDB.DatabaseCollation) -> GRDB._SQLCollatedExpression
}

extension _SQLDerivedExpressionType {
    public var capitalizedString: GRDB._SQLExpression { get }
    public var lowercaseString: GRDB._SQLExpression { get }
    public var uppercaseString: GRDB._SQLExpression { get }
}

extension _SQLDerivedExpressionType {
    public var localizedCapitalizedString: GRDB._SQLExpression { get }
    public var localizedLowercaseString: GRDB._SQLExpression { get }
    public var localizedUppercaseString: GRDB._SQLExpression { get }
}

extension _SQLDerivedExpressionType {
    public var reversedSortDescriptor: GRDB._SQLSortDescriptor { get }
    public func orderingSQL(db: GRDB.Database, inout _ bindings: [DatabaseValueConvertible?]) throws -> String
}

extension _SQLDerivedExpressionType {
    public func resultColumnSQL(db: GRDB.Database, inout _ bindings: [DatabaseValueConvertible?]) throws -> String
    public func countedSQL(db: GRDB.Database, inout _ bindings: [DatabaseValueConvertible?]) throws -> String
    public var sqlSelectableKind: GRDB._SQLSelectableKind { get }
}

extension _SQLDerivedExpressionType {
    public var asc: GRDB._SQLSortDescriptor { get }
    public var desc: GRDB._SQLSortDescriptor { get }
    public func aliased(alias: String) -> _SQLSelectable
}

indirect public enum _SQLExpression {
    case Literal(String)
    case Value(DatabaseValueConvertible?)
    case Identifier(identifier: String, sourceName: String?)
    case Collate(GRDB._SQLExpression, String)
    case Not(GRDB._SQLExpression)
    case Equal(GRDB._SQLExpression, GRDB._SQLExpression)
    case NotEqual(GRDB._SQLExpression, GRDB._SQLExpression)
    case Is(GRDB._SQLExpression, GRDB._SQLExpression)
    case IsNot(GRDB._SQLExpression, GRDB._SQLExpression)
    case PrefixOperator(String, GRDB._SQLExpression)
    case InfixOperator(String, GRDB._SQLExpression, GRDB._SQLExpression)
    case In([GRDB._SQLExpression], GRDB._SQLExpression)
    case InSubQuery(GRDB._SQLSelectQuery, GRDB._SQLExpression)
    case Exists(GRDB._SQLSelectQuery)
    case Between(value: GRDB._SQLExpression, min: GRDB._SQLExpression, max: GRDB._SQLExpression)
    case Function(String, [GRDB._SQLExpression])
    case Count(_SQLSelectable)
    case CountDistinct(GRDB._SQLExpression)
}

extension _SQLExpression : _SQLDerivedExpressionType {
    public var sqlExpression: GRDB._SQLExpression { get }
}

public protocol _SQLExpressionType {
    public var sqlExpression: GRDB._SQLExpression { get }
}

public struct _SQLSelectQuery {
}

public protocol _SQLSelectable {
    public func resultColumnSQL(db: GRDB.Database, inout _ bindings: [DatabaseValueConvertible?]) throws -> String
    public func countedSQL(db: GRDB.Database, inout _ bindings: [DatabaseValueConvertible?]) throws -> String
    public var sqlSelectableKind: GRDB._SQLSelectableKind { get }
}

public enum _SQLSelectableKind {
    case Expression(GRDB._SQLExpression)
    case Star(sourceName: String?)
}

public enum _SQLSortDescriptor {
    case Asc(GRDB._SQLExpression)
    case Desc(GRDB._SQLExpression)
}

extension _SQLSortDescriptor : _SQLSortDescriptorType {
    public var reversedSortDescriptor: GRDB._SQLSortDescriptor { get }
    public func orderingSQL(db: GRDB.Database, inout _ bindings: [DatabaseValueConvertible?]) throws -> String
}

public protocol _SQLSortDescriptorType {
    public var reversedSortDescriptor: GRDB._SQLSortDescriptor { get }
    public func orderingSQL(db: GRDB.Database, inout _ bindings: [DatabaseValueConvertible?]) throws -> String
}

public func abs(value: _SQLDerivedExpressionType) -> GRDB._SQLExpression

public func average(value: _SQLDerivedExpressionType) -> GRDB._SQLExpression

public func count(distinct value: _SQLDerivedExpressionType) -> GRDB._SQLExpression

public func count(counted: _SQLDerivedExpressionType) -> GRDB._SQLExpression

public func databaseQuestionMarks(count count: Int) -> String

public func max(value: _SQLDerivedExpressionType) -> GRDB._SQLExpression

public func min(value: _SQLDerivedExpressionType) -> GRDB._SQLExpression

public func sum(value: _SQLDerivedExpressionType) -> GRDB._SQLExpression

public func ||(lhs: _SQLExpressionType, rhs: _SQLDerivedExpressionType) -> GRDB._SQLExpression

public func ||(lhs: _SQLDerivedExpressionType, rhs: _SQLExpressionType) -> GRDB._SQLExpression

public func ||(lhs: _SQLDerivedExpressionType, rhs: _SQLDerivedExpressionType) -> GRDB._SQLExpression


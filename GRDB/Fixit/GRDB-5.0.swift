// Fixits for changes introduced by GRDB 5.0.0
// swiftlint:disable all

import Dispatch
#if os(iOS)
import UIKit
#endif

extension AnyFetchRequest {
    @available(*, unavailable, renamed: "RowDecoder")
    typealias T = RowDecoder
    
    @available(*, unavailable, message: "Use AnyFetchRequest(request).asRequest(of: SomeType.self) instead.")
    public init<Request: FetchRequest>(_ request: Request)
    { preconditionFailure() }
    
    @available(*, unavailable, message: "Define your own FetchRequest type instead.")
    public init(_ prepare: @escaping (Database, _ singleResult: Bool) throws -> (Statement, RowAdapter?))
    { preconditionFailure() }
}

@available(*, unavailable, message: "Custom reducers are no longer supported. See the \"Migrating From GRDB 4 to GRDB 5\" guide.")
public struct AnyValueReducer<Fetched, Value>: ValueReducer {
    public init(fetch: @escaping (Database) throws -> Fetched, value: @escaping (Fetched) -> Value?)
    { preconditionFailure() }
    
    public init<Base: _ValueReducer>(_ reducer: Base) where Base.Fetched == Fetched, Base.Value == Value
    { preconditionFailure() }
    
    public func _fetch(_ db: Database) throws -> Fetched
    { preconditionFailure() }
    
    public func _value(_ fetched: Fetched) -> Value?
    { preconditionFailure() }
}

extension AssociationAggregate {
    @available(*, unavailable, renamed: "forKey(_:)")
    public func aliased(_ name: String) -> AssociationAggregate<RowDecoder>
    { preconditionFailure() }
    
    @available(*, unavailable, renamed: "forKey(_:)")
    public func aliased(_ key: CodingKey) -> AssociationAggregate<RowDecoder>
    { preconditionFailure() }
}

extension Configuration {
    @available(*, unavailable, message: "Replace the assignment with a method call: prepareDatabase { db in ... }")
    public var prepareDatabase: ((Database) throws -> Void)? {
        get { preconditionFailure() }
        set { preconditionFailure() }
    }
    
    @available(*, unavailable, message: "Use Database.trace(options:_:) in Configuration.prepareDatabase instead.")
    public var trace: TraceFunction? {
        get { preconditionFailure() }
        set { preconditionFailure() }
    }
}

extension DatabaseFunction {
    @available(*, unavailable, renamed: "callAsFunction(_:)")
    public func apply(_ arguments: SQLExpressible...) -> SQLExpression
    { preconditionFailure() }
}

extension DatabaseMigrator {
    @available(*, unavailable, renamed: "registerMigration(_:migrate:)")
    public mutating func registerMigrationWithDeferredForeignKeyCheck(
        _ identifier: String,
        migrate: @escaping (Database) throws -> Void)
    { preconditionFailure() }
    
    @available(*, unavailable, message: "Wrap this method: reader.read(migrator.appliedMigrations) }")
    public func appliedMigrations(in reader: DatabaseReader) throws -> Set<String>
    { preconditionFailure() }
    
    @available(*, unavailable, message: "Wrap this method: reader.read(migrator.hasCompletedMigrations) }")
    public func hasCompletedMigrations(in reader: DatabaseReader) throws -> Bool
    { preconditionFailure() }
    
    @available(*, unavailable, message: "Prefer reader.read(migrator.completedMigrations).contains(targetIdentifier)")
    public func hasCompletedMigrations(in reader: DatabaseReader, through targetIdentifier: String) throws -> Bool
    { preconditionFailure() }
    
    @available(*, unavailable, message: "Prefer reader.read(migrator.completedMigrations).last")
    public func lastCompletedMigration(in reader: DatabaseReader) throws -> String?
    { preconditionFailure() }
}

extension DatabasePool {
    @available(*, unavailable, message: "Use pool.writeWithoutTransaction { $0.checkpoint() } instead")
    public func checkpoint(_ kind: Database.CheckpointMode = .passive) throws { preconditionFailure() }
    
    #if os(iOS)
    @available(*, unavailable, message: "Memory management is now enabled by default. This method does nothing.")
    public func setupMemoryManagement(in application: UIApplication) { preconditionFailure() }
    #endif
}

extension DatabaseQueue {
    #if os(iOS)
    @available(*, unavailable, message: "Memory management is now enabled by default. This method does nothing.")
    public func setupMemoryManagement(in application: UIApplication) { preconditionFailure() }
    #endif
}

extension DatabaseReader {
    @available(*, unavailable, message: "Use Database.add(collation:) in Configuration.prepareDatabase instead.")
    public func add(collation: DatabaseCollation) { preconditionFailure() }
    
    @available(*, unavailable)
    public func remove(collation: DatabaseCollation) { preconditionFailure() }
    
    @available(*, unavailable, message: "Use Database.add(function:) in Configuration.prepareDatabase instead.")
    public func add(function: DatabaseFunction) { preconditionFailure() }
    
    @available(*, unavailable)
    public func remove(function: DatabaseFunction) { preconditionFailure() }
    
    #if SQLITE_ENABLE_FTS5
    @available(*, unavailable, message: "Use Database.add(tokenizer:) in Configuration.prepareDatabase instead.")
    public func add<Tokenizer: FTS5CustomTokenizer>(tokenizer: Tokenizer.Type) { preconditionFailure() }
    #endif
}

extension FetchRequest {
    @available(*, unavailable, message: "Use makePreparedRequest(_:forSingleResult:) instead.")
    func prepare(_ db: Database, forSingleResult singleResult: Bool) throws -> (Statement, RowAdapter?)
    { preconditionFailure() }
    
    @available(*, unavailable, message: "Use ValueObservation.tracking(request.fetchCount) instead")
    public func observationForCount() -> ValueObservation<ValueReducers.Unavailable<Int>>
    { preconditionFailure() }
}

extension FetchRequest where RowDecoder: DatabaseValueConvertible {
    @available(*, unavailable, message: "Use ValueObservation.tracking(request.fetchAll) instead")
    public func observationForAll() -> ValueObservation<ValueReducers.Unavailable<[RowDecoder]>>
    { preconditionFailure() }
    
    @available(*, unavailable, message: "Use ValueObservation.tracking(request.fetchOne) instead")
    public func observationForFirst() -> ValueObservation<ValueReducers.Unavailable<RowDecoder?>>
    { preconditionFailure() }
}

extension FetchRequest where RowDecoder: FetchableRecord {
    @available(*, unavailable, message: "Use ValueObservation.tracking(request.fetchAll) instead")
    public func observationForAll() -> ValueObservation<ValueReducers.Unavailable<[RowDecoder]>>
    { preconditionFailure() }
    
    @available(*, unavailable, message: "Use ValueObservation.tracking(request.fetchOne) instead")
    public func observationForFirst() -> ValueObservation<ValueReducers.Unavailable<RowDecoder?>>
    { preconditionFailure() }
}

extension FetchRequest where RowDecoder: _OptionalProtocol, RowDecoder.Wrapped: DatabaseValueConvertible {
    @available(*, unavailable, message: "Use ValueObservation.tracking(request.fetchAll) instead")
    public func observationForAll() -> ValueObservation<ValueReducers.Unavailable<[RowDecoder.Wrapped?]>>
    { preconditionFailure() }
    
    @available(*, unavailable, message: "Use ValueObservation.tracking(request.fetchOne) instead")
    public func observationForFirst() -> ValueObservation<ValueReducers.Unavailable<RowDecoder.Wrapped?>>
    { preconditionFailure() }
}

extension FetchRequest where RowDecoder == Row {
    @available(*, unavailable, message: "Use ValueObservation.tracking(request.fetchAll) instead")
    public func observationForAll() -> ValueObservation<ValueReducers.Unavailable<[Row]>>
    { preconditionFailure() }
    
    @available(*, unavailable, message: "Use ValueObservation.tracking(request.fetchOne) instead")
    public func observationForFirst() -> ValueObservation<ValueReducers.Unavailable<Row?>>
    { preconditionFailure() }
}

extension QueryInterfaceRequest {
    @available(*, unavailable, renamed: "RowDecoder")
    typealias T = RowDecoder
}

extension SQLExpression {
    @available(*, unavailable, message: "Use SQL initializer instead")
    public var sqlLiteral: SQL
    { preconditionFailure() }
}

extension FilteredRequest {
    @available(*, unavailable, message: "The expectingSingleResult() hint is no longer available.")
    func expectingSingleResult() -> Self
    { preconditionFailure() }
}

@available(*, deprecated, renamed: "SQL")
public typealias SQLLiteral = SQL

/// :nodoc:
@available(*, unavailable, message: "Build literal expressions with SQL.sqlExpression instead.")
struct SQLExpressionLiteral: SQLSpecificExpressible {
    var sqlExpression: SQLExpression { preconditionFailure() }
    
    @available(*, unavailable, message: "Build literal expressions with SQL.sqlExpression instead.")
    public var sql: String { preconditionFailure() }
    
    @available(*, unavailable, message: "Build literal expressions with SQL.sqlExpression instead.")
    public var arguments: StatementArguments { preconditionFailure() }
    
    @available(*, unavailable, message: "Build literal expressions with SQL.sqlExpression instead.")
    public init(sql: String, arguments: StatementArguments = StatementArguments())
    { preconditionFailure() }
    
    @available(*, unavailable, message: "Build literal expressions with SQL.sqlExpression instead.")
    public init(literal sqlLiteral: SQL)
    { preconditionFailure() }
}

@available(*, deprecated, renamed: "SQL")
public typealias SQLiteral = SQL

extension SQL {
    @available(*, unavailable, message: "Use SQL interpolation instead.")
    public func mapSQL(_ transform: @escaping (String) -> String) -> SQL
    { preconditionFailure() }
    
    @available(*, unavailable, message: "Use the build(_:) method instead.")
    public var sql: String { preconditionFailure() }
    
    @available(*, unavailable, message: "Use the build(_:) method instead.")
    public var arguments: StatementArguments { preconditionFailure() }
}

@available(*, unavailable, renamed: "SQLExpression.AssociativeBinaryOperator")
typealias SQLLogicalBinaryOperator = SQLExpression.AssociativeBinaryOperator

@available(*, deprecated, renamed: "SQLExpression")
typealias SQLCollatedExpression = SQLExpression

extension SQLRequest {
    @available(*, unavailable, renamed: "RowDecoder")
    typealias T = RowDecoder
    
    @available(*, unavailable, message: "Turning a request into SQLRequest is no longer supported.")
    public init<Request>(
        _ db: Database,
        request: Request,
        cached: Bool = false)
    throws
    where Request: FetchRequest, Request.RowDecoder == RowDecoder
    { preconditionFailure() }
    
    @available(*, unavailable, message: "Use makePreparedRequest(db).statement.sql instead")
    public var sql: String { preconditionFailure() }
    
    @available(*, unavailable, message: "Use makePreparedRequest(db).statement.arguments instead")
    public var arguments: StatementArguments { preconditionFailure() }
}

extension SQLSpecificExpressible {
    @available(*, unavailable, renamed: "forKey(_:)")
    public func aliased(_ name: String) -> SQLSelectable
    { preconditionFailure() }
    
    @available(*, unavailable, renamed: "forKey(_:)")
    public func aliased(_ key: CodingKey) -> SQLSelectable
    { preconditionFailure() }
}

extension Statement {
    @available(*, unavailable, renamed: "setUncheckedArguments(_:)")
    public func unsafeSetArguments(_ arguments: StatementArguments)
    { preconditionFailure() }
    
    @available(*, unavailable, renamed: "validateArguments(_:)")
    public func validate(arguments: StatementArguments) throws
    { preconditionFailure() }
}

extension TableRecord {
    @available(*, unavailable, message: "Use ValueObservation.tracking(MyRecord.fetchCount) instead")
    public static func observationForCount() -> ValueObservation<ValueReducers.Unavailable<Int>>
    { preconditionFailure() }
    
    @available(*, unavailable, message: "Use SQL interpolation instead")
    public static func selectionSQL(alias: String? = nil) -> String
    { preconditionFailure() }
}

extension TableRecord where Self: FetchableRecord {
    @available(*, unavailable, message: "Use ValueObservation.tracking(MyRecord.fetchAll) instead")
    public static func observationForAll() -> ValueObservation<ValueReducers.Unavailable<[Self]>>
    { preconditionFailure() }
    
    @available(*, unavailable, message: "Use ValueObservation.tracking(MyRecord.fetchOne) instead")
    public static func observationForFirst() -> ValueObservation<ValueReducers.Unavailable<Self?>>
    { preconditionFailure() }
}

@available(*, unavailable)
public typealias TraceFunction = (String) -> Void

extension ValueObservation {
    @available(*, unavailable, message: "ValueObservation now schedules its values asynchronously on the main queue by default. See ValueObservation.start() for possible configuration")
    var scheduling: ValueScheduling {
        get { preconditionFailure() }
        set { preconditionFailure() }
    }
    
    @available(*, unavailable, message: "Custom reducers are no longer supported. See the \"Migrating From GRDB 4 to GRDB 5\" guide.")
    public static func tracking(_ regions: DatabaseRegionConvertible..., reducer: @escaping (Database) throws -> Reducer) -> ValueObservation
    { preconditionFailure() }
    
    @available(*, unavailable, message: "Custom reducers are no longer supported. See the \"Migrating From GRDB 4 to GRDB 5\" guide.")
    public static func tracking(_ regions: [DatabaseRegionConvertible], reducer: @escaping (Database) throws -> Reducer) -> ValueObservation
    { preconditionFailure() }
    
    @available(*, unavailable, message: "combine is no longer available. See the \"Migrating From GRDB 4 to GRDB 5\" guide.")
    public func combine<
        R1: _ValueReducer,
        Combined>(
        _ other: ValueObservation<R1>,
        _ transform: @escaping (Reducer.Value, R1.Value) -> Combined)
    -> ValueObservation<ValueReducers.Unavailable<Combined>>
    { preconditionFailure() }
    
    @available(*, unavailable, message: "combine is no longer available. See the \"Migrating From GRDB 4 to GRDB 5\" guide.")
    public func combine<
        R1: _ValueReducer,
        R2: _ValueReducer,
        Combined>(
        _ observation1: ValueObservation<R1>,
        _ observation2: ValueObservation<R2>,
        _ transform: @escaping (Reducer.Value, R1.Value, R2.Value) -> Combined)
    -> ValueObservation<ValueReducers.Unavailable<Combined>>
    { preconditionFailure() }
    
    @available(*, unavailable, message: "combine is no longer available. See the \"Migrating From GRDB 4 to GRDB 5\" guide.")
    public func combine<
        R1: _ValueReducer,
        R2: _ValueReducer,
        R3: _ValueReducer,
        Combined>(
        _ observation1: ValueObservation<R1>,
        _ observation2: ValueObservation<R2>,
        _ observation3: ValueObservation<R3>,
        _ transform: @escaping (Reducer.Value, R1.Value, R2.Value, R3.Value) -> Combined)
    -> ValueObservation<ValueReducers.Unavailable<Combined>>
    { preconditionFailure() }
    
    @available(*, unavailable, message: "combine is no longer available. See the \"Migrating From GRDB 4 to GRDB 5\" guide.")
    public func combine<
        R1: _ValueReducer,
        R2: _ValueReducer,
        R3: _ValueReducer,
        R4: _ValueReducer,
        Combined>(
        _ observation1: ValueObservation<R1>,
        _ observation2: ValueObservation<R2>,
        _ observation3: ValueObservation<R3>,
        _ observation4: ValueObservation<R4>,
        _ transform: @escaping (Reducer.Value, R1.Value, R2.Value, R3.Value, R4.Value) -> Combined)
    -> ValueObservation<ValueReducers.Unavailable<Combined>>
    { preconditionFailure() }
    
    @available(*, unavailable, message: "compactMap is no longer available. See the \"Migrating From GRDB 4 to GRDB 5\" guide.")
    public func compactMap<T>(_ transform: @escaping (Reducer.Value) -> T?) -> ValueObservation<ValueReducers.Unavailable<T>>
    { preconditionFailure() }
    
    @available(*, unavailable, message: "Use start(in:onError:onChange:) instead.")
    public func start(
        in reader: DatabaseReader,
        onChange: @escaping (Reducer.Value) -> Void) throws -> TransactionObserver
    { preconditionFailure() }
}

extension ValueObservation where Reducer == ValueReducers.Auto {
    @available(*, unavailable, message: "combine is no longer available. See the \"Migrating From GRDB 4 to GRDB 5\" guide.")
    public static func combine<
        R1: _ValueReducer,
        R2: _ValueReducer>(
        _ o1: ValueObservation<R1>,
        _ o2: ValueObservation<R2>)
    -> ValueObservation<ValueReducers.Unavailable<(R1.Value, R2.Value)>>
    { preconditionFailure() }
    
    @available(*, unavailable, message: "combine is no longer available. See the \"Migrating From GRDB 4 to GRDB 5\" guide.")
    public static func combine<
        R1: _ValueReducer,
        R2: _ValueReducer,
        R3: _ValueReducer>(
        _ o1: ValueObservation<R1>,
        _ o2: ValueObservation<R2>,
        _ o3: ValueObservation<R3>)
    -> ValueObservation<ValueReducers.Unavailable<(R1.Value, R2.Value, R3.Value)>>
    { preconditionFailure() }
    
    @available(*, unavailable, message: "combine is no longer available. See the \"Migrating From GRDB 4 to GRDB 5\" guide.")
    public static func combine<
        R1: _ValueReducer,
        R2: _ValueReducer,
        R3: _ValueReducer,
        R4: _ValueReducer>(
        _ o1: ValueObservation<R1>,
        _ o2: ValueObservation<R2>,
        _ o3: ValueObservation<R3>,
        _ o4: ValueObservation<R4>)
    -> ValueObservation<ValueReducers.Unavailable<(R1.Value, R2.Value, R3.Value, R4.Value)>>
    { preconditionFailure() }
    
    @available(*, unavailable, message: "combine is no longer available. See the \"Migrating From GRDB 4 to GRDB 5\" guide.")
    public static func combine<
        R1: _ValueReducer,
        R2: _ValueReducer,
        R3: _ValueReducer,
        R4: _ValueReducer,
        R5: _ValueReducer>(
        _ o1: ValueObservation<R1>,
        _ o2: ValueObservation<R2>,
        _ o3: ValueObservation<R3>,
        _ o4: ValueObservation<R4>,
        _ o5: ValueObservation<R5>)
    -> ValueObservation<ValueReducers.Unavailable<(R1.Value, R2.Value, R3.Value, R4.Value, R5.Value)>>
    { preconditionFailure() }
    
    @available(*, unavailable, message: "combine is no longer available. See the \"Migrating From GRDB 4 to GRDB 5\" guide.")
    public static func combine<
        R1: _ValueReducer,
        R2: _ValueReducer,
        R3: _ValueReducer,
        R4: _ValueReducer,
        R5: _ValueReducer,
        R6: _ValueReducer>(
        _ o1: ValueObservation<R1>,
        _ o2: ValueObservation<R2>,
        _ o3: ValueObservation<R3>,
        _ o4: ValueObservation<R4>,
        _ o5: ValueObservation<R5>,
        _ o6: ValueObservation<R6>)
    -> ValueObservation<ValueReducers.Unavailable<(R1.Value, R2.Value, R3.Value, R4.Value, R5.Value, R6.Value)>>
    { preconditionFailure() }
    
    @available(*, unavailable, message: "combine is no longer available. See the \"Migrating From GRDB 4 to GRDB 5\" guide.")
    public static func combine<
        R1: _ValueReducer,
        R2: _ValueReducer,
        R3: _ValueReducer,
        R4: _ValueReducer,
        R5: _ValueReducer,
        R6: _ValueReducer,
        R7: _ValueReducer>(
        _ o1: ValueObservation<R1>,
        _ o2: ValueObservation<R2>,
        _ o3: ValueObservation<R3>,
        _ o4: ValueObservation<R4>,
        _ o5: ValueObservation<R5>,
        _ o6: ValueObservation<R6>,
        _ o7: ValueObservation<R7>)
    -> ValueObservation<ValueReducers.Unavailable<(R1.Value, R2.Value, R3.Value, R4.Value, R5.Value, R6.Value, R7.Value)>>
    { preconditionFailure() }
    
    @available(*, unavailable, message: "combine is no longer available. See the \"Migrating From GRDB 4 to GRDB 5\" guide.")
    public static func combine<
        R1: _ValueReducer,
        R2: _ValueReducer,
        R3: _ValueReducer,
        R4: _ValueReducer,
        R5: _ValueReducer,
        R6: _ValueReducer,
        R7: _ValueReducer,
        R8: _ValueReducer>(
        _ o1: ValueObservation<R1>,
        _ o2: ValueObservation<R2>,
        _ o3: ValueObservation<R3>,
        _ o4: ValueObservation<R4>,
        _ o5: ValueObservation<R5>,
        _ o6: ValueObservation<R6>,
        _ o7: ValueObservation<R7>,
        _ o8: ValueObservation<R8>)
    -> ValueObservation<ValueReducers.Unavailable<(R1.Value, R2.Value, R3.Value, R4.Value, R5.Value, R6.Value, R7.Value, R8.Value)>>
    { preconditionFailure() }
    
    @available(*, unavailable, message: "Use ValueObservation.tracking(_:) instead")
    public static func trackingCount<Request: FetchRequest>(_ request: Request)
    -> ValueObservation<ValueReducers.Unavailable<Int>>
    { preconditionFailure() }
    
    @available(*, unavailable, message: "Use ValueObservation.tracking(_:) instead")
    public static func trackingAll<Request: FetchRequest>(_ request: Request)
    -> ValueObservation<ValueReducers.Unavailable<[Request.RowDecoder]>>
    where Request.RowDecoder: DatabaseValueConvertible
    { preconditionFailure() }
    
    @available(*, unavailable, message: "Use ValueObservation.tracking(_:) instead")
    public static func trackingOne<Request: FetchRequest>(_ request: Request)
    -> ValueObservation<ValueReducers.Unavailable<Request.RowDecoder?>>
    where Request.RowDecoder: DatabaseValueConvertible
    { preconditionFailure() }
    
    @available(*, unavailable, message: "Use ValueObservation.tracking(_:) instead")
    public static func trackingAll<Request: FetchRequest>(_ request: Request)
    -> ValueObservation<ValueReducers.Unavailable<[Request.RowDecoder.Wrapped?]>>
    where Request.RowDecoder: _OptionalProtocol,
          Request.RowDecoder.Wrapped: DatabaseValueConvertible
    { preconditionFailure() }
    
    @available(*, unavailable, message: "Use ValueObservation.tracking(_:) instead")
    public static func trackingAll<Request: FetchRequest>(_ request: Request)
    -> ValueObservation<ValueReducers.Unavailable<[Request.RowDecoder]>>
    where Request.RowDecoder: FetchableRecord
    { preconditionFailure() }
    
    @available(*, unavailable, message: "Use ValueObservation.tracking(_:) instead")
    public static func trackingOne<Request: FetchRequest>(_ request: Request) ->
    ValueObservation<ValueReducers.Unavailable<Request.RowDecoder?>>
    where Request.RowDecoder: FetchableRecord
    { preconditionFailure() }
    
    @available(*, unavailable, message: "Use ValueObservation.tracking(_:) instead")
    public static func trackingAll<Request: FetchRequest>(_ request: Request)
    -> ValueObservation<ValueReducers.Unavailable<[Row]>>
    where Request.RowDecoder == Row
    { preconditionFailure() }
    
    @available(*, unavailable, message: "Use ValueObservation.tracking(_:) instead")
    public static func trackingOne<Request: FetchRequest>(_ request: Request)
    -> ValueObservation<ValueReducers.Unavailable<Row?>>
    where Request.RowDecoder == Row
    { preconditionFailure() }
    
    @available(*, unavailable, message: "Use ValueObservation.tracking(_:) instead")
    public static func tracking<Value>(
        _ regions: DatabaseRegionConvertible...,
        fetch: @escaping (Database) throws -> Value)
    -> ValueObservation<ValueReducers.Unavailable<Value>>
    { preconditionFailure() }
    
    @available(*, unavailable, message: "Use ValueObservation.tracking(_:) instead")
    public static func tracking<Value>(
        _ regions: [DatabaseRegionConvertible],
        fetch: @escaping (Database) throws -> Value)
    -> ValueObservation<ValueReducers.Unavailable<Value>>
    { preconditionFailure() }
    
    @available(*, unavailable, renamed: "tracking(_:)")
    public static func tracking<Value>(
        value: @escaping (Database) throws -> Value)
    -> ValueObservation<ValueReducers.Unavailable<Value>>
    { preconditionFailure() }
}

extension ValueObservation where Reducer.Value: Equatable {
    @available(*, unavailable, renamed: "removeDuplicates")
    public func distinctUntilChanged() -> ValueObservation<ValueReducers.Unavailable<Reducer.Value>>
    { preconditionFailure() }
}

extension ValueReducers {
    @available(*, unavailable)
    public enum Unavailable<T>: ValueReducer {
        public func _fetch(_ db: Database) throws -> Never
        { preconditionFailure() }
        
        public mutating func _value(_ fetched: Never) -> T? { }
    }
}

@available(*, unavailable, message: "ValueObservation now schedules its values asynchronously on the main queue by default. See ValueObservation.start() for possible configuration")
enum ValueScheduling {
    case mainQueue
    case async(onQueue: DispatchQueue, startImmediately: Bool)
    case unsafe(startImmediately: Bool)
}

#if SQLITE_HAS_CODEC
extension Configuration {
    @available(*, unavailable, message: "Use Database.usePassphrase(_:) in Configuration.prepareDatabase instead.")
    public var passphrase: String? {
        get { preconditionFailure() }
        set { preconditionFailure() }
    }
}

extension DatabasePool {
    @available(*, unavailable, message: "Use Database.changePassphrase(_:) instead")
    public func change(passphrase: String) throws { preconditionFailure() }
}

extension DatabaseQueue {
    @available(*, unavailable, message: "Use Database.changePassphrase(_:) instead")
    public func change(passphrase: String) throws { preconditionFailure() }
}
#endif

// Fixits for changes introduced by GRDB 6.0.0
// swiftlint:disable all

extension AggregatingRequest {
    @available(*, unavailable, renamed: "groupWhenConnected(_:)")
    func group(_ expressions: @escaping (Database) throws -> [any SQLExpressible]) -> Self { preconditionFailure() }
    
    @available(*, unavailable, renamed: "havingWhenConnected(_:)")
    func having(_ predicate: @escaping (Database) throws -> any SQLExpressible) -> Self { preconditionFailure() }
}

extension Association {
    @available(*, unavailable, message: "limit(_:offset:) was not working properly, and was removed.")
    public func limit(_ limit: Int, offset: Int? = nil) -> Self { preconditionFailure() }
}

extension Database {
    @available(*, unavailable, renamed: "cachedStatement(sql:)")
    public func cachedSelectStatement(sql: String) throws -> Statement { preconditionFailure() }
    
    @available(*, unavailable, renamed: "cachedStatement(literal:)")
    public func cachedSelectStatement(literal sqlLiteral: SQL) throws -> Statement { preconditionFailure() }
    
    @available(*, unavailable, renamed: "cachedStatement(sql:)")
    public func cachedUpdateStatement(sql: String) throws -> Statement { preconditionFailure() }
    
    @available(*, unavailable, renamed: "cachedStatement(sql:)")
    public func cachedUpdateStatement(literal sqlLiteral: SQL) throws -> Statement { preconditionFailure() }
    
    @available(*, unavailable, message: "Use Database.isSQLiteInternalTable(_:) static method instead.")
    public func isSQLiteInternalTable(_ tableName: String) -> Bool { preconditionFailure() }
    
    @available(*, unavailable, message: "Use Database.isGRDBInternalTable(_:) static method instead.")
    public func isGRDBInternalTable(_ tableName: String) -> Bool { preconditionFailure() }
    
    @available(*, unavailable, renamed: "makeStatement(sql:)")
    public func makeSelectStatement(sql: String) throws -> Statement { preconditionFailure() }
    
    @available(*, unavailable, renamed: "makeStatement(literal:)")
    public func makeSelectStatement(literal sqlLiteral: SQL) throws -> Statement { preconditionFailure() }
    
    @available(*, unavailable, renamed: "makeStatement(sql:)")
    public func makeUpdateStatement(sql: String) throws -> Statement { preconditionFailure() }
    
    @available(*, unavailable, renamed: "makeStatement(literal:)")
    public func makeUpdateStatement(literal sqlLiteral: SQL) throws -> Statement { preconditionFailure() }
    
    @available(*, unavailable, renamed: "afterNextTransaction(onCommit:)")
    public func afterNextTransactionCommit(_ closure: @escaping (Database) -> Void) { preconditionFailure() }
}

extension DatabaseCursor {
    @available(*, unavailable, message: "statement has been removed. You may use other cursor properties instead.")
    public var statement: Statement { preconditionFailure() }
}

extension DatabaseMigrator {
    @available(*, unavailable, message: "The completion function now accepts one Result<Database, Error> argument")
    public func asyncMigrate(
        _ writer: any DatabaseWriter,
        completion: @escaping (Database, Error?) -> Void)
    { preconditionFailure() }
}

extension DatabaseRegionObservation {
    @available(*, unavailable, message: "The extent of the observation is now controlled by the cancellable returned by DatabaseRegionObservation.start().")
    public var extent: Database.TransactionObservationExtent {
        get { preconditionFailure() }
        set { preconditionFailure() }
    }
}

extension DatabaseUUIDEncodingStrategy {
    @available(*, unavailable, renamed: "uppercaseString")
    public static var string: Self { preconditionFailure() }
}

@available(*, unavailable, message: "FastNullableDatabaseValueCursor<T> has been replaced with FastDatabaseValueCursor<T?>")
typealias FastNullableDatabaseValueCursor<T: DatabaseValueConvertible & StatementColumnConvertible> = FastDatabaseValueCursor<T?>

extension FilteredRequest {
    @available(*, unavailable, renamed: "filterWhenConnected(with:)")
    func filter(_ predicate: @escaping (Database) throws -> any SQLExpressible) -> Self { preconditionFailure() }
}

extension MutablePersistableRecord {
    @available(*, unavailable, message: "Use persistence callbacks instead.")
    public mutating func performInsert(_ db: Database) throws { preconditionFailure() }
    
    @available(*, unavailable, message: "Use persistence callbacks instead.")
    public func performUpdate(_ db: Database, columns: Set<String>) throws { preconditionFailure() }
    
    @available(*, unavailable, message: "Use persistence callbacks instead.")
    public mutating func performSave(_ db: Database) throws { preconditionFailure() }
    
    @available(*, unavailable, message: "Use persistence callbacks instead.")
    public func performDelete(_ db: Database) throws -> Bool { preconditionFailure() }
    
    @available(*, unavailable, message: "performExists(_:) was removed without any replacement.")
    public func performExists(_ db: Database) throws -> Bool { preconditionFailure() }
    
    @available(*, unavailable, renamed: "updateChanges(_:modify:)")
    public mutating func updateChanges(_ db: Database, with change: (inout Self) throws -> Void) throws -> Bool { preconditionFailure() }
}

@available(*, unavailable, message: "NullableDatabaseValueCursor<T> has been replaced with DatabaseValueCursor<T?>")
typealias NullableDatabaseValueCursor<T: DatabaseValueConvertible> = DatabaseValueCursor<T?>

extension OrderedRequest {
    @available(*, unavailable, renamed: "orderWhenConnected(_:)")
    func order(_ orderings: @escaping (Database) throws -> [any SQLOrderingTerm]) -> Self { preconditionFailure() }
}

extension PersistableRecord {
    @available(*, unavailable, message: "Use persistence callbacks instead.")
    public func performInsert(_ db: Database) throws { preconditionFailure() }
    
    @available(*, unavailable, message: "Use persistence callbacks instead.")
    public func performSave(_ db: Database) throws { preconditionFailure() }
}

@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
extension QueryInterfaceRequest where RowDecoder: Identifiable, RowDecoder.ID: DatabaseValueConvertible {
    @available(*, unavailable, message: "selectID() has been removed. You may use selectPrimaryKey(as:) instead.")
    public func selectID() -> QueryInterfaceRequest<RowDecoder.ID> { preconditionFailure() }
}

extension Record {
    @available(*, unavailable, message: "Record.copy() was removed without any replacement.")
    final func copy() -> Self { preconditionFailure() }
}

@available(*, unavailable, renamed: "Statement")
public typealias SelectStatement = Statement

extension SelectionRequest {
    @available(*, unavailable, renamed: "annotatedWhenConnected(with:)")
    func annotated(with selection: @escaping (Database) throws -> [any SQLSelectable]) -> Self { preconditionFailure() }
    
    @available(*, unavailable, renamed: "selectWhenConnected(_:)")
    func select(_ selection: @escaping (Database) throws -> [any SQLSelectable]) -> Self { preconditionFailure() }
}

@available(*, unavailable, renamed: "SQLExpression.AssociativeBinaryOperator")
public typealias SQLAssociativeBinaryOperator = SQLExpression.AssociativeBinaryOperator

@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
extension Table where RowDecoder: Identifiable, RowDecoder.ID: DatabaseValueConvertible {
    @available(*, unavailable, message: "selectID() has been removed. You may use selectPrimaryKey(as:) instead.")
    public func selectID() -> QueryInterfaceRequest<RowDecoder.ID> { preconditionFailure() }
}

@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
extension TableRecord where Self: Identifiable, ID: DatabaseValueConvertible {
    @available(*, unavailable, message: "selectID() has been removed. You may use selectPrimaryKey(as:) instead.")
    public static func selectID() -> QueryInterfaceRequest<ID> { preconditionFailure() }
}

@available(*, unavailable, renamed: "Statement")
public typealias UpdateStatement = Statement

extension ValueObservation {
    @available(*, unavailable, renamed: "tracking(_:)")
    public static func trackingVaryingRegion<Value>(
        _ fetch: @escaping (Database) throws -> Value)
    -> Self
    where Reducer == ValueReducers.Fetch<Value>
    { preconditionFailure() }
}

// swiftlint:enable all

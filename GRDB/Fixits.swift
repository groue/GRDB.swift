// Fixits for changes introduced by GRDB 6.0.0
// swiftlint:disable all

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
}

extension DatabaseMigrator {
    @available(*, unavailable, message: "The completion function now accepts one Result<Database, Error> argument")
    public func asyncMigrate(
        _ writer: DatabaseWriter,
        completion: @escaping (Database, Error?) -> Void)
    { preconditionFailure() }
}

extension DatabaseUUIDEncodingStrategy {
    @available(*, unavailable, renamed: "uppercaseString")
    public static var string: Self { preconditionFailure() }
}

@available(*, unavailable, message: "FastNullableDatabaseValueCursor<T> has been replaced with FastDatabaseValueCursor<T?>")
typealias FastNullableDatabaseValueCursor<T: DatabaseValueConvertible & StatementColumnConvertible> = FastDatabaseValueCursor<T?>

@available(*, unavailable, message: "NullableDatabaseValueCursor<T> has been replaced with DatabaseValueCursor<T?>")
typealias NullableDatabaseValueCursor<T: DatabaseValueConvertible> = DatabaseValueCursor<T?>

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6, *)
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

@available(*, unavailable, renamed: "SQLExpression.AssociativeBinaryOperator")
public typealias SQLAssociativeBinaryOperator = SQLExpression.AssociativeBinaryOperator

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6, *)
extension Table where RowDecoder: Identifiable, RowDecoder.ID: DatabaseValueConvertible {
    @available(*, unavailable, message: "selectID() has been removed. You may use selectPrimaryKey(as:) instead.")
    public func selectID() -> QueryInterfaceRequest<RowDecoder.ID> { preconditionFailure() }
}

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6, *)
extension TableRecord where Self: Identifiable, ID: DatabaseValueConvertible {
    @available(*, unavailable, message: "selectID() has been removed. You may use selectPrimaryKey(as:) instead.")
    public static func selectID() -> QueryInterfaceRequest<ID> { preconditionFailure() }
}

@available(*, unavailable, renamed: "Statement")
public typealias UpdateStatement = Statement

extension ValueObservation<ValueReducers.Auto> {
    @available(*, unavailable, renamed: "tracking(_:)")
    public static func trackingVaryingRegion<Value>(
        _ fetch: @escaping (Database) throws -> Value)
    -> ValueObservation<ValueReducers.Fetch<Value>>
    { preconditionFailure() }
}

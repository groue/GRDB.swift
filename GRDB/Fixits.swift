// Fixits for changes introduced by GRDB 6.0.0
// swiftlint:disable all

@available(*, unavailable)
public func count(_ counted: SQLSelectable) -> SQLExpression { preconditionFailure() }

extension AssociationToMany {
    @available(*, unavailable, message: "Did you mean average(Column(...))? If not, prefer average(value.databaseValue) instead.")
    public func average(_ expression: SQLExpressible) -> AssociationAggregate<OriginRowDecoder> { preconditionFailure() }
    
    @available(*, unavailable, message: "Did you mean max(Column(...))? If not, prefer max(value.databaseValue) instead.")
    public func max(_ expression: SQLExpressible) -> AssociationAggregate<OriginRowDecoder> { preconditionFailure() }
    
    @available(*, unavailable, message: "Did you mean min(Column(...))? If not, prefer min(value.databaseValue) instead.")
    public func min(_ expression: SQLExpressible) -> AssociationAggregate<OriginRowDecoder> { preconditionFailure() }
    
    @available(*, unavailable, message: "Did you mean sum(Column(...))? If not, prefer sum(value.databaseValue) instead.")
    public func sum(_ expression: SQLExpressible) -> AssociationAggregate<OriginRowDecoder> { preconditionFailure() }
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
    public func isGRDBInternalTable(_ tableName: String) -> Bool { preconditionFailure() }
    
    @available(*, unavailable, message: "Use Database.isSQLiteInternalTable(_:) static method instead.")
    public func isSQLiteInternalTable(_ tableName: String) -> Bool { preconditionFailure() }
    
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

extension FilteredRequest {
    @available(*, unavailable, message: "Did you mean filter(id:) or filter(key:)? If not, prefer filter(value.databaseValue) instead. See also none().")
    public func filter(_ predicate: SQLExpressible) -> Self { preconditionFailure() }
}

@available(*, unavailable, renamed: "Statement")
public typealias SelectStatement = Statement

@available(*, unavailable, renamed: "SQLExpression.AssociativeBinaryOperator")
public typealias SQLAssociativeBinaryOperator = SQLExpression.AssociativeBinaryOperator

extension TableRecord {
    @available(*, unavailable, message: "Did you mean filter(id:) or filter(key:)? If not, prefer filter(value.databaseValue) instead. See also none().")
    public static func filter(_ predicate: SQLExpressible) -> QueryInterfaceRequest<Self> { preconditionFailure() }
}

@available(*, unavailable, renamed: "Statement")
public typealias UpdateStatement = Statement

extension ValueObservation where Reducer == ValueReducers.Auto {
    @available(*, unavailable, renamed: "tracking(_:)")
    public static func trackingVaryingRegion<Value>(
        _ fetch: @escaping (Database) throws -> Value)
    -> ValueObservation<ValueReducers.Fetch<Value>>
    { preconditionFailure() }
}

// Fixits for changes introduced by GRDB 6.0.0
// swiftlint:disable all

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

@available(*, unavailable, renamed: "Statement")
public typealias SelectStatement = Statement

@available(*, unavailable, renamed: "SQLExpression.AssociativeBinaryOperator")
public typealias SQLAssociativeBinaryOperator = SQLExpression.AssociativeBinaryOperator

@available(*, unavailable, renamed: "Statement")
public typealias UpdateStatement = Statement

extension ValueObservation where Reducer == ValueReducers.Auto {
    @available(*, unavailable, renamed: "tracking(_:)")
    public static func trackingVaryingRegion<Value>(
        _ fetch: @escaping (Database) throws -> Value)
    -> ValueObservation<ValueReducers.Fetch<Value>>
    { preconditionFailure() }
}


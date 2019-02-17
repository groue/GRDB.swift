// Fixits for changes introduced by GRDB 4.0.0

extension Cursor {
    @available(*, unavailable, renamed: "compactMap")
    public func flatMap<ElementOfResult>(_ transform: @escaping (Element) throws -> ElementOfResult?) -> MapCursor<FilterCursor<MapCursor<Self, ElementOfResult?>>, ElementOfResult> { preconditionFailure() }
}

extension DatabaseWriter {
    @available(*, unavailable, message: "Use concurrentRead instead")
    public func readFromCurrentState(_ block: @escaping (Database) -> Void) throws { preconditionFailure() }
}

extension ValueObservation {
    @available(*, unavailable, message: "Provide the reducer in a (Database) -> Reducer closure")
    public static func tracking(_ regions: DatabaseRegionConvertible..., reducer: Reducer) -> ValueObservation { preconditionFailure() }
    
    @available(*, unavailable, message: "Use distinctUntilChanged() instead")
    public static func tracking<Value>(_ regions: DatabaseRegionConvertible..., fetchDistinct fetch: @escaping (Database) throws -> Value) -> ValueObservation<DistinctUntilChangedValueReducer<RawValueReducer<Value>>> where Value: Equatable { preconditionFailure() }
}

@available(*, unavailable, renamed: "FastDatabaseValueCursor")
public typealias ColumnCursor<Value: DatabaseValueConvertible & StatementColumnConvertible> = FastDatabaseValueCursor<Value>

@available(*, unavailable, renamed: "FastNullableDatabaseValueCursor")
public typealias NullableColumnCursor<Value: DatabaseValueConvertible & StatementColumnConvertible> = FastNullableDatabaseValueCursor<Value>

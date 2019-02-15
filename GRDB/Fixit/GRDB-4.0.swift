import Dispatch

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

extension Database {
    @available(*, unavailable, renamed: "execute(rawSQL:arguments:)")
    public func execute(_ sql: String, arguments: StatementArguments? = nil) throws { }
}

extension DatabaseValueConvertible {
    @available(*, unavailable, renamed: "fetchCursor(_:rawSQL:arguments:adapter:)")
    public static func fetchCursor(_ db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> DatabaseValueCursor<Self> { preconditionFailure() }
    
    @available(*, unavailable, renamed: "fetchAll(_:rawSQL:arguments:adapter:)")
    public static func fetchAll(_ db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> [Self] { preconditionFailure() }
    
    @available(*, unavailable, renamed: "fetchOne(_:rawSQL:arguments:adapter:)")
    public static func fetchOne(_ db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> Self? { preconditionFailure() }
}

extension Optional where Wrapped: DatabaseValueConvertible {
    @available(*, unavailable, renamed: "fetchCursor(_:rawSQL:arguments:adapter:)")
    public static func fetchCursor(_ db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> NullableDatabaseValueCursor<Wrapped> { preconditionFailure() }
    
    @available(*, unavailable, renamed: "fetchAll(_:rawSQL:arguments:adapter:)")
    public static func fetchAll(_ db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> [Wrapped?] { preconditionFailure() }
}

extension Row {
    @available(*, unavailable, renamed: "fetchCursor(_:rawSQL:arguments:adapter:)")
    public static func fetchCursor(_ db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> RowCursor { preconditionFailure() }
    
    @available(*, unavailable, renamed: "fetchAll(_:rawSQL:arguments:adapter:)")
    public static func fetchAll(_ db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> [Row] { preconditionFailure() }
    
    @available(*, unavailable, renamed: "fetchOne(_:rawSQL:arguments:adapter:)")
    public static func fetchOne(_ db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> Row? { preconditionFailure() }
}

extension DatabaseValueConvertible where Self: StatementColumnConvertible {
    @available(*, unavailable, renamed: "fetchCursor(_:rawSQL:arguments:adapter:)")
    public static func fetchCursor(_ db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> FastDatabaseValueCursor<Self> { preconditionFailure() }
}

extension Optional where Wrapped: DatabaseValueConvertible & StatementColumnConvertible {
    @available(*, unavailable, renamed: "fetchCursor(_:rawSQL:arguments:adapter:)")
    public static func fetchCursor(_ db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> FastNullableDatabaseValueCursor<Wrapped> { preconditionFailure() }
}

extension FetchableRecord {
    @available(*, unavailable, renamed: "fetchCursor(_:rawSQL:arguments:adapter:)")
    public static func fetchCursor(_ db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> RecordCursor<Self> { preconditionFailure() }
    
    @available(*, unavailable, renamed: "fetchAll(_:rawSQL:arguments:adapter:)")
    public static func fetchAll(_ db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> [Self] { preconditionFailure() }
    
    @available(*, unavailable, renamed: "fetchOne(_:rawSQL:arguments:adapter:)")
    public static func fetchOne(_ db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> Self? { preconditionFailure() }
}

extension SQLRequest {
    @available(*, unavailable, renamed: "init(rawSQL:arguments:adapter:cached:)")
    public init(_ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil, cached: Bool = false) { preconditionFailure() }
}

extension SQLExpressionLiteral {
    @available(*, unavailable, renamed: "init(rawSQL:arguments:)")
    public init(_ sql: String, arguments: StatementArguments? = nil) { preconditionFailure() }
}

extension QueryInterfaceRequest {
    @available(*, unavailable, renamed: "select(rawSQL:arguments:as:)")
    public func select<RowDecoder>(sql: String, arguments: StatementArguments? = nil, as type: RowDecoder.Type) -> QueryInterfaceRequest<RowDecoder> { preconditionFailure() }
}

extension TableRecord {
    @available(*, unavailable, renamed: "select(rawSQL:arguments:)")
    public static func select(sql: String, arguments: StatementArguments? = nil) -> QueryInterfaceRequest<Self> { preconditionFailure() }
    
    @available(*, unavailable, renamed: "select(rawSQL:arguments:as:)")
    public static func select<RowDecoder>(sql: String, arguments: StatementArguments? = nil, as type: RowDecoder.Type) -> QueryInterfaceRequest<RowDecoder> { preconditionFailure() }
    
    @available(*, unavailable, renamed: "filter(rawSQL:arguments:)")
    public static func filter(sql: String, arguments: StatementArguments? = nil) -> QueryInterfaceRequest<Self> { preconditionFailure() }
    
    @available(*, unavailable, renamed: "order(rawSQL:arguments:)")
    public static func order(sql: String, arguments: StatementArguments? = nil) -> QueryInterfaceRequest<Self> { preconditionFailure() }
}

extension SelectionRequest {
    @available(*, unavailable, renamed: "select(rawSQL:arguments:)")
    public func select(sql: String, arguments: StatementArguments? = nil) -> Self { preconditionFailure() }
}

extension FilteredRequest {
    @available(*, unavailable, renamed: "filter(rawSQL:arguments:)")
    public func filter(sql: String, arguments: StatementArguments? = nil) -> Self { preconditionFailure() }
}

extension AggregatingRequest {
    @available(*, unavailable, renamed: "group(rawSQL:arguments:)")
    public func group(sql: String, arguments: StatementArguments? = nil) -> Self { preconditionFailure() }
    
    @available(*, unavailable, renamed: "having(rawSQL:arguments:)")
    public func having(sql: String, arguments: StatementArguments? = nil) -> Self { preconditionFailure() }
}

extension OrderedRequest {
    @available(*, unavailable, renamed: "order(rawSQL:arguments:)")
    public func order(sql: String, arguments: StatementArguments? = nil) -> Self { preconditionFailure() }
}

extension TableDefinition {
    @available(*, unavailable, renamed: "check(rawSQL:)")
    public func check(sql: String) { preconditionFailure() }
}

extension ColumnDefinition {
    @available(*, unavailable, renamed: "check(rawSQL:)")
    public func check(sql: String) { preconditionFailure() }
    
    @available(*, unavailable, renamed: "defaults(rawSQL:)")
    public func defaults(sql: String) -> Self { preconditionFailure() }
}

extension FetchedRecordsController {
    @available(*, unavailable, renamed: "init(_:rawSQL:arguments:adapter:queue:isSameRecord:)")
    public convenience init(
        _ databaseWriter: DatabaseWriter,
        sql: String,
        arguments: StatementArguments? = nil,
        adapter: RowAdapter? = nil,
        queue: DispatchQueue = .main,
        isSameRecord: ((Record, Record) -> Bool)? = nil) throws { preconditionFailure() }
    
    @available(*, unavailable, renamed: "setRequest(rawSQL:arguments:adapter:)")
    public func setRequest(sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws { preconditionFailure() }
}

extension FetchedRecordsController where Record: TableRecord {
    @available(*, unavailable, renamed: "init(_:rawSQL:arguments:adapter:queue:)")
    public convenience init(
        _ databaseWriter: DatabaseWriter,
        sql: String,
        arguments: StatementArguments? = nil,
        adapter: RowAdapter? = nil,
        queue: DispatchQueue = .main) throws { preconditionFailure() }
}

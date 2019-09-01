import Dispatch

// Fixits for changes introduced by GRDB 4.0.0

extension Cursor {
    @available(*, unavailable, renamed: "compactMap")
    public func flatMap<ElementOfResult>(
        _ transform: @escaping (Element) throws -> ElementOfResult?)
        -> MapCursor<FilterCursor<MapCursor<Self, ElementOfResult?>>, ElementOfResult>
    { preconditionFailure() }
}

extension DatabaseWriter {
    @available(*, unavailable, message: "Use concurrentRead instead")
    public func readFromCurrentState(_ block: @escaping (Database) -> Void) throws { preconditionFailure() }
}

extension ValueObservation {
    @available(*, unavailable, message: "Provide the reducer in a (Database) -> Reducer closure")
    public static func tracking(_ regions: DatabaseRegionConvertible..., reducer: Reducer)
        -> ValueObservation
    { preconditionFailure() }
    
    @available(*, unavailable, message: "Use removeDuplicates() instead")
    public static func tracking<Value>(
        _ regions: DatabaseRegionConvertible...,
        fetchDistinct fetch: @escaping (Database) throws -> Value)
        -> ValueObservation<ValueReducers.RemoveDuplicates<ValueReducers.Fetch<Value>>>
        where Value: Equatable
    { preconditionFailure() }
}

@available(*, unavailable, renamed: "FastDatabaseValueCursor")
public typealias ColumnCursor<Value> = FastDatabaseValueCursor<Value>
    where Value: DatabaseValueConvertible & StatementColumnConvertible

@available(*, unavailable, renamed: "FastNullableDatabaseValueCursor")
public typealias NullableColumnCursor<Value> = FastNullableDatabaseValueCursor<Value>
    where Value: DatabaseValueConvertible & StatementColumnConvertible

extension Database {
    @available(*, unavailable, renamed: "execute(sql:arguments:)")
    public func execute(_ sql: String, arguments: StatementArguments? = nil) throws { preconditionFailure() }
    
    @available(*, unavailable, renamed: "makeSelectStatement(sql:)")
    public func makeSelectStatement(_ sql: String) throws -> SelectStatement { preconditionFailure() }
    
    @available(*, unavailable, renamed: "cachedSelectStatement(sql:)")
    public func cachedSelectStatement(_ sql: String) throws -> SelectStatement { preconditionFailure() }
    
    @available(*, unavailable, renamed: "makeUpdateStatement(sql:)")
    public func makeUpdateStatement(_ sql: String) throws -> UpdateStatement { preconditionFailure() }
    
    @available(*, unavailable, renamed: "cachedUpdateStatement(sql:)")
    public func cachedUpdateStatement(_ sql: String) throws -> UpdateStatement { preconditionFailure() }
}

extension DatabaseValueConvertible {
    @available(*, unavailable, renamed: "fetchCursor(_:sql:arguments:adapter:)")
    public static func fetchCursor(
        _ db: Database,
        _ sql: String,
        arguments: StatementArguments? = nil,
        adapter: RowAdapter? = nil)
        throws -> DatabaseValueCursor<Self>
    { preconditionFailure() }
    
    @available(*, unavailable, renamed: "fetchAll(_:sql:arguments:adapter:)")
    public static func fetchAll(
        _ db: Database,
        _ sql: String,
        arguments: StatementArguments? = nil,
        adapter: RowAdapter? = nil)
        throws -> [Self]
    { preconditionFailure() }
    
    @available(*, unavailable, renamed: "fetchOne(_:sql:arguments:adapter:)")
    public static func fetchOne(
        _ db: Database,
        _ sql: String,
        arguments: StatementArguments? = nil,
        adapter: RowAdapter? = nil)
        throws -> Self?
    { preconditionFailure() }
}

extension Optional where Wrapped: DatabaseValueConvertible {
    @available(*, unavailable, renamed: "fetchCursor(_:sql:arguments:adapter:)")
    public static func fetchCursor(
        _ db: Database,
        _ sql: String,
        arguments: StatementArguments? = nil,
        adapter: RowAdapter? = nil)
        throws -> NullableDatabaseValueCursor<Wrapped>
    { preconditionFailure() }
    
    @available(*, unavailable, renamed: "fetchAll(_:sql:arguments:adapter:)")
    public static func fetchAll(
        _ db: Database,
        _ sql: String,
        arguments: StatementArguments? = nil,
        adapter: RowAdapter? = nil)
        throws -> [Wrapped?]
    { preconditionFailure() }
}

extension Row {
    @available(*, unavailable, renamed: "fetchCursor(_:sql:arguments:adapter:)")
    public static func fetchCursor(
        _ db: Database,
        _ sql: String,
        arguments: StatementArguments? = nil,
        adapter: RowAdapter? = nil)
        throws -> RowCursor
    { preconditionFailure() }
    
    @available(*, unavailable, renamed: "fetchAll(_:sql:arguments:adapter:)")
    public static func fetchAll(
        _ db: Database,
        _ sql: String,
        arguments: StatementArguments? = nil,
        adapter: RowAdapter? = nil)
        throws -> [Row]
    { preconditionFailure() }
    
    @available(*, unavailable, renamed: "fetchOne(_:sql:arguments:adapter:)")
    public static func fetchOne(
        _ db: Database,
        _ sql: String,
        arguments: StatementArguments? = nil,
        adapter: RowAdapter? = nil)
        throws -> Row?
    { preconditionFailure() }
}

extension DatabaseValueConvertible where Self: StatementColumnConvertible {
    @available(*, unavailable, renamed: "fetchCursor(_:sql:arguments:adapter:)")
    public static func fetchCursor(
        _ db: Database,
        _ sql: String,
        arguments: StatementArguments? = nil,
        adapter: RowAdapter? = nil)
        throws -> FastDatabaseValueCursor<Self>
    { preconditionFailure() }
}

extension Optional where Wrapped: DatabaseValueConvertible & StatementColumnConvertible {
    @available(*, unavailable, renamed: "fetchCursor(_:sql:arguments:adapter:)")
    public static func fetchCursor(
        _ db: Database,
        _ sql: String,
        arguments: StatementArguments? = nil,
        adapter: RowAdapter? = nil)
        throws -> FastNullableDatabaseValueCursor<Wrapped>
    { preconditionFailure() }
}

extension FetchableRecord {
    @available(*, unavailable, renamed: "fetchCursor(_:sql:arguments:adapter:)")
    public static func fetchCursor(
        _ db: Database,
        _ sql: String,
        arguments: StatementArguments? = nil,
        adapter: RowAdapter? = nil)
        throws -> RecordCursor<Self>
    { preconditionFailure() }
    
    @available(*, unavailable, renamed: "fetchAll(_:sql:arguments:adapter:)")
    public static func fetchAll(
        _ db: Database,
        _ sql: String,
        arguments: StatementArguments? = nil,
        adapter: RowAdapter? = nil)
        throws -> [Self]
    { preconditionFailure() }
    
    @available(*, unavailable, renamed: "fetchOne(_:sql:arguments:adapter:)")
    public static func fetchOne(
        _ db: Database,
        _ sql: String,
        arguments: StatementArguments? = nil,
        adapter: RowAdapter? = nil)
        throws -> Self?
    { preconditionFailure() }
}

extension SQLRequest {
    @available(*, unavailable, renamed: "init(sql:arguments:adapter:cached:)")
    public init(
        _ sql: String,
        arguments: StatementArguments? = nil,
        adapter: RowAdapter? = nil,
        cached: Bool = false)
    { preconditionFailure() }
}

extension SQLExpressionLiteral {
    @available(*, unavailable, renamed: "init(sql:arguments:)")
    public init(_ sql: String, arguments: StatementArguments? = nil) { preconditionFailure() }
}

extension SQLExpression {
    @available(*, unavailable, message: "Use sqlLiteral property instead")
    public var literal: SQLExpressionLiteral { preconditionFailure() }
}

extension FTS3TokenizerDescriptor {
    @available(*, unavailable, renamed: "unicode61(diacritics:separators:tokenCharacters:)")
    public static func unicode61(
        removeDiacritics: Bool,
        separators: Set<Character> = [],
        tokenCharacters: Set<Character> = [])
        -> FTS3TokenizerDescriptor
    { preconditionFailure() }
}

#if SQLITE_ENABLE_FTS5
extension FTS5TokenizerDescriptor {
    @available(*, unavailable, renamed: "unicode61(diacritics:separators:tokenCharacters:)")
    public static func unicode61(
        removeDiacritics: Bool = true,
        separators: Set<Character> = [],
        tokenCharacters: Set<Character> = [])
        -> FTS5TokenizerDescriptor
    { preconditionFailure() }
}
#endif

extension DatabaseValue {
    @available(*, unavailable)
    public func losslessConvert<T>(sql: String? = nil, arguments: StatementArguments? = nil)
        -> T
        where T: DatabaseValueConvertible
    { preconditionFailure() }
    
    @available(*, unavailable)
    public func losslessConvert<T>(sql: String? = nil, arguments: StatementArguments? = nil)
        -> T?
        where T: DatabaseValueConvertible
    { preconditionFailure() }
}

extension ValueScheduling {
    @available(*, unavailable, renamed: "async(onQueue:startImmediately:)")
    public static func onQueue(_ queue: DispatchQueue, startImmediately: Bool)
        -> ValueScheduling
    { preconditionFailure() }
}

extension ValueObservation {
    // swiftlint:disable:next line_length
    @available(*, unavailable, message: "Observation extent is controlled by the lifetime of observers returned by the start() method.")
    public var extent: Database.TransactionObservationExtent {
        get { preconditionFailure() }
        set { preconditionFailure() }
    }
}

extension Configuration {
    @available(*, unavailable, message: "Run the PRAGMA cipher_page_size in Configuration.prepareDatabase instead.")
    public var cipherPageSize: Int {
        get { preconditionFailure() }
        set { preconditionFailure() }
    }
    
    @available(*, unavailable, message: "Run the PRAGMA kdf_iter in Configuration.prepareDatabase instead.")
    public var kdfIterations: Int {
        get { preconditionFailure() }
        set { preconditionFailure() }
    }
}

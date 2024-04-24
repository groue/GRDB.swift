/// A container for database values to store in a database row.
///
/// `PersistenceContainer` is the argument of the
/// ``EncodableRecord/encode(to:)-k9pf`` method.
public struct PersistenceContainer: Sendable {
    // The ordering of the OrderedDictionary helps generating always the same
    // SQL queries, and hit the statement cache.
    private var storage: OrderedDictionary<CaseInsensitiveIdentifier, DatabaseValue>
    
    /// The value associated with the given column.
    ///
    /// The setter accepts any ``DatabaseValueConvertible`` type, but the
    /// getter always returns a ``DatabaseValue``.
    public subscript(_ column: String) -> (any DatabaseValueConvertible)? {
        get {
            storage[CaseInsensitiveIdentifier(rawValue: column)]
        }
        set {
            storage.updateValue(
                newValue?.databaseValue ?? .null,
                forKey: CaseInsensitiveIdentifier(rawValue: column))
        }
    }
    
    /// The value associated with the given column.
    ///
    /// The setter accepts any ``DatabaseValueConvertible`` type, but the
    /// getter always returns a ``DatabaseValue``.
    public subscript(_ column: some ColumnExpression) -> (any DatabaseValueConvertible)? {
        get { self[column.name] }
        set { self[column.name] = newValue }
    }
    
    init() {
        storage = OrderedDictionary()
    }
    
    init(minimumCapacity: Int) {
        storage = OrderedDictionary(minimumCapacity: minimumCapacity)
    }
    
    /// Convenience initializer from a record
    init<Record: EncodableRecord>(_ record: Record) throws {
        self.init()
        try record.encode(to: &self)
    }
    
    /// Convenience initializer from a database connection and a record
    @usableFromInline
    init(_ db: Database, _ record: some EncodableRecord & TableRecord) throws {
        let databaseTableName = type(of: record).databaseTableName
        let columnCount = try db.columns(in: databaseTableName).count
        self.init(minimumCapacity: columnCount) // Optimization
        try record.encode(to: &self)
    }
    
    /// Columns stored in the container, ordered like values.
    var columns: [String] { storage.keys.map(\.rawValue) }
    
    /// Values stored in the container, ordered like columns.
    var values: [DatabaseValue] { storage.values }
    
    /// Returns ``DatabaseValue/null`` if column is not defined
    func databaseValue(at column: String) -> DatabaseValue {
        storage[CaseInsensitiveIdentifier(rawValue: column)] ?? .null
    }
    
    @usableFromInline
    func changesIterator(from container: PersistenceContainer) -> AnyIterator<(String, DatabaseValue)> {
        var newValueIterator = storage.makeIterator()
        return AnyIterator {
            // Loop until we find a change, or exhaust columns:
            while let (column, newDbValue) = newValueIterator.next() {
                let oldDbValue = container.storage[column] ?? .null
                if newDbValue != oldDbValue {
                    return (column.rawValue, oldDbValue)
                }
            }
            return nil
        }
    }
}

extension PersistenceContainer: RandomAccessCollection {
    public typealias Index = Int
    
    public var startIndex: Int { storage.startIndex }
    
    public var endIndex: Int { storage.endIndex }
    
    /// Returns the (column, value) pair at given index.
    public subscript(position: Int) -> (String, DatabaseValue) {
        let element = storage[position]
        return (element.key.rawValue, element.value)
    }
}

extension Row {
    convenience init<Record: EncodableRecord>(_ record: Record) throws {
        try self.init(PersistenceContainer(record))
    }
    
    convenience init(_ container: PersistenceContainer) {
        self.init(impl: ArrayRowImpl(columns: container.lazy.map { ($0, $1) }))
    }
}

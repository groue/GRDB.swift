#if !USING_BUILTIN_SQLITE
    #if os(OSX)
        import SQLiteMacOSX
    #elseif os(iOS)
        #if (arch(i386) || arch(x86_64))
            import SQLiteiPhoneSimulator
        #else
            import SQLiteiPhoneOS
        #endif
    #endif
#endif

// MARK: - Scope

/// TODO: documentation
public final class Scope {
    let name: String?
    
    init(_ name: String? = nil) {
        self.name = name
    }
}

extension Scope : Equatable { }

// Two scopes are equal if and only if (they are the same instance), or (both are named, and the names are equal).
public func == (lhs: Scope, rhs: Scope) -> Bool {
    if lhs === rhs { return true }
    if case let (lname?, rname?) = (lhs.name, rhs.name) where lname == rname { return true }
    return false
}

extension Scope : Hashable {
    public var hashValue: Int {
        if let name = name {
            return name.hashValue
        } else {
            return ObjectIdentifier(self).hashValue
        }
    }
}


// MARK: - ConcreteColumnMapping

/// ConcreteColumnMapping is a type that supports the RowAdapter protocol.
public struct ConcreteColumnMapping {
    let mapping: [(Int, String)]                // [(baseRowIndex, adaptedColumn), ...]
    let lowercaseColumnIndexes: [String: Int]   // [adaptedColumn: adaptedRowIndex]
    let failureColumnIndexes: [Int]             // indexes in baseRow. If non empty, and all columns are NULL, the mapping is "failed".

    /// Creates an ConcreteColumnMapping from an array of (index, name)
    /// pairs. In each pair:
    ///
    /// - index is the index of a column in an original row
    /// - name is the name of the column in an adapted row
    ///
    /// For example, the following ConcreteColumnMapping defines two
    /// columns, "foo" and "bar", that load from the original columns at
    /// indexes 1 and 2:
    ///
    ///     ConcreteColumnMapping([(1, "foo"), (2, "bar")])
    ///
    /// Use it in your custom RowAdapter type:
    ///
    ///     struct FooBarAdapter : RowAdapter {
    ///         func concreteRowAdapter(with statement: SelectStatement) throws -> ConcreteRowAdapter {
    ///             return ConcreteColumnMapping([(1, "foo"), (2, "bar")])
    ///         }
    ///     }
    ///
    ///     // <Row foo:"foo" bar: "bar">
    ///     Row.fetchOne(db, "SELECT NULL, 'foo', 'bar'", adapter: FooBarAdapter())
    ///
    /// TODO: document failureColumnIndexes
    public init(mapping: [(Int, String)], failureColumnIndexes: [Int]? = nil) {
        self.mapping = mapping
        self.lowercaseColumnIndexes = Dictionary(keyValueSequence: mapping.enumerate().map { ($1.1.lowercaseString, $0) }.reverse())
        self.failureColumnIndexes = failureColumnIndexes ?? mapping.map { (index, name) in index }
    }

    var count: Int {
        return mapping.count
    }

    func baseColumIndex(adaptedIndex index: Int) -> Int {
        return mapping[index].0
    }

    func columnName(adaptedIndex index: Int) -> String {
        return mapping[index].1
    }

    func adaptedIndexOfColumn(named name: String) -> Int? {
        if let index = lowercaseColumnIndexes[name] {
            return index
        }
        return lowercaseColumnIndexes[name.lowercaseString]
    }
}

/// ConcreteColumnMapping adopts ConcreteRowAdapter
extension ConcreteColumnMapping : ConcreteRowAdapter {
    /// Part of the ConcreteRowAdapter protocol; returns self.
    public var concreteColumnMapping: ConcreteColumnMapping {
        return self
    }
    
    /// Part of the ConcreteRowAdapter protocol; returns the empty dictionary.
    public var scopes: [Scope: ConcreteRowAdapter] {
        return [:]
    }
    
    /// TODO: documentation
    public func failed(row: Row) -> Bool {
        // IMPORTANT: row has to be the base row
        guard !failureColumnIndexes.isEmpty else { return false }
        return !failureColumnIndexes.contains { row.value(atIndex: $0) != nil }
    }
}


// MARK: - ConcreteRowAdapter

/// ConcreteRowAdapter is a protocol that supports the RowAdapter protocol.
///
/// GRBD ships with a ready-made type that adopts this protocol:
/// ConcreteColumnMapping.
///
/// It is unlikely that you need to write your custom type that adopts
/// this protocol.
public protocol ConcreteRowAdapter {
    /// A ConcreteColumnMapping that defines how to map a column name to a
    /// column in an original row.
    var concreteColumnMapping: ConcreteColumnMapping { get }
    
    /// A dictionary of scopes
    var scopes: [Scope: ConcreteRowAdapter] { get }
    
    /// Used by joining API to recognize failed left joins.
    func failed(row: Row) -> Bool
}


// MARK: - RowAdapter

/// RowAdapter is a protocol that helps two incompatible row interfaces working
/// together.
///
/// GRDB ships with three concrete types that adopt the RowAdapter protocol:
///
/// - ColumnMapping: renames row columns
/// - SuffixRowAdapter: hides the first columns of a row
/// - ScopeAdapter: groups several adapters together to define named scopes
///
/// If the built-in adapters don't fit your needs, you can implement your own
/// type that adopts RowAdapter.
///
/// To use a row adapter, provide it to any method that fetches:
///
///     let adapter = SuffixRowAdapter(fromIndex: 2)
///     let sql = "SELECT 1 AS foo, 2 AS bar, 3 AS baz"
///
///     // <Row baz:3>
///     Row.fetchOne(db, sql, adapter: adapter)
public protocol RowAdapter {
    
    /// You never call this method directly. It is called for you whenever an
    /// adapter has to be applied.
    ///
    /// The result is a value that adopts ConcreteRowAdapter, such as
    /// ConcreteColumnMapping.
    ///
    /// For example:
    ///
    ///     // An adapter that turns any row to a row that contains a single
    ///     // column named "foo" whose value is the leftmost value of the
    ///     // original row.
    ///     struct FirstColumnAdapter : RowAdapter {
    ///         func concreteRowAdapter(with statement: SelectStatement) throws -> ConcreteRowAdapter {
    ///             return ConcreteColumnMapping(columns: [(0, "foo")])
    ///         }
    ///     }
    ///
    ///     // <Row foo:1>
    ///     Row.fetchOne(db, "SELECT 1, 2, 3", adapter: FirstColumnAdapter())
    func concreteRowAdapter(with statement: SelectStatement) throws -> ConcreteRowAdapter
}

extension RowAdapter {
    /// Returns an adapter based on self, with added scopes.
    ///
    /// If self already defines scopes, the added scopes replace
    /// eventual existing scopes with the same name.
    ///
    /// - parameter scopes: A dictionary that maps scope names to
    ///   row adapters.
    func addingScopes(scopes: [Scope: RowAdapter]) -> RowAdapter {
        if scopes.isEmpty {
            return self
        } else {
            return ScopeAdapter(mainAdapter: self, scopes: scopes)
        }
    }
    
    /// Returns an adapter based on self, with added scopes.
    ///
    /// If self already defines scopes, the added scopes replace
    /// eventual existing scopes with the same name.
    ///
    /// - parameter scopes: A dictionary that maps scope names to
    ///   row adapters.
    public func addingScopes(scopes: [String: RowAdapter]) -> RowAdapter {
        return addingScopes(Dictionary(keyValueSequence: scopes.map { (Scope($0), $1) }))
    }
}


// MARK: - ColumnMapping

/// ColumnMapping is a row adapter that maps column names.
///
///     let adapter = ColumnMapping(["foo": "bar"])
///     let sql = "SELECT 'foo' AS foo, 'bar' AS bar, 'baz' AS baz"
///
///     // <Row foo:"bar">
///     Row.fetchOne(db, sql, adapter: adapter)
public struct ColumnMapping : RowAdapter {
    /// The column names mapping, from adapted names to original names.
    let mapping: [String: String]
    
    /// Creates a ColumnMapping with a dictionary that maps adapted column names
    /// to original column names.
    public init(_ mapping: [String: String]) {
        self.mapping = mapping
    }
    
    /// Part of the RowAdapter protocol
    public func concreteRowAdapter(with statement: SelectStatement) throws -> ConcreteRowAdapter {
        let mapping = try self.mapping
            .map { (mappedColumn, baseColumn) -> (Int, String) in
                guard let index = statement.indexOfColumn(named: baseColumn) else {
                    throw DatabaseError(code: SQLITE_MISUSE, message: "Mapping references missing column \(baseColumn). Valid column names are: \(statement.columnNames.joinWithSeparator(", ")).")
                }
                return (index, mappedColumn)
            }
            .sort { $0.0 < $1.0 }
        return ConcreteColumnMapping(mapping: mapping)
    }
}


// MARK: - SuffixRowAdapter

/// SuffixRowAdapter is a row adapter that hides the first columns in a row.
///
///     let adapter = SuffixRowAdapter(fromIndex: 2)
///     let sql = "SELECT 1 AS foo, 2 AS bar, 3 AS baz"
///
///     // <Row baz:3>
///     Row.fetchOne(db, sql, adapter: adapter)
public struct SuffixRowAdapter : RowAdapter {
    /// The suffix index
    let index: Int
    let failureEndIndex: Int?
    
    /// Creates a SuffixRowAdapter that hides all columns before the
    /// provided index.
    ///
    /// If index is 0, the adapted row is identical to the original row.
    public init(fromIndex index: Int) {
        self.init(fromIndex: index, failureEndIndex: nil)
    }
    
    /// Creates a SuffixRowAdapter that hides all columns before the
    /// provided index.
    ///
    /// If index is 0, the adapted row is identical to the original row.
    ///
    /// TODO: document failureEndIndex
    public init(fromIndex index: Int, failureEndIndex: Int?) {
        GRDBPrecondition(index >= 0, "Negative column index is out of range")
        self.index = index
        self.failureEndIndex = failureEndIndex
    }
    
    /// Part of the RowAdapter protocol
    public func concreteRowAdapter(with statement: SelectStatement) throws -> ConcreteRowAdapter {
        GRDBPrecondition(index <= statement.columnCount, "Column index is out of range")
        let failureEndIndex = self.failureEndIndex ?? statement.columnCount
        return ConcreteColumnMapping(
            mapping: statement.columnNames.suffixFrom(index).enumerate().map { ($0 + index, $1) },
            failureColumnIndexes: Array(index..<failureEndIndex))
    }
}


// MARK: - ScopeAdapter

/// ScopeAdapter is a row adapter that lets you define scopes on rows.
///
///     // Two adapters
///     let fooAdapter = ColumnMapping(["value": "foo"])
///     let barAdapter = ColumnMapping(["value": "bar"])
///
///     // Define scopes
///     let adapter = ScopeAdapter([
///         "foo": fooAdapter,
///         "bar": barAdapter])
///
///     // Fetch
///     let sql = "SELECT 'foo' AS foo, 'bar' AS bar"
///     let row = Row.fetchOne(db, sql, adapter: adapter)!
///
///     // Scoped rows:
///     if let fooRow = row.scoped(on: "foo") {
///         fooRow.value(named: "value")    // "foo"
///     }
///     if let barRow = row.scopeed(on: "bar") {
///         barRow.value(named: "value")    // "bar"
///     }
public struct ScopeAdapter : RowAdapter {
    
    /// The main adapter
    let mainAdapter: RowAdapter
    
    /// The scope adapters
    let scopes: [Scope: RowAdapter]
    
    /// Creates a scoped adapter.
    ///
    /// - parameter scopes: A dictionary that maps scope names to
    ///   row adapters.
    public init(_ scopes: [String: RowAdapter]) {
        // Use SuffixRowAdapter(fromIndex: 0) as the identity adapter
        self.init(mainAdapter: SuffixRowAdapter(fromIndex: 0), scopes: Dictionary(keyValueSequence: scopes.map { (Scope($0), $1) }))
    }
    
    init(mainAdapter: RowAdapter, scopes: [Scope: RowAdapter]) {
        self.mainAdapter = mainAdapter
        self.scopes = scopes
    }
    
    /// Part of the RowAdapter protocol
    public func concreteRowAdapter(with statement: SelectStatement) throws -> ConcreteRowAdapter {
        let mainConcreteAdapter = try mainAdapter.concreteRowAdapter(with: statement)
        var concreteAdapterScopes = mainConcreteAdapter.scopes
        for (scope, adapter) in scopes {
            try concreteAdapterScopes[scope] = adapter.concreteRowAdapter(with: statement)
        }
        return ConcreteScopeAdapter(
            concreteColumnMapping: mainConcreteAdapter.concreteColumnMapping,
            scopes: concreteAdapterScopes)
    }
}

/// The concrete row adapter for ScopeAdapter
struct ConcreteScopeAdapter : ConcreteRowAdapter {
    let concreteColumnMapping: ConcreteColumnMapping
    let scopes: [Scope: ConcreteRowAdapter]
    
    func failed(row: Row) -> Bool {
        return concreteColumnMapping.failed(row)
    }
}


// MARK: - Row

extension Row {
    /// Creates a row from a base row and a statement adapter
    convenience init(baseRow: Row, concreteRowAdapter: ConcreteRowAdapter) {
        self.init(impl: AdapterRowImpl(baseRow: baseRow, concreteRowAdapter: concreteRowAdapter))
    }

    /// Returns self if adapter is nil
    func adaptedRow(adapter adapter: RowAdapter?, statement: SelectStatement) throws -> Row {
        guard let adapter = adapter else {
            return self
        }
        return try Row(baseRow: self, concreteRowAdapter: adapter.concreteRowAdapter(with: statement))
    }
}

struct AdapterRowImpl : RowImpl {
    let baseRow: Row
    let concreteRowAdapter: ConcreteRowAdapter
    let concreteColumnMapping: ConcreteColumnMapping

    init(baseRow: Row, concreteRowAdapter: ConcreteRowAdapter) {
        self.baseRow = baseRow
        self.concreteRowAdapter = concreteRowAdapter
        self.concreteColumnMapping = concreteRowAdapter.concreteColumnMapping
    }

    var count: Int {
        return concreteColumnMapping.count
    }

    func databaseValue(atIndex index: Int) -> DatabaseValue {
        return baseRow.databaseValue(atIndex: concreteColumnMapping.baseColumIndex(adaptedIndex: index))
    }

    func dataNoCopy(atIndex index:Int) -> NSData? {
        return baseRow.dataNoCopy(atIndex: concreteColumnMapping.baseColumIndex(adaptedIndex: index))
    }

    func columnName(atIndex index: Int) -> String {
        return concreteColumnMapping.columnName(adaptedIndex: index)
    }

    func indexOfColumn(named name: String) -> Int? {
        return concreteColumnMapping.adaptedIndexOfColumn(named: name)
    }

    func scoped(on scope: Scope) -> Row? {
        guard let concreteRowAdapter = concreteRowAdapter.scopes[scope] else {
            return nil
        }
        if concreteRowAdapter.failed(baseRow) {
            return nil
        }
        return Row(baseRow: baseRow, concreteRowAdapter: concreteRowAdapter)
    }
    
    var scopes: Set<Scope> {
        return Set(concreteRowAdapter.scopes.keys)
    }
    
    func copy(row: Row) -> Row {
        return Row(baseRow: baseRow.copy(), concreteRowAdapter: concreteRowAdapter)
    }
}

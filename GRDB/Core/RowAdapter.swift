#if !USING_BUILTIN_SQLITE
    #if os(OSX)
        import SQLiteMacOSX
    #elseif os(iOS)
        #if (arch(i386) || arch(x86_64))
            import SQLiteiPhoneSimulator
        #else
            import SQLiteiPhoneOS
        #endif
    #elseif os(watchOS)
        #if (arch(i386) || arch(x86_64))
            import SQLiteWatchSimulator
        #else
            import SQLiteWatchOS
        #endif
    #endif
#endif

/// ConcreteColumnMapping is a type that supports the RowAdapter protocol.
public struct ConcreteColumnMapping {
    let columns: [(Int, String)]         // [(baseRowIndex, adaptedColumn), ...]
    let lowercaseColumnIndexes: [String: Int]   // [adaptedColumn: adaptedRowIndex]
    
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
    public init(columns: [(Int, String)]) {
        self.columns = columns
        self.lowercaseColumnIndexes = Dictionary(keyValueSequence: columns.enumerated().map { ($1.1.lowercased(), $0) }.reversed())
    }
    
    var count: Int {
        return columns.count
    }
    
    func baseColumIndex(adaptedIndex index: Int) -> Int {
        return columns[index].0
    }
    
    func columnName(adaptedIndex index: Int) -> String {
        return columns[index].1
    }
    
    func adaptedIndexOfColumn(named name: String) -> Int? {
        if let index = lowercaseColumnIndexes[name] {
            return index
        }
        return lowercaseColumnIndexes[name.lowercased()]
    }
}

/// ConcreteColumnMapping adopts ConcreteRowAdapter
extension ConcreteColumnMapping : ConcreteRowAdapter {
    /// Part of the ConcreteRowAdapter protocol; returns self.
    public var concreteColumnMapping: ConcreteColumnMapping {
        return self
    }
    
    /// Part of the ConcreteRowAdapter protocol; returns the empty dictionary.
    public var scopes: [String: ConcreteRowAdapter] {
        return [:]
    }
}

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
    var scopes: [String: ConcreteRowAdapter] { get }
}

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
    public func addingScopes(_ scopes: [String: RowAdapter]) -> RowAdapter {
        return ScopeAdapter(mainAdapter: self, scopes: scopes)
    }
}

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
        let columns = try mapping
            .map { (mappedColumn, baseColumn) -> (Int, String) in
                guard let index = statement.index(ofColumn: baseColumn) else {
                    throw DatabaseError(code: SQLITE_MISUSE, message: "Mapping references missing column \(baseColumn). Valid column names are: \(statement.columnNames.joined(separator: ", ")).")
                }
                return (index, mappedColumn)
            }
            .sorted { $0.0 < $1.0 }
        return ConcreteColumnMapping(columns: columns)
    }
}

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
    
    /// Creates a SuffixRowAdapter that hides all columns before the
    /// provided index.
    ///
    /// If index is 0, the adapted row is identical to the original row.
    public init(fromIndex index: Int) {
        GRDBPrecondition(index >= 0, "Negative column index is out of range")
        self.index = index
    }
    
    /// Part of the RowAdapter protocol
    public func concreteRowAdapter(with statement: SelectStatement) throws -> ConcreteRowAdapter {
        GRDBPrecondition(index <= statement.columnCount, "Column index is out of range")
        return ConcreteColumnMapping(columns: statement.columnNames.suffix(from: index).enumerated().map { ($0 + index, $1) })
    }
}

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
    let scopes: [String: RowAdapter]
    
    /// Creates a scoped adapter.
    ///
    /// - parameter scopes: A dictionary that maps scope names to
    ///   row adapters.
    public init(_ scopes: [String: RowAdapter]) {
        self.mainAdapter = SuffixRowAdapter(fromIndex: 0)   // Use SuffixRowAdapter(fromIndex: 0) as the identity adapter
        self.scopes = scopes
    }
    
    init(mainAdapter: RowAdapter, scopes: [String: RowAdapter]) {
        self.mainAdapter = mainAdapter
        self.scopes = scopes
    }
    
    /// Part of the RowAdapter protocol
    public func concreteRowAdapter(with statement: SelectStatement) throws -> ConcreteRowAdapter {
        let mainConcreteAdapter = try mainAdapter.concreteRowAdapter(with: statement)
        var concreteAdapterScopes = mainConcreteAdapter.scopes
        for (name, adapter) in scopes {
            try concreteAdapterScopes[name] = adapter.concreteRowAdapter(with: statement)
        }
        return ConcreteScopeAdapter(
            concreteColumnMapping: mainConcreteAdapter.concreteColumnMapping,
            scopes: concreteAdapterScopes)
    }
}

/// The concrete row adapter for ScopeAdapter
struct ConcreteScopeAdapter : ConcreteRowAdapter {
    let concreteColumnMapping: ConcreteColumnMapping
    let scopes: [String: ConcreteRowAdapter]
}

extension Row {
    /// Creates a row from a base row and a statement adapter
    convenience init(baseRow: Row, concreteRowAdapter: ConcreteRowAdapter) {
        self.init(impl: AdapterRowImpl(baseRow: baseRow, concreteRowAdapter: concreteRowAdapter))
    }

    /// Returns self if adapter is nil
    func adaptedRow(adapter: RowAdapter?, statement: SelectStatement) throws -> Row {
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
    
    func databaseValue(atUncheckedIndex index: Int) -> DatabaseValue {
        return baseRow.value(atIndex: concreteColumnMapping.baseColumIndex(adaptedIndex: index))
    }
    
    func dataNoCopy(atUncheckedIndex index:Int) -> Data? {
        return baseRow.dataNoCopy(atIndex: concreteColumnMapping.baseColumIndex(adaptedIndex: index))
    }
    
    func columnName(atUncheckedIndex index: Int) -> String {
        return concreteColumnMapping.columnName(adaptedIndex: index)
    }
    
    func index(ofColumn name: String) -> Int? {
        return concreteColumnMapping.adaptedIndexOfColumn(named: name)
    }
    
    func scoped(on name: String) -> Row? {
        guard let concreteRowAdapter = concreteRowAdapter.scopes[name] else {
            return nil
        }
        return Row(baseRow: baseRow, concreteRowAdapter: concreteRowAdapter)
    }
    
    var scopeNames: Set<String> {
        return Set(concreteRowAdapter.scopes.keys)
    }
    
    func copy(_ row: Row) -> Row {
        return Row(baseRow: baseRow.copy(), concreteRowAdapter: concreteRowAdapter)
    }
}

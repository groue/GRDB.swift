import Foundation

/// Returns an array of row adapters that split a row according to the input
/// number of columns.
///
/// For example:
///
///     let sql = "SELECT 1, 2,3,4, 5,6, 7,8"
///     //               <.><. . .><. .><. .>
///     let adapters = splittingRowAdapters([1, 3, 2])
///     let adapter = ScopeAdapter([
///         "a": adapters[0],
///         "b": adapters[1],
///         "c": adapters[2],
///         "d": adapters[3]])
///     let row = try Row.fetchOne(db, sql: sql, adapter: adapter)
///     row.scopes["a"] // [1]
///     row.scopes["b"] // [2, 3, 4]
///     row.scopes["c"] // [5, 6]
///     row.scopes["d"] // [7, 8]
public func splittingRowAdapters(columnCounts: [Int]) -> [RowAdapter] {
    guard !columnCounts.isEmpty else {
        // Identity adapter
        return [SuffixRowAdapter(fromIndex: 0)]
    }
    
    // [1, 3, 2] -> [0, 1, 4, 6]
    let columnIndexes = columnCounts.reduce(into: [0]) { (acc, count) in
        acc.append(acc.last! + count)
    }
    
    // [0, 1, 4, 6] -> [(0..<1), (1..<4), (4..<6)]
    let rangeAdapters = zip(columnIndexes, columnIndexes.suffix(from: 1))
        .map { RangeRowAdapter($0..<$1) }
    
    // (6...)
    let suffixAdapter = SuffixRowAdapter(fromIndex: columnIndexes.last!)
    
    // [(0..<1), (1..<4), (4..<6), (6...)]
    return rangeAdapters + [suffixAdapter]
}

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// LayoutedColumnMapping is a type that supports the RowAdapter protocol.
///
/// :nodoc:
public struct LayoutedColumnMapping {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// An array of (baseIndex, mappedName) pairs, where baseIndex is the index
    /// of a column in a base row, and mappedName the mapped name of
    /// that column.
    public let layoutColumns: [(Int, String)]
    
    /// A cache for layoutIndex(ofColumn:)
    let lowercaseColumnIndexes: [String: Int]   // [mappedColumn: layoutColumnIndex]
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// Creates a LayoutedColumnMapping from an array of (baseIndex, mappedName)
    /// pairs. In each pair:
    ///
    /// - baseIndex is the index of a column in a base row
    /// - name is the mapped name of the column
    ///
    /// For example, the following LayoutedColumnMapping defines two columns, "foo"
    /// and "bar", based on the base columns at indexes 1 and 2:
    ///
    ///     LayoutedColumnMapping(layoutColumns: [(1, "foo"), (2, "bar")])
    ///
    /// Use it in your custom RowAdapter type:
    ///
    ///     struct FooBarAdapter : RowAdapter {
    ///         func layoutAdapter(layout: RowLayout) throws -> LayoutedRowAdapter {
    ///             return LayoutedColumnMapping(layoutColumns: [(1, "foo"), (2, "bar")])
    ///         }
    ///     }
    ///
    ///     // [foo:"foo" bar: "bar"]
    ///     try Row.fetchOne(db, sql: "SELECT NULL, 'foo', 'bar'", adapter: FooBarAdapter())
    public init<S: Sequence>(layoutColumns: S) where S.Iterator.Element == (Int, String) {
        self.layoutColumns = Array(layoutColumns)
        self.lowercaseColumnIndexes = Dictionary(
            layoutColumns
                .enumerated()
                .map { ($0.element.1.lowercased(), $0.offset) },
            uniquingKeysWith: { (left, _) in left }) // keep leftmost indexes
    }
    
    func baseColumnIndex(atMappingIndex index: Int) -> Int {
        return layoutColumns[index].0
    }
    
    func columnName(atMappingIndex index: Int) -> String {
        return layoutColumns[index].1
    }
}

/// LayoutedColumnMapping adopts LayoutedRowAdapter
///
/// :nodoc:
extension LayoutedColumnMapping: LayoutedRowAdapter {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// Returns self.
    public var mapping: LayoutedColumnMapping {
        return self
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// Returns the empty dictionary.
    public var scopes: [String: LayoutedRowAdapter] {
        return [:]
    }
}

/// :nodoc:
extension LayoutedColumnMapping: RowLayout {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// Returns the index of the leftmost column named `name`, in a
    /// case-insensitive way.
    public func layoutIndex(ofColumn name: String) -> Int? {
        if let index = lowercaseColumnIndexes[name] {
            return index
        }
        return lowercaseColumnIndexes[name.lowercased()]
    }
}

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// LayoutedRowAdapter is a protocol that supports the RowAdapter protocol.
///
/// GRBD ships with a ready-made type that adopts this protocol:
/// LayoutedColumnMapping.
///
/// :nodoc:
public protocol LayoutedRowAdapter {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// A LayoutedColumnMapping that defines how to map a column name to a
    /// column in a base row.
    var mapping: LayoutedColumnMapping { get }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// The layouted row adapters for each scope.
    var scopes: [String: LayoutedRowAdapter] { get }
}

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// RowLayout is a protocol that supports the RowAdapter protocol. It describes
/// a layout of a base row.
///
/// :nodoc:
public protocol RowLayout {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// An array of (baseIndex, name) pairs, where baseIndex is the index
    /// of a column in a base row, and name the name of that column.
    var layoutColumns: [(Int, String)] { get }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// Returns the index of the leftmost column named `name`, in a
    /// case-insensitive way.
    func layoutIndex(ofColumn name: String) -> Int?
}

extension SelectStatement: RowLayout {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public var layoutColumns: [(Int, String)] {
        return Array(columnNames.enumerated())
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public func layoutIndex(ofColumn name: String) -> Int? {
        return index(ofColumn: name)
    }
}

/// RowAdapter is a protocol that helps two incompatible row interfaces working
/// together.
///
/// GRDB ships with four concrete types that adopt the RowAdapter protocol:
///
/// - ColumnMapping: renames row columns
/// - SuffixRowAdapter: hides the first columns of a row
/// - RangeRowAdapter: only exposes a range of columns
/// - ScopeAdapter: groups several adapters together to define named scopes
///
/// To use a row adapter, provide it to any method that fetches:
///
///     let adapter = SuffixRowAdapter(fromIndex: 2)
///     let sql = "SELECT 1 AS foo, 2 AS bar, 3 AS baz"
///
///     // [baz:3]
///     try Row.fetchOne(db, sql: sql, adapter: adapter)
public protocol RowAdapter {
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// You never call this method directly. It is called for you whenever an
    /// adapter has to be applied.
    ///
    /// The result is a value that adopts LayoutedRowAdapter, such as
    /// LayoutedColumnMapping.
    ///
    /// For example:
    ///
    ///     // An adapter that turns any row to a row that contains a single
    ///     // column named "foo" whose value is the leftmost value of the
    ///     // base row.
    ///     struct FirstColumnAdapter : RowAdapter {
    ///         func layoutedAdapter(from layout: RowLayout) throws -> LayoutedRowAdapter {
    ///             return LayoutedColumnMapping(layoutColumns: [(0, "foo")])
    ///         }
    ///     }
    ///
    ///     // [foo:1]
    ///     try Row.fetchOne(db, sql: "SELECT 1, 2, 3", adapter: FirstColumnAdapter())
    func layoutedAdapter(from layout: RowLayout) throws -> LayoutedRowAdapter
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
        if scopes.isEmpty {
            return self
        } else {
            return ScopeAdapter(base: self, scopes: scopes)
        }
    }
}

extension RowAdapter {
    func baseColumnIndex(atIndex index: Int, layout: RowLayout) throws -> Int {
        return try layoutedAdapter(from: layout).mapping.baseColumnIndex(atMappingIndex: index)
    }
}

/// EmptyRowAdapter is a row adapter that hides all columns.
public struct EmptyRowAdapter: RowAdapter {
    /// Creates an EmptyRowAdapter
    public init() { }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public func layoutedAdapter(from layout: RowLayout) throws -> LayoutedRowAdapter {
        return LayoutedColumnMapping(layoutColumns: [])
    }
}

/// ColumnMapping is a row adapter that maps column names.
///
///     let adapter = ColumnMapping(["foo": "bar"])
///     let sql = "SELECT 'foo' AS foo, 'bar' AS bar, 'baz' AS baz"
///
///     // [foo:"bar"]
///     try Row.fetchOne(db, sql: sql, adapter: adapter)
public struct ColumnMapping: RowAdapter {
    /// A dictionary from mapped column names to column names in a base row.
    let mapping: [String: String]
    
    /// Creates a ColumnMapping with a dictionary from mapped column names to
    /// column names in a base row.
    public init(_ mapping: [String: String]) {
        self.mapping = mapping
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public func layoutedAdapter(from layout: RowLayout) throws -> LayoutedRowAdapter {
        let layoutColumns = try mapping
            .map { (mappedColumn, baseColumn) -> (Int, String) in
                guard let index = layout.layoutIndex(ofColumn: baseColumn) else {
                    let columnNames = layout.layoutColumns.map { $0.1 }
                    throw DatabaseError(
                        resultCode: .SQLITE_MISUSE,
                        message: """
                            Mapping references missing column \(baseColumn). \
                            Valid column names are: \(columnNames.joined(separator: ", ")).
                            """)
                }
                let baseIndex = layout.layoutColumns[index].0
                return (baseIndex, mappedColumn)
            }
            .sorted { $0.0 < $1.0 } // preserve ordering of base columns
        return LayoutedColumnMapping(layoutColumns: layoutColumns)
    }
}

/// SuffixRowAdapter is a row adapter that hides the first columns in a row.
///
///     let adapter = SuffixRowAdapter(fromIndex: 2)
///     let sql = "SELECT 1 AS foo, 2 AS bar, 3 AS baz"
///
///     // [baz:3]
///     try Row.fetchOne(db, sql: sql, adapter: adapter)
public struct SuffixRowAdapter: RowAdapter {
    /// The suffix index
    let index: Int
    
    /// Creates a SuffixRowAdapter that hides all columns before the
    /// provided index.
    ///
    /// If index is 0, the layout row is identical to the base row.
    public init(fromIndex index: Int) {
        GRDBPrecondition(index >= 0, "Negative column index is out of range")
        self.index = index
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public func layoutedAdapter(from layout: RowLayout) throws -> LayoutedRowAdapter {
        return LayoutedColumnMapping(layoutColumns: layout.layoutColumns.suffix(from: index))
    }
}

/// RangeRowAdapter is a row adapter that only exposes a range of columns.
///
///     let adapter = RangeRowAdapter(1..<3)
///     let sql = "SELECT 1 AS foo, 2 AS bar, 3 AS baz, 4 as qux"
///
///     // [bar:2 baz:3]
///     try Row.fetchOne(db, sql: sql, adapter: adapter)
public struct RangeRowAdapter: RowAdapter {
    /// The range
    let range: CountableRange<Int>
    
    /// Creates a RangeRowAdapter that only exposes a range of columns.
    public init(_ range: CountableRange<Int>) {
        GRDBPrecondition(range.lowerBound >= 0, "Negative column index is out of range")
        self.range = range
    }
    
    /// Creates a RangeRowAdapter that only exposes a range of columns.
    public init(_ range: CountableClosedRange<Int>) {
        GRDBPrecondition(range.lowerBound >= 0, "Negative column index is out of range")
        self.range = range.lowerBound..<(range.upperBound + 1)
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public func layoutedAdapter(from layout: RowLayout) throws -> LayoutedRowAdapter {
        return LayoutedColumnMapping(layoutColumns: layout.layoutColumns[range])
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
///     let row = try Row.fetchOne(db, sql: sql, adapter: adapter)!
///
///     // Scoped rows:
///     if let fooRow = row.scopes["foo"] {
///         fooRow["value"]    // "foo"
///     }
///     if let barRow = row.scopes["bar"] {
///         barRow["value"]    // "bar"
///     }
public struct ScopeAdapter: RowAdapter {
    
    /// The base adapter
    let base: RowAdapter
    
    /// The scope adapters
    let scopes: [String: RowAdapter]
    
    /// Creates an adapter that preserves row contents and add scoped rows.
    ///
    /// For example:
    ///
    ///     let adapter = ScopeAdapter(["suffix": SuffixRowAdapter(fromIndex: 1)])
    ///     let row = try Row.fetchOne(db, sql: "SELECT 1, 2, 3", adapter: adapter)!
    ///     row                  // [1, 2, 3]
    ///     row.scopes["suffix"] // [2, 3]
    ///
    /// - parameter scopes: A dictionary that maps scope names to
    ///   row adapters.
    public init(_ scopes: [String: RowAdapter]) {
        // Use SuffixRowAdapter(fromIndex: 0) as the identity adapter
        self.init(base: SuffixRowAdapter(fromIndex: 0), scopes: scopes)
    }
    
    /// Creates an adapter based on the base adapter, and add scoped rows.
    ///
    /// For example:
    ///
    ///     let baseAdapter = RangeRowAdapter(0..<1)
    ///     let adapter = ScopeAdapter(base: baseAdapter, scopes: ["suffix": SuffixRowAdapter(fromIndex: 1)])
    ///     let row = try Row.fetchOne(db, sql: "SELECT 1, 2, 3", adapter: adapter)!
    ///     row                   // [1]
    ///     row.scopes["initial"] // [2, 3]
    ///
    /// If the base adapter already defines scopes, the given scopes replace
    /// eventual existing scopes with the same name.
    ///
    /// This initializer is equivalent to `baseAdapter.addingScopes(scopes)`.
    ///
    /// - parameter base: A dictionary that maps scope names to
    ///   row adapters.
    /// - parameter scopes: A dictionary that maps scope names to
    ///   row adapters.
    public init(base: RowAdapter, scopes: [String: RowAdapter]) {
        self.base = base
        self.scopes = scopes
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public func layoutedAdapter(from layout: RowLayout) throws -> LayoutedRowAdapter {
        let layoutedAdapter = try base.layoutedAdapter(from: layout)
        var layoutedScopes = layoutedAdapter.scopes
        for (name, adapter) in scopes {
            try layoutedScopes[name] = adapter.layoutedAdapter(from: layout)
        }
        return LayoutedScopeAdapter(
            mapping: layoutedAdapter.mapping,
            scopes: layoutedScopes)
    }
}

/// The LayoutedRowAdapter for ScopeAdapter
struct LayoutedScopeAdapter: LayoutedRowAdapter {
    let mapping: LayoutedColumnMapping
    let scopes: [String: LayoutedRowAdapter]
}

struct ChainedAdapter: RowAdapter {
    let first: RowAdapter
    let second: RowAdapter
    
    func layoutedAdapter(from layout: RowLayout) throws -> LayoutedRowAdapter {
        return try second.layoutedAdapter(from: first.layoutedAdapter(from: layout).mapping)
    }
}

extension Row {
    /// Creates a row from a base row and a statement adapter
    convenience init(base: Row, adapter: LayoutedRowAdapter) {
        self.init(impl: AdaptedRowImpl(base: base, adapter: adapter))
    }
    
    /// Returns self if adapter is nil
    func adapted(with adapter: RowAdapter?, layout: RowLayout) throws -> Row {
        guard let adapter = adapter else {
            return self
        }
        return try Row(base: self, adapter: adapter.layoutedAdapter(from: layout))
    }
}

struct AdaptedRowImpl: RowImpl {
    let base: Row
    let adapter: LayoutedRowAdapter
    let mapping: LayoutedColumnMapping
    
    init(base: Row, adapter: LayoutedRowAdapter) {
        self.base = base
        self.adapter = adapter
        self.mapping = adapter.mapping
    }
    
    var count: Int {
        return mapping.layoutColumns.count
    }
    
    var isFetched: Bool {
        return base.isFetched
    }
    
    func scopes(prefetchedRows: Row.PrefetchedRowsView) -> Row.ScopesView {
        return Row.ScopesView(row: base, scopes: adapter.scopes, prefetchedRows: prefetchedRows)
    }
    
    func hasNull(atUncheckedIndex index: Int) -> Bool {
        let mappedIndex = mapping.baseColumnIndex(atMappingIndex: index)
        return base.impl.hasNull(atUncheckedIndex: mappedIndex)
    }
    
    func databaseValue(atUncheckedIndex index: Int) -> DatabaseValue {
        let mappedIndex = mapping.baseColumnIndex(atMappingIndex: index)
        return base.impl.databaseValue(atUncheckedIndex: mappedIndex)
    }
    
    func fastDecode<Value: DatabaseValueConvertible & StatementColumnConvertible>(
        _ type: Value.Type,
        atUncheckedIndex index: Int) -> Value
    {
        let mappedIndex = mapping.baseColumnIndex(atMappingIndex: index)
        return Value.fastDecode(from: base, atUncheckedIndex: mappedIndex)
    }
    
    func fastDecodeIfPresent<Value: DatabaseValueConvertible & StatementColumnConvertible>(
        _ type: Value.Type,
        atUncheckedIndex index: Int) -> Value?
    {
        let mappedIndex = mapping.baseColumnIndex(atMappingIndex: index)
        return Value.fastDecodeIfPresent(from: base, atUncheckedIndex: mappedIndex)
    }
    
    func dataNoCopy(atUncheckedIndex index: Int) -> Data? {
        let mappedIndex = mapping.baseColumnIndex(atMappingIndex: index)
        return base.impl.dataNoCopy(atUncheckedIndex: mappedIndex)
    }
    
    func columnName(atUncheckedIndex index: Int) -> String {
        return mapping.columnName(atMappingIndex: index)
    }
    
    func index(ofColumn name: String) -> Int? {
        return mapping.layoutIndex(ofColumn: name)
    }
    
    func copiedRow(_ row: Row) -> Row {
        return Row(base: base.copy(), adapter: adapter)
    }
    
    func unscopedRow(_ row: Row) -> Row {
        assert(adapter.mapping.scopes.isEmpty)
        return Row(base: base, adapter: adapter.mapping)
    }
    
    func unadaptedRow(_ row: Row) -> Row {
        return base.unadapted
    }
}

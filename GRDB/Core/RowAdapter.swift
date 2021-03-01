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

/// _LayoutedColumnMapping is a type that supports the RowAdapter protocol.
///
/// :nodoc:
public struct _LayoutedColumnMapping {
    /// An array of (baseIndex, mappedName) pairs, where baseIndex is the index
    /// of a column in a base row, and mappedName the mapped name of
    /// that column.
    public let _layoutColumns: [(Int, String)]
    
    /// A cache for layoutIndex(ofColumn:)
    let lowercaseColumnIndexes: [String: Int]   // [mappedColumn: layoutColumnIndex]
    
    /// Creates a _LayoutedColumnMapping from an array of (baseIndex, mappedName)
    /// pairs. In each pair:
    ///
    /// - baseIndex is the index of a column in a base row
    /// - name is the mapped name of the column
    ///
    /// For example, the following _LayoutedColumnMapping defines two columns, "foo"
    /// and "bar", based on the base columns at indexes 1 and 2:
    ///
    ///     _LayoutedColumnMapping(layoutColumns: [(1, "foo"), (2, "bar")])
    ///
    /// Use it in your custom RowAdapter type:
    ///
    ///     struct FooBarAdapter : RowAdapter {
    ///         func layoutAdapter(layout: _RowLayout) throws -> _LayoutedRowAdapter {
    ///             return _LayoutedColumnMapping(layoutColumns: [(1, "foo"), (2, "bar")])
    ///         }
    ///     }
    ///
    ///     // [foo:"foo" bar: "bar"]
    ///     try Row.fetchOne(db, sql: "SELECT NULL, 'foo', 'bar'", adapter: FooBarAdapter())
    init<S: Sequence>(layoutColumns: S) where S.Iterator.Element == (Int, String) {
        self._layoutColumns = Array(layoutColumns)
        self.lowercaseColumnIndexes = Dictionary(
            layoutColumns
                .enumerated()
                .map { ($0.element.1.lowercased(), $0.offset) },
            uniquingKeysWith: { (left, _) in left }) // keep leftmost indexes
    }
    
    func baseColumnIndex(atMappingIndex index: Int) -> Int {
        _layoutColumns[index].0
    }
    
    func columnName(atMappingIndex index: Int) -> String {
        _layoutColumns[index].1
    }
}

/// :nodoc:
extension _LayoutedColumnMapping: _LayoutedRowAdapter {
    /// Returns self.
    public var _mapping: _LayoutedColumnMapping { self }
    
    /// Returns the empty dictionary.
    public var _scopes: [String: _LayoutedRowAdapter] { [:] }
}

/// :nodoc:
extension _LayoutedColumnMapping: _RowLayout {
    /// Returns the index of the leftmost column named `name`, in a
    /// case-insensitive way.
    public func _layoutIndex(ofColumn name: String) -> Int? {
        if let index = lowercaseColumnIndexes[name] {
            return index
        }
        return lowercaseColumnIndexes[name.lowercased()]
    }
}

/// `_LayoutedRowAdapter` is a protocol that supports the `RowAdapter` protocol.
///
/// GRBD ships with a ready-made type that adopts this protocol:
/// `_LayoutedColumnMapping`.
///
/// :nodoc:
public protocol _LayoutedRowAdapter {
    /// A LayoutedColumnMapping that defines how to map a column name to a
    /// column in a base row.
    var _mapping: _LayoutedColumnMapping { get }
    
    /// The layouted row adapters for each scope.
    var _scopes: [String: _LayoutedRowAdapter] { get }
}

/// `_RowLayout` is a protocol that supports the `RowAdapter` protocol. It
/// describes the layout of a base row.
///
/// :nodoc:
public protocol _RowLayout {
    /// An array of (baseIndex, name) pairs, where baseIndex is the index
    /// of a column in a base row, and name the name of that column.
    var _layoutColumns: [(Int, String)] { get }
    
    /// Returns the index of the leftmost column named `name`, in a
    /// case-insensitive way.
    func _layoutIndex(ofColumn name: String) -> Int?
}

extension SelectStatement: _RowLayout {
    /// :nodoc:
    public var _layoutColumns: [(Int, String)] {
        Array(columnNames.enumerated())
    }
    
    /// :nodoc:
    public func _layoutIndex(ofColumn name: String) -> Int? {
        index(ofColumn: name)
    }
}

/// Implementation details of `RowAdapter`.
///
/// :nodoc:
public protocol _RowAdapter {
    /// You never call this method directly. It is called for you whenever an
    /// adapter has to be applied.
    ///
    /// The result is a value that adopts _LayoutedRowAdapter, such as
    /// _LayoutedColumnMapping.
    ///
    /// For example:
    ///
    ///     // An adapter that turns any row to a row that contains a single
    ///     // column named "foo" whose value is the leftmost value of the
    ///     // base row.
    ///     struct FirstColumnAdapter : RowAdapter {
    ///         func _layoutedAdapter(from layout: _RowLayout) throws -> _LayoutedRowAdapter {
    ///             return _LayoutedColumnMapping(layoutColumns: [(0, "foo")])
    ///         }
    ///     }
    ///
    ///     // [foo:1]
    ///     try Row.fetchOne(db, sql: "SELECT 1, 2, 3", adapter: FirstColumnAdapter())
    func _layoutedAdapter(from layout: _RowLayout) throws -> _LayoutedRowAdapter
}

/// `RowAdapter` is a protocol that helps two incompatible row interfaces
/// working together.
///
/// GRDB ships with four concrete types that adopt the RowAdapter protocol:
///
/// - `ColumnMapping`: renames row columns
/// - `SuffixRowAdapter`: hides the first columns of a row
/// - `RangeRowAdapter`: only exposes a range of columns
/// - `ScopeAdapter`: defines row scopes
///
/// To use a row adapter, provide it to any method that fetches:
///
///     let adapter = SuffixRowAdapter(fromIndex: 2)
///     let sql = "SELECT 1 AS foo, 2 AS bar, 3 AS baz"
///
///     // [baz:3]
///     try Row.fetchOne(db, sql: sql, adapter: adapter)
public protocol RowAdapter: _RowAdapter { }

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
    func baseColumnIndex(atIndex index: Int, layout: _RowLayout) throws -> Int {
        try _layoutedAdapter(from: layout)._mapping.baseColumnIndex(atMappingIndex: index)
    }
}

/// EmptyRowAdapter is a row adapter that hides all columns.
public struct EmptyRowAdapter: RowAdapter {
    /// Creates an EmptyRowAdapter
    public init() { }
    
    /// :nodoc:
    public func _layoutedAdapter(from layout: _RowLayout) throws -> _LayoutedRowAdapter {
        _LayoutedColumnMapping(layoutColumns: [])
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
    
    /// :nodoc:
    public func _layoutedAdapter(from layout: _RowLayout) throws -> _LayoutedRowAdapter {
        let layoutColumns = try mapping
            .map { (mappedColumn, baseColumn) -> (Int, String) in
                guard let index = layout._layoutIndex(ofColumn: baseColumn) else {
                    let columnNames = layout._layoutColumns.map { $0.1 }
                    throw DatabaseError(
                        resultCode: .SQLITE_MISUSE,
                        message: """
                            Mapping references missing column \(baseColumn). \
                            Valid column names are: \(columnNames.joined(separator: ", ")).
                            """)
                }
                let baseIndex = layout._layoutColumns[index].0
                return (baseIndex, mappedColumn)
            }
            .sorted { $0.0 < $1.0 } // preserve ordering of base columns
        return _LayoutedColumnMapping(layoutColumns: layoutColumns)
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
    
    /// :nodoc:
    public func _layoutedAdapter(from layout: _RowLayout) throws -> _LayoutedRowAdapter {
        _LayoutedColumnMapping(layoutColumns: layout._layoutColumns.suffix(from: index))
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
    
    /// :nodoc:
    public func _layoutedAdapter(from layout: _RowLayout) throws -> _LayoutedRowAdapter {
        _LayoutedColumnMapping(layoutColumns: layout._layoutColumns[range])
    }
}

/// `ScopeAdapter` is a row adapter that lets you define scopes on rows.
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
    
    /// :nodoc:
    public func _layoutedAdapter(from layout: _RowLayout) throws -> _LayoutedRowAdapter {
        let layoutedAdapter = try base._layoutedAdapter(from: layout)
        var layoutedScopes = layoutedAdapter._scopes
        for (name, adapter) in scopes {
            try layoutedScopes[name] = adapter._layoutedAdapter(from: layout)
        }
        return LayoutedScopeAdapter(
            _mapping: layoutedAdapter._mapping,
            _scopes: layoutedScopes)
    }
}

/// The `_LayoutedRowAdapter` for `ScopeAdapter`
struct LayoutedScopeAdapter: _LayoutedRowAdapter {
    let _mapping: _LayoutedColumnMapping
    let _scopes: [String: _LayoutedRowAdapter]
}

struct ChainedAdapter: RowAdapter {
    let first: RowAdapter
    let second: RowAdapter
    
    func _layoutedAdapter(from layout: _RowLayout) throws -> _LayoutedRowAdapter {
        try second._layoutedAdapter(from: first._layoutedAdapter(from: layout)._mapping)
    }
}

/// `RenameColumnAdapter` is a row adapter that renames columns.
///
/// For example:
///
///     let adapter = RenameColumnAdapter { $0 + "rrr" }
///     let sql = "SELECT 'foo' AS foo, 'bar' AS bar, 'baz' AS baz"
///
///     // [foorrr:"foo", barrrr:"bar", bazrrr:"baz"]
///     try Row.fetchOne(db, sql: sql, adapter: adapter)
public struct RenameColumnAdapter: RowAdapter {
    let transform: (String) -> String
    
    /// Creates a `RenameColumnAdapter` adapter that renames columns according to the
    /// provided transform function.
    public init(_ transform: @escaping (String) -> String) {
        self.transform = transform
    }
    
    /// :nodoc:
    public func _layoutedAdapter(from layout: _RowLayout) throws -> _LayoutedRowAdapter {
        let layoutColumns = layout._layoutColumns.map { (index, column) in (index, transform(column)) }
        return _LayoutedColumnMapping(layoutColumns: layoutColumns)
    }
}

extension Row {
    /// Creates a row from a base row and a statement adapter
    convenience init(base: Row, adapter: _LayoutedRowAdapter) {
        self.init(impl: AdaptedRowImpl(base: base, adapter: adapter))
    }
    
    /// Returns self if adapter is nil
    func adapted(with adapter: RowAdapter?, layout: _RowLayout) throws -> Row {
        guard let adapter = adapter else {
            return self
        }
        return try Row(base: self, adapter: adapter._layoutedAdapter(from: layout))
    }
}

struct AdaptedRowImpl: RowImpl {
    let base: Row
    let adapter: _LayoutedRowAdapter
    let mapping: _LayoutedColumnMapping
    
    init(base: Row, adapter: _LayoutedRowAdapter) {
        self.base = base
        self.adapter = adapter
        self.mapping = adapter._mapping
    }
    
    var count: Int { mapping._layoutColumns.count }
    
    var isFetched: Bool { base.isFetched }
    
    func scopes(prefetchedRows: Row.PrefetchedRowsView) -> Row.ScopesView {
        Row.ScopesView(row: base, scopes: adapter._scopes, prefetchedRows: prefetchedRows)
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
        atUncheckedIndex index: Int)
    throws -> Value
    {
        let mappedIndex = mapping.baseColumnIndex(atMappingIndex: index)
        return try Value.fastDecode(fromRow: base, atUncheckedIndex: mappedIndex)
    }
    
    func fastDecodeIfPresent<Value: DatabaseValueConvertible & StatementColumnConvertible>(
        _ type: Value.Type,
        atUncheckedIndex index: Int)
    throws -> Value?
    {
        let mappedIndex = mapping.baseColumnIndex(atMappingIndex: index)
        return try Value.fastDecodeIfPresent(fromRow: base, atUncheckedIndex: mappedIndex)
    }
    
    func fastDecodeDataNoCopy(atUncheckedIndex index: Int) throws -> Data {
        let mappedIndex = mapping.baseColumnIndex(atMappingIndex: index)
        return try base.impl.fastDecodeDataNoCopy(atUncheckedIndex: mappedIndex)
    }
    
    func fastDecodeDataNoCopyIfPresent(atUncheckedIndex index: Int) throws -> Data? {
        let mappedIndex = mapping.baseColumnIndex(atMappingIndex: index)
        return try base.impl.fastDecodeDataNoCopyIfPresent(atUncheckedIndex: mappedIndex)
    }
    
    func columnName(atUncheckedIndex index: Int) -> String {
        mapping.columnName(atMappingIndex: index)
    }
    
    func index(forColumn name: String) -> Int? {
        mapping._layoutIndex(ofColumn: name)
    }
    
    func copiedRow(_ row: Row) -> Row {
        Row(base: base.copy(), adapter: adapter)
    }
    
    func unscopedRow(_ row: Row) -> Row {
        assert(adapter._mapping._scopes.isEmpty)
        return Row(base: base, adapter: adapter._mapping)
    }
    
    func unadaptedRow(_ row: Row) -> Row {
        base.unadapted
    }
}

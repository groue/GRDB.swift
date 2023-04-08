import Foundation

/// Returns an array of row adapters that split a row according to the
/// provided numbers of columns.
///
/// This method is useful for splitting a row into chunks.
///
/// For example, let's consider the following SQL query:
///
/// ```swift
/// let sql = """
///     SELECT player.*, team.*
///     FROM player
///     LEFT JOIN team ON team.id = player.teamId
///     WHERE player.id = ?
///     """
/// ```
///
/// The resulting rows contains columns from both player and team tables:
///
/// ```swift
/// // [id: 1, name: "Arthur", teamId: 42, id: 42, name: "Reds"]
/// // <---------------------------------><-------------------->
/// //            player columns               team columns
/// let row = try Row.fetchOne(db, sql: sql, arguments: [1])
/// ```
///
/// Because some columns have the same name (`id` and `name`), it is
/// difficult to access the team columns.
///
/// `splittingRowAdapters` and ``ScopeAdapter`` make it possible to
/// access player and team columns independently, with row ``Row/scopes``:
///
/// ```swift
/// let adapters = try splittingRowAdapters([
///     db.columns(in: "player").count,
///     db.columns(in: "team").count,
/// ])
/// let adapter = ScopeAdapter([
///     "player": adapters[0],
///     "team": adapters[1],
/// ])
/// if let row = try Row.fetchOne(db, sql: sql, arguments: [1], adapter: adapter) {
///     // A Row that only contains player columns
///     // [id: 1, name: "Arthur", teamId: 42]
///     row.scopes["player"]
///
///     // A Row that only contains team columns
///     // [id: 42, name: "Reds"]
///     row.scopes["team"]
/// }
/// ```
///
/// Decoding ``FetchableRecord`` types is easy:
///
/// ```swift
/// if let row = try Row.fetchOne(db, sql: sql, arguments: [1], adapter: adapter) {
///     // Player(id: 1, name: "Arthur", teamId: 42)
///     let player: Player = row["player"]
///
///     // Team(id: 42, name: "Reds")
///     // nil if the LEFT JOIN has fetched NULL team columns
///     if let team: Team? = row["team"]
/// }
/// ```
///
/// You can package this technique in a dedicated type, as in the next
/// example. It enhances the previous sample codes with:
///
/// - Support for record types that customize their fetched columns
///   with ``TableRecord/databaseSelection-7iphs``.
/// - ``SQLRequest`` and its support for [SQL Interpolation](https://github.com/groue/GRDB.swift/blob/master/Documentation/SQLInterpolation.md).
/// - ``FetchRequest/adapted(_:)`` for building a request that embeds the
///   row adapters.
///
/// ```swift
/// struct Player: TableRecord, FetchableRecord { ... }
/// struct Team: TableRecord, FetchableRecord { ... }
///
/// struct PlayerInfo {
///     var player: Player
///     var team: Team?
/// }
///
/// extension PlayerInfo: FetchableRecord {
///     init(row: Row) {
///         player = row["player"]
///         team = row["team"]
///     }
/// }
///
/// extension PlayerInfo {
///     /// The request for the player info, given a player id
///     static func filter(playerId: Int64) -> some FetchRequest<PlayerInfo> {
///         // Build SQL request with SQL interpolation
///         let request: SQLRequest<PlayerInfo> = """
///             SELECT
///                 \(columnsOf: Player.self), -- Instead of player.*
///                 \(columnsOf: Team.self),   -- Instead of team.*
///             FROM player
///             LEFT JOIN team ON team.id = player.teamId
///             WHERE player.id = \(playerId)
///             """
///
///         // Returns an adapted request that defines the player and team
///         // scopes in the fetched row
///         return request.adapted { db in
///             let adapters = try splittingRowAdapters(columnCounts: [
///                 Player.numberOfSelectedColumns(db),
///                 Team.numberOfSelectedColumns(db),
///             ])
///             return ScopeAdapter([
///                 "player": adapters[0],
///                 "team": adapters[1],
///             ])
///         }
///     }
/// }
///
/// // Usage
/// try dbQueue.read { db in
///     if let playerInfo = try PlayerInfo.filter(playerId: 1).fetchOne(db) {
///         print(playerInfo.player) // Player(id: 1, name: "Arthur", teamId: 42)
///         print(playerInfo.team)   // Team(id: 42, name: "Reds")
///     }
/// }
/// ```
///
/// - parameter columnCounts: An array of row chunk lengths.
/// - returns: An array of row adapters that split a row into as many chunks
///   as the number of elements in `columnCounts`, plus one (the row adapter
///   for all columns that remain on the right of the last chunk).
public func splittingRowAdapters(columnCounts: [Int]) -> [any RowAdapter] {
    if columnCounts.isEmpty {
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
    ///         func layoutAdapter(layout: _RowLayout) throws -> any _LayoutedRowAdapter {
    ///             return _LayoutedColumnMapping(layoutColumns: [(1, "foo"), (2, "bar")])
    ///         }
    ///     }
    ///
    ///     // [foo:"foo" bar: "bar"]
    ///     try Row.fetchOne(db, sql: "SELECT NULL, 'foo', 'bar'", adapter: FooBarAdapter())
    init<S>(layoutColumns: S)
    where S: Sequence, S.Element == (Int, String)
    {
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

extension _LayoutedColumnMapping: _LayoutedRowAdapter {
    /// Returns self.
    public var _mapping: _LayoutedColumnMapping { self }
    
    /// Returns the empty dictionary.
    public var _scopes: [String: any _LayoutedRowAdapter] { [:] }
}

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
public protocol _LayoutedRowAdapter {
    /// A LayoutedColumnMapping that defines how to map a column name to a
    /// column in a base row.
    var _mapping: _LayoutedColumnMapping { get }
    
    /// The layouted row adapters for each scope.
    var _scopes: [String: any _LayoutedRowAdapter] { get }
}

/// `_RowLayout` is a protocol that supports the `RowAdapter` protocol. It
/// describes the layout of a base row.
public protocol _RowLayout {
    /// An array of (baseIndex, name) pairs, where baseIndex is the index
    /// of a column in a base row, and name the name of that column.
    var _layoutColumns: [(Int, String)] { get }
    
    /// Returns the index of the leftmost column named `name`, in a
    /// case-insensitive way.
    func _layoutIndex(ofColumn name: String) -> Int?
}

extension Statement: _RowLayout {
    public var _layoutColumns: [(Int, String)] {
        Array(columnNames.enumerated())
    }
    
    public func _layoutIndex(ofColumn name: String) -> Int? {
        index(ofColumn: name)
    }
}

/// A type that helps two incompatible row interfaces working together.
///
/// Row adapters present database rows in the way expected by the
/// row consumers.
///
/// For example, when a row consumer expects a column named "consumed", but
/// the raw row has a column named "produced", the ``ColumnMapping`` row
/// adapter comes in handy:
///
/// ```swift
/// // Feeds the "consumed" column from "produced":
/// let adapter = ColumnMapping(["consumed": "produced"])
/// let sql = "SELECT 'Hello' AS produced"
/// let row = try Row.fetchOne(db, sql: sql, adapter: adapter)!
///
/// // [consumed:"Hello"]
/// print(row)
///
/// // "Hello"
/// print(row["consumed"])
/// ```
///
/// The raw fetched columns are not lost (see ``Row/unadapted``):
///
/// ```swift
/// // ▿ [consumed:"Hello"]
/// //   unadapted: [produced:"Hello"]
/// print(row.debugDescription)
///
/// // [produced:"Hello"]
/// print(row.unadapted)
/// ```
///
/// There are several situations where row adapters are useful. Among them:
///
/// - Adapters help disambiguate columns with identical names, which may
///   happen when you select columns from several tables.
///   See ``splittingRowAdapters(columnCounts:)`` for some sample code.
///
/// - Adapters help when SQLite outputs unexpected column names, which may
///   happen with some subqueries. See ``RenameColumnAdapter`` for
///   an example.
///
/// ## Topics
///
/// ### Splitting a Row into Chunks
///
/// - ``splittingRowAdapters(columnCounts:)``
///
/// ### Adding Scopes to an Adapter
///
/// - ``addingScopes(_:)``
///
/// ### Built-in Adapters
///
/// - ``ColumnMapping``
/// - ``EmptyRowAdapter``
/// - ``RangeRowAdapter``
/// - ``RenameColumnAdapter``
/// - ``ScopeAdapter``
/// - ``SuffixRowAdapter``
public protocol RowAdapter {
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
    ///         func _layoutedAdapter(from layout: some _RowLayout) throws -> any _LayoutedRowAdapter {
    ///             return _LayoutedColumnMapping(layoutColumns: [(0, "foo")])
    ///         }
    ///     }
    ///
    ///     // [foo:1]
    ///     try Row.fetchOne(db, sql: "SELECT 1, 2, 3", adapter: FirstColumnAdapter())
    func _layoutedAdapter(from layout: some _RowLayout) throws -> any _LayoutedRowAdapter
}

extension RowAdapter {
    /// Returns an adapter based on self, with added scopes.
    ///
    /// If self already defines scopes, the added scopes replace
    /// eventual existing scopes with the same name.
    ///
    /// - parameter scopes: A dictionary that maps scope names to
    ///   row adapters.
    public func addingScopes(_ scopes: [String: any RowAdapter]) -> any RowAdapter {
        if scopes.isEmpty {
            return self
        } else {
            return ScopeAdapter(base: self, scopes: scopes)
        }
    }
}

extension RowAdapter {
    func baseColumnIndex(atIndex index: Int, layout: some _RowLayout) throws -> Int {
        try _layoutedAdapter(from: layout)._mapping.baseColumnIndex(atMappingIndex: index)
    }
}

/// `EmptyRowAdapter` is a row adapter that hides all columns.
///
/// For example:
///
/// ```swift
/// let adapter = EmptyRowAdapter()
/// let sql = "SELECT 0 AS a, 1 AS b, 2 AS c"
///
/// let row = try Row.fetchOne(db, sql: sql, adapter: adapter)!
/// row.isEmpty // true
/// ```
///
/// This limit adapter may turn out useful in some narrow use cases. You'll
/// be happy to find it when you need it.
public struct EmptyRowAdapter: RowAdapter {
    /// Creates an `EmptyRowAdapter`.
    public init() { }
    
    public func _layoutedAdapter(from layout: some _RowLayout) throws -> any _LayoutedRowAdapter {
        _LayoutedColumnMapping(layoutColumns: [])
    }
}

/// `ColumnMapping` is a row adapter that maps column names.
///
/// Build a `ColumnMapping` with a dictionary whose keys
/// are adapted column names, and values the column names in the base row:
///
/// ```swift
/// // Feeds "newA" from "a", and "newB" from "b":
/// let adapter = ColumnMapping(["newA": "a", "newB": "b"])
/// let sql = "SELECT 0 AS a, 1 AS b, 2 AS c"
///
/// // [newA:0, newB:1]
/// let row = try Row.fetchOne(db, sql: sql, adapter: adapter)!
/// ```
///
/// Note that columns that are not present in the dictionary are not present
/// in the resulting adapted row.
public struct ColumnMapping: RowAdapter {
    /// A dictionary from mapped column names to column names in a base row.
    let mapping: [String: String]
    
    /// Creates a `ColumnMapping` with a dictionary from mapped column names
    /// to column names in a base row.
    public init(_ mapping: [String: String]) {
        self.mapping = mapping
    }
    
    public func _layoutedAdapter(from layout: some _RowLayout) throws -> any _LayoutedRowAdapter {
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

/// `SuffixRowAdapter` hides the leftmost columns in a row.
///
/// For example:
///
/// ```swift
/// let adapter = SuffixRowAdapter(fromIndex: 2)
/// let sql = "SELECT 0 AS a, 1 AS b, 2 AS c, 3 AS d"
///
/// // [c:2, d: 3]
/// try Row.fetchOne(db, sql: sql, adapter: adapter)!
/// ```
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
    
    public func _layoutedAdapter(from layout: some _RowLayout) throws -> any _LayoutedRowAdapter {
        _LayoutedColumnMapping(layoutColumns: layout._layoutColumns.suffix(from: index))
    }
}

/// `RangeRowAdapter` is a row adapter that only exposes a range of columns.
///
/// For example:
///
/// ```swift
/// let adapter = RangeRowAdapter(1..<3)
/// let sql = "SELECT 0 AS a, 1 AS b, 2 AS c, 3 AS d"
///
/// // [b:1 c:2]
/// try Row.fetchOne(db, sql: sql, adapter: adapter)
/// ```
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
    
    public func _layoutedAdapter(from layout: some _RowLayout) throws -> any _LayoutedRowAdapter {
        _LayoutedColumnMapping(layoutColumns: layout._layoutColumns[range])
    }
}

/// `ScopeAdapter` is a row adapter that defines row scopes.
///
/// `ScopeAdapter` does not change the columns and values of the fetched
/// row. Instead, it defines *scopes* based on other adapter, which you
/// access through the ``Row/scopes`` property of the fetched rows.
///
/// For example:
///
/// ```swift
/// let adapter = ScopeAdapter([
///     "left": RangeRowAdapter(0..<2),
///     "right": RangeRowAdapter(2..<4)])
/// let sql = "SELECT 0 AS a, 1 AS b, 2 AS c, 3 AS d"
///
/// let row = try Row.fetchOne(db, sql: sql, adapter: adapter)!
///
/// row                   // [a:0 b:1 c:2 d:3]
/// row.scopes["left"]    // [a:0 b:1]
/// row.scopes["right"]   // [c:2 d:3]
/// row.scopes["missing"] // nil
/// ```
///
/// Scopes can be nested:
///
/// ```swift
/// let adapter = ScopeAdapter([
///     "left": ScopeAdapter([
///         "left": RangeRowAdapter(0..<1),
///         "right": RangeRowAdapter(1..<2)]),
///     "right": ScopeAdapter([
///         "left": RangeRowAdapter(2..<3),
///         "right": RangeRowAdapter(3..<4)])
///     ])
/// let sql = "SELECT 0 AS a, 1 AS b, 2 AS c, 3 AS d"
/// let row = try Row.fetchOne(db, sql: sql, adapter: adapter)!
///
/// let leftRow = row.scopes["left"]!
/// leftRow.scopes["left"]   // [a:0]
/// leftRow.scopes["right"]  // [b:1]
///
/// let rightRow = row.scopes["right"]!
/// rightRow.scopes["left"]  // [c:2]
/// rightRow.scopes["right"] // [d:3]
/// ```
///
/// Any adapter can be extended with scopes, with
/// ``RowAdapter/addingScopes(_:)``:
///
/// ```swift
/// let baseAdapter = RangeRowAdapter(0..<2)
/// let adapter = baseAdapter.addingScopes([
///     "remainder": SuffixRowAdapter(fromIndex: 2)
/// ])
/// let sql = "SELECT 0 AS a, 1 AS b, 2 AS c, 3 AS d"
/// let row = try Row.fetchOne(db, sql: sql, adapter: adapter)!
///
/// row                     // [a:0 b:1]
/// row.scopes["remainder"] // [c:2 d:3]
/// ```
public struct ScopeAdapter: RowAdapter {
    
    /// The base adapter
    let base: any RowAdapter
    
    /// The scope adapters
    let scopes: [String: any RowAdapter]
    
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
    public init(_ scopes: [String: any RowAdapter]) {
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
    public init(base: some RowAdapter, scopes: [String: any RowAdapter]) {
        self.base = base
        self.scopes = scopes
    }
    
    public func _layoutedAdapter(from layout: some _RowLayout) throws -> any _LayoutedRowAdapter {
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
    let _scopes: [String: any _LayoutedRowAdapter]
}

struct ChainedAdapter: RowAdapter {
    let first: any RowAdapter
    let second: any RowAdapter
    
    func _layoutedAdapter(from layout: some _RowLayout) throws -> any _LayoutedRowAdapter {
        try second._layoutedAdapter(from: first._layoutedAdapter(from: layout)._mapping)
    }
}

/// `RenameColumnAdapter` is a row adapter that renames columns.
///
/// For example:
///
/// ```swift
/// let adapter = RenameColumnAdapter { column in column + "rrr" }
/// let sql = "SELECT 0 AS a, 1 AS b, 2 AS c"
///
/// // [arrr:0, brrr:1, crrr:2]
/// let row = try Row.fetchOne(db, sql: sql, adapter: adapter)!
/// ```
///
/// This adapter is useful when subqueries contain duplicated column names:
///
/// ```swift
/// let sql = "SELECT * FROM (SELECT 1 AS id, 2 AS id)"
///
/// // Prints ["id", "id:1"]
/// // Note the "id:1" column, generated by SQLite.
/// let row = try Row.fetchOne(db, sql: sql)!
/// print(Array(row.columnNames))
///
/// // Drop the `:...` suffix, and prints ["id", "id"]
/// let adapter = RenameColumnAdapter { String($0.prefix(while: { $0 != ":" })) }
/// let adaptedRow = try Row.fetchOne(db, sql: sql, adapter: adapter)!
/// print(Array(adaptedRow.columnNames))
/// ```
public struct RenameColumnAdapter: RowAdapter {
    let transform: (String) -> String
    
    /// Creates a `RenameColumnAdapter` adapter that renames columns according to the
    /// provided transform function.
    public init(_ transform: @escaping (String) -> String) {
        self.transform = transform
    }
    
    public func _layoutedAdapter(from layout: some _RowLayout) throws -> any _LayoutedRowAdapter {
        let layoutColumns = layout._layoutColumns.map { (index, column) in (index, transform(column)) }
        return _LayoutedColumnMapping(layoutColumns: layoutColumns)
    }
}

extension Row {
    /// Creates a row from a base row and a statement adapter
    convenience init(base: Row, adapter: some _LayoutedRowAdapter) {
        self.init(impl: AdaptedRowImpl(base: base, adapter: adapter))
    }
    
    /// Returns self if adapter is nil
    func adapted(with adapter: (any RowAdapter)?, layout: some _RowLayout) throws -> Row {
        guard let adapter else {
            return self
        }
        return try Row(base: self, adapter: adapter._layoutedAdapter(from: layout))
    }
}

struct AdaptedRowImpl: RowImpl {
    let base: Row
    let adapter: any _LayoutedRowAdapter
    let mapping: _LayoutedColumnMapping
    
    init(base: Row, adapter: some _LayoutedRowAdapter) {
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
    
    func withUnsafeData<T>(atUncheckedIndex index: Int, _ body: (Data?) throws -> T) throws -> T {
        let mappedIndex = mapping.baseColumnIndex(atMappingIndex: index)
        return try base.impl.withUnsafeData(atUncheckedIndex: mappedIndex, body)
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

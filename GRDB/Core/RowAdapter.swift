#if !SQLITE_HAS_CODEC
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

// The types declared in this file are:
//
// - public struct RowAdapter
//
//     The public RowAdapter type
//
// - private protocol RowAdapterImpl
//
//     Protocol for inner implementation of RowAdapter
//
// - private struct DictionaryRowAdapterImpl
//
//     Implementation for RowAdapter that maps column names with a dictionary
//
// - private struct NestedRowAdapterImpl
//
//     Implementation for RowAdapter that holds a "main" adapter and a
//     dictionary of subrow adapters.
//
// - struct ColumnsAdapter
//
//     A RowAdapter itself can not do anything, because it doesn't know the
//     row layout. ColumnsAdapter is the product of a RowAdapter and the row
//     layout of a statement: it maps adapted columns to columns of the
//     "base row".
//
// - struct AdapterRowImpl
//
//     A RowImpl for adapter rows.
//
// - struct AdapterRowImpl.Binding
//
//     A struct that holds a "main" column adapter, and a dictionary
//     of subrows.

/// Row adapters helps two incompatible row interfaces to work together.
///
/// For instance, a row consumer expects a column named "foo", but the produced
/// column has a column named "bar".
///
/// A row adapter performs that column mapping:
///
///     // An adapter that maps column 'bar' to column 'foo':
///     let adapter = RowAdapter(["foo": "bar"])
///
///     // Fetch a column named 'bar':
///     let row = Row.fetchOne(db, "SELECT 'Hello' AS bar", adapter: adapter)
///
///     // The adapter in action:
///     row.value(named: "foo") // "Hello"
///
/// A row adapter can also define "sub rows", that help several consumers feed
/// on a single row:
///
///     let adapter = RowAdapter(
///         ["val": "val1"],
///         subrows: ["other": ["val": "val2"]])
///     let row = Row.fetchOne(db, "SELECT 'foo' AS val1, 'bar' AS val2", adapter: adapter)
///     let subrow = row.subrow(named: "other")!
///     row.value(named: "val")     // "foo"
///     subrow.value(named: "val")  // "bar"
///
public struct RowAdapter {
    private let impl: RowAdapterImpl
    
    public init(_ mainRowAdapter: RowAdapter, subrows subRowAdapters: [String: RowAdapter]) {
        impl = NestedRowAdapterImpl(mainRowAdapter: mainRowAdapter, subRowAdapters: subRowAdapters)
    }
    
    public init(_ dictionary: [String: String]) {
        self.init(impl: DictionaryRowAdapterImpl(dictionary: dictionary))
    }
    
    private init(impl: RowAdapterImpl) {
        self.impl = impl
    }
    
    func binding(with statement: SelectStatement) throws -> AdapterRowImpl.Binding {
        return try impl.binding(with: statement)
    }
    
    private func columnBaseIndexes(statement statement: SelectStatement) throws -> [(String, Int)] {
        return try impl.columnBaseIndexes(statement: statement)
    }
}

extension RowAdapter : DictionaryLiteralConvertible {
    public init(dictionaryLiteral elements: (String, String)...) {
        self.init(impl: DictionaryRowAdapterImpl(dictionary: Dictionary(keyValueSequence: elements)))
    }
}

private protocol RowAdapterImpl {
    func binding(with statement: SelectStatement) throws -> AdapterRowImpl.Binding
    
    // Return array [(mappedColumn, baseRowIndex), ...] ordered like the statement columns.
    func columnBaseIndexes(statement statement: SelectStatement) throws -> [(String, Int)]
}

private struct DictionaryRowAdapterImpl: RowAdapterImpl {
    let dictionary: [String: String]
    
    func binding(with statement: SelectStatement) throws -> AdapterRowImpl.Binding {
        let columnsAdapter = try ColumnsAdapter(columnBaseIndexes: columnBaseIndexes(statement: statement))
        return AdapterRowImpl.Binding(
            columnsAdapter: columnsAdapter,
            subBindings: [:])
    }

    func columnBaseIndexes(statement statement: SelectStatement) throws -> [(String, Int)] {
        return try dictionary
            .map { (mappedColumn, baseColumn) -> (String, Int) in
                guard let index = statement.indexOfColumn(named: baseColumn) else {
                    throw DatabaseError(code: SQLITE_MISUSE, message: "Mapping references missing column \(baseColumn). Valid column names are: \(statement.columnNames.joinWithSeparator(", ")).")
                }
                return (mappedColumn, index)
            }
            .sort { return $0.1 < $1.1 }
    }
}

private struct NestedRowAdapterImpl: RowAdapterImpl {
    let mainRowAdapter: RowAdapter
    let subRowAdapters: [String: RowAdapter]
    
    func binding(with statement: SelectStatement) throws -> AdapterRowImpl.Binding {
        let columnsAdapter = try ColumnsAdapter(columnBaseIndexes: columnBaseIndexes(statement: statement))
        let subBindings = try subRowAdapters.map { (identifier: String, adapter: RowAdapter) -> (String, AdapterRowImpl.Binding) in
            let subrowAdapter = try AdapterRowImpl.Binding(
                columnsAdapter: ColumnsAdapter(columnBaseIndexes: adapter.columnBaseIndexes(statement: statement)),
                subBindings: [:])
            return (identifier, subrowAdapter)
        }
        return AdapterRowImpl.Binding(
            columnsAdapter: columnsAdapter,
            subBindings: Dictionary(keyValueSequence: subBindings))
    }
    
    func columnBaseIndexes(statement statement: SelectStatement) throws -> [(String, Int)] {
        return try mainRowAdapter.columnBaseIndexes(statement: statement)
    }
}

struct ColumnsAdapter {
    let columnBaseIndexes: [(String, Int)]      // [(mappedColumn, baseRowIndex), ...]
    let lowercaseColumnIndexes: [String: Int]   // [mappedColumn: adaptedRowIndex]

    init(columnBaseIndexes: [(String, Int)]) {
        self.columnBaseIndexes = columnBaseIndexes
        self.lowercaseColumnIndexes = Dictionary(keyValueSequence: columnBaseIndexes.enumerate().map { ($1.0.lowercaseString, $0) })
    }

    var count: Int {
        return columnBaseIndexes.count
    }

    func baseColumIndex(adaptedIndex index: Int) -> Int {
        return columnBaseIndexes[index].1
    }

    func columnName(adaptedIndex index: Int) -> String {
        return columnBaseIndexes[index].0
    }

    func indexOfColumn(named name: String) -> Int? {
        if let index = lowercaseColumnIndexes[name] {
            return index
        }
        return lowercaseColumnIndexes[name.lowercaseString]
    }
}

extension Row {
    /// Builds a row from a base row and an adapter binding
    convenience init(baseRow: Row, adapterBinding binding: AdapterRowImpl.Binding) {
        self.init(impl: AdapterRowImpl(baseRow: baseRow, binding: binding))
    }
    
    /// Returns self if adapter is nil
    func adaptedRow(adapter adapter: RowAdapter?, statement: SelectStatement) throws -> Row {
        guard let adapter = adapter else {
            return self
        }
        return try Row(baseRow: self, adapterBinding: adapter.binding(with: statement))
    }
}

// See Row.init(baseRow:binding:)
struct AdapterRowImpl : RowImpl {
    
    struct Binding {
        let columnsAdapter: ColumnsAdapter
        let subBindings: [String: Binding]
    }
    
    let baseRow: Row
    let binding: Binding
    var columnsAdapter: ColumnsAdapter { return binding.columnsAdapter }
    
    init(baseRow: Row, binding: Binding) {
        self.baseRow = baseRow
        self.binding = binding
    }
    
    var count: Int {
        return columnsAdapter.count
    }
    
    func databaseValue(atIndex index: Int) -> DatabaseValue {
        return baseRow.databaseValue(atIndex: columnsAdapter.baseColumIndex(adaptedIndex: index))
    }
    
    func dataNoCopy(atIndex index:Int) -> NSData? {
        return baseRow.dataNoCopy(atIndex: columnsAdapter.baseColumIndex(adaptedIndex: index))
    }
    
    func columnName(atIndex index: Int) -> String {
        return columnsAdapter.columnName(adaptedIndex: index)
    }
    
    func indexOfColumn(named name: String) -> Int? {
        return columnsAdapter.indexOfColumn(named: name)
    }
    
    func subrow(named name: String) -> Row? {
        guard let binding = binding.subBindings[name] else {
            return nil
        }
        return Row(baseRow: baseRow, adapterBinding: binding)
    }
    
    var subrowNames: Set<String> {
        return Set(binding.subBindings.keys)
    }
    
    func copy(row: Row) -> Row {
        return Row(baseRow: baseRow.copy(), adapterBinding: binding)
    }
}

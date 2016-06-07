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

public struct ColumnsAdapter {
    let columnBaseIndexes: [(Int, String)]      // [(baseRowIndex, mappedColumn), ...]
    let lowercaseColumnIndexes: [String: Int]   // [mappedColumn: adaptedRowIndex]

    public init(columnBaseIndexes: [(Int, String)]) {
        self.columnBaseIndexes = columnBaseIndexes
        self.lowercaseColumnIndexes = Dictionary(keyValueSequence: columnBaseIndexes.enumerate().map { ($1.1.lowercaseString, $0) }.reverse())
    }

    var count: Int {
        return columnBaseIndexes.count
    }

    func baseColumIndex(adaptedIndex index: Int) -> Int {
        return columnBaseIndexes[index].0
    }

    func columnName(adaptedIndex index: Int) -> String {
        return columnBaseIndexes[index].1
    }

    func adaptedIndexOfColumn(named name: String) -> Int? {
        if let index = lowercaseColumnIndexes[name] {
            return index
        }
        return lowercaseColumnIndexes[name.lowercaseString]
    }
}

extension ColumnsAdapter : RowAdapterBinding {
    public var columnsAdapter: ColumnsAdapter {
        return self
    }
    public var variants: [String: RowAdapterBinding] {
        return [:]
    }
}

struct VariantAdapterBinding : RowAdapterBinding {
    let columnsAdapter: ColumnsAdapter
    let variants: [String: RowAdapterBinding]
}

public protocol RowAdapterBinding {
    var columnsAdapter: ColumnsAdapter { get }
    var variants: [String: RowAdapterBinding] { get }
}

public protocol RowAdapter {
    func binding(with statement: SelectStatement) throws -> RowAdapterBinding
}

public struct ColumnMapping : RowAdapter {
    public let mapping: [String: String]
    
    public init(_ mapping: [String: String]) {
        self.mapping = mapping
    }
    
    public func binding(with statement: SelectStatement) throws -> RowAdapterBinding {
        let columnBaseIndexes = try mapping
            .map { (mappedColumn, baseColumn) -> (Int, String) in
                guard let index = statement.indexOfColumn(named: baseColumn) else {
                    throw DatabaseError(code: SQLITE_MISUSE, message: "Mapping references missing column \(baseColumn). Valid column names are: \(statement.columnNames.joinWithSeparator(", ")).")
                }
                return (index, mappedColumn)
            }
            .sort { return $0.0 < $1.0 }
        return ColumnsAdapter(columnBaseIndexes: columnBaseIndexes)
    }
}

public struct SuffixRowAdapter : RowAdapter {
    public let index: Int
    
    public init(index: Int) {
        self.index = index
    }

    public func binding(with statement: SelectStatement) throws -> RowAdapterBinding {
        return ColumnsAdapter(columnBaseIndexes: statement.columnNames.suffixFrom(index).enumerate().map { ($0 + index, $1) })
    }
}

public struct VariantAdapter : RowAdapter {
    public let mainAdapter: RowAdapter
    public let variants: [String: RowAdapter]
    
    public init(_ mainAdapter: RowAdapter? = nil, variants: [String: RowAdapter]) {
        self.mainAdapter = mainAdapter ?? IdentityRowAdapter()
        self.variants = variants
    }

    public func binding(with statement: SelectStatement) throws -> RowAdapterBinding {
        let mainBinding = try mainAdapter.binding(with: statement)
        var variantBindings = mainBinding.variants
        for (name, adapter) in variants {
            try variantBindings[name] = adapter.binding(with: statement)
        }
        return VariantAdapterBinding(
            columnsAdapter: mainBinding.columnsAdapter,
            variants: variantBindings)
    }
}

struct IdentityRowAdapter : RowAdapter {
    func binding(with statement: SelectStatement) throws -> RowAdapterBinding {
        return ColumnsAdapter(columnBaseIndexes: Array(statement.columnNames.enumerate()))
    }
}

extension Row {
    /// Builds a row from a base row and an adapter binding
    convenience init(baseRow: Row, adapterBinding binding: RowAdapterBinding) {
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

struct AdapterRowImpl : RowImpl {

    let baseRow: Row
    let binding: RowAdapterBinding
    var columnsAdapter: ColumnsAdapter { return binding.columnsAdapter }

    init(baseRow: Row, binding: RowAdapterBinding) {
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
        return columnsAdapter.adaptedIndexOfColumn(named: name)
    }

    func variant(named name: String) -> Row? {
        guard let binding = binding.variants[name] else {
            return nil
        }
        return Row(baseRow: baseRow, adapterBinding: binding)
    }
    
    var variantNames: Set<String> {
        return Set(binding.variants.keys)
    }
    
    func copy(row: Row) -> Row {
        return Row(baseRow: baseRow.copy(), adapterBinding: binding)
    }
}

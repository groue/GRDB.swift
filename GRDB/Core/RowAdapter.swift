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

public struct StatementMapping {
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

extension StatementMapping : StatementAdapter {
    public var statementMapping: StatementMapping {
        return self
    }
    public var variants: [String: StatementAdapter] {
        return [:]
    }
}

struct VariantStatementAdapter : StatementAdapter {
    let mainAdapter: StatementAdapter
    let variants: [String: StatementAdapter]
    
    var statementMapping: StatementMapping {
        return mainAdapter.statementMapping
    }
}

public protocol StatementAdapter {
    var statementMapping: StatementMapping { get }
    var variants: [String: StatementAdapter] { get }
}

public protocol RowAdapter {
    func statementAdapter(with statement: SelectStatement) throws -> StatementAdapter
}

public struct ColumnMapping : RowAdapter {
    public let mapping: [String: String]
    
    public init(_ mapping: [String: String]) {
        self.mapping = mapping
    }
    
    public func statementAdapter(with statement: SelectStatement) throws -> StatementAdapter {
        let columnBaseIndexes = try mapping
            .map { (mappedColumn, baseColumn) -> (Int, String) in
                guard let index = statement.indexOfColumn(named: baseColumn) else {
                    throw DatabaseError(code: SQLITE_MISUSE, message: "Mapping references missing column \(baseColumn). Valid column names are: \(statement.columnNames.joinWithSeparator(", ")).")
                }
                return (index, mappedColumn)
            }
            .sort { return $0.0 < $1.0 }
        return StatementMapping(columnBaseIndexes: columnBaseIndexes)
    }
}

public struct SuffixRowAdapter : RowAdapter {
    public let index: Int
    
    public init(index: Int) {
        self.index = index
    }

    public func statementAdapter(with statement: SelectStatement) throws -> StatementAdapter {
        return StatementMapping(columnBaseIndexes: statement.columnNames.suffixFrom(index).enumerate().map { ($0 + index, $1) })
    }
}

public struct VariantAdapter : RowAdapter {
    public let mainAdapter: RowAdapter
    public let variants: [String: RowAdapter]
    
    public init(_ mainAdapter: RowAdapter? = nil, variants: [String: RowAdapter]) {
        self.mainAdapter = mainAdapter ?? IdentityRowAdapter()
        self.variants = variants
    }

    public func statementAdapter(with statement: SelectStatement) throws -> StatementAdapter {
        let mainStatementAdapter = try mainAdapter.statementAdapter(with: statement)
        var variantStatementAdapters = mainStatementAdapter.variants
        for (name, adapter) in variants {
            try variantStatementAdapters[name] = adapter.statementAdapter(with: statement)
        }
        return VariantStatementAdapter(
            mainAdapter: mainStatementAdapter,
            variants: variantStatementAdapters)
    }
}

struct IdentityRowAdapter : RowAdapter {
    func statementAdapter(with statement: SelectStatement) throws -> StatementAdapter {
        return StatementMapping(columnBaseIndexes: Array(statement.columnNames.enumerate()))
    }
}

extension Row {
    /// Builds a row from a base row and a statement adapter
    convenience init(baseRow: Row, statementAdapter: StatementAdapter) {
        self.init(impl: AdapterRowImpl(baseRow: baseRow, statementAdapter: statementAdapter))
    }

    /// Returns self if adapter is nil
    func adaptedRow(adapter adapter: RowAdapter?, statement: SelectStatement) throws -> Row {
        guard let adapter = adapter else {
            return self
        }
        return try Row(baseRow: self, statementAdapter: adapter.statementAdapter(with: statement))
    }
}

struct AdapterRowImpl : RowImpl {

    let baseRow: Row
    let statementAdapter: StatementAdapter
    let statementMapping: StatementMapping

    init(baseRow: Row, statementAdapter: StatementAdapter) {
        self.baseRow = baseRow
        self.statementAdapter = statementAdapter
        self.statementMapping = statementAdapter.statementMapping
    }

    var count: Int {
        return statementMapping.count
    }

    func databaseValue(atIndex index: Int) -> DatabaseValue {
        return baseRow.databaseValue(atIndex: statementMapping.baseColumIndex(adaptedIndex: index))
    }

    func dataNoCopy(atIndex index:Int) -> NSData? {
        return baseRow.dataNoCopy(atIndex: statementMapping.baseColumIndex(adaptedIndex: index))
    }

    func columnName(atIndex index: Int) -> String {
        return statementMapping.columnName(adaptedIndex: index)
    }

    func indexOfColumn(named name: String) -> Int? {
        return statementMapping.adaptedIndexOfColumn(named: name)
    }

    func variant(named name: String) -> Row? {
        guard let statementAdapter = statementAdapter.variants[name] else {
            return nil
        }
        return Row(baseRow: baseRow, statementAdapter: statementAdapter)
    }
    
    var variantNames: Set<String> {
        return Set(statementAdapter.variants.keys)
    }
    
    func copy(row: Row) -> Row {
        return Row(baseRow: baseRow.copy(), statementAdapter: statementAdapter)
    }
}

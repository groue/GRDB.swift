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

public struct RowAdapter {
    let impl: RowAdapterImpl
    
    public init(_ mainAdapter: RowAdapter, subrowAdapters: [String: RowAdapter]) {
        impl = NestedRowAdapterImpl(mainAdapter: mainAdapter, subrowAdapters: subrowAdapters)
    }
    
    public init(_ dictionary: [String: String]) {
        self.init(impl: DictionaryRowAdapterImpl(dictionary: dictionary))
    }
    
    init(impl: RowAdapterImpl) {
        self.impl = impl
    }
    
    func boundRowAdapter(with statement: SelectStatement) throws -> BoundRowAdapter {
        return try impl.boundRowAdapter(with: statement)
    }
    
    func orderedMapping(statement statement: SelectStatement) throws -> [(String, String)] {
        return try impl.orderedMapping(statement: statement)
    }
}

extension RowAdapter : DictionaryLiteralConvertible {
    public init(dictionaryLiteral elements: (String, String)...) {
        self.init(impl: DictionaryRowAdapterImpl(dictionary: Dictionary(keyValueSequence: elements)))
    }
}

protocol RowAdapterImpl {
    func boundRowAdapter(with statement: SelectStatement) throws -> BoundRowAdapter
    func orderedMapping(statement statement: SelectStatement) throws -> [(String, String)]
}

struct DictionaryRowAdapterImpl: RowAdapterImpl {
    let dictionary: [String: String]
    
    func boundRowAdapter(with statement: SelectStatement) throws -> BoundRowAdapter {
        let mainColumnsAdapter = try ColumnsAdapter(orderedMapping: orderedMapping(statement: statement))
        return BoundRowAdapter(mainColumnsAdapter: mainColumnsAdapter, subrowBoundRowAdapters: [:])
    }

    // Turns a dictionary [mappedColumn:baseColumn, ...] into an array
    // [(mappedColumn, baseColumn), ...] ordered like the satement columns.
    func orderedMapping(statement statement: SelectStatement) throws -> [(String, String)] {
        return try dictionary
            .map { (mappedColumn, baseColumn) -> (Int, (String, String)) in
                guard let index = statement.indexOfColumn(named: baseColumn) else {
                    throw DatabaseError(code: SQLITE_MISUSE, message: "Mapping references missing column \(baseColumn). Valid column names are: \(statement.columnNames.joinWithSeparator(", ")).")
                }
                return (index, (mappedColumn, baseColumn))
            }
            .sort { return $0.0 < $1.0 }
            .map { $0.1 }
    }
}

struct NestedRowAdapterImpl: RowAdapterImpl {
    let mainAdapter: RowAdapter
    let subrowAdapters: [String: RowAdapter]
    
    func boundRowAdapter(with statement: SelectStatement) throws -> BoundRowAdapter {
        let mainColumnsAdapter = try ColumnsAdapter(orderedMapping: orderedMapping(statement: statement))
        let subrowBoundRowAdapters = try Dictionary(keyValueSequence: subrowAdapters.map { (identifier, adapter) in
            (identifier, try BoundRowAdapter(mainColumnsAdapter: ColumnsAdapter(orderedMapping: adapter.orderedMapping(statement: statement)), subrowBoundRowAdapters: [:]))
            })
        return BoundRowAdapter(mainColumnsAdapter: mainColumnsAdapter, subrowBoundRowAdapters: subrowBoundRowAdapters)
    }
    
    func orderedMapping(statement statement: SelectStatement) throws -> [(String, String)] {
        return try mainAdapter.orderedMapping(statement: statement)
    }
}

struct BoundRowAdapter {
    let mainColumnsAdapter: ColumnsAdapter
    let subrowBoundRowAdapters: [String: BoundRowAdapter]
}

struct ColumnsAdapter {
    let orderedMapping: [(String, String)]  // [(mappedColumn, baseColumn), ...]
    let lowercaseColumnIndexes: [String: Int]

    init(orderedMapping: [(String, String)]) {
        self.orderedMapping = orderedMapping
        self.lowercaseColumnIndexes = Dictionary(keyValueSequence: orderedMapping.enumerate().map { ($1.0.lowercaseString, $0) })
    }

    var count: Int {
        return orderedMapping.count
    }

    func baseColumName(atIndex index: Int) -> String {
        return orderedMapping[index].1
    }

    func columnName(atIndex index: Int) -> String {
        return orderedMapping[index].0
    }

    func indexOfColumn(named name: String) -> Int? {
        if let index = lowercaseColumnIndexes[name] {
            return index
        }
        return lowercaseColumnIndexes[name.lowercaseString]
    }
}

extension Row {
    /// Builds a row from a base row and column mappings
    convenience init(baseRow: Row, boundRowAdapter: BoundRowAdapter) {
        self.init(impl: AdaptedRowImpl(baseRow: baseRow, boundRowAdapter: boundRowAdapter))
    }
}

// See Row.init(baseRow:boundRowAdapter:)
private struct AdaptedRowImpl : RowImpl {
    let baseRow: Row
    let boundRowAdapter: BoundRowAdapter
    var mainAdapter: ColumnsAdapter { return boundRowAdapter.mainColumnsAdapter }
    
    init(baseRow: Row, boundRowAdapter: BoundRowAdapter) {
        self.baseRow = baseRow
        self.boundRowAdapter = boundRowAdapter
    }
    
    var count: Int {
        return mainAdapter.count
    }
    
    func databaseValue(atIndex index: Int) -> DatabaseValue {
        return baseRow.databaseValue(named: mainAdapter.baseColumName(atIndex: index))!
    }
    
    func dataNoCopy(atIndex index:Int) -> NSData? {
        return baseRow.dataNoCopy(named: mainAdapter.baseColumName(atIndex: index))
    }
    
    func columnName(atIndex index: Int) -> String {
        return mainAdapter.columnName(atIndex: index)
    }
    
    func indexOfColumn(named name: String) -> Int? {
        return mainAdapter.indexOfColumn(named: name)
    }
    
    func subrow(named name: String) -> Row? {
        guard let adapter = boundRowAdapter.subrowBoundRowAdapters[name] else {
            return nil
        }
        return Row(baseRow: baseRow, boundRowAdapter: adapter)
    }
    
    var subrowNames: Set<String> {
        return Set(boundRowAdapter.subrowBoundRowAdapters.keys)
    }
    
    func copy(row: Row) -> Row {
        return Row(baseRow: baseRow.copy(), boundRowAdapter: boundRowAdapter)
    }
}

/// Information about the table, columns, and rows read by a SelectStatement.
///
/// You don't create SelectionInfo directly. Instead, you use one of
/// those methods:
///
///     class SelectStatement {
///         var selectionInfo: SelectionInfo
///     }
///     protocol Request {
///         func selectionInfo(_ db: Database) throws -> SelectionInfo
///     }
///     class Database {
///         func selectionInfo(rowIds: Set<Int64>, in tableName: String) throws -> SelectionInfo
///     }
public struct DatabaseSelectionInfo {
    private let tables: [String: TableSelectionInfo]?
    private init(tables: [String: TableSelectionInfo]?) {
        self.tables = tables
    }
    
    /// TODO
    public var isEmpty: Bool {
        guard let tables = tables else { return false }
        return tables.isEmpty
    }
    
    var tableNames: Set<String> {
        guard let tables = tables else { return [] }
        return Set(tables.keys)
    }
    
    /// Full database = (All columns in all tables) × (all rows)
    static let fullDatabase = DatabaseSelectionInfo(tables: nil)
    
    /// Empty selection
    init() {
        self.init(tables: [:])
    }
    
    /// (all columns in a table) × (all rows)
    init(table: String) {
        self.init(tables: [table: TableSelectionInfo(columns: nil, rowIds: nil)])
    }
    
    /// (some columns in a table) × (all rows)
    init(table: String, columns: Set<String>) {
        self.init(tables: [table: TableSelectionInfo(columns: columns, rowIds: nil)])
    }
    
    /// (all columns in a table) × (some rows)
    init(table: String, rowIds: Set<Int64>) {
        self.init(tables: [table: TableSelectionInfo(columns: nil, rowIds: rowIds)])
    }
    
    public func intersection(_ other: DatabaseSelectionInfo) -> DatabaseSelectionInfo {
        guard let tables = tables else { return other }
        guard let otherTables = other.tables else { return self }
        
        var tablesIntersection: [String: TableSelectionInfo] = [:]
        for (table, tableInfo) in tables {
            guard let otherTableInfo = otherTables
                .first(where: { (otherTable, _) in otherTable == table })?
                .value else { continue }
            let tableInfoIntersection = tableInfo.intersection(otherTableInfo)
            guard !tableInfoIntersection.isEmpty else { continue }
            tablesIntersection[table] = tableInfoIntersection
        }
        
        return DatabaseSelectionInfo(tables: tablesIntersection)
    }
    
    public func union(_ other: DatabaseSelectionInfo) -> DatabaseSelectionInfo {
        guard let tables = tables else { return .fullDatabase }
        guard let otherTables = other.tables else { return .fullDatabase }
        
        var tablesUnion: [String: TableSelectionInfo] = [:]
        let tableNames = Set(tables.map { $0.key }).union(Set(otherTables.map { $0.key }))
        for table in tableNames {
            let tableInfo = tables[table]
            let otherTableInfo = otherTables[table]
            let tableInfoUnion: TableSelectionInfo
            switch (tableInfo, otherTableInfo) {
            case (nil, nil):
                preconditionFailure()
            case (nil, let tableInfo?), (let tableInfo?, nil):
                tableInfoUnion = tableInfo
            case (let tableInfo?, let otherTableInfo?):
                tableInfoUnion = tableInfo.union(otherTableInfo)
            }
            tablesUnion[table] = tableInfoUnion
        }
        
        return DatabaseSelectionInfo(tables: tablesUnion)
    }
    
    public mutating func formIntersection(_ other: DatabaseSelectionInfo) {
        self = intersection(other)
    }
    
    public mutating func formUnion(_ other: DatabaseSelectionInfo) {
        self = union(other)
    }
}

extension DatabaseSelectionInfo {
    
    // MARK: - Database Events
    
    /// TODO
    public func isModified(byEventsOfKind eventKind: DatabaseEventKind) -> Bool {
        switch eventKind {
        case .delete(let tableName):
            return !intersection(DatabaseSelectionInfo(table: tableName)).isEmpty
        case .insert(let tableName):
            return !intersection(DatabaseSelectionInfo(table: tableName)).isEmpty
        case .update(let tableName, let updatedColumnNames):
            return !intersection(DatabaseSelectionInfo(table: tableName, columns: updatedColumnNames)).isEmpty
        }
    }
    
    /// TODO
    /// - precondition: event has been filtered by the same selection info
    ///   in the TransactionObserver.observes(eventsOfKind:) method.
    public func isModified(by event: DatabaseEvent) -> Bool {
        guard let tables = tables else {
            return true
        }
        
        switch tables.count {
        case 1:
            // The precondition applies here:
            //
            // The selectionInfo contains a single table. Due to the
            // filtering of events performed in observes(eventsOfKind:), the
            // event argument is guaranteed to be about the fetched table.
            // We thus only have to check for rowIds.
            assert(event.tableName == tables[tables.startIndex].key) // sanity check
            guard let rowIds = tables[tables.startIndex].value.rowIds else {
                return true
            }
            return rowIds.contains(event.rowID)
        default:
            guard let tableInfo = tables[event.tableName] else {
                // Shouldn't happen if the precondition is met.
                fatalError("precondition failure: missing selection info for table \(event.tableName)")
            }
            guard let rowIds = tableInfo.rowIds else {
                return true
            }
            return rowIds.contains(event.rowID)
        }
    }
}

extension DatabaseSelectionInfo: Equatable {
    public static func == (lhs: DatabaseSelectionInfo, rhs: DatabaseSelectionInfo) -> Bool {
        switch (lhs.tables, rhs.tables) {
        case (nil, nil):
            return true
        case (let ltables?, let rtables?):
            let ltableNames = Set(ltables.map { $0.key })
            let rtableNames = Set(rtables.map { $0.key })
            guard ltableNames == rtableNames else {
                return false
            }
            for tableName in ltableNames {
                if ltables[tableName]! != rtables[tableName]! {
                    return false
                }
            }
            return true
        default:
            return false
        }
    }
}

extension DatabaseSelectionInfo: CustomStringConvertible {
    public var description: String {
        guard let tables = tables else {
            return "full database"
        }
        if tables.isEmpty {
            return "empty"
        }
        return tables
            .sorted(by: { (l, r) in l.key < r.key })
            .map { (table, tableInfo) in
                var desc = table
                if let columns = tableInfo.columns {
                    desc += "(" + columns.sorted().joined(separator: ",") + ")"
                } else {
                    desc += "(*)"
                }
                if let rowIds = tableInfo.rowIds {
                    desc += "[" + rowIds.sorted().map { "\($0)" }.joined(separator: ",") + "]"
                }
                return desc
            }
            .joined(separator: ",")
    }
}

private struct TableSelectionInfo: Equatable {
    var columns: Set<String>? // nil means "all columns"
    var rowIds: Set<Int64>? // nil means "all rowids"
    
    var isEmpty: Bool {
        if let columns = columns, columns.isEmpty { return true }
        if let rowIds = rowIds, rowIds.isEmpty { return true }
        return false
    }
    
    static func == (lhs: TableSelectionInfo, rhs: TableSelectionInfo) -> Bool {
        if lhs.columns != rhs.columns { return false }
        if lhs.rowIds != rhs.rowIds { return false }
        return true
    }
    
    func intersection(_ other: TableSelectionInfo) -> TableSelectionInfo {
        let columnsIntersection: Set<String>?
        switch (self.columns, other.columns) {
        case (nil, let columns), (let columns, nil):
            columnsIntersection = columns
        case (let columns?, let other?):
            columnsIntersection = columns.intersection(other)
        }
        
        let rowIdsIntersection: Set<Int64>?
        switch (self.rowIds, other.rowIds) {
        case (nil, let rowIds), (let rowIds, nil):
            rowIdsIntersection = rowIds
        case (let rowIds?, let other?):
            rowIdsIntersection = rowIds.intersection(other)
        }
        
        return TableSelectionInfo(columns: columnsIntersection, rowIds: rowIdsIntersection)
    }
    
    func union(_ other: TableSelectionInfo) -> TableSelectionInfo {
        let columnsUnion: Set<String>?
        switch (self.columns, other.columns) {
        case (nil, _), (_, nil):
            columnsUnion = nil
        case (let columns?, let other?):
            columnsUnion = columns.union(other)
        }
        
        let rowIdsUnion: Set<Int64>?
        switch (self.rowIds, other.rowIds) {
        case (nil, _), (_, nil):
            rowIdsUnion = nil
        case (let rowIds?, let other?):
            rowIdsUnion = rowIds.union(other)
        }
        
        return TableSelectionInfo(columns: columnsUnion, rowIds: rowIdsUnion)
    }
}

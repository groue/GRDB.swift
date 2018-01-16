/// DatabaseRegion defines a region in the database, that is to say tables,
/// columns, and rows (identified by their rowids). DatabaseRegion is dedicated
/// to help transaction observers recognize impactful database changes.
///
///    |  T  |   |  U  |    |  V  |
///    |-----|   |-----|    |-----|
///    |x|x|x|   |x| | |    | | | |
///    |x|x|x|   |x| | |    |x|x|x|
///    |x|x|x|   |x| | |    | | | |
///    |x|x|x|   |x| | |    | | | |
///
/// Unions and intersections of regions create more complex regions:
///
///    |  T  |   |  U  |   |  T  | |  U  |
///    |-----|   |-----|   |-----| |-----|
///    | | | | + |x| | | = | | | | |x| | |
///    |x| | |   |x| | |   |x| | | |x| | |
///    | | | |   |x| | |   | | | | |x| | |
///    | | | |   |x| | |   | | | | |x| | |
///
///    |  T  |   |  T  |   |  T  |
///    |-----|   |-----|   |-----|
///    |x| | | * | | | | = | | | |
///    |x| | |   |x|x|x|   |x| | |
///    |x| | |   | | | |   | | | |
///    |x| | |   | | | |   | | | |
///
/// You don't create a database region directly. Instead, you use one of
/// those methods:
///
/// - `SelectStatement.region`:
///
///     let statement = db.makeSelectStatement("SELECT name, score FROM players")
///     print(statement.region)
///     // prints "players(name,score)"
///
/// - `Request.region(_:)`
///
///     let request = Player.filter(key: 1)
///     try print(request.region(db))
///     // prints "players(*)[1]"
///
/// - `Database.region(rowIds:in:)`
///
///     try print(db.region(rowIds: [1, 2], in: "players")
///     // prints "players(*)[1, 2]"
public struct DatabaseRegion {
    private let tables: [String: TableRegion]?
    private init(tables: [String: TableRegion]?) {
        self.tables = tables
    }
    
    /// Returns whether the region is empty.
    public var isEmpty: Bool {
        guard let tables = tables else { return false }
        return tables.isEmpty
    }
    
    /// The full database: (All columns in all tables) × (all rows)
    static let fullDatabase = DatabaseRegion(tables: nil)
    
    /// The empty region
    init() {
        self.init(tables: [:])
    }
    
    /// A full table: (all columns in the table) × (all rows)
    init(table: String) {
        self.init(tables: [table: TableRegion(columns: nil, rowIds: nil)])
    }
    
    /// Full columns in a table: (some columns in a table) × (all rows)
    init(table: String, columns: Set<String>) {
        self.init(tables: [table: TableRegion(columns: columns, rowIds: nil)])
    }
    
    /// Full rows in a table: (all columns in a table) × (some rows)
    init(table: String, rowIds: Set<Int64>) {
        self.init(tables: [table: TableRegion(columns: nil, rowIds: rowIds)])
    }
    
    /// Returns the intersection of this region and the given one.
    ///
    ///    |  T  |   |  T  |   |  T  |
    ///    |-----|   |-----|   |-----|
    ///    |x| | | * | | | | = | | | |
    ///    |x| | |   |x|x|x|   |x| | |
    ///    |x| | |   | | | |   | | | |
    ///    |x| | |   | | | |   | | | |
    public func intersection(_ other: DatabaseRegion) -> DatabaseRegion {
        guard let tables = tables else { return other }
        guard let otherTables = other.tables else { return self }
        
        var tablesIntersection: [String: TableRegion] = [:]
        for (table, tableInfo) in tables {
            guard let otherTableInfo = otherTables
                .first(where: { (otherTable, _) in otherTable == table })?
                .value else { continue }
            let tableInfoIntersection = tableInfo.intersection(otherTableInfo)
            guard !tableInfoIntersection.isEmpty else { continue }
            tablesIntersection[table] = tableInfoIntersection
        }
        
        return DatabaseRegion(tables: tablesIntersection)
    }
    
    /// Returns the union of this region and the given one.
    ///
    ///    |  T  |   |  T  |   |  T  |
    ///    |-----|   |-----|   |-----|
    ///    |x| | | + | |x| | = |x|x| |
    ///    |x| | |   | |x| |   |x|x| |
    ///    |x| | |   | |x| |   |x|x| |
    ///    |x| | |   | |x| |   |x|x| |
    public func union(_ other: DatabaseRegion) -> DatabaseRegion {
        guard let tables = tables else { return .fullDatabase }
        guard let otherTables = other.tables else { return .fullDatabase }
        
        var tablesUnion: [String: TableRegion] = [:]
        let tableNames = Set(tables.map { $0.key }).union(Set(otherTables.map { $0.key }))
        for table in tableNames {
            let tableInfo = tables[table]
            let otherTableInfo = otherTables[table]
            let tableInfoUnion: TableRegion
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
        
        return DatabaseRegion(tables: tablesUnion)
    }

    /// Removes the table, columns, and rows in the given region that are not
    /// in this region.
    ///
    ///    |  T  |   |  T  |   |  T  |
    ///    |-----|   |-----|   |-----|
    ///    |x| | | * | | | | = | | | |
    ///    |x| | |   |x|x|x|   |x| | |
    ///    |x| | |   | | | |   | | | |
    ///    |x| | |   | | | |   | | | |
    public mutating func formIntersection(_ other: DatabaseRegion) {
        self = intersection(other)
    }

    /// Inserts the given region into this region
    ///
    ///    |  T  |   |  T  |   |  T  |
    ///    |-----|   |-----|   |-----|
    ///    |x| | | + | |x| | = |x|x| |
    ///    |x| | |   | |x| |   |x|x| |
    ///    |x| | |   | |x| |   |x|x| |
    ///    |x| | |   | |x| |   |x|x| |
    public mutating func formUnion(_ other: DatabaseRegion) {
        self = union(other)
    }
}

extension DatabaseRegion {
    
    // MARK: - Database Events
    
    /// Returns whether the content in the region would be impacted if the
    /// database were modified by an event of this kind.
    public func isModified(byEventsOfKind eventKind: DatabaseEventKind) -> Bool {
        return !intersection(eventKind.region).isEmpty
    }
    
    /// Returns whether the content in the region is impacted by this event.
    ///
    /// - precondition: event has been filtered by the same region
    ///   in the TransactionObserver.observes(eventsOfKind:) method, by calling
    ///   region.isModified(byEventsOfKind:)
    public func isModified(by event: DatabaseEvent) -> Bool {
        guard let tables = tables else {
            return true
        }
        
        switch tables.count {
        case 1:
            // The precondition applies here:
            //
            // The region contains a single table. Due to the
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
                fatalError("precondition failure: event was not filtered out in observes(eventsOfKind:) by region.isModified(byEventsOfKind:)")
            }
            guard let rowIds = tableInfo.rowIds else {
                return true
            }
            return rowIds.contains(event.rowID)
        }
    }
}

extension DatabaseRegion: Equatable {
    public static func == (lhs: DatabaseRegion, rhs: DatabaseRegion) -> Bool {
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

extension DatabaseRegion: CustomStringConvertible {
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

private struct TableRegion: Equatable {
    var columns: Set<String>? // nil means "all columns"
    var rowIds: Set<Int64>? // nil means "all rowids"
    
    var isEmpty: Bool {
        if let columns = columns, columns.isEmpty { return true }
        if let rowIds = rowIds, rowIds.isEmpty { return true }
        return false
    }
    
    static func == (lhs: TableRegion, rhs: TableRegion) -> Bool {
        if lhs.columns != rhs.columns { return false }
        if lhs.rowIds != rhs.rowIds { return false }
        return true
    }
    
    func intersection(_ other: TableRegion) -> TableRegion {
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
        
        return TableRegion(columns: columnsIntersection, rowIds: rowIdsIntersection)
    }
    
    func union(_ other: TableRegion) -> TableRegion {
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
        
        return TableRegion(columns: columnsUnion, rowIds: rowIdsUnion)
    }
}

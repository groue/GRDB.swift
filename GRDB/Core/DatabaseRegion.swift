/// DatabaseRegion defines a region in the database. DatabaseRegion is dedicated
/// to help transaction observers recognize impactful database changes in their
/// `observes(eventsOfKind:)` and `databaseDidChange(with:)` methods.
///
/// A database region is the union of any number of "table regions", which can
/// cover a full table, or the combination of columns and rows (identified by
/// their rowids):
///
///     |Table1 |   |Table2 |   |Table3 |   |Table4 |   |Table5 |
///     |-------|   |-------|   |-------|   |-------|   |-------|
///     |x|x|x|x|   |x| | | |   |x|x|x|x|   |x|x| |x|   | | | | |
///     |x|x|x|x|   |x| | | |   | | | | |   | | | | |   | |x| | |
///     |x|x|x|x|   |x| | | |   | | | | |   |x|x| |x|   | | | | |
///     |x|x|x|x|   |x| | | |   | | | | |   | | | | |   | | | | |
///
/// You don't create a database region directly. Instead, you use one of
/// those methods:
///
/// - `SelectStatement.databaseRegion`:
///
///         let statement = db.makeSelectStatement("SELECT name, score FROM player")
///         print(statement.databaseRegion)
///         // prints "player(name,score)"
///
/// - `FetchRequest.databaseRegion(_:)`
///
///         let request = Player.filter(key: 1)
///         try print(request.databaseRegion(db))
///         // prints "player(*)[1]"
///
/// Database regions returned by requests can be more precise than regions
/// returned by select statements. Especially, regions returned by statements
/// don't know about rowids:
///
///     // A plain statement
///     let statement = db.makeSelectStatement("SELECT * FROM player WHERE id = 1")
///     statement.databaseRegion       // "player(*)"
///
///     // A query interface request that executes the same statement:
///     let request = Player.filter(key: 1)
///     try request.databaseRegion(db) // "player(*)[1]"
public struct DatabaseRegion: CustomStringConvertible, Equatable {
    private let tableRegions: [String: TableRegion]?
    private init(tableRegions: [String: TableRegion]?) {
        self.tableRegions = tableRegions
    }
    
    /// Returns whether the region is empty.
    public var isEmpty: Bool {
        guard let tableRegions = tableRegions else {
            // full database
            return false
        }
        return tableRegions.isEmpty
    }
    
    /// The region that covers the full database: all columns and all rows
    /// from all tables.
    public static let fullDatabase = DatabaseRegion(tableRegions: nil)
    
    /// The empty database region
    public init() {
        self.init(tableRegions: [:])
    }
    
    /// A full table: (all columns in the table) × (all rows)
    init(table: String) {
        self.init(tableRegions: [table: TableRegion(columns: nil, rowIds: nil)])
    }
    
    /// Full columns in a table: (some columns in a table) × (all rows)
    init(table: String, columns: Set<String>) {
        self.init(tableRegions: [table: TableRegion(columns: columns, rowIds: nil)])
    }
    
    /// Full rows in a table: (all columns in a table) × (some rows)
    init(table: String, rowIds: Set<Int64>) {
        self.init(tableRegions: [table: TableRegion(columns: nil, rowIds: rowIds)])
    }
    
    /// Returns the intersection of this region and the given one.
    ///
    /// This method is not public because there is no known public use case for
    /// this intersection. It is currently only used as support for
    /// the isModified(byEventsOfKind:) method.
    func intersection(_ other: DatabaseRegion) -> DatabaseRegion {
        guard let tableRegions = tableRegions else { return other }
        guard let otherTableRegions = other.tableRegions else { return self }
        
        var tableRegionsIntersection: [String: TableRegion] = [:]
        for (table, tableRegion) in tableRegions {
            guard let otherTableRegion = otherTableRegions
                .first(where: { (otherTable, _) in otherTable == table })?
                .value else { continue }
            let tableRegionIntersection = tableRegion.intersection(otherTableRegion)
            guard !tableRegionIntersection.isEmpty else { continue }
            tableRegionsIntersection[table] = tableRegionIntersection
        }
        
        return DatabaseRegion(tableRegions: tableRegionsIntersection)
    }
    
    /// Only keeps those rowIds in the given table
    func tableIntersection(_ table: String, rowIds: Set<Int64>) -> DatabaseRegion {
        guard var tableRegions = tableRegions else {
            return DatabaseRegion(table: table, rowIds: rowIds)
        }
        
        guard let tableRegion = tableRegions[table] else {
            return self
        }
        
        let intersection = tableRegion.intersection(TableRegion(columns: nil, rowIds: rowIds))
        if intersection.isEmpty {
            tableRegions.removeValue(forKey: table)
        } else {
            tableRegions[table] = intersection
        }
        return DatabaseRegion(tableRegions: tableRegions)
    }
    
    /// Returns the union of this region and the given one.
    public func union(_ other: DatabaseRegion) -> DatabaseRegion {
        guard let tableRegions = tableRegions else { return .fullDatabase }
        guard let otherTableRegions = other.tableRegions else { return .fullDatabase }
        
        var tableRegionsUnion: [String: TableRegion] = [:]
        let tableNames = Set(tableRegions.keys).union(Set(otherTableRegions.keys))
        for table in tableNames {
            let tableRegion = tableRegions[table]
            let otherTableRegion = otherTableRegions[table]
            let tableRegionUnion: TableRegion
            switch (tableRegion, otherTableRegion) {
            case (nil, nil):
                preconditionFailure()
            case (nil, let tableRegion?), (let tableRegion?, nil):
                tableRegionUnion = tableRegion
            case (let tableRegion?, let otherTableRegion?):
                tableRegionUnion = tableRegion.union(otherTableRegion)
            }
            tableRegionsUnion[table] = tableRegionUnion
        }
        
        return DatabaseRegion(tableRegions: tableRegionsUnion)
    }
    
    /// Inserts the given region into this region
    public mutating func formUnion(_ other: DatabaseRegion) {
        self = union(other)
    }
    
    func ignoring(_ tables: Set<String>) -> DatabaseRegion {
        guard tables.isEmpty == false else { return self }
        guard let tableRegions = tableRegions else { return .fullDatabase }
        let filteredRegions = tableRegions.filter { tables.contains($0.key) == false }
        return DatabaseRegion(tableRegions: filteredRegions)
    }
}

extension DatabaseRegion {
    
    // MARK: - Database Events
    
    /// Returns whether the content in the region would be impacted if the
    /// database were modified by an event of this kind.
    public func isModified(byEventsOfKind eventKind: DatabaseEventKind) -> Bool {
        return intersection(eventKind.modifiedRegion).isEmpty == false
    }
    
    /// Returns whether the content in the region is impacted by this event.
    ///
    /// - precondition: event has been filtered by the same region
    ///   in the TransactionObserver.observes(eventsOfKind:) method, by calling
    ///   region.isModified(byEventsOfKind:)
    public func isModified(by event: DatabaseEvent) -> Bool {
        guard let tableRegions = tableRegions else {
            // Full database: all changes are impactful
            return true
        }
        
        if tableRegions.count == 1 {
            // Fast path when the region contains a single table.
            //
            // We can apply the precondition: due to the filtering of events
            // performed in observes(eventsOfKind:), the event argument is
            // guaranteed to be about the fetched table. We thus only have to
            // check for rowIds.
            assert(event.tableName == tableRegions[tableRegions.startIndex].key) // sanity check in debug mode
            let tableRegion = tableRegions[tableRegions.startIndex].value
            return tableRegion.contains(rowID: event.rowID)
        } else {
            // Slow path when several tables are observed.
            guard let tableRegion = tableRegions[event.tableName] else {
                // Shouldn't happen if the precondition is met.
                fatalError("precondition failure: event was not filtered out in observes(eventsOfKind:) by region.isModified(byEventsOfKind:)")
            }
            return tableRegion.contains(rowID: event.rowID)
        }
    }
}

// Equatable
extension DatabaseRegion {
    /// :nodoc:
    public static func == (lhs: DatabaseRegion, rhs: DatabaseRegion) -> Bool {
        switch (lhs.tableRegions, rhs.tableRegions) {
        case (nil, nil):
            return true
        case (let ltableRegions?, let rtableRegions?):
            let ltableNames = Set(ltableRegions.keys)
            let rtableNames = Set(rtableRegions.keys)
            guard ltableNames == rtableNames else {
                return false
            }
            for tableName in ltableNames {
                if ltableRegions[tableName]! != rtableRegions[tableName]! {
                    return false
                }
            }
            return true
        default:
            return false
        }
    }
}

// CustomStringConvertible
extension DatabaseRegion {
    /// :nodoc:
    public var description: String {
        guard let tableRegions = tableRegions else {
            return "full database"
        }
        if tableRegions.isEmpty {
            return "empty"
        }
        return tableRegions
            .sorted(by: { (l, r) in l.key < r.key })
            .map { (table, tableRegion) in
                var desc = table
                if let columns = tableRegion.columns {
                    desc += "(" + columns.sorted().joined(separator: ",") + ")"
                } else {
                    desc += "(*)"
                }
                if let rowIds = tableRegion.rowIds {
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
    
    @inline(__always)
    func contains(rowID: Int64) -> Bool {
        guard let rowIds = rowIds else {
            return true
        }
        return rowIds.contains(rowID)
    }
}

// MARK: - DatabaseRegionConvertible

public protocol DatabaseRegionConvertible {
    /// Returns a database region.
    ///
    /// - parameter db: A database connection.
    func databaseRegion(_ db: Database) throws -> DatabaseRegion
}

extension DatabaseRegion: DatabaseRegionConvertible {
    /// :nodoc:
    public func databaseRegion(_ db: Database) throws -> DatabaseRegion {
        return self
    }
}

/// A type-erased DatabaseRegionConvertible
public struct AnyDatabaseRegionConvertible: DatabaseRegionConvertible {
    let _region: (Database) throws -> DatabaseRegion
    
    public init(_ region: @escaping (Database) throws -> DatabaseRegion) {
        _region = region
    }
    
    public init(_ region: DatabaseRegionConvertible) {
        _region = { try region.databaseRegion($0) }
    }
    
    /// :nodoc:
    public func databaseRegion(_ db: Database) throws -> DatabaseRegion {
        return try _region(db)
    }
}

// MARK: - Utils

extension DatabaseRegion {
    static func union(_ regions: DatabaseRegion...) -> DatabaseRegion {
        return regions.reduce(into: DatabaseRegion()) { union, region in
            union.formUnion(region)
        }
    }
    
    static func union(_ regions: [DatabaseRegionConvertible]) -> (Database) throws -> DatabaseRegion {
        return { db in
            try regions.reduce(into: DatabaseRegion()) { union, region in
                try union.formUnion(region.databaseRegion(db))
            }
        }
    }
}

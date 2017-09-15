/// Types that adopt TableMapping declare a particular relationship with
/// a database table.
///
/// Types that adopt both TableMapping and RowConvertible are granted with
/// built-in methods that allow to fetch instances identified by key:
///
///     try Player.fetchOne(db, key: 123)  // Player?
///     try Citizenship.fetchOne(db, key: ["citizenId": 12, "countryId": 45]) // Citizenship?
///
/// TableMapping is adopted by Record.
public protocol TableMapping {
    /// The name of the database table used to build requests.
    ///
    ///     struct Player : TableMapping {
    ///         static var databaseTableName = "players"
    ///     }
    ///
    ///     // SELECT * FROM players
    ///     try Player.fetchAll(db)
    static var databaseTableName: String { get }
    
    /// The default request selection.
    ///
    /// Unless said otherwise, requests select all columns:
    ///
    ///     // SELECT * FROM players
    ///     try Player.fetchAll(db)
    ///
    /// You can provide a custom implementation and provide an explicit list
    /// of columns:
    ///
    ///     struct RestrictedPlayer : TableMapping {
    ///         static var databaseTableName = "players"
    ///         static var databaseSelection = [Column("id"), Column("name")]
    ///     }
    ///
    ///     // SELECT id, name FROM players
    ///     try RestrictedPlayer.fetchAll(db)
    ///
    /// You can also add extra columns such as the `rowid` column:
    ///
    ///     struct ExtendedPlayer : TableMapping {
    ///         static var databaseTableName = "players"
    ///         static let databaseSelection: [SQLSelectable] = [AllColumns(), Column.rowID]
    ///     }
    ///
    ///     // SELECT *, rowid FROM players
    ///     try ExtendedPlayer.fetchAll(db)
    static var databaseSelection: [SQLSelectable] { get }
}

extension TableMapping {
    /// Default value: `[AllColumns()]`.
    public static var databaseSelection: [SQLSelectable] {
        return [AllColumns()]
    }
}

extension TableMapping {
    
    // MARK: Counting All
    
    /// The number of records.
    ///
    /// - parameter db: A database connection.
    public static func fetchCount(_ db: Database) throws -> Int {
        return try all().fetchCount(db)
    }
}

extension TableMapping {
    
    // MARK: Key Requests
    
    static func filter<Sequence: Swift.Sequence>(_ db: Database, keys: Sequence) throws -> QueryInterfaceRequest<Self> where Sequence.Element: DatabaseValueConvertible {
        let primaryKey = try db.primaryKey(databaseTableName)
        let columns = primaryKey.columns.map { Column($0) }
        GRDBPrecondition(columns.count == 1, "table \(databaseTableName) has multiple columns in its primary key")
        let column = columns[0]
        
        let keys = Array(keys)
        switch keys.count {
        case 0:
            return none()
        case 1:
            return filter(column == keys[0])
        default:
            return filter(keys.contains(column))
        }
    }
    
    // Raises a fatal error if there is no unique index on the columns (unless
    // fatalErrorOnMissingUniqueIndex is false, for testability).
    //
    // TODO: think about
    // - allowing non unique keys in Type.fetchOne(db, key: ...) ???
    // - allowing non unique keys in Type.fetchAll/Cursor(db, keys: ...)
    // - forbidding nil values: Player.deleteOne(db, key: ["email": nil]) may delete several rows (case of a nullable unique key)
    static func filter(_ db: Database, keys: [[String: DatabaseValueConvertible?]], fatalErrorOnMissingUniqueIndex: Bool = true) throws -> QueryInterfaceRequest<Self> {
        // SELECT * FROM table WHERE ((a=? AND b=?) OR (c=? AND d=?) OR ...)
        let keyPredicates: [SQLExpression] = try keys.map { key in
            // Prevent filter(db, keys: [[:]])
            GRDBPrecondition(!key.isEmpty, "Invalid empty key dictionary")

            // Prevent filter(db, keys: [["foo": 1, "bar": 2]]) where
            // ("foo", "bar") is not a unique key (primary key or columns of a
            // unique index)
            guard let orderedColumns = try db.columnsForUniqueKey(key.keys, in: databaseTableName) else {
                let message = "table \(databaseTableName) has no unique index on column(s) \(key.keys.sorted().joined(separator: ", "))"
                if fatalErrorOnMissingUniqueIndex {
                    fatalError(message)
                } else {
                    throw DatabaseError(resultCode: .SQLITE_MISUSE, message: message)
                }
            }
            
            let lowercaseOrderedColumns = orderedColumns.map { $0.lowercased() }
            let columnPredicates: [SQLExpression] = key
                // Sort key columns in the same order as the unique index
                .sorted { (kv1, kv2) in lowercaseOrderedColumns.index(of: kv1.0.lowercased())! < lowercaseOrderedColumns.index(of: kv2.0.lowercased())! }
                .map { (column, value) in Column(column) == value }
            return SQLBinaryOperator.and.join(columnPredicates)! // not nil because columnPredicates is not empty
        }
        
        guard let predicate = SQLBinaryOperator.or.join(keyPredicates) else {
            // No key
            return none()
        }
        
        return filter(predicate)
    }
}

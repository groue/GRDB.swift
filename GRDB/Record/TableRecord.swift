/// Types that adopt TableRecord declare a particular relationship with
/// a database table.
///
/// Types that adopt both TableRecord and FetchableRecord are granted with
/// built-in methods that allow to fetch instances identified by key:
///
///     try Player.fetchOne(db, key: 123)  // Player?
///     try Citizenship.fetchOne(db, key: ["citizenId": 12, "countryId": 45]) // Citizenship?
///
/// TableRecord is adopted by Record.
public protocol TableRecord {
    /// The name of the database table used to build requests.
    ///
    ///     struct Player : TableRecord {
    ///         static var databaseTableName = "player"
    ///     }
    ///
    ///     // SELECT * FROM player
    ///     try Player.fetchAll(db)
    static var databaseTableName: String { get }
    
    /// The default request selection.
    ///
    /// Unless said otherwise, requests select all columns:
    ///
    ///     // SELECT * FROM player
    ///     try Player.fetchAll(db)
    ///
    /// You can provide a custom implementation and provide an explicit list
    /// of columns:
    ///
    ///     struct RestrictedPlayer : TableRecord {
    ///         static var databaseTableName = "player"
    ///         static var databaseSelection = [Column("id"), Column("name")]
    ///     }
    ///
    ///     // SELECT id, name FROM player
    ///     try RestrictedPlayer.fetchAll(db)
    ///
    /// You can also add extra columns such as the `rowid` column:
    ///
    ///     struct ExtendedPlayer : TableRecord {
    ///         static var databaseTableName = "player"
    ///         static let databaseSelection: [SQLSelectable] = [AllColumns(), Column.rowID]
    ///     }
    ///
    ///     // SELECT *, rowid FROM player
    ///     try ExtendedPlayer.fetchAll(db)
    static var databaseSelection: [SQLSelectable] { get }
}

extension TableRecord {
    /// Default value: `[AllColumns()]`.
    public static var databaseSelection: [SQLSelectable] {
        return [AllColumns()]
    }
}

extension TableRecord {
    
    // MARK: - Counting All
    
    /// The number of records.
    ///
    /// - parameter db: A database connection.
    public static func fetchCount(_ db: Database) throws -> Int {
        return try all().fetchCount(db)
    }
}

extension TableRecord {
    
    // MARK: - SQL Generation
    
    /// The selection as an SQL String.
    ///
    /// For example:
    ///
    ///     struct Player: TableRecord {
    ///         static let databaseTableName = "player"
    ///     }
    ///
    ///     // SELECT "player".* FROM player
    ///     let sql = "SELECT \(Player.selectionSQL()) FROM player"
    ///
    ///     // SELECT "p".* FROM player AS p
    ///     let sql = "SELECT \(Player.selectionSQL(alias: "p")) FROM player p"
    public static func selectionSQL(alias: String? = nil) -> String {
        let alias = TableAlias(tableName: databaseTableName, userName: alias)
        let selection = databaseSelection.map { $0.qualifiedSelectable(with: alias) }
        var context = SQLGenerationContext.recordSelectionGenerationContext(alias: alias)
        return selection
            .map { $0.resultColumnSQL(&context) }
            .joined(separator: ", ")
    }
    
    /// Returns the number of selected columns.
    ///
    /// For example:
    ///
    ///     struct Player: TableRecord {
    ///         static let databaseTableName = "player"
    ///     }
    ///
    ///     try dbQueue.write { db in
    ///         try db.create(table: "player") { t in
    ///             t.autoIncrementedPrimaryKey("id")
    ///             t.column("name", .text)
    ///             t.column("score", .integer)
    ///         }
    ///
    ///         // 3
    ///         try Player.numberOfSelectedColumns(db)
    ///     }
    public static func numberOfSelectedColumns(_ db: Database) throws -> Int {
        let alias = TableAlias(tableName: databaseTableName)
        return try databaseSelection
            .map { try $0.qualifiedSelectable(with: alias).columnCount(db) }
            .reduce(0, +)
    }
}

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
    
    // MARK: - Counting All
    
    /// The number of records.
    ///
    /// - parameter db: A database connection.
    public static func fetchCount(_ db: Database) throws -> Int {
        return try all().fetchCount(db)
    }
}

extension TableMapping {
    
    // MARK: - SQL Generation
    
    /// The selection as an SQL String.
    ///
    /// For example:
    ///
    ///     struct Player: TableMapping {
    ///         static let databaseTableName = "players"
    ///     }
    ///
    ///     // SELECT "players".* FROM players
    ///     let sql = "SELECT \(Player.selectionSQL()) FROM players"
    ///
    ///     // SELECT "p".* FROM players AS p
    ///     let sql = "SELECT \(Player.selectionSQL(alias: "p")) FROM players AS p"
    public static func selectionSQL(alias: String? = nil) -> String {
        let qualifier = SQLTableQualifier(tableName: databaseTableName, alias: alias ?? databaseTableName)
        let selection = databaseSelection.map { $0.qualified(by: qualifier) }
        var arguments: StatementArguments? = nil
        return selection
            .map { $0.resultColumnSQL(&arguments) }
            .joined(separator: ", ")
    }
    
    /// Returns the number of selected columns.
    ///
    /// For example:
    ///
    ///     struct Player: TableMapping {
    ///         static let databaseTableName = "players"
    ///     }
    ///
    ///     try dbQueue.inDatabase { db in
    ///         try db.create(table: "players") { t in
    ///             t.column("id", .integer).primaryKey()
    ///             t.column("name", .text)
    ///             t.column("score", .integer)
    ///         }
    ///
    ///         // 3
    ///         try Player.numberOfSelectedColumns(db)
    ///     }
    public static func numberOfSelectedColumns(_ db: Database) throws -> Int {
        let qualifier = SQLTableQualifier(tableName: databaseTableName, alias: nil)
        return try databaseSelection
            .map { try $0.qualified(by: qualifier).columnCount(db) }
            .reduce(0, +)
    }
}


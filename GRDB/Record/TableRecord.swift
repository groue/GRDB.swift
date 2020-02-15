import Foundation

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
    
    /// The default name of the database table used to build requests.
    ///
    /// - Player -> "player"
    /// - Place -> "place"
    /// - PostalAddress -> "postalAddress"
    /// - HTTPRequest -> "httpRequest"
    /// - TOEFL -> "toefl"
    internal static var defaultDatabaseTableName: String {
        if let cached = defaultDatabaseTableNameCache.object(forKey: "\(Self.self)" as NSString) {
            return cached as String
        }
        let typeName = "\(Self.self)".replacingOccurrences(of: "(.)\\b.*$", with: "$1", options: [.regularExpression])
        let initial = typeName.replacingOccurrences(of: "^([A-Z]+).*$", with: "$1", options: [.regularExpression])
        let tableName: String
        switch initial.count {
        case typeName.count:
            tableName = initial.lowercased()
        case 0:
            tableName = typeName
        case 1:
            tableName = initial.lowercased() + typeName.dropFirst()
        default:
            tableName = initial.dropLast().lowercased() + typeName.dropFirst(initial.count - 1)
        }
        defaultDatabaseTableNameCache.setObject(tableName as NSString, forKey: "\(Self.self)" as NSString)
        return tableName
    }
    
    /// The default name of the database table used to build requests.
    ///
    /// - Player -> "player"
    /// - Place -> "place"
    /// - PostalAddress -> "postalAddress"
    /// - HTTPRequest -> "httpRequest"
    /// - TOEFL -> "toefl"
    public static var databaseTableName: String {
        return defaultDatabaseTableName
    }
    
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
        var context = SQLGenerationContext.selectionContext
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

/// Calculating `defaultDatabaseTableName` is somewhat expensive due to the regular expression evaluation
///
/// This cache mitigates the cost of the calculation by storing the name for later retrieval
private let defaultDatabaseTableNameCache = NSCache<NSString, NSString>()

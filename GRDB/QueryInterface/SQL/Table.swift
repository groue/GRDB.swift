/// A `Table` builds database queries with the Swift language instead of SQL.
///
/// ## Overview
///
/// A `Table` instance is similar to a ``TableRecord`` type. You will use one
/// when the other is impractical or impossible to use.
///
/// For example:
///
/// ```swift
/// let table = Table("player")
/// try dbQueue.read { db in
///     // SELECT * FROM player WHERE score >= 1000
///     let rows: [Row] = table.filter(Column("score") >= 1000).fetchAll(db)
/// }
/// ```
///
/// ## Topics
///
/// ### Creating a Table
///
/// - ``init(_:)-2iz5y``
/// - ``init(_:)-3mfb8``
///
/// ### Instance Properties
///
/// - ``tableName``
/// 
/// ### Counting Rows
///
/// - ``fetchCount(_:)``
///
/// ### Testing for Row Existence
///
/// - ``exists(_:id:)``
/// - ``exists(_:key:)-4dk7e``
/// - ``exists(_:key:)-36jtu``
///
/// ### Deleting Rows
///
/// - ``deleteAll(_:)``
/// - ``deleteAll(_:ids:)``
/// - ``deleteAll(_:keys:)-5t865``
/// - ``deleteAll(_:keys:)-28sff``
/// - ``deleteOne(_:id:)``
/// - ``deleteOne(_:key:)-404su``
/// - ``deleteOne(_:key:)-64wmq``
///
/// ### Updating Rows
///
/// - ``updateAll(_:onConflict:_:)-4w9b``
/// - ``updateAll(_:onConflict:_:)-4cvap``
///
/// ### Building Query Interface Requests
///
/// `Table` provide convenience access to most ``DerivableRequest`` and
/// ``QueryInterfaceRequest`` methods.
///
/// - ``aliased(_:)``
/// - ``all()``
/// - ``annotated(with:)-6i101``
/// - ``annotated(with:)-6x399``
/// - ``annotated(with:)-4sbgw``
/// - ``annotated(with:)-98t4p``
/// - ``annotated(withOptional:)``
/// - ``annotated(withRequired:)``
/// - ``filter(_:)``
/// - ``filter(id:)``
/// - ``filter(ids:)``
/// - ``filter(key:)-tw3i``
/// - ``filter(key:)-4sun7``
/// - ``filter(keys:)-85e0v``
/// - ``filter(keys:)-qqgf``
/// - ``filter(literal:)``
/// - ``filter(sql:arguments:)``
/// - ``having(_:)``
/// - ``including(all:)``
/// - ``including(optional:)``
/// - ``including(required:)``
/// - ``joining(optional:)``
/// - ``joining(required:)``
/// - ``limit(_:offset:)``
/// - ``none()``
/// - ``order(_:)-2gvi7``
/// - ``order(_:)-9o5bb``
/// - ``order(literal:)``
/// - ``order(sql:arguments:)``
/// - ``orderByPrimaryKey()``
/// - ``select(_:)-1599q``
/// - ``select(_:)-2cnd1``
/// - ``select(_:as:)-20ci9``
/// - ``select(_:as:)-3pr6x``
/// - ``select(literal:)``
/// - ``select(literal:as:)``
/// - ``select(sql:arguments:)``
/// - ``select(sql:arguments:as:)``
/// - ``selectPrimaryKey(as:)``
/// - ``with(_:)``
///
/// ### Defining Associations
///
/// - ``association(to:)``
/// - ``association(to:on:)``
/// - ``belongsTo(_:key:using:)-8p5xr``
/// - ``belongsTo(_:key:using:)-117wr``
/// - ``hasMany(_:key:using:)-3i6yk``
/// - ``hasMany(_:key:using:)-57dwf``
/// - ``hasMany(_:through:using:key:)``
/// - ``hasOne(_:key:using:)-81vqy``
/// - ``hasOne(_:key:using:)-3438j``
/// - ``hasOne(_:through:using:key:)``
///
/// ### Fetching Database Rows
///
/// - ``fetchCursor(_:)-1oqex``
/// - ``fetchAll(_:)-4s7yn``
/// - ``fetchSet(_:)-5lp4s``
/// - ``fetchOne(_:)-3bduz``
///
/// ### Fetching Database Values
///
/// - ``fetchCursor(_:)-65lci``
/// - ``fetchCursor(_:)-295uw``
/// - ``fetchAll(_:)-6xr01``
/// - ``fetchAll(_:)-7tjdp``
/// - ``fetchSet(_:)-3mchk``
/// - ``fetchSet(_:)-8k2uk``
/// - ``fetchOne(_:)-infc``
/// - ``fetchOne(_:)-71icb``
///
/// ### Fetching Records
///
/// - ``fetchCursor(_:)-81wuu``
/// - ``fetchAll(_:)-3l7ol``
/// - ``fetchSet(_:)-ko77``
/// - ``fetchOne(_:)-8n1q``
///
/// ### Database Observation Support
///
/// - ``databaseRegion(_:)``
public struct Table<RowDecoder> {
    /// The table name.
    public var tableName: String
    
    private init(_ tableName: String, _ type: RowDecoder.Type) {
        self.tableName = tableName
    }
    
    /// Creates a `Table`.
    ///
    /// For example:
    ///
    /// ```swift
    /// let table = Table<Row>("player")
    /// let table = Table<Player>("player")
    /// ```
    public init(_ tableName: String) {
        self.init(tableName, RowDecoder.self)
    }
}

extension Table where RowDecoder == Row {
    /// Create a `Table<Row>`.
    ///
    /// For example:
    ///
    /// ```swift
    /// let table = Table("player") // Table<Row>
    /// ```
    public init(_ tableName: String) {
        self.init(tableName, Row.self)
    }
}

extension Table: DatabaseRegionConvertible {
    public func databaseRegion(_ db: Database) throws -> DatabaseRegion {
        DatabaseRegion(table: tableName)
    }
}

// MARK: Request Derivation

extension Table {
    var relationForAll: SQLRelation {
        .all(fromTable: tableName)
    }
    
    /// Returns a request for all rows of the table.
    ///
    /// ```swift
    /// // Fetch all players
    /// let table = Table<Player>("player")
    /// let request = table.all()
    /// let players: [Player] = try request.fetchAll(db)
    /// ```
    public func all() -> QueryInterfaceRequest<RowDecoder> {
        QueryInterfaceRequest(relation: relationForAll)
    }
    
    /// Returns an empty request that fetches no row.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let request = Table("player").none()
    ///     let rows = try request.fetchAll(db) // empty array
    /// }
    public func none() -> QueryInterfaceRequest<RowDecoder> {
        all().none() // don't laugh
    }
    
    /// Returns a request that selects the provided result columns.
    ///
    /// For example:
    ///
    /// ```swift
    /// let playerTable = Table("player")
    ///
    /// // SELECT id, score FROM player
    /// let request = playerTable.select(Column("id"), Column("score"))
    /// ```
    public func select(_ selection: any SQLSelectable...) -> QueryInterfaceRequest<RowDecoder> {
        all().select(selection)
    }
    
    /// Returns a request that selects the provided result columns.
    ///
    /// For example:
    ///
    /// ```swift
    /// let playerTable = Table("player")
    ///
    /// // SELECT id, score FROM player
    /// let request = playerTable.select([Column("id"), Column("score")])
    /// ```
    public func select(_ selection: [any SQLSelectable]) -> QueryInterfaceRequest<RowDecoder> {
        all().select(selection)
    }
    
    /// Returns a request that selects the provided SQL string.
    ///
    /// For example:
    ///
    /// ```swift
    /// let playerTable = Table("player")
    ///
    /// // SELECT id, name FROM player
    /// let request = playerTable.select(sql: "id, name")
    ///
    /// // SELECT id, IFNULL(name, 'Anonymous') FROM player
    /// let defaultName = "Anonymous"
    /// let request = playerTable.select(sql: "id, IFNULL(name, ?)", arguments: [defaultName])
    /// ```
    public func select(
        sql: String,
        arguments: StatementArguments = StatementArguments())
    -> QueryInterfaceRequest<RowDecoder>
    {
        all().select(SQL(sql: sql, arguments: arguments))
    }
    
    /// Returns a request that selects the provided ``SQL`` literal.
    ///
    /// ``SQL`` literals allow you to safely embed raw values in your SQL,
    /// without any risk of syntax errors or SQL injection:
    ///
    /// ```swift
    /// let playerTable = Table("player")
    ///
    /// // SELECT id, IFNULL(name, 'Anonymous') FROM player
    /// let defaultName = "Anonymous"
    /// let request = playerTable.select(literal: "id, IFNULL(name, \(defaultName))")
    /// ```
    public func select(literal sqlLiteral: SQL) -> QueryInterfaceRequest<RowDecoder> {
        all().select(sqlLiteral)
    }
    
    /// Returns a request that selects the provided result columns, and defines
    /// the type of decoded rows.
    ///
    /// For example:
    ///
    /// ```swift
    /// let playerTable = Table("player")
    ///
    /// let minScore = min(Column("score"))
    /// let maxScore = max(Column("score"))
    ///
    /// // SELECT MAX(score) FROM player
    /// let request = playerTable.select([maxScore], as: Int.self)
    /// let maxScore = try request.fetchOne(db) // Int?
    ///
    /// // SELECT MIN(score), MAX(score) FROM player
    /// let request = playerTable.select([minScore, maxScore], as: Row.self)
    /// if let row = try request.fetchOne(db) {
    ///     let minScore: Int = row[0]
    ///     let maxScore: Int = row[1]
    /// }
    /// ```
    public func select<T>(
        _ selection: [any SQLSelectable],
        as type: T.Type = T.self)
    -> QueryInterfaceRequest<T>
    {
        all().select(selection, as: type)
    }
    
    /// Returns a request that selects the provided result columns, and defines
    /// the type of decoded rows.
    ///
    /// For example:
    ///
    /// ```swift
    /// let playerTable = Table("player")
    ///
    /// let minScore = min(Column("score"))
    /// let maxScore = max(Column("score"))
    ///
    /// // SELECT MAX(score) FROM player
    /// let request = playerTable.select(maxScore, as: Int.self)
    /// let maxScore = try request.fetchOne(db) // Int?
    ///
    /// // SELECT MIN(score), MAX(score) FROM player
    /// let request = playerTable.select(minScore, maxScore, as: Row.self)
    /// if let row = try request.fetchOne(db) {
    ///     let minScore: Int = row[0]
    ///     let maxScore: Int = row[1]
    /// }
    /// ```
    public func select<T>(
        _ selection: any SQLSelectable...,
        as type: T.Type = T.self)
    -> QueryInterfaceRequest<T>
    {
        all().select(selection, as: type)
    }
    
    /// Returns a request that selects the provided SQL string, and defines the
    /// type of decoded rows.
    ///
    /// For example:
    ///
    /// ```swift
    /// let playerTable = Table("player")
    ///
    /// // SELECT name FROM player
    /// let request = playerTable.select(sql: "name", as: String.self)
    /// let names = try request.fetchAll(db) // [String]
    ///
    /// // SELECT IFNULL(name, 'Anonymous') FROM player
    /// let defaultName = "Anonymous"
    /// let request = playerTable.select(sql: "IFNULL(name, ?)", arguments: [defaultName], as: String.self)
    /// let names = try request.fetchAll(db) // [String]
    /// ```
    public func select<T>(
        sql: String,
        arguments: StatementArguments = StatementArguments(),
        as type: T.Type = T.self)
    -> QueryInterfaceRequest<T>
    {
        all().select(SQL(sql: sql, arguments: arguments), as: type)
    }
    
    /// Returns a request that selects the provided ``SQL`` literal, and defines
    /// the type of decoded rows.
    ///
    /// ``SQL`` literals allow you to safely embed raw values in your SQL,
    /// without any risk of syntax errors or SQL injection:
    ///
    /// ```swift
    /// let playerTable = Table("player")
    ///
    /// // SELECT IFNULL(name, 'Anonymous') FROM player
    /// let defaultName = "Anonymous"
    /// let request = playerTable.select(literal: "IFNULL(name, \(defaultName))", as: String.self)
    /// let names = try request.fetchAll(db) // [String]
    /// ```
    public func select<T>(
        literal sqlLiteral: SQL,
        as type: T.Type = T.self)
    -> QueryInterfaceRequest<T>
    {
        all().select(sqlLiteral, as: type)
    }
    
    /// Returns a request that selects the primary key.
    ///
    /// All primary keys are supported:
    ///
    /// ```swift
    /// let playerTable = Table("player")
    /// let countryTable = Table("country")
    /// let citizenshipTable = Table("citizenship")
    ///
    /// // SELECT id FROM player WHERE ...
    /// let request = try playerTable.selectPrimaryKey(as: Int64.self)
    /// let ids = try request.fetchAll(db) // [Int64]
    ///
    /// // SELECT code FROM country WHERE ...
    /// let request = try countryTable.selectPrimaryKey(as: String.self)
    /// let countryCodes = try request.fetchAll(db) // [String]
    ///
    /// // SELECT citizenId, countryCode FROM citizenship WHERE ...
    /// let request = try citizenshipTable.selectPrimaryKey(as: Row.self)
    /// let rows = try request.fetchAll(db) // [Row]
    /// ```
    ///
    /// For composite primary keys, you can define a ``FetchableRecord`` type:
    ///
    /// ```swift
    /// extension Citizenship {
    ///     struct ID: Decodable, FetchableRecord {
    ///         var citizenId: Int64
    ///         var countryCode: String
    ///     }
    /// }
    /// let request = try citizenshipTable.selectPrimaryKey(as: Citizenship.ID.self)
    /// let ids = try request.fetchAll(db) // [Citizenship.ID]
    /// ```
    public func selectPrimaryKey<PrimaryKey>(as type: PrimaryKey.Type = PrimaryKey.self)
    -> QueryInterfaceRequest<PrimaryKey>
    {
        all().selectPrimaryKey(as: type)
    }
    
    /// Returns a request with the provided result columns appended to the
    /// table columns.
    ///
    /// For example:
    ///
    /// ```swift
    /// let playerTable = Table("player")
    ///
    /// // SELECT *, score + bonus AS totalScore FROM player
    /// let totalScore = (Column("score") + Column("bonus")).forKey("totalScore")
    /// let request = playerTable.annotated(with: [totalScore])
    /// ```
    public func annotated(with selection: [any SQLSelectable]) -> QueryInterfaceRequest<RowDecoder> {
        all().annotated(with: selection)
    }
    
    /// Returns a request with the provided result columns appended to the
    /// table columns.
    ///
    /// For example:
    ///
    /// ```swift
    /// let playerTable = Table("player")
    ///
    /// // SELECT *, score + bonus AS totalScore FROM player
    /// let totalScore = (Column("score") + Column("bonus")).forKey("totalScore")
    /// let request = playerTable.annotated(with: totalScore)
    /// ```
    public func annotated(with selection: any SQLSelectable...) -> QueryInterfaceRequest<RowDecoder> {
        all().annotated(with: selection)
    }
    
    /// Returns a request filtered with a boolean SQL expression.
    ///
    /// For example:
    ///
    /// ```swift
    /// let playerTable = Table("player")
    ///
    /// // SELECT * FROM player WHERE name = 'O''Brien'
    /// let name = "O'Brien"
    /// let request = playerTable.filter(Column("name") == name)
    /// ```
    public func filter(_ predicate: some SQLSpecificExpressible) -> QueryInterfaceRequest<RowDecoder> {
        all().filter(predicate)
    }
    
    /// Returns a request filtered by primary key.
    ///
    /// All single-column primary keys are supported:
    ///
    /// ```swift
    /// let playerTable = Table("player")
    /// let countryTable = Table("country")
    ///
    /// // SELECT * FROM player WHERE id = 1
    /// let request = playerTable.filter(key: 1)
    ///
    /// // SELECT * FROM country WHERE code = 'FR'
    /// let request = countryTable.filter(key: "FR")
    /// ```
    ///
    /// - parameter key: A primary key
    public func filter(key: some DatabaseValueConvertible) -> QueryInterfaceRequest<RowDecoder> {
        all().filter(key: key)
    }
    
    /// Returns a request filtered by primary key.
    ///
    /// All single-column primary keys are supported:
    ///
    /// ```swift
    /// let playerTable = Table("player")
    /// let countryTable = Table("country")
    ///
    /// // SELECT * FROM player WHERE id = IN (1, 2, 3)
    /// let request = playerTable.filter(keys: [1, 2, 3])
    ///
    /// // SELECT * FROM country WHERE code = IN ('FR', 'US')
    /// let request = countryTable.filter(keys: ["FR", "US"])
    /// ```
    ///
    /// - parameter keys: A collection of primary keys
    public func filter<Keys>(keys: Keys)
    -> QueryInterfaceRequest<RowDecoder>
    where Keys: Sequence, Keys.Element: DatabaseValueConvertible
    {
        all().filter(keys: keys)
    }
    
    /// Returns a request filtered by primary or unique key.
    ///
    /// For example:
    ///
    /// ```swift
    /// let playerTable = Table("player")
    /// let citizenshipTable = Table("citizenship")
    ///
    /// // SELECT * FROM player WHERE id = 1
    /// let request = playerTable.filter(key: ["id": 1])
    ///
    /// // SELECT * FROM player WHERE email = 'arthur@example.com'
    /// let request = playerTable.filter(key: ["email": "arthur@example.com"])
    ///
    /// // SELECT * FROM citizenship WHERE citizenId = 1 AND countryCode = 'FR'
    /// let request = citizenshipTable.filter(key: [
    ///     "citizenId": 1,
    ///     "countryCode": "FR",
    /// ])
    /// ```
    ///
    /// When executed, this request raises a fatal error if no unique index
    /// exists on a subset of the key columns.
    ///
    /// - parameter key: A key dictionary.
    public func filter(key: [String: (any DatabaseValueConvertible)?]?) -> QueryInterfaceRequest<RowDecoder> {
        all().filter(key: key)
    }
    
    /// Returns a request filtered by primary or unique key.
    ///
    /// For example:
    ///
    /// ```swift
    /// let playerTable = Table("player")
    /// let citizenshipTable = Table("citizenship")
    ///
    /// // SELECT * FROM player WHERE id = 1
    /// let request = playerTable.filter(keys: [["id": 1]])
    ///
    /// // SELECT * FROM player WHERE email = 'arthur@example.com'
    /// let request = playerTable.filter(keys: [["email": "arthur@example.com"]])
    ///
    /// // SELECT * FROM citizenship WHERE citizenId = 1 AND countryCode = 'FR'
    /// let request = citizenshipTable.filter(keys: [
    ///     ["citizenId": 1, "countryCode": "FR"],
    /// ])
    /// ```
    ///
    /// When executed, this request raises a fatal error if no unique index
    /// exists on a subset of the key columns.
    ///
    /// - parameter keys: An array of key dictionaries.
    public func filter(keys: [[String: (any DatabaseValueConvertible)?]]) -> QueryInterfaceRequest<RowDecoder> {
        all().filter(keys: keys)
    }
    
    /// Returns a request filtered with an SQL string.
    ///
    /// For example:
    ///
    /// ```swift
    /// let playerTable = Table("player")
    ///
    /// // SELECT * FROM player WHERE name = 'O''Brien'
    /// let name = "O'Brien"
    /// let request = playerTable.filter(sql: "name = ?", arguments: [name])
    /// ```
    public func filter(
        sql: String,
        arguments: StatementArguments = StatementArguments())
    -> QueryInterfaceRequest<RowDecoder>
    {
        filter(SQL(sql: sql, arguments: arguments))
    }
    
    /// Returns a request filtered with an ``SQL`` literal.
    ///
    /// ``SQL`` literals allow you to safely embed raw values in your SQL,
    /// without any risk of syntax errors or SQL injection:
    ///
    /// ```swift
    /// let playerTable = Table("player")
    ///
    /// // SELECT * FROM player WHERE name = 'O''Brien'
    /// let name = "O'Brien"
    /// let request = playerTable.filter(literal: "name = \(name)")
    /// ```
    public func filter(literal sqlLiteral: SQL) -> QueryInterfaceRequest<RowDecoder> {
        all().filter(sqlLiteral)
    }
    
    /// Returns a request sorted according to the given SQL ordering terms.
    ///
    /// For example:
    ///
    /// ```swift
    /// let playerTable = Table("player")
    ///
    /// // SELECT * FROM player ORDER BY score DESC, name
    /// let request = playerTable.order(Column("score").desc, Column("name"))
    /// ```
    public func order(_ orderings: any SQLOrderingTerm...) -> QueryInterfaceRequest<RowDecoder> {
        all().order(orderings)
    }
    
    /// Returns a request sorted according to the given SQL ordering terms.
    ///
    /// For example:
    ///
    /// ```swift
    /// let playerTable = Table("player")
    ///
    /// // SELECT * FROM player ORDER BY score DESC, name
    /// let request = playerTable.order([Column("score").desc, Column("name")])
    /// ```
    public func order(_ orderings: [any SQLOrderingTerm]) -> QueryInterfaceRequest<RowDecoder> {
        all().order(orderings)
    }
    
    /// Returns a request sorted by primary key.
    ///
    /// All primary keys are supported:
    ///
    /// ```swift
    /// let playerTable = Table("player")
    /// let countryTable = Table("country")
    /// let citizenshipTable = Table("citizenship")
    ///
    /// // SELECT * FROM player ORDER BY id
    /// let request = playerTable.orderByPrimaryKey()
    ///
    /// // SELECT * FROM country ORDER BY code
    /// let request = countryTable.orderByPrimaryKey()
    ///
    /// // SELECT * FROM citizenship ORDER BY citizenId, countryCode
    /// let request = citizenshipTable.orderByPrimaryKey()
    /// ```
    public func orderByPrimaryKey() -> QueryInterfaceRequest<RowDecoder> {
        all().orderByPrimaryKey()
    }
    
    /// Returns a request sorted according to the given SQL string.
    ///
    /// For example:
    ///
    /// ```swift
    /// let playerTable = Table("player")
    ///
    /// // SELECT * FROM player ORDER BY score DESC, name
    /// let request = playerTable.order(sql: "score DESC, name")
    /// ```
    public func order(
        sql: String,
        arguments: StatementArguments = StatementArguments())
    -> QueryInterfaceRequest<RowDecoder>
    {
        all().order(SQL(sql: sql, arguments: arguments))
    }
    
    /// Returns a request sorted according to the given ``SQL`` literal.
    ///
    /// For example:
    ///
    /// ```swift
    /// let playerTable = Table("player")
    ///
    /// // SELECT * FROM player ORDER BY score DESC, name
    /// let request = playerTable.order(literal: "score DESC, name")
    /// ```
    public func order(literal sqlLiteral: SQL) -> QueryInterfaceRequest<RowDecoder> {
        all().order(sqlLiteral)
    }
    
    /// Returns a limited request.
    ///
    /// The returned request fetches `limit` rows, starting at `offset`. For
    /// example:
    ///
    /// ```swift
    /// let playerTable = Table("player")
    ///
    /// // SELECT * FROM player LIMIT 10
    /// let request = playerTable.limit(10)
    ///
    /// // SELECT * FROM player LIMIT 10 OFFSET 20
    /// let request = playerTable.limit(10, offset: 20)
    /// ```
    public func limit(_ limit: Int, offset: Int? = nil) -> QueryInterfaceRequest<RowDecoder> {
        all().limit(limit, offset: offset)
    }
    
    /// Returns a request that can be referred to with the provided alias.
    ///
    /// `table.aliased(alias)` is equivalent to `table.all().aliased(alias)`.
    /// See ``TableRequest/aliased(_:)`` for more information.
    public func aliased(_ alias: TableAlias) -> QueryInterfaceRequest<RowDecoder> {
        all().aliased(alias)
    }
    
    /// Returns a request that embeds a common table expression.
    ///
    /// `table.with(cte)` is equivalent to `table.all().with(cte)`.
    /// See ``DerivableRequest/with(_:)`` for more information.
    public func with<T>(_ cte: CommonTableExpression<T>) -> QueryInterfaceRequest<RowDecoder> {
        all().with(cte)
    }
}

@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
extension Table where RowDecoder: Identifiable, RowDecoder.ID: DatabaseValueConvertible {
    /// Returns a request filtered by primary key.
    ///
    /// All single-column primary keys are supported:
    ///
    /// ```swift
    /// struct Player: Identifiable {
    ///     var id: Int64
    /// }
    /// struct Country: Identifiable {
    ///     var id: String
    /// }
    ///
    /// let playerTable = Table<Player>("player")
    /// let countryTable = Table<Country>("country")
    ///
    /// // SELECT * FROM player WHERE id = 1
    /// let request = playerTable.filter(id: 1)
    ///
    /// // SELECT * FROM country WHERE code = 'FR'
    /// let request = countryTable.filter(id: "FR")
    /// ```
    ///
    /// - parameter id: A primary key
    public func filter(id: RowDecoder.ID) -> QueryInterfaceRequest<RowDecoder> {
        all().filter(id: id)
    }

    /// Returns a request filtered by primary key.
    ///
    /// All single-column primary keys are supported:
    ///
    /// ```swift
    /// struct Player: Identifiable {
    ///     var id: Int64
    /// }
    /// struct Country: Identifiable {
    ///     var id: String
    /// }
    ///
    /// let playerTable = Table<Player>("player")
    /// let countryTable = Table<Country>("country")
    ///
    /// // SELECT * FROM player WHERE id = IN (1, 2, 3)
    /// let request = playerTable.filter(ids: [1, 2, 3])
    ///
    /// // SELECT * FROM country WHERE code = IN ('FR', 'US')
    /// let request = countryTable.filter(ids: ["FR", "US"])
    /// ```
    ///
    /// - parameter ids: A collection of primary keys
    public func filter<IDS>(ids: IDS) -> QueryInterfaceRequest<RowDecoder>
    where IDS: Collection, IDS.Element == RowDecoder.ID
    {
        all().filter(ids: ids)
    }
}

extension Table {

    // MARK: - Counting All

    /// Returns the number of rows in the database table.
    ///
    /// For example:
    ///
    /// ```swift
    /// let playerTable = Table("player")
    ///
    /// try dbQueue.read { db in
    ///     // SELECT COUNT(*) FROM player
    ///     let count = try playerTable.fetchCount(db)
    /// }
    /// ```
    ///
    /// - parameter db: A database connection.
    public func fetchCount(_ db: Database) throws -> Int {
        try all().fetchCount(db)
    }
}

// MARK: - Fetching Records from Table

extension Table where RowDecoder: FetchableRecord {
    /// Returns a cursor over all records fetched from the database.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: FetchableRecord { }
    /// let playerTable = Table<Player>("player")
    ///
    /// try dbQueue.read { db in
    ///     // SELECT * FROM player
    ///     let players = try playerTable.fetchCursor(db)
    ///     while let player = try players.next() {
    ///         print(player.name)
    ///     }
    /// }
    /// ```
    ///
    /// The order in which the records are returned is undefined
    /// ([ref](https://www.sqlite.org/lang_select.html#the_order_by_clause)).
    ///
    /// The returned cursor is valid only during the remaining execution of the
    /// database access. Do not store or return the cursor for later use.
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// - parameter db: A database connection.
    /// - returns: A ``RecordCursor`` over fetched records.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func fetchCursor(_ db: Database) throws -> RecordCursor<RowDecoder> {
        try all().fetchCursor(db)
    }

    /// Returns an array of all records fetched from the database.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: FetchableRecord { }
    /// let playerTable = Table<Player>("player")
    ///
    /// try dbQueue.read { db in
    ///     // SELECT * FROM player
    ///     let players = try playerTable.fetchAll(db)
    /// }
    /// ```
    ///
    /// The order in which the records are returned is undefined
    /// ([ref](https://www.sqlite.org/lang_select.html#the_order_by_clause)).
    ///
    /// - parameter db: A database connection.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func fetchAll(_ db: Database) throws -> [RowDecoder] {
        try all().fetchAll(db)
    }

    /// Returns a single record fetched from the database.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: FetchableRecord { }
    /// let playerTable = Table<Player>("player")
    ///
    /// try dbQueue.read { db in
    ///     // SELECT * FROM player LIMIT 1
    ///     let player = try playerTable.fetchOne(db)
    /// }
    /// ```
    ///
    /// - parameter db: A database connection.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func fetchOne(_ db: Database) throws -> RowDecoder? {
        try all().fetchOne(db)
    }
}

extension Table where RowDecoder: FetchableRecord & Hashable {
    /// Returns a set of all records fetched from the database.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: FetchableRecord, Hashable { }
    /// let playerTable = Table<Player>("player")
    ///
    /// try dbQueue.read { db in
    ///     // SELECT * FROM player
    ///     let players = try playerTable.fetchSet(db)
    /// }
    /// ```
    ///
    /// - parameter db: A database connection.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func fetchSet(_ db: Database) throws -> Set<RowDecoder> {
        try all().fetchSet(db)
    }
}

// MARK: - Fetching Rows from Table

extension Table where RowDecoder == Row {
    /// Returns a cursor over all rows fetched from the database.
    ///
    /// For example:
    ///
    /// ```swift
    /// let playerTable = Table("player")
    ///
    /// try dbQueue.read { db in
    ///     // SELECT * FROM player
    ///     let rows = try playerTable.fetchCursor(db)
    ///     while let row = try rows.next() {
    ///         let id: Int64 = row["id"]
    ///         let name: String = row["name"]
    ///     }
    /// }
    /// ```
    ///
    /// The order in which the rows are returned is undefined
    /// ([ref](https://www.sqlite.org/lang_select.html#the_order_by_clause)).
    ///
    /// The returned cursor is valid only during the remaining execution of the
    /// database access. Do not store or return the cursor for later use.
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// - parameter db: A database connection.
    /// - returns: A ``RowCursor`` over fetched rows.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func fetchCursor(_ db: Database) throws -> RowCursor {
        try all().fetchCursor(db)
    }

    /// Returns an array of all rows fetched from the database.
    ///
    /// For example:
    ///
    /// ```swift
    /// let playerTable = Table("player")
    ///
    /// try dbQueue.read { db in
    ///     // SELECT * FROM player
    ///     let rows = try playerTable.fetchAll(db)
    /// }
    /// ```
    ///
    /// The order in which the rows are returned is undefined
    /// ([ref](https://www.sqlite.org/lang_select.html#the_order_by_clause)).
    ///
    /// - parameter db: A database connection.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func fetchAll(_ db: Database) throws -> [Row] {
        try all().fetchAll(db)
    }

    /// Returns a single row fetched from the database.
    ///
    /// For example:
    ///
    /// ```swift
    /// let playerTable = Table("player")
    ///
    /// try dbQueue.read { db in
    ///     // SELECT * FROM player LIMIT 1
    ///     let row = try playerTable.fetchOne(db)
    /// }
    /// ```
    ///
    /// - parameter db: A database connection.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func fetchOne(_ db: Database) throws -> Row? {
        try all().fetchOne(db)
    }

    /// Returns a set of all rows fetched from the database.
    ///
    /// For example:
    ///
    /// ```swift
    /// let playerTable = Table("player")
    ///
    /// try dbQueue.read { db in
    ///     // SELECT * FROM player
    ///     let rows = try playerTable.fetchSet(db)
    /// }
    /// ```
    ///
    /// - parameter db: A database connection.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func fetchSet(_ db: Database) throws -> Set<Row> {
        try all().fetchSet(db)
    }
}

// MARK: - Fetching Values from Table

extension Table where RowDecoder: DatabaseValueConvertible {
    /// Returns a cursor over fetched values.
    ///
    /// The order in which the values are returned is undefined
    /// ([ref](https://www.sqlite.org/lang_select.html#the_order_by_clause)).
    ///
    /// Values are decoded from the leftmost column.
    ///
    /// The returned cursor is valid only during the remaining execution of the
    /// database access. Do not store or return the cursor for later use.
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// - parameter db: A database connection.
    /// - returns: A ``DatabaseValueCursor`` over fetched values.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func fetchCursor(_ db: Database) throws -> DatabaseValueCursor<RowDecoder> {
        try all().fetchCursor(db)
    }

    /// Returns an array of fetched values.
    ///
    /// Values are decoded from the leftmost column.
    ///
    /// - parameter db: A database connection.
    /// - returns: An array of values.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func fetchAll(_ db: Database) throws -> [RowDecoder] {
        try all().fetchAll(db)
    }

    /// Returns a single fetched value.
    ///
    /// The value is decoded from the leftmost column.
    ///
    /// The result is nil if the request returns no row, or one row with a
    /// `NULL` value.
    ///
    /// - parameter db: A database connection.
    /// - returns: An optional value.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func fetchOne(_ db: Database) throws -> RowDecoder? {
        try all().fetchOne(db)
    }
}

extension Table where RowDecoder: DatabaseValueConvertible & Hashable {
    /// Returns a set of fetched values.
    ///
    /// Values are decoded from the leftmost column.
    ///
    /// - parameter db: A database connection.
    /// - returns: A set of values.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func fetchSet(_ db: Database) throws -> Set<RowDecoder> {
        try all().fetchSet(db)
    }
}

// MARK: - Fetching Fast Values from Table

extension Table where RowDecoder: DatabaseValueConvertible & StatementColumnConvertible {
    /// Returns a cursor over fetched values.
    ///
    /// The order in which the values are returned is undefined
    /// ([ref](https://www.sqlite.org/lang_select.html#the_order_by_clause)).
    ///
    /// Values are decoded from the leftmost column.
    ///
    /// The returned cursor is valid only during the remaining execution of the
    /// database access. Do not store or return the cursor for later use.
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// - parameter db: A database connection.
    /// - returns: A ``FastDatabaseValueCursor`` over fetched values.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func fetchCursor(_ db: Database) throws -> FastDatabaseValueCursor<RowDecoder> {
        try all().fetchCursor(db)
    }

    /// Returns an array of fetched values.
    ///
    /// Values are decoded from the leftmost column.
    ///
    /// - parameter db: A database connection.
    /// - returns: An array of values.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func fetchAll(_ db: Database) throws -> [RowDecoder] {
        try all().fetchAll(db)
    }

    /// Returns a single fetched value.
    ///
    /// The value is decoded from the leftmost column.
    ///
    /// The result is nil if the request returns no row, or one row with a
    /// `NULL` value.
    ///
    /// - parameter db: A database connection.
    /// - returns: An optional value.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func fetchOne(_ db: Database) throws -> RowDecoder? {
        try all().fetchOne(db)
    }
}

extension Table where RowDecoder: DatabaseValueConvertible & StatementColumnConvertible & Hashable {
    /// Returns a set of fetched values.
    ///
    /// Values are decoded from the leftmost column.
    ///
    /// - parameter db: A database connection.
    /// - returns: A set of values.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func fetchSet(_ db: Database) throws -> Set<RowDecoder> {
        try all().fetchSet(db)
    }
}

// MARK: - Associations to TableRecord

extension Table {
    /// Creates a ``BelongsToAssociation`` between this table and the
    /// destination `TableRecord` type.
    ///
    /// For more information, see ``TableRecord/belongsTo(_:key:using:)-13t5r``.
    ///
    /// - parameters:
    ///     - destination: The record type at the other side of the association.
    ///     - key: The association key. By default, it
    ///       is `Destination.databaseTableName`.
    ///     - foreignKey: An eventual foreign key. You need to provide one when
    ///       no foreign key exists to the destination table, or several foreign
    ///       keys exist.
    public func belongsTo<Destination>(
        _ destination: Destination.Type,
        key: String? = nil,
        using foreignKey: ForeignKey? = nil)
    -> BelongsToAssociation<RowDecoder, Destination>
    where Destination: TableRecord
    {
        BelongsToAssociation(
            to: Destination.relationForAll,
            key: key,
            using: foreignKey)
    }

    /// Creates a ``HasManyAssociation`` between this table and the
    /// destination `TableRecord` type.
    ///
    /// For more information, see ``TableRecord/hasMany(_:key:using:)-45axo``.
    ///
    /// - parameters:
    ///     - destination: The record type at the other side of the association.
    ///     - key: The association key. By default, it
    ///       is `Destination.databaseTableName`.
    ///     - foreignKey: An eventual foreign key. You need to provide one when
    ///       no foreign key exists to the destination table, or several foreign
    ///       keys exist.
    public func hasMany<Destination>(
        _ destination: Destination.Type,
        key: String? = nil,
        using foreignKey: ForeignKey? = nil)
    -> HasManyAssociation<RowDecoder, Destination>
    where Destination: TableRecord
    {
        HasManyAssociation(
            to: Destination.relationForAll,
            key: key,
            using: foreignKey)
    }

    /// Creates a ``HasOneAssociation`` between this table and the
    /// destination `TableRecord` type.
    ///
    /// For more information, see ``TableRecord/hasOne(_:key:using:)-4g9tm``.
    ///
    /// - parameters:
    ///     - destination: The record type at the other side of the association.
    ///     - key: The association key. By default, it
    ///       is `Destination.databaseTableName`.
    ///     - foreignKey: An eventual foreign key. You need to provide one when
    ///       no foreign key exists to the destination table, or several foreign
    ///       keys exist.
    public func hasOne<Destination>(
        _ destination: Destination.Type,
        key: String? = nil,
        using foreignKey: ForeignKey? = nil)
    -> HasOneAssociation<RowDecoder, Destination>
    where Destination: TableRecord
    {
        HasOneAssociation(
            to: Destination.relationForAll,
            key: key,
            using: foreignKey)
    }
}

// MARK: - Associations to Table

extension Table {
    /// Creates a ``BelongsToAssociation`` between this table and the
    /// destination `Table`.
    ///
    /// For more information, see ``TableRecord/belongsTo(_:key:using:)-13t5r``.
    ///
    /// - parameters:
    ///     - destination: The table at the other side of the association.
    ///     - key: The association key. By default, it
    ///       is `destination.tableName`.
    ///     - foreignKey: An eventual foreign key. You need to provide one when
    ///       no foreign key exists to the destination table, or several foreign
    ///       keys exist.
    public func belongsTo<Destination>(
        _ destination: Table<Destination>,
        key: String? = nil,
        using foreignKey: ForeignKey? = nil)
    -> BelongsToAssociation<RowDecoder, Destination>
    {
        BelongsToAssociation(
            to: destination.relationForAll,
            key: key,
            using: foreignKey)
    }

    /// Creates a ``HasManyAssociation`` between this table and the
    /// destination `Table`.
    ///
    /// For more information, see ``TableRecord/hasMany(_:key:using:)-45axo``.
    ///
    /// - parameters:
    ///     - destination: The table at the other side of the association.
    ///     - key: The association key. By default, it
    ///       is `destination.tableName`.
    ///     - foreignKey: An eventual foreign key. You need to provide one when
    ///       no foreign key exists to the destination table, or several foreign
    ///       keys exist.
    public func hasMany<Destination>(
        _ destination: Table<Destination>,
        key: String? = nil,
        using foreignKey: ForeignKey? = nil)
    -> HasManyAssociation<RowDecoder, Destination>
    {
        HasManyAssociation(
            to: destination.relationForAll,
            key: key,
            using: foreignKey)
    }

    /// Creates a ``HasOneAssociation`` between this table and the
    /// destination `Table`.
    ///
    /// For more information, see ``TableRecord/hasOne(_:key:using:)-4g9tm``.
    ///
    /// - parameters:
    ///     - destination: The table at the other side of the association.
    ///     - key: The association key. By default, it
    ///       is `destination.tableName`.
    ///     - foreignKey: An eventual foreign key. You need to provide one when
    ///       no foreign key exists to the destination table, or several foreign
    ///       keys exist.
    public func hasOne<Destination>(
        _ destination: Table<Destination>,
        key: String? = nil,
        using foreignKey: ForeignKey? = nil)
    -> HasOneAssociation<RowDecoder, Destination>
    {
        HasOneAssociation(
            to: destination.relationForAll,
            key: key,
            using: foreignKey)
    }
}

// MARK: - Associations to CommonTableExpression

extension Table {
    /// Creates an association to a common table expression.
    ///
    /// For more information, see ``TableRecord/association(to:on:)``.
    ///
    /// - parameter cte: A common table expression.
    /// - parameter condition: A function that returns the joining clause.
    /// - parameter left: A `TableAlias` for the left table.
    /// - parameter right: A `TableAlias` for the right table.
    /// - returns: An association to the common table expression.
    public func association<Destination>(
        to cte: CommonTableExpression<Destination>,
        on condition: @escaping (_ left: TableAlias, _ right: TableAlias) -> any SQLExpressible)
    -> JoinAssociation<RowDecoder, Destination>
    {
        JoinAssociation(
            to: cte.relationForAll,
            condition: .expression { condition($0, $1).sqlExpression })
    }

    /// Creates an association to a common table expression.
    ///
    /// For more information, see ``TableRecord/association(to:)``.
    ///
    /// - parameter cte: A common table expression.
    /// - returns: An association to the common table expression.
    public func association<Destination>(
        to cte: CommonTableExpression<Destination>)
    -> JoinAssociation<RowDecoder, Destination>
    {
        JoinAssociation(to: cte.relationForAll, condition: .none)
    }
}

// MARK: - "Through" Associations

extension Table {
    /// Creates a ``HasManyThroughAssociation`` between this table and the
    /// destination type.
    ///
    /// For more information, see ``TableRecord/hasMany(_:through:using:key:)``.
    ///
    /// - parameters:
    ///     - destination: The record type at the other side of the association.
    ///     - pivot: An association from `Self` to the intermediate type.
    ///     - target: A target association from the intermediate type to the
    ///       destination type.
    ///     - key: The association key. By default, it is the key of the target.
    public func hasMany<Pivot, Target>(
        _ destination: Target.RowDecoder.Type,
        through pivot: Pivot,
        using target: Target,
        key: String? = nil)
    -> HasManyThroughAssociation<RowDecoder, Target.RowDecoder>
    where Pivot: Association,
          Target: Association,
          Pivot.OriginRowDecoder == RowDecoder,
          Pivot.RowDecoder == Target.OriginRowDecoder
    {
        let association = HasManyThroughAssociation(through: pivot, using: target)

        if let key {
            return association.forKey(key)
        } else {
            return association
        }
    }

    /// Creates a ``HasOneThroughAssociation`` between this table and the
    /// destination type.
    ///
    /// For more information, see ``TableRecord/hasOne(_:through:using:key:)``.
    ///
    /// - parameters:
    ///     - destination: The record type at the other side of the association.
    ///     - pivot: An association from Self to the intermediate type.
    ///     - target: A target association from the intermediate type to the
    ///       destination type.
    ///     - key: An eventual decoding key for the association. By default, it
    ///       is the same key as the target.
    public func hasOne<Pivot, Target>(
        _ destination: Target.RowDecoder.Type,
        through pivot: Pivot,
        using target: Target,
        key: String? = nil)
    -> HasOneThroughAssociation<RowDecoder, Target.RowDecoder>
    where Pivot: AssociationToOne,
          Target: AssociationToOne,
          Pivot.OriginRowDecoder == RowDecoder,
          Pivot.RowDecoder == Target.OriginRowDecoder
    {
        let association = HasOneThroughAssociation(through: pivot, using: target)

        if let key {
            return association.forKey(key)
        } else {
            return association
        }
    }
}

// MARK: - Joining Methods

extension Table {
    /// Returns a request that fetches all rows associated with each row
    /// in this request.
    ///
    /// See the ``TableRecord`` method ``TableRecord/including(all:)``
    /// for more information.
    public func including<A: AssociationToMany>(all association: A)
    -> QueryInterfaceRequest<RowDecoder>
    where A.OriginRowDecoder == RowDecoder
    {
        all().including(all: association)
    }

    /// Returns a request that fetches the eventual row associated with each
    /// row of this request.
    ///
    /// See the ``TableRecord`` method ``TableRecord/including(optional:)``
    /// for more information.
    public func including<A: Association>(optional association: A)
    -> QueryInterfaceRequest<RowDecoder>
    where A.OriginRowDecoder == RowDecoder
    {
        all().including(optional: association)
    }

    /// Returns a request that fetches the row associated with each row in
    /// this request. Rows that do not have an associated row are discarded.
    ///
    /// See the ``TableRecord`` method ``TableRecord/including(required:)``
    /// for more information.
    public func including<A: Association>(required association: A)
    -> QueryInterfaceRequest<RowDecoder>
    where A.OriginRowDecoder == RowDecoder
    {
        all().including(required: association)
    }

    /// Returns a request that joins each row of this request to its
    /// eventual associated row.
    ///
    /// See the ``TableRecord`` method ``TableRecord/including(optional:)``
    /// for more information.
    public func joining<A: Association>(optional association: A)
    -> QueryInterfaceRequest<RowDecoder>
    where A.OriginRowDecoder == RowDecoder
    {
        all().joining(optional: association)
    }

    /// Returns a request that joins each row of this request to its
    /// associated row. Rows that do not have an associated row are discarded.
    ///
    /// See the ``TableRecord`` method ``TableRecord/including(required:)``
    /// for more information.
    public func joining<A: Association>(required association: A)
    -> QueryInterfaceRequest<RowDecoder>
    where A.OriginRowDecoder == RowDecoder
    {
        all().joining(required: association)
    }

    /// Returns a request with the columns of the eventual associated row
    /// appended to the table columns.
    ///
    /// See the ``TableRecord`` method ``TableRecord/annotated(withOptional:)``
    /// for more information.
    public func annotated<A: Association>(withOptional association: A)
    -> QueryInterfaceRequest<RowDecoder>
    where A.OriginRowDecoder == RowDecoder
    {
        all().annotated(withOptional: association)
    }

    /// Returns a request with the columns of the associated row appended to
    /// the table columns. Rows that do not have an associated row
    /// are discarded.
    ///
    /// See the ``TableRecord`` method ``TableRecord/annotated(withRequired:)``
    /// for more information.
    public func annotated<A: Association>(withRequired association: A)
    -> QueryInterfaceRequest<RowDecoder>
    where A.OriginRowDecoder == RowDecoder
    {
        all().annotated(withRequired: association)
    }
}

// MARK: - Association Aggregates

extension Table {
    /// Returns a request with the given association aggregates appended to
    /// the table colums.
    ///
    /// See the ``TableRecord`` method ``TableRecord/annotated(with:)-4xoen``
    /// for more information.
    public func annotated(with aggregates: AssociationAggregate<RowDecoder>...) -> QueryInterfaceRequest<RowDecoder> {
        all().annotated(with: aggregates)
    }

    /// Returns a request with the given association aggregates appended to
    /// the table colums.
    ///
    /// See the ``TableRecord`` method ``TableRecord/annotated(with:)-8ce7u``
    /// for more information.
    public func annotated(with aggregates: [AssociationAggregate<RowDecoder>]) -> QueryInterfaceRequest<RowDecoder> {
        all().annotated(with: aggregates)
    }

    /// Returns a request filtered according to the provided
    /// association aggregate.
    ///
    /// See the ``TableRecord`` method ``TableRecord/having(_:)``
    /// for more information.
    public func having(_ predicate: AssociationAggregate<RowDecoder>) -> QueryInterfaceRequest<RowDecoder> {
        all().having(predicate)
    }
}

// MARK: - Batch Delete

extension Table {
    /// Deletes all rows, and returns the number of deleted rows.
    ///
    /// - parameter db: A database connection.
    /// - returns: The number of deleted rows
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    @discardableResult
    public func deleteAll(_ db: Database) throws -> Int {
        try all().deleteAll(db)
    }
}

// MARK: - Check Existence by Single-Column Primary Key

extension Table {
    /// Returns whether a row exists for this primary key.
    ///
    /// All single-column primary keys are supported:
    ///
    /// ```swift
    /// let playerTable = Table("player")
    /// let countryTable = Table("country")
    ///
    /// try dbQueue.read { db in
    ///     let playerExists = try playerTable.exists(db, key: 1)
    ///     let countryExists = try countryTable.exists(db, key: "FR")
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - key: A primary key value.
    /// - returns: Whether a row exists for this primary key.
    public func exists(_ db: Database, key: some DatabaseValueConvertible) throws -> Bool {
        try !filter(key: key).isEmpty(db)
    }
}

@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
extension Table
where RowDecoder: Identifiable,
      RowDecoder.ID: DatabaseValueConvertible
{
    /// Returns whether a row exists for this primary key.
    ///
    /// All single-column primary keys are supported:
    ///
    /// ```swift
    /// struct Player: Identifiable {
    ///     var id: Int64
    /// }
    /// struct Country: Identifiable {
    ///     var id: String
    /// }
    ///
    /// let playerTable = Table<Player>("player")
    /// let countryTable = Table<Country>("country")
    ///
    /// try dbQueue.read { db in
    ///     let playerExists = try playerTable.exists(db, id: 1)
    ///     let countryExists = try countryTable.exists(db, id: "FR")
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - id: A primary key value.
    /// - returns: Whether a row exists for this primary key.
    public func exists(_ db: Database, id: RowDecoder.ID) throws -> Bool {
        if id.databaseValue.isNull {
            // Don't hit the database
            return false
        }
        return try !filter(id: id).isEmpty(db)
    }
}

// MARK: - Check Existence by Key

extension Table {
    /// Returns whether a row exists for this primary or unique key.
    ///
    /// For example:
    ///
    /// ```swift
    /// let playerTable = Table("player")
    /// let citizenshipTable = Table("citizenship")
    ///
    /// try dbQueue.read { db in
    ///     let playerExists = playerTable.exists(db, key: ["id": 1])
    ///     let playerExists = playerTable.exists(db, key: ["email": "arthur@example.com"])
    ///     let citizenshipExists = citizenshipTable.exists(db, key: [
    ///         "citizenId": 1,
    ///         "countryCode": "FR",
    ///     ])
    /// }
    /// ```
    ///
    /// A fatal error is raised if no unique index exists on a subset of the
    /// key columns.
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - key: A key dictionary.
    /// - returns: Whether a row exists for this key.
    public func exists(_ db: Database, key: [String: (any DatabaseValueConvertible)?]) throws -> Bool {
        try !filter(key: key).isEmpty(db)
    }
}

// MARK: - Deleting by Single-Column Primary Key

extension Table {
    /// Deletes rows identified by their primary keys, and returns the number
    /// of deleted rows.
    ///
    /// All single-column primary keys are supported:
    ///
    /// ```swift
    /// let playerTable = Table("player")
    /// let countryTable = Table("country")
    ///
    /// try dbQueue.write { db in
    ///     // DELETE FROM player WHERE id IN (1, 2, 3)
    ///     try playerTable.deleteAll(db, keys: [1, 2, 3])
    ///
    ///     // DELETE FROM country WHERE code IN ('FR', 'US')
    ///     try countryTable.deleteAll(db, keys: ["FR", "US"])
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - keys: A sequence of primary keys.
    /// - returns: The number of deleted rows.
    @discardableResult
    public func deleteAll<Keys>(_ db: Database, keys: Keys)
    throws -> Int
    where Keys: Sequence, Keys.Element: DatabaseValueConvertible
    {
        let keys = Array(keys)
        if keys.isEmpty {
            // Avoid hitting the database
            return 0
        }
        return try filter(keys: keys).deleteAll(db)
    }

    /// Deletes the row identified by its primary key, and returns whether a
    /// row was deleted.
    ///
    /// All single-column primary keys are supported:
    ///
    /// ```swift
    /// let playerTable = Table("player")
    /// let countryTable = Table("country")
    ///
    /// try dbQueue.write { db in
    ///     // DELETE FROM player WHERE id = 1
    ///     try playerTable.deleteOne(db, key: 1)
    ///
    ///     // DELETE FROM country WHERE code = 'FR'
    ///     try countryTable.deleteOne(db, key: "FR")
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - key: A primary key value.
    /// - returns: Whether a row was deleted.
    @discardableResult
    public func deleteOne(_ db: Database, key: some DatabaseValueConvertible) throws -> Bool {
        if key.databaseValue.isNull {
            // Don't hit the database
            return false
        }
        return try deleteAll(db, keys: [key]) > 0
    }
}

@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
extension Table
where RowDecoder: Identifiable,
      RowDecoder.ID: DatabaseValueConvertible
{
    /// Deletes rows identified by their primary keys, and returns the number
    /// of deleted rows.
    ///
    /// All single-column primary keys are supported:
    ///
    /// ```swift
    /// struct Player: Identifiable {
    ///     var id: Int64
    /// }
    /// struct Country: Identifiable {
    ///     var id: String
    /// }
    ///
    /// let playerTable = Table<Player>("player")
    /// let countryTable = Table<Country>("country")
    ///
    /// try dbQueue.write { db in
    ///     // DELETE FROM player WHERE id IN (1, 2, 3)
    ///     try playerTable.deleteAll(db, ids: [1, 2, 3])
    ///
    ///     // DELETE FROM country WHERE code IN ('FR', 'US')
    ///     try countryTable.deleteAll(db, ids: ["FR", "US"])
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - ids: A collection of primary keys.
    /// - returns: The number of deleted rows.
    @discardableResult
    public func deleteAll<IDS>(_ db: Database, ids: IDS) throws -> Int
    where IDS: Collection, IDS.Element == RowDecoder.ID
    {
        if ids.isEmpty {
            // Avoid hitting the database
            return 0
        }
        return try filter(ids: ids).deleteAll(db)
    }

    /// Deletes the row identified by its primary key, and returns whether a
    /// row was deleted.
    ///
    /// All single-column primary keys are supported:
    ///
    /// ```swift
    /// struct Player: Identifiable {
    ///     var id: Int64
    /// }
    /// struct Country: Identifiable {
    ///     var id: String
    /// }
    ///
    /// let playerTable = Table<Player>("player")
    /// let countryTable = Table<Country>("country")
    ///
    /// try dbQueue.write { db in
    ///     // DELETE FROM player WHERE id = 1
    ///     try playerTable.deleteOne(db, id: 1)
    ///
    ///     // DELETE FROM country WHERE code = 'FR'
    ///     try countryTable.deleteOne(db, id: "FR")
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - id: A primary key value.
    /// - returns: Whether a row was deleted.
    @discardableResult
    public func deleteOne(_ db: Database, id: RowDecoder.ID) throws -> Bool {
        if id.databaseValue.isNull {
            // Don't hit the database
            return false
        }
        return try deleteAll(db, ids: [id]) > 0
    }
}

// MARK: - Deleting by Key

extension Table {
    /// Deletes rows identified by their primary or unique keys, and returns
    /// the number of deleted rows.
    ///
    /// For example:
    ///
    /// ```swift
    /// let playerTable = Table("player")
    /// let citizenshipTable = Table("citizenship")
    ///
    /// try dbQueue.write { db in
    ///     // DELETE FROM player WHERE id = 1
    ///     try playerTable.deleteAll(db, keys: [["id": 1]])
    ///
    ///     // DELETE FROM player WHERE email = 'arthur@example.com'
    ///     try playerTable.deleteAll(db, keys: [["email": "arthur@example.com"]])
    ///
    ///     // DELETE FROM citizenship WHERE citizenId = 1 AND countryCode = 'FR'
    ///     try citizenshipTable.deleteAll(db, keys: [
    ///         ["citizenId": 1, "countryCode": "FR"],
    ///     ])
    /// }
    /// ```
    ///
    /// A fatal error is raised if no unique index exists on a subset of the
    /// key columns.
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - keys: An array of key dictionaries.
    /// - returns: The number of deleted rows.
    @discardableResult
    public func deleteAll(_ db: Database, keys: [[String: (any DatabaseValueConvertible)?]]) throws -> Int {
        if keys.isEmpty {
            // Avoid hitting the database
            return 0
        }
        return try filter(keys: keys).deleteAll(db)
    }

    /// Deletes the row identified by its primary or unique keys, and returns
    /// whether a row was deleted.
    ///
    /// For example:
    ///
    /// ```swift
    /// let playerTable = Table("player")
    /// let citizenshipTable = Table("citizenship")
    ///
    /// try dbQueue.write { db in
    ///     // DELETE FROM player WHERE id = 1
    ///     try playerTable.deleteOne(db, key: ["id": 1])
    ///
    ///     // DELETE FROM player WHERE email = 'arthur@example.com'
    ///     try playerTable.deleteOne(db, key: ["email": "arthur@example.com"])
    ///
    ///     // DELETE FROM citizenship WHERE citizenId = 1 AND countryCode = 'FR'
    ///     try citizenshipTable.deleteOne(db, key: [
    ///         "citizenId": 1,
    ///         "countryCode": "FR",
    ///     ])
    /// }
    /// ```
    ///
    /// A fatal error is raised if no unique index exists on a subset of the
    /// key columns.
    /// - parameters:
    ///     - db: A database connection.
    ///     - key: A key dictionary.
    /// - returns: Whether a row was deleted.
    @discardableResult
    public func deleteOne(_ db: Database, key: [String: (any DatabaseValueConvertible)?]) throws -> Bool {
        try deleteAll(db, keys: [key]) > 0
    }
}

// MARK: - Batch Update

extension Table {
    /// Updates all rows, and returns the number of updated rows.
    ///
    /// For example:
    ///
    /// ```swift
    /// let playerTable = Table("player")
    ///
    /// try dbQueue.write { db in
    ///     // UPDATE player SET score = 0
    ///     try playerTable.updateAll(db, [Column("score").set(to: 0)])
    /// }
    /// ```
    ///
    /// - parameter db: A database connection.
    /// - parameter conflictResolution: A policy for conflict resolution.
    /// - parameter assignments: An array of column assignments.
    /// - returns: The number of updated rows.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    @discardableResult
    public func updateAll(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution? = nil,
        _ assignments: [ColumnAssignment])
    throws -> Int
    {
        try all().updateAll(db, onConflict: conflictResolution, assignments)
    }

    /// Updates all rows, and returns the number of updated rows.
    ///
    /// For example:
    ///
    /// ```swift
    /// let playerTable = Table("player")
    ///
    /// try dbQueue.write { db in
    ///     // UPDATE player SET score = 0
    ///     try playerTable.updateAll(db, Column("score").set(to: 0))
    /// }
    /// ```
    ///
    /// - parameter db: A database connection.
    /// - parameter conflictResolution: A policy for conflict resolution.
    /// - parameter assignments: An array of column assignments.
    /// - returns: The number of updated rows.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    @discardableResult
    public func updateAll(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution? = nil,
        _ assignments: ColumnAssignment...)
    throws -> Int
    {
        try updateAll(db, onConflict: conflictResolution, assignments)
    }
}

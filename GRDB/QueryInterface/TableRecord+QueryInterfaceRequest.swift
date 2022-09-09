extension TableRecord {
    
    // MARK: Request Derivation
    
    static var relationForAll: SQLRelation {
        .all(fromTable: databaseTableName, selection: { _ in databaseSelection.map(\.sqlSelection) })
    }
    
    /// Creates a request which fetches all records.
    ///
    ///     // SELECT * FROM player
    ///     let request = Player.all()
    public static func all() -> QueryInterfaceRequest<Self> {
        QueryInterfaceRequest(relation: relationForAll)
    }
    
    /// Creates a request which fetches no record.
    public static func none() -> QueryInterfaceRequest<Self> {
        all().none() // don't laugh
    }
    
    /// Creates a request which selects *selection*.
    ///
    ///     // SELECT id, email FROM player
    ///     let request = Player.select(Column("id"), Column("email"))
    public static func select(_ selection: any SQLSelectable...) -> QueryInterfaceRequest<Self> {
        all().select(selection)
    }
    
    /// Creates a request which selects *selection*.
    ///
    ///     // SELECT id, email FROM player
    ///     let request = Player.select([Column("id"), Column("email")])
    public static func select(_ selection: [any SQLSelectable]) -> QueryInterfaceRequest<Self> {
        all().select(selection)
    }
    
    /// Creates a request which selects *sql*.
    ///
    ///     // SELECT id, email FROM player
    ///     let request = Player.select(sql: "id, email")
    public static func select(
        sql: String,
        arguments: StatementArguments = StatementArguments())
    -> QueryInterfaceRequest<Self>
    {
        all().select(SQL(sql: sql, arguments: arguments))
    }
    
    /// Creates a request which selects an SQL *literal*.
    ///
    /// Literals allow you to safely embed raw values in your SQL, without any
    /// risk of syntax errors or SQL injection:
    ///
    ///     // SELECT id, email, score + 1000 FROM player
    ///     let bonus = 1000
    ///     let request = Player.select(literal: """
    ///         id, email, score + \(bonus)
    ///         """)
    public static func select(literal sqlLiteral: SQL) -> QueryInterfaceRequest<Self> {
        all().select(sqlLiteral)
    }
    
    /// Creates a request which selects *selection*, and fetches values of
    /// type *type*.
    ///
    ///     try dbQueue.read { db in
    ///         // SELECT max(score) FROM player
    ///         let request = Player.select([max(Column("score"))], as: Int.self)
    ///         let maxScore: Int? = try request.fetchOne(db)
    ///     }
    public static func select<RowDecoder>(
        _ selection: [any SQLSelectable],
        as type: RowDecoder.Type = RowDecoder.self)
    -> QueryInterfaceRequest<RowDecoder>
    {
        all().select(selection, as: type)
    }
    
    /// Creates a request which selects *selection*, and fetches values of
    /// type *type*.
    ///
    ///     try dbQueue.read { db in
    ///         // SELECT max(score) FROM player
    ///         let request = Player.select(max(Column("score")), as: Int.self)
    ///         let maxScore: Int? = try request.fetchOne(db)
    ///     }
    public static func select<RowDecoder>(
        _ selection: any SQLSelectable...,
        as type: RowDecoder.Type = RowDecoder.self)
    -> QueryInterfaceRequest<RowDecoder>
    {
        all().select(selection, as: type)
    }
    
    /// Creates a request which selects *sql*, and fetches values of
    /// type *type*.
    ///
    ///     try dbQueue.read { db in
    ///         // SELECT max(score) FROM player
    ///         let request = Player.select(sql: "max(score)", as: Int.self)
    ///         let maxScore: Int? = try request.fetchOne(db)
    ///     }
    public static func select<RowDecoder>(
        sql: String,
        arguments: StatementArguments = StatementArguments(),
        as type: RowDecoder.Type = RowDecoder.self)
    -> QueryInterfaceRequest<RowDecoder>
    {
        all().select(SQL(sql: sql, arguments: arguments), as: type)
    }
    
    /// Creates a request which selects an SQL *literal*, and fetches values of
    /// type *type*.
    ///
    /// Literals allow you to safely embed raw values in your SQL, without any
    /// risk of syntax errors or SQL injection:
    ///
    ///     // SELECT IFNULL(name, 'Anonymous') FROM player
    ///     let defaultName = "Anonymous"
    ///     let request = Player.select(
    ///         literal: "IFNULL(name, \(defaultName))",
    ///         as: String.self)
    ///     let name: String? = try request.fetchOne(db)
    public static func select<RowDecoder>(
        literal sqlLiteral: SQL,
        as type: RowDecoder.Type = RowDecoder.self)
    -> QueryInterfaceRequest<RowDecoder>
    {
        all().select(sqlLiteral, as: type)
    }
    
    /// Creates a request which selects the primary key.
    ///
    /// All primary keys are supported:
    ///
    ///     // SELECT id FROM player
    ///     let request = try Player.selectPrimaryKey(as: Int64.self)
    ///
    ///     // SELECT code FROM country
    ///     let request = try Country.selectPrimaryKey(as: String.self)
    ///
    ///     // SELECT citizenId, countryCode FROM citizenship
    ///     let request = try Citizenship.selectPrimaryKey(as: Row.self)
    public static func selectPrimaryKey<PrimaryKey>(as type: PrimaryKey.Type = PrimaryKey.self)
    -> QueryInterfaceRequest<PrimaryKey>
    {
        all().selectPrimaryKey(as: type)
    }
    
    /// Creates a request which appends *selection*.
    ///
    ///     // SELECT id, email, name FROM player
    ///     let request = Player
    ///         .select([Column("id"), Column("email")])
    ///         .annotated(with: [Column("name")])
    public static func annotated(with selection: [any SQLSelectable]) -> QueryInterfaceRequest<Self> {
        all().annotated(with: selection)
    }
    
    /// Creates a request which appends *selection*.
    ///
    ///     // SELECT id, email, name FROM player
    ///     let request = Player
    ///         .select([Column("id"), Column("email")])
    ///         .annotated(with: Column("name"))
    public static func annotated(with selection: any SQLSelectable...) -> QueryInterfaceRequest<Self> {
        all().annotated(with: selection)
    }
    
    // Accept SQLSpecificExpressible instead of SQLExpressible, so that we
    // prevent the `Player.filter(42)` misuse.
    // See https://github.com/groue/GRDB.swift/pull/864
    /// Creates a request with the provided *predicate*.
    ///
    ///     // SELECT * FROM player WHERE email = 'arthur@example.com'
    ///     let request = Player.filter(Column("email") == "arthur@example.com")
    public static func filter(_ predicate: some SQLSpecificExpressible) -> QueryInterfaceRequest<Self> {
        all().filter(predicate)
    }
    
    /// Creates a request with the provided primary key *predicate*.
    ///
    ///     // SELECT * FROM player WHERE id = 1
    ///     let request = Player.filter(key: 1)
    public static func filter(key: some DatabaseValueConvertible) -> QueryInterfaceRequest<Self> {
        all().filter(key: key)
    }
    
    /// Creates a request with the provided primary key *predicate*.
    ///
    ///     // SELECT * FROM player WHERE id IN (1, 2, 3)
    ///     let request = Player.filter(keys: [1, 2, 3])
    public static func filter<Keys>(keys: Keys)
    -> QueryInterfaceRequest<Self>
    where Keys: Sequence, Keys.Element: DatabaseValueConvertible
    {
        all().filter(keys: keys)
    }
    
    /// Creates a request with the provided primary key *predicate*.
    ///
    ///     // SELECT * FROM passport WHERE personId = 1 AND countryCode = 'FR'
    ///     let request = Passport.filter(key: ["personId": 1, "countryCode": "FR"])
    ///
    /// When executed, this request raises a fatal error if there is no unique
    /// index on the key columns.
    public static func filter(key: [String: (any DatabaseValueConvertible)?]?) -> QueryInterfaceRequest<Self> {
        all().filter(key: key)
    }
    
    /// Creates a request with the provided primary key *predicate*.
    ///
    ///     // SELECT * FROM passport WHERE (personId = 1 AND countryCode = 'FR') OR ...
    ///     let request = Passport.filter(keys: [["personId": 1, "countryCode": "FR"], ...])
    ///
    /// When executed, this request raises a fatal error if there is no unique
    /// index on the key columns.
    public static func filter(keys: [[String: (any DatabaseValueConvertible)?]]) -> QueryInterfaceRequest<Self> {
        all().filter(keys: keys)
    }
    
    /// Creates a request with the provided *predicate*.
    ///
    ///     // SELECT * FROM player WHERE email = 'arthur@example.com'
    ///     let request = Player.filter(sql: "email = ?", arguments: ["arthur@example.com"])
    public static func filter(
        sql: String,
        arguments: StatementArguments = StatementArguments())
    -> QueryInterfaceRequest<Self>
    {
        filter(SQL(sql: sql, arguments: arguments))
    }
    
    /// Creates a request with the provided *predicate* added to the
    /// eventual set of already applied predicates.
    ///
    /// Literals allow you to safely embed raw values in your SQL, without any
    /// risk of syntax errors or SQL injection:
    ///
    ///     // SELECT * FROM player WHERE name = 'O''Brien'
    ///     let name = "O'Brien"
    ///     let request = Player.filter(literal: "email = \(email)")
    public static func filter(literal sqlLiteral: SQL) -> QueryInterfaceRequest<Self> {
        // NOT TESTED
        all().filter(sqlLiteral)
    }
    
    /// Creates a request sorted according to the
    /// provided *orderings*.
    ///
    ///     // SELECT * FROM player ORDER BY name
    ///     let request = Player.order(Column("name"))
    public static func order(_ orderings: any SQLOrderingTerm...) -> QueryInterfaceRequest<Self> {
        all().order(orderings)
    }
    
    /// Creates a request sorted according to the
    /// provided *orderings*.
    ///
    ///     // SELECT * FROM player ORDER BY name
    ///     let request = Player.order([Column("name")])
    public static func order(_ orderings: [any SQLOrderingTerm]) -> QueryInterfaceRequest<Self> {
        all().order(orderings)
    }
    
    /// Creates a request sorted by primary key.
    ///
    ///     // SELECT * FROM player ORDER BY id
    ///     let request = Player.orderByPrimaryKey()
    ///
    ///     // SELECT * FROM country ORDER BY code
    ///     let request = Country.orderByPrimaryKey()
    public static func orderByPrimaryKey() -> QueryInterfaceRequest<Self> {
        all().orderByPrimaryKey()
    }
    
    /// Creates a request sorted according to *sql*.
    ///
    ///     // SELECT * FROM player ORDER BY name
    ///     let request = Player.order(sql: "name")
    public static func order(
        sql: String,
        arguments: StatementArguments = StatementArguments())
    -> QueryInterfaceRequest<Self>
    {
        all().order(SQL(sql: sql, arguments: arguments))
    }
    
    /// Creates a request sorted according to an SQL *literal*.
    ///
    ///     // SELECT * FROM player ORDER BY name
    ///     let request = Player.order(literal: "name")
    public static func order(literal sqlLiteral: SQL) -> QueryInterfaceRequest<Self> {
        all().order(sqlLiteral)
    }
    
    /// Creates a request which fetches *limit* rows, starting at
    /// *offset*.
    ///
    ///     // SELECT * FROM player LIMIT 1
    ///     let request = Player.limit(1)
    public static func limit(_ limit: Int, offset: Int? = nil) -> QueryInterfaceRequest<Self> {
        all().limit(limit, offset: offset)
    }
    
    /// Creates a request that allows you to define expressions that target
    /// a specific database table.
    ///
    /// In the example below, the "team.avgScore < player.score" condition in
    /// the ON clause could be not achieved without table aliases.
    ///
    ///     struct Player: TableRecord {
    ///         static let team = belongsTo(Team.self)
    ///     }
    ///
    ///     // SELECT player.*, team.*
    ///     // JOIN team ON ... AND team.avgScore < player.score
    ///     let playerAlias = TableAlias()
    ///     let request = Player
    ///         .aliased(playerAlias)
    ///         .including(required: Player.team.filter(Column("avgScore") < playerAlias[Column("score")])
    public static func aliased(_ alias: TableAlias) -> QueryInterfaceRequest<Self> {
        all().aliased(alias)
    }
    
    /// Returns a request which embeds the common table expression.
    ///
    /// If a common table expression with the same table name had already been
    /// embedded, it is replaced by the new one.
    ///
    /// For example, you can build a request that fetches all chats with their
    /// latest post:
    ///
    ///     let latestMessageRequest = Message
    ///         .annotated(with: max(Column("date")))
    ///         .group(Column("chatID"))
    ///
    ///     let latestMessageCTE = CommonTableExpression(
    ///         named: "latestMessage",
    ///         request: latestMessageRequest)
    ///
    ///     let latestMessage = Chat.association(
    ///         to: latestMessageCTE,
    ///         on: { chat, latestMessage in
    ///             chat[Column("id")] == latestMessage[Column("chatID")]
    ///         })
    ///
    ///     // WITH latestMessage AS
    ///     //   (SELECT *, MAX(date) FROM message GROUP BY chatID)
    ///     // SELECT chat.*, latestMessage.*
    ///     // FROM chat
    ///     // LEFT JOIN latestMessage ON chat.id = latestMessage.chatID
    ///     let request = Chat
    ///         .with(latestMessageCTE)
    ///         .including(optional: latestMessage)
    ///
    /// - parameter cte: A common table expression.
    /// - returns: A request.
    public static func with<RowDecoder>(_ cte: CommonTableExpression<RowDecoder>) -> QueryInterfaceRequest<Self> {
        all().with(cte)
    }
}

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6, *)
extension TableRecord where Self: Identifiable, ID: DatabaseValueConvertible {
    /// Creates a request filtered by primary key.
    ///
    ///     // SELECT * FROM player WHERE id = 1
    ///     let request = Player.filter(id: 1)
    ///
    /// - parameter id: A primary key
    public static func filter(id: ID) -> QueryInterfaceRequest<Self> {
        all().filter(id: id)
    }
    
    /// Creates a request filtered by primary key.
    ///
    ///     // SELECT * FROM player WHERE id IN (1, 2, 3)
    ///     let request = Player.filter(ids: [1, 2, 3])
    ///
    /// - parameter ids: A collection of primary keys
    public static func filter<IDS>(ids: IDS) -> QueryInterfaceRequest<Self>
    where IDS: Collection, IDS.Element == ID
    {
        all().filter(ids: ids)
    }
}

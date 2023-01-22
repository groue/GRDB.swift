extension TableRecord {
    
    // MARK: Request Derivation
    
    static var relationForAll: SQLRelation {
        .all(fromTable: databaseTableName, selection: { _ in databaseSelection.map(\.sqlSelection) })
    }
    
    /// Returns a request for all records in the table.
    ///
    /// The record selection is determined by
    /// ``TableRecord/databaseSelection-7iphs``, which defaults to all columns.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: TableRecord { }
    ///
    /// try dbQueue.read { db in
    ///     // SELECT * FROM player
    ///     let request = Player.all()
    /// }
    public static func all() -> QueryInterfaceRequest<Self> {
        QueryInterfaceRequest(relation: relationForAll)
    }
    
    /// Returns an empty request that fetches no record.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: TableRecord, FetchableRecord { }
    ///
    /// try dbQueue.read { db in
    ///     let request = Player.none()
    ///     let players = try request.fetchAll(db) // empty array
    /// }
    public static func none() -> QueryInterfaceRequest<Self> {
        all().none() // don't laugh
    }
    
    /// Returns a request that selects the provided result columns.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: TableRecord { }
    ///
    /// // SELECT id, score FROM player
    /// let request = Player.select(Column("id"), Column("score"))
    /// ```
    public static func select(_ selection: any SQLSelectable...) -> QueryInterfaceRequest<Self> {
        all().select(selection)
    }
    
    /// Returns a request that selects the provided result columns.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: TableRecord { }
    ///
    /// // SELECT id, score FROM player
    /// let request = Player.select([Column("id"), Column("score")])
    /// ```
    public static func select(_ selection: [any SQLSelectable]) -> QueryInterfaceRequest<Self> {
        all().select(selection)
    }
    
    /// Returns a request that selects the provided SQL string.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: TableRecord { }
    ///
    /// // SELECT id, name FROM player
    /// let request = Player.select(sql: "id, name")
    ///
    /// // SELECT id, IFNULL(name, 'Anonymous') FROM player
    /// let defaultName = "Anonymous"
    /// let request = Player.select(sql: "id, IFNULL(name, ?)", arguments: [defaultName])
    /// ```
    public static func select(
        sql: String,
        arguments: StatementArguments = StatementArguments())
    -> QueryInterfaceRequest<Self>
    {
        all().select(SQL(sql: sql, arguments: arguments))
    }
    
    /// Returns a request that selects the provided ``SQL`` literal.
    ///
    /// ``SQL`` literals allow you to safely embed raw values in your SQL,
    /// without any risk of syntax errors or SQL injection:
    ///
    /// ```swift
    /// struct Player: TableRecord { }
    ///
    /// // SELECT id, IFNULL(name, 'Anonymous') FROM player
    /// let defaultName = "Anonymous"
    /// let request = Player.select(literal: "id, IFNULL(name, \(defaultName))")
    /// ```
    public static func select(literal sqlLiteral: SQL) -> QueryInterfaceRequest<Self> {
        all().select(sqlLiteral)
    }
    
    /// Returns a request that selects the provided result columns, and defines
    /// the type of decoded rows.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: TableRecord { }
    /// let minScore = min(Column("score"))
    /// let maxScore = max(Column("score"))
    ///
    /// // SELECT MAX(score) FROM player
    /// let request = Player.select([maxScore], as: Int.self)
    /// let maxScore = try request.fetchOne(db) // Int?
    ///
    /// // SELECT MIN(score), MAX(score) FROM player
    /// let request = Player.select([minScore, maxScore], as: Row.self)
    /// if let row = try request.fetchOne(db) {
    ///     let minScore: Int = row[0]
    ///     let maxScore: Int = row[1]
    /// }
    /// ```
    public static func select<RowDecoder>(
        _ selection: [any SQLSelectable],
        as type: RowDecoder.Type = RowDecoder.self)
    -> QueryInterfaceRequest<RowDecoder>
    {
        all().select(selection, as: type)
    }
    
    /// Returns a request that selects the provided result columns, and defines
    /// the type of decoded rows.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: TableRecord { }
    /// let minScore = min(Column("score"))
    /// let maxScore = max(Column("score"))
    ///
    /// // SELECT MAX(score) FROM player
    /// let request = Player.select(maxScore, as: Int.self)
    /// let maxScore = try request.fetchOne(db) // Int?
    ///
    /// // SELECT MIN(score), MAX(score) FROM player
    /// let request = Player.select(minScore, maxScore, as: Row.self)
    /// if let row = try request.fetchOne(db) {
    ///     let minScore: Int = row[0]
    ///     let maxScore: Int = row[1]
    /// }
    /// ```
    public static func select<RowDecoder>(
        _ selection: any SQLSelectable...,
        as type: RowDecoder.Type = RowDecoder.self)
    -> QueryInterfaceRequest<RowDecoder>
    {
        all().select(selection, as: type)
    }
    
    /// Returns a request that selects the provided SQL string, and defines the
    /// type of decoded rows.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: TableRecord { }
    ///
    /// // SELECT name FROM player
    /// let request = Player.select(sql: "name", as: String.self)
    /// let names = try request.fetchAll(db) // [String]
    ///
    /// // SELECT IFNULL(name, 'Anonymous') FROM player
    /// let defaultName = "Anonymous"
    /// let request = Player.select(sql: "IFNULL(name, ?)", arguments: [defaultName], as: String.self)
    /// let names = try request.fetchAll(db) // [String]
    /// ```
    public static func select<RowDecoder>(
        sql: String,
        arguments: StatementArguments = StatementArguments(),
        as type: RowDecoder.Type = RowDecoder.self)
    -> QueryInterfaceRequest<RowDecoder>
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
    /// struct Player: TableRecord { }
    ///
    /// // SELECT IFNULL(name, 'Anonymous') FROM player
    /// let defaultName = "Anonymous"
    /// let request = Player.select(literal: "IFNULL(name, \(defaultName))", as: String.self)
    /// let names = try request.fetchAll(db) // [String]
    /// ```
    public static func select<RowDecoder>(
        literal sqlLiteral: SQL,
        as type: RowDecoder.Type = RowDecoder.self)
    -> QueryInterfaceRequest<RowDecoder>
    {
        all().select(sqlLiteral, as: type)
    }
    
    /// Returns a request that selects the primary key.
    ///
    /// All primary keys are supported:
    ///
    /// ```swift
    /// struct Player: TableRecord { }
    /// struct Country: TableRecord { }
    /// struct Citizenship: TableRecord { }
    ///
    /// // SELECT id FROM player WHERE ...
    /// let request = try Player.selectPrimaryKey(as: Int64.self)
    /// let ids = try request.fetchAll(db) // [Int64]
    ///
    /// // SELECT code FROM country WHERE ...
    /// let request = try Country.selectPrimaryKey(as: String.self)
    /// let countryCodes = try request.fetchAll(db) // [String]
    ///
    /// // SELECT citizenId, countryCode FROM citizenship WHERE ...
    /// let request = try Citizenship.selectPrimaryKey(as: Row.self)
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
    /// let request = try Citizenship.selectPrimaryKey(as: Citizenship.ID.self)
    /// let ids = try request.fetchAll(db) // [Citizenship.ID]
    /// ```
    public static func selectPrimaryKey<PrimaryKey>(as type: PrimaryKey.Type = PrimaryKey.self)
    -> QueryInterfaceRequest<PrimaryKey>
    {
        all().selectPrimaryKey(as: type)
    }
    
    /// Returns a request with the provided result columns appended to the
    /// record selection.
    ///
    /// The record selection is determined by
    /// ``TableRecord/databaseSelection-7iphs``, which defaults to all columns.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: TableRecord { }
    ///
    /// // SELECT *, score + bonus AS totalScore FROM player
    /// let totalScore = (Column("score") + Column("bonus")).forKey("totalScore")
    /// let request = Player.annotated(with: [totalScore])
    /// ```
    public static func annotated(with selection: [any SQLSelectable]) -> QueryInterfaceRequest<Self> {
        all().annotated(with: selection)
    }
    
    /// Returns a request with the provided result columns appended to the
    /// record selection.
    ///
    /// The record selection is determined by
    /// ``TableRecord/databaseSelection-7iphs``, which defaults to all columns.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: TableRecord { }
    ///
    /// // SELECT *, score + bonus AS totalScore FROM player
    /// let totalScore = (Column("score") + Column("bonus")).forKey("totalScore")
    /// let request = Player.annotated(with: totalScore)
    /// ```
    public static func annotated(with selection: any SQLSelectable...) -> QueryInterfaceRequest<Self> {
        all().annotated(with: selection)
    }
    
    // Accept SQLSpecificExpressible instead of SQLExpressible, so that we
    // prevent the `Player.filter(42)` misuse.
    // See https://github.com/groue/GRDB.swift/pull/864
    /// Returns a request filtered with a boolean SQL expression.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: TableRecord { }
    ///
    /// // SELECT * FROM player WHERE name = 'O''Brien'
    /// let name = "O'Brien"
    /// let request = Player.filter(Column("name") == name)
    /// ```
    public static func filter(_ predicate: some SQLSpecificExpressible) -> QueryInterfaceRequest<Self> {
        all().filter(predicate)
    }
    
    /// Returns a request filtered by primary key.
    ///
    /// All single-column primary keys are supported:
    ///
    /// ```swift
    /// struct Player: TableRecord { }
    /// struct Country: TableRecord { }
    ///
    /// // SELECT * FROM player WHERE id = 1
    /// let request = Player.filter(key: 1)
    ///
    /// // SELECT * FROM country WHERE code = 'FR'
    /// let request = Country.filter(key: "FR")
    /// ```
    ///
    /// - parameter key: A primary key
    public static func filter(key: some DatabaseValueConvertible) -> QueryInterfaceRequest<Self> {
        all().filter(key: key)
    }
    
    /// Returns a request filtered by primary key.
    ///
    /// All single-column primary keys are supported:
    ///
    /// ```swift
    /// struct Player: TableRecord { }
    /// struct Country: TableRecord { }
    ///
    /// // SELECT * FROM player WHERE id = IN (1, 2, 3)
    /// let request = Player.filter(keys: [1, 2, 3])
    ///
    /// // SELECT * FROM country WHERE code = IN ('FR', 'US')
    /// let request = Country.filter(keys: ["FR", "US"])
    /// ```
    ///
    /// - parameter keys: A collection of primary keys
    public static func filter<Keys>(keys: Keys)
    -> QueryInterfaceRequest<Self>
    where Keys: Sequence, Keys.Element: DatabaseValueConvertible
    {
        all().filter(keys: keys)
    }
    
    /// Returns a request filtered by primary or unique key.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: TableRecord { }
    /// struct Citizenship: TableRecord { }
    ///
    /// // SELECT * FROM player WHERE id = 1
    /// let request = Player.filter(key: ["id": 1])
    ///
    /// // SELECT * FROM player WHERE email = 'arthur@example.com'
    /// let request = Player.filter(key: ["email": "arthur@example.com"])
    ///
    /// // SELECT * FROM citizenship WHERE citizenId = 1 AND countryCode = 'FR'
    /// let request = Citizenship.filter(key: [
    ///     "citizenId": 1,
    ///     "countryCode": "FR",
    /// ])
    /// ```
    ///
    /// When executed, this request raises a fatal error if no unique index
    /// exists on a subset of the key columns.
    ///
    /// - parameter key: A key dictionary.
    public static func filter(key: [String: (any DatabaseValueConvertible)?]?) -> QueryInterfaceRequest<Self> {
        all().filter(key: key)
    }
    
    /// Returns a request filtered by primary or unique key.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: TableRecord { }
    /// struct Citizenship: TableRecord { }
    ///
    /// // SELECT * FROM player WHERE id = 1
    /// let request = Player.filter(keys: [["id": 1]])
    ///
    /// // SELECT * FROM player WHERE email = 'arthur@example.com'
    /// let request = Player.filter(keys: [["email": "arthur@example.com"]])
    ///
    /// // SELECT * FROM citizenship WHERE citizenId = 1 AND countryCode = 'FR'
    /// let request = Citizenship.filter(keys: [
    ///     ["citizenId": 1, "countryCode": "FR"],
    /// ])
    /// ```
    ///
    /// When executed, this request raises a fatal error if no unique index
    /// exists on a subset of the key columns.
    ///
    /// - parameter keys: An array of key dictionaries.
    public static func filter(keys: [[String: (any DatabaseValueConvertible)?]]) -> QueryInterfaceRequest<Self> {
        all().filter(keys: keys)
    }
    
    /// Returns a request filtered with an SQL string.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: TableRecord { }
    ///
    /// // SELECT * FROM player WHERE name = 'O''Brien'
    /// let name = "O'Brien"
    /// let request = Player.filter(sql: "name = ?", arguments: [name])
    /// ```
    public static func filter(
        sql: String,
        arguments: StatementArguments = StatementArguments())
    -> QueryInterfaceRequest<Self>
    {
        filter(SQL(sql: sql, arguments: arguments))
    }
    
    /// Returns a request filtered with an ``SQL`` literal.
    ///
    /// ``SQL`` literals allow you to safely embed raw values in your SQL,
    /// without any risk of syntax errors or SQL injection:
    ///
    /// ```swift
    /// struct Player: TableRecord { }
    ///
    /// // SELECT * FROM player WHERE name = 'O''Brien'
    /// let name = "O'Brien"
    /// let request = Player.filter(literal: "name = \(name)")
    /// ```
    public static func filter(literal sqlLiteral: SQL) -> QueryInterfaceRequest<Self> {
        // NOT TESTED
        all().filter(sqlLiteral)
    }
    
    /// Returns a request sorted according to the given SQL ordering terms.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: TableRecord { }
    ///
    /// // SELECT * FROM player ORDER BY score DESC, name
    /// let request = Player.order(Column("score").desc, Column("name"))
    /// ```
    public static func order(_ orderings: any SQLOrderingTerm...) -> QueryInterfaceRequest<Self> {
        all().order(orderings)
    }
    
    /// Returns a request sorted according to the given SQL ordering terms.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: TableRecord { }
    ///
    /// // SELECT * FROM player ORDER BY score DESC, name
    /// let request = Player.order([Column("score").desc, Column("name")])
    /// ```
    public static func order(_ orderings: [any SQLOrderingTerm]) -> QueryInterfaceRequest<Self> {
        all().order(orderings)
    }
    
    /// Returns a request sorted by primary key.
    ///
    /// All primary keys are supported:
    ///
    /// ```swift
    /// struct Player: TableRecord { }
    /// struct Country: TableRecord { }
    /// struct Citizenship: TableRecord { }
    ///
    /// // SELECT * FROM player ORDER BY id
    /// let request = Player.orderByPrimaryKey()
    ///
    /// // SELECT * FROM country ORDER BY code
    /// let request = Country.orderByPrimaryKey()
    ///
    /// // SELECT * FROM citizenship ORDER BY citizenId, countryCode
    /// let request = Citizenship.orderByPrimaryKey()
    /// ```
    public static func orderByPrimaryKey() -> QueryInterfaceRequest<Self> {
        all().orderByPrimaryKey()
    }
    
    /// Returns a request sorted according to the given SQL string.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: TableRecord { }
    /// 
    /// // SELECT * FROM player ORDER BY score DESC, name
    /// let request = Player.order(sql: "score DESC, name")
    /// ```
    public static func order(
        sql: String,
        arguments: StatementArguments = StatementArguments())
    -> QueryInterfaceRequest<Self>
    {
        all().order(SQL(sql: sql, arguments: arguments))
    }
    
    /// Returns a request sorted according to the given ``SQL`` literal.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: TableRecord { }
    ///
    /// // SELECT * FROM player ORDER BY score DESC, name
    /// let request = Player.order(literal: "score DESC, name")
    /// ```
    public static func order(literal sqlLiteral: SQL) -> QueryInterfaceRequest<Self> {
        all().order(sqlLiteral)
    }
    
    /// Returns a limited request.
    ///
    /// The returned request fetches `limit` rows, starting at `offset`. For
    /// example:
    ///
    /// ```swift
    /// struct Player: TableRecord { }
    ///
    /// // SELECT * FROM player LIMIT 10
    /// let request = Player.limit(10)
    ///
    /// // SELECT * FROM player LIMIT 10 OFFSET 20
    /// let request = Player.limit(10, offset: 20)
    /// ```
    public static func limit(_ limit: Int, offset: Int? = nil) -> QueryInterfaceRequest<Self> {
        all().limit(limit, offset: offset)
    }
    
    /// Returns a request that can be referred to with the provided alias.
    ///
    /// Use this method when you need to refer to this table from
    /// another request.
    ///
    /// For example, the request below fetches posthumous books:
    ///
    /// ```swift
    /// struct Author: TableRecord { }
    /// struct Book: TableRecord {
    ///     static let author = belongsTo(Author.self)
    /// }
    ///
    /// // SELECT book.*
    /// // FROM book
    /// // JOIN author ON author.id = book.authorId
    /// //            AND author.deathDate <= book.publishDate
    /// let bookAlias = TableAlias()
    /// let request = Book
    ///     .aliased(bookAlias)
    ///     .joining(required: Book.author.filter(Column("deathDate") <= bookAlias[Column("publishDate")])
    /// ```
    ///
    /// See ``TableRequest/aliased(_:)`` for more information.
    public static func aliased(_ alias: TableAlias) -> QueryInterfaceRequest<Self> {
        all().aliased(alias)
    }
    
    /// Returns a request that embeds a common table expression.
    ///
    /// For example, you can build a request that fetches all chats with their
    /// latest message:
    ///
    /// ```swift
    /// let latestMessageRequest = Message
    ///     .annotated(with: max(Column("date")))
    ///     .group(Column("chatID"))
    ///
    /// let latestMessageCTE = CommonTableExpression(
    ///     named: "latestMessage",
    ///     request: latestMessageRequest)
    ///
    /// let latestMessageAssociation = Chat.association(
    ///     to: latestMessageCTE,
    ///     on: { chat, latestMessage in
    ///         chat[Column("id")] == latestMessage[Column("chatID")]
    ///     })
    ///
    /// // WITH latestMessage AS
    /// //   (SELECT *, MAX(date) FROM message GROUP BY chatID)
    /// // SELECT chat.*, latestMessage.*
    /// // FROM chat
    /// // LEFT JOIN latestMessage ON chat.id = latestMessage.chatID
    /// let request = Chat
    ///     .with(latestMessageCTE)
    ///     .including(optional: latestMessageAssociation)
    /// ```
    public static func with<RowDecoder>(_ cte: CommonTableExpression<RowDecoder>) -> QueryInterfaceRequest<Self> {
        all().with(cte)
    }
}

@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
extension TableRecord where Self: Identifiable, ID: DatabaseValueConvertible {
    /// Returns a request filtered by primary key.
    ///
    /// All single-column primary keys are supported:
    ///
    /// ```swift
    /// struct Player: TableRecord, Identifiable {
    ///     var id: Int64
    /// }
    /// struct Country: TableRecord, Identifiable {
    ///     var id: String
    /// }
    ///
    /// // SELECT * FROM player WHERE id = 1
    /// let request = Player.filter(id: 1)
    ///
    /// // SELECT * FROM country WHERE code = 'FR'
    /// let request = Country.filter(id: "FR")
    /// ```
    ///
    /// - parameter id: A primary key
    public static func filter(id: ID) -> QueryInterfaceRequest<Self> {
        all().filter(id: id)
    }
    
    /// Returns a request filtered by primary key.
    ///
    /// All single-column primary keys are supported:
    ///
    /// ```swift
    /// struct Player: TableRecord, Identifiable {
    ///     var id: Int64
    /// }
    /// struct Country: TableRecord, Identifiable {
    ///     var id: String
    /// }
    ///
    /// // SELECT * FROM player WHERE id = IN (1, 2, 3)
    /// let request = Player.filter(ids: [1, 2, 3])
    ///
    /// // SELECT * FROM country WHERE code = IN ('FR', 'US')
    /// let request = Country.filter(ids: ["FR", "US"])
    /// ```
    ///
    /// - parameter ids: A collection of primary keys
    public static func filter<IDS>(ids: IDS) -> QueryInterfaceRequest<Self>
    where IDS: Collection, IDS.Element == ID
    {
        all().filter(ids: ids)
    }
}

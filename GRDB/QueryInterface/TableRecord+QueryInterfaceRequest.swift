extension TableRecord {
    
    // MARK: Request Derivation
    
    /// Creates a request which fetches all records.
    ///
    ///     // SELECT * FROM player
    ///     let request = Player.all()
    ///
    /// The selection defaults to all columns. This default can be changed for
    /// all requests by the `TableRecord.databaseSelection` property, or
    /// for individual requests with the `TableRecord.select` method.
    public static func all() -> QueryInterfaceRequest<Self> {
        let relation = SQLRelation(
            source: .table(tableName: databaseTableName, alias: nil),
            selection: databaseSelection)
        return QueryInterfaceRequest(relation: relation)
    }
    
    /// Creates a request which fetches no record.
    public static func none() -> QueryInterfaceRequest<Self> {
        return all().none() // don't laugh
    }
    
    /// Creates a request which selects *selection*.
    ///
    ///     // SELECT id, email FROM player
    ///     let request = Player.select(Column("id"), Column("email"))
    public static func select(_ selection: SQLSelectable...) -> QueryInterfaceRequest<Self> {
        return all().select(selection)
    }
    
    /// Creates a request which selects *selection*.
    ///
    ///     // SELECT id, email FROM player
    ///     let request = Player.select([Column("id"), Column("email")])
    public static func select(_ selection: [SQLSelectable]) -> QueryInterfaceRequest<Self> {
        return all().select(selection)
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
        return select(literal: SQLLiteral(sql: sql, arguments: arguments))
    }
    
    /// Creates a request which selects an SQL *literal*.
    ///
    ///     // SELECT id, email FROM player
    ///     let request = Player.select(literal: SQLLiteral(sql: "id, email"))
    public static func select(literal sqlLiteral: SQLLiteral) -> QueryInterfaceRequest<Self> {
        return all().select(literal: sqlLiteral)
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
        _ selection: [SQLSelectable],
        as type: RowDecoder.Type = RowDecoder.self)
        -> QueryInterfaceRequest<RowDecoder>
    {
        return all().select(selection, as: type)
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
        _ selection: SQLSelectable...,
        as type: RowDecoder.Type = RowDecoder.self)
        -> QueryInterfaceRequest<RowDecoder>
    {
        return all().select(selection, as: type)
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
        return all().select(literal: SQLLiteral(sql: sql, arguments: arguments), as: type)
    }
    
    /// Creates a request which selects an SQL *literal*, and fetches values of
    /// type *type*.
    ///
    ///     try dbQueue.read { db in
    ///         // SELECT max(score) FROM player
    ///         let request = Player.select(literal: SQLLiteral(sql: "max(score)"), as: Int.self)
    ///         let maxScore: Int? = try request.fetchOne(db)
    ///     }
    public static func select<RowDecoder>(
        literal sqlLiteral: SQLLiteral,
        as type: RowDecoder.Type = RowDecoder.self)
        -> QueryInterfaceRequest<RowDecoder>
    {
        return all().select(literal: sqlLiteral, as: type)
    }
    
    /// Creates a request which appends *selection*.
    ///
    ///     // SELECT id, email, name FROM player
    ///     le request = Player
    ///         .select([Column("id"), Column("email")])
    ///         .annotated(with: [Column("name")])
    public static func annotated(with selection: [SQLSelectable]) -> QueryInterfaceRequest<Self> {
        return all().annotated(with: selection)
    }
    
    /// Creates a request which appends *selection*.
    ///
    ///     // SELECT id, email, name FROM player
    ///     le request = Player
    ///         .select([Column("id"), Column("email")])
    ///         .annotated(with: Column("name"))
    public static func annotated(with selection: SQLSelectable...) -> QueryInterfaceRequest<Self> {
        return all().annotated(with: selection)
    }
    
    /// Creates a request with the provided *predicate*.
    ///
    ///     // SELECT * FROM player WHERE email = 'arthur@example.com'
    ///     let request = Player.filter(Column("email") == "arthur@example.com")
    ///
    /// The selection defaults to all columns. This default can be changed for
    /// all requests by the `TableRecord.databaseSelection` property, or
    /// for individual requests with the `TableRecord.select` method.
    public static func filter(_ predicate: SQLExpressible) -> QueryInterfaceRequest<Self> {
        return all().filter(predicate)
    }
    
    /// Creates a request with the provided primary key *predicate*.
    ///
    ///     // SELECT * FROM player WHERE id = 1
    ///     let request = Player.filter(key: 1)
    ///
    /// The selection defaults to all columns. This default can be changed for
    /// all requests by the `TableRecord.databaseSelection` property, or
    /// for individual requests with the `TableRecord.select` method.
    public static func filter<PrimaryKeyType>(key: PrimaryKeyType?)
        -> QueryInterfaceRequest<Self>
        where PrimaryKeyType: DatabaseValueConvertible
    {
        return all().filter(key: key)
    }
    
    /// Creates a request with the provided primary key *predicate*.
    ///
    ///     // SELECT * FROM player WHERE id IN (1, 2, 3)
    ///     let request = Player.filter(keys: [1, 2, 3])
    ///
    /// The selection defaults to all columns. This default can be changed for
    /// all requests by the `TableRecord.databaseSelection` property, or
    /// for individual requests with the `TableRecord.select` method.
    public static func filter<Sequence>(keys: Sequence)
        -> QueryInterfaceRequest<Self>
        where Sequence: Swift.Sequence, Sequence.Element: DatabaseValueConvertible
    {
        return all().filter(keys: keys)
    }
    
    /// Creates a request with the provided primary key *predicate*.
    ///
    ///     // SELECT * FROM passport WHERE personId = 1 AND countryCode = 'FR'
    ///     let request = Passport.filter(key: ["personId": 1, "countryCode": "FR"])
    ///
    /// When executed, this request raises a fatal error if there is no unique
    /// index on the key columns.
    ///
    /// The selection defaults to all columns. This default can be changed for
    /// all requests by the `TableRecord.databaseSelection` property, or
    /// for individual requests with the `TableRecord.select` method.
    public static func filter(key: [String: DatabaseValueConvertible?]?) -> QueryInterfaceRequest<Self> {
        return all().filter(key: key)
    }
    
    /// Creates a request with the provided primary key *predicate*.
    ///
    ///     // SELECT * FROM passport WHERE (personId = 1 AND countryCode = 'FR') OR ...
    ///     let request = Passport.filter(keys: [["personId": 1, "countryCode": "FR"], ...])
    ///
    /// When executed, this request raises a fatal error if there is no unique
    /// index on the key columns.
    ///
    /// The selection defaults to all columns. This default can be changed for
    /// all requests by the `TableRecord.databaseSelection` property, or
    /// for individual requests with the `TableRecord.select` method.
    public static func filter(keys: [[String: DatabaseValueConvertible?]]) -> QueryInterfaceRequest<Self> {
        return all().filter(keys: keys)
    }
    
    /// Creates a request with the provided *predicate*.
    ///
    ///     // SELECT * FROM player WHERE email = 'arthur@example.com'
    ///     let request = Player.filter(sql: "email = ?", arguments: ["arthur@example.com"])
    ///
    /// The selection defaults to all columns. This default can be changed for
    /// all requests by the `TableRecord.databaseSelection` property, or
    /// for individual requests with the `TableRecord.select` method.
    public static func filter(
        sql: String,
        arguments: StatementArguments = StatementArguments())
        -> QueryInterfaceRequest<Self>
    {
        return filter(literal: SQLLiteral(sql: sql, arguments: arguments))
    }
    
    /// Creates a request with the provided *predicate*.
    ///
    ///     // SELECT * FROM player WHERE email = 'arthur@example.com'
    ///     let request = Player.filter(literal: SQLLiteral(sql: "email = ?", arguments: ["arthur@example.com"]))
    ///
    /// With Swift 5, you can safely embed raw values in your SQL queries,
    /// without any risk of syntax errors or SQL injection:
    ///
    ///     let request = Player.filter(literal: "name = \("O'Brien"))
    ///
    /// The selection defaults to all columns. This default can be changed for
    /// all requests by the `TableRecord.databaseSelection` property, or
    /// for individual requests with the `TableRecord.select` method.
    public static func filter(literal sqlLiteral: SQLLiteral) -> QueryInterfaceRequest<Self> {
        // NOT TESTED
        return all().filter(literal: sqlLiteral)
    }
    
    /// Creates a request sorted according to the
    /// provided *orderings*.
    ///
    ///     // SELECT * FROM player ORDER BY name
    ///     let request = Player.order(Column("name"))
    ///
    /// The selection defaults to all columns. This default can be changed for
    /// all requests by the `TableRecord.databaseSelection` property, or
    /// for individual requests with the `TableRecord.select` method.
    public static func order(_ orderings: SQLOrderingTerm...) -> QueryInterfaceRequest<Self> {
        return all().order(orderings)
    }
    
    /// Creates a request sorted according to the
    /// provided *orderings*.
    ///
    ///     // SELECT * FROM player ORDER BY name
    ///     let request = Player.order([Column("name")])
    ///
    /// The selection defaults to all columns. This default can be changed for
    /// all requests by the `TableRecord.databaseSelection` property, or
    /// for individual requests with the `TableRecord.select` method.
    public static func order(_ orderings: [SQLOrderingTerm]) -> QueryInterfaceRequest<Self> {
        return all().order(orderings)
    }
    
    /// Creates a request sorted by primary key.
    ///
    ///     // SELECT * FROM player ORDER BY id
    ///     let request = Player.orderByPrimaryKey()
    ///
    ///     // SELECT * FROM country ORDER BY code
    ///     let request = Country.orderByPrimaryKey()
    ///
    /// The selection defaults to all columns. This default can be changed for
    /// all requests by the `TableRecord.databaseSelection` property, or
    /// for individual requests with the `TableRecord.select` method.
    public static func orderByPrimaryKey() -> QueryInterfaceRequest<Self> {
        return all().orderByPrimaryKey()
    }
    
    /// Creates a request sorted according to *sql*.
    ///
    ///     // SELECT * FROM player ORDER BY name
    ///     let request = Player.order(sql: "name")
    ///
    /// The selection defaults to all columns. This default can be changed for
    /// all requests by the `TableRecord.databaseSelection` property, or
    /// for individual requests with the `TableRecord.select` method.
    public static func order(
        sql: String,
        arguments: StatementArguments = StatementArguments())
        -> QueryInterfaceRequest<Self>
    {
        return all().order(literal: SQLLiteral(sql: sql, arguments: arguments))
    }
    
    /// Creates a request sorted according to an SQL *literal*.
    ///
    ///     // SELECT * FROM player ORDER BY name
    ///     let request = Player.order(literal: SQLLiteral(sql: "name"))
    ///
    /// With Swift 5, you can safely embed raw values in your SQL queries,
    /// without any risk of syntax errors or SQL injection:
    ///
    ///     // SELECT * FROM player ORDER BY name
    ///     let request = Player.order(literal: "name"))
    ///
    /// The selection defaults to all columns. This default can be changed for
    /// all requests by the `TableRecord.databaseSelection` property, or
    /// for individual requests with the `TableRecord.select` method.
    public static func order(literal sqlLiteral: SQLLiteral) -> QueryInterfaceRequest<Self> {
        return all().order(literal: sqlLiteral)
    }
    
    /// Creates a request which fetches *limit* rows, starting at
    /// *offset*.
    ///
    ///     // SELECT * FROM player LIMIT 1
    ///     let request = Player.limit(1)
    ///
    /// The selection defaults to all columns. This default can be changed for
    /// all requests by the `TableRecord.databaseSelection` property, or
    /// for individual requests with the `TableRecord.select` method.
    public static func limit(_ limit: Int, offset: Int? = nil) -> QueryInterfaceRequest<Self> {
        return all().limit(limit, offset: offset)
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
        return all().aliased(alias)
    }
}

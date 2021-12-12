/// `Table` can build query interface requests.
///
///     // SELECT * FROM player WHERE score >= 1000
///     let table = Table("player")
///     let rows: [Row] = try dbQueue.read { db in
///         table.all()
///             .filter(Column("score") >= 1000)
///             .fetchAll(db)
///     }
public struct Table<RowDecoder> {
    /// The table name
    public var tableName: String
    
    private init(_ tableName: String, _ type: RowDecoder.Type) {
        self.tableName = tableName
    }
    
    /// Create a `Table`
    ///
    ///     let table = Table<Row>("player")
    ///     let table = Table<Player>("player")
    public init(_ tableName: String) {
        self.init(tableName, RowDecoder.self)
    }
}

extension Table where RowDecoder == Row {
    /// Create a `Table` of `Row`.
    ///
    ///     let table = Table("player") // Table<Row>
    public init(_ tableName: String) {
        self.init(tableName, Row.self)
    }
}

extension Table: DatabaseRegionConvertible {
    public func databaseRegion(_ db: Database) throws -> DatabaseRegion {
        DatabaseRegion.fullTable(tableName)
    }
}

// MARK: Request Derivation

extension Table {
    var relationForAll: SQLRelation {
        .all(fromTable: tableName)
    }
    
    /// Creates a request for all rows of the table.
    ///
    ///     // Fetch all players
    ///     let table = Table<Player>("player")
    ///     let request = table.all()
    ///     let players: [Player] = try request.fetchAll(db)
    public func all() -> QueryInterfaceRequest<RowDecoder> {
        QueryInterfaceRequest(relation: relationForAll)
    }
    
    /// Creates a request which fetches no row.
    ///
    ///     // Fetch no players
    ///     let table = Table<Player>("player")
    ///     let request = table.none()
    ///     let players: [Player] = try request.fetchAll(db) // Empty array
    public func none() -> QueryInterfaceRequest<RowDecoder> {
        all().none() // don't laugh
    }
    
    /// Creates a request which selects *selection*.
    ///
    ///     // SELECT id, email FROM player
    ///     let table = Table("player")
    ///     let request = table.select(Column("id"), Column("email"))
    public func select(_ selection: SQLSelectable...) -> QueryInterfaceRequest<RowDecoder> {
        all().select(selection)
    }
    
    /// Creates a request which selects *selection*.
    ///
    ///     // SELECT id, email FROM player
    ///     let table = Table("player")
    ///     let request = table.select([Column("id"), Column("email")])
    public func select(_ selection: [SQLSelectable]) -> QueryInterfaceRequest<RowDecoder> {
        all().select(selection)
    }
    
    /// Creates a request which selects *sql*.
    ///
    ///     // SELECT id, email FROM player
    ///     let table = Table("player")
    ///     let request = table.select(sql: "id, email")
    public func select(
        sql: String,
        arguments: StatementArguments = StatementArguments())
    -> QueryInterfaceRequest<RowDecoder>
    {
        all().select(SQL(sql: sql, arguments: arguments))
    }
    
    /// Creates a request which selects an SQL *literal*.
    ///
    /// Literals allow you to safely embed raw values in your SQL, without any
    /// risk of syntax errors or SQL injection:
    ///
    ///     // SELECT id, email, score + 1000 FROM player
    ///     let table = Table("player")
    ///     let bonus = 1000
    ///     let request = table.select(literal: """
    ///         id, email, score + \(bonus)
    ///         """)
    public func select(literal sqlLiteral: SQL) -> QueryInterfaceRequest<RowDecoder> {
        all().select(sqlLiteral)
    }
    
    /// Creates a request which selects *selection*, and fetches values of
    /// type *type*.
    ///
    ///     try dbQueue.read { db in
    ///         // SELECT max(score) FROM player
    ///         let table = Table("player")
    ///         let request = table.select([max(Column("score"))], as: Int.self)
    ///         let maxScore: Int? = try request.fetchOne(db)
    ///     }
    public func select<RowDecoder>(
        _ selection: [SQLSelectable],
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
    ///         let table = Table("player")
    ///         let request = table.select(max(Column("score")), as: Int.self)
    ///         let maxScore: Int? = try request.fetchOne(db)
    ///     }
    public func select<RowDecoder>(
        _ selection: SQLSelectable...,
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
    ///         let table = Table("player")
    ///         let request = table.select(sql: "max(score)", as: Int.self)
    ///         let maxScore: Int? = try request.fetchOne(db)
    ///     }
    public func select<RowDecoder>(
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
    ///     let table = Table("player")
    ///     let defaultName = "Anonymous"
    ///     let request = table.select(
    ///         literal: "IFNULL(name, \(defaultName))",
    ///         as: String.self)
    ///     let name: String? = try request.fetchOne(db)
    public func select<RowDecoder>(
        literal sqlLiteral: SQL,
        as type: RowDecoder.Type = RowDecoder.self)
    -> QueryInterfaceRequest<RowDecoder>
    {
        all().select(sqlLiteral, as: type)
    }
    
    /// Creates a request which appends *selection*.
    ///
    ///     // SELECT id, email, name FROM player
    ///     let table = Table("player")
    ///     let request = table
    ///         .select([Column("id"), Column("email")])
    ///         .annotated(with: [Column("name")])
    public func annotated(with selection: [SQLSelectable]) -> QueryInterfaceRequest<RowDecoder> {
        all().annotated(with: selection)
    }
    
    /// Creates a request which appends *selection*.
    ///
    ///     // SELECT id, email, name FROM player
    ///     let table = Table("player")
    ///     let request = table
    ///         .select([Column("id"), Column("email")])
    ///         .annotated(with: Column("name"))
    public func annotated(with selection: SQLSelectable...) -> QueryInterfaceRequest<RowDecoder> {
        all().annotated(with: selection)
    }
    
    /// Creates a request with the provided *predicate*.
    ///
    ///     // SELECT * FROM player WHERE email = 'arthur@example.com'
    ///     let table = Table<Player>("player")
    ///     let request = table.filter(Column("email") == "arthur@example.com")
    public func filter(_ predicate: SQLSpecificExpressible) -> QueryInterfaceRequest<RowDecoder> {
        all().filter(predicate)
    }
    
    /// Creates a request with the provided primary key *predicate*.
    ///
    ///     // SELECT * FROM player WHERE id = 1
    ///     let table = Table<Player>("player")
    ///     let request = table.filter(key: 1)
    public func filter<PrimaryKeyType>(key: PrimaryKeyType?)
    -> QueryInterfaceRequest<RowDecoder>
    where PrimaryKeyType: DatabaseValueConvertible
    {
        all().filter(key: key)
    }
    
    /// Creates a request with the provided primary key *predicate*.
    ///
    ///     // SELECT * FROM player WHERE id IN (1, 2, 3)
    ///     let table = Table<Player>("player")
    ///     let request = table.filter(keys: [1, 2, 3])
    public func filter<Sequence>(keys: Sequence)
    -> QueryInterfaceRequest<RowDecoder>
    where Sequence: Swift.Sequence, Sequence.Element: DatabaseValueConvertible
    {
        all().filter(keys: keys)
    }
    
    /// Creates a request with the provided primary key *predicate*.
    ///
    ///     // SELECT * FROM passport WHERE personId = 1 AND countryCode = 'FR'
    ///     let table = Table<Passport>("passport")
    ///     let request = table.filter(key: ["personId": 1, "countryCode": "FR"])
    ///
    /// When executed, this request raises a fatal error if there is no unique
    /// index on the key columns.
    public func filter(key: [String: DatabaseValueConvertible?]?) -> QueryInterfaceRequest<RowDecoder> {
        all().filter(key: key)
    }
    
    /// Creates a request with the provided primary key *predicate*.
    ///
    ///     // SELECT * FROM passport WHERE (personId = 1 AND countryCode = 'FR') OR ...
    ///     let table = Table<Passport>("passport")
    ///     let request = table.filter(keys: [["personId": 1, "countryCode": "FR"], ...])
    ///
    /// When executed, this request raises a fatal error if there is no unique
    /// index on the key columns.
    public func filter(keys: [[String: DatabaseValueConvertible?]]) -> QueryInterfaceRequest<RowDecoder> {
        all().filter(keys: keys)
    }
    
    /// Creates a request with the provided *predicate*.
    ///
    ///     // SELECT * FROM player WHERE email = 'arthur@example.com'
    ///     let table = Table<Player>("player")
    ///     let request = table.filter(sql: "email = ?", arguments: ["arthur@example.com"])
    public func filter(
        sql: String,
        arguments: StatementArguments = StatementArguments())
    -> QueryInterfaceRequest<RowDecoder>
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
    ///     let table = Table<Player>("player")
    ///     let name = "O'Brien"
    ///     let request = table.filter(literal: "email = \(email)")
    public func filter(literal sqlLiteral: SQL) -> QueryInterfaceRequest<RowDecoder> {
        all().filter(sqlLiteral)
    }
    
    /// Creates a request sorted according to the
    /// provided *orderings*.
    ///
    ///     // SELECT * FROM player ORDER BY name
    ///     let table = Table<Player>("player")
    ///     let request = table.order(Column("name"))
    public func order(_ orderings: SQLOrderingTerm...) -> QueryInterfaceRequest<RowDecoder> {
        all().order(orderings)
    }
    
    /// Creates a request sorted according to the
    /// provided *orderings*.
    ///
    ///     // SELECT * FROM player ORDER BY name
    ///     let table = Table<Player>("player")
    ///     let request = table.order([Column("name")])
    public func order(_ orderings: [SQLOrderingTerm]) -> QueryInterfaceRequest<RowDecoder> {
        all().order(orderings)
    }
    
    /// Creates a request sorted by primary key.
    ///
    ///     // SELECT * FROM player ORDER BY id
    ///     let table = Table<Player>("player")
    ///     let request = table.orderByPrimaryKey()
    ///
    ///     // SELECT * FROM country ORDER BY code
    ///     let request = Country.orderByPrimaryKey()
    public func orderByPrimaryKey() -> QueryInterfaceRequest<RowDecoder> {
        all().orderByPrimaryKey()
    }
    
    /// Creates a request sorted according to *sql*.
    ///
    ///     // SELECT * FROM player ORDER BY name
    ///     let table = Table<Player>("player")
    ///     let request = table.order(sql: "name")
    public func order(
        sql: String,
        arguments: StatementArguments = StatementArguments())
    -> QueryInterfaceRequest<RowDecoder>
    {
        all().order(SQL(sql: sql, arguments: arguments))
    }
    
    /// Creates a request sorted according to an SQL *literal*.
    ///
    ///     // SELECT * FROM player ORDER BY name
    ///     let table = Table<Player>("player")
    ///     let request = table.order(literal: "name")
    public func order(literal sqlLiteral: SQL) -> QueryInterfaceRequest<RowDecoder> {
        all().order(sqlLiteral)
    }
    
    /// Creates a request which fetches *limit* rows, starting at
    /// *offset*.
    ///
    ///     // SELECT * FROM player LIMIT 1
    ///     let table = Table<Player>("player")
    ///     let request = table.limit(1)
    public func limit(_ limit: Int, offset: Int? = nil) -> QueryInterfaceRequest<RowDecoder> {
        all().limit(limit, offset: offset)
    }
    
    /// Creates a request that allows you to define expressions that target
    /// a specific database table.
    ///
    /// See `TableRecord.aliased(_:)` for more information.
    public func aliased(_ alias: TableAlias) -> QueryInterfaceRequest<RowDecoder> {
        all().aliased(alias)
    }
    
    /// Returns a request which embeds the common table expression.
    ///
    /// See `TableRecord.with(_:)` for more information.
    ///
    /// - parameter cte: A common table expression.
    /// - returns: A request.
    public func with<T>(_ cte: CommonTableExpression<T>) -> QueryInterfaceRequest<RowDecoder> {
        all().with(cte)
    }
}

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6, *)
extension Table where RowDecoder: Identifiable, RowDecoder.ID: DatabaseValueConvertible {
    /// Creates a request filtered by primary key.
    ///
    ///     // SELECT * FROM player WHERE id = 1
    ///     let table = Table<Player>("player")
    ///     let request = table.filter(id: 1)
    ///
    /// - parameter id: A primary key
    public func filter(id: RowDecoder.ID) -> QueryInterfaceRequest<RowDecoder> {
        all().filter(id: id)
    }
    
    /// Creates a request filtered by primary key.
    ///
    ///     // SELECT * FROM player WHERE id IN (1, 2, 3)
    ///     let table = Table<Player>("player")
    ///     let request = table.filter(ids: [1, 2, 3])
    ///
    /// - parameter ids: A collection of primary keys
    public func filter<Collection>(ids: Collection)
    -> QueryInterfaceRequest<RowDecoder>
    where Collection: Swift.Collection, Collection.Element == RowDecoder.ID
    {
        all().filter(ids: ids)
    }
    
    /// Creates a request which selects the primary key.
    ///
    ///     // SELECT id FROM player
    ///     let table = Table("player")
    ///     let request = try table.selectID()
    public func selectID() -> QueryInterfaceRequest<RowDecoder.ID> {
        all().selectID()
    }
}

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6, *)
extension Table
where RowDecoder: Identifiable,
      RowDecoder.ID: _OptionalProtocol,
      RowDecoder.ID.Wrapped: DatabaseValueConvertible
{
    /// Creates a request filtered by primary key.
    ///
    ///     // SELECT * FROM player WHERE id = 1
    ///     let table = Table<Player>("player")
    ///     let request = table.filter(id: 1)
    ///
    /// - parameter id: A primary key
    public func filter(id: RowDecoder.ID.Wrapped) -> QueryInterfaceRequest<RowDecoder> {
        all().filter(id: id)
    }
    
    /// Creates a request filtered by primary key.
    ///
    ///     // SELECT * FROM player WHERE id IN (1, 2, 3)
    ///     let table = Table<Player>("player")
    ///     let request = table.filter(ids: [1, 2, 3])
    ///
    /// - parameter ids: A collection of primary keys
    public func filter<Collection>(ids: Collection)
    -> QueryInterfaceRequest<RowDecoder>
    where Collection: Swift.Collection, Collection.Element == RowDecoder.ID.Wrapped
    {
        all().filter(ids: ids)
    }
    
    /// Creates a request which selects the primary key.
    ///
    ///     // SELECT id FROM player
    ///     let table = Table("player")
    ///     let request = try table.selectID()
    public func selectID() -> QueryInterfaceRequest<RowDecoder.ID.Wrapped> {
        all().selectID()
    }
}

extension Table {
    
    // MARK: - Counting All
    
    /// The number of rows.
    ///
    /// - parameter db: A database connection.
    public func fetchCount(_ db: Database) throws -> Int {
        try all().fetchCount(db)
    }
}

// MARK: - Fetching Records from Table

extension Table where RowDecoder: FetchableRecord {
    /// A cursor over all records fetched from the database.
    ///
    ///     // SELECT * FROM player
    ///     let table = Table<Player>("player")
    ///     let players = try table.fetchCursor(db) // Cursor of Player
    ///     while let player = try players.next() {  // Player
    ///         ...
    ///     }
    ///
    /// Records are iterated in the natural ordering of the table.
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// The cursor must be iterated in a protected dispatch queue.
    ///
    /// - parameter db: A database connection.
    /// - returns: A cursor over fetched records.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchCursor(_ db: Database) throws -> RecordCursor<RowDecoder> {
        try all().fetchCursor(db)
    }
    
    /// An array of all records fetched from the database.
    ///
    ///     // SELECT * FROM player
    ///     let table = Table<Player>("player")
    ///     let players = try table.fetchAll(db) // [Player]
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchAll(_ db: Database) throws -> [RowDecoder] {
        try all().fetchAll(db)
    }
    
    /// The first found record.
    ///
    ///     // SELECT * FROM player LIMIT 1
    ///     let table = Table<Player>("player")
    ///     let player = try table.fetchOne(db) // Player?
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchOne(_ db: Database) throws -> RowDecoder? {
        try all().fetchOne(db)
    }
}

extension Table where RowDecoder: FetchableRecord & Hashable {
    /// A set of all records fetched from the database.
    ///
    ///     // SELECT * FROM player
    ///     let table = Table<Player>("player")
    ///     let players = try table.fetchSet(db) // Set<Player>
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchSet(_ db: Database) throws -> Set<RowDecoder> {
        try all().fetchSet(db)
    }
}

// MARK: - Fetching Rows from Table

extension Table where RowDecoder == Row {
    /// A cursor over all rows fetched from the database.
    ///
    ///     // SELECT * FROM player
    ///     let table = Table("player")
    ///     let rows = try table.fetchCursor(db) // Cursor of Row
    ///     while let row = try rows.next() {    // Row
    ///         ...
    ///     }
    ///
    /// Rows are iterated in the natural ordering of the table.
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// The cursor must be iterated in a protected dispatch queue.
    ///
    /// - parameter db: A database connection.
    /// - returns: A cursor over fetched records.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchCursor(_ db: Database) throws -> RowCursor {
        try all().fetchCursor(db)
    }
    
    /// An array of all rows fetched from the database.
    ///
    ///     // SELECT * FROM player
    ///     let table = Table("player")
    ///     let players = try table.fetchAll(db) // [Row]
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchAll(_ db: Database) throws -> [Row] {
        try all().fetchAll(db)
    }
    
    /// The first found row.
    ///
    ///     // SELECT * FROM player LIMIT 1
    ///     let table = Table("player")
    ///     let row = try table.fetchOne(db) // Row?
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchOne(_ db: Database) throws -> Row? {
        try all().fetchOne(db)
    }
    
    /// A set of all rows fetched from the database.
    ///
    ///     // SELECT * FROM player
    ///     let table = Table("player")
    ///     let rows = try table.fetchSet(db) // Set<Row>
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchSet(_ db: Database) throws -> Set<Row> {
        try all().fetchSet(db)
    }
}

// MARK: - Fetching Values from Table

extension Table where RowDecoder: DatabaseValueConvertible {
    /// A cursor over all values fetched from the leftmost column.
    ///
    ///     // SELECT * FROM name
    ///     let table = Table<String>("name")
    ///     let names = try table.fetchCursor(db) // Cursor of String
    ///     while let name = try names.next() {   // String
    ///         ...
    ///     }
    ///
    /// Values are iterated in the natural ordering of the table.
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// The cursor must be iterated in a protected dispatch queue.
    ///
    /// - parameter db: A database connection.
    /// - returns: A cursor over fetched records.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchCursor(_ db: Database) throws -> DatabaseValueCursor<RowDecoder> {
        try all().fetchCursor(db)
    }
    
    /// An array of all values fetched from the leftmost column.
    ///
    ///     // SELECT * FROM name
    ///     let table = Table<String>("name")
    ///     let names = try table.fetchAll(db) // [String]
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchAll(_ db: Database) throws -> [RowDecoder] {
        try all().fetchAll(db)
    }
    
    /// The value from the leftmost column of the first row.
    ///
    ///     // SELECT * FROM name LIMIT 1
    ///     let table = Table<String>("name")
    ///     let name = try table.fetchOne(db) // String?
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchOne(_ db: Database) throws -> RowDecoder? {
        try all().fetchOne(db)
    }
}

extension Table where RowDecoder: DatabaseValueConvertible & Hashable {
    /// A set of all values fetched from the leftmost column.
    ///
    ///     // SELECT * FROM name
    ///     let table = Table<String>("name")
    ///     let names = try table.fetchSet(db) // Set<String>
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchSet(_ db: Database) throws -> Set<RowDecoder> {
        try all().fetchSet(db)
    }
}

extension Table where RowDecoder: _OptionalProtocol, RowDecoder.Wrapped: DatabaseValueConvertible {
    /// A cursor over all values fetched from the leftmost column.
    ///
    ///     // SELECT * FROM name
    ///     let table = Table<String?>("name")
    ///     let names = try table.fetchCursor(db) // Cursor of String?
    ///     while let name = try names.next() {   // String?
    ///         ...
    ///     }
    ///
    /// Values are iterated in the natural ordering of the table.
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// The cursor must be iterated in a protected dispatch queue.
    ///
    /// - parameter db: A database connection.
    /// - returns: A cursor over fetched records.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchCursor(_ db: Database) throws -> NullableDatabaseValueCursor<RowDecoder.Wrapped> {
        try all().fetchCursor(db)
    }
    
    /// An array of all values fetched from the leftmost column.
    ///
    ///     // SELECT * FROM name
    ///     let table = Table<String?>("name")
    ///     let names = try table.fetchAll(db) // [String?]
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchAll(_ db: Database) throws -> [RowDecoder.Wrapped?] {
        try all().fetchAll(db)
    }
    
    /// The value from the leftmost column of the first row.
    ///
    ///     // SELECT * FROM name LIMIT 1
    ///     let table = Table<String?>("name")
    ///     let name = try table.fetchOne(db) // String?
    ///
    /// The result is nil if the query returns no row, or if no value can be
    /// extracted from the first row.
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchOne(_ db: Database) throws -> RowDecoder.Wrapped? {
        try all().fetchOne(db)
    }
}

extension Table where RowDecoder: _OptionalProtocol, RowDecoder.Wrapped: DatabaseValueConvertible & Hashable {
    /// A set of all values fetched from the leftmost column.
    ///
    ///     // SELECT * FROM name
    ///     let table = Table<String?>("name")
    ///     let names = try table.fetchSet(db) // Set<String?>
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchSet(_ db: Database) throws -> Set<RowDecoder.Wrapped?> {
        try all().fetchSet(db)
    }
}

// MARK: - Fetching Fast Values from Table

extension Table where RowDecoder: DatabaseValueConvertible & StatementColumnConvertible {
    /// A cursor over all values fetched from the leftmost column.
    ///
    ///     // SELECT * FROM name
    ///     let table = Table<String>("name")
    ///     let names = try table.fetchCursor(db) // Cursor of String
    ///     while let name = try names.next() {   // String
    ///         ...
    ///     }
    ///
    /// Values are iterated in the natural ordering of the table.
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// The cursor must be iterated in a protected dispatch queue.
    ///
    /// - parameter db: A database connection.
    /// - returns: A cursor over fetched records.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchCursor(_ db: Database) throws -> FastDatabaseValueCursor<RowDecoder> {
        try all().fetchCursor(db)
    }
    
    /// An array of all values fetched from the leftmost column.
    ///
    ///     // SELECT * FROM name
    ///     let table = Table<String>("name")
    ///     let names = try table.fetchAll(db) // [String]
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchAll(_ db: Database) throws -> [RowDecoder] {
        try all().fetchAll(db)
    }
    
    /// The value from the leftmost column of the first row.
    ///
    ///     // SELECT * FROM name LIMIT 1
    ///     let table = Table<String>("name")
    ///     let name = try table.fetchOne(db) // String?
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchOne(_ db: Database) throws -> RowDecoder? {
        try all().fetchOne(db)
    }
}

extension Table where RowDecoder: DatabaseValueConvertible & StatementColumnConvertible & Hashable {
    /// A set of all values fetched from the leftmost column.
    ///
    ///     // SELECT * FROM name
    ///     let table = Table<String>("name")
    ///     let names = try table.fetchSet(db) // Set<String>
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchSet(_ db: Database) throws -> Set<RowDecoder> {
        try all().fetchSet(db)
    }
}

extension Table
where RowDecoder: _OptionalProtocol,
      RowDecoder.Wrapped: DatabaseValueConvertible & StatementColumnConvertible
{
    /// A cursor over all values fetched from the leftmost column.
    ///
    ///     // SELECT * FROM name
    ///     let table = Table<String?>("name")
    ///     let names = try table.fetchCursor(db) // Cursor of String?
    ///     while let name = try names.next() {   // String?
    ///         ...
    ///     }
    ///
    /// Values are iterated in the natural ordering of the table.
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// The cursor must be iterated in a protected dispatch queue.
    ///
    /// - parameter db: A database connection.
    /// - returns: A cursor over fetched records.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchCursor(_ db: Database) throws -> FastNullableDatabaseValueCursor<RowDecoder.Wrapped> {
        try all().fetchCursor(db)
    }
    
    /// An array of all values fetched from the leftmost column.
    ///
    ///     // SELECT * FROM name
    ///     let table = Table<String?>("name")
    ///     let names = try table.fetchAll(db) // [String?]
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchAll(_ db: Database) throws -> [RowDecoder.Wrapped?] {
        try all().fetchAll(db)
    }
    
    /// The value from the leftmost column of the first row.
    ///
    ///     // SELECT * FROM name LIMIT 1
    ///     let table = Table<String?>("name")
    ///     let name = try table.fetchOne(db) // String?
    ///
    /// The result is nil if the query returns no row, or if no value can be
    /// extracted from the first row.
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchOne(_ db: Database) throws -> RowDecoder.Wrapped? {
        try all().fetchOne(db)
    }
}

extension Table
where RowDecoder: _OptionalProtocol,
      RowDecoder.Wrapped: DatabaseValueConvertible & StatementColumnConvertible & Hashable
{
    /// A set of all values fetched from the leftmost column.
    ///
    ///     // SELECT * FROM name
    ///     let table = Table<String?>("name")
    ///     let names = try table.fetchSet(db) // Set<String?>
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public func fetchSet(_ db: Database) throws -> Set<RowDecoder.Wrapped?> {
        try all().fetchSet(db)
    }
}

// MARK: - Associations to TableRecord

extension Table {
    /// Creates a "Belongs To" association between Self and the destination
    /// type, based on a database foreign key.
    ///
    /// For more information, see `TableRecord.belongsTo(_:key:using:)`.
    ///
    /// - parameters:
    ///     - destination: The record type at the other side of the association.
    ///     - key: An eventual decoding key for the association. By default, it
    ///       is `destination.databaseTableName`.
    ///     - foreignKey: An eventual foreign key. You need to provide an
    ///       explicit foreign key when GRDB can't infer one from the database
    ///       schema. This happens when the schema does not define any foreign
    ///       key to the destination table, or when the schema defines several
    ///       foreign keys to the destination table.
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
    
    /// Creates a "Has many" association between Self and the destination type,
    /// based on a database foreign key.
    ///
    /// For more information, see `TableRecord.hasMany(_:key:using:)`.
    ///
    /// - parameters:
    ///     - destination: The record type at the other side of the association.
    ///     - key: An eventual decoding key for the association. By default, it
    ///       is `destination.databaseTableName`.
    ///     - foreignKey: An eventual foreign key. You need to provide an
    ///       explicit foreign key when GRDB can't infer one from the database
    ///       schema. This happens when the schema does not define any foreign
    ///       key from the destination table, or when the schema defines several
    ///       foreign keys from the destination table.
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
    
    /// Creates a "Has one" association between Self and the destination type,
    /// based on a database foreign key.
    ///
    /// For more information, see `TableRecord.hasOne(_:key:using:)`.
    ///
    /// - parameters:
    ///     - destination: The record type at the other side of the association.
    ///     - key: An eventual decoding key for the association. By default, it
    ///       is `destination.databaseTableName`.
    ///     - foreignKey: An eventual foreign key. You need to provide an
    ///       explicit foreign key when GRDB can't infer one from the database
    ///       schema. This happens when the schema does not define any foreign
    ///       key from the destination table, or when the schema defines several
    ///       foreign keys from the destination table.
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
    /// Creates a "Belongs To" association between Self and the destination
    /// table, based on a database foreign key.
    ///
    /// For more information, see `TableRecord.belongsTo(_:key:using:)`.
    ///
    /// - parameters:
    ///     - destination: The table at the other side of the association.
    ///     - key: An eventual decoding key for the association. By default, it
    ///       is `destination.tableName`.
    ///     - foreignKey: An eventual foreign key. You need to provide an
    ///       explicit foreign key when GRDB can't infer one from the database
    ///       schema. This happens when the schema does not define any foreign
    ///       key to the destination table, or when the schema defines several
    ///       foreign keys to the destination table.
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
    
    /// Creates a "Has many" association between Self and the destination table,
    /// based on a database foreign key.
    ///
    /// For more information, see `TableRecord.hasMany(_:key:using:)`.
    ///
    /// - parameters:
    ///     - destination: The table at the other side of the association.
    ///     - key: An eventual decoding key for the association. By default, it
    ///       is `destination.tableName`.
    ///     - foreignKey: An eventual foreign key. You need to provide an
    ///       explicit foreign key when GRDB can't infer one from the database
    ///       schema. This happens when the schema does not define any foreign
    ///       key from the destination table, or when the schema defines several
    ///       foreign keys from the destination table.
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
    
    /// Creates a "Has one" association between Self and the destination table,
    /// based on a database foreign key.
    ///
    /// For more information, see `TableRecord.hasOne(_:key:using:)`.
    ///
    /// - parameters:
    ///     - destination: The table at the other side of the association.
    ///     - key: An eventual decoding key for the association. By default, it
    ///       is `destination.databaseTableName`.
    ///     - foreignKey: An eventual foreign key. You need to provide an
    ///       explicit foreign key when GRDB can't infer one from the database
    ///       schema. This happens when the schema does not define any foreign
    ///       key from the destination table, or when the schema defines several
    ///       foreign keys from the destination table.
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
    /// Creates an association to a common table expression that you can join
    /// or include in another request.
    ///
    /// For more information, see `TableRecord.association(to:on:)`.
    ///
    /// - parameter cte: A common table expression.
    /// - parameter condition: A function that returns the joining clause.
    /// - parameter left: A `TableAlias` for the left table.
    /// - parameter right: A `TableAlias` for the right table.
    /// - returns: An association to the common table expression.
    public func association<Destination>(
        to cte: CommonTableExpression<Destination>,
        on condition: @escaping (_ left: TableAlias, _ right: TableAlias) -> SQLExpressible)
    -> JoinAssociation<RowDecoder, Destination>
    {
        JoinAssociation(
            to: cte.relationForAll,
            condition: .expression { condition($0, $1).sqlExpression })
    }
    
    /// Creates an association to a common table expression that you can join
    /// or include in another request.
    ///
    /// The key of the returned association is the table name of the common
    /// table expression.
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
    /// Creates a "Has Many Through" association between Self and the
    /// destination type.
    ///
    /// For more information, see `TableRecord.hasMany(_:through:using:key:)`.
    ///
    /// - parameters:
    ///     - destination: The record type at the other side of the association.
    ///     - pivot: An association from Self to the intermediate type.
    ///     - target: A target association from the intermediate type to the
    ///       destination type.
    ///     - key: An eventual decoding key for the association. By default, it
    ///       is the same key as the target.
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
        let association = HasManyThroughAssociation<RowDecoder, Target.RowDecoder>(
            _sqlAssociation: target._sqlAssociation.through(pivot._sqlAssociation))
        
        if let key = key {
            return association.forKey(key)
        } else {
            return association
        }
    }
    
    /// Creates a "Has One Through" association between Self and the
    /// destination type.
    ///
    /// For more information, see `TableRecord.hasOne(_:through:using:key:)`.
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
        let association = HasOneThroughAssociation<RowDecoder, Target.RowDecoder>(
            _sqlAssociation: target._sqlAssociation.through(pivot._sqlAssociation))
        
        if let key = key {
            return association.forKey(key)
        } else {
            return association
        }
    }
}

// MARK: - Joining Methods

extension Table {
    /// Creates a request that prefetches an association.
    public func including<A: AssociationToMany>(all association: A)
    -> QueryInterfaceRequest<RowDecoder>
    where A.OriginRowDecoder == RowDecoder
    {
        all().including(all: association)
    }
    
    /// Creates a request that includes an association. The columns of the
    /// associated record are selected. The returned association does not
    /// require that the associated database table contains a matching row.
    public func including<A: Association>(optional association: A)
    -> QueryInterfaceRequest<RowDecoder>
    where A.OriginRowDecoder == RowDecoder
    {
        all().including(optional: association)
    }
    
    /// Creates a request that includes an association. The columns of the
    /// associated record are selected. The returned association requires
    /// that the associated database table contains a matching row.
    public func including<A: Association>(required association: A)
    -> QueryInterfaceRequest<RowDecoder>
    where A.OriginRowDecoder == RowDecoder
    {
        all().including(required: association)
    }
    
    /// Creates a request that includes an association. The columns of the
    /// associated record are not selected. The returned association does not
    /// require that the associated database table contains a matching row.
    public func joining<A: Association>(optional association: A)
    -> QueryInterfaceRequest<RowDecoder>
    where A.OriginRowDecoder == RowDecoder
    {
        all().joining(optional: association)
    }
    
    /// Creates a request that includes an association. The columns of the
    /// associated record are not selected. The returned association requires
    /// that the associated database table contains a matching row.
    public func joining<A: Association>(required association: A)
    -> QueryInterfaceRequest<RowDecoder>
    where A.OriginRowDecoder == RowDecoder
    {
        all().joining(required: association)
    }
    
    /// Creates a request which appends *columns of an associated record* to
    /// the columns of the table.
    ///
    ///     let playerTable = Table("player")
    ///     let teamTable = Table("team")
    ///     let playerTeam = playerTable.belongsTo(teamTable)
    ///
    ///     // SELECT player.*, team.color
    ///     // FROM player LEFT JOIN team ...
    ///     let teamColor = playerTeam.select(Column("color")
    ///     let request = playerTable.annotated(withOptional: teamColor))
    ///
    /// This method performs the same SQL request as `including(optional:)`.
    /// The difference is in the shape of Decodable records that decode such
    /// a request: the associated columns can be decoded at the same level as
    /// the main record:
    ///
    ///     struct PlayerWithTeamColor: FetchableRecord, Decodable {
    ///         var player: Player
    ///         var color: String?
    ///     }
    ///     let players = try dbQueue.read { db in
    ///         try request
    ///             .asRequest(of: PlayerWithTeamColor.self)
    ///             .fetchAll(db)
    ///     }
    ///
    /// Note: this is a convenience method. You can build the same request with
    /// `TableAlias`, `annotated(with:)`, and `joining(optional:)`:
    ///
    ///     let teamAlias = TableAlias()
    ///     let request = playerTable
    ///         .annotated(with: teamAlias[Column("color")])
    ///         .joining(optional: playerTeam.aliased(teamAlias))
    public func annotated<A: Association>(withOptional association: A)
    -> QueryInterfaceRequest<RowDecoder>
    where A.OriginRowDecoder == RowDecoder
    {
        all().annotated(withOptional: association)
    }
    
    /// Creates a request which appends *columns of an associated record* to
    /// the columns of the table.
    ///
    ///     let playerTable = Table("player")
    ///     let teamTable = Table("team")
    ///     let playerTeam = playerTable.belongsTo(teamTable)
    ///
    ///     // SELECT player.*, team.color
    ///     // FROM player JOIN team ...
    ///     let teamColor = playerTeam.select(Column("color")
    ///     let request = playerTable.annotated(withRequired: teamColor))
    ///
    /// This method performs the same SQL request as `including(required:)`.
    /// The difference is in the shape of Decodable records that decode such
    /// a request: the associated columns can be decoded at the same level as
    /// the main record:
    ///
    ///     struct PlayerWithTeamColor: FetchableRecord, Decodable {
    ///         var player: Player
    ///         var color: String
    ///     }
    ///     let players = try dbQueue.read { db in
    ///         try request
    ///             .asRequest(of: PlayerWithTeamColor.self)
    ///             .fetchAll(db)
    ///     }
    ///
    /// Note: this is a convenience method. You can build the same request with
    /// `TableAlias`, `annotated(with:)`, and `joining(required:)`:
    ///
    ///     let teamAlias = TableAlias()
    ///     let request = playerTable
    ///         .annotated(with: teamAlias[Column("color")])
    ///         .joining(required: playerTeam.aliased(teamAlias))
    public func annotated<A: Association>(withRequired association: A)
    -> QueryInterfaceRequest<RowDecoder>
    where A.OriginRowDecoder == RowDecoder
    {
        all().annotated(withRequired: association)
    }
}

// MARK: - Association Aggregates

extension Table {
    /// Creates a request with *aggregates* appended to the selection.
    ///
    ///     // SELECT player.*, COUNT(DISTINCT book.id) AS bookCount
    ///     // FROM player LEFT JOIN book ...
    ///     let table = Table<Player>("player")
    ///     let request = table.annotated(with: Player.books.count)
    public func annotated(with aggregates: AssociationAggregate<RowDecoder>...) -> QueryInterfaceRequest<RowDecoder> {
        all().annotated(with: aggregates)
    }
    
    /// Creates a request with *aggregates* appended to the selection.
    ///
    ///     // SELECT player.*, COUNT(DISTINCT book.id) AS bookCount
    ///     // FROM player LEFT JOIN book ...
    ///     let table = Table<Player>("player")
    ///     let request = table.annotated(with: [Player.books.count])
    public func annotated(with aggregates: [AssociationAggregate<RowDecoder>]) -> QueryInterfaceRequest<RowDecoder> {
        all().annotated(with: aggregates)
    }
    
    /// Creates a request with the provided aggregate *predicate*.
    ///
    ///     // SELECT player.*
    ///     // FROM player LEFT JOIN book ...
    ///     // HAVING COUNT(DISTINCT book.id) = 0
    ///     let table = Table<Player>("player")
    ///     var request = table.all()
    ///     request = request.having(Player.books.isEmpty)
    ///
    /// The selection defaults to all columns. This default can be changed for
    /// all requests by the `TableRecord.databaseSelection` property, or
    /// for individual requests with the `TableRecord.select` method.
    public func having(_ predicate: AssociationAggregate<RowDecoder>) -> QueryInterfaceRequest<RowDecoder> {
        all().having(predicate)
    }
}

// MARK: - Batch Delete

extension Table {
    /// Deletes all rows; returns the number of deleted rows.
    ///
    /// - parameter db: A database connection.
    /// - returns: The number of deleted rows
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    @discardableResult
    public func deleteAll(_ db: Database) throws -> Int {
        try all().deleteAll(db)
    }
}

// MARK: - Check Existence by Single-Column Primary Key

extension Table {
    /// Returns whether a row exists for this primary key.
    ///
    ///     try Table("player").exists(db, key: 123)
    ///     try Table("country").exists(db, key: "FR")
    ///
    /// When the table has no explicit primary key, GRDB uses the hidden
    /// "rowid" column:
    ///
    ///     try Table("document").exists(db, key: 1)
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - key: A primary key value.
    /// - returns: Whether a row exists for this primary key.
    public func exists<PrimaryKeyType>(_ db: Database, key: PrimaryKeyType)
    throws -> Bool
    where PrimaryKeyType: DatabaseValueConvertible
    {
        try !filter(key: key).isEmpty(db)
    }
}

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6, *)
extension Table
where RowDecoder: Identifiable,
      RowDecoder.ID: DatabaseValueConvertible
{
    /// Returns whether a row exists for this primary key.
    ///
    ///     try Table<Player>("player").exists(db, id: 123)
    ///     try Table<Country>("player").exists(db, id: "FR")
    ///
    /// When the table has no explicit primary key, GRDB uses the hidden
    /// "rowid" column:
    ///
    ///     try Table<Document>("document").exists(db, id: 1)
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - id: A primary key value.
    /// - returns: Whether a row exists for this primary key.
    public func exists(_ db: Database, id: RowDecoder.ID) throws -> Bool {
        try !filter(id: id).isEmpty(db)
    }
}

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6, *)
extension Table
where RowDecoder: Identifiable,
      RowDecoder.ID: _OptionalProtocol,
      RowDecoder.ID.Wrapped: DatabaseValueConvertible
{
    /// Returns whether a row exists for this primary key.
    ///
    ///     try Table<Player>("player").exists(db, id: 123)
    ///     try Table<Country>("country").exists(db, id: "FR")
    ///
    /// When the table has no explicit primary key, GRDB uses the hidden
    /// "rowid" column:
    ///
    ///     try Table<Document>("document").exists(db, id: 1)
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - id: A primary key value.
    /// - returns: Whether a row exists for this primary key.
    public func exists(_ db: Database, id: RowDecoder.ID.Wrapped) throws -> Bool {
        try !filter(id: id).isEmpty(db)
    }
}

// MARK: - Check Existence by Key

extension Table {
    /// Returns whether a row exists for this unique key (primary key or any key
    /// with a unique index on it).
    ///
    ///     Table("player").exists(db, key: ["name": Arthur"])
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - key: A dictionary of values.
    /// - returns: Whether a row exists for this key.
    public func exists(_ db: Database, key: [String: DatabaseValueConvertible?]) throws -> Bool {
        try !filter(key: key).isEmpty(db)
    }
}

// MARK: - Deleting by Single-Column Primary Key

extension Table {
    /// Delete rows identified by their primary keys; returns the number of
    /// deleted rows.
    ///
    ///     // DELETE FROM player WHERE id IN (1, 2, 3)
    ///     try Table("player").deleteAll(db, keys: [1, 2, 3])
    ///
    ///     // DELETE FROM country WHERE code IN ('FR', 'US', 'DE')
    ///     try Table("country").deleteAll(db, keys: ["FR", "US", "DE"])
    ///
    /// When the table has no explicit primary key, GRDB uses the hidden
    /// "rowid" column:
    ///
    ///     // DELETE FROM document WHERE rowid IN (1, 2, 3)
    ///     try Table("document").deleteAll(db, keys: [1, 2, 3])
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - keys: A sequence of primary keys.
    /// - returns: The number of deleted rows
    @discardableResult
    public func deleteAll<Sequence>(_ db: Database, keys: Sequence)
    throws -> Int
    where Sequence: Swift.Sequence, Sequence.Element: DatabaseValueConvertible
    {
        let keys = Array(keys)
        if keys.isEmpty {
            // Avoid hitting the database
            return 0
        }
        return try filter(keys: keys).deleteAll(db)
    }
    
    /// Delete a row, identified by its primary key; returns whether a
    /// database row was deleted.
    ///
    ///     // DELETE FROM player WHERE id = 123
    ///     try Table("player").deleteOne(db, key: 123)
    ///
    ///     // DELETE FROM country WHERE code = 'FR'
    ///     try Table("country").deleteOne(db, key: "FR")
    ///
    /// When the table has no explicit primary key, GRDB uses the hidden
    /// "rowid" column:
    ///
    ///     // DELETE FROM document WHERE rowid = 1
    ///     try Table("document").deleteOne(db, key: 1)
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - key: A primary key value.
    /// - returns: Whether a database row was deleted.
    @discardableResult
    public func deleteOne<PrimaryKeyType>(_ db: Database, key: PrimaryKeyType?)
    throws -> Bool
    where PrimaryKeyType: DatabaseValueConvertible
    {
        guard let key = key else {
            // Avoid hitting the database
            return false
        }
        return try deleteAll(db, keys: [key]) > 0
    }
}

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6, *)
extension Table
where RowDecoder: Identifiable,
      RowDecoder.ID: DatabaseValueConvertible
{
    /// Delete rows identified by their primary keys; returns the number of
    /// deleted rows.
    ///
    ///     // DELETE FROM player WHERE id IN (1, 2, 3)
    ///     try Table<Player>("player").deleteAll(db, ids: [1, 2, 3])
    ///
    ///     // DELETE FROM country WHERE code IN ('FR', 'US', 'DE')
    ///     try Table<Country>("country").deleteAll(db, ids: ["FR", "US", "DE"])
    ///
    /// When the table has no explicit primary key, GRDB uses the hidden
    /// "rowid" column:
    ///
    ///     // DELETE FROM document WHERE rowid IN (1, 2, 3)
    ///     try Table<Document>("document").deleteAll(db, ids: [1, 2, 3])
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - ids: A collection of primary keys.
    /// - returns: The number of deleted rows
    @discardableResult
    public func deleteAll<Collection>(_ db: Database, ids: Collection)
    throws -> Int
    where Collection: Swift.Collection, Collection.Element == RowDecoder.ID
    {
        if ids.isEmpty {
            // Avoid hitting the database
            return 0
        }
        return try filter(ids: ids).deleteAll(db)
    }
    
    /// Delete a row, identified by its primary key; returns whether a
    /// database row was deleted.
    ///
    ///     // DELETE FROM player WHERE id = 123
    ///     try Table<Player>("player").deleteOne(db, id: 123)
    ///
    ///     // DELETE FROM country WHERE code = 'FR'
    ///     try Table<Country>("country").deleteOne(db, id: "FR")
    ///
    /// When the table has no explicit primary key, GRDB uses the hidden
    /// "rowid" column:
    ///
    ///     // DELETE FROM document WHERE rowid = 1
    ///     try Table<Document>("document").deleteOne(db, id: 1)
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - id: A primary key value.
    /// - returns: Whether a database row was deleted.
    @discardableResult
    public func deleteOne(_ db: Database, id: RowDecoder.ID) throws -> Bool {
        try deleteAll(db, ids: [id]) > 0
    }
}

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6, *)
extension Table
where RowDecoder: Identifiable,
      RowDecoder.ID: _OptionalProtocol,
      RowDecoder.ID.Wrapped: DatabaseValueConvertible
{
    /// Delete rows identified by their primary keys; returns the number of
    /// deleted rows.
    ///
    ///     // DELETE FROM player WHERE id IN (1, 2, 3)
    ///     try Table<Player>("player").deleteAll(db, ids: [1, 2, 3])
    ///
    ///     // DELETE FROM country WHERE code IN ('FR', 'US', 'DE')
    ///     try Table<Country>("country").deleteAll(db, ids: ["FR", "US", "DE"])
    ///
    /// When the table has no explicit primary key, GRDB uses the hidden
    /// "rowid" column:
    ///
    ///     // DELETE FROM document WHERE rowid IN (1, 2, 3)
    ///     try Table<Document>("document").deleteAll(db, ids: [1, 2, 3])
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - ids: A collection of primary keys.
    /// - returns: The number of deleted rows
    @discardableResult
    public func deleteAll<Collection>(_ db: Database, ids: Collection)
    throws -> Int
    where Collection: Swift.Collection, Collection.Element == RowDecoder.ID.Wrapped
    {
        if ids.isEmpty {
            // Avoid hitting the database
            return 0
        }
        return try filter(ids: ids).deleteAll(db)
    }
    
    /// Delete a row, identified by its primary key; returns whether a
    /// database row was deleted.
    ///
    ///     // DELETE FROM player WHERE id = 123
    ///     try Table<Player>("player").deleteOne(db, id: 123)
    ///
    ///     // DELETE FROM country WHERE code = 'FR'
    ///     try Table<Country>("country").deleteOne(db, id: "FR")
    ///
    /// When the table has no explicit primary key, GRDB uses the hidden
    /// "rowid" column:
    ///
    ///     // DELETE FROM document WHERE rowid = 1
    ///     try Table<Document>("document").deleteOne(db, id: 1)
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - id: A primary key value.
    /// - returns: Whether a database row was deleted.
    @discardableResult
    public func deleteOne(_ db: Database, id: RowDecoder.ID.Wrapped) throws -> Bool {
        try deleteAll(db, ids: [id]) > 0
    }
}

// MARK: - Deleting by Key

extension Table {
    /// Delete rows identified by the provided unique keys (primary key or
    /// any key with a unique index on it); returns the number of deleted rows.
    ///
    ///     try Table("player").deleteAll(db, keys: [["email": "a@example.com"], ["email": "b@example.com"]])
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - keys: An array of key dictionaries.
    /// - returns: The number of deleted rows
    @discardableResult
    public func deleteAll(_ db: Database, keys: [[String: DatabaseValueConvertible?]]) throws -> Int {
        if keys.isEmpty {
            // Avoid hitting the database
            return 0
        }
        return try filter(keys: keys).deleteAll(db)
    }
    
    /// Delete a row, identified by a unique key (the primary key or any key
    /// with a unique index on it); returns whether a database row was deleted.
    ///
    ///     Table("player").deleteOne(db, key: ["name": Arthur"])
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - key: A dictionary of values.
    /// - returns: Whether a database row was deleted.
    @discardableResult
    public func deleteOne(_ db: Database, key: [String: DatabaseValueConvertible?]) throws -> Bool {
        try deleteAll(db, keys: [key]) > 0
    }
}

// MARK: - Batch Update

extension Table {
    /// Updates all rows; returns the number of updated rows.
    ///
    /// For example:
    ///
    ///     try dbQueue.write { db in
    ///         // UPDATE player SET score = 0
    ///         try Table("player").updateAll(db, [Column("score").set(to: 0)])
    ///     }
    ///
    /// - parameter db: A database connection.
    /// - parameter conflictResolution: A policy for conflict resolution.
    /// - parameter assignments: An array of column assignments.
    /// - returns: The number of updated rows.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    @discardableResult
    public func updateAll(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution? = nil,
        _ assignments: [ColumnAssignment])
    throws -> Int
    {
        try all().updateAll(db, onConflict: conflictResolution, assignments)
    }
    
    /// Updates all rows; returns the number of updated rows.
    ///
    /// For example:
    ///
    ///     try dbQueue.write { db in
    ///         // UPDATE player SET score = 0
    ///         try Table("player").updateAll(db, Column("score").set(to: 0))
    ///     }
    ///
    /// - parameter db: A database connection.
    /// - parameter conflictResolution: A policy for conflict resolution.
    /// - parameter assignment: A column assignment.
    /// - parameter otherAssignments: Eventual other column assignments.
    /// - returns: The number of updated rows.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    @discardableResult
    public func updateAll(
        _ db: Database,
        onConflict conflictResolution: Database.ConflictResolution? = nil,
        _ assignment: ColumnAssignment,
        _ otherAssignments: ColumnAssignment...)
    throws -> Int
    {
        try updateAll(db, onConflict: conflictResolution, [assignment] + otherAssignments)
    }
}

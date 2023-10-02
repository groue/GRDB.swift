/// A JSON column in a database table.
///
/// ## Overview
///
/// `JSONColumn` has benefits over ``Column`` for database columns that
/// contain JSON strings.
///
/// It behaves like a regular `Column`, with all extra conveniences and
/// behaviors of ``SQLJSONExpressible``.
///
/// For example, the sample code below directly accesses the "countryCode"
/// key of the "address" JSON column:
///
/// ```swift
/// struct Player: Codable {
///     var id: Int64
///     var name: String
///     var address: Address
/// }
///
/// struct Address: Codable {
///     var street: String
///     var city: String
///     var countryCode: String
/// }
///
/// extension Player: FetchableRecord, PersistableRecord {
///     enum Columns {
///         static let id = Column(CodingKeys.id)
///         static let name = Column(CodingKeys.name)
///         static let address = JSONColumn(CodingKeys.address) // JSONColumn!
///     }
/// }
///
/// try dbQueue.write { db in
///     // In a real app, table creation should happen in a migration.
///     try db.create(table: "player") { t in
///         t.autoIncrementedPrimaryKey("id")
///         t.column("name", .text).notNull()
///         t.column("address", .jsonText).notNull()
///     }
///
///     // Fetch all country codes
///     // SELECT DISTINCT address ->> 'countryCode' FROM player
///     let countryCodes: [String] = try Player
///         .select(Player.Columns.address["countryCode"], as: String.self)
///         .distinct()
///         .fetchAll(db)
/// }
/// ```
///
/// > Tip: When you can not create a `JSONColumn`, you'll get the same
/// > convenient access to JSON subcomponents
/// > with ``SQLSpecificExpressible/asJSON``.
/// >
/// > For example, the above sample can be adapted as below:
/// >
/// > ```swift
/// > extension Player: FetchableRecord, PersistableRecord {
/// >     // That's another valid way to define columns.
/// >     // But we don't have any JSONColumn this time.
/// >     enum Columns: String, ColumnExpression {
/// >         case id, name, address
/// >     }
/// > }
/// >
/// > try dbQueue.write { db in
/// >     // Fetch all country codes
/// >     // SELECT DISTINCT address ->> 'countryCode' FROM player
/// >     let countryCodes: [String] = try Player
/// >         .select(Player.Columns.address.asJSON["countryCode"], as: String.self)
/// >         .distinct()
/// >         .fetchAll(db)
/// > }
/// > ```
public struct JSONColumn: ColumnExpression, SQLJSONExpressible {
    public var name: String
    
    /// Creates a `JSONColumn` given its name.
    ///
    /// The name should be unqualified, such as `"score"`. Qualified name such
    /// as `"player.score"` are unsupported.
    public init(_ name: String) {
        self.name = name
    }
    
    /// Creates a `JSONColumn` given a `CodingKey`.
    public init(_ codingKey: some CodingKey) {
        self.name = codingKey.stringValue
    }
}

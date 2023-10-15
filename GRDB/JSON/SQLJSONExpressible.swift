/// A type of SQL expression that is interpreted as a JSON value.
///
/// ## Overview
///
/// JSON values that conform to `SQLJSONExpressible` have two purposes:
///
/// - They provide Swift APIs for accessing their JSON subcomponents at
/// the SQL level.
///
/// - When used in a JSON-building function such as
///   ``Database/jsonArray(_:)-8xxe3`` or ``Database/jsonObject(_:)``,
///   they are parsed and interpreted as JSON, not as plain strings.
///
/// To build a JSON value, create a ``JSONColumn``, or call the
///  ``SQLSpecificExpressible/asJSON`` property of any
/// other expression.
///
/// For example, here are some JSON values:
///
/// ```swift
/// // JSON columns:
/// JSONColumn("info")
/// Column("info").asJSON
///
/// // The JSON array [1, 2, 3]:
/// "[1, 2, 3]".databaseValue.asJSON
///
/// // A JSON value that will trigger a
/// // "malformed JSON" SQLite error when
/// // parsed by SQLite:
/// "{foo".databaseValue.asJSON
/// ```
///
/// The expressions below are not JSON values:
///
/// ```swift
/// // A plain column:
/// Column("info")
///
/// // Plain strings:
/// "[1, 2, 3]"
/// "{foo"
/// ```
///
/// ## Access JSON subcomponents
///
/// JSON values provide access to the [`->` and `->>` SQL operators](https://www.sqlite.org/json1.html)
/// and other SQLite JSON functions:
///
/// ```swift
/// let info = JSONColumn("info")
///
/// // SELECT info ->> 'firstName' FROM player
/// // → 'Arthur'
/// let firstName = try Player
///     .select(info["firstName"], as: String.self)
///     .fetchOne(db)
///
/// // SELECT info ->> 'address' FROM player
/// // → '{"street":"Rue de Belleville","city":"Paris"}'
/// let address = try Player
///     .select(info["address"], as: String.self)
///     .fetchOne(db)
/// ```
///
/// ## Build JSON objects and arrays from JSON values
///
/// When used in a JSON-building function such as
/// ``Database/jsonArray(_:)-8xxe3`` or ``Database/jsonObject(_:)-5iswr``,
/// JSON values are parsed and interpreted as JSON, not as plain strings.
///
/// In the example below, we can see how the `JSONColumn` is interpreted as
/// JSON, while the `Column` with the same name is interpreted as a
/// plain string:
///
/// ```swift
/// let elements: [any SQLExpressible] = [
///     JSONColumn("address"),
///     Column("address"),
/// ]
///
/// let array = Database.jsonArray(elements)
///
/// // SELECT JSON_ARRAY(JSON(address), address) FROM player
/// // → '[{"country":"FR"},"{\"country\":\"FR\"}"]'
/// //     <--- object ---> <------ string ------>
/// let json = try Player
///     .select(array, as: String.self)
///     .fetchOne(db)
/// ```
///
/// ## Topics
///
/// ### Accessing JSON subcomponents
///
/// - ``subscript(_:)``
/// - ``jsonExtract(atPath:)``
/// - ``jsonExtract(atPaths:)``
/// - ``jsonRepresentation(atPath:)``
///
/// ### Supporting Types
///
/// - ``AnySQLJSONExpressible``
public protocol SQLJSONExpressible: SQLSpecificExpressible { }

extension ColumnExpression where Self: SQLJSONExpressible {
    /// Returns an SQL column that is interpreted as a JSON value.
    public var sqlExpression: SQLExpression {
        .column(name).withPreferredJSONInterpretation(.jsonValue)
    }
}

// This type only grants access to `SQLJSONExpressible` apis. The fact that
// it is a JSON value is embedded in its
// `sqlExpression.preferredJSONInterpretation`.
/// A type-erased ``SQLJSONExpressible``.
public struct AnySQLJSONExpressible: SQLJSONExpressible {
    /// An SQL expression that is interpreted as a JSON value.
    public let sqlExpression: SQLExpression
    
    public init(_ base: some SQLJSONExpressible) {
        self.init(sqlExpression: base.sqlExpression)
    }
    
    /// - Precondition: `sqlExpression` is a JSON value
    init(sqlExpression: SQLExpression) {
        assert(sqlExpression.preferredJSONInterpretation == .jsonValue)
        self.sqlExpression = sqlExpression
    }
}

extension SQLSpecificExpressible {
    /// Returns an expression that is interpreted as a JSON value.
    ///
    /// For example:
    ///
    /// ```swift
    /// let info = Column("info").asJSON
    ///
    /// // SELECT info ->> 'firstName' FROM player
    /// // → 'Arthur'
    /// let firstName = try Player
    ///     .select(info["firstName"], as: String.self)
    ///     .fetchOne(db)
    /// ```
    ///
    /// For more information, see ``SQLJSONExpressible``.
    public var asJSON: AnySQLJSONExpressible {
        AnySQLJSONExpressible(sqlExpression: sqlExpression.withPreferredJSONInterpretation(.jsonValue))
    }
}

#if GRDBCUSTOMSQLITE || GRDBCIPHER
extension SQLJSONExpressible {
    /// The `->>` SQL operator.
    ///
    /// For example:
    ///
    /// ```swift
    /// let info = JSONColumn("info")
    ///
    /// // SELECT info ->> 'firstName' FROM player
    /// // → 'Arthur'
    /// let firstName = try Player
    ///     .select(info["firstName"], as: String.self)
    ///     .fetchOne(db)
    ///
    /// // SELECT info ->> 'address' FROM player
    /// // → '{"street":"Rue de Belleville","city":"Paris"}'
    /// let address = try Player
    ///     .select(info["address"], as: String.self)
    ///     .fetchOne(db)
    /// ```
    ///
    /// Related SQL documentation: <https://www.sqlite.org/json1.html#jptr>
    ///
    /// - parameter path: A [JSON path](https://www.sqlite.org/json1.html#path_arguments),
    ///   or an JSON object field label, or an array index.
    public subscript(_ path: some SQLExpressible) -> SQLExpression {
        .binary(.jsonExtractSQL, sqlExpression, path.sqlExpression)
    }
    
    /// The `JSON_EXTRACT` SQL function.
    ///
    /// For example:
    ///
    /// ```swift
    /// let info = JSONColumn("info")
    ///
    /// // SELECT JSON_EXTRACT(info, '$.firstName') FROM player
    /// // → 'Arthur'
    /// let firstName = try Player
    ///     .select(info.jsonExtract(atPath: "$.firstName"), as: String.self)
    ///     .fetchOne(db)
    ///
    /// // SELECT JSON_EXTRACT(info, '$.address') FROM player
    /// // → '{"street":"Rue de Belleville","city":"Paris"}'
    /// let address = try Player
    ///     .select(info.jsonExtract(atPath: "$.address"), as: String.self)
    ///     .fetchOne(db)
    /// ```
    ///
    /// Related SQL documentation: <https://www.sqlite.org/json1.html#jex>
    ///
    /// - parameter path: A [JSON path](https://www.sqlite.org/json1.html#path_arguments).
    public func jsonExtract(atPath path: some SQLExpressible) -> SQLExpression {
        Database.jsonExtract(self, atPath: path)
    }
    
    /// The `JSON_EXTRACT` SQL function.
    ///
    /// For example:
    ///
    /// ```swift
    /// let info = JSONColumn("info")
    ///
    /// // SELECT JSON_EXTRACT(info, '$.firstName', '$.lastName') FROM player
    /// // → '["Arthur","Miller"]'
    /// let nameComponents = try Player
    ///     .select(info.jsonExtract(atPaths: ["$.firstName", "$.lastName"]), as: String.self)
    ///     .fetchOne(db)
    /// ```
    ///
    /// Related SQL documentation: <https://www.sqlite.org/json1.html#jex>
    ///
    /// - parameter paths: A collection of [JSON paths](https://www.sqlite.org/json1.html#path_arguments).
    public func jsonExtract<C>(atPaths paths: C) -> SQLExpression
    where C: Collection, C.Element: SQLExpressible
    {
        Database.jsonExtract(self, atPaths: paths)
    }
    
    /// Returns a valid JSON string with the `->` SQL operator.
    ///
    /// For example:
    ///
    /// ```swift
    /// let info = JSONColumn("info")
    ///
    /// // SELECT info -> 'firstName' FROM player
    /// // → '"Arthur"'
    /// let name = try Player
    ///     .select(info.jsonRepresentation(atPath: "firstName"), as: String.self)
    ///     .fetchOne(db)
    ///
    /// // SELECT info -> 'address' FROM player
    /// // → '{"street":"Rue de Belleville","city":"Paris"}'
    /// let name = try Player
    ///     .select(info.jsonRepresentation(atPath: "address"), as: String.self)
    ///     .fetchOne(db)
    /// ```
    ///
    /// Related SQL documentation: <https://www.sqlite.org/json1.html#jptr>
    ///
    /// - parameter path: A [JSON path](https://www.sqlite.org/json1.html#path_arguments),
    ///   or an JSON object field label, or an array index.
    public func jsonRepresentation(atPath path: some SQLExpressible) -> SQLExpression {
        .binary(.jsonExtractJSON, sqlExpression, path.sqlExpression)
    }
}
#else
extension SQLJSONExpressible {
    /// The `->>` SQL operator.
    ///
    /// For example:
    ///
    /// ```swift
    /// let info = JSONColumn("info")
    ///
    /// // SELECT info ->> 'firstName' FROM player
    /// // → 'Arthur'
    /// let firstName = try Player
    ///     .select(info["firstName"], as: String.self)
    ///     .fetchOne(db)
    ///
    /// // SELECT info ->> 'address' FROM player
    /// // → '{"street":"Rue de Belleville","city":"Paris"}'
    /// let address = try Player
    ///     .select(info["address"], as: String.self)
    ///     .fetchOne(db)
    /// ```
    ///
    /// Related SQL documentation: <https://www.sqlite.org/json1.html#jptr>
    ///
    /// - parameter path: A [JSON path](https://www.sqlite.org/json1.html#path_arguments),
    ///   or an JSON object field label, or an array index.
    @available(iOS 16, macOS 13.2, tvOS 17, watchOS 9, *) // SQLite 3.38+
    public subscript(_ path: some SQLExpressible) -> SQLExpression {
        .binary(.jsonExtractSQL, sqlExpression, path.sqlExpression)
    }
    
    /// The `JSON_EXTRACT` SQL function.
    ///
    /// For example:
    ///
    /// ```swift
    /// let info = JSONColumn("info")
    ///
    /// // SELECT JSON_EXTRACT(info, '$.firstName') FROM player
    /// // → 'Arthur'
    /// let firstName = try Player
    ///     .select(info.jsonExtract(atPath: "$.firstName"), as: String.self)
    ///     .fetchOne(db)
    ///
    /// // SELECT JSON_EXTRACT(info, '$.address') FROM player
    /// // → '{"street":"Rue de Belleville","city":"Paris"}'
    /// let address = try Player
    ///     .select(info.jsonExtract(atPath: "$.address"), as: String.self)
    ///     .fetchOne(db)
    /// ```
    ///
    /// Related SQL documentation: <https://www.sqlite.org/json1.html#jex>
    ///
    /// - parameter path: A [JSON path](https://www.sqlite.org/json1.html#path_arguments).
    @available(iOS 16, macOS 10.15, tvOS 17, watchOS 9, *) // SQLite 3.38+ with exceptions for macOS
    public func jsonExtract(atPath path: some SQLExpressible) -> SQLExpression {
        Database.jsonExtract(self, atPath: path)
    }
    
    /// The `JSON_EXTRACT` SQL function.
    ///
    /// For example:
    ///
    /// ```swift
    /// let info = JSONColumn("info")
    ///
    /// // SELECT JSON_EXTRACT(info, '$.firstName', '$.lastName') FROM player
    /// // → '["Arthur","Miller"]'
    /// let nameComponents = try Player
    ///     .select(info.jsonExtract(atPaths: ["$.firstName", "$.lastName"]), as: String.self)
    ///     .fetchOne(db)
    /// ```
    ///
    /// Related SQL documentation: <https://www.sqlite.org/json1.html#jex>
    ///
    /// - parameter paths: A collection of [JSON paths](https://www.sqlite.org/json1.html#path_arguments).
    @available(iOS 16, macOS 10.15, tvOS 17, watchOS 9, *) // SQLite 3.38+ with exceptions for macOS
    public func jsonExtract<C>(atPaths paths: C) -> SQLExpression
    where C: Collection, C.Element: SQLExpressible
    {
        Database.jsonExtract(self, atPaths: paths)
    }
    
    /// Returns a valid JSON string with the `->` SQL operator.
    ///
    /// For example:
    ///
    /// ```swift
    /// let info = JSONColumn("info")
    ///
    /// // SELECT info -> 'firstName' FROM player
    /// // → '"Arthur"'
    /// let name = try Player
    ///     .select(info.jsonRepresentation(atPath: "firstName"), as: String.self)
    ///     .fetchOne(db)
    ///
    /// // SELECT info -> 'address' FROM player
    /// // → '{"street":"Rue de Belleville","city":"Paris"}'
    /// let name = try Player
    ///     .select(info.jsonRepresentation(atPath: "address"), as: String.self)
    ///     .fetchOne(db)
    /// ```
    ///
    /// Related SQL documentation: <https://www.sqlite.org/json1.html#jptr>
    ///
    /// - parameter path: A [JSON path](https://www.sqlite.org/json1.html#path_arguments),
    ///   or an JSON object field label, or an array index.
    @available(iOS 16, macOS 13.2, tvOS 17, watchOS 9, *) // SQLite 3.38+
    public func jsonRepresentation(atPath path: some SQLExpressible) -> SQLExpression {
        .binary(.jsonExtractJSON, sqlExpression, path.sqlExpression)
    }
}

// TODO: Enable when those apis are ready.
// extension ColumnExpression where Self: SQLJSONExpressible {
//     /// Updates a columns with the `JSON_PATCH` SQL function.
//     ///
//     /// For example:
//     ///
//     /// ```swift
//     /// // UPDATE player SET address = JSON_PATCH(address, '{"country": "FR"}')
//     /// try Player.updateAll(db, [
//     ///     JSONColumn("address").jsonPatch(#"{"country": "FR"}"#)
//     /// ])
//     /// ```
//     ///
//     /// Related SQLite documentation: <https://www.sqlite.org/json1.html#jpatch>
//     @available(iOS 16, macOS 10.15, tvOS 17, watchOS 9, *) // SQLite 3.38+ with exceptions for macOS
//     public func jsonPatch(
//         with patch: some SQLExpressible)
//     -> ColumnAssignment
//     {
//         .init(columnName: name, value: Database.jsonPatch(self, with: patch))
//     }
// 
//     /// Updates a columns with the `JSON_REMOVE` SQL function.
//     ///
//     /// For example:
//     ///
//     /// ```swift
//     /// // UPDATE player SET address = JSON_REMOVE(address, '$.country')
//     /// try Player.updateAll(db, [
//     ///     JSONColumn("address").jsonRemove(atPath: "$.country")
//     /// ])
//     /// ```
//     ///
//     /// Related SQLite documentation: <https://www.sqlite.org/json1.html#jrm>
//     ///
//     /// - Parameters:
//     ///   - paths: A [JSON path](https://www.sqlite.org/json1.html#path_arguments).
//     @available(iOS 16, macOS 10.15, tvOS 17, watchOS 9, *) // SQLite 3.38+ with exceptions for macOS
//     public func jsonRemove(atPath path: some SQLExpressible) -> ColumnAssignment {
//         .init(columnName: name, value: Database.jsonRemove(self, atPath: path))
//     }
// 
//     /// Updates a columns with the `JSON_REMOVE` SQL function.
//     ///
//     /// For example:
//     ///
//     /// ```swift
//     /// // UPDATE player SET address = JSON_REMOVE(address, '$.country', '$.city')
//     /// try Player.updateAll(db, [
//     ///     JSONColumn("address").jsonRemove(atPatsh: ["$.country", "$.city"])
//     /// ])
//     /// ```
//     ///
//     /// Related SQLite documentation: <https://www.sqlite.org/json1.html#jrm>
//     ///
//     /// - Parameters:
//     ///   - paths: A collection of [JSON paths](https://www.sqlite.org/json1.html#path_arguments).
//     @available(iOS 16, macOS 10.15, tvOS 17, watchOS 9, *) // SQLite 3.38+ with exceptions for macOS
//     public func jsonRemove<C>(atPaths paths: C)
//     -> ColumnAssignment
//     where C: Collection, C.Element: SQLExpressible
//     {
//         .init(columnName: name, value: Database.jsonRemove(self, atPaths: paths))
//     }
// 
// }
#endif

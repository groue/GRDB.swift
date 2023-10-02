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
@available(iOS 16, macOS 13.2, tvOS 17, watchOS 9, *) // SQLite 3.38+
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

// TODO: Enable when those apis are ready.
// @available(iOS 16, macOS 13.2, tvOS 17, watchOS 9, *) // SQLite 3.38+
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
//     public func jsonRemove<C>(atPaths paths: C)
//     -> ColumnAssignment
//     where C: Collection, C.Element: SQLExpressible
//     {
//         .init(columnName: name, value: Database.jsonRemove(self, atPaths: paths))
//     }
// 
// }
#endif

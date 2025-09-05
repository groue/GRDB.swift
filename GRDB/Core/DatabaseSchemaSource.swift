/// A type that provides information about the database schema.
///
/// ## Overview
///
/// - note: [**🔥 EXPERIMENTAL**](https://github.com/groue/GRDB.swift/blob/master/README.md#what-are-experimental-features)
///
/// The use case for a custom schema source is enabling GRDB features that
/// would not work with the built-in schema introspection that is provided
/// by SQLite.
///
/// For example, if your database schema contains a view and you wish to use
/// GRDB features that need a primary key, such as the
/// ``FetchableRecord/find(_:id:)`` record method, or the persistence
/// methods of the ``PersistableRecord`` protocol, then use a schema source
/// that implements the ``columnsForPrimaryKey(_:inView:)`` method.
///
/// ## Enabling a Schema Source
///
/// To enable a schema source in a database connection, configure its
/// ``Configuration/schemaSource``:
///
/// ```swift
/// struct MySchemaSource: DatabaseSchemaSource { ... }
///
/// var config = Configuration()
/// config.schemaSource = MySchemaSource()
/// let dbQueue = try DatabaseQueue(path: "/path/to/db.sqlite", configuration: config)
/// ```
///
/// For temporary use, call ``Database/withSchemaSource(_:execute:)``:
///
/// ```swift
/// try dbQueue.read { db in
///     try db.withSchemaSource(MySchemaSource()) {
///         ...
///     }
/// }
/// ```
///
/// ## Topics
///
/// ### Customizing the Database Schema
///
/// - ``columnsForPrimaryKey(_:inView:)``
public protocol DatabaseSchemaSource: Sendable {
    /// Returns the names of the columns for the primary key in the
    /// provided database view.
    ///
    /// Return nil if no customization should happen. Return an empty array
    /// to specify that the view has no primary key. The default
    /// implementation returns nil.
    ///
    /// In your implementation, make sure that:
    ///
    /// - The returned columns exist in the database schema.
    /// - The returned columns identify unique rows.
    /// - The returned columns do not contain NULL values.
    ///
    /// For example:
    ///
    /// ```swift
    /// // A schema source that specifies that views have an "id" primary key.
    /// struct MySchemaSource: DatabaseSchemaSource {
    ///     func columnsForPrimaryKey(_ db: Database, inView view: DatabaseObjectID) {
    ///         ["id"]
    ///     }
    /// }
    ///
    /// // A database connection configured with the schema source.
    /// var config = Configuration()
    /// config.schemaSource = MySchemaSource()
    /// let dbQueue = try DatabaseQueue(path: "/path/to/db.sqlite", configuration: config)
    ///
    /// // A record type that feeds from a view.
    /// struct Player: Decodable, Identifiable, FetchableRecord {
    ///     static let databaseTableName = "playerView"
    ///     var id: String
    ///     var name: String
    /// }
    ///
    /// // Thanks to the schema source, we can fetch players by id:
    /// let player = try dbQueue.read { db in
    ///     try Player.find(db, id: "alice")
    /// }
    /// ```
    ///
    /// When you are developing a library that accesses database files owned
    /// by the users of your library, then you you should allow the host
    /// application to deal with their own views. To do so, return nil for
    /// views that your library does not manage. When necessary, use the
    /// `db` argument in order to query the database schema.
    ///
    /// ```swift
    /// struct MyLbrarySchemaSource: DatabaseSchemaSource {
    ///     func columnsForPrimaryKey(_ db: Database, inView view: DatabaseObjectID) {
    ///         if view.name == "playerView" {
    ///             // This is a view managed by my library:
    ///             return ["id"]
    ///         } else {
    ///             // Not a view managed by my library:
    ///             // don't mess with user's schema
    ///             return nil
    ///         }
    ///     }
    /// }
    /// ```
    func columnsForPrimaryKey(
        _ db: Database,
        inView view: DatabaseObjectID
    ) throws -> [String]?
}

extension DatabaseSchemaSource {
    public func columnsForPrimaryKey(
        _ db: Database,
        inView view: DatabaseObjectID
    ) throws -> [String]? {
        nil
    }
}

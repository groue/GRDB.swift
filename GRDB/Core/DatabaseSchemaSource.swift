/// A type that provides information about the database schema.
///
/// ## Overview
///
/// - note: [**🔥 EXPERIMENTAL**](https://github.com/groue/GRDB.swift/blob/master/README.md#what-are-experimental-features)
///
/// The use case for a custom schema source is to enable GRDB features that
/// would not work with the built-in schema introspection provided
/// by SQLite.
///
/// For example, if your database schema contains a view and you wish to use
/// GRDB features that need a primary key, such as the
/// ``FetchableRecord/find(_:id:)`` record method, or the persistence
/// methods of the ``PersistableRecord`` protocol, then use a schema source
/// that implements the ``columnsForPrimaryKey(_:inView:)`` method. See
/// <doc:ViewRecords> for a detailed guide about such views.
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
/// ## Schema Sources and Migrations
///
/// By default, schema sources are disabled during <doc:Migrations>. In
/// migrations that need a schema source, you can use
/// ``Database/withSchemaSource(_:execute:)``:
///
/// ```swift
/// migrator.registerMigration("My migration") { db in
///     // No schema source is enabled at this point.
///     try db.withSchemaSource(MySchemaSource()) {
///         // Here the provided schema source is in effect.
///     }
/// }
/// ```
///
/// Take care that **a good migration is a migration that is never
/// modified once it has shipped**: check
/// <doc:Migrations#Good-Practices-for-Defining-Migrations>.
///
/// ## Topics
///
/// ### Customizing the Database Schema
///
/// - ``columnsForPrimaryKey(_:inView:)``
///
/// ### Chaining Schema Sources
///
/// - ``then(_:)``
public protocol DatabaseSchemaSource: Sendable {
    /// Returns the names of the columns for the primary key in the
    /// provided database view.
    ///
    /// Return `nil` if no customization should happen. Return an empty
    /// array to specify that the view has no primary key. The default
    /// implementation returns `nil`.
    ///
    /// In your implementation, make sure that the returned columns define
    /// a genuine **primary key**:
    ///
    /// - All columns exist in the provided view.
    /// - The set of columns reliably identifies and distinguishes between
    ///   each individual row in the view.
    /// - No column contains NULL values.
    ///
    /// It is a programmer error with undefined consequences to miss
    /// those requirements.
    ///
    /// For example:
    ///
    /// ```swift
    /// // A schema source that specifies that all views are identified by
    /// // their "id" column:
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
    /// ### Schema Sources in Libraries
    ///
    /// When you are developing a schema source for a library, some extra
    /// care is necessary whenever the database file is owned by the users
    /// of your library. Your users may define views for their own purposes,
    /// and your library knows nothing about the eventual primary key of
    /// those views.
    ///
    /// In this case, make your schema source `public`, and have this method
    /// return `nil` for those unknown views. If needed, use the `db`
    /// argument and query the database schema with
    /// <doc:DatabaseSchemaIntrospection> methods.
    ///
    /// For example:
    ///
    /// ```swift
    /// // A well-behaved schema source defined by a library is public
    /// // and returns nil for unknown views.
    /// public struct MyLibrarySchemaSource: DatabaseSchemaSource {
    ///     public func columnsForPrimaryKey(_ db: Database, inView view: DatabaseObjectID) {
    ///         if view.name == "playerView" {
    ///             // This is a view managed by my library:
    ///             return ["id"]
    ///         } else if try db.tableExists(view.name + "MyLibrary") {
    ///             // This is a view managed by my library:
    ///             return ["uuid"]
    ///         } else {
    ///             // Not a view managed by my library:
    ///             // don't mess with user's schema
    ///             return nil
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// With such a setup, your user will be able to deal with their
    /// own views, by chaining your schema source with other ones
    /// (see ``DatabaseSchemaSource/then(_:)``):
    ///
    /// ```swift
    /// // Application code
    /// import MyLibrary
    /// import GRDB
    ///
    /// let myLibrarySchemaSource = MyLibrarySchemaSource()
    /// let customSchemaSource = TheirCustomSchemaSource()
    /// let schemaSource = myLibrarySchemaSource.then(customSchemaSource)
    ///
    /// var config = Configuration()
    /// config.schemaSource = schemaSource
    /// let dbQueue = try DatabaseQueue(path: "...", configuration: config)
    /// ```
    ///
    /// - Parameters:
    ///     - db: A database connection.
    ///     - view: The identifier of a database view.
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

// MARK: - Combined2SchemaSource

extension DatabaseSchemaSource {
    /// Returns a schema source that queries `other` when this source does
    /// not perform a customization.
    ///
    /// For example:
    ///
    /// ```swift
    /// let schemaSource1 = SomeSchemaSource()
    /// let schemaSource2 = AnotherSchemaSource()
    /// let schemaSource = schemaSource1.then(schemaSource2)
    ///
    /// var config = Configuration()
    /// config.schemaSource = schemaSource
    /// let dbQueue = try DatabaseQueue(path: "...", configuration: config)
    /// ```
    public func then(_ other: some DatabaseSchemaSource) -> some DatabaseSchemaSource {
        Chained2SchemaSource(first: self, second: other)
    }
}

// TODO: move to parameter packs eventually. Parameter packs in generic types
// are only available in macOS 14.0.0 or newer.
// This schema source is designed to tame bad citizens that customize tables
// and views they do not own (such as insufficienly robust schema sources
// exposed by external libraries). We should NEVER MERGE the results of the
// schema sources.
struct Chained2SchemaSource<Source1, Source2>: DatabaseSchemaSource
where Source1: DatabaseSchemaSource,
      Source2: DatabaseSchemaSource
{
    var first: Source1
    var second: Source2
    
    func columnsForPrimaryKey(_ db: Database, inView view: DatabaseObjectID) throws -> [String]? {
        if let result = try first.columnsForPrimaryKey(db, inView: view) { return result }
        if let result = try second.columnsForPrimaryKey(db, inView: view) { return result }
        return nil
    }
}

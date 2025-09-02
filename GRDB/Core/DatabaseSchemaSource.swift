/// A type that provides information about the database schema.
///
/// ## Overview
///
/// - note: [**🔥 EXPERIMENTAL**](https://github.com/groue/GRDB.swift/blob/master/README.md#what-are-experimental-features)
///
/// The use case for a custom schema source is enabling GRDB features that
/// would not work with the built-in schema introspection that is provided
/// by SQLite. For example, a custom schema source can help record types
/// that read or write in a database view.
///
/// You do not interact directly with values of such a type. Instead, you
/// configure a database connection with ``Configuration/schemaSource``, and
/// you call <doc:DatabaseSchemaIntrospection> methods on a
/// ``Database`` connection.
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
    /// struct MySchemaSource: DatabaseSchemaSource {
    ///     func columnsForPrimaryKey(
    ///         _ db: Database,
    ///         inView view: DatabaseObjectID
    ///     ) throws -> [String]? {
    ///         switch table.name {
    ///         case "player":
    ///             // Use the email column as the primary key of this view.
    ///             return ["email"]
    ///
    ///         default:
    ///             // Do not customize.
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

/// Describes an association in the database schema.
///
/// You get instances of `ForeignKeyDefinition` when you create a database
/// tables. For example:
///
/// ```swift
/// try db.create(table: "player") { t in
///     t.belongsTo("team") // ForeignKeyDefinition
/// }
/// ```
///
/// See ``TableDefinition/belongsTo(_:inTable:onDelete:onUpdate:deferred:indexed:)``.
public final class ForeignKeyDefinition {
    enum Indexing {
        case index
        case unique
    }
    
    var name: String
    var table: String?
    var deleteAction: Database.ForeignKeyAction?
    var updateAction: Database.ForeignKeyAction?
    var indexing: Indexing?
    var isDeferred: Bool
    var notNullConflictResolution: Database.ConflictResolution?
    
    init(
        name: String,
        table: String?,
        deleteAction: Database.ForeignKeyAction?,
        updateAction: Database.ForeignKeyAction?,
        isIndexed: Bool,
        isDeferred: Bool)
    {
        self.name = name
        self.table = table
        self.deleteAction = deleteAction
        self.updateAction = updateAction
        self.indexing = isIndexed ? .index : nil
        self.isDeferred = isDeferred
    }
    
    /// Adds a not null constraint.
    ///
    /// For example:
    ///
    /// ```swift
    /// // CREATE TABLE player(
    /// //   teamId INTEGER NOT NULL REFERENCES team(id)
    /// // )
    /// try db.create(table: "player") { t in
    ///     t.belongsTo("team").notNull()
    /// }
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/lang_createtable.html#notnullconst>
    ///
    /// - parameter conflictResolution: An optional ``Database/ConflictResolution``.
    /// - returns: `self` so that you can further refine the definition of
    ///   the association.
    @discardableResult
    public func notNull(onConflict conflictResolution: Database.ConflictResolution? = nil) -> Self {
        notNullConflictResolution = conflictResolution ?? .abort
        return self
    }
    
    /// Adds a unique constraint.
    ///
    /// For example:
    ///
    /// ```swift
    /// // CREATE TABLE player(
    /// //   teamId INTEGER UNIQUE REFERENCES team(id)
    /// // )
    /// try db.create(table: "player") { t in
    ///     t.belongsTo("team").unique()
    /// }
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/lang_createtable.html#uniqueconst>
    ///
    /// - returns: `self` so that you can further refine the definition of
    ///   the association.
    @discardableResult
    public func unique() -> Self {
        indexing = .unique
        return self
    }
    
    func primaryKey(_ db: Database) throws -> SQLPrimaryKeyDescriptor {
        if let table {
            return try SQLPrimaryKeyDescriptor.find(db, table: table)
        }
        
        if try db.tableExists(name) {
            return try SQLPrimaryKeyDescriptor.find(db, table: name)
        }
        
        let pluralizedName = name.pluralized
        if try db.tableExists(pluralizedName) {
            return try SQLPrimaryKeyDescriptor.find(db, table: pluralizedName)
        }
        
        throw DatabaseError.noSuchTable(name)
    }
}

// Explicit non-conformance to Sendable: `ForeignKeyDefinition` is a mutable
// class and there is no known reason for making it thread-safe.
@available(*, unavailable)
extension ForeignKeyDefinition: Sendable { }

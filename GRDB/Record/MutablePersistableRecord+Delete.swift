// MARK: - Delete Callbacks

extension MutablePersistableRecord {
    @inline(__always)
    @inlinable
    public func willDelete(_ db: Database) throws { }
    
    @inline(__always)
    @inlinable
    public func aroundDelete(_ db: Database, delete: () throws -> Bool) throws {
        _ = try delete()
    }
    
    @inline(__always)
    @inlinable
    public func didDelete(deleted: Bool) { }
}

// MARK: - Delete

extension MutablePersistableRecord {
    /// Executes a DELETE statement.
    ///
    /// - parameter db: A database connection.
    /// - returns: Whether a database row was deleted.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    @discardableResult
    @inlinable // allow specialization so that empty callbacks are removed
    public func delete(_ db: Database) throws -> Bool {
        try willDelete(db)
        
        var deleted: Bool?
        try aroundDelete(db) {
            deleted = try deleteWithoutCallbacks(db)
            return deleted!
        }
        
        guard let deleted else {
            try persistenceCallbackMisuse("aroundDelete")
        }
        didDelete(deleted: deleted)
        return deleted
    }
}

// MARK: - Internals

extension MutablePersistableRecord {
    /// Executes an `DELETE` statement, and DOES NOT run deletion callbacks.
    @usableFromInline
    func deleteWithoutCallbacks(_ db: Database) throws -> Bool {
        guard let statement = try DAO(db, self).deleteStatement() else {
            // Nil primary key
            return false
        }
        try statement.execute()
        return db.changesCount > 0
    }
}

/// A protocol for all types that can fetch values from a database.
public protocol DatabaseReader {
    func nonIsolatedRead<T>(block: (db: Database) throws -> T) rethrows -> T
}

extension DatabaseQueue : DatabaseReader {
    
    /// Synonym for DatabaseQueue.inDatabase()
    public func nonIsolatedRead<T>(block: (db: Database) throws -> T) rethrows -> T {
        return try inDatabase(block)
    }
}

extension DatabasePool : DatabaseReader {
}

extension Database : DatabaseReader {
    /// Conformance to the DatabaseReader protocol.
    /// Don't use this method directly.
    public func nonIsolatedRead<T>(block: (db: Database) throws -> T) rethrows -> T {
        return try block(db: self)
    }
}

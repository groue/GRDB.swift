/// The protocol for all types that can fetch values from a database.
///
/// It is adopted by DatabaseQueue, and DatabasePool, and Database.
///
/// You don't use the protocol directly. Instead, you provide a DatabaseReader
/// to fetching methods:
/// 
///     let persons = Person.fetchAll(dbQueue)
///     let persons = Person.fetchAll(dbPool)
///     dbQueue.inDatabase { db in
///         let persons = Person.fetchAll(db)
///     }
public protocol DatabaseReader {
    /// This method is an implementation detail: do not use it directly.
    func _readSingleStatement<T>(block: (db: Database) throws -> T) rethrows -> T
}

/// A type that can be persisted in the database.
///
/// ``PersistableRecord`` has non-mutating variants of
/// ``MutablePersistableRecord`` methods.
///
/// ## Conforming to the PersistableRecord Protocol
///
/// To conform to `PersistableRecord`, provide an implementation for the
/// ``EncodableRecord/encode(to:)-k9pf`` method. This implementation is
/// ready-made for `Encodable` types.
///
/// You configure the database table where records are persisted with the
/// ``TableRecord`` inherited protocol.
///
/// ## Topics
///
/// ### Inserting a Record
///
/// - ``insert(_:onConflict:)``
/// - ``upsert(_:)``
///
/// ### Inserting a Record and Fetching the Inserted Row
///
/// - ``insertAndFetch(_:onConflict:as:)``
/// - ``insertAndFetch(_:onConflict:selection:fetch:)``
/// - ``upsertAndFetch(_:onConflict:doUpdate:)``
/// - ``upsertAndFetch(_:as:onConflict:doUpdate:)``
///
/// ### Saving a Record
///
/// - ``save(_:onConflict:)``
///
/// ### Saving a Record and Fetching the Saved Row
///
/// - ``saveAndFetch(_:onConflict:as:)``
/// - ``saveAndFetch(_:onConflict:selection:fetch:)``
///
/// ### Persistence Callbacks
///
/// - ``willInsert(_:)-5x6sh``
/// - ``didInsert(_:)-9jpoy``
public protocol PersistableRecord: MutablePersistableRecord {
    
    // MARK: Insertion Callbacks
    
    /// Persistence callback called before the record is inserted.
    ///
    /// Default implementation does nothing.
    ///
    /// - note: If you need a mutating variant of this method, adopt the
    ///   ``MutablePersistableRecord`` protocol instead.
    func willInsert(_ db: Database) throws
    
    /// Persistence callback called upon successful insertion.
    ///
    /// The default implementation does nothing.
    ///
    /// You can provide a custom implementation in order to grab the
    /// auto-incremented id:
    ///
    /// ```swift
    /// class Player: PersistableRecord {
    ///     var id: Int64?
    ///     var name: String?
    ///
    ///     func didInsert(_ inserted: InsertionSuccess) {
    ///         id = inserted.rowID
    ///     }
    /// }
    /// ```
    ///
    /// - note: If you need a mutating variant of this method, adopt the
    ///   ``MutablePersistableRecord`` protocol instead.
    ///
    /// - parameter inserted: Information about the inserted row.
    func didInsert(_ inserted: InsertionSuccess)
}

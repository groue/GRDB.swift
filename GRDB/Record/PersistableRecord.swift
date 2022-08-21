/// Types that adopt `PersistableRecord` can be inserted, updated, and deleted.
///
/// `PersistableRecord` has non-mutating variants of
/// `MutablePersistableRecord` methods.
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
    ///     class Player: PersistableRecord {
    ///         var id: Int64?
    ///         var name: String?
    ///
    ///         func didInsert(_ inserted: InsertionSuccess) {
    ///             id = inserted.rowID
    ///         }
    ///     }
    ///
    /// - note: If you need a mutating variant of this method, adopt the
    ///   ``MutablePersistableRecord`` protocol instead.
    ///
    /// - parameter inserted: Information about the inserted row.
    func didInsert(_ inserted: InsertionSuccess)
}

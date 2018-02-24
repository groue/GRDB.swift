/// RecordBox is a subclass of Record that aims at giving any record type the
/// changes tracking provided by the Record class.
///
///     // A Regular record struct
///     struct Player: RowConvertible, MutablePersistable, Codable {
///         static let databaseTableName = "players"
///         var id: Int64?
///         var name: String
///         var score: Int
///         mutating func didInsert(with rowID: Int64, for column: String?) {
///             id = rowID
///         }
///     }
///
///     try dbQueue.inDatabase { db in
///         // Fetch a player record
///         let playerRecord = try RecordBox<Player>.fetchOne(db, key: 1)!
///
///         // Profit from changes tracking
///         playerRecord.value.score = 300
///         playerRecord.hasPersistentChangedValues         // true
///         playerRecord.persistentChangedValues["score"]   // 100 (the old value)
///     }
@available(*, deprecated, message: "Prefer changes methods defined on the MutablePersistable protocol: databaseEqual(_:), databaseChanges(from:), updateChanges(from:)")
public final class RecordBox<T: RowConvertible & MutablePersistable>: Record {
    /// The boxed record
    public var value: T
    
    /// Creates a RecordBox that wraps the given record
    public init(value: T) {
        self.value = value
        super.init()
    }
    
    // MARK: - RowConvertible
    
    /// Initializes a record from `row`.
    public required init(row: Row) {
        self.value = T(row: row)
        super.init(row: row)
    }
    
    // MARK: - TableMapping
    
    /// :nodoc:
    override public class var databaseTableName: String {
        return T.databaseTableName
    }
    
    /// :nodoc:
    override public class var databaseSelection: [SQLSelectable] {
        return T.databaseSelection
    }
    
    // MARK: - MutablePersistable
    
    /// :nodoc:
    override public class var persistenceConflictPolicy: PersistenceConflictPolicy {
        return T.persistenceConflictPolicy
    }
    
    /// :nodoc:
    override public func encode(to container: inout PersistenceContainer) {
        value.encode(to: &container)
    }
    
    /// :nodoc:
    override public func didInsert(with rowID: Int64, for column: String?) {
        value.didInsert(with: rowID, for: column)
    }
    
    /// :nodoc:
    override public func insert(_ db: Database) throws {
        try value.insert(db)
        hasPersistentChangedValues = false
    }
    
    /// :nodoc:
    override public func update(_ db: Database, columns: Set<String>) throws {
        try value.update(db, columns: columns)
        hasPersistentChangedValues = false
    }
    
    /// :nodoc:
    @discardableResult
    override public func delete(_ db: Database) throws -> Bool {
        defer {
            // Future calls to update() will throw NotFound. Make the user
            // a favor and make sure this error is thrown even if she checks the
            // hasPersistentChangedValues flag:
            hasPersistentChangedValues = true
        }
        return try value.delete(db)
    }
    
    /// :nodoc:
    public func exists(_ db: Database) throws -> Bool {
        return try value.exists(db)
    }
}


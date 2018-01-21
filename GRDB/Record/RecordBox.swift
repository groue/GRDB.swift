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
public final class RecordBox<T: RowConvertible & MutablePersistable>: Record {
    public var value: T
    
    public init(value: T) {
        self.value = value
        super.init()
    }
    
    // MARK: - RowConvertible
    
    public required init(row: Row) {
        self.value = T(row: row)
        super.init(row: row)
    }
    
    // MARK: - TableMapping
    
    override public class var databaseTableName: String {
        return T.databaseTableName
    }
    
    override public class var databaseSelection: [SQLSelectable] {
        return T.databaseSelection
    }
    
    // MARK: - MutablePersistable
    
    override public class var persistenceConflictPolicy: PersistenceConflictPolicy {
        return T.persistenceConflictPolicy
    }
    
    override public func encode(to container: inout PersistenceContainer) {
        value.encode(to: &container)
    }
    
    override public func didInsert(with rowID: Int64, for column: String?) {
        value.didInsert(with: rowID, for: column)
    }
    
    override public func insert(_ db: Database) throws {
        try value.insert(db)
        hasPersistentChangedValues = false
    }
    
    override public func update(_ db: Database, columns: Set<String>) throws {
        try value.update(db, columns: columns)
        hasPersistentChangedValues = false
    }
    
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
    
    public func exists(_ db: Database) throws -> Bool {
        return try value.exists(db)
    }
}


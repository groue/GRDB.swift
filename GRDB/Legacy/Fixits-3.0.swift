/// :nodoc:
@available(*, unavailable, renamed:"FetchRequest")
public typealias Request = FetchRequest

/// :nodoc:
@available(*, unavailable, renamed:"FetchableRecord")
public typealias RowConvertible = FetchableRecord

/// :nodoc:
@available(*, unavailable, renamed:"TableRecord")
public typealias TableMapping = TableRecord

/// :nodoc:
@available(*, unavailable, renamed:"MutablePersistableRecord")
public typealias MutablePersistable = MutablePersistableRecord

/// :nodoc:
@available(*, unavailable, renamed:"PersistableRecord")
public typealias Persistable = PersistableRecord

extension Database {
    /// :nodoc:
    @available(*, unavailable, message: "Use db.columns(in: tableName).count instead")
    public func columnCount(in tableName: String) throws -> Int { preconditionFailure() }
}

extension SelectStatement {
    /// :nodoc:
    @available(*, unavailable, renamed:"DatabaseRegion")
    public typealias SelectionInfo = DatabaseRegion
    
    /// :nodoc:
    @available(*, unavailable, renamed:"fetchedRegion")
    public var selectionInfo: DatabaseRegion { preconditionFailure() }
}

extension DatabaseEventKind {
    /// :nodoc:
    @available(*, unavailable, message: "Use DatabaseRegion.isModified(byEventsOfKind:) instead")
    public func impacts(_ region: DatabaseRegion) -> Bool { preconditionFailure() }
}

extension Record {
    /// :nodoc:
    @available(*, unavailable, renamed: "hasDatabaseChanges")
    public var hasPersistentChangedValues: Bool { preconditionFailure() }
    
    /// :nodoc:
    @available(*, unavailable, renamed: "databaseChanges")
    public var persistentChangedValues: [String: DatabaseValue?] { preconditionFailure() }
}

@available(*, unavailable, message: "Use changes methods defined on the MutablePersistableRecord protocol: databaseEquals(_:), databaseChanges(from:), updateChanges(from:)")
public final class RecordBox<T: FetchableRecord & MutablePersistableRecord>: Record { }

extension MutablePersistableRecord {
    /// :nodoc:
    @available(*, unavailable, renamed: "databaseEquals")
    public func databaseEqual(_ record: Self) -> Bool { preconditionFailure() }
}

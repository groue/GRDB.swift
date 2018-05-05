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

/// :nodoc:
@available(*, unavailable, renamed:"TableAlias")
public typealias SQLTableQualifier = TableAlias

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
    @available(*, unavailable, renamed:"databaseRegion")
    public var selectionInfo: DatabaseRegion { preconditionFailure() }
    
    /// :nodoc:
    @available(*, unavailable, renamed:"databaseRegion")
    public var fetchedRegion: DatabaseRegion { preconditionFailure() }
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

extension Row {
    /// :nodoc:
    @available(*, unavailable, message: "Use row.scopes.names instead")
    var scopeNames: Set<String> { preconditionFailure() }

    /// :nodoc:
    @available(*, unavailable, message: "Use row.scopes[name] instead")
    public func scoped(on name: String) -> Row? { preconditionFailure() }
}

extension FetchRequest {
    
    /// :nodoc:
    @available(*, unavailable, renamed:"databaseRegion(_:)")
    public func fetchedRegion(_ db: Database) throws -> DatabaseRegion { preconditionFailure() }
}

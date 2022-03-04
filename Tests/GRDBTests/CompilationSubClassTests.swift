import GRDB

// This file contains types that subclass GRBD open classes. Test pass if this
// file compiles without any error.

// MARK: - Record

private class UserRecord : Record {
    override init() { super.init() }
    required init(row: Row) throws { try super.init(row: row) }
    override class var databaseTableName: String { super.databaseTableName }
    override class  var persistenceConflictPolicy: PersistenceConflictPolicy { super.persistenceConflictPolicy }
    override class var databaseSelection: [SQLSelectable] { super.databaseSelection }
    override func encode(to container: inout PersistenceContainer) { super.encode(to: &container) }
    override func didInsert(with rowID: Int64, for column: String?) { super.didInsert(with: rowID, for: column) }
    override func insert(_ db: Database) throws { try super.insert(db) }
    override func update(_ db: Database, columns: Set<String>) throws { try super.update(db, columns: columns) }
    override func delete(_ db: Database) throws -> Bool { try super.delete(db) }
}

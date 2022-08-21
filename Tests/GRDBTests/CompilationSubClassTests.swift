import GRDB

// This file contains types that subclass GRBD open classes. Test pass if this
// file compiles without any error.

// MARK: - Record

private class UserRecord : Record {
    override init() { super.init() }
    required init(row: Row) throws { try super.init(row: row) }
    override class var databaseTableName: String { super.databaseTableName }
    override class  var persistenceConflictPolicy: PersistenceConflictPolicy { super.persistenceConflictPolicy }
    override class var databaseSelection: [any SQLSelectable] { super.databaseSelection }
    override func encode(to container: inout PersistenceContainer) throws { try super.encode(to: &container) }
    
    override func willInsert(_ db: Database) throws {
        try super.willInsert(db)
    }
    
    override func aroundInsert(_ db: Database, insert: () throws -> InsertionSuccess) throws {
        try super.aroundInsert(db, insert: insert)
    }
    
    override func didInsert(_ inserted: InsertionSuccess) {
        super.didInsert(inserted)
    }
    
    override func willUpdate(_ db: Database, columns: Set<String>) throws {
        try super.willUpdate(db, columns: columns)
    }
    
    override func aroundUpdate(_ db: Database, columns: Set<String>, update: () throws -> PersistenceSuccess) throws {
        try super.aroundUpdate(db, columns: columns, update: update)
    }
    
    override func didUpdate(_ updated: PersistenceSuccess) {
        super.didUpdate(updated)
    }
    
    override func willSave(_ db: Database) throws {
        try super.willSave(db)
    }
    
    override func aroundSave(_ db: Database, save: () throws -> PersistenceSuccess) throws {
        try super.aroundSave(db, save: save)
    }
    
    override func didSave(_ saved: PersistenceSuccess) {
        super.didSave(saved)
    }

    override func willDelete(_ db: Database) throws {
        try super.willDelete(db)
    }
    
    override func aroundDelete(_ db: Database, delete: () throws -> Bool) throws {
        try super.aroundDelete(db, delete: delete)
    }
    
    override func didDelete(deleted: Bool) {
        super.didDelete(deleted: deleted)
    }
}

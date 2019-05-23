import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private struct DefaultPolicy: MutablePersistableRecord {
    var id: Int64?
    
    static let databaseTableName = "records"
    
    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
    }
    
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

private struct MixedPolicy: MutablePersistableRecord {
    var id: Int64?
    
    static let databaseTableName = "records"
    static let persistenceConflictPolicy = PersistenceConflictPolicy(insert: .fail, update: .rollback)
    
    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
    }
    
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

private struct ReplacePolicy: MutablePersistableRecord {
    var id: Int64?
    var email: String
    
    static let databaseTableName = "records"
    static let persistenceConflictPolicy = PersistenceConflictPolicy(insert: .replace, update: .replace)
    
    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["email"] = email
    }
    
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

private struct IgnorePolicy: MutablePersistableRecord {
    var id: Int64?
    
    static let databaseTableName = "records"
    static let persistenceConflictPolicy = PersistenceConflictPolicy(insert: .ignore, update: .ignore)
    
    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
    }
    
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

private struct FailPolicy: MutablePersistableRecord {
    var id: Int64?
    
    static let databaseTableName = "records"
    static let persistenceConflictPolicy = PersistenceConflictPolicy(insert: .fail, update: .fail)
    
    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
    }
    
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

private struct AbortPolicy: MutablePersistableRecord {
    var id: Int64?
    
    static let databaseTableName = "records"
    static let persistenceConflictPolicy = PersistenceConflictPolicy(insert: .abort, update: .abort)
    
    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
    }
    
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

private struct RollbackPolicy: MutablePersistableRecord {
    var id: Int64?
    
    static let databaseTableName = "records"
    static let persistenceConflictPolicy = PersistenceConflictPolicy(insert: .rollback, update: .rollback)
    
    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
    }
    
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

class MutablePersistableRecordPersistenceConflictPolicyTests: GRDBTestCase {
    
    func testPolicyDefaultArguments() {
        let policy = PersistenceConflictPolicy()
        XCTAssertEqual(policy.conflictResolutionForInsert, .abort)
        XCTAssertEqual(policy.conflictResolutionForUpdate, .abort)
    }
    
    func testDefaultPolicy() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "records") { t in
                t.column("id", .integer).primaryKey()
            }
            
            // Insert
            var record = DefaultPolicy(id: nil)
            try record.insert(db)
            XCTAssertTrue(self.lastSQLQuery.hasPrefix("INSERT INTO \"records\""))
            XCTAssertEqual(record.id, 1)
            
            // Update
            record = DefaultPolicy(id: 1)
            try record.update(db)
            XCTAssertTrue(self.lastSQLQuery.hasPrefix("UPDATE \"records\""))
        }
    }

    func testMixedPolicy() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "records") { t in
                t.column("id", .integer).primaryKey()
            }
            
            // Insert
            var record = MixedPolicy(id: nil)
            try record.insert(db)
            XCTAssertTrue(self.lastSQLQuery.hasPrefix("INSERT OR FAIL INTO \"records\""))
            XCTAssertEqual(record.id, 1)
            
            // Update
            record = MixedPolicy(id: 1)
            try record.update(db)
            XCTAssertTrue(self.lastSQLQuery.hasPrefix("UPDATE OR ROLLBACK \"records\""))
        }
    }

    func testReplacePolicy() throws {
        class Observer : TransactionObserver {
            var transactionEvents: [DatabaseEvent] = []
            var events: [DatabaseEvent] = []
            
            func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool {
                return true
            }
            
            func databaseDidChange(with event: DatabaseEvent) {
                transactionEvents.append(event.copy())
            }
            
            func databaseDidCommit(_ db: Database) {
                events = transactionEvents
                transactionEvents = []
            }
            
            func databaseDidRollback(_ db: Database) {
                events = []
                transactionEvents = []
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        let observer = Observer()
        dbQueue.add(transactionObserver: observer)
        
        try dbQueue.writeWithoutTransaction { db in
            try db.create(table: "records") { t in
                t.column("id", .integer).primaryKey()
                t.column("email", .text).unique()
            }
            
            // Insert
            var record = ReplacePolicy(id: nil, email: "arthur@example.com")
            try record.insert(db)
            XCTAssertTrue(self.lastSQLQuery.hasPrefix("INSERT OR REPLACE INTO \"records\""))
            XCTAssertEqual(record.id, 1)
            XCTAssertEqual(observer.events.count, 1)
            XCTAssertEqual(observer.events[0].kind, .insert)
            XCTAssertEqual(observer.events[0].rowID, 1)
            
            // Insert
            record = ReplacePolicy(id: nil, email: "arthur@example.com")
            try record.insert(db)
            XCTAssertTrue(self.lastSQLQuery.hasPrefix("INSERT OR REPLACE INTO \"records\""))
            XCTAssertEqual(record.id, 2)
            XCTAssertTrue(try ReplacePolicy.fetchCount(db) == 1)
            XCTAssertEqual(observer.events.count, 1)
            XCTAssertEqual(observer.events[0].kind, .insert)
            XCTAssertEqual(observer.events[0].rowID, 2)
            
            // Update
            record = ReplacePolicy(id: 2, email: "arthur@example.com")
            try record.update(db)
            XCTAssertTrue(self.lastSQLQuery.hasPrefix("UPDATE OR REPLACE \"records\""))
            XCTAssertEqual(observer.events.count, 1)
            XCTAssertEqual(observer.events[0].kind, .update)
            XCTAssertEqual(observer.events[0].rowID, 2)
            
            // Update which replaces
            record = ReplacePolicy(id: 3, email: "barbara@example.com")
            try record.insert(db)
            XCTAssertTrue(try ReplacePolicy.fetchCount(db) == 2)
            XCTAssertEqual(observer.events.count, 1)
            XCTAssertEqual(observer.events[0].kind, .insert)
            XCTAssertEqual(observer.events[0].rowID, 3)
            record.email = "arthur@example.com"
            try record.update(db)
            XCTAssertTrue(try ReplacePolicy.fetchCount(db) == 1)
            XCTAssertEqual(try Int64.fetchOne(db, sql: "SELECT id FROM records")!, 3)
            XCTAssertEqual(observer.events.count, 1)
            XCTAssertEqual(observer.events[0].kind, .update)
            XCTAssertEqual(observer.events[0].rowID, 3)
        }
    }

    func testIgnorePolicy() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "records") { t in
                t.column("id", .integer).primaryKey()
            }
            
            // Insert
            var record = IgnorePolicy(id: nil)
            try record.insert(db)
            XCTAssertTrue(self.lastSQLQuery.hasPrefix("INSERT OR IGNORE INTO \"records\""))
            XCTAssertTrue(record.id == nil)
            
            // Update
            record = IgnorePolicy(id: 1)
            try record.update(db)
            XCTAssertTrue(self.lastSQLQuery.hasPrefix("UPDATE OR IGNORE \"records\""))
        }
    }

    func testFailPolicy() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "records") { t in
                t.column("id", .integer).primaryKey()
            }
            
            // Insert
            var record = FailPolicy(id: nil)
            try record.insert(db)
            XCTAssertTrue(self.lastSQLQuery.hasPrefix("INSERT OR FAIL INTO \"records\""))
            XCTAssertEqual(record.id, 1)
            
            // Update
            record = FailPolicy(id: 1)
            try record.update(db)
            XCTAssertTrue(self.lastSQLQuery.hasPrefix("UPDATE OR FAIL \"records\""))
        }
    }

    func testAbortPolicy() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "records") { t in
                t.column("id", .integer).primaryKey()
            }
            
            // Insert
            var record = AbortPolicy(id: nil)
            try record.insert(db)
            XCTAssertTrue(self.lastSQLQuery.hasPrefix("INSERT INTO \"records\""))
            XCTAssertEqual(record.id, 1)
            
            // Update
            record = AbortPolicy(id: 1)
            try record.update(db)
            XCTAssertTrue(self.lastSQLQuery.hasPrefix("UPDATE \"records\""))
        }
    }

    func testRollbackPolicy() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "records") { t in
                t.column("id", .integer).primaryKey()
            }
            
            // Insert
            var record = RollbackPolicy(id: nil)
            try record.insert(db)
            XCTAssertTrue(self.lastSQLQuery.hasPrefix("INSERT OR ROLLBACK INTO \"records\""))
            XCTAssertEqual(record.id, 1)
            
            // Update
            record = RollbackPolicy(id: 1)
            try record.update(db)
            XCTAssertTrue(self.lastSQLQuery.hasPrefix("UPDATE OR ROLLBACK \"records\""))
        }
    }
}

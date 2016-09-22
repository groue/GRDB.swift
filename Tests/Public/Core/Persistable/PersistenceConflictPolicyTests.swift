import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private struct DefaultPolicy: MutablePersistable {
    var id: Int64?
    
    static let databaseTableName = "records"
    
    var persistentDictionary: [String: DatabaseValueConvertible?] {
        return ["id": id]
    }
    
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

private struct MixedPolicy: MutablePersistable {
    var id: Int64?
    
    static let databaseTableName = "records"
    static let persistenceConflictPolicy = PersistenceConflictPolicy(insert: .fail, update: .rollback)
    
    var persistentDictionary: [String: DatabaseValueConvertible?] {
        return ["id": id]
    }
    
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

private struct ReplacePolicy: MutablePersistable {
    var id: Int64?
    var email: String
    
    static let databaseTableName = "records"
    static let persistenceConflictPolicy = PersistenceConflictPolicy(insert: .replace, update: .replace)
    
    var persistentDictionary: [String: DatabaseValueConvertible?] {
        return ["id": id, "email": email]
    }
    
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

private struct IgnorePolicy: MutablePersistable {
    var id: Int64?
    
    static let databaseTableName = "records"
    static let persistenceConflictPolicy = PersistenceConflictPolicy(insert: .ignore, update: .ignore)
    
    var persistentDictionary: [String: DatabaseValueConvertible?] {
        return ["id": id]
    }
    
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

private struct FailPolicy: MutablePersistable {
    var id: Int64?
    
    static let databaseTableName = "records"
    static let persistenceConflictPolicy = PersistenceConflictPolicy(insert: .fail, update: .fail)
    
    var persistentDictionary: [String: DatabaseValueConvertible?] {
        return ["id": id]
    }
    
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

private struct AbortPolicy: MutablePersistable {
    var id: Int64?
    
    static let databaseTableName = "records"
    static let persistenceConflictPolicy = PersistenceConflictPolicy(insert: .abort, update: .abort)
    
    var persistentDictionary: [String: DatabaseValueConvertible?] {
        return ["id": id]
    }
    
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

private struct RollbackPolicy: MutablePersistable {
    var id: Int64?
    
    static let databaseTableName = "records"
    static let persistenceConflictPolicy = PersistenceConflictPolicy(insert: .rollback, update: .rollback)
    
    var persistentDictionary: [String: DatabaseValueConvertible?] {
        return ["id": id]
    }
    
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

class PersistenceConflictPolicyTests: GRDBTestCase {
    
    func testPolicyDefaultArguments() {
        let policy = PersistenceConflictPolicy()
        XCTAssertEqual(policy.conflictResolutionForInsert, .abort)
        XCTAssertEqual(policy.conflictResolutionForUpdate, .abort)
    }
    
    func testDefaultPolicy() {
        assertNoError {
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
    }
    
    func testMixedPolicy() {
        assertNoError {
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
    }
    
    func testReplacePolicy() {
        assertNoError {
            class Observer : TransactionObserver {
                var transactionEvents: [DatabaseEvent] = []
                var events: [DatabaseEvent] = []
                
                func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool {
                    return true
                }
                
                func databaseDidChange(with event: DatabaseEvent) {
                    transactionEvents.append(event.copy())
                }
                
                func databaseWillCommit() throws {
                }
                
                func databaseDidCommit(_ db: Database) {
                    events = transactionEvents
                    transactionEvents = []
                }
                
                func databaseDidRollback(_ db: Database) {
                    events = []
                    transactionEvents = []
                }
                
                #if SQLITE_ENABLE_PREUPDATE_HOOK
                func databaseWillChange(with event: DatabasePreUpdateEvent) {
                }
                #endif
            }
            
            let dbQueue = try makeDatabaseQueue()
            let observer = Observer()
            dbQueue.add(transactionObserver: observer)
            
            try dbQueue.inDatabase { db in
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
                XCTAssertTrue(ReplacePolicy.fetchCount(db) == 1)
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
                XCTAssertTrue(ReplacePolicy.fetchCount(db) == 2)
                XCTAssertEqual(observer.events.count, 1)
                XCTAssertEqual(observer.events[0].kind, .insert)
                XCTAssertEqual(observer.events[0].rowID, 3)
                record.email = "arthur@example.com"
                try record.update(db)
                XCTAssertTrue(ReplacePolicy.fetchCount(db) == 1)
                XCTAssertEqual(Int64.fetchOne(db, "SELECT id FROM records")!, 3)
                XCTAssertEqual(observer.events.count, 1)
                XCTAssertEqual(observer.events[0].kind, .update)
                XCTAssertEqual(observer.events[0].rowID, 3)
            }
        }
    }
    
    func testIgnorePolicy() {
        assertNoError {
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
    }
    
    func testFailPolicy() {
        assertNoError {
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
    }
    
    func testAbortPolicy() {
        assertNoError {
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
    }
    
    func testRollbackPolicy() {
        assertNoError {
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
}

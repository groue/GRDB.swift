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
    static let persistenceConflictPolicy = PersistenceConflictPolicy(insertion: .fail, update: .rollback)
    
    var persistentDictionary: [String: DatabaseValueConvertible?] {
        return ["id": id]
    }
    
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

private struct ReplacePolicy: MutablePersistable {
    var id: Int64?
    
    static let databaseTableName = "records"
    static let persistenceConflictPolicy = PersistenceConflictPolicy(insertion: .replace, update: .replace)
    
    var persistentDictionary: [String: DatabaseValueConvertible?] {
        return ["id": id]
    }
    
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

private struct IgnorePolicy: MutablePersistable {
    var id: Int64?
    
    static let databaseTableName = "records"
    static let persistenceConflictPolicy = PersistenceConflictPolicy(insertion: .ignore, update: .ignore)
    
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
    static let persistenceConflictPolicy = PersistenceConflictPolicy(insertion: .fail, update: .fail)
    
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
    static let persistenceConflictPolicy = PersistenceConflictPolicy(insertion: .abort, update: .abort)
    
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
    static let persistenceConflictPolicy = PersistenceConflictPolicy(insertion: .rollback, update: .rollback)
    
    var persistentDictionary: [String: DatabaseValueConvertible?] {
        return ["id": id]
    }
    
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

class PersistenceConflictPolicyTests: GRDBTestCase {
    
    func testDefaultPolicy() {
        assertNoError {
            let db = try makeDatabaseQueue()
            try db.inDatabase { db in
                try db.create(table: "records") { t in
                    t.column("id", .integer).primaryKey()
                }
                
                // Insert
                var record = DefaultPolicy(id: nil)
                try record.insert(db)
                XCTAssertTrue(self.lastSQLQuery.hasPrefix("INSERT INTO \"records\""))
                XCTAssertTrue(record.id == 1)
                
                // Update
                record = DefaultPolicy(id: 1)
                try record.update(db)
                XCTAssertTrue(self.lastSQLQuery.hasPrefix("UPDATE \"records\""))
            }
        }
    }
    
    func testMixedPolicy() {
        assertNoError {
            let db = try makeDatabaseQueue()
            try db.inDatabase { db in
                try db.create(table: "records") { t in
                    t.column("id", .integer).primaryKey()
                }
                
                // Insert
                var record = MixedPolicy(id: nil)
                try record.insert(db)
                XCTAssertTrue(self.lastSQLQuery.hasPrefix("INSERT OR FAIL INTO \"records\""))
                XCTAssertTrue(record.id == 1)
                
                // Update
                record = MixedPolicy(id: 1)
                try record.update(db)
                XCTAssertTrue(self.lastSQLQuery.hasPrefix("UPDATE OR ROLLBACK \"records\""))
            }
        }
    }
    
    func testReplacePolicy() {
        assertNoError {
            let db = try makeDatabaseQueue()
            try db.inDatabase { db in
                try db.create(table: "records") { t in
                    t.column("id", .integer).primaryKey()
                }
                
                // Insert
                var record = ReplacePolicy(id: nil)
                try record.insert(db)
                XCTAssertTrue(self.lastSQLQuery.hasPrefix("INSERT OR REPLACE INTO \"records\""))
                XCTAssertTrue(record.id == nil)
                
                // Update
                record = ReplacePolicy(id: 1)
                try record.update(db)
                XCTAssertTrue(self.lastSQLQuery.hasPrefix("UPDATE OR REPLACE \"records\""))
            }
        }
    }
    
    func testIgnorePolicy() {
        assertNoError {
            let db = try makeDatabaseQueue()
            try db.inDatabase { db in
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
            let db = try makeDatabaseQueue()
            try db.inDatabase { db in
                try db.create(table: "records") { t in
                    t.column("id", .integer).primaryKey()
                }
                
                // Insert
                var record = FailPolicy(id: nil)
                try record.insert(db)
                XCTAssertTrue(self.lastSQLQuery.hasPrefix("INSERT OR FAIL INTO \"records\""))
                XCTAssertTrue(record.id == 1)
                
                // Update
                record = FailPolicy(id: 1)
                try record.update(db)
                XCTAssertTrue(self.lastSQLQuery.hasPrefix("UPDATE OR FAIL \"records\""))
            }
        }
    }
    
    func testAbortPolicy() {
        assertNoError {
            let db = try makeDatabaseQueue()
            try db.inDatabase { db in
                try db.create(table: "records") { t in
                    t.column("id", .integer).primaryKey()
                }
                
                // Insert
                var record = AbortPolicy(id: nil)
                try record.insert(db)
                XCTAssertTrue(self.lastSQLQuery.hasPrefix("INSERT INTO \"records\""))
                XCTAssertTrue(record.id == 1)
                
                // Update
                record = AbortPolicy(id: 1)
                try record.update(db)
                XCTAssertTrue(self.lastSQLQuery.hasPrefix("UPDATE \"records\""))
            }
        }
    }
    
    func testRollbackPolicy() {
        assertNoError {
            let db = try makeDatabaseQueue()
            try db.inDatabase { db in
                try db.create(table: "records") { t in
                    t.column("id", .integer).primaryKey()
                }
                
                // Insert
                var record = RollbackPolicy(id: nil)
                try record.insert(db)
                XCTAssertTrue(self.lastSQLQuery.hasPrefix("INSERT OR ROLLBACK INTO \"records\""))
                XCTAssertTrue(record.id == 1)
                
                // Update
                record = RollbackPolicy(id: 1)
                try record.update(db)
                XCTAssertTrue(self.lastSQLQuery.hasPrefix("UPDATE OR ROLLBACK \"records\""))
            }
        }
    }
    
}

import XCTest
import GRDB

class TransactionDateTests: GRDBTestCase {
    func testTransactionDateOutsideOfTransaction() throws {
        let dates = [
            Date.distantPast,
            Date(),
            Date.distantFuture,
        ]
        let dateIteratorMutex = Mutex(dates.makeIterator())
        dbConfiguration.transactionClock = .custom { _ in
            dateIteratorMutex.withLock { $0.next()! }
        }
        
        var collectedDates: [Date] = []
        try makeDatabaseQueue().inDatabase { db in
            try collectedDates.append(db.transactionDate)
            try collectedDates.append(db.transactionDate)
            try collectedDates.append(db.transactionDate)
        }
        XCTAssertEqual(collectedDates, dates)
    }
    
    func testTransactionDateInsideTransaction_commit() throws {
        let dates = [
            Date.distantPast,
            Date(),
            Date.distantFuture,
        ]
        let dateIteratorMutex = Mutex(dates.makeIterator())
        dbConfiguration.transactionClock = .custom { _ in
            dateIteratorMutex.withLock { $0.next()! }
        }
        
        var collectedDates: [Date] = []
        try makeDatabaseQueue().inDatabase { db in
            try collectedDates.append(db.transactionDate)
            try db.execute(sql: "BEGIN")
            try collectedDates.append(db.transactionDate)
            try collectedDates.append(db.transactionDate)
            try db.execute(sql: "COMMIT")
            try collectedDates.append(db.transactionDate)
        }
        XCTAssertEqual(collectedDates, [dates[0], dates[1], dates[1], dates[2]])
    }
    
    func testTransactionDateInsideTransaction_rollback() throws {
        let dates = [
            Date.distantPast,
            Date(),
            Date.distantFuture,
        ]
        let dateIteratorMutex = Mutex(dates.makeIterator())
        dbConfiguration.transactionClock = .custom { _ in
            dateIteratorMutex.withLock { $0.next()! }
        }
        
        var collectedDates: [Date] = []
        try makeDatabaseQueue().inDatabase { db in
            try collectedDates.append(db.transactionDate)
            try db.execute(sql: "BEGIN")
            try collectedDates.append(db.transactionDate)
            try collectedDates.append(db.transactionDate)
            try db.execute(sql: "ROLLBACK")
            try collectedDates.append(db.transactionDate)
        }
        XCTAssertEqual(collectedDates, [dates[0], dates[1], dates[1], dates[2]])
    }
    
    func testTransactionDateInsideTransaction_rollbackingError() throws {
        let dates = [
            Date.distantPast,
            Date(),
            Date.distantFuture,
        ]
        let dateIteratorMutex = Mutex(dates.makeIterator())
        dbConfiguration.transactionClock = .custom { _ in
            dateIteratorMutex.withLock { $0.next()! }
        }
        
        var collectedDates: [Date] = []
        try makeDatabaseQueue().inDatabase { db in
            try collectedDates.append(db.transactionDate)
            try db.execute(sql: "BEGIN")
            try collectedDates.append(db.transactionDate)
            try collectedDates.append(db.transactionDate)
            try? db.execute(sql: """
                CREATE TABLE t(id INTEGER PRIMARY KEY ON CONFLICT ROLLBACK);
                INSERT INTO t VALUES (1);
                INSERT INTO t VALUES (1); -- fails and rollbacks
                """)
            try collectedDates.append(db.transactionDate)
        }
        XCTAssertEqual(collectedDates, [dates[0], dates[1], dates[1], dates[2]])
    }
    
    func test_TimestampedRecord_default_willInsert() throws {
        struct Player: Codable, MutablePersistableRecord, FetchableRecord, TimestampedRecord {
            var id: Int64?
            var creationDate: Date?
            var modificationDate: Date?
            var name: String
            
            mutating func didInsert(_ inserted: InsertionSuccess) {
                id = inserted.rowID
            }
        }
        
        dbConfiguration.transactionClock = .custom { _ in .distantPast }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("creationDate", .datetime).notNull()
                t.column("modificationDate", .datetime).notNull()
                t.column("name", .text).notNull()
            }
        }
        
        try dbQueue.write { db in
            do {
                var player = Player(name: "Arthur")
                try player.insert(db)
                XCTAssertEqual(player.creationDate, .distantPast)
                XCTAssertEqual(player.modificationDate, .distantPast)
            }
            
            do {
                let customDate = Date()
                var player = Player(name: "Arthur")
                player.creationDate = customDate
                player.modificationDate = customDate
                try player.insert(db)
                XCTAssertEqual(player.creationDate, customDate)
                XCTAssertEqual(player.modificationDate, customDate)
            }
        }
    }
    
    func test_TimestampedRecord_updateWithTimestamp() throws {
        struct Player: Codable, MutablePersistableRecord, FetchableRecord, TimestampedRecord {
            var id: Int64?
            var creationDate: Date?
            var modificationDate: Date?
            var name: String
            
            mutating func didInsert(_ inserted: InsertionSuccess) {
                id = inserted.rowID
            }
        }
        
        let currentDate = Mutex(Date.distantPast)
        dbConfiguration.transactionClock = .custom { _ in currentDate.load() }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("creationDate", .datetime).notNull()
                t.column("modificationDate", .datetime).notNull()
                t.column("name", .text).notNull()
            }
        }
        
        try dbQueue.write { db in
            var player = Player(name: "Arthur")
            try player.insert(db)
        }
        
        let newTransactionDate = Date()
        currentDate.store(newTransactionDate)
        try dbQueue.write { db in
            var player = try Player.find(db, key: 1)
            
            player.name = "Barbara"
            try player.updateWithTimestamp(db)
            XCTAssertEqual(player.creationDate, .distantPast)
            XCTAssertEqual(player.modificationDate, newTransactionDate)
            
            try player.updateWithTimestamp(db, modificationDate: .distantFuture)
            XCTAssertEqual(player.creationDate, .distantPast)
            XCTAssertEqual(player.modificationDate, .distantFuture)
        }
    }
    
    func test_TimestampedRecord_updateChangesWithTimestamp() throws {
        struct Player: Codable, MutablePersistableRecord, FetchableRecord, TimestampedRecord {
            var id: Int64?
            var creationDate: Date?
            var modificationDate: Date?
            var name: String
            
            mutating func didInsert(_ inserted: InsertionSuccess) {
                id = inserted.rowID
            }
        }
        
        let currentDate = Mutex(Date.distantPast)
        dbConfiguration.transactionClock = .custom { _ in currentDate.load() }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("creationDate", .datetime).notNull()
                t.column("modificationDate", .datetime).notNull()
                t.column("name", .text).notNull()
            }
        }
        
        try dbQueue.write { db in
            var player = Player(name: "Arthur")
            try player.insert(db)
        }
        
        let newTransactionDate = Date()
        currentDate.store(newTransactionDate)
        try dbQueue.write { db in
            var player = try Player.find(db, key: 1)
            
            let changed = try player.updateChangesWithTimestamp(db) {
                $0.name = "Barbara"
            }
            XCTAssertTrue(changed)
            XCTAssertEqual(player.creationDate, .distantPast)
            XCTAssertEqual(player.modificationDate, newTransactionDate)
        }
        
        try dbQueue.write { db in
            var player = try Player.find(db, key: 1)
            
            let changed = try player.updateChangesWithTimestamp(db) {
                $0.name = "Barbara"
            }
            XCTAssertFalse(changed)
        }
    }
    
    func test_TimestampedRecord_touch() throws {
        struct Player: Codable, MutablePersistableRecord, FetchableRecord, TimestampedRecord {
            var id: Int64?
            var creationDate: Date?
            var modificationDate: Date?
            var name: String
            
            mutating func didInsert(_ inserted: InsertionSuccess) {
                id = inserted.rowID
            }
        }
        
        let currentDate = Mutex(Date.distantPast)
        dbConfiguration.transactionClock = .custom { _ in currentDate.load() }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("creationDate", .datetime).notNull()
                t.column("modificationDate", .datetime).notNull()
                t.column("name", .text).notNull()
            }
            
            var player = Player(name: "Arthur")
            try player.insert(db)
        }
        
        let newTransactionDate = Date()
        currentDate.store(newTransactionDate)
        try dbQueue.write { db in
            var player = try Player.find(db, key: 1)
            try player.touch(db)
            XCTAssertEqual(player.modificationDate, newTransactionDate)

            try player.touch(db, modificationDate: .distantFuture)
            XCTAssertEqual(player.modificationDate, .distantFuture)
        }
    }
    
    func test_TimestampedRecord_struct_with_customized_willInsert() throws {
        struct Player: Codable, TimestampedRecord, FetchableRecord {
            var id: Int64?
            var creationDate: Date?
            var modificationDate: Date?
            var name: String
            var isInserted = false // transient
            
            enum CodingKeys: String, CodingKey {
                case id
                case creationDate
                case modificationDate
                case name
            }
            
            mutating func willInsert(_ db: Database) throws {
                isInserted = true
                try initializeTimestamps(db)
            }
            
            mutating func didInsert(_ inserted: InsertionSuccess) {
                id = inserted.rowID
            }
        }
        
        dbConfiguration.transactionClock = .custom { _ in .distantPast }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("creationDate", .datetime).notNull()
                t.column("modificationDate", .datetime).notNull()
                t.column("name", .text).notNull()
            }
        }
        
        try dbQueue.write { db in
            var player = Player(name: "Arthur", isInserted: false)
            try player.insert(db)
            XCTAssertTrue(player.isInserted)
            XCTAssertEqual(player.creationDate, .distantPast)
            XCTAssertEqual(player.modificationDate, .distantPast)
        }
    }
    
    func test_TimestampedRecord_class_with_non_mutating_willInsert() throws {
        class Player: Codable, TimestampedRecord, PersistableRecord, FetchableRecord {
            var id: Int64?
            var creationDate: Date?
            var modificationDate: Date?
            var name: String
            
            init(id: Int64? = nil, creationDate: Date? = nil, modificationDate: Date? = nil, name: String) {
                self.id = id
                self.creationDate = creationDate
                self.modificationDate = modificationDate
                self.name = name
            }
            
            func willInsert(_ db: Database) throws {
                // Can't call initializeTimestamps because it is mutating
                if creationDate == nil {
                    creationDate = try db.transactionDate
                }
                if modificationDate == nil {
                    modificationDate = try db.transactionDate
                }
            }
            
            func didInsert(_ inserted: InsertionSuccess) {
                id = inserted.rowID
            }
        }
        
        dbConfiguration.transactionClock = .custom { _ in .distantPast }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("creationDate", .datetime).notNull()
                t.column("modificationDate", .datetime).notNull()
                t.column("name", .text).notNull()
            }
        }
        
        try dbQueue.write { db in
            let player = Player(name: "Arthur")
            try player.insert(db)
            XCTAssertEqual(player.creationDate, .distantPast)
            XCTAssertEqual(player.modificationDate, .distantPast)
        }
    }
}

// The protocol in RecordTimestamps.md

/// A record type that tracks its creation and modification dates. See
/// <https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/recordtimestamps>
protocol TimestampedRecord: MutablePersistableRecord {
    var creationDate: Date? { get set }
    var modificationDate: Date? { get set }
}

extension TimestampedRecord {
    /// By default, `TimestampedRecord` types set `creationDate` and
    /// `modificationDate` to the transaction date, if they are nil,
    /// before insertion.
    ///
    /// `TimestampedRecord` types that customize the `willInsert`
    /// persistence callback should call `initializeTimestamps` from
    /// their implementation.
    mutating func willInsert(_ db: Database) throws {
        try initializeTimestamps(db)
    }
    
    /// Sets `creationDate` and `modificationDate` to the transaction date,
    /// if they are nil.
    ///
    /// It is called automatically before insertion, if your type does not
    /// customize the `willInsert` persistence callback. If you customize
    /// this callback, call `initializeTimestamps` from your implementation.
    mutating func initializeTimestamps(_ db: Database) throws {
        if creationDate == nil {
            creationDate = try db.transactionDate
        }
        if modificationDate == nil {
            modificationDate = try db.transactionDate
        }
    }
    
    /// Sets `modificationDate`, and executes an `UPDATE` statement
    /// on all columns.
    ///
    /// - parameter modificationDate: The modification date. If nil, the
    ///   transaction date is used.
    mutating func updateWithTimestamp(_ db: Database, modificationDate: Date? = nil) throws {
        self.modificationDate = try modificationDate ?? db.transactionDate
        try update(db)
    }
    
    /// Modifies the record according to the provided `modify` closure, and,
    /// if and only if the record was modified, sets `modificationDate` and
    /// executes an `UPDATE` statement that updates the modified columns.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.write { db in
    ///     var player = Player.find(db, id: 1)
    ///     let modified = try player.updateChangesWithTimestamp(db) {
    ///         $0.score = 1000
    ///     }
    ///     if modified {
    ///         print("player was modified")
    ///     } else {
    ///         print("player was not modified")
    ///     }
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - modificationDate: The modification date. If nil, the
    ///       transaction date is used.
    ///     - modify: A closure that modifies the record.
    /// - returns: Whether the record was changed and updated.
    @discardableResult
    mutating func updateChangesWithTimestamp(
        _ db: Database,
        modificationDate: Date? = nil,
        modify: (inout Self) -> Void)
    throws -> Bool
    {
        // Grab the changes performed by `modify`
        let initialChanges = try databaseChanges(modify: modify)
        if initialChanges.isEmpty {
            return false
        }
        
        // Update modification date and grab its column name
        let dateChanges = try databaseChanges(modify: {
            $0.modificationDate = try modificationDate ?? db.transactionDate
        })
        
        // Update the modified columns
        let modifiedColumns = Set(initialChanges.keys).union(dateChanges.keys)
        try update(db, columns: modifiedColumns)
        return true
    }
    
    /// Sets `modificationDate`, and executes an `UPDATE` statement that
    /// updates the `modificationDate` column, if and only if the record
    /// was modified.
    ///
    /// - parameter modificationDate: The modification date. If nil, the
    ///   transaction date is used.
    mutating func touch(_ db: Database, modificationDate: Date? = nil) throws {
        try updateChanges(db) {
            $0.modificationDate = try modificationDate ?? db.transactionDate
        }
    }
}

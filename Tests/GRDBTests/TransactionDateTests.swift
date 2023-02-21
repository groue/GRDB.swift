import XCTest
import GRDB

class TransactionDateTests: GRDBTestCase {
    func testTransactionDateOutsideOfTransaction() throws {
        let dates = [
            Date.distantPast,
            Date(),
            Date.distantFuture,
        ]
        var dateIterator = dates.makeIterator()
        dbConfiguration.transactionClock = .custom { _ in
            dateIterator.next()!
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
        var dateIterator = dates.makeIterator()
        dbConfiguration.transactionClock = .custom { _ in
            dateIterator.next()!
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
        var dateIterator = dates.makeIterator()
        dbConfiguration.transactionClock = .custom { _ in
            dateIterator.next()!
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
        var dateIterator = dates.makeIterator()
        dbConfiguration.transactionClock = .custom { _ in
            dateIterator.next()!
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
    
    func test_TimestampedRecord_default() throws {
        struct Player: Codable, MutablePersistableRecord, FetchableRecord, TimestampedRecord {
            var id: Int64?
            var creationDate: Date?
            var modificationDate: Date?
            var name: String
            
            mutating func didInsert(_ inserted: InsertionSuccess) {
                id = inserted.rowID
            }
        }
        
        var currentDate = Date.distantPast
        dbConfiguration.transactionClock = .custom { _ in currentDate }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("creationDate", .datetime).notNull()
                t.column("modificationDate", .datetime).notNull()
                t.column("name", .text).notNull()
            }
        }
        
        currentDate = Date.distantPast
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
        
        let newTransactionDate = Date()
        currentDate = newTransactionDate
        try dbQueue.write { db in
            var player = try Player.fetchOne(db, key: 1)!
            
            player.name = "Barbara"
            try player.updateWithTimestamp(db)
            XCTAssertEqual(player.creationDate, .distantPast)
            XCTAssertEqual(player.modificationDate, newTransactionDate)
            
            try player.updateWithTimestamp(db, modificationDate: .distantFuture)
            XCTAssertEqual(player.creationDate, .distantPast)
            XCTAssertEqual(player.modificationDate, .distantFuture)
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
        
        var currentDate = Date.distantPast
        dbConfiguration.transactionClock = .custom { _ in currentDate }
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
        currentDate = newTransactionDate
        try dbQueue.write { db in
            var player = try Player.fetchOne(db, key: 1)!
            try player.touch(db)
            XCTAssertEqual(player.modificationDate, newTransactionDate)

            try player.touch(db, modificationDate: .distantFuture)
            XCTAssertEqual(player.modificationDate, .distantFuture)
        }
    }
    
    func test_TimestampedRecord_customized_willInsert() throws {
        struct Player: Codable, MutablePersistableRecord, FetchableRecord, TimestampedRecord {
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
        
        var currentDate = Date.distantPast
        dbConfiguration.transactionClock = .custom { _ in currentDate }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("creationDate", .datetime).notNull()
                t.column("modificationDate", .datetime).notNull()
                t.column("name", .text).notNull()
            }
        }
        
        currentDate = Date.distantPast
        try dbQueue.write { db in
            var player = Player(name: "Arthur", isInserted: false)
            try player.insert(db)
            XCTAssertTrue(player.isInserted)
            XCTAssertEqual(player.creationDate, .distantPast)
            XCTAssertEqual(player.modificationDate, .distantPast)
        }
    }
}

// The protocol in RecordTimestamps.md

/// A type that tracks its creation and modification dates. See
/// <https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/recordtimestamps>
protocol TimestampedRecord {
    var creationDate: Date? { get set }
    var modificationDate: Date? { get set }
}

extension TimestampedRecord where Self: MutablePersistableRecord {
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
    /// - parameter date: The modification date. If nil, the
    ///   transaction date is used.
    mutating func updateWithTimestamp(_ db: Database, modificationDate: Date? = nil) throws {
        self.modificationDate = try modificationDate ?? db.transactionDate
        try update(db)
    }
    
    /// Sets `modificationDate`, and executes an `UPDATE` statement that
    /// updates the `modificationDate` column, if and only if the record
    /// was modified.
    ///
    /// - parameter date: The modification date. If nil, the
    ///   transaction date is used.
    mutating func touch(_ db: Database, modificationDate: Date? = nil) throws {
        try updateChanges(db) {
            $0.modificationDate = try modificationDate ?? db.transactionDate
        }
    }
}

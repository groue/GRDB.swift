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
        
        let newTransactionDate = Date()
        currentDate = newTransactionDate
        try dbQueue.write { db in
            var player = try Player.fetchOne(db, key: 1)!
            player.name = "Barbara"
            try player.updateWithTimestamp(db)
            XCTAssertEqual(player.creationDate, .distantPast)
            XCTAssertEqual(player.modificationDate, newTransactionDate)
        }
    }
}

// The protocol in RecordTimestamps.md

/// A type that tracks its creation and modification dates, as described in
/// <https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/recordtimestamps>
protocol TimestampedRecord {
    var creationDate: Date? { get set }
    var modificationDate: Date? { get set }
}

extension TimestampedRecord {
    /// Sets `modificationDate` to the transaction date, and `creationDate` if
    /// not set yet.
    mutating func touch(_ db: Database) throws {
        if creationDate == nil {
            creationDate = try db.transactionDate
        }
        modificationDate = try db.transactionDate
    }
    
    /// Sets both `creationDate` and `modificationDate` to the transaction date,
    /// if they are not set yet.
    mutating func initializeTimestamps(_ db: Database) throws {
        if creationDate == nil {
            creationDate = try db.transactionDate
        }
        if modificationDate == nil {
            modificationDate = try db.transactionDate
        }
    }
}

extension TimestampedRecord where Self: MutablePersistableRecord {
    /// By default, TimestampedRecord types initialize their timestamps
    /// before insertion.
    ///
    /// Records that customize `willInsert` should call
    /// `initializeTimestamps` from their implementation.
    mutating func willInsert(_ db: Database) throws {
        try initializeTimestamps(db)
    }
    
    /// Sets `modificationDate` to the transaction date, and executes an
    /// `UPDATE` statement on all columns.
    mutating func updateWithTimestamp(_ db: Database) throws {
        try touch(db)
        try update(db)
    }
}

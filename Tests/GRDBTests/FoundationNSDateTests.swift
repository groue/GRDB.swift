import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class FoundationNSDateTests : GRDBTestCase {
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createDates") { db in
            try db.execute(sql: """
                CREATE TABLE dates (
                    ID INTEGER PRIMARY KEY,
                    creationDate DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP)
                """)
        }
        try migrator.migrate(dbWriter)
    }

    func testNSDate() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            
            let calendar = Calendar(identifier: .gregorian)
            let dateComponents = NSDateComponents()
            dateComponents.year = 1973
            dateComponents.month = 9
            dateComponents.day = 18
            dateComponents.hour = 10
            dateComponents.minute = 11
            dateComponents.second = 12
            dateComponents.nanosecond = 123_456_789
            
            do {
                let date = calendar.date(from: dateComponents as DateComponents)!
                try db.execute(sql: "INSERT INTO dates (creationDate) VALUES (?)", arguments: [date])
            }
            
            do {
                let date = try NSDate.fetchOne(db, sql: "SELECT creationDate FROM dates")!
                // All components must be preserved, but nanosecond since ISO-8601 stores milliseconds.
                XCTAssertEqual(calendar.component(.year, from: date as Date), dateComponents.year)
                XCTAssertEqual(calendar.component(.month, from: date as Date), dateComponents.month)
                XCTAssertEqual(calendar.component(.day, from: date as Date), dateComponents.day)
                XCTAssertEqual(calendar.component(.hour, from: date as Date), dateComponents.hour)
                XCTAssertEqual(calendar.component(.minute, from: date as Date), dateComponents.minute)
                XCTAssertEqual(calendar.component(.second, from: date as Date), dateComponents.second)
                XCTAssertEqual(round(Double(calendar.component(.nanosecond, from: date as Date)) / 1.0e6), round(Double(dateComponents.nanosecond) / 1.0e6))
            }
        }
    }

    func testNSDateIsLexicallyComparableToCURRENT_TIMESTAMP() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(
                sql: "INSERT INTO dates (id, creationDate) VALUES (?,?)",
                arguments: [1, NSDate().addingTimeInterval(-1)])
            
            try db.execute(
                sql: "INSERT INTO dates (id) VALUES (?)",
                arguments: [2])
            
            try db.execute(
                sql: "INSERT INTO dates (id, creationDate) VALUES (?,?)",
                arguments: [3, NSDate().addingTimeInterval(1)])
            
            let ids = try Int.fetchAll(db, sql: "SELECT id FROM dates ORDER BY creationDate")
            XCTAssertEqual(ids, [1,2,3])
        }
    }

    func testNSDateFromUnparsableString() {
        XCTAssertTrue(NSDate.fromDatabaseValue("foo".databaseValue) == nil)
    }
    
    func testNSDateDoesNotAcceptFormatHM() {
        XCTAssertTrue(NSDate.fromDatabaseValue("01:02".databaseValue) == nil)
    }
    
    func testNSDateDoesNotAcceptFormatHMS() {
        XCTAssertTrue(NSDate.fromDatabaseValue("01:02:03".databaseValue) == nil)
    }
    
    func testNSDateDoesNotAcceptFormatHMSS() {
        XCTAssertTrue(NSDate.fromDatabaseValue("01:02:03.00456".databaseValue) == nil)
    }
    
    func testNSDateAcceptsFormatYMD() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(
                sql: "INSERT INTO dates (creationDate) VALUES (?)",
                arguments: ["2015-07-22"])
            let date = try NSDate.fetchOne(db, sql: "SELECT creationDate from dates")!
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            XCTAssertEqual(calendar.component(.year, from: date as Date), 2015)
            XCTAssertEqual(calendar.component(.month, from: date as Date), 7)
            XCTAssertEqual(calendar.component(.day, from: date as Date), 22)
            XCTAssertEqual(calendar.component(.hour, from: date as Date), 0)
            XCTAssertEqual(calendar.component(.minute, from: date as Date), 0)
            XCTAssertEqual(calendar.component(.second, from: date as Date), 0)
            XCTAssertEqual(calendar.component(.nanosecond, from: date as Date), 0)
        }
    }

    func testNSDateAcceptsFormatYMD_HM() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(
                sql: "INSERT INTO dates (creationDate) VALUES (?)",
                arguments: ["2015-07-22 01:02"])
            let date = try NSDate.fetchOne(db, sql: "SELECT creationDate from dates")!
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            XCTAssertEqual(calendar.component(.year, from: date as Date), 2015)
            XCTAssertEqual(calendar.component(.month, from: date as Date), 7)
            XCTAssertEqual(calendar.component(.day, from: date as Date), 22)
            XCTAssertEqual(calendar.component(.hour, from: date as Date), 1)
            XCTAssertEqual(calendar.component(.minute, from: date as Date), 2)
            XCTAssertEqual(calendar.component(.second, from: date as Date), 0)
            XCTAssertEqual(calendar.component(.nanosecond, from: date as Date), 0)
        }
    }

    func testNSDateAcceptsFormatYMD_HMS() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(
                sql: "INSERT INTO dates (creationDate) VALUES (?)",
                arguments: ["2015-07-22 01:02:03"])
            let date = try NSDate.fetchOne(db, sql: "SELECT creationDate from dates")!
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            XCTAssertEqual(calendar.component(.year, from: date as Date), 2015)
            XCTAssertEqual(calendar.component(.month, from: date as Date), 7)
            XCTAssertEqual(calendar.component(.day, from: date as Date), 22)
            XCTAssertEqual(calendar.component(.hour, from: date as Date), 1)
            XCTAssertEqual(calendar.component(.minute, from: date as Date), 2)
            XCTAssertEqual(calendar.component(.second, from: date as Date), 3)
            XCTAssertEqual(calendar.component(.nanosecond, from: date as Date), 0)
        }
    }

    func testNSDateAcceptsFormatYMD_HMSS() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(
                sql: "INSERT INTO dates (creationDate) VALUES (?)",
                arguments: ["2015-07-22 01:02:03.00456"])
            let date = try NSDate.fetchOne(db, sql: "SELECT creationDate from dates")!
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            XCTAssertEqual(calendar.component(.year, from: date as Date), 2015)
            XCTAssertEqual(calendar.component(.month, from: date as Date), 7)
            XCTAssertEqual(calendar.component(.day, from: date as Date), 22)
            XCTAssertEqual(calendar.component(.hour, from: date as Date), 1)
            XCTAssertEqual(calendar.component(.minute, from: date as Date), 2)
            XCTAssertEqual(calendar.component(.second, from: date as Date), 3)
            XCTAssertTrue(abs(calendar.component(.nanosecond, from: date as Date) - 4_000_000) < 10)  // We actually get 4_000_008. Some precision is lost during the NSDateComponents -> NSDate conversion. Not a big deal.
        }
    }

    func testNSDateAcceptsTimestamp() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(
                sql: "INSERT INTO dates (creationDate) VALUES (?)",
                arguments: [1437526920])
            
            let string = try String.fetchOne(db, sql: "SELECT datetime(creationDate, 'unixepoch') from dates")!
            XCTAssertEqual(string, "2015-07-22 01:02:00")
            
            let date = try NSDate.fetchOne(db, sql: "SELECT creationDate from dates")!
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            XCTAssertEqual(calendar.component(.year, from: date as Date), 2015)
            XCTAssertEqual(calendar.component(.month, from: date as Date), 7)
            XCTAssertEqual(calendar.component(.day, from: date as Date), 22)
            XCTAssertEqual(calendar.component(.hour, from: date as Date), 1)
            XCTAssertEqual(calendar.component(.minute, from: date as Date), 2)
            XCTAssertEqual(calendar.component(.second, from: date as Date), 0)
            XCTAssertEqual(calendar.component(.nanosecond, from: date as Date), 0)
        }
    }
    
    func testNSDateAcceptsFormatIso8601YMD_HM() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(
                sql: "INSERT INTO dates (creationDate) VALUES (?)",
                arguments: ["2015-07-22T01:02"])
            let date = try NSDate.fetchOne(db, sql: "SELECT creationDate from dates")!
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            XCTAssertEqual(calendar.component(.year, from: date as Date), 2015)
            XCTAssertEqual(calendar.component(.month, from: date as Date), 7)
            XCTAssertEqual(calendar.component(.day, from: date as Date), 22)
            XCTAssertEqual(calendar.component(.hour, from: date as Date), 1)
            XCTAssertEqual(calendar.component(.minute, from: date as Date), 2)
            XCTAssertEqual(calendar.component(.second, from: date as Date), 0)
            XCTAssertEqual(calendar.component(.nanosecond, from: date as Date), 0)
        }
    }

    func testNSDateAcceptsFormatIso8601YMD_HMS() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(
                sql: "INSERT INTO dates (creationDate) VALUES (?)",
                arguments: ["2015-07-22T01:02:03"])
            let date = try NSDate.fetchOne(db, sql: "SELECT creationDate from dates")!
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            XCTAssertEqual(calendar.component(.year, from: date as Date), 2015)
            XCTAssertEqual(calendar.component(.month, from: date as Date), 7)
            XCTAssertEqual(calendar.component(.day, from: date as Date), 22)
            XCTAssertEqual(calendar.component(.hour, from: date as Date), 1)
            XCTAssertEqual(calendar.component(.minute, from: date as Date), 2)
            XCTAssertEqual(calendar.component(.second, from: date as Date), 3)
            XCTAssertEqual(calendar.component(.nanosecond, from: date as Date), 0)
        }
    }

    func testNSDateAcceptsFormatIso8601YMD_HMSS() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(
                sql: "INSERT INTO dates (creationDate) VALUES (?)",
                arguments: ["2015-07-22T01:02:03.00456"])
            let date = try NSDate.fetchOne(db, sql: "SELECT creationDate from dates")!
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            XCTAssertEqual(calendar.component(.year, from: date as Date), 2015)
            XCTAssertEqual(calendar.component(.month, from: date as Date), 7)
            XCTAssertEqual(calendar.component(.day, from: date as Date), 22)
            XCTAssertEqual(calendar.component(.hour, from: date as Date), 1)
            XCTAssertEqual(calendar.component(.minute, from: date as Date), 2)
            XCTAssertEqual(calendar.component(.second, from: date as Date), 3)
            XCTAssertTrue(abs(calendar.component(.nanosecond, from: date as Date) - 4_000_000) < 10)  // We actually get 4_000_008. Some precision is lost during the NSDateComponents -> NSDate conversion. Not a big deal.
        }
    }
}

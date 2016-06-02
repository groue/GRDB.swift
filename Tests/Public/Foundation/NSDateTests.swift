import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class NSDateTests : GRDBTestCase {
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createDates") { db in
            try db.execute(
                "CREATE TABLE dates (" +
                    "ID INTEGER PRIMARY KEY, " +
                    "creationDate DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" +
                ")")
        }
        try migrator.migrate(dbWriter)
    }

    func testNSDate() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                
                let calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
                let dateComponents = NSDateComponents()
                dateComponents.year = 1973
                dateComponents.month = 9
                dateComponents.day = 18
                dateComponents.hour = 10
                dateComponents.minute = 11
                dateComponents.second = 12
                dateComponents.nanosecond = 123_456_789
                
                do {
                    let date = calendar.date(from: dateComponents)!
                    try db.execute("INSERT INTO dates (creationDate) VALUES (?)", arguments: [date])
                }
                
                do {
                    let date = NSDate.fetchOne(db, "SELECT creationDate FROM dates")!
                    // All components must be preserved, but nanosecond since ISO-8601 stores milliseconds.
                    XCTAssertEqual(calendar.component(.year, from: date), dateComponents.year)
                    XCTAssertEqual(calendar.component(.month, from: date), dateComponents.month)
                    XCTAssertEqual(calendar.component(.day, from: date), dateComponents.day)
                    XCTAssertEqual(calendar.component(.hour, from: date), dateComponents.hour)
                    XCTAssertEqual(calendar.component(.minute, from: date), dateComponents.minute)
                    XCTAssertEqual(calendar.component(.second, from: date), dateComponents.second)
                    XCTAssertEqual(round(Double(calendar.component(.nanosecond, from: date)) / 1.0e6), round(Double(dateComponents.nanosecond) / 1.0e6))
                }
            }
        }
    }
    
    func testNSDateIsLexicallyComparableToCURRENT_TIMESTAMP() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute(
                    "INSERT INTO dates (id, creationDate) VALUES (?,?)",
                    arguments: [1, NSDate().addingTimeInterval(-1)])
                
                try db.execute(
                    "INSERT INTO dates (id) VALUES (?)",
                    arguments: [2])
                
                try db.execute(
                    "INSERT INTO dates (id, creationDate) VALUES (?,?)",
                    arguments: [3, NSDate().addingTimeInterval(1)])
                
                let ids = Int.fetchAll(db, "SELECT id FROM dates ORDER BY creationDate")
                XCTAssertEqual(ids, [1,2,3])
            }
        }
    }
    
    func testNSDateFromUnparsableString() {
        let date = NSDate.fromDatabaseValue("foo".databaseValue)
        XCTAssertTrue(date == nil)
    }
    
    func testNSDateDoesNotAcceptFormatHM() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute(
                    "INSERT INTO dates (creationDate) VALUES (?)",
                    arguments: ["01:02"])
                let date = NSDate.fetchOne(db, "SELECT creationDate from dates")
                XCTAssertTrue(date == nil)
            }
        }
    }
    
    func testNSDateDoesNotAcceptFormatHMS() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute(
                    "INSERT INTO dates (creationDate) VALUES (?)",
                    arguments: ["01:02:03"])
                let date = NSDate.fetchOne(db, "SELECT creationDate from dates")
                XCTAssertTrue(date == nil)
            }
        }
    }
    
    func testNSDateDoesNotAcceptFormatHMSS() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute(
                    "INSERT INTO dates (creationDate) VALUES (?)",
                    arguments: ["01:02:03.00456"])
                let date = NSDate.fetchOne(db, "SELECT creationDate from dates")
                XCTAssertTrue(date == nil)
            }
        }
    }
    
    func testNSDateAcceptsFormatYMD() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute(
                    "INSERT INTO dates (creationDate) VALUES (?)",
                    arguments: ["2015-07-22"])
                let date = NSDate.fetchOne(db, "SELECT creationDate from dates")!
                let calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
                calendar.timeZone = NSTimeZone(forSecondsFromGMT: 0)
                XCTAssertEqual(calendar.component(.year, from: date), 2015)
                XCTAssertEqual(calendar.component(.month, from: date), 7)
                XCTAssertEqual(calendar.component(.day, from: date), 22)
                XCTAssertEqual(calendar.component(.hour, from: date), 0)
                XCTAssertEqual(calendar.component(.minute, from: date), 0)
                XCTAssertEqual(calendar.component(.second, from: date), 0)
                XCTAssertEqual(calendar.component(.nanosecond, from: date), 0)
            }
        }
    }
    
    func testNSDateAcceptsFormatYMD_HM() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute(
                    "INSERT INTO dates (creationDate) VALUES (?)",
                    arguments: ["2015-07-22 01:02"])
                let date = NSDate.fetchOne(db, "SELECT creationDate from dates")!
                let calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
                calendar.timeZone = NSTimeZone(forSecondsFromGMT: 0)
                XCTAssertEqual(calendar.component(.year, from: date), 2015)
                XCTAssertEqual(calendar.component(.month, from: date), 7)
                XCTAssertEqual(calendar.component(.day, from: date), 22)
                XCTAssertEqual(calendar.component(.hour, from: date), 1)
                XCTAssertEqual(calendar.component(.minute, from: date), 2)
                XCTAssertEqual(calendar.component(.second, from: date), 0)
                XCTAssertEqual(calendar.component(.nanosecond, from: date), 0)
            }
        }
    }
    
    func testNSDateAcceptsFormatYMD_HMS() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute(
                    "INSERT INTO dates (creationDate) VALUES (?)",
                    arguments: ["2015-07-22 01:02:03"])
                let date = NSDate.fetchOne(db, "SELECT creationDate from dates")!
                let calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
                calendar.timeZone = NSTimeZone(forSecondsFromGMT: 0)
                XCTAssertEqual(calendar.component(.year, from: date), 2015)
                XCTAssertEqual(calendar.component(.month, from: date), 7)
                XCTAssertEqual(calendar.component(.day, from: date), 22)
                XCTAssertEqual(calendar.component(.hour, from: date), 1)
                XCTAssertEqual(calendar.component(.minute, from: date), 2)
                XCTAssertEqual(calendar.component(.second, from: date), 3)
                XCTAssertEqual(calendar.component(.nanosecond, from: date), 0)
            }
        }
    }
    
    func testNSDateAcceptsFormatYMD_HMSS() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute(
                    "INSERT INTO dates (creationDate) VALUES (?)",
                    arguments: ["2015-07-22 01:02:03.00456"])
                let date = NSDate.fetchOne(db, "SELECT creationDate from dates")!
                let calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
                calendar.timeZone = NSTimeZone(forSecondsFromGMT: 0)
                XCTAssertEqual(calendar.component(.year, from: date), 2015)
                XCTAssertEqual(calendar.component(.month, from: date), 7)
                XCTAssertEqual(calendar.component(.day, from: date), 22)
                XCTAssertEqual(calendar.component(.hour, from: date), 1)
                XCTAssertEqual(calendar.component(.minute, from: date), 2)
                XCTAssertEqual(calendar.component(.second, from: date), 3)
                XCTAssertTrue(abs(calendar.component(.nanosecond, from: date) - 4_000_000) < 10)  // We actually get 4_000_008. Some precision is lost during the NSDateComponents -> NSDate conversion. Not a big deal.
            }
        }
    }
    
    func testNSDateAcceptsJulianDayNumber() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                // 00:30:00.0 UT January 1, 2013 according to https://en.wikipedia.org/wiki/Julian_day
                try db.execute(
                    "INSERT INTO dates (creationDate) VALUES (?)",
                    arguments: [2_456_293.520833])
                
                let string = String.fetchOne(db, "SELECT datetime(creationDate) from dates")!
                XCTAssertEqual(string, "2013-01-01 00:29:59")
                
                let date = NSDate.fetchOne(db, "SELECT creationDate from dates")!
                let calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
                calendar.timeZone = NSTimeZone(forSecondsFromGMT: 0)
                XCTAssertEqual(calendar.component(.year, from: date), 2013)
                XCTAssertEqual(calendar.component(.month, from: date), 1)
                XCTAssertEqual(calendar.component(.day, from: date), 1)
                XCTAssertEqual(calendar.component(.hour, from: date), 0)
                XCTAssertEqual(calendar.component(.minute, from: date), 29)
                XCTAssertEqual(calendar.component(.second, from: date), 59)
            }
        }
    }

    func testNSDateAcceptsFormatIso8601YMD_HM() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute(
                    "INSERT INTO dates (creationDate) VALUES (?)",
                    arguments: ["2015-07-22T01:02"])
                let date = NSDate.fetchOne(db, "SELECT creationDate from dates")!
                let calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
                calendar.timeZone = NSTimeZone(forSecondsFromGMT: 0)
                XCTAssertEqual(calendar.component(.year, from: date), 2015)
                XCTAssertEqual(calendar.component(.month, from: date), 7)
                XCTAssertEqual(calendar.component(.day, from: date), 22)
                XCTAssertEqual(calendar.component(.hour, from: date), 1)
                XCTAssertEqual(calendar.component(.minute, from: date), 2)
                XCTAssertEqual(calendar.component(.second, from: date), 0)
                XCTAssertEqual(calendar.component(.nanosecond, from: date), 0)
            }
        }
    }
    
    func testNSDateAcceptsFormatIso8601YMD_HMS() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute(
                    "INSERT INTO dates (creationDate) VALUES (?)",
                    arguments: ["2015-07-22T01:02:03"])
                let date = NSDate.fetchOne(db, "SELECT creationDate from dates")!
                let calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
                calendar.timeZone = NSTimeZone(forSecondsFromGMT: 0)
                XCTAssertEqual(calendar.component(.year, from: date), 2015)
                XCTAssertEqual(calendar.component(.month, from: date), 7)
                XCTAssertEqual(calendar.component(.day, from: date), 22)
                XCTAssertEqual(calendar.component(.hour, from: date), 1)
                XCTAssertEqual(calendar.component(.minute, from: date), 2)
                XCTAssertEqual(calendar.component(.second, from: date), 3)
                XCTAssertEqual(calendar.component(.nanosecond, from: date), 0)
            }
        }
    }
    
    func testNSDateAcceptsFormatIso8601YMD_HMSS() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute(
                    "INSERT INTO dates (creationDate) VALUES (?)",
                    arguments: ["2015-07-22T01:02:03.00456"])
                let date = NSDate.fetchOne(db, "SELECT creationDate from dates")!
                let calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
                calendar.timeZone = NSTimeZone(forSecondsFromGMT: 0)
                XCTAssertEqual(calendar.component(.year, from: date), 2015)
                XCTAssertEqual(calendar.component(.month, from: date), 7)
                XCTAssertEqual(calendar.component(.day, from: date), 22)
                XCTAssertEqual(calendar.component(.hour, from: date), 1)
                XCTAssertEqual(calendar.component(.minute, from: date), 2)
                XCTAssertEqual(calendar.component(.second, from: date), 3)
                XCTAssertTrue(abs(calendar.component(.nanosecond, from: date) - 4_000_000) < 10)  // We actually get 4_000_008. Some precision is lost during the NSDateComponents -> NSDate conversion. Not a big deal.
            }
        }
    }
}

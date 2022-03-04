import XCTest
import GRDB

class FoundationDateTests : GRDBTestCase {
    
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

    func testDate() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            
            let calendar = Calendar(identifier: .gregorian)
            var dateComponents = DateComponents()
            dateComponents.year = 1973
            dateComponents.month = 9
            dateComponents.day = 18
            dateComponents.hour = 10
            dateComponents.minute = 11
            dateComponents.second = 12
            dateComponents.nanosecond = 123_456_789
            
            do {
                let date = calendar.date(from: dateComponents)!
                try db.execute(sql: "INSERT INTO dates (creationDate) VALUES (?)", arguments: [date])
            }
            
            do {
                let date = try Date.fetchOne(db, sql: "SELECT creationDate FROM dates")!
                // All components must be preserved, but nanosecond since ISO-8601 stores milliseconds.
                XCTAssertEqual(calendar.component(.year, from: date), dateComponents.year)
                XCTAssertEqual(calendar.component(.month, from: date), dateComponents.month)
                XCTAssertEqual(calendar.component(.day, from: date), dateComponents.day)
                XCTAssertEqual(calendar.component(.hour, from: date), dateComponents.hour)
                XCTAssertEqual(calendar.component(.minute, from: date), dateComponents.minute)
                XCTAssertEqual(calendar.component(.second, from: date), dateComponents.second)
                XCTAssertEqual(round(Double(calendar.component(.nanosecond, from: date)) / 1.0e6), round(Double(dateComponents.nanosecond!) / 1.0e6))
            }
        }
    }

    func testDateIsLexicallyComparableToCURRENT_TIMESTAMP() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(
                sql: "INSERT INTO dates (id, creationDate) VALUES (?,?)",
                arguments: [1, Date().addingTimeInterval(-1)])
            
            try db.execute(
                sql: "INSERT INTO dates (id) VALUES (?)",
                arguments: [2])
            
            try db.execute(
                sql: "INSERT INTO dates (id, creationDate) VALUES (?,?)",
                arguments: [3, Date().addingTimeInterval(1)])
            
            let ids = try Int.fetchAll(db, sql: "SELECT id FROM dates ORDER BY creationDate")
            XCTAssertEqual(ids, [1,2,3])
        }
    }

    func testDateFromUnparsableString() {
        XCTAssertTrue(Date.fromDatabaseValue("foo".databaseValue) == nil)
    }
    
    func testDateDoesNotAcceptFormatHM() {
        XCTAssertTrue(Date.fromDatabaseValue("01:02".databaseValue) == nil)
    }
    
    func testDateDoesNotAcceptFormatHMS() {
        XCTAssertTrue(Date.fromDatabaseValue("01:02:03".databaseValue) == nil)
    }
    
    func testDateDoesNotAcceptFormatHMSS() {
        XCTAssertTrue(Date.fromDatabaseValue("01:02:03.00456".databaseValue) == nil)
    }
    
    func testDateFromJulianDayNumber() throws {
        // 00:30:00.0 UT January 1, 2013 according to https://en.wikipedia.org/wiki/Julian_day
        let jdn = 2_456_293.520833
        guard let date = Date(julianDay: jdn) else {
            XCTFail()
            return
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        XCTAssertEqual(calendar.component(.year, from: date), 2013)
        XCTAssertEqual(calendar.component(.month, from: date), 1)
        XCTAssertEqual(calendar.component(.day, from: date), 1)
        XCTAssertEqual(calendar.component(.hour, from: date), 0)
        XCTAssertEqual(calendar.component(.minute, from: date), 29) // actual SQLite result
        XCTAssertEqual(calendar.component(.second, from: date), 59) // actual SQLite result
    }
    
    func testDateAcceptsFormatYMD() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(
                sql: "INSERT INTO dates (creationDate) VALUES (?)",
                arguments: ["2015-07-22"])
            let date = try Date.fetchOne(db, sql: "SELECT creationDate from dates")!
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            XCTAssertEqual(calendar.component(.year, from: date), 2015)
            XCTAssertEqual(calendar.component(.month, from: date), 7)
            XCTAssertEqual(calendar.component(.day, from: date), 22)
            XCTAssertEqual(calendar.component(.hour, from: date), 0)
            XCTAssertEqual(calendar.component(.minute, from: date), 0)
            XCTAssertEqual(calendar.component(.second, from: date), 0)
            XCTAssertEqual(calendar.component(.nanosecond, from: date), 0)
        }
    }

    func testDateAcceptsFormatYMD_HM() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(
                sql: "INSERT INTO dates (creationDate) VALUES (?)",
                arguments: ["2015-07-22 01:02"])
            let date = try Date.fetchOne(db, sql: "SELECT creationDate from dates")!
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            XCTAssertEqual(calendar.component(.year, from: date), 2015)
            XCTAssertEqual(calendar.component(.month, from: date), 7)
            XCTAssertEqual(calendar.component(.day, from: date), 22)
            XCTAssertEqual(calendar.component(.hour, from: date), 1)
            XCTAssertEqual(calendar.component(.minute, from: date), 2)
            XCTAssertEqual(calendar.component(.second, from: date), 0)
            XCTAssertEqual(calendar.component(.nanosecond, from: date), 0)
        }
    }

    func testDateAcceptsFormatYMD_HMZ() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(
                sql: "INSERT INTO dates (creationDate) VALUES (?)",
                arguments: ["2015-07-22 01:02+01:15"])
            let date = try Date.fetchOne(db, sql: "SELECT creationDate from dates")!
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            XCTAssertEqual(calendar.component(.year, from: date), 2015)
            XCTAssertEqual(calendar.component(.month, from: date), 7)
            XCTAssertEqual(calendar.component(.day, from: date), 21)
            XCTAssertEqual(calendar.component(.hour, from: date), 23)
            XCTAssertEqual(calendar.component(.minute, from: date), 47)
            XCTAssertEqual(calendar.component(.second, from: date), 0)
            XCTAssertEqual(calendar.component(.nanosecond, from: date), 0)
        }
    }

    func testDateAcceptsFormatYMD_HMS() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(
                sql: "INSERT INTO dates (creationDate) VALUES (?)",
                arguments: ["2015-07-22 01:02:03"])
            let date = try Date.fetchOne(db, sql: "SELECT creationDate from dates")!
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            XCTAssertEqual(calendar.component(.year, from: date), 2015)
            XCTAssertEqual(calendar.component(.month, from: date), 7)
            XCTAssertEqual(calendar.component(.day, from: date), 22)
            XCTAssertEqual(calendar.component(.hour, from: date), 1)
            XCTAssertEqual(calendar.component(.minute, from: date), 2)
            XCTAssertEqual(calendar.component(.second, from: date), 3)
            XCTAssertEqual(calendar.component(.nanosecond, from: date), 0)
        }
    }

    func testDateAcceptsFormatYMD_HMSZ() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(
                sql: "INSERT INTO dates (creationDate) VALUES (?)",
                arguments: ["2015-07-22 01:02:03+01:15"])
            let date = try Date.fetchOne(db, sql: "SELECT creationDate from dates")!
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            XCTAssertEqual(calendar.component(.year, from: date), 2015)
            XCTAssertEqual(calendar.component(.month, from: date), 7)
            XCTAssertEqual(calendar.component(.day, from: date), 21)
            XCTAssertEqual(calendar.component(.hour, from: date), 23)
            XCTAssertEqual(calendar.component(.minute, from: date), 47)
            XCTAssertEqual(calendar.component(.second, from: date), 3)
            XCTAssertEqual(calendar.component(.nanosecond, from: date), 0)
        }
    }

    func testDateAcceptsFormatYMD_HMSS() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(
                sql: "INSERT INTO dates (creationDate) VALUES (?)",
                arguments: ["2015-07-22 01:02:03.00456"])
            let date = try Date.fetchOne(db, sql: "SELECT creationDate from dates")!
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            XCTAssertEqual(calendar.component(.year, from: date), 2015)
            XCTAssertEqual(calendar.component(.month, from: date), 7)
            XCTAssertEqual(calendar.component(.day, from: date), 22)
            XCTAssertEqual(calendar.component(.hour, from: date), 1)
            XCTAssertEqual(calendar.component(.minute, from: date), 2)
            XCTAssertEqual(calendar.component(.second, from: date), 3)
            XCTAssertTrue(abs(calendar.component(.nanosecond, from: date) - 4_000_000) < 10)  // We actually get 4_000_008. Some precision is lost during the DateComponents -> Date conversion. Not a big deal.
        }
    }

    func testDateAcceptsFormatYMD_HMSSZ() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(
                sql: "INSERT INTO dates (creationDate) VALUES (?)",
                arguments: ["2015-07-22 01:02:03.00456+01:15"])
            let date = try Date.fetchOne(db, sql: "SELECT creationDate from dates")!
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            XCTAssertEqual(calendar.component(.year, from: date), 2015)
            XCTAssertEqual(calendar.component(.month, from: date), 7)
            XCTAssertEqual(calendar.component(.day, from: date), 21)
            XCTAssertEqual(calendar.component(.hour, from: date), 23)
            XCTAssertEqual(calendar.component(.minute, from: date), 47)
            XCTAssertEqual(calendar.component(.second, from: date), 3)
            XCTAssertTrue(abs(calendar.component(.nanosecond, from: date) - 4_000_000) < 10)  // We actually get 4_000_008. Some precision is lost during the DateComponents -> Date conversion. Not a big deal.
        }
    }

    func testDateAcceptsTimestamp() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(
                sql: "INSERT INTO dates (creationDate) VALUES (?)",
                arguments: [1437526920])
            
            let string = try String.fetchOne(db, sql: "SELECT datetime(creationDate, 'unixepoch') from dates")!
            XCTAssertEqual(string, "2015-07-22 01:02:00")
            
            let date = try Date.fetchOne(db, sql: "SELECT creationDate from dates")!
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            XCTAssertEqual(calendar.component(.year, from: date), 2015)
            XCTAssertEqual(calendar.component(.month, from: date), 7)
            XCTAssertEqual(calendar.component(.day, from: date), 22)
            XCTAssertEqual(calendar.component(.hour, from: date), 1)
            XCTAssertEqual(calendar.component(.minute, from: date), 2)
            XCTAssertEqual(calendar.component(.second, from: date), 0)
            XCTAssertEqual(calendar.component(.nanosecond, from: date), 0)
        }
    }

    func testDateAcceptsFormatIso8601YMD_HM() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(
                sql: "INSERT INTO dates (creationDate) VALUES (?)",
                arguments: ["2015-07-22T01:02"])
            let date = try Date.fetchOne(db, sql: "SELECT creationDate from dates")!
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            XCTAssertEqual(calendar.component(.year, from: date), 2015)
            XCTAssertEqual(calendar.component(.month, from: date), 7)
            XCTAssertEqual(calendar.component(.day, from: date), 22)
            XCTAssertEqual(calendar.component(.hour, from: date), 1)
            XCTAssertEqual(calendar.component(.minute, from: date), 2)
            XCTAssertEqual(calendar.component(.second, from: date), 0)
            XCTAssertEqual(calendar.component(.nanosecond, from: date), 0)
        }
    }

    func testDateAcceptsFormatIso8601YMD_HMS() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(
                sql: "INSERT INTO dates (creationDate) VALUES (?)",
                arguments: ["2015-07-22T01:02:03"])
            let date = try Date.fetchOne(db, sql: "SELECT creationDate from dates")!
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            XCTAssertEqual(calendar.component(.year, from: date), 2015)
            XCTAssertEqual(calendar.component(.month, from: date), 7)
            XCTAssertEqual(calendar.component(.day, from: date), 22)
            XCTAssertEqual(calendar.component(.hour, from: date), 1)
            XCTAssertEqual(calendar.component(.minute, from: date), 2)
            XCTAssertEqual(calendar.component(.second, from: date), 3)
            XCTAssertEqual(calendar.component(.nanosecond, from: date), 0)
        }
    }

    func testDateAcceptsFormatIso8601YMD_HMSS() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(
                sql: "INSERT INTO dates (creationDate) VALUES (?)",
                arguments: ["2015-07-22T01:02:03.00456"])
            let date = try Date.fetchOne(db, sql: "SELECT creationDate from dates")!
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            XCTAssertEqual(calendar.component(.year, from: date), 2015)
            XCTAssertEqual(calendar.component(.month, from: date), 7)
            XCTAssertEqual(calendar.component(.day, from: date), 22)
            XCTAssertEqual(calendar.component(.hour, from: date), 1)
            XCTAssertEqual(calendar.component(.minute, from: date), 2)
            XCTAssertEqual(calendar.component(.second, from: date), 3)
            XCTAssertTrue(abs(calendar.component(.nanosecond, from: date) - 4_000_000) < 10)  // We actually get 4_000_008. Some precision is lost during the DateComponents -> Date conversion. Not a big deal.
        }
    }
    
    func testJulianDaySQLFunction() throws {
        // 00:30:00.0 UT January 1, 2013 according to https://en.wikipedia.org/wiki/Julian_day
        let jdn = 2_456_293.520833
        guard let date = Date(julianDay: jdn) else {
            XCTFail()
            return
        }
        
        func assert(
            _ db: Database,
            _ expression: SQLExpression,
            equal expectedDate: Date,
            file: StaticString = #filePath,
            line: UInt = #line) throws
        {
            let request: SQLRequest<Double> = "SELECT \(expression)"
            guard let shiftedDate = try request.fetchOne(db).flatMap(Date.init(julianDay:)) else {
                XCTFail(file: file, line: line)
                return
            }
            let shiftedInterval = shiftedDate.timeIntervalSince(date)
            let expectedInterval = expectedDate.timeIntervalSince(date)
            XCTAssertEqual(shiftedInterval, expectedInterval, accuracy: 0.1, file: file, line: line)
        }
                
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let dbDate = date.databaseValue
            try assert(db, julianDay(dbDate), equal: date)
            try assert(db, julianDay(dbDate, .day(1)), equal: date.addingTimeInterval(86400))
            try assert(db, julianDay(dbDate, .day(-1)), equal: date.addingTimeInterval(-86400))
            try assert(db, julianDay(dbDate, .hour(1)), equal: date.addingTimeInterval(3600))
            try assert(db, julianDay(dbDate, .hour(-1)), equal: date.addingTimeInterval(-3600))
            try assert(db, julianDay(dbDate, .minute(1)), equal: date.addingTimeInterval(60))
            try assert(db, julianDay(dbDate, .minute(-1)), equal: date.addingTimeInterval(-60))
            try assert(db, julianDay(dbDate, .second(1)), equal: date.addingTimeInterval(1))
            try assert(db, julianDay(dbDate, .second(-1)), equal: date.addingTimeInterval(-1))
            try assert(db, julianDay(dbDate, .second(1.5)), equal: date.addingTimeInterval(1.5))
            try assert(db, julianDay(dbDate, .month(1)), equal: date.addingTimeInterval(2678400))
            try assert(db, julianDay(dbDate, .month(-1)), equal: date.addingTimeInterval(-2678400))
            try assert(db, julianDay(dbDate, .year(1)), equal: date.addingTimeInterval(31536000))
            try assert(db, julianDay(dbDate, .year(-1)), equal: date.addingTimeInterval(-31622400))
            try assert(db, julianDay(dbDate, .startOfDay), equal: date.addingTimeInterval(-1800))
            try assert(db, julianDay(dbDate, .startOfMonth), equal: date.addingTimeInterval(-1800))
            try assert(db, julianDay(dbDate, .startOfYear), equal: date.addingTimeInterval(-1800))
            try assert(db, julianDay(dbDate, .startOfMonth, .month(+1), .day(-1)), equal: date.addingTimeInterval(2590200))
        }
    }
    
    func testDateTimeSQLFunction() throws {
        // 00:30:00.0 UT January 1, 2013 according to https://en.wikipedia.org/wiki/Julian_day
        let jdn = 2_456_293.520833
        guard let date = Date(julianDay: jdn) else {
            XCTFail()
            return
        }
        
        func assert(
            _ db: Database,
            _ expression: SQLExpression,
            equal expectedDate: String,
            file: StaticString = #filePath,
            line: UInt = #line) throws
        {
            let request: SQLRequest<String> = "SELECT \(expression)"
            guard let shiftedDate = try request.fetchOne(db) else {
                XCTFail(file: file, line: line)
                return
            }
            XCTAssertEqual(shiftedDate, expectedDate, file: file, line: line)
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let dbDate = date.databaseValue
            try assert(db, dateTime(dbDate), equal: "2013-01-01 00:29:59")
            try assert(db, dateTime(dbDate, .day(1)), equal: "2013-01-02 00:29:59")
            try assert(db, dateTime(dbDate, .day(-1)), equal: "2012-12-31 00:29:59")
            try assert(db, dateTime(dbDate, .hour(1)), equal: "2013-01-01 01:29:59")
            try assert(db, dateTime(dbDate, .hour(-1)), equal: "2012-12-31 23:29:59")
            try assert(db, dateTime(dbDate, .minute(1)), equal: "2013-01-01 00:30:59")
            try assert(db, dateTime(dbDate, .minute(-1)), equal: "2013-01-01 00:28:59")
            try assert(db, dateTime(dbDate, .second(1)), equal: "2013-01-01 00:30:00")
            try assert(db, dateTime(dbDate, .second(-1)), equal: "2013-01-01 00:29:58")
            try assert(db, dateTime(dbDate, .second(1.5)), equal: "2013-01-01 00:30:01")
            try assert(db, dateTime(dbDate, .month(1)), equal: "2013-02-01 00:29:59")
            try assert(db, dateTime(dbDate, .month(-1)), equal: "2012-12-01 00:29:59")
            try assert(db, dateTime(dbDate, .year(1)), equal: "2014-01-01 00:29:59")
            try assert(db, dateTime(dbDate, .year(-1)), equal: "2012-01-01 00:29:59")
            try assert(db, dateTime(dbDate, .startOfDay), equal: "2013-01-01 00:00:00")
            try assert(db, dateTime(dbDate, .startOfMonth), equal: "2013-01-01 00:00:00")
            try assert(db, dateTime(dbDate, .startOfYear), equal: "2013-01-01 00:00:00")
            try assert(db, dateTime(dbDate, .startOfMonth, .month(+1), .day(-1)), equal: "2013-01-31 00:00:00")
        }
    }
}

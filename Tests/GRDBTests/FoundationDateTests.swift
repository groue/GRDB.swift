import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class FoundationDateTests : GRDBTestCase {
    
    private let UTCCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()
    
    private func assertYear(_ date: Date, _ value: Int, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(UTCCalendar.component(.year, from: date), value, file: file, line: line)
    }
    
    private func assertMonth(_ date: Date, _ value: Int, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(UTCCalendar.component(.month, from: date), value, file: file, line: line)
    }
    
    private func assertDay(_ date: Date, _ value: Int, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(UTCCalendar.component(.day, from: date), value, file: file, line: line)
    }
    
    private func assertHour(_ date: Date, _ value: Int, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(UTCCalendar.component(.hour, from: date), value, file: file, line: line)
    }
    
    private func assertMinute(_ date: Date, _ value: Int, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(UTCCalendar.component(.minute, from: date), value, file: file, line: line)
    }
    
    private func assertSecond(_ date: Date, _ value: Int, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(UTCCalendar.component(.second, from: date), value, file: file, line: line)
    }
    
    private func assertMilliseconds(_ date: Date, _ milliseconds: Int, file: StaticString = #file, line: UInt = #line) {
        #if os(Linux)
            // Word around https://bugs.swift.org/browse/SR-3158
            let seconds = date.timeIntervalSince1970
            let m = Int(round(1000 * (seconds - floor(seconds))))
        #else
            let nanoseconds = UTCCalendar.component(.nanosecond, from: date)
            let m = Int(round(Double(nanoseconds) / 1.0e6))
        #endif
        XCTAssertEqual(m, milliseconds, file: file, line: line)
    }
    
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

    func testDateSerialization() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let date = Date(timeIntervalSince1970: 117195072.1234)
            try db.execute("INSERT INTO dates (creationDate) VALUES (?)", arguments: [date])
            let string = try String.fetchOne(db, "SELECT creationDate FROM dates")!
            XCTAssertEqual(string, "1973-09-18 10:11:12.123")
        }
    }

    func testDateIsLexicallyComparableToCURRENT_TIMESTAMP() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(
                "INSERT INTO dates (id, creationDate) VALUES (?,?)",
                arguments: [1, Date().addingTimeInterval(-1)])
            
            try db.execute(
                "INSERT INTO dates (id) VALUES (?)",
                arguments: [2])
            
            try db.execute(
                "INSERT INTO dates (id, creationDate) VALUES (?,?)",
                arguments: [3, Date().addingTimeInterval(1)])
            
            let ids = try Int.fetchAll(db, "SELECT id FROM dates ORDER BY creationDate")
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
    
    func testDateAcceptsFormatYMD() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(
                "INSERT INTO dates (creationDate) VALUES (?)",
                arguments: ["2015-07-22"])
            let date = try Date.fetchOne(db, "SELECT creationDate from dates")!
            assertYear(date, 2015)
            assertMonth(date, 7)
            assertDay(date, 22)
            assertHour(date, 0)
            assertMinute(date, 0)
            assertSecond(date, 0)
            assertMilliseconds(date, 0)
        }
    }

    func testDateAcceptsFormatYMD_HM() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(
                "INSERT INTO dates (creationDate) VALUES (?)",
                arguments: ["2015-07-22 01:02"])
            let date = try Date.fetchOne(db, "SELECT creationDate from dates")!
            assertYear(date, 2015)
            assertMonth(date, 7)
            assertDay(date, 22)
            assertHour(date, 1)
            assertMinute(date, 2)
            assertSecond(date, 0)
            assertMilliseconds(date, 0)
        }
    }

    func testDateAcceptsFormatYMD_HMS() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(
                "INSERT INTO dates (creationDate) VALUES (?)",
                arguments: ["2015-07-22 01:02:03"])
            let date = try Date.fetchOne(db, "SELECT creationDate from dates")!
            assertYear(date, 2015)
            assertMonth(date, 7)
            assertDay(date, 22)
            assertHour(date, 1)
            assertMinute(date, 2)
            assertSecond(date, 3)
            assertMilliseconds(date, 0)
        }
    }

    func testDateAcceptsFormatYMD_HMSS() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(
                "INSERT INTO dates (creationDate) VALUES (?)",
                arguments: ["2015-07-22 01:02:03.004"])
            let date = try Date.fetchOne(db, "SELECT creationDate from dates")!
            assertYear(date, 2015)
            assertMonth(date, 7)
            assertDay(date, 22)
            assertHour(date, 1)
            assertMinute(date, 2)
            assertSecond(date, 3)
            assertMilliseconds(date, 4)
        }
    }

    func testDateAcceptsJulianDayNumber() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            // 00:30:00.0 UT January 1, 2013 according to https://en.wikipedia.org/wiki/Julian_day
            try db.execute(
                "INSERT INTO dates (creationDate) VALUES (?)",
                arguments: [2_456_293.520833])
            
            let string = try String.fetchOne(db, "SELECT datetime(creationDate) from dates")!
            XCTAssertEqual(string, "2013-01-01 00:29:59")
            
            let date = try Date.fetchOne(db, "SELECT creationDate from dates")!
            assertYear(date, 2013)
            assertMonth(date, 1)
            assertDay(date, 1)
            assertHour(date, 0)
            assertMinute(date, 29)
            assertSecond(date, 59)
        }
    }

    func testDateAcceptsFormatIso8601YMD_HM() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(
                "INSERT INTO dates (creationDate) VALUES (?)",
                arguments: ["2015-07-22T01:02"])
            let date = try Date.fetchOne(db, "SELECT creationDate from dates")!
            assertYear(date, 2015)
            assertMonth(date, 7)
            assertDay(date, 22)
            assertHour(date, 1)
            assertMinute(date, 2)
            assertSecond(date, 0)
            assertMilliseconds(date, 0)
        }
    }

    func testDateAcceptsFormatIso8601YMD_HMS() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(
                "INSERT INTO dates (creationDate) VALUES (?)",
                arguments: ["2015-07-22T01:02:03"])
            let date = try Date.fetchOne(db, "SELECT creationDate from dates")!
            assertYear(date, 2015)
            assertMonth(date, 7)
            assertDay(date, 22)
            assertHour(date, 1)
            assertMinute(date, 2)
            assertSecond(date, 3)
            assertMilliseconds(date, 0)
        }
    }

    func testDateAcceptsFormatIso8601YMD_HMSS() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(
                "INSERT INTO dates (creationDate) VALUES (?)",
                arguments: ["2015-07-22T01:02:03.004"])
            let date = try Date.fetchOne(db, "SELECT creationDate from dates")!
            assertYear(date, 2015)
            assertMonth(date, 7)
            assertDay(date, 22)
            assertHour(date, 1)
            assertMinute(date, 2)
            assertSecond(date, 3)
            assertMilliseconds(date, 4)
        }
    }
}

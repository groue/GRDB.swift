import XCTest
import GRDB

class FoundationDateComponentsTests : GRDBTestCase {
    
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
    
    func testDatabaseDateComponentsFormatHM() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            
            var dateComponents = DateComponents()
            dateComponents.year = 1973
            dateComponents.month = 9
            dateComponents.day = 18
            dateComponents.hour = 10
            dateComponents.minute = 11
            dateComponents.second = 12
            dateComponents.nanosecond = 123_456_789
            try db.execute(sql: "INSERT INTO dates (creationDate) VALUES (?)", arguments: [DatabaseDateComponents(dateComponents, format: .HM)])
            
            let string = try String.fetchOne(db, sql: "SELECT creationDate from dates")!
            XCTAssertEqual(string, "10:11")
            
            let databaseDateComponents = try DatabaseDateComponents.fetchOne(db, sql: "SELECT creationDate FROM dates")!
            XCTAssertEqual(databaseDateComponents.format, DatabaseDateComponents.Format.HM)
            XCTAssertTrue(databaseDateComponents.dateComponents.year == nil)
            XCTAssertTrue(databaseDateComponents.dateComponents.month == nil)
            XCTAssertTrue(databaseDateComponents.dateComponents.day == nil)
            XCTAssertEqual(databaseDateComponents.dateComponents.hour, dateComponents.hour)
            XCTAssertEqual(databaseDateComponents.dateComponents.minute, dateComponents.minute)
            XCTAssertTrue(databaseDateComponents.dateComponents.second == nil)
            XCTAssertTrue(databaseDateComponents.dateComponents.nanosecond == nil)
        }
    }

    func testDatabaseDateComponentsFormatHMS() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            
            var dateComponents = DateComponents()
            dateComponents.year = 1973
            dateComponents.month = 9
            dateComponents.day = 18
            dateComponents.hour = 10
            dateComponents.minute = 11
            dateComponents.second = 12
            dateComponents.nanosecond = 123_456_789
            try db.execute(sql: "INSERT INTO dates (creationDate) VALUES (?)", arguments: [DatabaseDateComponents(dateComponents, format: .HMS)])
            
            let string = try String.fetchOne(db, sql: "SELECT creationDate from dates")!
            XCTAssertEqual(string, "10:11:12")
            
            let databaseDateComponents = try DatabaseDateComponents.fetchOne(db, sql: "SELECT creationDate FROM dates")!
            XCTAssertEqual(databaseDateComponents.format, DatabaseDateComponents.Format.HMS)
            XCTAssertTrue(databaseDateComponents.dateComponents.year == nil)
            XCTAssertTrue(databaseDateComponents.dateComponents.month == nil)
            XCTAssertTrue(databaseDateComponents.dateComponents.day == nil)
            XCTAssertEqual(databaseDateComponents.dateComponents.hour, dateComponents.hour)
            XCTAssertEqual(databaseDateComponents.dateComponents.minute, dateComponents.minute)
            XCTAssertEqual(databaseDateComponents.dateComponents.second, dateComponents.second)
            XCTAssertTrue(databaseDateComponents.dateComponents.nanosecond == nil)
        }
    }

    func testDatabaseDateComponentsFormatHMSS() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            
            var dateComponents = DateComponents()
            dateComponents.year = 1973
            dateComponents.month = 9
            dateComponents.day = 18
            dateComponents.hour = 10
            dateComponents.minute = 11
            dateComponents.second = 12
            dateComponents.nanosecond = 123_456_789
            try db.execute(sql: "INSERT INTO dates (creationDate) VALUES (?)", arguments: [DatabaseDateComponents(dateComponents, format: .HMSS)])
            
            let string = try String.fetchOne(db, sql: "SELECT creationDate from dates")!
            XCTAssertEqual(string, "10:11:12.123")
            
            let databaseDateComponents = try DatabaseDateComponents.fetchOne(db, sql: "SELECT creationDate FROM dates")!
            XCTAssertEqual(databaseDateComponents.format, DatabaseDateComponents.Format.HMSS)
            XCTAssertTrue(databaseDateComponents.dateComponents.year == nil)
            XCTAssertTrue(databaseDateComponents.dateComponents.month == nil)
            XCTAssertTrue(databaseDateComponents.dateComponents.day == nil)
            XCTAssertEqual(databaseDateComponents.dateComponents.hour, dateComponents.hour)
            XCTAssertEqual(databaseDateComponents.dateComponents.minute, dateComponents.minute)
            XCTAssertEqual(databaseDateComponents.dateComponents.second, dateComponents.second)
            XCTAssertEqual(round(Double(databaseDateComponents.dateComponents.nanosecond!) / 1.0e6), round(Double(dateComponents.nanosecond!) / 1.0e6))
        }
    }

    func testDatabaseDateComponentsFormatYMD() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            
            var dateComponents = DateComponents()
            dateComponents.year = 1973
            dateComponents.month = 9
            dateComponents.day = 18
            dateComponents.hour = 10
            dateComponents.minute = 11
            dateComponents.second = 12
            dateComponents.nanosecond = 123_456_789
            try db.execute(sql: "INSERT INTO dates (creationDate) VALUES (?)", arguments: [DatabaseDateComponents(dateComponents, format: .YMD)])
            
            let string = try String.fetchOne(db, sql: "SELECT creationDate from dates")!
            XCTAssertEqual(string, "1973-09-18")
            
            let databaseDateComponents = try DatabaseDateComponents.fetchOne(db, sql: "SELECT creationDate FROM dates")!
            XCTAssertEqual(databaseDateComponents.format, DatabaseDateComponents.Format.YMD)
            XCTAssertEqual(databaseDateComponents.dateComponents.year, dateComponents.year)
            XCTAssertEqual(databaseDateComponents.dateComponents.month, dateComponents.month)
            XCTAssertEqual(databaseDateComponents.dateComponents.day, dateComponents.day)
            XCTAssertTrue(databaseDateComponents.dateComponents.hour == nil)
            XCTAssertTrue(databaseDateComponents.dateComponents.minute == nil)
            XCTAssertTrue(databaseDateComponents.dateComponents.second == nil)
            XCTAssertTrue(databaseDateComponents.dateComponents.nanosecond == nil)
        }
    }

    func testDatabaseDateComponentsFormatYMD_HM() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            
            var dateComponents = DateComponents()
            dateComponents.year = 1973
            dateComponents.month = 9
            dateComponents.day = 18
            dateComponents.hour = 10
            dateComponents.minute = 11
            dateComponents.second = 12
            dateComponents.nanosecond = 123_456_789
            try db.execute(sql: "INSERT INTO dates (creationDate) VALUES (?)", arguments: [DatabaseDateComponents(dateComponents, format: .YMD_HM)])
            
            let string = try String.fetchOne(db, sql: "SELECT creationDate from dates")!
            XCTAssertEqual(string, "1973-09-18 10:11")
            
            let databaseDateComponents = try DatabaseDateComponents.fetchOne(db, sql: "SELECT creationDate FROM dates")!
            XCTAssertEqual(databaseDateComponents.format, DatabaseDateComponents.Format.YMD_HM)
            XCTAssertEqual(databaseDateComponents.dateComponents.year, dateComponents.year)
            XCTAssertEqual(databaseDateComponents.dateComponents.month, dateComponents.month)
            XCTAssertEqual(databaseDateComponents.dateComponents.day, dateComponents.day)
            XCTAssertEqual(databaseDateComponents.dateComponents.hour, dateComponents.hour)
            XCTAssertEqual(databaseDateComponents.dateComponents.minute, dateComponents.minute)
            XCTAssertTrue(databaseDateComponents.dateComponents.second == nil)
            XCTAssertTrue(databaseDateComponents.dateComponents.nanosecond == nil)
        }
    }

    func testDatabaseDateComponentsFormatYMD_HMS() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            
            var dateComponents = DateComponents()
            dateComponents.year = 1973
            dateComponents.month = 9
            dateComponents.day = 18
            dateComponents.hour = 10
            dateComponents.minute = 11
            dateComponents.second = 12
            dateComponents.nanosecond = 123_456_789
            try db.execute(sql: "INSERT INTO dates (creationDate) VALUES (?)", arguments: [DatabaseDateComponents(dateComponents, format: .YMD_HMS)])
            
            let string = try String.fetchOne(db, sql: "SELECT creationDate from dates")!
            XCTAssertEqual(string, "1973-09-18 10:11:12")
            
            let databaseDateComponents = try DatabaseDateComponents.fetchOne(db, sql: "SELECT creationDate FROM dates")!
            XCTAssertEqual(databaseDateComponents.format, DatabaseDateComponents.Format.YMD_HMS)
            XCTAssertEqual(databaseDateComponents.dateComponents.year, dateComponents.year)
            XCTAssertEqual(databaseDateComponents.dateComponents.month, dateComponents.month)
            XCTAssertEqual(databaseDateComponents.dateComponents.day, dateComponents.day)
            XCTAssertEqual(databaseDateComponents.dateComponents.hour, dateComponents.hour)
            XCTAssertEqual(databaseDateComponents.dateComponents.minute, dateComponents.minute)
            XCTAssertEqual(databaseDateComponents.dateComponents.second, dateComponents.second)
            XCTAssertTrue(databaseDateComponents.dateComponents.nanosecond == nil)
        }
    }

    func testDatabaseDateComponentsFormatYMD_HMSS() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            
            var dateComponents = DateComponents()
            dateComponents.year = 1973
            dateComponents.month = 9
            dateComponents.day = 18
            dateComponents.hour = 10
            dateComponents.minute = 11
            dateComponents.second = 12
            dateComponents.nanosecond = 123_456_789
            try db.execute(sql: "INSERT INTO dates (creationDate) VALUES (?)", arguments: [DatabaseDateComponents(dateComponents, format: .YMD_HMSS)])
            
            let string = try String.fetchOne(db, sql: "SELECT creationDate from dates")!
            XCTAssertEqual(string, "1973-09-18 10:11:12.123")
            
            let databaseDateComponents = try DatabaseDateComponents.fetchOne(db, sql: "SELECT creationDate FROM dates")!
            XCTAssertEqual(databaseDateComponents.format, DatabaseDateComponents.Format.YMD_HMSS)
            XCTAssertEqual(databaseDateComponents.dateComponents.year, dateComponents.year)
            XCTAssertEqual(databaseDateComponents.dateComponents.month, dateComponents.month)
            XCTAssertEqual(databaseDateComponents.dateComponents.day, dateComponents.day)
            XCTAssertEqual(databaseDateComponents.dateComponents.hour, dateComponents.hour)
            XCTAssertEqual(databaseDateComponents.dateComponents.minute, dateComponents.minute)
            XCTAssertEqual(databaseDateComponents.dateComponents.second, dateComponents.second)
            XCTAssertEqual(round(Double(databaseDateComponents.dateComponents.nanosecond!) / 1.0e6), round(Double(dateComponents.nanosecond!) / 1.0e6))
        }
    }

    func testUndefinedDatabaseDateComponentsFormatYMD_HMSS() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            
            let dateComponents = DateComponents()
            try db.execute(sql: "INSERT INTO dates (creationDate) VALUES (?)", arguments: [DatabaseDateComponents(dateComponents, format: .YMD_HMSS)])
            
            let string = try String.fetchOne(db, sql: "SELECT creationDate from dates")!
            XCTAssertEqual(string, "0000-01-01 00:00:00.000")
            
            let databaseDateComponents = try DatabaseDateComponents.fetchOne(db, sql: "SELECT creationDate FROM dates")!
            XCTAssertEqual(databaseDateComponents.format, DatabaseDateComponents.Format.YMD_HMSS)
            XCTAssertEqual(databaseDateComponents.dateComponents.year, 0)
            XCTAssertEqual(databaseDateComponents.dateComponents.month, 1)
            XCTAssertEqual(databaseDateComponents.dateComponents.day, 1)
            XCTAssertEqual(databaseDateComponents.dateComponents.hour, 0)
            XCTAssertEqual(databaseDateComponents.dateComponents.minute, 0)
            XCTAssertEqual(databaseDateComponents.dateComponents.second, 0)
            XCTAssertEqual(databaseDateComponents.dateComponents.nanosecond, 0)
        }
    }

    func testDatabaseDateComponentsFormatIso8601YMD_HM() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            
            var dateComponents = DateComponents()
            dateComponents.year = 1973
            dateComponents.month = 9
            dateComponents.day = 18
            dateComponents.hour = 10
            dateComponents.minute = 11
            dateComponents.second = 12
            dateComponents.nanosecond = 123_456_789
            try db.execute(sql: "INSERT INTO dates (creationDate) VALUES (?)", arguments: ["1973-09-18T10:11"])
            
            let databaseDateComponents = try DatabaseDateComponents.fetchOne(db, sql: "SELECT creationDate FROM dates")!
            XCTAssertEqual(databaseDateComponents.format, DatabaseDateComponents.Format.YMD_HM)
            XCTAssertEqual(databaseDateComponents.dateComponents.year, dateComponents.year)
            XCTAssertEqual(databaseDateComponents.dateComponents.month, dateComponents.month)
            XCTAssertEqual(databaseDateComponents.dateComponents.day, dateComponents.day)
            XCTAssertEqual(databaseDateComponents.dateComponents.hour, dateComponents.hour)
            XCTAssertEqual(databaseDateComponents.dateComponents.minute, dateComponents.minute)
            XCTAssertTrue(databaseDateComponents.dateComponents.second == nil)
            XCTAssertTrue(databaseDateComponents.dateComponents.nanosecond == nil)
        }
    }

    func testDatabaseDateComponentsFormatIso8601YMD_HMS() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            
            var dateComponents = DateComponents()
            dateComponents.year = 1973
            dateComponents.month = 9
            dateComponents.day = 18
            dateComponents.hour = 10
            dateComponents.minute = 11
            dateComponents.second = 12
            dateComponents.nanosecond = 123_456_789
            try db.execute(sql: "INSERT INTO dates (creationDate) VALUES (?)", arguments: ["1973-09-18T10:11:12"])
            
            let databaseDateComponents = try DatabaseDateComponents.fetchOne(db, sql: "SELECT creationDate FROM dates")!
            XCTAssertEqual(databaseDateComponents.format, DatabaseDateComponents.Format.YMD_HMS)
            XCTAssertEqual(databaseDateComponents.dateComponents.year, dateComponents.year)
            XCTAssertEqual(databaseDateComponents.dateComponents.month, dateComponents.month)
            XCTAssertEqual(databaseDateComponents.dateComponents.day, dateComponents.day)
            XCTAssertEqual(databaseDateComponents.dateComponents.hour, dateComponents.hour)
            XCTAssertEqual(databaseDateComponents.dateComponents.minute, dateComponents.minute)
            XCTAssertEqual(databaseDateComponents.dateComponents.second, dateComponents.second)
            XCTAssertTrue(databaseDateComponents.dateComponents.nanosecond == nil)
        }
    }

    func testDatabaseDateComponentsFormatIso8601YMD_HMSS() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            
            var dateComponents = DateComponents()
            dateComponents.year = 1973
            dateComponents.month = 9
            dateComponents.day = 18
            dateComponents.hour = 10
            dateComponents.minute = 11
            dateComponents.second = 12
            dateComponents.nanosecond = 123_456_789
            try db.execute(sql: "INSERT INTO dates (creationDate) VALUES (?)", arguments: ["1973-09-18T10:11:12.123"])
            
            let databaseDateComponents = try DatabaseDateComponents.fetchOne(db, sql: "SELECT creationDate FROM dates")!
            XCTAssertEqual(databaseDateComponents.format, DatabaseDateComponents.Format.YMD_HMSS)
            XCTAssertEqual(databaseDateComponents.dateComponents.year, dateComponents.year)
            XCTAssertEqual(databaseDateComponents.dateComponents.month, dateComponents.month)
            XCTAssertEqual(databaseDateComponents.dateComponents.day, dateComponents.day)
            XCTAssertEqual(databaseDateComponents.dateComponents.hour, dateComponents.hour)
            XCTAssertEqual(databaseDateComponents.dateComponents.minute, dateComponents.minute)
            XCTAssertEqual(databaseDateComponents.dateComponents.second, dateComponents.second)
            XCTAssertEqual(round(Double(databaseDateComponents.dateComponents.nanosecond!) / 1.0e6), round(Double(dateComponents.nanosecond!) / 1.0e6))
        }
    }

    func testFormatYMD_HMSIsLexicallyComparableToCURRENT_TIMESTAMP() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            do {
                let date = Date().addingTimeInterval(-1)
                let dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
                try db.execute(
                    sql: "INSERT INTO dates (id, creationDate) VALUES (?,?)",
                    arguments: [1, DatabaseDateComponents(dateComponents, format: .YMD_HMS)])
            }
            do {
                try db.execute(
                    sql: "INSERT INTO dates (id) VALUES (?)",
                    arguments: [2])
            }
            do {
                let date = Date().addingTimeInterval(1)
                let dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
                try db.execute(
                    sql: "INSERT INTO dates (id, creationDate) VALUES (?,?)",
                    arguments: [3, DatabaseDateComponents(dateComponents, format: .YMD_HMS)])
            }
            
            let ids = try Int.fetchAll(db, sql: "SELECT id FROM dates ORDER BY creationDate")
            XCTAssertEqual(ids, [1,2,3])
        }
    }

    func testDatabaseDateComponentsParsing() {
        func assertParse(_ string: String, _ dateComponent: DatabaseDateComponents, file: StaticString = #filePath, line: UInt = #line) {
            do {
                // Test DatabaseValueConvertible adoption
                guard let parsed = DatabaseDateComponents.fromDatabaseValue(string.databaseValue) else {
                    XCTFail("Could not parse \(String(reflecting: string))", file: file, line: line)
                    return
                }
                XCTAssertEqual(parsed.format, dateComponent.format, file: file, line: line)
                XCTAssertEqual(parsed.dateComponents, dateComponent.dateComponents, file: file, line: line)
            }
            do {
                // Test StatementColumnConvertible adoption
                guard let parsed = try? DatabaseQueue().inDatabase({
                    try DatabaseDateComponents.fetchOne($0, sql: "SELECT ?", arguments: [string])
                }) else {
                    XCTFail("Could not parse \(String(reflecting: string))", file: file, line: line)
                    return
                }
                XCTAssertEqual(parsed.format, dateComponent.format, file: file, line: line)
                XCTAssertEqual(parsed.dateComponents, dateComponent.dateComponents, file: file, line: line)
            }
        }
        
        assertParse(
            "0000-01-01",
            DatabaseDateComponents(
                DateComponents(year: 0, month: 1, day: 1, hour: nil, minute: nil, second: nil, nanosecond: nil),
                format: .YMD))
        assertParse(
            "2018-12-31",
            DatabaseDateComponents(
                DateComponents(year: 2018, month: 12, day: 31, hour: nil, minute: nil, second: nil, nanosecond: nil),
                format: .YMD))
        assertParse(
            "2018-04-21 00:00",
            DatabaseDateComponents(
                DateComponents(year: 2018, month: 04, day: 21, hour: 0, minute: 0, second: nil, nanosecond: nil),
                format: .YMD_HM))
        assertParse(
            "2018-04-21 00:00Z",
            DatabaseDateComponents(
                DateComponents(
                    timeZone: TimeZone(secondsFromGMT: 0),
                    year: 2018, month: 04, day: 21, hour: 0, minute: 0, second: nil, nanosecond: nil),
                format: .YMD_HM))
        assertParse(
            "2018-04-21 00:00+00:00",
            DatabaseDateComponents(
                DateComponents(
                    timeZone: TimeZone(secondsFromGMT: 0),
                    year: 2018, month: 04, day: 21, hour: 0, minute: 0, second: nil, nanosecond: nil),
                format: .YMD_HM))
        assertParse(
            "2018-04-21 00:00-00:00",
            DatabaseDateComponents(
                DateComponents(
                    timeZone: TimeZone(secondsFromGMT: 0),
                    year: 2018, month: 04, day: 21, hour: 0, minute: 0, second: nil, nanosecond: nil),
                format: .YMD_HM))
        assertParse(
            "2018-04-21 00:00+01:15",
            DatabaseDateComponents(
                DateComponents(
                    timeZone: TimeZone(secondsFromGMT: 4500),
                    year: 2018, month: 04, day: 21, hour: 0, minute: 0, second: nil, nanosecond: nil),
                format: .YMD_HM))
        assertParse(
            "2018-04-21 00:00-01:15",
            DatabaseDateComponents(
                DateComponents(
                    timeZone: TimeZone(secondsFromGMT: -4500),
                    year: 2018, month: 04, day: 21, hour: 0, minute: 0, second: nil, nanosecond: nil),
                format: .YMD_HM))
        assertParse(
            "2018-04-21T23:59",
            DatabaseDateComponents(
                DateComponents(year: 2018, month: 04, day: 21, hour: 23, minute: 59, second: nil, nanosecond: nil),
                format: .YMD_HM))
        assertParse(
            "2018-04-21 00:00:00",
            DatabaseDateComponents(
                DateComponents(year: 2018, month: 04, day: 21, hour: 0, minute: 0, second: 0, nanosecond: nil),
                format: .YMD_HMS))
        assertParse(
            "2018-04-21T23:59:59",
            DatabaseDateComponents(
                DateComponents(year: 2018, month: 04, day: 21, hour: 23, minute: 59, second: 59, nanosecond: nil),
                format: .YMD_HMS))
        assertParse(
            "2018-04-21 00:00:00.0",
            DatabaseDateComponents(
                DateComponents(year: 2018, month: 04, day: 21, hour: 0, minute: 0, second: 0, nanosecond: 0),
                format: .YMD_HMSS))
        assertParse(
            "2018-04-21T23:59:59.9",
            DatabaseDateComponents(
                DateComponents(year: 2018, month: 04, day: 21, hour: 23, minute: 59, second: 59, nanosecond: 900_000_000),
                format: .YMD_HMSS))
        assertParse(
            "2018-04-21T23:59:59.9Z",
            DatabaseDateComponents(
                DateComponents(
                    timeZone: TimeZone(secondsFromGMT: 0),
                    year: 2018, month: 04, day: 21, hour: 23, minute: 59, second: 59, nanosecond: 900_000_000),
                format: .YMD_HMSS))
        assertParse(
            "2018-04-21 00:00:00.00",
            DatabaseDateComponents(
                DateComponents(year: 2018, month: 04, day: 21, hour: 0, minute: 0, second: 0, nanosecond: 0),
                format: .YMD_HMSS))
        assertParse(
            "2018-04-21 00:00:00.01",
            DatabaseDateComponents(
                DateComponents(year: 2018, month: 04, day: 21, hour: 0, minute: 0, second: 0, nanosecond: 10_000_000),
                format: .YMD_HMSS))
        assertParse(
            "2018-04-21T23:59:59.99",
            DatabaseDateComponents(
                DateComponents(year: 2018, month: 04, day: 21, hour: 23, minute: 59, second: 59, nanosecond: 990_000_000),
                format: .YMD_HMSS))
        assertParse(
            "2018-04-21T23:59:59.99Z",
            DatabaseDateComponents(
                DateComponents(
                    timeZone: TimeZone(secondsFromGMT: 0),
                    year: 2018, month: 04, day: 21, hour: 23, minute: 59, second: 59, nanosecond: 990_000_000),
                format: .YMD_HMSS))
        assertParse(
            "2018-04-21 00:00:00.000",
            DatabaseDateComponents(
                DateComponents(year: 2018, month: 04, day: 21, hour: 0, minute: 0, second: 0, nanosecond: 0),
                format: .YMD_HMSS))
        assertParse(
            "2018-04-21 00:00:00.001",
            DatabaseDateComponents(
                DateComponents(year: 2018, month: 04, day: 21, hour: 0, minute: 0, second: 0, nanosecond: 1_000_000),
                format: .YMD_HMSS))
        assertParse(
            "2018-04-21T23:59:59.999",
            DatabaseDateComponents(
                DateComponents(year: 2018, month: 04, day: 21, hour: 23, minute: 59, second: 59, nanosecond: 999_000_000),
                format: .YMD_HMSS))
        assertParse(
            "2018-04-21T23:59:59.999Z",
            DatabaseDateComponents(
                DateComponents(
                    timeZone: TimeZone(secondsFromGMT: 0),
                    year: 2018, month: 04, day: 21, hour: 23, minute: 59, second: 59, nanosecond: 999_000_000),
                format: .YMD_HMSS))
        assertParse(
            "2018-04-21T23:59:59.999+00:00",
            DatabaseDateComponents(
                DateComponents(
                    timeZone: TimeZone(secondsFromGMT: 0),
                    year: 2018, month: 04, day: 21, hour: 23, minute: 59, second: 59, nanosecond: 999_000_000),
                format: .YMD_HMSS))
        assertParse(
            "2018-04-21T23:59:59.999-00:00",
            DatabaseDateComponents(
                DateComponents(
                    timeZone: TimeZone(secondsFromGMT: 0),
                    year: 2018, month: 04, day: 21, hour: 23, minute: 59, second: 59, nanosecond: 999_000_000),
                format: .YMD_HMSS))
        assertParse(
            "2018-04-21T23:59:59.999+01:15",
            DatabaseDateComponents(
                DateComponents(
                    timeZone: TimeZone(secondsFromGMT: 4500),
                    year: 2018, month: 04, day: 21, hour: 23, minute: 59, second: 59, nanosecond: 999_000_000),
                format: .YMD_HMSS))
        assertParse(
            "2018-04-21T23:59:59.999-01:15",
            DatabaseDateComponents(
                DateComponents(
                    timeZone: TimeZone(secondsFromGMT: -4500),
                    year: 2018, month: 04, day: 21, hour: 23, minute: 59, second: 59, nanosecond: 999_000_000),
                format: .YMD_HMSS))
        assertParse(
            "2018-04-21T23:59:59.999123",
            DatabaseDateComponents(
                DateComponents(year: 2018, month: 04, day: 21, hour: 23, minute: 59, second: 59, nanosecond: 999_000_000),
                format: .YMD_HMSS))
        assertParse(
            "2018-04-21T23:59:59.999123Z",
            DatabaseDateComponents(
                DateComponents(
                    timeZone: TimeZone(secondsFromGMT: 0),
                    year: 2018, month: 04, day: 21, hour: 23, minute: 59, second: 59, nanosecond: 999_000_000),
                format: .YMD_HMSS))
        assertParse(
            "00:00",
            DatabaseDateComponents(
                DateComponents(year: nil, month: nil, day: nil, hour: 0, minute: 0, second: nil, nanosecond: nil),
                format: .HM))
        assertParse(
            "23:59",
            DatabaseDateComponents(
                DateComponents(year: nil, month: nil, day: nil, hour: 23, minute: 59, second: nil, nanosecond: nil),
                format: .HM))
        assertParse(
            "23:59Z",
            DatabaseDateComponents(
                DateComponents(
                    timeZone: TimeZone(secondsFromGMT: 0),
                    year: nil, month: nil, day: nil, hour: 23, minute: 59, second: nil, nanosecond: nil),
                format: .HM))
        assertParse(
            "23:59+00:00",
            DatabaseDateComponents(
                DateComponents(
                    timeZone: TimeZone(secondsFromGMT: 0),
                    year: nil, month: nil, day: nil, hour: 23, minute: 59, second: nil, nanosecond: nil),
                format: .HM))
        assertParse(
            "23:59-00:00",
            DatabaseDateComponents(
                DateComponents(
                    timeZone: TimeZone(secondsFromGMT: 0),
                    year: nil, month: nil, day: nil, hour: 23, minute: 59, second: nil, nanosecond: nil),
                format: .HM))
        assertParse(
            "23:59+01:15",
            DatabaseDateComponents(
                DateComponents(
                    timeZone: TimeZone(secondsFromGMT: 4500),
                    year: nil, month: nil, day: nil, hour: 23, minute: 59, second: nil, nanosecond: nil),
                format: .HM))
        assertParse(
            "23:59-01:15",
            DatabaseDateComponents(
                DateComponents(
                    timeZone: TimeZone(secondsFromGMT: -4500),
                    year: nil, month: nil, day: nil, hour: 23, minute: 59, second: nil, nanosecond: nil),
                format: .HM))
        assertParse(
            "00:00:00",
            DatabaseDateComponents(
                DateComponents(year: nil, month: nil, day: nil, hour: 0, minute: 0, second: 0, nanosecond: nil),
                format: .HMS))
        assertParse(
            "23:59:59",
            DatabaseDateComponents(
                DateComponents(year: nil, month: nil, day: nil, hour: 23, minute: 59, second: 59, nanosecond: nil),
                format: .HMS))
        assertParse(
            "00:00:00.0",
            DatabaseDateComponents(
                DateComponents(year: nil, month: nil, day: nil, hour: 0, minute: 0, second: 0, nanosecond: 0),
                format: .HMSS))
        assertParse(
            "23:59:59.9",
            DatabaseDateComponents(
                DateComponents(year: nil, month: nil, day: nil, hour: 23, minute: 59, second: 59, nanosecond: 900_000_000),
                format: .HMSS))
        assertParse(
            "23:59:59.9Z",
            DatabaseDateComponents(
                DateComponents(
                    timeZone: TimeZone(secondsFromGMT: 0),
                    year: nil, month: nil, day: nil, hour: 23, minute: 59, second: 59, nanosecond: 900_000_000),
                format: .HMSS))
        assertParse(
            "00:00:00.00",
            DatabaseDateComponents(
                DateComponents(year: nil, month: nil, day: nil, hour: 0, minute: 0, second: 0, nanosecond: 0),
                format: .HMSS))
        assertParse(
            "00:00:00.01",
            DatabaseDateComponents(
                DateComponents(year: nil, month: nil, day: nil, hour: 0, minute: 0, second: 0, nanosecond: 10_000_000),
                format: .HMSS))
        assertParse(
            "23:59:59.99",
            DatabaseDateComponents(
                DateComponents(year: nil, month: nil, day: nil, hour: 23, minute: 59, second: 59, nanosecond: 990_000_000),
                format: .HMSS))
        assertParse(
            "23:59:59.99Z",
            DatabaseDateComponents(
                DateComponents(
                    timeZone: TimeZone(secondsFromGMT: 0),
                    year: nil, month: nil, day: nil, hour: 23, minute: 59, second: 59, nanosecond: 990_000_000),
                format: .HMSS))
        assertParse(
            "00:00:00.000",
            DatabaseDateComponents(
                DateComponents(year: nil, month: nil, day: nil, hour: 0, minute: 0, second: 0, nanosecond: 0),
                format: .HMSS))
        assertParse(
            "00:00:00.001",
            DatabaseDateComponents(
                DateComponents(year: nil, month: nil, day: nil, hour: 0, minute: 0, second: 0, nanosecond: 1_000_000),
                format: .HMSS))
        assertParse(
            "23:59:59.999",
            DatabaseDateComponents(
                DateComponents(year: nil, month: nil, day: nil, hour: 23, minute: 59, second: 59, nanosecond: 999_000_000),
                format: .HMSS))
        assertParse(
            "23:59:59.999Z",
            DatabaseDateComponents(
                DateComponents(
                    timeZone: TimeZone(secondsFromGMT: 0),
                    year: nil, month: nil, day: nil, hour: 23, minute: 59, second: 59, nanosecond: 999_000_000),
                format: .HMSS))
        assertParse(
            "23:59:59.999+00:00",
            DatabaseDateComponents(
                DateComponents(
                    timeZone: TimeZone(secondsFromGMT: 0),
                    year: nil, month: nil, day: nil, hour: 23, minute: 59, second: 59, nanosecond: 999_000_000),
                format: .HMSS))
        assertParse(
            "23:59:59.999-00:00",
            DatabaseDateComponents(
                DateComponents(
                    timeZone: TimeZone(secondsFromGMT: 0),
                    year: nil, month: nil, day: nil, hour: 23, minute: 59, second: 59, nanosecond: 999_000_000),
                format: .HMSS))
        assertParse(
            "23:59:59.999+01:15",
            DatabaseDateComponents(
                DateComponents(
                    timeZone: TimeZone(secondsFromGMT: 4500),
                    year: nil, month: nil, day: nil, hour: 23, minute: 59, second: 59, nanosecond: 999_000_000),
                format: .HMSS))
        assertParse(
            "23:59:59.999-01:15",
            DatabaseDateComponents(
                DateComponents(
                    timeZone: TimeZone(secondsFromGMT: -4500),
                    year: nil, month: nil, day: nil, hour: 23, minute: 59, second: 59, nanosecond: 999_000_000),
                format: .HMSS))
        assertParse(
            "23:59:59.999123",
            DatabaseDateComponents(
                DateComponents(year: nil, month: nil, day: nil, hour: 23, minute: 59, second: 59, nanosecond: 999_000_000),
                format: .HMSS))
        assertParse(
            "23:59:59.999123Z",
            DatabaseDateComponents(
                DateComponents(
                    timeZone: TimeZone(secondsFromGMT: 0),
                    year: nil, month: nil, day: nil, hour: 23, minute: 59, second: 59, nanosecond: 999_000_000),
                format: .HMSS))
    }
    
    func testDatabaseDateComponentsFromUnparsableString() {
        let databaseDateComponents = DatabaseDateComponents.fromDatabaseValue("foo".databaseValue)
        XCTAssertTrue(databaseDateComponents == nil)
    }

    func testJSONEncodingOfDatabaseDateComponents() throws {
        // Encoding root string is not supported by all system version: use an object
        struct Record: Encodable {
            var date: DatabaseDateComponents
        }
        let record = Record(date: DatabaseDateComponents(DateComponents(year: 2018, month: 12, day: 31), format: .YMD))
        let jsonData = try JSONEncoder().encode(record)
        let json = String(data: jsonData, encoding: .utf8)!
        XCTAssertEqual(json, """
            {"date":"2018-12-31"}
            """)
    }

    func testJSONDecodingOfDatabaseDateComponents() throws {
        // Decoding root string is not supported by all system version: use an object
        struct Record: Decodable {
            var date: DatabaseDateComponents
        }
        let json = """
            {"date":"2018-12-31"}
            """
        let record = try JSONDecoder().decode(Record.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(record.date.format, .YMD)
        XCTAssertEqual(record.date.dateComponents, DateComponents(year: 2018, month: 12, day: 31))
    }
}

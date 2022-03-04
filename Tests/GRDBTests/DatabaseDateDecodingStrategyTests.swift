import Foundation
import XCTest
import GRDB

private protocol StrategyProvider {
    static var strategy: DatabaseDateDecodingStrategy { get }
}

private enum StrategyDeferredToDate: StrategyProvider {
    static let strategy: DatabaseDateDecodingStrategy = .deferredToDate
}

private enum StrategyTimeIntervalSinceReferenceDate: StrategyProvider {
    static let strategy: DatabaseDateDecodingStrategy = .timeIntervalSinceReferenceDate
}

private enum StrategyTimeIntervalSince1970: StrategyProvider {
    static let strategy: DatabaseDateDecodingStrategy = .timeIntervalSince1970
}

private enum StrategyMillisecondsSince1970: StrategyProvider {
    static let strategy: DatabaseDateDecodingStrategy = .millisecondsSince1970
}

@available(macOS 10.12, watchOS 3.0, tvOS 10.0, *)
private enum StrategyIso8601: StrategyProvider {
    static let strategy: DatabaseDateDecodingStrategy = .iso8601
}

private enum StrategyFormatted: StrategyProvider {
    static let strategy: DatabaseDateDecodingStrategy = .formatted({
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)!
        formatter.dateStyle = .full
        formatter.timeStyle = .full
        return formatter
        }())
}

private enum StrategyCustom: StrategyProvider {
    static let strategy: DatabaseDateDecodingStrategy = .custom { dbValue in
        if dbValue == "invalid".databaseValue {
            return nil
        }
        return Date(timeIntervalSinceReferenceDate: 123456)
    }
}

private struct RecordWithDate<Strategy: StrategyProvider>: FetchableRecord, Decodable {
    static var databaseDateDecodingStrategy: DatabaseDateDecodingStrategy { Strategy.strategy }
    var date: Date
}

private struct RecordWithOptionalDate<Strategy: StrategyProvider>: FetchableRecord, Decodable {
    static var databaseDateDecodingStrategy: DatabaseDateDecodingStrategy { Strategy.strategy }
    var date: Date?
}

class DatabaseDateDecodingStrategyTests: GRDBTestCase {
    /// test the conversion from a database value to a date extracted from a record
    private func test<T: FetchableRecord>(
        _ db: Database,
        record: T.Type,
        date: (T) -> Date?,
        databaseValue: DatabaseValueConvertible?,
        with test: (Date?) -> Void) throws
    {
        let request = SQLRequest<Void>(sql: "SELECT ? AS date", arguments: [databaseValue])
        do {
            // test decoding straight from SQLite
            let record = try T.fetchOne(db, request)!
            test(date(record))
        }
        do {
            // test decoding from copied row
            let record = try T(row: Row.fetchOne(db, request)!)
            test(date(record))
        }
    }
    
    /// test the conversion from a database value to a date with a given strategy
    private func test<Strategy: StrategyProvider>(_ db: Database, strategy: Strategy.Type, databaseValue: DatabaseValueConvertible, _ test: (Date) -> Void) throws {
        try self.test(db, record: RecordWithDate<Strategy>.self, date: { $0.date }, databaseValue: databaseValue, with: { test($0!) })
        try self.test(db, record: RecordWithOptionalDate<Strategy>.self, date: { $0.date }, databaseValue: databaseValue, with: { test($0!) })
    }
    
    private func testNullDecoding<Strategy: StrategyProvider>(_ db: Database, strategy: Strategy.Type) throws {
        try self.test(db, record: RecordWithOptionalDate<Strategy>.self, date: { $0.date }, databaseValue: nil) { date in
            XCTAssertNil(date)
        }
    }
}

// MARK: - deferredToDate

extension DatabaseDateDecodingStrategyTests {
    func testDeferredToDate() throws {
        try makeDatabaseQueue().read { db in
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            
            // Null
            try testNullDecoding(db, strategy: StrategyDeferredToDate.self)
            
            // YMD
            try test(db, strategy: StrategyDeferredToDate.self, databaseValue: "2015-07-22") { date in
                XCTAssertEqual(calendar.component(.year, from: date), 2015)
                XCTAssertEqual(calendar.component(.month, from: date), 7)
                XCTAssertEqual(calendar.component(.day, from: date), 22)
                XCTAssertEqual(calendar.component(.hour, from: date), 0)
                XCTAssertEqual(calendar.component(.minute, from: date), 0)
                XCTAssertEqual(calendar.component(.second, from: date), 0)
                XCTAssertEqual(calendar.component(.nanosecond, from: date), 0)
            }
            
            // YMD_HM
            try test(db, strategy: StrategyDeferredToDate.self, databaseValue: "2015-07-22 01:02") { date in
                XCTAssertEqual(calendar.component(.year, from: date), 2015)
                XCTAssertEqual(calendar.component(.month, from: date), 7)
                XCTAssertEqual(calendar.component(.day, from: date), 22)
                XCTAssertEqual(calendar.component(.hour, from: date), 1)
                XCTAssertEqual(calendar.component(.minute, from: date), 2)
                XCTAssertEqual(calendar.component(.second, from: date), 0)
                XCTAssertEqual(calendar.component(.nanosecond, from: date), 0)
            }
            
            // YMD_HMS
            try test(db, strategy: StrategyDeferredToDate.self, databaseValue: "2015-07-22 01:02:03") { date in
                XCTAssertEqual(calendar.component(.year, from: date), 2015)
                XCTAssertEqual(calendar.component(.month, from: date), 7)
                XCTAssertEqual(calendar.component(.day, from: date), 22)
                XCTAssertEqual(calendar.component(.hour, from: date), 1)
                XCTAssertEqual(calendar.component(.minute, from: date), 2)
                XCTAssertEqual(calendar.component(.second, from: date), 3)
                XCTAssertEqual(calendar.component(.nanosecond, from: date), 0)
            }
            
            // YMD_HMSS
            try test(db, strategy: StrategyDeferredToDate.self, databaseValue: "2015-07-22 01:02:03.00456") { date in
                XCTAssertEqual(calendar.component(.year, from: date), 2015)
                XCTAssertEqual(calendar.component(.month, from: date), 7)
                XCTAssertEqual(calendar.component(.day, from: date), 22)
                XCTAssertEqual(calendar.component(.hour, from: date), 1)
                XCTAssertEqual(calendar.component(.minute, from: date), 2)
                XCTAssertEqual(calendar.component(.second, from: date), 3)
                XCTAssertTrue(abs(calendar.component(.nanosecond, from: date) - 4_000_000) < 10)  // We actually get 4_000_008. Some precision is lost during the DateComponents -> Date conversion. Not a big deal.
            }
            
            // Timestamp
            try test(db, strategy: StrategyDeferredToDate.self, databaseValue: 1437526920) { date in
                XCTAssertEqual(calendar.component(.year, from: date), 2015)
                XCTAssertEqual(calendar.component(.month, from: date), 7)
                XCTAssertEqual(calendar.component(.day, from: date), 22)
                XCTAssertEqual(calendar.component(.hour, from: date), 1)
                XCTAssertEqual(calendar.component(.minute, from: date), 2)
                XCTAssertEqual(calendar.component(.second, from: date), 0)
                XCTAssertEqual(calendar.component(.nanosecond, from: date), 0)
            }
            
            // Iso8601YMD_HM
            try test(db, strategy: StrategyDeferredToDate.self, databaseValue: "2015-07-22T01:02") { date in
                XCTAssertEqual(calendar.component(.year, from: date), 2015)
                XCTAssertEqual(calendar.component(.month, from: date), 7)
                XCTAssertEqual(calendar.component(.day, from: date), 22)
                XCTAssertEqual(calendar.component(.hour, from: date), 1)
                XCTAssertEqual(calendar.component(.minute, from: date), 2)
                XCTAssertEqual(calendar.component(.second, from: date), 0)
                XCTAssertEqual(calendar.component(.nanosecond, from: date), 0)
            }
            
            // Iso8601YMD_HMS
            try test(db, strategy: StrategyDeferredToDate.self, databaseValue: "2015-07-22T01:02:03") { date in
                XCTAssertEqual(calendar.component(.year, from: date), 2015)
                XCTAssertEqual(calendar.component(.month, from: date), 7)
                XCTAssertEqual(calendar.component(.day, from: date), 22)
                XCTAssertEqual(calendar.component(.hour, from: date), 1)
                XCTAssertEqual(calendar.component(.minute, from: date), 2)
                XCTAssertEqual(calendar.component(.second, from: date), 3)
                XCTAssertEqual(calendar.component(.nanosecond, from: date), 0)
            }
            
            // Iso8601YMD_HMSS
            try test(db, strategy: StrategyDeferredToDate.self, databaseValue: "2015-07-22T01:02:03.00456") { date in
                XCTAssertEqual(calendar.component(.year, from: date), 2015)
                XCTAssertEqual(calendar.component(.month, from: date), 7)
                XCTAssertEqual(calendar.component(.day, from: date), 22)
                XCTAssertEqual(calendar.component(.hour, from: date), 1)
                XCTAssertEqual(calendar.component(.minute, from: date), 2)
                XCTAssertEqual(calendar.component(.second, from: date), 3)
                XCTAssertTrue(abs(calendar.component(.nanosecond, from: date) - 4_000_000) < 10)  // We actually get 4_000_008. Some precision is lost during the DateComponents -> Date conversion. Not a big deal.
            }
            
            // error
            do {
                try test(db, strategy: StrategyDeferredToDate.self, databaseValue: "Yesterday") { date in
                    XCTFail("Unexpected Date")
                }
            } catch let error as DatabaseDecodingError {
                switch error {
                case .valueMismatch:
                    XCTAssertEqual(error.description, """
                        could not decode Date from database value "Yesterday" - \
                        column: "date", \
                        column index: 0, \
                        row: [date:"Yesterday"], \
                        sql: `SELECT ? AS date`
                        """)
                    XCTAssertEqual(error.expandedDescription, """
                        could not decode Date from database value "Yesterday" - \
                        column: "date", \
                        column index: 0, \
                        row: [date:"Yesterday"], \
                        sql: `SELECT ? AS date`, \
                        arguments: ["Yesterday"]
                        """)
                default:
                    XCTFail("Unexpected Error")
                }
            }
        }
    }
}

// MARK: - timeIntervalSinceReferenceDate

extension DatabaseDateDecodingStrategyTests {
    func testTimeIntervalSinceReferenceDate() throws {
        try makeDatabaseQueue().read { db in
            // Null
            try testNullDecoding(db, strategy: StrategyTimeIntervalSinceReferenceDate.self)

            // 0
            try test(db, strategy: StrategyTimeIntervalSinceReferenceDate.self, databaseValue: 0) { date in
                XCTAssertEqual(date, Date(timeIntervalSinceReferenceDate: 0))
            }
            
            // 123.456
            try test(db, strategy: StrategyTimeIntervalSinceReferenceDate.self, databaseValue: 123.456) { date in
                XCTAssertEqual(date, Date(timeIntervalSinceReferenceDate: 123.456))
            }
            
            // error
            do {
                try test(db, strategy: StrategyTimeIntervalSinceReferenceDate.self, databaseValue: "Yesterday") { date in
                    // Decoding from SQLite statement works:
                    // "Yesterday" is decoded as 0.
                    XCTAssertEqual(date, Date(timeIntervalSinceReferenceDate: 0))
                }
            } catch let error as DatabaseDecodingError {
                // Decoding from DatabaseValue does not work:
                // "Yesterday" is not decoded as 0.
                switch error {
                case .valueMismatch:
                    XCTAssertEqual(error.description, """
                        could not decode Date from database value "Yesterday" - \
                        column: "date", \
                        column index: 0, \
                        row: [date:"Yesterday"]
                        """)
                default:
                    XCTFail("Unexpected Error")
                }
            }
        }
    }
}

// MARK: - timeIntervalSince1970

extension DatabaseDateDecodingStrategyTests {
    func testTimeIntervalSince1970() throws {
        try makeDatabaseQueue().read { db in
            // Null
            try testNullDecoding(db, strategy: StrategyTimeIntervalSince1970.self)

            // 0
            try test(db, strategy: StrategyTimeIntervalSince1970.self, databaseValue: 0) { date in
                XCTAssertEqual(date, Date(timeIntervalSince1970: 0))
            }
            
            // 123.456
            try test(db, strategy: StrategyTimeIntervalSince1970.self, databaseValue: 123.456) { date in
                XCTAssertEqual(date, Date(timeIntervalSince1970: 123.456))
            }
            
            // error
            do {
                try test(db, strategy: StrategyTimeIntervalSince1970.self, databaseValue: "Yesterday") { date in
                    // Decoding from SQLite statement works:
                    // "Yesterday" is decoded as 0.
                    XCTAssertEqual(date, Date(timeIntervalSince1970: 0))
                }
            } catch let error as DatabaseDecodingError {
                // Decoding from DatabaseValue does not work:
                // "Yesterday" is not decoded as 0.
                switch error {
                case .valueMismatch:
                    XCTAssertEqual(error.description, """
                        could not decode Date from database value "Yesterday" - \
                        column: "date", \
                        column index: 0, \
                        row: [date:"Yesterday"]
                        """)
                default:
                    XCTFail("Unexpected Error")
                }
            }
        }
    }
}

// MARK: - millisecondsSince1970

extension DatabaseDateDecodingStrategyTests {
    func testMillisecondsSince1970() throws {
        try makeDatabaseQueue().read { db in
            // Null
            try testNullDecoding(db, strategy: StrategyMillisecondsSince1970.self)

            // 0
            try test(db, strategy: StrategyMillisecondsSince1970.self, databaseValue: 0) { date in
                XCTAssertEqual(date, Date(timeIntervalSince1970: 0))
            }
            
            // 123.456
            try test(db, strategy: StrategyMillisecondsSince1970.self, databaseValue: 123.456) { date in
                XCTAssertEqual(date, Date(timeIntervalSince1970: 123.456 / 1000 ))
            }
            
            // 123456
            try test(db, strategy: StrategyMillisecondsSince1970.self, databaseValue: 123456) { date in
                XCTAssertEqual(date, Date(timeIntervalSince1970: 123456.0 / 1000))
            }
            
            // 123456.789
            try test(db, strategy: StrategyMillisecondsSince1970.self, databaseValue: 123456.789) { date in
                XCTAssertEqual(date, Date(timeIntervalSince1970: 123456.789 / 1000))
            }
            
            // error
            do {
                try test(db, strategy: StrategyMillisecondsSince1970.self, databaseValue: "Yesterday") { date in
                    // Decoding from SQLite statement works:
                    // "Yesterday" is decoded as 0.
                    XCTAssertEqual(date, Date(timeIntervalSince1970: 0))
                }
            } catch let error as DatabaseDecodingError {
                // Decoding from DatabaseValue does not work:
                // "Yesterday" is not decoded as 0.
                switch error {
                case .valueMismatch:
                    XCTAssertEqual(error.description, """
                        could not decode Date from database value "Yesterday" - \
                        column: "date", \
                        column index: 0, \
                        row: [date:"Yesterday"]
                        """)
                default:
                    XCTFail("Unexpected Error")
                }
            }
        }
    }
}

// MARK: - iso8601(ISO8601DateFormatter)

extension DatabaseDateDecodingStrategyTests {
    func testIso8601() throws {
        // check ISO8601DateFormatter availabiliity
        if #available(macOS 10.12, watchOS 3.0, tvOS 10.0, *) {
            try makeDatabaseQueue().read { db in
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = TimeZone(secondsFromGMT: 0)!
                
                // Null
                try testNullDecoding(db, strategy: StrategyIso8601.self)
                
                // Date
                try test(db, strategy: StrategyIso8601.self, databaseValue: "2018-08-19T17:18:07Z") { date in
                    XCTAssertEqual(calendar.component(.year, from: date), 2018)
                    XCTAssertEqual(calendar.component(.month, from: date), 8)
                    XCTAssertEqual(calendar.component(.day, from: date), 19)
                    XCTAssertEqual(calendar.component(.hour, from: date), 17)
                    XCTAssertEqual(calendar.component(.minute, from: date), 18)
                    XCTAssertEqual(calendar.component(.second, from: date), 7)
                    XCTAssertEqual(calendar.component(.nanosecond, from: date), 0)
                }
                
                // error
                do {
                    try test(db, strategy: StrategyIso8601.self, databaseValue: "Yesterday") { date in
                        XCTFail("Unexpected Date")
                    }
                } catch let error as DatabaseDecodingError {
                    switch error {
                    case .valueMismatch:
                        XCTAssertEqual(error.description, """
                            could not decode Date from database value "Yesterday" - \
                            column: "date", \
                            column index: 0, \
                            row: [date:"Yesterday"], \
                            sql: `SELECT ? AS date`
                            """)
                        XCTAssertEqual(error.expandedDescription, """
                            could not decode Date from database value "Yesterday" - \
                            column: "date", \
                            column index: 0, \
                            row: [date:"Yesterday"], \
                            sql: `SELECT ? AS date`, \
                            arguments: ["Yesterday"]
                            """)
                    default:
                        XCTFail("Unexpected Error")
                    }
                }
            }
        }
    }
}

// MARK: - formatted(DateFormatter)

extension DatabaseDateDecodingStrategyTests {
    func testFormatted() throws {
        try makeDatabaseQueue().read { db in
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            
            // Null
            try testNullDecoding(db, strategy: StrategyFormatted.self)

            // Date
            try test(db, strategy: StrategyFormatted.self, databaseValue: "Sunday, August 19, 2018 at 5:21:55 PM Greenwich Mean Time") { date in
                XCTAssertEqual(calendar.component(.year, from: date), 2018)
                XCTAssertEqual(calendar.component(.month, from: date), 8)
                XCTAssertEqual(calendar.component(.day, from: date), 19)
                XCTAssertEqual(calendar.component(.hour, from: date), 17)
                XCTAssertEqual(calendar.component(.minute, from: date), 21)
                XCTAssertEqual(calendar.component(.second, from: date), 55)
                XCTAssertEqual(calendar.component(.nanosecond, from: date), 0)
            }
            
            // error
            do {
                try test(db, strategy: StrategyFormatted.self, databaseValue: "Yesterday") { date in
                    XCTFail("Unexpected Date")
                }
            } catch let error as DatabaseDecodingError {
                switch error {
                case .valueMismatch:
                    XCTAssertEqual(error.description, """
                        could not decode Date from database value "Yesterday" - \
                        column: "date", \
                        column index: 0, \
                        row: [date:"Yesterday"], \
                        sql: `SELECT ? AS date`
                        """)
                    XCTAssertEqual(error.expandedDescription, """
                        could not decode Date from database value "Yesterday" - \
                        column: "date", \
                        column index: 0, \
                        row: [date:"Yesterday"], \
                        sql: `SELECT ? AS date`, \
                        arguments: ["Yesterday"]
                        """)
                default:
                    XCTFail("Unexpected Error")
                }
            }
        }
    }
}

// MARK: - custom((DatabaseValue) -> Date?

extension DatabaseDateDecodingStrategyTests {
    func testCustom() throws {
        try makeDatabaseQueue().read { db in
            // Null
            try testNullDecoding(db, strategy: StrategyCustom.self)

            // Date
            try test(db, strategy: StrategyCustom.self, databaseValue: "valid") { date in
                XCTAssertEqual(date, Date(timeIntervalSinceReferenceDate: 123456))
            }
            
            // error
            do {
                try test(db, strategy: StrategyCustom.self, databaseValue: "invalid") { date in
                    XCTFail("Unexpected Date")
                }
            } catch let error as DatabaseDecodingError {
                switch error {
                case .valueMismatch:
                    XCTAssertEqual(error.description, """
                        could not decode Date from database value "invalid" - \
                        column: "date", \
                        column index: 0, \
                        row: [date:"invalid"], \
                        sql: `SELECT ? AS date`
                        """)
                    XCTAssertEqual(error.expandedDescription, """
                        could not decode Date from database value "invalid" - \
                        column: "date", \
                        column index: 0, \
                        row: [date:"invalid"], \
                        sql: `SELECT ? AS date`, \
                        arguments: ["invalid"]
                        """)
                default:
                    XCTFail("Unexpected Error")
                }
            }
        }
    }
}

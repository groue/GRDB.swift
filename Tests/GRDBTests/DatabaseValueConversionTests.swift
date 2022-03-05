import XCTest
import GRDB

// TODO: test conversions from invalid UTF-8 blob to string

private enum SQLiteStorageClass {
    case null
    case integer
    case real
    case text
    case blob
}

private extension DatabaseValue {
    var storageClass: SQLiteStorageClass {
        switch storage {
        case .null:   return .null
        case .int64:  return .integer
        case .double: return .real
        case .string: return .text
        case .blob:   return .blob
        }
    }
}

private let emojiString = "'fooéı👨👨🏿🇫🇷🇨🇮'"
private let emojiData = emojiString.data(using: .utf8)
private let nonUTF8Data = Data([0x80])
private let invalidString = "\u{FFFD}" // decoded from nonUTF8Data
private let jpegData = try! Data(contentsOf: testBundle.url(forResource: "Betty", withExtension: "jpeg")!)

class DatabaseValueConversionTests : GRDBTestCase {
    
    private func assertDecoding<T: DatabaseValueConvertible & StatementColumnConvertible & Equatable>(
        _ db: Database,
        _ sql: String,
        _ type: T.Type,
        expectedSQLiteConversion: T?,
        expectedDatabaseValueConversion: T?,
        file: StaticString = #filePath,
        line: UInt = #line) throws
    {
        func stringRepresentation(_ value: T?) -> String {
            guard let value = value else { return "nil" }
            return String(reflecting: value)
        }
        
        do {
            // test T.fetchOne
            let sqliteConversion = try T.fetchOne(db, sql: sql)
            XCTAssert(
                sqliteConversion == expectedSQLiteConversion,
                "unexpected SQLite conversion: \(stringRepresentation(sqliteConversion)) instead of \(stringRepresentation(expectedSQLiteConversion))",
                file: file, line: line)
        }
        
        do {
            // test row[0] as T?
            let sqliteConversion = try Row.fetchCursor(db, sql: sql).map { try $0[0] as T? }.next()!
            XCTAssert(
                sqliteConversion == expectedSQLiteConversion,
                "unexpected SQLite conversion: \(stringRepresentation(sqliteConversion)) instead of \(stringRepresentation(expectedSQLiteConversion))",
                file: file, line: line)
        }
        
        do {
            // test row[0] as T
            let sqliteConversion = try Row.fetchCursor(db, sql: sql).map { try $0.hasNull(atIndex: 0) ? nil : ($0[0] as T) }.next()!
            XCTAssert(
                sqliteConversion == expectedSQLiteConversion,
                "unexpected SQLite conversion: \(stringRepresentation(sqliteConversion)) instead of \(stringRepresentation(expectedSQLiteConversion))",
                file: file, line: line)
        }
        
        do {
            // test T.fromDatabaseValue
            let dbValue = try DatabaseValue.fetchOne(db, sql: sql)!
            let dbValueConversion = T.fromDatabaseValue(dbValue)
            XCTAssert(
                dbValueConversion == expectedDatabaseValueConversion,
                "unexpected SQLite conversion: \(stringRepresentation(dbValueConversion)) instead of \(stringRepresentation(expectedDatabaseValueConversion))",
                file: file, line: line)
        }
    }
    
    private func assertFailedDecoding<T: DatabaseValueConvertible>(
        _ db: Database,
        _ sql: String,
        _ type: T.Type,
        file: StaticString = #filePath,
        line: UInt = #line) throws
    {
        do {
            // test T.fetchOne
            _ = try T.fetchOne(db, sql: sql)
            XCTFail("Expected error")
        } catch is DatabaseDecodingError { }
        
        do {
            // test row[0] as T?
            _ = try Row.fetchCursor(db, sql: sql).map { try $0[0] as T? }.next()!
            XCTFail("Expected error")
        } catch is DatabaseDecodingError { }
        
        do {
            // test row[0] as T
            _ = try Row.fetchCursor(db, sql: sql).map { try $0.hasNull(atIndex: 0) ? nil : ($0[0] as T) }.next()!
            XCTFail("Expected error")
        } catch is DatabaseDecodingError { }
        
        do {
            // test T.fromDatabaseValue
            let dbValue = try DatabaseValue.fetchOne(db, sql: sql)!
            XCTAssertNil(T.fromDatabaseValue(dbValue), file: file, line: line)
        }
    }
    
    // Datatypes In SQLite Version 3: https://www.sqlite.org/datatype3.html
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createPersons") { db in
            try db.execute(sql: """
                CREATE TABLE `values` (
                    integerAffinity INTEGER,
                    textAffinity TEXT,
                    noneAffinity BLOB,
                    realAffinity DOUBLE,
                    numericAffinity NUMERIC)
                """)
        }
        try migrator.migrate(dbWriter)
    }
    
    func testTextAffinity() throws {
        // https://www.sqlite.org/datatype3.html
        //
        // > A column with TEXT affinity stores all data using storage classes
        // > NULL, TEXT or BLOB. If numerical data is inserted into a column
        // > with TEXT affinity it is converted into text form before being
        // > stored.
        
        let dbQueue = try makeDatabaseQueue()
        
        // Null is turned to null
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "INSERT INTO `values` (textAffinity) VALUES (NULL)")
            let sql = "SELECT textAffinity FROM `values`"
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: sql)!.storageClass, .null)
            try assertDecoding(db, sql, Bool.self, expectedSQLiteConversion: nil, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int.self, expectedSQLiteConversion: nil, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int32.self, expectedSQLiteConversion: nil, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int64.self, expectedSQLiteConversion: nil, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Double.self, expectedSQLiteConversion: nil, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, String.self, expectedSQLiteConversion: nil, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Data.self, expectedSQLiteConversion: nil, expectedDatabaseValueConversion: nil)
            return .rollback
        }
        
        // Int is turned to Text
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "INSERT INTO `values` (textAffinity) VALUES (?)", arguments: [0 as Int])
            let sql = "SELECT textAffinity FROM `values`"
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: sql)!.storageClass, .text)
            try assertDecoding(db, sql, Bool.self, expectedSQLiteConversion: false, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int32.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int64.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Double.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, String.self, expectedSQLiteConversion: "0", expectedDatabaseValueConversion: "0")
            try assertDecoding(db, sql, Data.self, expectedSQLiteConversion: "0".data(using: .utf8), expectedDatabaseValueConversion: "0".data(using: .utf8))
            return .rollback
        }
        
        // Int64 is turned to Text
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "INSERT INTO `values` (textAffinity) VALUES (?)", arguments: [0 as Int64])
            let sql = "SELECT textAffinity FROM `values`"
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: sql)!.storageClass, .text)
            try assertDecoding(db, sql, Bool.self, expectedSQLiteConversion: false, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int32.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int64.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Double.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, String.self, expectedSQLiteConversion: "0", expectedDatabaseValueConversion: "0")
            try assertDecoding(db, sql, Data.self, expectedSQLiteConversion: "0".data(using: .utf8), expectedDatabaseValueConversion: "0".data(using: .utf8))
            return .rollback
        }
        
        // Int32 is turned to Text
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "INSERT INTO `values` (textAffinity) VALUES (?)", arguments: [0 as Int32])
            let sql = "SELECT textAffinity FROM `values`"
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: sql)!.storageClass, .text)
            try assertDecoding(db, sql, Bool.self, expectedSQLiteConversion: false, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int32.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int64.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Double.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, String.self, expectedSQLiteConversion: "0", expectedDatabaseValueConversion: "0")
            try assertDecoding(db, sql, Data.self, expectedSQLiteConversion: "0".data(using: .utf8), expectedDatabaseValueConversion: "0".data(using: .utf8))
            return .rollback
        }
        
        // Double is turned to Text
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "INSERT INTO `values` (textAffinity) VALUES (?)", arguments: [0.0])
            let sql = "SELECT textAffinity FROM `values`"
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: sql)!.storageClass, .text)
            try assertDecoding(db, sql, Bool.self, expectedSQLiteConversion: false, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int32.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int64.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Double.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, String.self, expectedSQLiteConversion: "0.0", expectedDatabaseValueConversion: "0.0")
            try assertDecoding(db, sql, Data.self, expectedSQLiteConversion: "0.0".data(using: .utf8), expectedDatabaseValueConversion: "0.0".data(using: .utf8))

            return .rollback
        }
        
        // Empty string is turned to Text
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "INSERT INTO `values` (textAffinity) VALUES (?)", arguments: [""])
            let sql = "SELECT textAffinity FROM `values`"
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: sql)!.storageClass, .text)
            try assertDecoding(db, sql, Bool.self, expectedSQLiteConversion: false, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int32.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int64.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Double.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, String.self, expectedSQLiteConversion: "", expectedDatabaseValueConversion: "")
            try assertDecoding(db, sql, Data.self, expectedSQLiteConversion: Data(), expectedDatabaseValueConversion: Data())
            return .rollback
        }
        
        // "3.0e+5" is turned to Text
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "INSERT INTO `values` (textAffinity) VALUES (?)", arguments: ["3.0e+5"])
            let sql = "SELECT textAffinity FROM `values`"
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: sql)!.storageClass, .text)
            try assertDecoding(db, sql, Bool.self, expectedSQLiteConversion: true, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int.self, expectedSQLiteConversion:3, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int32.self, expectedSQLiteConversion: 3, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int64.self, expectedSQLiteConversion: 3, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Double.self, expectedSQLiteConversion: 300000, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, String.self, expectedSQLiteConversion: "3.0e+5", expectedDatabaseValueConversion: "3.0e+5")
            try assertDecoding(db, sql, Data.self, expectedSQLiteConversion: "3.0e+5".data(using: .utf8), expectedDatabaseValueConversion: "3.0e+5".data(using: .utf8))
            return .rollback
        }
        
        // emojiString is turned to Text
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "INSERT INTO `values` (textAffinity) VALUES (?)", arguments: [emojiString])
            let sql = "SELECT textAffinity FROM `values`"
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: sql)!.storageClass, .text)
            try assertDecoding(db, sql, Bool.self, expectedSQLiteConversion: false, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int.self, expectedSQLiteConversion:0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int32.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int64.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Double.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, String.self, expectedSQLiteConversion: emojiString, expectedDatabaseValueConversion: emojiString)
            try assertDecoding(db, sql, Data.self, expectedSQLiteConversion: emojiData, expectedDatabaseValueConversion: emojiData)
            return .rollback
        }
        
        // emojiData is turned to Blob
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "INSERT INTO `values` (textAffinity) VALUES (?)", arguments: [emojiData])
            let sql = "SELECT textAffinity FROM `values`"
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: sql)!.storageClass, .blob)
            try assertDecoding(db, sql, Bool.self, expectedSQLiteConversion: false, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int.self, expectedSQLiteConversion:0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int32.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int64.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Double.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, String.self, expectedSQLiteConversion: emojiString, expectedDatabaseValueConversion: emojiString)
            try assertDecoding(db, sql, Data.self, expectedSQLiteConversion: emojiData, expectedDatabaseValueConversion: emojiData)
            return .rollback
        }
        
        // nonUTF8Data is turned to Blob
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "INSERT INTO `values` (textAffinity) VALUES (?)", arguments: [nonUTF8Data])
            let sql = "SELECT textAffinity FROM `values`"
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: sql)!.storageClass, .blob)
            try assertDecoding(db, sql, Bool.self, expectedSQLiteConversion: false, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int.self, expectedSQLiteConversion:0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int32.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int64.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Double.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, String.self, expectedSQLiteConversion: invalidString, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Data.self, expectedSQLiteConversion: nonUTF8Data, expectedDatabaseValueConversion: nonUTF8Data)
            return .rollback
        }
        
        // jpegData is turned to Blob
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "INSERT INTO `values` (textAffinity) VALUES (?)", arguments: [jpegData])
            let sql = "SELECT textAffinity FROM `values`"
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: sql)!.storageClass, .blob)
            try assertDecoding(db, sql, Bool.self, expectedSQLiteConversion: false, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int.self, expectedSQLiteConversion:0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int32.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int64.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Double.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            // TODO: test SQLite decoding to String
            try assertFailedDecoding(db, sql, String.self)
            try assertDecoding(db, sql, Data.self, expectedSQLiteConversion: jpegData, expectedDatabaseValueConversion: jpegData)
            return .rollback
        }
    }

    func testNumericAffinity() throws {
        // https://www.sqlite.org/datatype3.html
        //
        // > A column with NUMERIC affinity may contain values using all five
        // > storage classes. When text data is inserted into a NUMERIC column,
        // > the storage class of the text is converted to INTEGER or REAL (in
        // > order of preference) if such conversion is lossless and reversible.
        // > For conversions between TEXT and REAL storage classes, SQLite
        // > considers the conversion to be lossless and reversible if the first
        // > 15 significant decimal digits of the number are preserved. If the
        // > lossless conversion of TEXT to INTEGER or REAL is not possible then
        // > the value is stored using the TEXT storage class. No attempt is
        // > made to convert NULL or BLOB values.
        // >
        // > A string might look like a floating-point literal with a decimal
        // > point and/or exponent notation but as long as the value can be
        // > expressed as an integer, the NUMERIC affinity will convert it into
        // > an integer. Hence, the string '3.0e+5' is stored in a column with
        // > NUMERIC affinity as the integer 300000, not as the floating point
        // > value 300000.0.
        
        try testNumericAffinity("numericAffinity")
    }
    
    func testIntegerAffinity() throws {
        // https://www.sqlite.org/datatype3.html
        //
        // > A column that uses INTEGER affinity behaves the same as a column
        // > with NUMERIC affinity. The difference between INTEGER and NUMERIC
        // > affinity is only evident in a CAST expression.
        
        try testNumericAffinity("integerAffinity")
    }
    
    func testRealAffinity() throws {
        // https://www.sqlite.org/datatype3.html
        //
        // > A column with REAL affinity behaves like a column with NUMERIC
        // > affinity except that it forces integer values into floating point
        // > representation. (As an internal optimization, small floating point
        // > values with no fractional component and stored in columns with REAL
        // > affinity are written to disk as integers in order to take up less
        // > space and are automatically converted back into floating point as
        // > the value is read out. This optimization is completely invisible at
        // > the SQL level and can only be detected by examining the raw bits of
        // > the database file.)
        
        let dbQueue = try makeDatabaseQueue()
        
        // Null is turned to null
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "INSERT INTO `values` (realAffinity) VALUES (NULL)")
            let sql = "SELECT realAffinity FROM `values`"
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: sql)!.storageClass, .null)
            try assertDecoding(db, sql, Bool.self, expectedSQLiteConversion: nil, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int.self, expectedSQLiteConversion: nil, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int32.self, expectedSQLiteConversion: nil, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int64.self, expectedSQLiteConversion: nil, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Double.self, expectedSQLiteConversion: nil, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, String.self, expectedSQLiteConversion: nil, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Data.self, expectedSQLiteConversion: nil, expectedDatabaseValueConversion: nil)
            return .rollback
        }
        
        // Int is turned to Real
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "INSERT INTO `values` (realAffinity) VALUES (?)", arguments: [0 as Int])
            let sql = "SELECT realAffinity FROM `values`"
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: sql)!.storageClass, .real)
            try assertDecoding(db, sql, Bool.self, expectedSQLiteConversion: false, expectedDatabaseValueConversion: false)
            try assertDecoding(db, sql, Int.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: 0)
            try assertDecoding(db, sql, Int32.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: 0)
            try assertDecoding(db, sql, Int64.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: 0)
            try assertDecoding(db, sql, Double.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: 0)
            try assertDecoding(db, sql, String.self, expectedSQLiteConversion: "0.0", expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Data.self, expectedSQLiteConversion: "0.0".data(using: .utf8), expectedDatabaseValueConversion: nil)
            return .rollback
        }
        
        // Int64 is turned to Real
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "INSERT INTO `values` (realAffinity) VALUES (?)", arguments: [0 as Int64])
            let sql = "SELECT realAffinity FROM `values`"
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: sql)!.storageClass, .real)
            try assertDecoding(db, sql, Bool.self, expectedSQLiteConversion: false, expectedDatabaseValueConversion: false)
            try assertDecoding(db, sql, Int.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: 0)
            try assertDecoding(db, sql, Int32.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: 0)
            try assertDecoding(db, sql, Int64.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: 0)
            try assertDecoding(db, sql, Double.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: 0)
            try assertDecoding(db, sql, String.self, expectedSQLiteConversion: "0.0", expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Data.self, expectedSQLiteConversion: "0.0".data(using: .utf8), expectedDatabaseValueConversion: nil)
            return .rollback
        }
        
        // Int32 is turned to Real
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "INSERT INTO `values` (realAffinity) VALUES (?)", arguments: [0 as Int32])
            let sql = "SELECT realAffinity FROM `values`"
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: sql)!.storageClass, .real)
            try assertDecoding(db, sql, Bool.self, expectedSQLiteConversion: false, expectedDatabaseValueConversion: false)
            try assertDecoding(db, sql, Int.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: 0)
            try assertDecoding(db, sql, Int32.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: 0)
            try assertDecoding(db, sql, Int64.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: 0)
            try assertDecoding(db, sql, Double.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: 0)
            try assertDecoding(db, sql, String.self, expectedSQLiteConversion: "0.0", expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Data.self, expectedSQLiteConversion: "0.0".data(using: .utf8), expectedDatabaseValueConversion: nil)
            return .rollback
        }
        
        // 3.0e5 Double is turned to Real
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "INSERT INTO `values` (realAffinity) VALUES (?)", arguments: [3.0e5])
            let sql = "SELECT realAffinity FROM `values`"
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: sql)!.storageClass, .real)
            try assertDecoding(db, sql, Bool.self, expectedSQLiteConversion: true, expectedDatabaseValueConversion: true)
            try assertDecoding(db, sql, Int.self, expectedSQLiteConversion: 300000, expectedDatabaseValueConversion: 300000)
            try assertDecoding(db, sql, Int32.self, expectedSQLiteConversion: 300000, expectedDatabaseValueConversion: 300000)
            try assertDecoding(db, sql, Int64.self, expectedSQLiteConversion: 300000, expectedDatabaseValueConversion: 300000)
            try assertDecoding(db, sql, Double.self, expectedSQLiteConversion: 300000, expectedDatabaseValueConversion: 300000)
            try assertDecoding(db, sql, String.self, expectedSQLiteConversion: "300000.0", expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Data.self, expectedSQLiteConversion: "300000.0".data(using: .utf8), expectedDatabaseValueConversion: nil)
            return .rollback
        }
        
        // 1.0e20 Double is turned to Real
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "INSERT INTO `values` (realAffinity) VALUES (?)", arguments: [1.0e20])
            let sql = "SELECT realAffinity FROM `values`"
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: sql)!.storageClass, .real)
            try assertDecoding(db, sql, Bool.self, expectedSQLiteConversion: true, expectedDatabaseValueConversion: true)
            try assertFailedDecoding(db, sql, Int.self)
            try assertFailedDecoding(db, sql, Int32.self)
            try assertFailedDecoding(db, sql, Int64.self)
            try assertDecoding(db, sql, Double.self, expectedSQLiteConversion: 1e20, expectedDatabaseValueConversion: 1e20)
            try assertDecoding(db, sql, String.self, expectedSQLiteConversion: "1.0e+20", expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Data.self, expectedSQLiteConversion: "1.0e+20".data(using: .utf8), expectedDatabaseValueConversion: nil)
            return .rollback
        }
        
        // Empty string is turned to Text
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "INSERT INTO `values` (realAffinity) VALUES (?)", arguments: [""])
            let sql = "SELECT realAffinity FROM `values`"
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: sql)!.storageClass, .text)
            try assertDecoding(db, sql, Bool.self, expectedSQLiteConversion: false, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int32.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int64.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Double.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, String.self, expectedSQLiteConversion: "", expectedDatabaseValueConversion: "")
            try assertDecoding(db, sql, Data.self, expectedSQLiteConversion: Data(), expectedDatabaseValueConversion: Data())
            return .rollback
        }
        
        // "3.0e+5" is turned to Real
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "INSERT INTO `values` (realAffinity) VALUES (?)", arguments: ["3.0e+5"])
            let sql = "SELECT realAffinity FROM `values`"
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: sql)!.storageClass, .real)
            try assertDecoding(db, sql, Bool.self, expectedSQLiteConversion: true, expectedDatabaseValueConversion: true)
            try assertDecoding(db, sql, Int.self, expectedSQLiteConversion: 300000, expectedDatabaseValueConversion: 300000)
            try assertDecoding(db, sql, Int32.self, expectedSQLiteConversion: 300000, expectedDatabaseValueConversion: 300000)
            try assertDecoding(db, sql, Int64.self, expectedSQLiteConversion: 300000, expectedDatabaseValueConversion: 300000)
            try assertDecoding(db, sql, Double.self, expectedSQLiteConversion: 300000, expectedDatabaseValueConversion: 300000)
            try assertDecoding(db, sql, String.self, expectedSQLiteConversion: "300000.0", expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Data.self, expectedSQLiteConversion: "300000.0".data(using: .utf8), expectedDatabaseValueConversion: nil)
            return .rollback
        }
        
        // "1.0e+20" is turned to Real
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "INSERT INTO `values` (realAffinity) VALUES (?)", arguments: ["1.0e+20"])
            let sql = "SELECT realAffinity FROM `values`"
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: sql)!.storageClass, .real)
            try assertDecoding(db, sql, Bool.self, expectedSQLiteConversion: true, expectedDatabaseValueConversion: true)
            try assertFailedDecoding(db, sql, Int.self)
            try assertFailedDecoding(db, sql, Int32.self)
            try assertFailedDecoding(db, sql, Int64.self)
            try assertDecoding(db, sql, Double.self, expectedSQLiteConversion: 1e20, expectedDatabaseValueConversion: 1e20)
            try assertDecoding(db, sql, String.self, expectedSQLiteConversion: "1.0e+20", expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Data.self, expectedSQLiteConversion: "1.0e+20".data(using: .utf8), expectedDatabaseValueConversion: nil)
            return .rollback
        }
        
        // emojiString is turned to Text
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "INSERT INTO `values` (realAffinity) VALUES (?)", arguments: [emojiString])
            let sql = "SELECT realAffinity FROM `values`"
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: sql)!.storageClass, .text)
            try assertDecoding(db, sql, Bool.self, expectedSQLiteConversion: false, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int.self, expectedSQLiteConversion:0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int32.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int64.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Double.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, String.self, expectedSQLiteConversion: emojiString, expectedDatabaseValueConversion: emojiString)
            try assertDecoding(db, sql, Data.self, expectedSQLiteConversion: emojiData, expectedDatabaseValueConversion: emojiData)
            return .rollback
        }
        
        // emojiData is turned to Blob
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "INSERT INTO `values` (realAffinity) VALUES (?)", arguments: [emojiData])
            let sql = "SELECT realAffinity FROM `values`"
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: sql)!.storageClass, .blob)
            try assertDecoding(db, sql, Bool.self, expectedSQLiteConversion: false, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int.self, expectedSQLiteConversion:0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int32.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int64.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Double.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, String.self, expectedSQLiteConversion: emojiString, expectedDatabaseValueConversion: emojiString)
            try assertDecoding(db, sql, Data.self, expectedSQLiteConversion: emojiData, expectedDatabaseValueConversion: emojiData)
            return .rollback
        }
        
        // nonUTF8Data is turned to Blob
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "INSERT INTO `values` (realAffinity) VALUES (?)", arguments: [nonUTF8Data])
            let sql = "SELECT realAffinity FROM `values`"
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: sql)!.storageClass, .blob)
            try assertDecoding(db, sql, Bool.self, expectedSQLiteConversion: false, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int.self, expectedSQLiteConversion:0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int32.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int64.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Double.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, String.self, expectedSQLiteConversion: invalidString, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Data.self, expectedSQLiteConversion: nonUTF8Data, expectedDatabaseValueConversion: nonUTF8Data)
            return .rollback
        }
        
        // jpegData is turned to Blob
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "INSERT INTO `values` (realAffinity) VALUES (?)", arguments: [jpegData])
            let sql = "SELECT realAffinity FROM `values`"
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: sql)!.storageClass, .blob)
            try assertDecoding(db, sql, Bool.self, expectedSQLiteConversion: false, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int.self, expectedSQLiteConversion:0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int32.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int64.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Double.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            // TODO: test SQLite decoding to String
            try assertFailedDecoding(db, sql, String.self)
            try assertDecoding(db, sql, Data.self, expectedSQLiteConversion: jpegData, expectedDatabaseValueConversion: jpegData)
            return .rollback
        }
    }
    
    func testNoneAffinity() throws {
        // https://www.sqlite.org/datatype3.html
        //
        // > A column with affinity NONE does not prefer one storage class over
        // > another and no attempt is made to coerce data from one storage
        // > class into another.
        
        let dbQueue = try makeDatabaseQueue()
        
        // Null is turned to null
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "INSERT INTO `values` (noneAffinity) VALUES (NULL)")
            let sql = "SELECT noneAffinity FROM `values`"
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: sql)!.storageClass, .null)
            try assertDecoding(db, sql, Bool.self, expectedSQLiteConversion: nil, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int.self, expectedSQLiteConversion: nil, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int32.self, expectedSQLiteConversion: nil, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int64.self, expectedSQLiteConversion: nil, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Double.self, expectedSQLiteConversion: nil, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, String.self, expectedSQLiteConversion: nil, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Data.self, expectedSQLiteConversion: nil, expectedDatabaseValueConversion: nil)
            return .rollback
        }
        
        // Int is turned to Integer
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "INSERT INTO `values` (noneAffinity) VALUES (?)", arguments: [0 as Int])
            let sql = "SELECT noneAffinity FROM `values`"
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: sql)!.storageClass, .integer)
            try assertDecoding(db, sql, Bool.self, expectedSQLiteConversion: false, expectedDatabaseValueConversion: false)
            try assertDecoding(db, sql, Int.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: 0)
            try assertDecoding(db, sql, Int32.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: 0)
            try assertDecoding(db, sql, Int64.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: 0)
            try assertDecoding(db, sql, Double.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: 0)
            try assertDecoding(db, sql, String.self, expectedSQLiteConversion: "0", expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Data.self, expectedSQLiteConversion: "0".data(using: .utf8), expectedDatabaseValueConversion: nil)
            return .rollback
        }
        
        // Int64 is turned to Integer
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "INSERT INTO `values` (noneAffinity) VALUES (?)", arguments: [0 as Int64])
            let sql = "SELECT noneAffinity FROM `values`"
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: sql)!.storageClass, .integer)
            try assertDecoding(db, sql, Bool.self, expectedSQLiteConversion: false, expectedDatabaseValueConversion: false)
            try assertDecoding(db, sql, Int.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: 0)
            try assertDecoding(db, sql, Int32.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: 0)
            try assertDecoding(db, sql, Int64.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: 0)
            try assertDecoding(db, sql, Double.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: 0)
            try assertDecoding(db, sql, String.self, expectedSQLiteConversion: "0", expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Data.self, expectedSQLiteConversion: "0".data(using: .utf8), expectedDatabaseValueConversion: nil)
            return .rollback
        }
        
        // Int32 is turned to Integer
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "INSERT INTO `values` (noneAffinity) VALUES (?)", arguments: [0 as Int32])
            let sql = "SELECT noneAffinity FROM `values`"
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: sql)!.storageClass, .integer)
            try assertDecoding(db, sql, Bool.self, expectedSQLiteConversion: false, expectedDatabaseValueConversion: false)
            try assertDecoding(db, sql, Int.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: 0)
            try assertDecoding(db, sql, Int32.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: 0)
            try assertDecoding(db, sql, Int64.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: 0)
            try assertDecoding(db, sql, Double.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: 0)
            try assertDecoding(db, sql, String.self, expectedSQLiteConversion: "0", expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Data.self, expectedSQLiteConversion: "0".data(using: .utf8), expectedDatabaseValueConversion: nil)
            return .rollback
        }
        
        // Double is turned to Real
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "INSERT INTO `values` (noneAffinity) VALUES (?)", arguments: [0.0])
            let sql = "SELECT noneAffinity FROM `values`"
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: sql)!.storageClass, .real)
            try assertDecoding(db, sql, Bool.self, expectedSQLiteConversion: false, expectedDatabaseValueConversion: false)
            try assertDecoding(db, sql, Int.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: 0)
            try assertDecoding(db, sql, Int32.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: 0)
            try assertDecoding(db, sql, Int64.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: 0)
            try assertDecoding(db, sql, Double.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: 0)
            try assertDecoding(db, sql, String.self, expectedSQLiteConversion: "0.0", expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Data.self, expectedSQLiteConversion: "0.0".data(using: .utf8), expectedDatabaseValueConversion: nil)
            return .rollback
        }
        
        // Empty string is turned to Text
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "INSERT INTO `values` (noneAffinity) VALUES (?)", arguments: [""])
            let sql = "SELECT noneAffinity FROM `values`"
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: sql)!.storageClass, .text)
            try assertDecoding(db, sql, Bool.self, expectedSQLiteConversion: false, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int32.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int64.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Double.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, String.self, expectedSQLiteConversion: "", expectedDatabaseValueConversion: "")
            try assertDecoding(db, sql, Data.self, expectedSQLiteConversion: Data(), expectedDatabaseValueConversion: Data())
            return .rollback
        }
        
        // "3.0e+5" is turned to Text
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "INSERT INTO `values` (noneAffinity) VALUES (?)", arguments: ["3.0e+5"])
            let sql = "SELECT noneAffinity FROM `values`"
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: sql)!.storageClass, .text)
            try assertDecoding(db, sql, Bool.self, expectedSQLiteConversion: true, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int.self, expectedSQLiteConversion:3, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int32.self, expectedSQLiteConversion: 3, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int64.self, expectedSQLiteConversion: 3, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Double.self, expectedSQLiteConversion: 300000, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, String.self, expectedSQLiteConversion: "3.0e+5", expectedDatabaseValueConversion: "3.0e+5")
            try assertDecoding(db, sql, Data.self, expectedSQLiteConversion: "3.0e+5".data(using: .utf8), expectedDatabaseValueConversion: "3.0e+5".data(using: .utf8))
            return .rollback
        }
        
        // emojiString is turned to Text
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "INSERT INTO `values` (noneAffinity) VALUES (?)", arguments: [emojiString])
            let sql = "SELECT noneAffinity FROM `values`"
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: sql)!.storageClass, .text)
            try assertDecoding(db, sql, Bool.self, expectedSQLiteConversion: false, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int.self, expectedSQLiteConversion:0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int32.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int64.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Double.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, String.self, expectedSQLiteConversion: emojiString, expectedDatabaseValueConversion: emojiString)
            try assertDecoding(db, sql, Data.self, expectedSQLiteConversion: emojiData, expectedDatabaseValueConversion: emojiData)
            return .rollback
        }
        
        // emojiData is turned to Blob
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "INSERT INTO `values` (noneAffinity) VALUES (?)", arguments: [emojiData])
            let sql = "SELECT noneAffinity FROM `values`"
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: sql)!.storageClass, .blob)
            try assertDecoding(db, sql, Bool.self, expectedSQLiteConversion: false, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int.self, expectedSQLiteConversion:0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int32.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int64.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Double.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, String.self, expectedSQLiteConversion: emojiString, expectedDatabaseValueConversion: emojiString)
            try assertDecoding(db, sql, Data.self, expectedSQLiteConversion: emojiData, expectedDatabaseValueConversion: emojiData)
            return .rollback
        }
        
        // nonUTF8Data is turned to Blob
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "INSERT INTO `values` (noneAffinity) VALUES (?)", arguments: [nonUTF8Data])
            let sql = "SELECT noneAffinity FROM `values`"
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: sql)!.storageClass, .blob)
            try assertDecoding(db, sql, Bool.self, expectedSQLiteConversion: false, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int.self, expectedSQLiteConversion:0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int32.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int64.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Double.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, String.self, expectedSQLiteConversion: invalidString, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Data.self, expectedSQLiteConversion: nonUTF8Data, expectedDatabaseValueConversion: nonUTF8Data)
            return .rollback
        }
        
        // jpegData is turned to Blob
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "INSERT INTO `values` (noneAffinity) VALUES (?)", arguments: [jpegData])
            let sql = "SELECT noneAffinity FROM `values`"
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: sql)!.storageClass, .blob)
            try assertDecoding(db, sql, Bool.self, expectedSQLiteConversion: false, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int.self, expectedSQLiteConversion:0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int32.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int64.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Double.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            // TODO: test SQLite decoding to String
            try assertFailedDecoding(db, sql, String.self)
            try assertDecoding(db, sql, Data.self, expectedSQLiteConversion: jpegData, expectedDatabaseValueConversion: jpegData)
            return .rollback
        }
    }
    
    func testNumericAffinity(_ columnName: String) throws {
        // https://www.sqlite.org/datatype3.html
        //
        // > A column with NUMERIC affinity may contain values using all five
        // > storage classes. When text data is inserted into a NUMERIC column,
        // > the storage class of the text is converted to INTEGER or REAL (in
        // > order of preference) if such conversion is lossless and reversible.
        // > For conversions between TEXT and REAL storage classes, SQLite
        // > considers the conversion to be lossless and reversible if the first
        // > 15 significant decimal digits of the number are preserved. If the
        // > lossless conversion of TEXT to INTEGER or REAL is not possible then
        // > the value is stored using the TEXT storage class. No attempt is
        // > made to convert NULL or BLOB values.
        // >
        // > A string might look like a floating-point literal with a decimal
        // > point and/or exponent notation but as long as the value can be
        // > expressed as an integer, the NUMERIC affinity will convert it into
        // > an integer. Hence, the string '3.0e+5' is stored in a column with
        // > NUMERIC affinity as the integer 300000, not as the floating point
        // > value 300000.0.
        
        let dbQueue = try makeDatabaseQueue()
        
        // Null is turned to null
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "INSERT INTO `values` (\(columnName)) VALUES (NULL)")
            let sql = "SELECT \(columnName) FROM `values`"
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: sql)!.storageClass, .null)
            try assertDecoding(db, sql, Bool.self, expectedSQLiteConversion: nil, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int.self, expectedSQLiteConversion: nil, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int32.self, expectedSQLiteConversion: nil, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int64.self, expectedSQLiteConversion: nil, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Double.self, expectedSQLiteConversion: nil, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, String.self, expectedSQLiteConversion: nil, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Data.self, expectedSQLiteConversion: nil, expectedDatabaseValueConversion: nil)
            return .rollback
        }
        
        // Int is turned to Integer
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "INSERT INTO `values` (\(columnName)) VALUES (?)", arguments: [0 as Int])
            let sql = "SELECT \(columnName) FROM `values`"
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: sql)!.storageClass, .integer)
            try assertDecoding(db, sql, Bool.self, expectedSQLiteConversion: false, expectedDatabaseValueConversion: false)
            try assertDecoding(db, sql, Int.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: 0)
            try assertDecoding(db, sql, Int32.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: 0)
            try assertDecoding(db, sql, Int64.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: 0)
            try assertDecoding(db, sql, Double.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: 0)
            try assertDecoding(db, sql, String.self, expectedSQLiteConversion: "0", expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Data.self, expectedSQLiteConversion: "0".data(using: .utf8), expectedDatabaseValueConversion: nil)
            return .rollback
        }
        
        // Int64 is turned to Integer
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "INSERT INTO `values` (\(columnName)) VALUES (?)", arguments: [0 as Int64])
            let sql = "SELECT \(columnName) FROM `values`"
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: sql)!.storageClass, .integer)
            try assertDecoding(db, sql, Bool.self, expectedSQLiteConversion: false, expectedDatabaseValueConversion: false)
            try assertDecoding(db, sql, Int.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: 0)
            try assertDecoding(db, sql, Int32.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: 0)
            try assertDecoding(db, sql, Int64.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: 0)
            try assertDecoding(db, sql, Double.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: 0)
            try assertDecoding(db, sql, String.self, expectedSQLiteConversion: "0", expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Data.self, expectedSQLiteConversion: "0".data(using: .utf8), expectedDatabaseValueConversion: nil)
            return .rollback
        }
        
        // Int32 is turned to Integer
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "INSERT INTO `values` (\(columnName)) VALUES (?)", arguments: [0 as Int32])
            let sql = "SELECT \(columnName) FROM `values`"
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: sql)!.storageClass, .integer)
            try assertDecoding(db, sql, Bool.self, expectedSQLiteConversion: false, expectedDatabaseValueConversion: false)
            try assertDecoding(db, sql, Int.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: 0)
            try assertDecoding(db, sql, Int32.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: 0)
            try assertDecoding(db, sql, Int64.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: 0)
            try assertDecoding(db, sql, Double.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: 0)
            try assertDecoding(db, sql, String.self, expectedSQLiteConversion: "0", expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Data.self, expectedSQLiteConversion: "0".data(using: .utf8), expectedDatabaseValueConversion: nil)
            return .rollback
        }
        
        // 3.0e5 Double is turned to Integer
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "INSERT INTO `values` (\(columnName)) VALUES (?)", arguments: [3.0e5])
            let sql = "SELECT \(columnName) FROM `values`"
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: sql)!.storageClass, .integer)
            try assertDecoding(db, sql, Bool.self, expectedSQLiteConversion: true, expectedDatabaseValueConversion: true)
            try assertDecoding(db, sql, Int.self, expectedSQLiteConversion: 300000, expectedDatabaseValueConversion: 300000)
            try assertDecoding(db, sql, Int32.self, expectedSQLiteConversion: 300000, expectedDatabaseValueConversion: 300000)
            try assertDecoding(db, sql, Int64.self, expectedSQLiteConversion: 300000, expectedDatabaseValueConversion: 300000)
            try assertDecoding(db, sql, Double.self, expectedSQLiteConversion: 300000, expectedDatabaseValueConversion: 300000)
            try assertDecoding(db, sql, String.self, expectedSQLiteConversion: "300000", expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Data.self, expectedSQLiteConversion: "300000".data(using: .utf8), expectedDatabaseValueConversion: nil)
            return .rollback
        }
        
        // 1.0e20 Double is turned to Real
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "INSERT INTO `values` (\(columnName)) VALUES (?)", arguments: [1.0e20])
            let sql = "SELECT \(columnName) FROM `values`"
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: sql)!.storageClass, .real)
            try assertDecoding(db, sql, Bool.self, expectedSQLiteConversion: true, expectedDatabaseValueConversion: true)
            try assertFailedDecoding(db, sql, Int.self)
            try assertFailedDecoding(db, sql, Int32.self)
            try assertFailedDecoding(db, sql, Int64.self)
            try assertDecoding(db, sql, Double.self, expectedSQLiteConversion: 1e20, expectedDatabaseValueConversion: 1e20)
            try assertDecoding(db, sql, String.self, expectedSQLiteConversion: "1.0e+20", expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Data.self, expectedSQLiteConversion: "1.0e+20".data(using: .utf8), expectedDatabaseValueConversion: nil)
            return .rollback
        }
        
        // Empty string is turned to Text
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "INSERT INTO `values` (\(columnName)) VALUES (?)", arguments: [""])
            let sql = "SELECT \(columnName) FROM `values`"
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: sql)!.storageClass, .text)
            try assertDecoding(db, sql, Bool.self, expectedSQLiteConversion: false, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int32.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int64.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Double.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, String.self, expectedSQLiteConversion: "", expectedDatabaseValueConversion: "")
            try assertDecoding(db, sql, Data.self, expectedSQLiteConversion: Data(), expectedDatabaseValueConversion: Data())
            return .rollback
        }
        
        // "3.0e+5" is turned to Integer
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "INSERT INTO `values` (\(columnName)) VALUES (?)", arguments: ["3.0e+5"])
            let sql = "SELECT \(columnName) FROM `values`"
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: sql)!.storageClass, .integer)
            try assertDecoding(db, sql, Bool.self, expectedSQLiteConversion: true, expectedDatabaseValueConversion: true)
            try assertDecoding(db, sql, Int.self, expectedSQLiteConversion: 300000, expectedDatabaseValueConversion: 300000)
            try assertDecoding(db, sql, Int32.self, expectedSQLiteConversion: 300000, expectedDatabaseValueConversion: 300000)
            try assertDecoding(db, sql, Int64.self, expectedSQLiteConversion: 300000, expectedDatabaseValueConversion: 300000)
            try assertDecoding(db, sql, Double.self, expectedSQLiteConversion: 300000, expectedDatabaseValueConversion: 300000)
            try assertDecoding(db, sql, String.self, expectedSQLiteConversion: "300000", expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Data.self, expectedSQLiteConversion: "300000".data(using: .utf8), expectedDatabaseValueConversion: nil)
            return .rollback
        }
        
        // "1.0e+20" is turned to Real
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "INSERT INTO `values` (\(columnName)) VALUES (?)", arguments: ["1.0e+20"])
            let sql = "SELECT \(columnName) FROM `values`"
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: sql)!.storageClass, .real)
            try assertDecoding(db, sql, Bool.self, expectedSQLiteConversion: true, expectedDatabaseValueConversion: true)
            try assertFailedDecoding(db, sql, Int.self)
            try assertFailedDecoding(db, sql, Int32.self)
            try assertFailedDecoding(db, sql, Int64.self)
            try assertDecoding(db, sql, Double.self, expectedSQLiteConversion: 1e20, expectedDatabaseValueConversion: 1e20)
            try assertDecoding(db, sql, String.self, expectedSQLiteConversion: "1.0e+20", expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Data.self, expectedSQLiteConversion: "1.0e+20".data(using: .utf8), expectedDatabaseValueConversion: nil)
            return .rollback
        }
        
        // emojiString is turned to Text
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "INSERT INTO `values` (\(columnName)) VALUES (?)", arguments: [emojiString])
            let sql = "SELECT \(columnName) FROM `values`"
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: sql)!.storageClass, .text)
            try assertDecoding(db, sql, Bool.self, expectedSQLiteConversion: false, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int.self, expectedSQLiteConversion:0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int32.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int64.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Double.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, String.self, expectedSQLiteConversion: emojiString, expectedDatabaseValueConversion: emojiString)
            try assertDecoding(db, sql, Data.self, expectedSQLiteConversion: emojiData, expectedDatabaseValueConversion: emojiData)
            return .rollback
        }
        
        // emojiData is turned to Blob
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "INSERT INTO `values` (\(columnName)) VALUES (?)", arguments: [emojiData])
            let sql = "SELECT \(columnName) FROM `values`"
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: sql)!.storageClass, .blob)
            try assertDecoding(db, sql, Bool.self, expectedSQLiteConversion: false, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int.self, expectedSQLiteConversion:0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int32.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int64.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Double.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, String.self, expectedSQLiteConversion: emojiString, expectedDatabaseValueConversion: emojiString)
            try assertDecoding(db, sql, Data.self, expectedSQLiteConversion: emojiData, expectedDatabaseValueConversion: emojiData)
            return .rollback
        }
        
        // nonUTF8Data is turned to Blob
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "INSERT INTO `values` (\(columnName)) VALUES (?)", arguments: [nonUTF8Data])
            let sql = "SELECT \(columnName) FROM `values`"
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: sql)!.storageClass, .blob)
            try assertDecoding(db, sql, Bool.self, expectedSQLiteConversion: false, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int.self, expectedSQLiteConversion:0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int32.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int64.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Double.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, String.self, expectedSQLiteConversion: invalidString, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Data.self, expectedSQLiteConversion: nonUTF8Data, expectedDatabaseValueConversion: nonUTF8Data)
            return .rollback
        }
        
        // jpegData is turned to Blob
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "INSERT INTO `values` (\(columnName)) VALUES (?)", arguments: [jpegData])
            let sql = "SELECT \(columnName) FROM `values`"
            XCTAssertEqual(try DatabaseValue.fetchOne(db, sql: sql)!.storageClass, .blob)
            try assertDecoding(db, sql, Bool.self, expectedSQLiteConversion: false, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int.self, expectedSQLiteConversion:0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int32.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Int64.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            try assertDecoding(db, sql, Double.self, expectedSQLiteConversion: 0, expectedDatabaseValueConversion: nil)
            // TODO: test SQLite decoding to String
            try assertFailedDecoding(db, sql, String.self)
            try assertDecoding(db, sql, Data.self, expectedSQLiteConversion: jpegData, expectedDatabaseValueConversion: jpegData)
            return .rollback
        }
    }
}

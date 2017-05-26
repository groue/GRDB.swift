import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class StatementColumnConvertibleTests : GRDBTestCase {
    
    // Datatypes In SQLite Version 3: https://www.sqlite.org/datatype3.html
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createPersons") { db in
            try db.execute(
                "CREATE TABLE `values` (" +
                    "integerAffinity INTEGER, " +
                    "textAffinity TEXT, " +
                    "noneAffinity BLOB, " +
                    "realAffinity DOUBLE, " +
                    "numericAffinity NUMERIC" +
                ")")
        }
        try migrator.migrate(dbWriter)
    }
    
    private func fetchValue<T: DatabaseValueConvertible & StatementColumnConvertible>(_ db: Database, _ columnName: String) throws -> T? {
        return try Row.fetchCursor(db, "SELECT \(columnName) FROM `values`").next()!.value(atIndex: 0)
    }
    
    private func fetchValue<T: DatabaseValueConvertible & StatementColumnConvertible>(_ db: Database, _ columnName: String) throws -> T {
        return try Row.fetchCursor(db, "SELECT \(columnName) FROM `values`").next()!.value(atIndex: 0)
    }
    
    private func fetchValue<T: DatabaseValueConvertible>(_ db: Database, _ columnName: String) throws -> T? {
        return try Row.fetchCursor(db, "SELECT \(columnName) FROM `values`").next()!.value(atIndex: 0)
    }
    
    private func fetchValue<T: DatabaseValueConvertible>(_ db: Database, _ columnName: String) throws -> T {
        return try Row.fetchCursor(db, "SELECT \(columnName) FROM `values`").next()!.value(atIndex: 0)
    }
    
    func testTextAffinity() throws {
        // https://www.sqlite.org/datatype3.html
        //
        // > A column with TEXT affinity stores all data using storage classes
        // > NULL, TEXT or BLOB. If numerical data is inserted into a column
        // > with TEXT affinity it is converted into text form before being
        // > stored.
        
        let dbQueue = try makeDatabaseQueue()
        
        // Int is turned to Text
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (textAffinity) VALUES (?)", arguments: [0 as Int])
            // Check SQLite conversions from Text storage:
            XCTAssertEqual((try fetchValue(db, "textAffinity") as Bool?), false)     // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "textAffinity") as Int?), 0)          // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "textAffinity") as Int32?), 0)        // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "textAffinity") as Int64?), 0)        // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "textAffinity") as Double?), 0.0)     // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "textAffinity") as String?)!, "0")
            XCTAssertEqual((try fetchValue(db, "textAffinity") as String), "0")
            // Data extraction: precondition failed: could not convert "0" to Data
            //                XCTAssertEqual((try fetchValue(db, "textAffinity") as Data?) == nil)
            return .rollback
        }
        
        // Int64 is turned to Text
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (textAffinity) VALUES (?)", arguments: [0 as Int64])
            // Check SQLite conversions from Text storage:
            XCTAssertEqual((try fetchValue(db, "textAffinity") as Bool?), false)     // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "textAffinity") as Int?), 0)          // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "textAffinity") as Int32?), 0)        // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "textAffinity") as Int64?), 0)        // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "textAffinity") as Double?), 0.0)     // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "textAffinity") as String?)!, "0")
            XCTAssertEqual((try fetchValue(db, "textAffinity") as String), "0")
            // Data extraction: precondition failed: could not convert "0" to Data
            //                XCTAssertEqual((try fetchValue(db, "textAffinity") as Data?) == nil)
            return .rollback
        }
        
        // Int32 is turned to Text
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (textAffinity) VALUES (?)", arguments: [0 as Int32])
            // Check SQLite conversions from Text storage:
            XCTAssertEqual((try fetchValue(db, "textAffinity") as Bool?), false)     // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "textAffinity") as Int?), 0)          // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "textAffinity") as Int32?), 0)        // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "textAffinity") as Int64?), 0)        // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "textAffinity") as Double?), 0.0)     // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "textAffinity") as String?)!, "0")
            XCTAssertEqual((try fetchValue(db, "textAffinity") as String), "0")
            // Data extraction: precondition failed: could not convert "0" to Data
            //                XCTAssertEqual((try fetchValue(db, "textAffinity") as Data?) == nil)
            return .rollback
        }
        
        // Double is turned to Text
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (textAffinity) VALUES (?)", arguments: [0.0])
            // Check SQLite conversions from Text storage:
            XCTAssertEqual((try fetchValue(db, "textAffinity") as Bool?), false)     // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "textAffinity") as Int?), 0)          // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "textAffinity") as Int32?), 0)        // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "textAffinity") as Int64?), 0)        // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "textAffinity") as Double?), 0.0)     // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "textAffinity") as String?)!, "0.0")
            XCTAssertEqual((try fetchValue(db, "textAffinity") as String), "0.0")
            // Data extraction: precondition failed: could not convert "0.0" to Data
            //                XCTAssertEqual((try fetchValue(db, "textAffinity") as Data?) == nil)
            return .rollback
        }
        
        // "3.0e+5" is turned to Text
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (textAffinity) VALUES (?)", arguments: ["3.0e+5"])
            // Check SQLite conversions from Text storage:
            XCTAssertEqual((try fetchValue(db, "textAffinity") as Bool?), true)          // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "textAffinity") as Int?), 3)              // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "textAffinity") as Int32?), 3)            // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "textAffinity") as Int64?), 3)            // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "textAffinity") as Double?), 300000.0)    // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "textAffinity") as String?)!, "3.0e+5")
            XCTAssertEqual((try fetchValue(db, "textAffinity") as String), "3.0e+5")
            // Data extraction: precondition failed: could not convert "3.0e+5" to Data
            //                XCTAssertEqual((try fetchValue(db, "textAffinity") as Data?) == nil)
            return .rollback
        }
        
        // "'fooéı👨👨🏿🇫🇷🇨🇮'" is turned to Text
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (textAffinity) VALUES (?)", arguments: ["'fooéı👨👨🏿🇫🇷🇨🇮'"])
            // Check SQLite conversions from Text storage:
            XCTAssertEqual((try fetchValue(db, "textAffinity") as Bool?), false)     // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "textAffinity") as Int?), 0)          // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "textAffinity") as Int32?), 0)        // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "textAffinity") as Int64?), 0)        // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "textAffinity") as Double?), 0.0)     // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "textAffinity") as String?)!, "'fooéı👨👨🏿🇫🇷🇨🇮'")
            XCTAssertEqual((try fetchValue(db, "textAffinity") as String), "'fooéı👨👨🏿🇫🇷🇨🇮'")
            // Data extraction: precondition failed: could not convert "'fooéı👨👨🏿🇫🇷🇨🇮'" to Data
            //                XCTAssertEqual((try fetchValue(db, "textAffinity") as Data?) == nil)
            return .rollback
        }
        
        // Blob is turned to Blob
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (textAffinity) VALUES (?)", arguments: ["'fooéı👨👨🏿🇫🇷🇨🇮'".data(using: .utf8)])
            // Check SQLite conversions from Blob storage:
            XCTAssertEqual((try fetchValue(db, "textAffinity") as Bool?), false)     // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "textAffinity") as Int?), 0)          // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "textAffinity") as Int32?), 0)        // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "textAffinity") as Int64?), 0)        // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "textAffinity") as Double?), 0.0)     // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "textAffinity") as String?), "'fooéı👨👨🏿🇫🇷🇨🇮'")   // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "textAffinity") as Data?), "'fooéı👨👨🏿🇫🇷🇨🇮'".data(using: .utf8))
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
        
        // Int is turned to Real
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (realAffinity) VALUES (?)", arguments: [0 as Int])
            // Check SQLite conversions from Real storage
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Bool?)!, false)
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Bool), false)
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Int?)!, 0)
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Int), 0)
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Int32?)!, Int32(0))
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Int32), Int32(0))
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Int64?)!, Int64(0))
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Int64), Int64(0))
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Double?)!, 0.0)
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Double), 0.0)
            XCTAssertEqual((try fetchValue(db, "realAffinity") as String?), "0.0")   // incompatible with DatabaseValue conversion
            // Data extraction: precondition failed: could not convert 0.0 to Data
//                XCTAssertEqual((try fetchValue(db, "realAffinity") as Data?) == nil)
            return .rollback
        }
        
        // Int64 is turned to Real
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (realAffinity) VALUES (?)", arguments: [0 as Int64])
            // Check SQLite conversions from Real storage
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Bool?)!, false)
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Bool), false)
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Int?)!, 0)
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Int), 0)
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Int32?)!, Int32(0))
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Int32), Int32(0))
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Int64?)!, Int64(0))
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Int64), Int64(0))
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Double?)!, 0.0)
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Double), 0.0)
            XCTAssertEqual((try fetchValue(db, "realAffinity") as String?), "0.0")   // incompatible with DatabaseValue conversion
            // Data extraction: precondition failed: could not convert 0.0 to Data
//                XCTAssertEqual((try fetchValue(db, "realAffinity") as Data?) == nil)
            return .rollback
        }
        
        // Int32 is turned to Real
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (realAffinity) VALUES (?)", arguments: [0 as Int32])
            // Check SQLite conversions from Real storage
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Bool?)!, false)
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Bool), false)
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Int?)!, 0)
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Int), 0)
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Int32?)!, Int32(0))
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Int32), Int32(0))
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Int64?)!, Int64(0))
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Int64), Int64(0))
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Double?)!, 0.0)
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Double), 0.0)
            XCTAssertEqual((try fetchValue(db, "realAffinity") as String?), "0.0")   // incompatible with DatabaseValue conversion
            // Data extraction: precondition failed: could not convert 0.0 to Data
//                XCTAssertEqual((try fetchValue(db, "realAffinity") as Data?) == nil)
            return .rollback
        }
        
        // 3.0e5 Double is turned to Real
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (realAffinity) VALUES (?)", arguments: [3.0e5])
            // Check SQLite conversions from Real storage
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Bool?)!, true)
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Bool), true)
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Int?)!, 300000)
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Int), 300000)
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Int32?)!, Int32(300000))
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Int32), Int32(300000))
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Int64?)!, Int64(300000))
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Int64), Int64(300000))
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Double?)!, Double(300000))
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Double), Double(300000))
            XCTAssertEqual((try fetchValue(db, "realAffinity") as String?), "300000.0")    // incompatible with DatabaseValue conversion
            // Data extraction: precondition failed: could not convert 300000.0 to Data
//                XCTAssertEqual((try fetchValue(db, "realAffinity") as Data?) == nil)
            return .rollback
        }
        
        // 1.0e20 Double is turned to Real
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (realAffinity) VALUES (?)", arguments: [1.0e20])
            // Check SQLite conversions from Real storage (avoid Int, Int32 and Int64 since 1.0e20 does not fit)
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Bool?)!, true)
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Bool), true)
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Double?)!, 1e20)
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Double), 1e20)
            XCTAssertEqual((try fetchValue(db, "realAffinity") as String?), "1.0e+20")   // incompatible with DatabaseValue conversion
            // Data extraction: precondition failed: could not convert 1e+20 to Data
//                XCTAssertEqual((try fetchValue(db, "realAffinity") as Data?) == nil)
            return .rollback
        }
        
        // "3.0e+5" is turned to Real
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (realAffinity) VALUES (?)", arguments: ["3.0e+5"])
            // Check SQLite conversions from Real storage
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Bool?)!, true)
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Bool), true)
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Int?)!, 300000)
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Int), 300000)
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Int32?)!, Int32(300000))
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Int32), Int32(300000))
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Int64?)!, Int64(300000))
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Int64), Int64(300000))
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Double?)!, Double(300000))
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Double), Double(300000))
            XCTAssertEqual((try fetchValue(db, "realAffinity") as String?), "300000.0")  // incompatible with DatabaseValue conversion
            // Data extraction: precondition failed: could not convert 300000.0 to Data
//                XCTAssertEqual((try fetchValue(db, "realAffinity") as Data?) == nil)
            return .rollback
        }
        
        // "1.0e+20" is turned to Real
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (realAffinity) VALUES (?)", arguments: ["1.0e+20"])
            // Check SQLite conversions from Real storage: (avoid Int, Int32 and Int64 since 1.0e20 does not fit)
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Bool?)!, true)
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Bool), true)
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Double?)!, 1e20)
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Double), 1e20)
            XCTAssertEqual((try fetchValue(db, "realAffinity") as String?), "1.0e+20")   // incompatible with DatabaseValue conversion
            // Data extraction: precondition failed: could not convert 1e+20 to Data
//                XCTAssertEqual((try fetchValue(db, "realAffinity") as Data?) == nil)
            return .rollback
        }
        
        // "'fooéı👨👨🏿🇫🇷🇨🇮'" is turned to Text
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (realAffinity) VALUES (?)", arguments: ["'fooéı👨👨🏿🇫🇷🇨🇮'"])
            // Check SQLite conversions from Text storage:
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Bool?), false)     // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Int?), 0)          // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Int32?), 0)        // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Int64?), 0)        // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Double?), 0.0)     // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "realAffinity") as String?)!, "'fooéı👨👨🏿🇫🇷🇨🇮'")
            XCTAssertEqual((try fetchValue(db, "realAffinity") as String), "'fooéı👨👨🏿🇫🇷🇨🇮'")
            // Data extraction: precondition failed: could not convert "'fooéı👨👨🏿🇫🇷🇨🇮'" to Data
//                XCTAssertEqual((try fetchValue(db, "realAffinity") as Data?) == nil)
            return .rollback
        }
        
        // Blob is turned to Blob
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (realAffinity) VALUES (?)", arguments: ["'fooéı👨👨🏿🇫🇷🇨🇮'".data(using: .utf8)])
            // Check SQLite conversions from Blob storage:
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Bool?), false)     // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Int?), 0)          // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Int32?), 0)        // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Int64?), 0)        // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Double?), 0.0)     // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "realAffinity") as String?), "'fooéı👨👨🏿🇫🇷🇨🇮'")   // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "realAffinity") as Data?), "'fooéı👨👨🏿🇫🇷🇨🇮'".data(using: .utf8))
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
        
        // Int is turned to Integer
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (noneAffinity) VALUES (?)", arguments: [0 as Int])
            // Check SQLite conversions from Integer storage
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Bool?)!, false)
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Bool), false)
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Int?)!, 0)
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Int), 0)
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Int32?)!, Int32(0))
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Int32), Int32(0))
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Int64?)!, Int64(0))
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Int64), Int64(0))
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Double?)!, 0.0)
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Double), 0.0)
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as String?), "0")     // incompatible with DatabaseValue conversion
            // Data extraction: precondition failed: could not convert 0 to Data
//                XCTAssertEqual((try fetchValue(db, "noneAffinity") as Data?) == nil)
            return .rollback
        }
        
        // Int64 is turned to Integer
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (noneAffinity) VALUES (?)", arguments: [0 as Int64])
            // Check SQLite conversions from Integer storage
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Bool?)!, false)
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Bool), false)
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Int?)!, 0)
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Int), 0)
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Int32?)!, Int32(0))
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Int32), Int32(0))
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Int64?)!, Int64(0))
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Int64), Int64(0))
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Double?)!, 0.0)
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Double), 0.0)
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as String?), "0")     // incompatible with DatabaseValue conversion
            // Data extraction: precondition failed: could not convert 0 to Data
//                XCTAssertEqual((try fetchValue(db, "noneAffinity") as Data?) == nil)
            return .rollback
        }
        
        // Int32 is turned to Integer
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (noneAffinity) VALUES (?)", arguments: [0 as Int32])
            // Check SQLite conversions from Integer storage
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Bool?)!, false)
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Bool), false)
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Int?)!, 0)
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Int), 0)
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Int32?)!, Int32(0))
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Int32), Int32(0))
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Int64?)!, Int64(0))
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Int64), Int64(0))
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Double?)!, 0.0)
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Double), 0.0)
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as String?), "0")     // incompatible with DatabaseValue conversion
            // Data extraction: precondition failed: could not convert 0 to Data
//                XCTAssertEqual((try fetchValue(db, "noneAffinity") as Data?) == nil)
            return .rollback
        }
        
        // Double is turned to Real
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (noneAffinity) VALUES (?)", arguments: [0.0])
            // Check SQLite conversions from Real storage
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Bool?)!, false)
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Bool), false)
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Int?)!, 0)
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Int), 0)
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Int32?)!, Int32(0))
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Int32), Int32(0))
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Int64?)!, Int64(0))
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Int64), Int64(0))
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Double?)!, 0.0)
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Double), 0.0)
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as String?), "0.0")   // incompatible with DatabaseValue conversion
            // Data extraction: precondition failed: could not convert 0.0 to Data
//                XCTAssertEqual((try fetchValue(db, "noneAffinity") as Data?) == nil)
            return .rollback
        }
        
        // "3.0e+5" is turned to Text
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (noneAffinity) VALUES (?)", arguments: ["3.0e+5"])
            // Check SQLite conversions from Text storage
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Bool?), true)      // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Int?), 3)          // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Int32?), 3)        // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Int64?), 3)        // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Double?), 300000.0)    // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as String?)!, "3.0e+5")
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as String), "3.0e+5")
            // Data extraction: precondition failed: could not convert "3.0e+5" to Data
//                XCTAssertEqual((try fetchValue(db, "noneAffinity") as Data?) == nil)
            return .rollback
        }
        
        // Blob is turned to Blob
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (noneAffinity) VALUES (?)", arguments: ["'fooéı👨👨🏿🇫🇷🇨🇮'".data(using: .utf8)])
            // Check SQLite conversions from Blob storage
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Bool?), false)     // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Int?), 0)          // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Int32?), 0)        // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Int64?), 0)        // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Double?), 0.0)     // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as String?), "'fooéı👨👨🏿🇫🇷🇨🇮'")   // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, "noneAffinity") as Data?), "'fooéı👨👨🏿🇫🇷🇨🇮'".data(using: .utf8))
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
        
        // Int is turned to Integer
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (\(columnName)) VALUES (?)", arguments: [0 as Int])
            // Check SQLite conversions from Integer storage
            XCTAssertEqual((try fetchValue(db, columnName) as Bool?)!, false)
            XCTAssertEqual((try fetchValue(db, columnName) as Bool), false)
            XCTAssertEqual((try fetchValue(db, columnName) as Int?)!, 0)
            XCTAssertEqual((try fetchValue(db, columnName) as Int), 0)
            XCTAssertEqual((try fetchValue(db, columnName) as Int32?)!, Int32(0))
            XCTAssertEqual((try fetchValue(db, columnName) as Int32), Int32(0))
            XCTAssertEqual((try fetchValue(db, columnName) as Int64?)!, Int64(0))
            XCTAssertEqual((try fetchValue(db, columnName) as Int64), Int64(0))
            XCTAssertEqual((try fetchValue(db, columnName) as Double?)!, 0.0)
            XCTAssertEqual((try fetchValue(db, columnName) as Double), 0.0)
            XCTAssertEqual((try fetchValue(db, columnName) as String?), "0")     // incompatible with DatabaseValue conversion
            // Data extraction: precondition failed: could not convert 0 to Data
//                XCTAssertEqual((try fetchValue(db, columnName) as Data?) == nil)
            return .rollback
        }
        
        // Int64 is turned to Integer
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (\(columnName)) VALUES (?)", arguments: [0 as Int64])
            // Check SQLite conversions from Integer storage
            XCTAssertEqual((try fetchValue(db, columnName) as Bool?)!, false)
            XCTAssertEqual((try fetchValue(db, columnName) as Bool), false)
            XCTAssertEqual((try fetchValue(db, columnName) as Int?)!, 0)
            XCTAssertEqual((try fetchValue(db, columnName) as Int), 0)
            XCTAssertEqual((try fetchValue(db, columnName) as Int32?)!, Int32(0))
            XCTAssertEqual((try fetchValue(db, columnName) as Int32), Int32(0))
            XCTAssertEqual((try fetchValue(db, columnName) as Int64?)!, Int64(0))
            XCTAssertEqual((try fetchValue(db, columnName) as Int64), Int64(0))
            XCTAssertEqual((try fetchValue(db, columnName) as Double?)!, 0.0)
            XCTAssertEqual((try fetchValue(db, columnName) as Double), 0.0)
            XCTAssertEqual((try fetchValue(db, columnName) as String?), "0")     // incompatible with DatabaseValue conversion
            // Data extraction: precondition failed: could not convert 0 to Data
//                XCTAssertEqual((try fetchValue(db, columnName) as Data?) == nil)
            return .rollback
        }
        
        // Int32 is turned to Integer
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (\(columnName)) VALUES (?)", arguments: [0 as Int32])
            // Check SQLite conversions from Integer storage
            XCTAssertEqual((try fetchValue(db, columnName) as Bool?)!, false)
            XCTAssertEqual((try fetchValue(db, columnName) as Bool), false)
            XCTAssertEqual((try fetchValue(db, columnName) as Int?)!, 0)
            XCTAssertEqual((try fetchValue(db, columnName) as Int), 0)
            XCTAssertEqual((try fetchValue(db, columnName) as Int32?)!, Int32(0))
            XCTAssertEqual((try fetchValue(db, columnName) as Int32), Int32(0))
            XCTAssertEqual((try fetchValue(db, columnName) as Int64?)!, Int64(0))
            XCTAssertEqual((try fetchValue(db, columnName) as Int64), Int64(0))
            XCTAssertEqual((try fetchValue(db, columnName) as Double?)!, 0.0)
            XCTAssertEqual((try fetchValue(db, columnName) as Double), 0.0)
            XCTAssertEqual((try fetchValue(db, columnName) as String?), "0")     // incompatible with DatabaseValue conversion
            // Data extraction: precondition failed: could not convert 0 to Data
//                XCTAssertEqual((try fetchValue(db, columnName) as Data?) == nil)
            return .rollback
        }
        
        // 3.0e5 Double is turned to Integer
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (\(columnName)) VALUES (?)", arguments: [3.0e5])
            // Check SQLite conversions from Integer storage
            XCTAssertEqual((try fetchValue(db, columnName) as Bool?)!, true)
            XCTAssertEqual((try fetchValue(db, columnName) as Bool), true)
            XCTAssertEqual((try fetchValue(db, columnName) as Int?)!, 300000)
            XCTAssertEqual((try fetchValue(db, columnName) as Int), 300000)
            XCTAssertEqual((try fetchValue(db, columnName) as Int32?)!, Int32(300000))
            XCTAssertEqual((try fetchValue(db, columnName) as Int32), Int32(300000))
            XCTAssertEqual((try fetchValue(db, columnName) as Int64?)!, Int64(300000))
            XCTAssertEqual((try fetchValue(db, columnName) as Int64), Int64(300000))
            XCTAssertEqual((try fetchValue(db, columnName) as Double?)!, Double(300000))
            XCTAssertEqual((try fetchValue(db, columnName) as Double), Double(300000))
            XCTAssertEqual((try fetchValue(db, columnName) as String?), "300000")    // incompatible with DatabaseValue conversion
            // Data extraction: precondition failed: could not convert 300000 to Data
//                XCTAssertEqual((try fetchValue(db, columnName) as Data?) == nil)
            return .rollback
        }
        
        // 1.0e20 Double is turned to Real
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (\(columnName)) VALUES (?)", arguments: [1.0e20])
            // Check SQLite conversions from Real storage (avoid Int, Int32 and Int64 since 1.0e20 does not fit)
            XCTAssertEqual((try fetchValue(db, columnName) as Bool?)!, true)
            XCTAssertEqual((try fetchValue(db, columnName) as Bool), true)
            XCTAssertEqual((try fetchValue(db, columnName) as Double?)!, 1e20)
            XCTAssertEqual((try fetchValue(db, columnName) as Double), 1e20)
            XCTAssertEqual((try fetchValue(db, columnName) as String?), "1.0e+20")   // incompatible with DatabaseValue conversion
            // Data extraction: precondition failed: could not convert 1e+20 to Data
//                XCTAssertEqual((try fetchValue(db, columnName) as Data?) == nil)
            return .rollback
        }
        
        // "3.0e+5" is turned to Integer
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (\(columnName)) VALUES (?)", arguments: ["3.0e+5"])
            // Check SQLite conversions from Integer storage
            XCTAssertEqual((try fetchValue(db, columnName) as Bool?)!, true)
            XCTAssertEqual((try fetchValue(db, columnName) as Bool), true)
            XCTAssertEqual((try fetchValue(db, columnName) as Int?)!, 300000)
            XCTAssertEqual((try fetchValue(db, columnName) as Int), 300000)
            XCTAssertEqual((try fetchValue(db, columnName) as Int32?)!, Int32(300000))
            XCTAssertEqual((try fetchValue(db, columnName) as Int32), Int32(300000))
            XCTAssertEqual((try fetchValue(db, columnName) as Int64?)!, Int64(300000))
            XCTAssertEqual((try fetchValue(db, columnName) as Int64), Int64(300000))
            XCTAssertEqual((try fetchValue(db, columnName) as Double?)!, Double(300000))
            XCTAssertEqual((try fetchValue(db, columnName) as Double), Double(300000))
            XCTAssertEqual((try fetchValue(db, columnName) as String?), "300000")    // incompatible with DatabaseValue conversion
            // Data extraction: precondition failed: could not convert 300000 to Data
//                XCTAssertEqual((try fetchValue(db, columnName) as Data?) == nil)
            return .rollback
        }
        
        // "1.0e+20" is turned to Real
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (\(columnName)) VALUES (?)", arguments: ["1.0e+20"])
            // Check SQLite conversions from Real storage: (avoid Int, Int32 and Int64 since 1.0e20 does not fit)
            XCTAssertEqual((try fetchValue(db, columnName) as Bool?)!, true)
            XCTAssertEqual((try fetchValue(db, columnName) as Bool), true)
            XCTAssertEqual((try fetchValue(db, columnName) as Double?)!, 1e20)
            XCTAssertEqual((try fetchValue(db, columnName) as Double), 1e20)
            XCTAssertEqual((try fetchValue(db, columnName) as String?), "1.0e+20")   // incompatible with DatabaseValue conversion
            // Data extraction: precondition failed: could not convert 1e+20 to Data
//                XCTAssertEqual((try fetchValue(db, columnName) as Data?) == nil)
            return .rollback
        }
        
        // "'fooéı👨👨🏿🇫🇷🇨🇮'" is turned to Text
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (\(columnName)) VALUES (?)", arguments: ["'fooéı👨👨🏿🇫🇷🇨🇮'"])
            // Check SQLite conversions from Text storage:
            XCTAssertEqual((try fetchValue(db, columnName) as Bool?), false)     // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, columnName) as Int?), 0)          // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, columnName) as Int32?), 0)        // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, columnName) as Int64?), 0)        // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, columnName) as Double?), 0.0)     // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, columnName) as String?)!, "'fooéı👨👨🏿🇫🇷🇨🇮'")
            XCTAssertEqual((try fetchValue(db, columnName) as String), "'fooéı👨👨🏿🇫🇷🇨🇮'")
            // Data extraction: precondition failed: could not convert "'fooéı👨👨🏿🇫🇷🇨🇮'" to Data
//                XCTAssertEqual((try fetchValue(db, columnName) as Data?) == nil)
            return .rollback
        }
        
        // Blob is turned to Blob
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (\(columnName)) VALUES (?)", arguments: ["'fooéı👨👨🏿🇫🇷🇨🇮'".data(using: .utf8)])
            // Check SQLite conversions from Blob storage:
            XCTAssertEqual((try fetchValue(db, columnName) as Bool?), false)     // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, columnName) as Int?), 0)          // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, columnName) as Int32?), 0)        // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, columnName) as Int64?), 0)        // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, columnName) as Double?), 0.0)     // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, columnName) as String?), "'fooéı👨👨🏿🇫🇷🇨🇮'")   // incompatible with DatabaseValue conversion
            XCTAssertEqual((try fetchValue(db, columnName) as Data?), "'fooéı👨👨🏿🇫🇷🇨🇮'".data(using: .utf8))
            return .rollback
        }
    }
}

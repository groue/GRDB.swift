import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

enum SQLiteStorageClass {
    case null
    case integer
    case real
    case text
    case blob
}

extension DatabaseValue {
    var storageClass: SQLiteStorageClass {
        switch storage {
        case .null:
            return .null
        case .int64:
            return .integer
        case .double:
            return .real
        case .string:
            return .text
        case .blob:
            return .blob
        }
    }
}

class DatabaseValueConversionTests : GRDBTestCase {
    
    // Datatypes In SQLite Version 3: https://www.sqlite.org/datatype3.html
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createPersons") { db in
            try db.execute("""
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
        
        // Int is turned to Text
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (textAffinity) VALUES (?)", arguments: [0 as Int])
            let dbValue = try Row.fetchOne(db, "SELECT textAffinity FROM `values`")!.first!.1   // first is (columnName, dbValue)
            XCTAssertEqual(dbValue.storageClass, SQLiteStorageClass.text)
            
            // Check GRDB conversions from Text storage:
            XCTAssertTrue(Bool.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Int.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Int32.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Int64.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Double.fromDatabaseValue(dbValue) == nil)
            XCTAssertEqual(String.fromDatabaseValue(dbValue)!, "0")
            XCTAssertTrue(Data.fromDatabaseValue(dbValue) == nil)

            return .rollback
        }
        
        // Int64 is turned to Text
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (textAffinity) VALUES (?)", arguments: [0 as Int64])
            let dbValue = try Row.fetchOne(db, "SELECT textAffinity FROM `values`")!.first!.1   // first is (columnName, dbValue)
            XCTAssertEqual(dbValue.storageClass, SQLiteStorageClass.text)
            
            // Check GRDB conversions from Text storage:
            XCTAssertTrue(Bool.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Int.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Int32.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Int64.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Double.fromDatabaseValue(dbValue) == nil)
            XCTAssertEqual(String.fromDatabaseValue(dbValue)!, "0")
            XCTAssertTrue(Data.fromDatabaseValue(dbValue) == nil)
            
            return .rollback
        }
        
        // Int32 is turned to Text
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (textAffinity) VALUES (?)", arguments: [0 as Int32])
            let dbValue = try Row.fetchOne(db, "SELECT textAffinity FROM `values`")!.first!.1   // first is (columnName, dbValue)
            XCTAssertEqual(dbValue.storageClass, SQLiteStorageClass.text)
            
            // Check GRDB conversions from Text storage:
            XCTAssertTrue(Bool.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Int.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Int32.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Int64.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Double.fromDatabaseValue(dbValue) == nil)
            XCTAssertEqual(String.fromDatabaseValue(dbValue)!, "0")
            XCTAssertTrue(Data.fromDatabaseValue(dbValue) == nil)
            
            return .rollback
        }
        
        // Double is turned to Real
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (textAffinity) VALUES (?)", arguments: [0.0])
            let dbValue = try Row.fetchOne(db, "SELECT textAffinity FROM `values`")!.first!.1   // first is (columnName, dbValue)
            XCTAssertEqual(dbValue.storageClass, SQLiteStorageClass.text)
            
            // Check GRDB conversions from Text storage:
            XCTAssertTrue(Bool.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Int.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Int32.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Int64.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Double.fromDatabaseValue(dbValue) == nil)
            XCTAssertEqual(String.fromDatabaseValue(dbValue)!, "0.0")
            XCTAssertTrue(Data.fromDatabaseValue(dbValue) == nil)
            
            return .rollback
        }
        
        // "3.0e+5" is turned to Text
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (textAffinity) VALUES (?)", arguments: ["3.0e+5"])
            let dbValue = try Row.fetchOne(db, "SELECT textAffinity FROM `values`")!.first!.1   // first is (columnName, dbValue)
            XCTAssertEqual(dbValue.storageClass, SQLiteStorageClass.text)
            
            // Check GRDB conversions from Text storage:
            XCTAssertTrue(Bool.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Int.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Int32.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Int64.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Double.fromDatabaseValue(dbValue) == nil)
            XCTAssertEqual(String.fromDatabaseValue(dbValue)!, "3.0e+5")
            XCTAssertTrue(Data.fromDatabaseValue(dbValue) == nil)

            return .rollback
        }
        
        // "'fooéı👨👨🏿🇫🇷🇨🇮'" is turned to Text
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (textAffinity) VALUES (?)", arguments: ["'fooéı👨👨🏿🇫🇷🇨🇮'"])
            let dbValue = try Row.fetchOne(db, "SELECT textAffinity FROM `values`")!.first!.1   // first is (columnName, dbValue)
            XCTAssertEqual(dbValue.storageClass, SQLiteStorageClass.text)
            
            // Check GRDB conversions from Text storage:
            XCTAssertTrue(Bool.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Int.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Int32.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Int64.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Double.fromDatabaseValue(dbValue) == nil)
            XCTAssertEqual(String.fromDatabaseValue(dbValue)!, "'fooéı👨👨🏿🇫🇷🇨🇮'")
            XCTAssertTrue(Data.fromDatabaseValue(dbValue) == nil)
            
            return .rollback
        }
        
        // Blob is turned to Blob
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (textAffinity) VALUES (?)", arguments: ["'fooéı👨👨🏿🇫🇷🇨🇮'".data(using: .utf8)])
            let dbValue = try Row.fetchOne(db, "SELECT textAffinity FROM `values`")!.first!.1   // first is (columnName, dbValue)
            XCTAssertEqual(dbValue.storageClass, SQLiteStorageClass.blob)
            
            // Check GRDB conversions from Blob storage:
            XCTAssertTrue(Bool.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Int.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Int32.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Int64.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Double.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(String.fromDatabaseValue(dbValue) == nil)
            XCTAssertEqual(Data.fromDatabaseValue(dbValue), "'fooéı👨👨🏿🇫🇷🇨🇮'".data(using: .utf8))
            
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
            let dbValue = try Row.fetchOne(db, "SELECT realAffinity FROM `values`")!.first!.1   // first is (columnName, dbValue)
            XCTAssertEqual(dbValue.storageClass, SQLiteStorageClass.real)
            
            // Check GRDB conversions from Real storage
            XCTAssertEqual(Bool.fromDatabaseValue(dbValue)!, false)
            XCTAssertEqual(Int.fromDatabaseValue(dbValue)!, 0)
            XCTAssertEqual(Int32.fromDatabaseValue(dbValue)!, Int32(0))
            XCTAssertEqual(Int64.fromDatabaseValue(dbValue)!, Int64(0))
            XCTAssertEqual(Double.fromDatabaseValue(dbValue)!, 0.0)
            XCTAssertTrue(String.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Data.fromDatabaseValue(dbValue) == nil)
            
            return .rollback
        }
        
        // Int64 is turned to Real
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (realAffinity) VALUES (?)", arguments: [0 as Int64])
            let dbValue = try Row.fetchOne(db, "SELECT realAffinity FROM `values`")!.first!.1   // first is (columnName, dbValue)
            XCTAssertEqual(dbValue.storageClass, SQLiteStorageClass.real)
            
            // Check GRDB conversions from Real storage
            XCTAssertEqual(Bool.fromDatabaseValue(dbValue)!, false)
            XCTAssertEqual(Int.fromDatabaseValue(dbValue)!, 0)
            XCTAssertEqual(Int32.fromDatabaseValue(dbValue)!, Int32(0))
            XCTAssertEqual(Int64.fromDatabaseValue(dbValue)!, Int64(0))
            XCTAssertEqual(Double.fromDatabaseValue(dbValue)!, 0.0)
            XCTAssertTrue(String.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Data.fromDatabaseValue(dbValue) == nil)
            
            return .rollback
        }
        
        // Int32 is turned to Real
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (realAffinity) VALUES (?)", arguments: [0 as Int32])
            let dbValue = try Row.fetchOne(db, "SELECT realAffinity FROM `values`")!.first!.1   // first is (columnName, dbValue)
            XCTAssertEqual(dbValue.storageClass, SQLiteStorageClass.real)
            
            // Check GRDB conversions from Real storage
            XCTAssertEqual(Bool.fromDatabaseValue(dbValue)!, false)
            XCTAssertEqual(Int.fromDatabaseValue(dbValue)!, 0)
            XCTAssertEqual(Int32.fromDatabaseValue(dbValue)!, Int32(0))
            XCTAssertEqual(Int64.fromDatabaseValue(dbValue)!, Int64(0))
            XCTAssertEqual(Double.fromDatabaseValue(dbValue)!, 0.0)
            XCTAssertTrue(String.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Data.fromDatabaseValue(dbValue) == nil)
            
            return .rollback
        }
        
        // 3.0e5 Double is turned to Real
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (realAffinity) VALUES (?)", arguments: [3.0e5])
            let dbValue = try Row.fetchOne(db, "SELECT realAffinity FROM `values`")!.first!.1   // first is (columnName, dbValue)
            XCTAssertEqual(dbValue.storageClass, SQLiteStorageClass.real)
            
            // Check GRDB conversions from Real storage
            XCTAssertEqual(Bool.fromDatabaseValue(dbValue)!, true)
            XCTAssertEqual(Int.fromDatabaseValue(dbValue)!, 300000)
            XCTAssertEqual(Int32.fromDatabaseValue(dbValue)!, Int32(300000))
            XCTAssertEqual(Int64.fromDatabaseValue(dbValue)!, Int64(300000))
            XCTAssertEqual(Double.fromDatabaseValue(dbValue)!, Double(300000))
            XCTAssertTrue(String.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Data.fromDatabaseValue(dbValue) == nil)
            
            return .rollback
        }
        
        // 1.0e20 Double is turned to Real
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (realAffinity) VALUES (?)", arguments: [1.0e20])
            let dbValue = try Row.fetchOne(db, "SELECT realAffinity FROM `values`")!.first!.1   // first is (columnName, dbValue)
            XCTAssertEqual(dbValue.storageClass, SQLiteStorageClass.real)
            
            // Check GRDB conversions from Real storage (avoid Int, Int32 and Int64 since 1.0e20 does not fit)
            XCTAssertEqual(Bool.fromDatabaseValue(dbValue)!, true)
            XCTAssertEqual(Double.fromDatabaseValue(dbValue)!, 1e20)
            XCTAssertTrue(String.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Data.fromDatabaseValue(dbValue) == nil)

            return .rollback
        }
        
        // "3.0e+5" is turned to Real
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (realAffinity) VALUES (?)", arguments: ["3.0e+5"])
            let dbValue = try Row.fetchOne(db, "SELECT realAffinity FROM `values`")!.first!.1   // first is (columnName, dbValue)
            XCTAssertEqual(dbValue.storageClass, SQLiteStorageClass.real)
            
            // Check GRDB conversions from Real storage
            XCTAssertEqual(Bool.fromDatabaseValue(dbValue)!, true)
            XCTAssertEqual(Int.fromDatabaseValue(dbValue)!, 300000)
            XCTAssertEqual(Int32.fromDatabaseValue(dbValue)!, Int32(300000))
            XCTAssertEqual(Int64.fromDatabaseValue(dbValue)!, Int64(300000))
            XCTAssertEqual(Double.fromDatabaseValue(dbValue)!, Double(300000))
            XCTAssertTrue(String.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Data.fromDatabaseValue(dbValue) == nil)
            
            return .rollback
        }
        
        // "1.0e+20" is turned to Real
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (realAffinity) VALUES (?)", arguments: ["1.0e+20"])
            let dbValue = try Row.fetchOne(db, "SELECT realAffinity FROM `values`")!.first!.1   // first is (columnName, dbValue)
            XCTAssertEqual(dbValue.storageClass, SQLiteStorageClass.real)
            
            // Check GRDB conversions from Real storage: (avoid Int, Int32 and Int64 since 1.0e20 does not fit)
            XCTAssertEqual(Bool.fromDatabaseValue(dbValue)!, true)
            XCTAssertEqual(Double.fromDatabaseValue(dbValue)!, 1e20)
            XCTAssertTrue(String.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Data.fromDatabaseValue(dbValue) == nil)
            
            return .rollback
        }
        
        // "'fooéı👨👨🏿🇫🇷🇨🇮'" is turned to Text
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (realAffinity) VALUES (?)", arguments: ["'fooéı👨👨🏿🇫🇷🇨🇮'"])
            let dbValue = try Row.fetchOne(db, "SELECT realAffinity FROM `values`")!.first!.1   // first is (columnName, dbValue)
            XCTAssertEqual(dbValue.storageClass, SQLiteStorageClass.text)
            
            // Check GRDB conversions from Text storage:
            XCTAssertTrue(Bool.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Int.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Int32.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Int64.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Double.fromDatabaseValue(dbValue) == nil)
            XCTAssertEqual(String.fromDatabaseValue(dbValue)!, "'fooéı👨👨🏿🇫🇷🇨🇮'")
            XCTAssertTrue(Data.fromDatabaseValue(dbValue) == nil)
            
            return .rollback
        }
        
        // Blob is turned to Blob
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (realAffinity) VALUES (?)", arguments: ["'fooéı👨👨🏿🇫🇷🇨🇮'".data(using: .utf8)])
            let dbValue = try Row.fetchOne(db, "SELECT realAffinity FROM `values`")!.first!.1   // first is (columnName, dbValue)
            XCTAssertEqual(dbValue.storageClass, SQLiteStorageClass.blob)
            
            // Check GRDB conversions from Blob storage:
            XCTAssertTrue(Bool.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Int.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Int32.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Int64.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Double.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(String.fromDatabaseValue(dbValue) == nil)
            XCTAssertEqual(Data.fromDatabaseValue(dbValue), "'fooéı👨👨🏿🇫🇷🇨🇮'".data(using: .utf8))
            
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
            let dbValue = try Row.fetchOne(db, "SELECT noneAffinity FROM `values`")!.first!.1   // first is (columnName, dbValue)
            XCTAssertEqual(dbValue.storageClass, SQLiteStorageClass.integer)
            
            // Check GRDB conversions from Integer storage
            XCTAssertEqual(Bool.fromDatabaseValue(dbValue)!, false)
            XCTAssertEqual(Int.fromDatabaseValue(dbValue)!, 0)
            XCTAssertEqual(Int32.fromDatabaseValue(dbValue)!, Int32(0))
            XCTAssertEqual(Int64.fromDatabaseValue(dbValue)!, Int64(0))
            XCTAssertEqual(Double.fromDatabaseValue(dbValue)!, 0.0)
            XCTAssertTrue(String.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Data.fromDatabaseValue(dbValue) == nil)
            
            return .rollback
        }
        
        // Int64 is turned to Integer
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (noneAffinity) VALUES (?)", arguments: [0 as Int64])
            let dbValue = try Row.fetchOne(db, "SELECT noneAffinity FROM `values`")!.first!.1   // first is (columnName, dbValue)
            XCTAssertEqual(dbValue.storageClass, SQLiteStorageClass.integer)
            
            // Check GRDB conversions from Integer storage
            XCTAssertEqual(Bool.fromDatabaseValue(dbValue)!, false)
            XCTAssertEqual(Int.fromDatabaseValue(dbValue)!, 0)
            XCTAssertEqual(Int32.fromDatabaseValue(dbValue)!, Int32(0))
            XCTAssertEqual(Int64.fromDatabaseValue(dbValue)!, Int64(0))
            XCTAssertEqual(Double.fromDatabaseValue(dbValue)!, 0.0)
            XCTAssertTrue(String.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Data.fromDatabaseValue(dbValue) == nil)
            
            return .rollback
        }
        
        // Int32 is turned to Integer
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (noneAffinity) VALUES (?)", arguments: [0 as Int32])
            let dbValue = try Row.fetchOne(db, "SELECT noneAffinity FROM `values`")!.first!.1   // first is (columnName, dbValue)
            XCTAssertEqual(dbValue.storageClass, SQLiteStorageClass.integer)
            
            // Check GRDB conversions from Integer storage
            XCTAssertEqual(Bool.fromDatabaseValue(dbValue)!, false)
            XCTAssertEqual(Int.fromDatabaseValue(dbValue)!, 0)
            XCTAssertEqual(Int32.fromDatabaseValue(dbValue)!, Int32(0))
            XCTAssertEqual(Int64.fromDatabaseValue(dbValue)!, Int64(0))
            XCTAssertEqual(Double.fromDatabaseValue(dbValue)!, 0.0)
            XCTAssertTrue(String.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Data.fromDatabaseValue(dbValue) == nil)
            
            return .rollback
        }
        
        // Double is turned to Real
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (noneAffinity) VALUES (?)", arguments: [0.0])
            let dbValue = try Row.fetchOne(db, "SELECT noneAffinity FROM `values`")!.first!.1   // first is (columnName, dbValue)
            XCTAssertEqual(dbValue.storageClass, SQLiteStorageClass.real)
            
            // Check GRDB conversions from Real storage
            XCTAssertEqual(Bool.fromDatabaseValue(dbValue)!, false)
            XCTAssertEqual(Int.fromDatabaseValue(dbValue)!, 0)
            XCTAssertEqual(Int32.fromDatabaseValue(dbValue)!, Int32(0))
            XCTAssertEqual(Int64.fromDatabaseValue(dbValue)!, Int64(0))
            XCTAssertEqual(Double.fromDatabaseValue(dbValue)!, 0.0)
            XCTAssertTrue(String.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Data.fromDatabaseValue(dbValue) == nil)
            
            return .rollback
        }
        
        // "3.0e+5" is turned to Text
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (noneAffinity) VALUES (?)", arguments: ["3.0e+5"])
            let dbValue = try Row.fetchOne(db, "SELECT noneAffinity FROM `values`")!.first!.1   // first is (columnName, dbValue)
            XCTAssertEqual(dbValue.storageClass, SQLiteStorageClass.text)
            
            // Check GRDB conversions from Text storage
            XCTAssertTrue(Bool.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Int.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Int32.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Int64.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Double.fromDatabaseValue(dbValue) == nil)
            XCTAssertEqual(String.fromDatabaseValue(dbValue)!, "3.0e+5")
            XCTAssertTrue(Data.fromDatabaseValue(dbValue) == nil)
            
            return .rollback
        }
        
        // Blob is turned to Blob
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (noneAffinity) VALUES (?)", arguments: ["'fooéı👨👨🏿🇫🇷🇨🇮'".data(using: .utf8)])
            let dbValue = try Row.fetchOne(db, "SELECT noneAffinity FROM `values`")!.first!.1   // first is (columnName, dbValue)
            XCTAssertEqual(dbValue.storageClass, SQLiteStorageClass.blob)
            
            // Check GRDB conversions from Blob storage
            XCTAssertTrue(Bool.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Int.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Int32.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Int64.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Double.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(String.fromDatabaseValue(dbValue) == nil)
            XCTAssertEqual(Data.fromDatabaseValue(dbValue), "'fooéı👨👨🏿🇫🇷🇨🇮'".data(using: .utf8))
            
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
            let dbValue = try Row.fetchOne(db, "SELECT \(columnName) FROM `values`")!.first!.1   // first is (columnName, dbValue)
            XCTAssertEqual(dbValue.storageClass, SQLiteStorageClass.integer)
            
            // Check GRDB conversions from Integer storage
            XCTAssertEqual(Bool.fromDatabaseValue(dbValue)!, false)
            XCTAssertEqual(Int.fromDatabaseValue(dbValue)!, 0)
            XCTAssertEqual(Int32.fromDatabaseValue(dbValue)!, Int32(0))
            XCTAssertEqual(Int64.fromDatabaseValue(dbValue)!, Int64(0))
            XCTAssertEqual(Double.fromDatabaseValue(dbValue)!, 0.0)
            XCTAssertTrue(String.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Data.fromDatabaseValue(dbValue) == nil)
            
            return .rollback
        }
        
        // Int64 is turned to Integer
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (\(columnName)) VALUES (?)", arguments: [0 as Int64])
            let dbValue = try Row.fetchOne(db, "SELECT \(columnName) FROM `values`")!.first!.1   // first is (columnName, dbValue)
            XCTAssertEqual(dbValue.storageClass, SQLiteStorageClass.integer)
            
            // Check GRDB conversions from Integer storage
            XCTAssertEqual(Bool.fromDatabaseValue(dbValue)!, false)
            XCTAssertEqual(Int.fromDatabaseValue(dbValue)!, 0)
            XCTAssertEqual(Int32.fromDatabaseValue(dbValue)!, Int32(0))
            XCTAssertEqual(Int64.fromDatabaseValue(dbValue)!, Int64(0))
            XCTAssertEqual(Double.fromDatabaseValue(dbValue)!, 0.0)
            XCTAssertTrue(String.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Data.fromDatabaseValue(dbValue) == nil)
            
            return .rollback
        }
        
        // Int32 is turned to Integer
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (\(columnName)) VALUES (?)", arguments: [0 as Int32])
            let dbValue = try Row.fetchOne(db, "SELECT \(columnName) FROM `values`")!.first!.1   // first is (columnName, dbValue)
            XCTAssertEqual(dbValue.storageClass, SQLiteStorageClass.integer)
            
            // Check GRDB conversions from Integer storage
            XCTAssertEqual(Bool.fromDatabaseValue(dbValue)!, false)
            XCTAssertEqual(Int.fromDatabaseValue(dbValue)!, 0)
            XCTAssertEqual(Int32.fromDatabaseValue(dbValue)!, Int32(0))
            XCTAssertEqual(Int64.fromDatabaseValue(dbValue)!, Int64(0))
            XCTAssertEqual(Double.fromDatabaseValue(dbValue)!, 0.0)
            XCTAssertTrue(String.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Data.fromDatabaseValue(dbValue) == nil)
            
            return .rollback
        }
        
        // 3.0e5 Double is turned to Integer
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (\(columnName)) VALUES (?)", arguments: [3.0e5])
            let dbValue = try Row.fetchOne(db, "SELECT \(columnName) FROM `values`")!.first!.1   // first is (columnName, dbValue)
            XCTAssertEqual(dbValue.storageClass, SQLiteStorageClass.integer)
            
            // Check GRDB conversions from Integer storage
            XCTAssertEqual(Bool.fromDatabaseValue(dbValue)!, true)
            XCTAssertEqual(Int.fromDatabaseValue(dbValue)!, 300000)
            XCTAssertEqual(Int32.fromDatabaseValue(dbValue)!, Int32(300000))
            XCTAssertEqual(Int64.fromDatabaseValue(dbValue)!, Int64(300000))
            XCTAssertEqual(Double.fromDatabaseValue(dbValue)!, Double(300000))
            XCTAssertTrue(String.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Data.fromDatabaseValue(dbValue) == nil)
            
            return .rollback
        }
        
        // 1.0e20 Double is turned to Real
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (\(columnName)) VALUES (?)", arguments: [1.0e20])
            let dbValue = try Row.fetchOne(db, "SELECT \(columnName) FROM `values`")!.first!.1   // first is (columnName, dbValue)
            XCTAssertEqual(dbValue.storageClass, SQLiteStorageClass.real)
            
            // Check GRDB conversions from Real storage (avoid Int, Int32 and Int64 since 1.0e20 does not fit)
            XCTAssertEqual(Bool.fromDatabaseValue(dbValue)!, true)
            XCTAssertEqual(Double.fromDatabaseValue(dbValue)!, 1e20)
            XCTAssertTrue(String.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Data.fromDatabaseValue(dbValue) == nil)
            
            return .rollback
        }
        
        // "3.0e+5" is turned to Integer
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (\(columnName)) VALUES (?)", arguments: ["3.0e+5"])
            let dbValue = try Row.fetchOne(db, "SELECT \(columnName) FROM `values`")!.first!.1   // first is (columnName, dbValue)
            XCTAssertEqual(dbValue.storageClass, SQLiteStorageClass.integer)
            
            // Check GRDB conversions from Integer storage
            XCTAssertEqual(Bool.fromDatabaseValue(dbValue)!, true)
            XCTAssertEqual(Int.fromDatabaseValue(dbValue)!, 300000)
            XCTAssertEqual(Int32.fromDatabaseValue(dbValue)!, Int32(300000))
            XCTAssertEqual(Int64.fromDatabaseValue(dbValue)!, Int64(300000))
            XCTAssertEqual(Double.fromDatabaseValue(dbValue)!, Double(300000))
            XCTAssertTrue(String.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Data.fromDatabaseValue(dbValue) == nil)
            
            return .rollback
        }
        
        // "1.0e+20" is turned to Real
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (\(columnName)) VALUES (?)", arguments: ["1.0e+20"])
            let dbValue = try Row.fetchOne(db, "SELECT \(columnName) FROM `values`")!.first!.1   // first is (columnName, dbValue)
            XCTAssertEqual(dbValue.storageClass, SQLiteStorageClass.real)
            
            // Check GRDB conversions from Real storage: (avoid Int, Int32 and Int64 since 1.0e20 does not fit)
            XCTAssertEqual(Bool.fromDatabaseValue(dbValue)!, true)
            XCTAssertEqual(Double.fromDatabaseValue(dbValue)!, 1e20)
            XCTAssertTrue(String.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Data.fromDatabaseValue(dbValue) == nil)
            
            return .rollback
        }
        
        // "'fooéı👨👨🏿🇫🇷🇨🇮'" is turned to Text
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (\(columnName)) VALUES (?)", arguments: ["'fooéı👨👨🏿🇫🇷🇨🇮'"])
            let dbValue = try Row.fetchOne(db, "SELECT \(columnName) FROM `values`")!.first!.1   // first is (columnName, dbValue)
            XCTAssertEqual(dbValue.storageClass, SQLiteStorageClass.text)
            
            // Check GRDB conversions from Text storage:
            XCTAssertTrue(Bool.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Int.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Int32.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Int64.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Double.fromDatabaseValue(dbValue) == nil)
            XCTAssertEqual(String.fromDatabaseValue(dbValue)!, "'fooéı👨👨🏿🇫🇷🇨🇮'")
            XCTAssertTrue(Data.fromDatabaseValue(dbValue) == nil)
            
            return .rollback
        }
        
        // Blob is turned to Blob
        
        try dbQueue.inTransaction { db in
            try db.execute("INSERT INTO `values` (\(columnName)) VALUES (?)", arguments: ["'fooéı👨👨🏿🇫🇷🇨🇮'".data(using: .utf8)])
            let dbValue = try Row.fetchOne(db, "SELECT \(columnName) FROM `values`")!.first!.1   // first is (columnName, dbValue)
            XCTAssertEqual(dbValue.storageClass, SQLiteStorageClass.blob)
            
            // Check GRDB conversions from Blob storage:
            XCTAssertTrue(Bool.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Int.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Int32.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Int64.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(Double.fromDatabaseValue(dbValue) == nil)
            XCTAssertTrue(String.fromDatabaseValue(dbValue) == nil)
            XCTAssertEqual(Data.fromDatabaseValue(dbValue), "'fooéı👨👨🏿🇫🇷🇨🇮'".data(using: .utf8))
            
            return .rollback
        }
    }
}

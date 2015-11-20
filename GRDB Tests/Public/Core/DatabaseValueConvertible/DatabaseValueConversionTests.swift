import XCTest
import GRDB

enum SQLiteStorageClass {
    case Null
    case Integer
    case Real
    case Text
    case Blob
}

extension DatabaseValue {
    var storageClass: SQLiteStorageClass {
        switch storage {
        case .Null:
            return .Null
        case .Int64:
            return .Integer
        case .Double:
            return .Real
        case .String:
            return .Text
        case .Blob:
            return .Blob
        }
    }
}

class DatabaseValueConversionTests : GRDBTestCase {
    
    // Datatypes In SQLite Version 3: https://www.sqlite.org/datatype3.html
    
    override func setUp() {
        super.setUp()
        
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
        
        assertNoError {
            try migrator.migrate(dbQueue)
        }
    }
    
    func testTextAffinity() {
        // https://www.sqlite.org/datatype3.html
        //
        // > A column with TEXT affinity stores all data using storage classes
        // > NULL, TEXT or BLOB. If numerical data is inserted into a column
        // > with TEXT affinity it is converted into text form before being
        // > stored.
        
        assertNoError {
            
            // Int is turned to Text
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (textAffinity) VALUES (?)", arguments: [0 as Int])
                let dbv = Row.fetchOne(db, "SELECT textAffinity FROM `values`")!.first!.1   // first is (columnName, dbv)
                XCTAssertEqual(dbv.storageClass, SQLiteStorageClass.Text)
                
                // Check GRDB conversions from Text storage:
                XCTAssertTrue((dbv.value() as Bool?) == nil)
                XCTAssertTrue((dbv.value() as Int?) == nil)
                XCTAssertTrue((dbv.value() as Int32?) == nil)
                XCTAssertTrue((dbv.value() as Int64?) == nil)
                XCTAssertTrue((dbv.value() as Double?) == nil)
                XCTAssertEqual((dbv.value() as String?)!, "0")
                XCTAssertEqual((dbv.value() as String), "0")
                XCTAssertTrue((dbv.value() as NSData?) == nil)
                
                return .Rollback
            }
            
            // Int64 is turned to Text
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (textAffinity) VALUES (?)", arguments: [0 as Int64])
                let dbv = Row.fetchOne(db, "SELECT textAffinity FROM `values`")!.first!.1   // first is (columnName, dbv)
                XCTAssertEqual(dbv.storageClass, SQLiteStorageClass.Text)
                
                // Check GRDB conversions from Text storage:
                XCTAssertTrue((dbv.value() as Bool?) == nil)
                XCTAssertTrue((dbv.value() as Int?) == nil)
                XCTAssertTrue((dbv.value() as Int32?) == nil)
                XCTAssertTrue((dbv.value() as Int64?) == nil)
                XCTAssertTrue((dbv.value() as Double?) == nil)
                XCTAssertEqual((dbv.value() as String?)!, "0")
                XCTAssertEqual((dbv.value() as String), "0")
                XCTAssertTrue((dbv.value() as NSData?) == nil)
                
                return .Rollback
            }
            
            // Int32 is turned to Text
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (textAffinity) VALUES (?)", arguments: [0 as Int32])
                let dbv = Row.fetchOne(db, "SELECT textAffinity FROM `values`")!.first!.1   // first is (columnName, dbv)
                XCTAssertEqual(dbv.storageClass, SQLiteStorageClass.Text)
                
                // Check GRDB conversions from Text storage:
                XCTAssertTrue((dbv.value() as Bool?) == nil)
                XCTAssertTrue((dbv.value() as Int?) == nil)
                XCTAssertTrue((dbv.value() as Int32?) == nil)
                XCTAssertTrue((dbv.value() as Int64?) == nil)
                XCTAssertTrue((dbv.value() as Double?) == nil)
                XCTAssertEqual((dbv.value() as String?)!, "0")
                XCTAssertEqual((dbv.value() as String), "0")
                XCTAssertTrue((dbv.value() as NSData?) == nil)
                
                return .Rollback
            }
            
            // Double is turned to Real
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (textAffinity) VALUES (?)", arguments: [0.0])
                let dbv = Row.fetchOne(db, "SELECT textAffinity FROM `values`")!.first!.1   // first is (columnName, dbv)
                XCTAssertEqual(dbv.storageClass, SQLiteStorageClass.Text)
                
                // Check GRDB conversions from Text storage:
                XCTAssertTrue((dbv.value() as Bool?) == nil)
                XCTAssertTrue((dbv.value() as Int?) == nil)
                XCTAssertTrue((dbv.value() as Int32?) == nil)
                XCTAssertTrue((dbv.value() as Int64?) == nil)
                XCTAssertTrue((dbv.value() as Double?) == nil)
                XCTAssertEqual((dbv.value() as String?)!, "0.0")
                XCTAssertEqual((dbv.value() as String), "0.0")
                XCTAssertTrue((dbv.value() as NSData?) == nil)
                
                return .Rollback
            }
            
            // "3.0e+5" is turned to Text
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (textAffinity) VALUES (?)", arguments: ["3.0e+5"])
                let dbv = Row.fetchOne(db, "SELECT textAffinity FROM `values`")!.first!.1   // first is (columnName, dbv)
                XCTAssertEqual(dbv.storageClass, SQLiteStorageClass.Text)
                
                // Check GRDB conversions from Text storage:
                XCTAssertTrue((dbv.value() as Bool?) == nil)
                XCTAssertTrue((dbv.value() as Int?) == nil)
                XCTAssertTrue((dbv.value() as Int32?) == nil)
                XCTAssertTrue((dbv.value() as Int64?) == nil)
                XCTAssertTrue((dbv.value() as Double?) == nil)
                XCTAssertEqual((dbv.value() as String?)!, "3.0e+5")
                XCTAssertEqual((dbv.value() as String), "3.0e+5")
                XCTAssertTrue((dbv.value() as NSData?) == nil)
                
                return .Rollback
            }
            
            // "foo" is turned to Text
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (textAffinity) VALUES (?)", arguments: ["foo"])
                let dbv = Row.fetchOne(db, "SELECT textAffinity FROM `values`")!.first!.1   // first is (columnName, dbv)
                XCTAssertEqual(dbv.storageClass, SQLiteStorageClass.Text)
                
                // Check GRDB conversions from Text storage:
                XCTAssertTrue((dbv.value() as Bool?) == nil)
                XCTAssertTrue((dbv.value() as Int?) == nil)
                XCTAssertTrue((dbv.value() as Int32?) == nil)
                XCTAssertTrue((dbv.value() as Int64?) == nil)
                XCTAssertTrue((dbv.value() as Double?) == nil)
                XCTAssertEqual((dbv.value() as String?)!, "foo")
                XCTAssertEqual((dbv.value() as String), "foo")
                XCTAssertTrue((dbv.value() as NSData?) == nil)
                
                return .Rollback
            }
            
            // Blob is turned to Blob
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (textAffinity) VALUES (?)", arguments: ["foo".dataUsingEncoding(NSUTF8StringEncoding)])
                let dbv = Row.fetchOne(db, "SELECT textAffinity FROM `values`")!.first!.1   // first is (columnName, dbv)
                XCTAssertEqual(dbv.storageClass, SQLiteStorageClass.Blob)
                
                // Check GRDB conversions from Blob storage:
                XCTAssertTrue((dbv.value() as Bool?) == nil)
                XCTAssertTrue((dbv.value() as Int?) == nil)
                XCTAssertTrue((dbv.value() as Int32?) == nil)
                XCTAssertTrue((dbv.value() as Int64?) == nil)
                XCTAssertTrue((dbv.value() as Double?) == nil)
                XCTAssertTrue((dbv.value() as String?) == nil)
                XCTAssertEqual((dbv.value() as NSData?), "foo".dataUsingEncoding(NSUTF8StringEncoding))
                
                return .Rollback
            }
        }
    }

    func testNumericAffinity() {
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

        testNumericAffinity("numericAffinity")
    }
    
    func testIntegerAffinity() {
        // https://www.sqlite.org/datatype3.html
        //
        // > A column that uses INTEGER affinity behaves the same as a column
        // > with NUMERIC affinity. The difference between INTEGER and NUMERIC
        // > affinity is only evident in a CAST expression.
        
        testNumericAffinity("integerAffinity")
    }
    
    func testRealAffinity() {
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
        
        assertNoError {
            
            // Int is turned to Real
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (realAffinity) VALUES (?)", arguments: [0 as Int])
                let dbv = Row.fetchOne(db, "SELECT realAffinity FROM `values`")!.first!.1   // first is (columnName, dbv)
                XCTAssertEqual(dbv.storageClass, SQLiteStorageClass.Real)
                
                // Check GRDB conversions from Real storage
                XCTAssertEqual((dbv.value() as Bool?)!, false)
                XCTAssertEqual((dbv.value() as Bool), false)
                XCTAssertEqual((dbv.value() as Int?)!, 0)
                XCTAssertEqual((dbv.value() as Int), 0)
                XCTAssertEqual((dbv.value() as Int32?)!, Int32(0))
                XCTAssertEqual((dbv.value() as Int32), Int32(0))
                XCTAssertEqual((dbv.value() as Int64?)!, Int64(0))
                XCTAssertEqual((dbv.value() as Int64), Int64(0))
                XCTAssertEqual((dbv.value() as Double?)!, 0.0)
                XCTAssertEqual((dbv.value() as Double), 0.0)
                XCTAssertTrue((dbv.value() as String?) == nil)
                XCTAssertTrue((dbv.value() as NSData?) == nil)
                
                return .Rollback
            }
            
            // Int64 is turned to Real
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (realAffinity) VALUES (?)", arguments: [0 as Int64])
                let dbv = Row.fetchOne(db, "SELECT realAffinity FROM `values`")!.first!.1   // first is (columnName, dbv)
                XCTAssertEqual(dbv.storageClass, SQLiteStorageClass.Real)
                
                // Check GRDB conversions from Real storage
                XCTAssertEqual((dbv.value() as Bool?)!, false)
                XCTAssertEqual((dbv.value() as Bool), false)
                XCTAssertEqual((dbv.value() as Int?)!, 0)
                XCTAssertEqual((dbv.value() as Int), 0)
                XCTAssertEqual((dbv.value() as Int32?)!, Int32(0))
                XCTAssertEqual((dbv.value() as Int32), Int32(0))
                XCTAssertEqual((dbv.value() as Int64?)!, Int64(0))
                XCTAssertEqual((dbv.value() as Int64), Int64(0))
                XCTAssertEqual((dbv.value() as Double?)!, 0.0)
                XCTAssertEqual((dbv.value() as Double), 0.0)
                XCTAssertTrue((dbv.value() as String?) == nil)
                XCTAssertTrue((dbv.value() as NSData?) == nil)
                
                return .Rollback
            }
            
            // Int32 is turned to Real
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (realAffinity) VALUES (?)", arguments: [0 as Int32])
                let dbv = Row.fetchOne(db, "SELECT realAffinity FROM `values`")!.first!.1   // first is (columnName, dbv)
                XCTAssertEqual(dbv.storageClass, SQLiteStorageClass.Real)
                
                // Check GRDB conversions from Real storage
                XCTAssertEqual((dbv.value() as Bool?)!, false)
                XCTAssertEqual((dbv.value() as Bool), false)
                XCTAssertEqual((dbv.value() as Int?)!, 0)
                XCTAssertEqual((dbv.value() as Int), 0)
                XCTAssertEqual((dbv.value() as Int32?)!, Int32(0))
                XCTAssertEqual((dbv.value() as Int32), Int32(0))
                XCTAssertEqual((dbv.value() as Int64?)!, Int64(0))
                XCTAssertEqual((dbv.value() as Int64), Int64(0))
                XCTAssertEqual((dbv.value() as Double?)!, 0.0)
                XCTAssertEqual((dbv.value() as Double), 0.0)
                XCTAssertTrue((dbv.value() as String?) == nil)
                XCTAssertTrue((dbv.value() as NSData?) == nil)
                
                return .Rollback
            }
            
            // 3.0e5 Double is turned to Real
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (realAffinity) VALUES (?)", arguments: [3.0e5])
                let dbv = Row.fetchOne(db, "SELECT realAffinity FROM `values`")!.first!.1   // first is (columnName, dbv)
                XCTAssertEqual(dbv.storageClass, SQLiteStorageClass.Real)
                
                // Check GRDB conversions from Real storage
                XCTAssertEqual((dbv.value() as Bool?)!, true)
                XCTAssertEqual((dbv.value() as Bool), true)
                XCTAssertEqual((dbv.value() as Int?)!, 300000)
                XCTAssertEqual((dbv.value() as Int), 300000)
                XCTAssertEqual((dbv.value() as Int32?)!, Int32(300000))
                XCTAssertEqual((dbv.value() as Int32), Int32(300000))
                XCTAssertEqual((dbv.value() as Int64?)!, Int64(300000))
                XCTAssertEqual((dbv.value() as Int64), Int64(300000))
                XCTAssertEqual((dbv.value() as Double?)!, Double(300000))
                XCTAssertEqual((dbv.value() as Double), Double(300000))
                XCTAssertTrue((dbv.value() as String?) == nil)
                XCTAssertTrue((dbv.value() as NSData?) == nil)
                
                return .Rollback
            }
            
            // 1.0e20 Double is turned to Real
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (realAffinity) VALUES (?)", arguments: [1.0e20])
                let dbv = Row.fetchOne(db, "SELECT realAffinity FROM `values`")!.first!.1   // first is (columnName, dbv)
                XCTAssertEqual(dbv.storageClass, SQLiteStorageClass.Real)
                
                // Check GRDB conversions from Real storage (avoid Int, Int32 and Int64 since 1.0e20 does not fit)
                XCTAssertEqual((dbv.value() as Bool?)!, true)
                XCTAssertEqual((dbv.value() as Bool), true)
                XCTAssertEqual((dbv.value() as Double?)!, 1e20)
                XCTAssertEqual((dbv.value() as Double), 1e20)
                XCTAssertTrue((dbv.value() as String?) == nil)
                XCTAssertTrue((dbv.value() as NSData?) == nil)
                
                return .Rollback
            }
            
            // "3.0e+5" is turned to Real
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (realAffinity) VALUES (?)", arguments: ["3.0e+5"])
                let dbv = Row.fetchOne(db, "SELECT realAffinity FROM `values`")!.first!.1   // first is (columnName, dbv)
                XCTAssertEqual(dbv.storageClass, SQLiteStorageClass.Real)
                
                // Check GRDB conversions from Real storage
                XCTAssertEqual((dbv.value() as Bool?)!, true)
                XCTAssertEqual((dbv.value() as Bool), true)
                XCTAssertEqual((dbv.value() as Int?)!, 300000)
                XCTAssertEqual((dbv.value() as Int), 300000)
                XCTAssertEqual((dbv.value() as Int32?)!, Int32(300000))
                XCTAssertEqual((dbv.value() as Int32), Int32(300000))
                XCTAssertEqual((dbv.value() as Int64?)!, Int64(300000))
                XCTAssertEqual((dbv.value() as Int64), Int64(300000))
                XCTAssertEqual((dbv.value() as Double?)!, Double(300000))
                XCTAssertEqual((dbv.value() as Double), Double(300000))
                XCTAssertTrue((dbv.value() as String?) == nil)
                XCTAssertTrue((dbv.value() as NSData?) == nil)
                
                return .Rollback
            }
            
            // "1.0e+20" is turned to Real
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (realAffinity) VALUES (?)", arguments: ["1.0e+20"])
                let dbv = Row.fetchOne(db, "SELECT realAffinity FROM `values`")!.first!.1   // first is (columnName, dbv)
                XCTAssertEqual(dbv.storageClass, SQLiteStorageClass.Real)
                
                // Check GRDB conversions from Real storage: (avoid Int, Int32 and Int64 since 1.0e20 does not fit)
                XCTAssertEqual((dbv.value() as Bool?)!, true)
                XCTAssertEqual((dbv.value() as Bool), true)
                XCTAssertEqual((dbv.value() as Double?)!, 1e20)
                XCTAssertEqual((dbv.value() as Double), 1e20)
                XCTAssertTrue((dbv.value() as String?) == nil)
                XCTAssertTrue((dbv.value() as NSData?) == nil)
                
                return .Rollback
            }
            
            // "foo" is turned to Text
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (realAffinity) VALUES (?)", arguments: ["foo"])
                let dbv = Row.fetchOne(db, "SELECT realAffinity FROM `values`")!.first!.1   // first is (columnName, dbv)
                XCTAssertEqual(dbv.storageClass, SQLiteStorageClass.Text)
                
                // Check GRDB conversions from Text storage:
                XCTAssertTrue((dbv.value() as Bool?) == nil)
                XCTAssertTrue((dbv.value() as Int?) == nil)
                XCTAssertTrue((dbv.value() as Int32?) == nil)
                XCTAssertTrue((dbv.value() as Int64?) == nil)
                XCTAssertTrue((dbv.value() as Double?) == nil)
                XCTAssertEqual((dbv.value() as String?)!, "foo")
                XCTAssertEqual((dbv.value() as String), "foo")
                XCTAssertTrue((dbv.value() as NSData?) == nil)
                
                return .Rollback
            }
            
            // Blob is turned to Blob
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (realAffinity) VALUES (?)", arguments: ["foo".dataUsingEncoding(NSUTF8StringEncoding)])
                let dbv = Row.fetchOne(db, "SELECT realAffinity FROM `values`")!.first!.1   // first is (columnName, dbv)
                XCTAssertEqual(dbv.storageClass, SQLiteStorageClass.Blob)
                
                // Check GRDB conversions from Blob storage:
                XCTAssertTrue((dbv.value() as Bool?) == nil)
                XCTAssertTrue((dbv.value() as Int?) == nil)
                XCTAssertTrue((dbv.value() as Int32?) == nil)
                XCTAssertTrue((dbv.value() as Int64?) == nil)
                XCTAssertTrue((dbv.value() as Double?) == nil)
                XCTAssertTrue((dbv.value() as String?) == nil)
                XCTAssertEqual((dbv.value() as NSData?), "foo".dataUsingEncoding(NSUTF8StringEncoding))
                
                return .Rollback
            }
        }
    }
    
    func testNoneAffinity() {
        // https://www.sqlite.org/datatype3.html
        //
        // > A column with affinity NONE does not prefer one storage class over
        // > another and no attempt is made to coerce data from one storage
        // > class into another.
        
        assertNoError {
            
            // Int is turned to Integer
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (noneAffinity) VALUES (?)", arguments: [0 as Int])
                let dbv = Row.fetchOne(db, "SELECT noneAffinity FROM `values`")!.first!.1   // first is (columnName, dbv)
                XCTAssertEqual(dbv.storageClass, SQLiteStorageClass.Integer)
                
                // Check GRDB conversions from Integer storage
                XCTAssertEqual((dbv.value() as Bool?)!, false)
                XCTAssertEqual((dbv.value() as Bool), false)
                XCTAssertEqual((dbv.value() as Int?)!, 0)
                XCTAssertEqual((dbv.value() as Int), 0)
                XCTAssertEqual((dbv.value() as Int32?)!, Int32(0))
                XCTAssertEqual((dbv.value() as Int32), Int32(0))
                XCTAssertEqual((dbv.value() as Int64?)!, Int64(0))
                XCTAssertEqual((dbv.value() as Int64), Int64(0))
                XCTAssertEqual((dbv.value() as Double?)!, 0.0)
                XCTAssertEqual((dbv.value() as Double), 0.0)
                XCTAssertTrue((dbv.value() as String?) == nil)
                XCTAssertTrue((dbv.value() as NSData?) == nil)
                
                return .Rollback
            }
            
            // Int64 is turned to Integer
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (noneAffinity) VALUES (?)", arguments: [0 as Int64])
                let dbv = Row.fetchOne(db, "SELECT noneAffinity FROM `values`")!.first!.1   // first is (columnName, dbv)
                XCTAssertEqual(dbv.storageClass, SQLiteStorageClass.Integer)
                
                // Check GRDB conversions from Integer storage
                XCTAssertEqual((dbv.value() as Bool?)!, false)
                XCTAssertEqual((dbv.value() as Bool), false)
                XCTAssertEqual((dbv.value() as Int?)!, 0)
                XCTAssertEqual((dbv.value() as Int), 0)
                XCTAssertEqual((dbv.value() as Int32?)!, Int32(0))
                XCTAssertEqual((dbv.value() as Int32), Int32(0))
                XCTAssertEqual((dbv.value() as Int64?)!, Int64(0))
                XCTAssertEqual((dbv.value() as Int64), Int64(0))
                XCTAssertEqual((dbv.value() as Double?)!, 0.0)
                XCTAssertEqual((dbv.value() as Double), 0.0)
                XCTAssertTrue((dbv.value() as String?) == nil)
                XCTAssertTrue((dbv.value() as NSData?) == nil)
                
                return .Rollback
            }
            
            // Int32 is turned to Integer
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (noneAffinity) VALUES (?)", arguments: [0 as Int32])
                let dbv = Row.fetchOne(db, "SELECT noneAffinity FROM `values`")!.first!.1   // first is (columnName, dbv)
                XCTAssertEqual(dbv.storageClass, SQLiteStorageClass.Integer)
                
                // Check GRDB conversions from Integer storage
                XCTAssertEqual((dbv.value() as Bool?)!, false)
                XCTAssertEqual((dbv.value() as Bool), false)
                XCTAssertEqual((dbv.value() as Int?)!, 0)
                XCTAssertEqual((dbv.value() as Int), 0)
                XCTAssertEqual((dbv.value() as Int32?)!, Int32(0))
                XCTAssertEqual((dbv.value() as Int32), Int32(0))
                XCTAssertEqual((dbv.value() as Int64?)!, Int64(0))
                XCTAssertEqual((dbv.value() as Int64), Int64(0))
                XCTAssertEqual((dbv.value() as Double?)!, 0.0)
                XCTAssertEqual((dbv.value() as Double), 0.0)
                XCTAssertTrue((dbv.value() as String?) == nil)
                XCTAssertTrue((dbv.value() as NSData?) == nil)
                
                return .Rollback
            }
            
            // Double is turned to Real
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (noneAffinity) VALUES (?)", arguments: [0.0])
                let dbv = Row.fetchOne(db, "SELECT noneAffinity FROM `values`")!.first!.1   // first is (columnName, dbv)
                XCTAssertEqual(dbv.storageClass, SQLiteStorageClass.Real)
                
                // Check GRDB conversions from Real storage
                XCTAssertEqual((dbv.value() as Bool?)!, false)
                XCTAssertEqual((dbv.value() as Bool), false)
                XCTAssertEqual((dbv.value() as Int?)!, 0)
                XCTAssertEqual((dbv.value() as Int), 0)
                XCTAssertEqual((dbv.value() as Int32?)!, Int32(0))
                XCTAssertEqual((dbv.value() as Int32), Int32(0))
                XCTAssertEqual((dbv.value() as Int64?)!, Int64(0))
                XCTAssertEqual((dbv.value() as Int64), Int64(0))
                XCTAssertEqual((dbv.value() as Double?)!, 0.0)
                XCTAssertEqual((dbv.value() as Double), 0.0)
                XCTAssertTrue((dbv.value() as String?) == nil)
                XCTAssertTrue((dbv.value() as NSData?) == nil)
                
                return .Rollback
            }
            
            // "3.0e+5" is turned to Text
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (noneAffinity) VALUES (?)", arguments: ["3.0e+5"])
                let dbv = Row.fetchOne(db, "SELECT noneAffinity FROM `values`")!.first!.1   // first is (columnName, dbv)
                XCTAssertEqual(dbv.storageClass, SQLiteStorageClass.Text)
                
                // Check GRDB conversions from Text storage
                XCTAssertTrue((dbv.value() as Bool?) == nil)
                XCTAssertTrue((dbv.value() as Int?) == nil)
                XCTAssertTrue((dbv.value() as Int32?) == nil)
                XCTAssertTrue((dbv.value() as Int64?) == nil)
                XCTAssertTrue((dbv.value() as Double?) == nil)
                XCTAssertEqual((dbv.value() as String?)!, "3.0e+5")
                XCTAssertEqual((dbv.value() as String), "3.0e+5")
                XCTAssertTrue((dbv.value() as NSData?) == nil)
                
                return .Rollback
            }
            
            // Blob is turned to Blob
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (noneAffinity) VALUES (?)", arguments: ["foo".dataUsingEncoding(NSUTF8StringEncoding)])
                let dbv = Row.fetchOne(db, "SELECT noneAffinity FROM `values`")!.first!.1   // first is (columnName, dbv)
                XCTAssertEqual(dbv.storageClass, SQLiteStorageClass.Blob)
                
                // Check GRDB conversions from Blob storage
                XCTAssertTrue((dbv.value() as Bool?) == nil)
                XCTAssertTrue((dbv.value() as Int?) == nil)
                XCTAssertTrue((dbv.value() as Int32?) == nil)
                XCTAssertTrue((dbv.value() as Int64?) == nil)
                XCTAssertTrue((dbv.value() as Double?) == nil)
                XCTAssertTrue((dbv.value() as String?) == nil)
                XCTAssertEqual((dbv.value() as NSData?), "foo".dataUsingEncoding(NSUTF8StringEncoding))
                
                return .Rollback
            }
        }
    }
    
    func testNumericAffinity(columnName: String) {
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
        
        assertNoError {
            
            // Int is turned to Integer
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (\(columnName)) VALUES (?)", arguments: [0 as Int])
                let dbv = Row.fetchOne(db, "SELECT \(columnName) FROM `values`")!.first!.1   // first is (columnName, dbv)
                XCTAssertEqual(dbv.storageClass, SQLiteStorageClass.Integer)
                
                // Check GRDB conversions from Integer storage
                XCTAssertEqual((dbv.value() as Bool?)!, false)
                XCTAssertEqual((dbv.value() as Bool), false)
                XCTAssertEqual((dbv.value() as Int?)!, 0)
                XCTAssertEqual((dbv.value() as Int), 0)
                XCTAssertEqual((dbv.value() as Int32?)!, Int32(0))
                XCTAssertEqual((dbv.value() as Int32), Int32(0))
                XCTAssertEqual((dbv.value() as Int64?)!, Int64(0))
                XCTAssertEqual((dbv.value() as Int64), Int64(0))
                XCTAssertEqual((dbv.value() as Double?)!, 0.0)
                XCTAssertEqual((dbv.value() as Double), 0.0)
                XCTAssertTrue((dbv.value() as String?) == nil)
                XCTAssertTrue((dbv.value() as NSData?) == nil)
                
                return .Rollback
            }
            
            // Int64 is turned to Integer
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (\(columnName)) VALUES (?)", arguments: [0 as Int64])
                let dbv = Row.fetchOne(db, "SELECT \(columnName) FROM `values`")!.first!.1   // first is (columnName, dbv)
                XCTAssertEqual(dbv.storageClass, SQLiteStorageClass.Integer)
                
                // Check GRDB conversions from Integer storage
                XCTAssertEqual((dbv.value() as Bool?)!, false)
                XCTAssertEqual((dbv.value() as Bool), false)
                XCTAssertEqual((dbv.value() as Int?)!, 0)
                XCTAssertEqual((dbv.value() as Int), 0)
                XCTAssertEqual((dbv.value() as Int32?)!, Int32(0))
                XCTAssertEqual((dbv.value() as Int32), Int32(0))
                XCTAssertEqual((dbv.value() as Int64?)!, Int64(0))
                XCTAssertEqual((dbv.value() as Int64), Int64(0))
                XCTAssertEqual((dbv.value() as Double?)!, 0.0)
                XCTAssertEqual((dbv.value() as Double), 0.0)
                XCTAssertTrue((dbv.value() as String?) == nil)
                XCTAssertTrue((dbv.value() as NSData?) == nil)
                
                return .Rollback
            }
            
            // Int32 is turned to Integer
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (\(columnName)) VALUES (?)", arguments: [0 as Int32])
                let dbv = Row.fetchOne(db, "SELECT \(columnName) FROM `values`")!.first!.1   // first is (columnName, dbv)
                XCTAssertEqual(dbv.storageClass, SQLiteStorageClass.Integer)
                
                // Check GRDB conversions from Integer storage
                XCTAssertEqual((dbv.value() as Bool?)!, false)
                XCTAssertEqual((dbv.value() as Bool), false)
                XCTAssertEqual((dbv.value() as Int?)!, 0)
                XCTAssertEqual((dbv.value() as Int), 0)
                XCTAssertEqual((dbv.value() as Int32?)!, Int32(0))
                XCTAssertEqual((dbv.value() as Int32), Int32(0))
                XCTAssertEqual((dbv.value() as Int64?)!, Int64(0))
                XCTAssertEqual((dbv.value() as Int64), Int64(0))
                XCTAssertEqual((dbv.value() as Double?)!, 0.0)
                XCTAssertEqual((dbv.value() as Double), 0.0)
                XCTAssertTrue((dbv.value() as String?) == nil)
                XCTAssertTrue((dbv.value() as NSData?) == nil)
                
                return .Rollback
            }
            
            // 3.0e5 Double is turned to Integer
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (\(columnName)) VALUES (?)", arguments: [3.0e5])
                let dbv = Row.fetchOne(db, "SELECT \(columnName) FROM `values`")!.first!.1   // first is (columnName, dbv)
                XCTAssertEqual(dbv.storageClass, SQLiteStorageClass.Integer)
                
                // Check GRDB conversions from Integer storage
                XCTAssertEqual((dbv.value() as Bool?)!, true)
                XCTAssertEqual((dbv.value() as Bool), true)
                XCTAssertEqual((dbv.value() as Int?)!, 300000)
                XCTAssertEqual((dbv.value() as Int), 300000)
                XCTAssertEqual((dbv.value() as Int32?)!, Int32(300000))
                XCTAssertEqual((dbv.value() as Int32), Int32(300000))
                XCTAssertEqual((dbv.value() as Int64?)!, Int64(300000))
                XCTAssertEqual((dbv.value() as Int64), Int64(300000))
                XCTAssertEqual((dbv.value() as Double?)!, Double(300000))
                XCTAssertEqual((dbv.value() as Double), Double(300000))
                XCTAssertTrue((dbv.value() as String?) == nil)
                XCTAssertTrue((dbv.value() as NSData?) == nil)
                
                return .Rollback
            }
            
            // 1.0e20 Double is turned to Real
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (\(columnName)) VALUES (?)", arguments: [1.0e20])
                let dbv = Row.fetchOne(db, "SELECT \(columnName) FROM `values`")!.first!.1   // first is (columnName, dbv)
                XCTAssertEqual(dbv.storageClass, SQLiteStorageClass.Real)
                
                // Check GRDB conversions from Real storage (avoid Int, Int32 and Int64 since 1.0e20 does not fit)
                XCTAssertEqual((dbv.value() as Bool?)!, true)
                XCTAssertEqual((dbv.value() as Bool), true)
                XCTAssertEqual((dbv.value() as Double?)!, 1e20)
                XCTAssertEqual((dbv.value() as Double), 1e20)
                XCTAssertTrue((dbv.value() as String?) == nil)
                XCTAssertTrue((dbv.value() as NSData?) == nil)
                
                return .Rollback
            }
            
            // "3.0e+5" is turned to Integer
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (\(columnName)) VALUES (?)", arguments: ["3.0e+5"])
                let dbv = Row.fetchOne(db, "SELECT \(columnName) FROM `values`")!.first!.1   // first is (columnName, dbv)
                XCTAssertEqual(dbv.storageClass, SQLiteStorageClass.Integer)
                
                // Check GRDB conversions from Integer storage
                XCTAssertEqual((dbv.value() as Bool?)!, true)
                XCTAssertEqual((dbv.value() as Bool), true)
                XCTAssertEqual((dbv.value() as Int?)!, 300000)
                XCTAssertEqual((dbv.value() as Int), 300000)
                XCTAssertEqual((dbv.value() as Int32?)!, Int32(300000))
                XCTAssertEqual((dbv.value() as Int32), Int32(300000))
                XCTAssertEqual((dbv.value() as Int64?)!, Int64(300000))
                XCTAssertEqual((dbv.value() as Int64), Int64(300000))
                XCTAssertEqual((dbv.value() as Double?)!, Double(300000))
                XCTAssertEqual((dbv.value() as Double), Double(300000))
                XCTAssertTrue((dbv.value() as String?) == nil)
                XCTAssertTrue((dbv.value() as NSData?) == nil)
                
                return .Rollback
            }
            
            // "1.0e+20" is turned to Real
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (\(columnName)) VALUES (?)", arguments: ["1.0e+20"])
                let dbv = Row.fetchOne(db, "SELECT \(columnName) FROM `values`")!.first!.1   // first is (columnName, dbv)
                XCTAssertEqual(dbv.storageClass, SQLiteStorageClass.Real)
                
                // Check GRDB conversions from Real storage: (avoid Int, Int32 and Int64 since 1.0e20 does not fit)
                XCTAssertEqual((dbv.value() as Bool?)!, true)
                XCTAssertEqual((dbv.value() as Bool), true)
                XCTAssertEqual((dbv.value() as Double?)!, 1e20)
                XCTAssertEqual((dbv.value() as Double), 1e20)
                XCTAssertTrue((dbv.value() as String?) == nil)
                XCTAssertTrue((dbv.value() as NSData?) == nil)
                
                return .Rollback
            }
            
            // "foo" is turned to Text
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (\(columnName)) VALUES (?)", arguments: ["foo"])
                let dbv = Row.fetchOne(db, "SELECT \(columnName) FROM `values`")!.first!.1   // first is (columnName, dbv)
                XCTAssertEqual(dbv.storageClass, SQLiteStorageClass.Text)
                
                // Check GRDB conversions from Text storage:
                XCTAssertTrue((dbv.value() as Bool?) == nil)
                XCTAssertTrue((dbv.value() as Int?) == nil)
                XCTAssertTrue((dbv.value() as Int32?) == nil)
                XCTAssertTrue((dbv.value() as Int64?) == nil)
                XCTAssertTrue((dbv.value() as Double?) == nil)
                XCTAssertEqual((dbv.value() as String?)!, "foo")
                XCTAssertEqual((dbv.value() as String), "foo")
                XCTAssertTrue((dbv.value() as NSData?) == nil)
                
                return .Rollback
            }
            
            // Blob is turned to Blob
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (\(columnName)) VALUES (?)", arguments: ["foo".dataUsingEncoding(NSUTF8StringEncoding)])
                let dbv = Row.fetchOne(db, "SELECT \(columnName) FROM `values`")!.first!.1   // first is (columnName, dbv)
                XCTAssertEqual(dbv.storageClass, SQLiteStorageClass.Blob)
                
                // Check GRDB conversions from Blob storage:
                XCTAssertTrue((dbv.value() as Bool?) == nil)
                XCTAssertTrue((dbv.value() as Int?) == nil)
                XCTAssertTrue((dbv.value() as Int32?) == nil)
                XCTAssertTrue((dbv.value() as Int64?) == nil)
                XCTAssertTrue((dbv.value() as Double?) == nil)
                XCTAssertTrue((dbv.value() as String?) == nil)
                XCTAssertEqual((dbv.value() as NSData?), "foo".dataUsingEncoding(NSUTF8StringEncoding))
                
                return .Rollback
            }
        }
    }
}

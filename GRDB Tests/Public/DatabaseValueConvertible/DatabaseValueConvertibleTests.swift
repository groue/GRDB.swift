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
        switch self {
        case .Null:
            return .Null
        case .Integer:
            return .Integer
        case .Real:
            return .Real
        case .Text:
            return .Text
        case .Blob:
            return .Blob
        }
    }
}

class DatabaseValueConvertibleTests : GRDBTestCase {
    
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
    
    func bool(databaseValue: DatabaseValue) -> Bool? {
        return databaseValue.value()
    }
    func int(databaseValue: DatabaseValue) -> Int? {
        return databaseValue.value()
    }
    func int32(databaseValue: DatabaseValue) -> Int32? {
        return databaseValue.value()
    }
    func int64(databaseValue: DatabaseValue) -> Int64? {
        return databaseValue.value()
    }
    func double(databaseValue: DatabaseValue) -> Double? {
        return databaseValue.value()
    }
    func string(databaseValue: DatabaseValue) -> String? {
        return databaseValue.value()
    }
    func blob(databaseValue: DatabaseValue) -> Blob? {
        return databaseValue.value()
    }
    
    func testBlobDatabaseValueCanNotStoreEmptyData() {
        // SQLite can't store zero-length blob.
        let blob = Blob(NSData())
        XCTAssertTrue(blob == nil)
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
                let databaseValue = Row.fetchOne(db, "SELECT textAffinity FROM `values`")!.first!.1   // first is (columnName, databaseValue)
                XCTAssertEqual(databaseValue.storageClass, SQLiteStorageClass.Text)
                
                // Check built-in conversions from Text storage:
                XCTAssertTrue(self.bool(databaseValue) == nil)
                XCTAssertTrue(self.int(databaseValue) == nil)
                XCTAssertTrue(self.int32(databaseValue) == nil)
                XCTAssertTrue(self.int64(databaseValue) == nil)
                XCTAssertTrue(self.double(databaseValue) == nil)
                XCTAssertEqual(self.string(databaseValue)!, "0")
                XCTAssertTrue(self.blob(databaseValue) == nil)
                
                return .Rollback
            }
            
            // Int64 is turned to Text
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (textAffinity) VALUES (?)", arguments: [0 as Int64])
                let databaseValue = Row.fetchOne(db, "SELECT textAffinity FROM `values`")!.first!.1   // first is (columnName, databaseValue)
                XCTAssertEqual(databaseValue.storageClass, SQLiteStorageClass.Text)
                
                // Check built-in conversions from Text storage:
                XCTAssertTrue(self.bool(databaseValue) == nil)
                XCTAssertTrue(self.int(databaseValue) == nil)
                XCTAssertTrue(self.int32(databaseValue) == nil)
                XCTAssertTrue(self.int64(databaseValue) == nil)
                XCTAssertTrue(self.double(databaseValue) == nil)
                XCTAssertEqual(self.string(databaseValue)!, "0")
                XCTAssertTrue(self.blob(databaseValue) == nil)
                
                return .Rollback
            }
            
            // Int32 is turned to Text
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (textAffinity) VALUES (?)", arguments: [0 as Int32])
                let databaseValue = Row.fetchOne(db, "SELECT textAffinity FROM `values`")!.first!.1   // first is (columnName, databaseValue)
                XCTAssertEqual(databaseValue.storageClass, SQLiteStorageClass.Text)
                
                // Check built-in conversions from Text storage:
                XCTAssertTrue(self.bool(databaseValue) == nil)
                XCTAssertTrue(self.int(databaseValue) == nil)
                XCTAssertTrue(self.int32(databaseValue) == nil)
                XCTAssertTrue(self.int64(databaseValue) == nil)
                XCTAssertTrue(self.double(databaseValue) == nil)
                XCTAssertEqual(self.string(databaseValue)!, "0")
                XCTAssertTrue(self.blob(databaseValue) == nil)
                
                return .Rollback
            }
            
            // Double is turned to Real
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (textAffinity) VALUES (?)", arguments: [0.0])
                let databaseValue = Row.fetchOne(db, "SELECT textAffinity FROM `values`")!.first!.1   // first is (columnName, databaseValue)
                XCTAssertEqual(databaseValue.storageClass, SQLiteStorageClass.Text)
                
                // Check built-in conversions from Text storage:
                XCTAssertTrue(self.bool(databaseValue) == nil)
                XCTAssertTrue(self.int(databaseValue) == nil)
                XCTAssertTrue(self.int32(databaseValue) == nil)
                XCTAssertTrue(self.int64(databaseValue) == nil)
                XCTAssertTrue(self.double(databaseValue) == nil)
                XCTAssertEqual(self.string(databaseValue)!, "0.0")
                XCTAssertTrue(self.blob(databaseValue) == nil)
                
                return .Rollback
            }
            
            // "3.0e+5" is turned to Text
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (textAffinity) VALUES (?)", arguments: ["3.0e+5"])
                let databaseValue = Row.fetchOne(db, "SELECT textAffinity FROM `values`")!.first!.1   // first is (columnName, databaseValue)
                XCTAssertEqual(databaseValue.storageClass, SQLiteStorageClass.Text)
                
                // Check built-in conversions from Text storage:
                XCTAssertTrue(self.bool(databaseValue) == nil)
                XCTAssertTrue(self.int(databaseValue) == nil)
                XCTAssertTrue(self.int32(databaseValue) == nil)
                XCTAssertTrue(self.int64(databaseValue) == nil)
                XCTAssertTrue(self.double(databaseValue) == nil)
                XCTAssertEqual(self.string(databaseValue)!, "3.0e+5")
                XCTAssertTrue(self.blob(databaseValue) == nil)
                
                return .Rollback
            }
            
            // "foo" is turned to Text
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (textAffinity) VALUES (?)", arguments: ["foo"])
                let databaseValue = Row.fetchOne(db, "SELECT textAffinity FROM `values`")!.first!.1   // first is (columnName, databaseValue)
                XCTAssertEqual(databaseValue.storageClass, SQLiteStorageClass.Text)
                
                // Check built-in conversions from Text storage:
                XCTAssertTrue(self.bool(databaseValue) == nil)
                XCTAssertTrue(self.int(databaseValue) == nil)
                XCTAssertTrue(self.int32(databaseValue) == nil)
                XCTAssertTrue(self.int64(databaseValue) == nil)
                XCTAssertTrue(self.double(databaseValue) == nil)
                XCTAssertEqual(self.string(databaseValue)!, "foo")
                XCTAssertTrue(self.blob(databaseValue) == nil)
                
                return .Rollback
            }
            
            // Blob is turned to Blob
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (textAffinity) VALUES (?)", arguments: [Blob("foo".dataUsingEncoding(NSUTF8StringEncoding))])
                let databaseValue = Row.fetchOne(db, "SELECT textAffinity FROM `values`")!.first!.1   // first is (columnName, databaseValue)
                XCTAssertEqual(databaseValue.storageClass, SQLiteStorageClass.Blob)
                
                // Check built-in conversions from Blob storage:
                XCTAssertTrue(self.bool(databaseValue) == nil)
                XCTAssertTrue(self.int(databaseValue) == nil)
                XCTAssertTrue(self.int32(databaseValue) == nil)
                XCTAssertTrue(self.int64(databaseValue) == nil)
                XCTAssertTrue(self.double(databaseValue) == nil)
                XCTAssertTrue(self.string(databaseValue) == nil)
                XCTAssertTrue(self.blob(databaseValue)!.data .isEqualToData("foo".dataUsingEncoding(NSUTF8StringEncoding)!))
                
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
                let databaseValue = Row.fetchOne(db, "SELECT realAffinity FROM `values`")!.first!.1   // first is (columnName, databaseValue)
                XCTAssertEqual(databaseValue.storageClass, SQLiteStorageClass.Real)
                
                // Check built-in conversions from Real storage
                XCTAssertEqual(self.bool(databaseValue)!, false)
                XCTAssertEqual(self.int(databaseValue)!, 0)
                XCTAssertEqual(self.int32(databaseValue)!, Int32(0))
                XCTAssertEqual(self.int64(databaseValue)!, Int64(0))
                XCTAssertEqual(self.double(databaseValue)!, 0.0)
                XCTAssertTrue(self.string(databaseValue) == nil)
                XCTAssertTrue(self.blob(databaseValue) == nil)
                
                return .Rollback
            }
            
            // Int64 is turned to Real
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (realAffinity) VALUES (?)", arguments: [0 as Int64])
                let databaseValue = Row.fetchOne(db, "SELECT realAffinity FROM `values`")!.first!.1   // first is (columnName, databaseValue)
                XCTAssertEqual(databaseValue.storageClass, SQLiteStorageClass.Real)
                
                // Check built-in conversions from Real storage
                XCTAssertEqual(self.bool(databaseValue)!, false)
                XCTAssertEqual(self.int(databaseValue)!, 0)
                XCTAssertEqual(self.int32(databaseValue)!, Int32(0))
                XCTAssertEqual(self.int64(databaseValue)!, Int64(0))
                XCTAssertEqual(self.double(databaseValue)!, 0.0)
                XCTAssertTrue(self.string(databaseValue) == nil)
                XCTAssertTrue(self.blob(databaseValue) == nil)
                
                return .Rollback
            }
            
            // Int32 is turned to Real
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (realAffinity) VALUES (?)", arguments: [0 as Int32])
                let databaseValue = Row.fetchOne(db, "SELECT realAffinity FROM `values`")!.first!.1   // first is (columnName, databaseValue)
                XCTAssertEqual(databaseValue.storageClass, SQLiteStorageClass.Real)
                
                // Check built-in conversions from Real storage
                XCTAssertEqual(self.bool(databaseValue)!, false)
                XCTAssertEqual(self.int(databaseValue)!, 0)
                XCTAssertEqual(self.int32(databaseValue)!, Int32(0))
                XCTAssertEqual(self.int64(databaseValue)!, Int64(0))
                XCTAssertEqual(self.double(databaseValue)!, 0.0)
                XCTAssertTrue(self.string(databaseValue) == nil)
                XCTAssertTrue(self.blob(databaseValue) == nil)
                
                return .Rollback
            }
            
            // 3.0e5 Double is turned to Real
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (realAffinity) VALUES (?)", arguments: [3.0e5])
                let databaseValue = Row.fetchOne(db, "SELECT realAffinity FROM `values`")!.first!.1   // first is (columnName, databaseValue)
                XCTAssertEqual(databaseValue.storageClass, SQLiteStorageClass.Real)
                
                // Check built-in conversions from Real storage
                XCTAssertEqual(self.bool(databaseValue)!, true)
                XCTAssertEqual(self.int(databaseValue)!, 300000)
                XCTAssertEqual(self.int32(databaseValue)!, Int32(300000))
                XCTAssertEqual(self.int64(databaseValue)!, Int64(300000))
                XCTAssertEqual(self.double(databaseValue)!, Double(300000))
                XCTAssertTrue(self.string(databaseValue) == nil)
                XCTAssertTrue(self.blob(databaseValue) == nil)
                
                return .Rollback
            }
            
            // 1.0e20 Double is turned to Real
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (realAffinity) VALUES (?)", arguments: [1.0e20])
                let databaseValue = Row.fetchOne(db, "SELECT realAffinity FROM `values`")!.first!.1   // first is (columnName, databaseValue)
                XCTAssertEqual(databaseValue.storageClass, SQLiteStorageClass.Real)
                
                // Check built-in conversions from Real storage (avoid Int, Int32 and Int64 since 1.0e20 does not fit)
                XCTAssertEqual(self.bool(databaseValue)!, true)
                XCTAssertEqual(self.double(databaseValue)!, 1e20)
                XCTAssertTrue(self.string(databaseValue) == nil)
                XCTAssertTrue(self.blob(databaseValue) == nil)
                
                return .Rollback
            }
            
            // "3.0e+5" is turned to Real
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (realAffinity) VALUES (?)", arguments: ["3.0e+5"])
                let databaseValue = Row.fetchOne(db, "SELECT realAffinity FROM `values`")!.first!.1   // first is (columnName, databaseValue)
                XCTAssertEqual(databaseValue.storageClass, SQLiteStorageClass.Real)
                
                // Check built-in conversions from Real storage
                XCTAssertEqual(self.bool(databaseValue)!, true)
                XCTAssertEqual(self.int(databaseValue)!, 300000)
                XCTAssertEqual(self.int32(databaseValue)!, Int32(300000))
                XCTAssertEqual(self.int64(databaseValue)!, Int64(300000))
                XCTAssertEqual(self.double(databaseValue)!, Double(300000))
                XCTAssertTrue(self.string(databaseValue) == nil)
                XCTAssertTrue(self.blob(databaseValue) == nil)
                
                return .Rollback
            }
            
            // "1.0e+20" is turned to Real
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (realAffinity) VALUES (?)", arguments: ["1.0e+20"])
                let databaseValue = Row.fetchOne(db, "SELECT realAffinity FROM `values`")!.first!.1   // first is (columnName, databaseValue)
                XCTAssertEqual(databaseValue.storageClass, SQLiteStorageClass.Real)
                
                // Check built-in conversions from Real storage: (avoid Int, Int32 and Int64 since 1.0e20 does not fit)
                XCTAssertEqual(self.bool(databaseValue)!, true)
                XCTAssertEqual(self.double(databaseValue)!, 1e20)
                XCTAssertTrue(self.string(databaseValue) == nil)
                XCTAssertTrue(self.blob(databaseValue) == nil)
                
                return .Rollback
            }
            
            // "foo" is turned to Text
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (realAffinity) VALUES (?)", arguments: ["foo"])
                let databaseValue = Row.fetchOne(db, "SELECT realAffinity FROM `values`")!.first!.1   // first is (columnName, databaseValue)
                XCTAssertEqual(databaseValue.storageClass, SQLiteStorageClass.Text)
                
                // Check built-in conversions from Text storage:
                XCTAssertTrue(self.bool(databaseValue) == nil)
                XCTAssertTrue(self.int(databaseValue) == nil)
                XCTAssertTrue(self.int32(databaseValue) == nil)
                XCTAssertTrue(self.int64(databaseValue) == nil)
                XCTAssertTrue(self.double(databaseValue) == nil)
                XCTAssertEqual(self.string(databaseValue)!, "foo")
                XCTAssertTrue(self.blob(databaseValue) == nil)
                
                return .Rollback
            }
            
            // Blob is turned to Blob
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (realAffinity) VALUES (?)", arguments: [Blob("foo".dataUsingEncoding(NSUTF8StringEncoding))])
                let databaseValue = Row.fetchOne(db, "SELECT realAffinity FROM `values`")!.first!.1   // first is (columnName, databaseValue)
                XCTAssertEqual(databaseValue.storageClass, SQLiteStorageClass.Blob)
                
                // Check built-in conversions from Blob storage:
                XCTAssertTrue(self.bool(databaseValue) == nil)
                XCTAssertTrue(self.int(databaseValue) == nil)
                XCTAssertTrue(self.int32(databaseValue) == nil)
                XCTAssertTrue(self.int64(databaseValue) == nil)
                XCTAssertTrue(self.double(databaseValue) == nil)
                XCTAssertTrue(self.string(databaseValue) == nil)
                XCTAssertTrue(self.blob(databaseValue)!.data .isEqualToData("foo".dataUsingEncoding(NSUTF8StringEncoding)!))
                
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
                let databaseValue = Row.fetchOne(db, "SELECT noneAffinity FROM `values`")!.first!.1   // first is (columnName, databaseValue)
                XCTAssertEqual(databaseValue.storageClass, SQLiteStorageClass.Integer)
                
                // Check built-in conversions from Integer storage
                XCTAssertEqual(self.bool(databaseValue)!, false)
                XCTAssertEqual(self.int(databaseValue)!, 0)
                XCTAssertEqual(self.int32(databaseValue)!, Int32(0))
                XCTAssertEqual(self.int64(databaseValue)!, Int64(0))
                XCTAssertEqual(self.double(databaseValue)!, 0.0)
                XCTAssertTrue(self.string(databaseValue) == nil)      
                XCTAssertTrue(self.blob(databaseValue) == nil)
                
                return .Rollback
            }
            
            // Int64 is turned to Integer
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (noneAffinity) VALUES (?)", arguments: [0 as Int64])
                let databaseValue = Row.fetchOne(db, "SELECT noneAffinity FROM `values`")!.first!.1   // first is (columnName, databaseValue)
                XCTAssertEqual(databaseValue.storageClass, SQLiteStorageClass.Integer)
                
                // Check built-in conversions from Integer storage
                XCTAssertEqual(self.bool(databaseValue)!, false)
                XCTAssertEqual(self.int(databaseValue)!, 0)
                XCTAssertEqual(self.int32(databaseValue)!, Int32(0))
                XCTAssertEqual(self.int64(databaseValue)!, Int64(0))
                XCTAssertEqual(self.double(databaseValue)!, 0.0)
                XCTAssertTrue(self.string(databaseValue) == nil)
                XCTAssertTrue(self.blob(databaseValue) == nil)
                
                return .Rollback
            }
            
            // Int32 is turned to Integer
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (noneAffinity) VALUES (?)", arguments: [0 as Int32])
                let databaseValue = Row.fetchOne(db, "SELECT noneAffinity FROM `values`")!.first!.1   // first is (columnName, databaseValue)
                XCTAssertEqual(databaseValue.storageClass, SQLiteStorageClass.Integer)
                
                // Check built-in conversions from Integer storage
                XCTAssertEqual(self.bool(databaseValue)!, false)
                XCTAssertEqual(self.int(databaseValue)!, 0)
                XCTAssertEqual(self.int32(databaseValue)!, Int32(0))
                XCTAssertEqual(self.int64(databaseValue)!, Int64(0))
                XCTAssertEqual(self.double(databaseValue)!, 0.0)
                XCTAssertTrue(self.string(databaseValue) == nil)
                XCTAssertTrue(self.blob(databaseValue) == nil)
                
                return .Rollback
            }
            
            // Double is turned to Real
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (noneAffinity) VALUES (?)", arguments: [0.0])
                let databaseValue = Row.fetchOne(db, "SELECT noneAffinity FROM `values`")!.first!.1   // first is (columnName, databaseValue)
                XCTAssertEqual(databaseValue.storageClass, SQLiteStorageClass.Real)
                
                // Check built-in conversions from Real storage
                XCTAssertEqual(self.bool(databaseValue)!, false)
                XCTAssertEqual(self.int(databaseValue)!, 0)
                XCTAssertEqual(self.int32(databaseValue)!, Int32(0))
                XCTAssertEqual(self.int64(databaseValue)!, Int64(0))
                XCTAssertEqual(self.double(databaseValue)!, 0.0)
                XCTAssertTrue(self.string(databaseValue) == nil)
                XCTAssertTrue(self.blob(databaseValue) == nil)
                
                return .Rollback
            }
            
            // "3.0e+5" is turned to Text
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (noneAffinity) VALUES (?)", arguments: ["3.0e+5"])
                let databaseValue = Row.fetchOne(db, "SELECT noneAffinity FROM `values`")!.first!.1   // first is (columnName, databaseValue)
                XCTAssertEqual(databaseValue.storageClass, SQLiteStorageClass.Text)
                
                // Check built-in conversions from Text storage
                XCTAssertTrue(self.bool(databaseValue) == nil)
                XCTAssertTrue(self.int(databaseValue) == nil)
                XCTAssertTrue(self.int32(databaseValue) == nil)
                XCTAssertTrue(self.int64(databaseValue) == nil)
                XCTAssertTrue(self.double(databaseValue) == nil)
                XCTAssertEqual(self.string(databaseValue)!, "3.0e+5")
                XCTAssertTrue(self.blob(databaseValue) == nil)
                
                return .Rollback
            }
            
            // Blob is turned to Blob
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (noneAffinity) VALUES (?)", arguments: [Blob("foo".dataUsingEncoding(NSUTF8StringEncoding))])
                let databaseValue = Row.fetchOne(db, "SELECT noneAffinity FROM `values`")!.first!.1   // first is (columnName, databaseValue)
                XCTAssertEqual(databaseValue.storageClass, SQLiteStorageClass.Blob)
                
                // Check built-in conversions from Blob storage
                XCTAssertTrue(self.bool(databaseValue) == nil)
                XCTAssertTrue(self.int(databaseValue) == nil)
                XCTAssertTrue(self.int32(databaseValue) == nil)
                XCTAssertTrue(self.int64(databaseValue) == nil)
                XCTAssertTrue(self.double(databaseValue) == nil)
                XCTAssertTrue(self.string(databaseValue) == nil)
                XCTAssertTrue(self.blob(databaseValue)!.data .isEqualToData("foo".dataUsingEncoding(NSUTF8StringEncoding)!))
                
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
                let databaseValue = Row.fetchOne(db, "SELECT \(columnName) FROM `values`")!.first!.1   // first is (columnName, databaseValue)
                XCTAssertEqual(databaseValue.storageClass, SQLiteStorageClass.Integer)
                
                // Check built-in conversions from Integer storage
                XCTAssertEqual(self.bool(databaseValue)!, false)
                XCTAssertEqual(self.int(databaseValue)!, 0)
                XCTAssertEqual(self.int32(databaseValue)!, Int32(0))
                XCTAssertEqual(self.int64(databaseValue)!, Int64(0))
                XCTAssertEqual(self.double(databaseValue)!, 0.0)
                XCTAssertTrue(self.string(databaseValue) == nil)
                XCTAssertTrue(self.blob(databaseValue) == nil)
                
                return .Rollback
            }
            
            // Int64 is turned to Integer
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (\(columnName)) VALUES (?)", arguments: [0 as Int64])
                let databaseValue = Row.fetchOne(db, "SELECT \(columnName) FROM `values`")!.first!.1   // first is (columnName, databaseValue)
                XCTAssertEqual(databaseValue.storageClass, SQLiteStorageClass.Integer)
                
                // Check built-in conversions from Integer storage
                XCTAssertEqual(self.bool(databaseValue)!, false)
                XCTAssertEqual(self.int(databaseValue)!, 0)
                XCTAssertEqual(self.int32(databaseValue)!, Int32(0))
                XCTAssertEqual(self.int64(databaseValue)!, Int64(0))
                XCTAssertEqual(self.double(databaseValue)!, 0.0)
                XCTAssertTrue(self.string(databaseValue) == nil)
                XCTAssertTrue(self.blob(databaseValue) == nil)
                
                return .Rollback
            }
            
            // Int32 is turned to Integer
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (\(columnName)) VALUES (?)", arguments: [0 as Int32])
                let databaseValue = Row.fetchOne(db, "SELECT \(columnName) FROM `values`")!.first!.1   // first is (columnName, databaseValue)
                XCTAssertEqual(databaseValue.storageClass, SQLiteStorageClass.Integer)
                
                // Check built-in conversions from Integer storage
                XCTAssertEqual(self.bool(databaseValue)!, false)
                XCTAssertEqual(self.int(databaseValue)!, 0)
                XCTAssertEqual(self.int32(databaseValue)!, Int32(0))
                XCTAssertEqual(self.int64(databaseValue)!, Int64(0))
                XCTAssertEqual(self.double(databaseValue)!, 0.0)
                XCTAssertTrue(self.string(databaseValue) == nil)
                XCTAssertTrue(self.blob(databaseValue) == nil)
                
                return .Rollback
            }
            
            // 3.0e5 Double is turned to Integer
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (\(columnName)) VALUES (?)", arguments: [3.0e5])
                let databaseValue = Row.fetchOne(db, "SELECT \(columnName) FROM `values`")!.first!.1   // first is (columnName, databaseValue)
                XCTAssertEqual(databaseValue.storageClass, SQLiteStorageClass.Integer)
                
                // Check built-in conversions from Integer storage
                XCTAssertEqual(self.bool(databaseValue)!, true)
                XCTAssertEqual(self.int(databaseValue)!, 300000)
                XCTAssertEqual(self.int32(databaseValue)!, Int32(300000))
                XCTAssertEqual(self.int64(databaseValue)!, Int64(300000))
                XCTAssertEqual(self.double(databaseValue)!, Double(300000))
                XCTAssertTrue(self.string(databaseValue) == nil)
                XCTAssertTrue(self.blob(databaseValue) == nil)
                
                return .Rollback
            }
            
            // 1.0e20 Double is turned to Real
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (\(columnName)) VALUES (?)", arguments: [1.0e20])
                let databaseValue = Row.fetchOne(db, "SELECT \(columnName) FROM `values`")!.first!.1   // first is (columnName, databaseValue)
                XCTAssertEqual(databaseValue.storageClass, SQLiteStorageClass.Real)
                
                // Check built-in conversions from Real storage (avoid Int, Int32 and Int64 since 1.0e20 does not fit)
                XCTAssertEqual(self.bool(databaseValue)!, true)
                XCTAssertEqual(self.double(databaseValue)!, 1e20)
                XCTAssertTrue(self.string(databaseValue) == nil)
                XCTAssertTrue(self.blob(databaseValue) == nil)
                
                return .Rollback
            }
            
            // "3.0e+5" is turned to Integer
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (\(columnName)) VALUES (?)", arguments: ["3.0e+5"])
                let databaseValue = Row.fetchOne(db, "SELECT \(columnName) FROM `values`")!.first!.1   // first is (columnName, databaseValue)
                XCTAssertEqual(databaseValue.storageClass, SQLiteStorageClass.Integer)
                
                // Check built-in conversions from Integer storage
                XCTAssertEqual(self.bool(databaseValue)!, true)
                XCTAssertEqual(self.int(databaseValue)!, 300000)
                XCTAssertEqual(self.int32(databaseValue)!, Int32(300000))
                XCTAssertEqual(self.int64(databaseValue)!, Int64(300000))
                XCTAssertEqual(self.double(databaseValue)!, Double(300000))
                XCTAssertTrue(self.string(databaseValue) == nil)
                XCTAssertTrue(self.blob(databaseValue) == nil)
                
                return .Rollback
            }
            
            // "1.0e+20" is turned to Real
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (\(columnName)) VALUES (?)", arguments: ["1.0e+20"])
                let databaseValue = Row.fetchOne(db, "SELECT \(columnName) FROM `values`")!.first!.1   // first is (columnName, databaseValue)
                XCTAssertEqual(databaseValue.storageClass, SQLiteStorageClass.Real)
                
                // Check built-in conversions from Real storage: (avoid Int, Int32 and Int64 since 1.0e20 does not fit)
                XCTAssertEqual(self.bool(databaseValue)!, true)
                XCTAssertEqual(self.double(databaseValue)!, 1e20)
                XCTAssertTrue(self.string(databaseValue) == nil)
                XCTAssertTrue(self.blob(databaseValue) == nil)
                
                return .Rollback
            }
            
            // "foo" is turned to Text
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (\(columnName)) VALUES (?)", arguments: ["foo"])
                let databaseValue = Row.fetchOne(db, "SELECT \(columnName) FROM `values`")!.first!.1   // first is (columnName, databaseValue)
                XCTAssertEqual(databaseValue.storageClass, SQLiteStorageClass.Text)
                
                // Check built-in conversions from Text storage:
                XCTAssertTrue(self.bool(databaseValue) == nil)
                XCTAssertTrue(self.int(databaseValue) == nil)
                XCTAssertTrue(self.int32(databaseValue) == nil)
                XCTAssertTrue(self.int64(databaseValue) == nil)
                XCTAssertTrue(self.double(databaseValue) == nil)
                XCTAssertEqual(self.string(databaseValue)!, "foo")
                XCTAssertTrue(self.blob(databaseValue) == nil)
                
                return .Rollback
            }
            
            // Blob is turned to Blob
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (\(columnName)) VALUES (?)", arguments: [Blob("foo".dataUsingEncoding(NSUTF8StringEncoding))])
                let databaseValue = Row.fetchOne(db, "SELECT \(columnName) FROM `values`")!.first!.1   // first is (columnName, databaseValue)
                XCTAssertEqual(databaseValue.storageClass, SQLiteStorageClass.Blob)
                
                // Check built-in conversions from Blob storage:
                XCTAssertTrue(self.bool(databaseValue) == nil)
                XCTAssertTrue(self.int(databaseValue) == nil)
                XCTAssertTrue(self.int32(databaseValue) == nil)
                XCTAssertTrue(self.int64(databaseValue) == nil)
                XCTAssertTrue(self.double(databaseValue) == nil)
                XCTAssertTrue(self.string(databaseValue) == nil)
                XCTAssertTrue(self.blob(databaseValue)!.data .isEqualToData("foo".dataUsingEncoding(NSUTF8StringEncoding)!))
                
                return .Rollback
            }
        }
    }
}

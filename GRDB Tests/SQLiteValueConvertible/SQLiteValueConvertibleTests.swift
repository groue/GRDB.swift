//
// GRDB.swift
// https://github.com/groue/GRDB.swift
// Copyright (c) 2015 Gwendal Roué
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.


import XCTest
@testable import GRDB

enum SQLiteStorageClass {
    case Null
    case Integer
    case Real
    case Text
    case Blob
}

extension SQLiteValue {
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

class SQLiteValueConvertibleTests : GRDBTestCase {
    
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
    
    func bool(sqliteValue: SQLiteValue) -> Bool? {
        return sqliteValue.value()
    }
    func int(sqliteValue: SQLiteValue) -> Int? {
        return sqliteValue.value()
    }
    func int64(sqliteValue: SQLiteValue) -> Int64? {
        return sqliteValue.value()
    }
    func double(sqliteValue: SQLiteValue) -> Double? {
        return sqliteValue.value()
    }
    func string(sqliteValue: SQLiteValue) -> String? {
        return sqliteValue.value()
    }
    func blob(sqliteValue: SQLiteValue) -> Blob? {
        return sqliteValue.value()
    }
    
    func testTextAffinity() {
        // https://www.sqlite.org/datatype3.html
        //
        // > A column with TEXT affinity stores all data using storage classes
        // > NULL, TEXT or BLOB. If numerical data is inserted into a column
        // > with TEXT affinity it is converted into text form before being
        // > stored.
        
        assertNoError {
            
            // Integer is turned to Text
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (textAffinity) VALUES (?)", bindings: [0])
                let sqliteValue = db.fetchOneRow("SELECT textAffinity FROM `values`")!.sqliteValue(atIndex: 0)
                XCTAssertEqual(sqliteValue.storageClass, SQLiteStorageClass.Text)
                
                // Check built-in conversions from Text storage:
                XCTAssertTrue(self.bool(sqliteValue) == nil)
                XCTAssertTrue(self.int(sqliteValue) == nil)
                XCTAssertTrue(self.int64(sqliteValue) == nil)
                XCTAssertTrue(self.double(sqliteValue) == nil)
                XCTAssertEqual(self.string(sqliteValue)!, "0")
                XCTAssertTrue(self.blob(sqliteValue) == nil)
                
                return .Rollback
            }
            
            // Double is turned to Real
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (textAffinity) VALUES (?)", bindings: [0.0])
                let sqliteValue = db.fetchOneRow("SELECT textAffinity FROM `values`")!.sqliteValue(atIndex: 0)
                XCTAssertEqual(sqliteValue.storageClass, SQLiteStorageClass.Text)
                
                // Check built-in conversions from Text storage:
                XCTAssertTrue(self.bool(sqliteValue) == nil)
                XCTAssertTrue(self.int(sqliteValue) == nil)
                XCTAssertTrue(self.int64(sqliteValue) == nil)
                XCTAssertTrue(self.double(sqliteValue) == nil)
                XCTAssertEqual(self.string(sqliteValue)!, "0.0")
                XCTAssertTrue(self.blob(sqliteValue) == nil)
                
                return .Rollback
            }
            
            // "3.0e+5" is turned to Text
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (textAffinity) VALUES (?)", bindings: ["3.0e+5"])
                let sqliteValue = db.fetchOneRow("SELECT textAffinity FROM `values`")!.sqliteValue(atIndex: 0)
                XCTAssertEqual(sqliteValue.storageClass, SQLiteStorageClass.Text)
                
                // Check built-in conversions from Text storage:
                XCTAssertTrue(self.bool(sqliteValue) == nil)
                XCTAssertTrue(self.int(sqliteValue) == nil)
                XCTAssertTrue(self.int64(sqliteValue) == nil)
                XCTAssertTrue(self.double(sqliteValue) == nil)
                XCTAssertEqual(self.string(sqliteValue)!, "3.0e+5")
                XCTAssertTrue(self.blob(sqliteValue) == nil)
                
                return .Rollback
            }
            
            // "foo" is turned to Text
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (textAffinity) VALUES (?)", bindings: ["foo"])
                let sqliteValue = db.fetchOneRow("SELECT textAffinity FROM `values`")!.sqliteValue(atIndex: 0)
                XCTAssertEqual(sqliteValue.storageClass, SQLiteStorageClass.Text)
                
                // Check built-in conversions from Text storage:
                XCTAssertTrue(self.bool(sqliteValue) == nil)
                XCTAssertTrue(self.int(sqliteValue) == nil)
                XCTAssertTrue(self.int64(sqliteValue) == nil)
                XCTAssertTrue(self.double(sqliteValue) == nil)
                XCTAssertEqual(self.string(sqliteValue)!, "foo")
                XCTAssertTrue(self.blob(sqliteValue) == nil)
                
                return .Rollback
            }
            
            // Blob is turned to Blob
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (textAffinity) VALUES (?)", bindings: [Blob("foo".dataUsingEncoding(NSUTF8StringEncoding))])
                let sqliteValue = db.fetchOneRow("SELECT textAffinity FROM `values`")!.sqliteValue(atIndex: 0)
                XCTAssertEqual(sqliteValue.storageClass, SQLiteStorageClass.Blob)
                
                // Check built-in conversions from Blob storage:
                XCTAssertTrue(self.bool(sqliteValue) == nil)
                XCTAssertTrue(self.int(sqliteValue) == nil)
                XCTAssertTrue(self.int64(sqliteValue) == nil)
                XCTAssertTrue(self.double(sqliteValue) == nil)
                XCTAssertTrue(self.string(sqliteValue) == nil)
                XCTAssertTrue(self.blob(sqliteValue)!.data .isEqualToData("foo".dataUsingEncoding(NSUTF8StringEncoding)!))
                
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
            
            // Integer is turned to Real
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (realAffinity) VALUES (?)", bindings: [0])
                let sqliteValue = db.fetchOneRow("SELECT realAffinity FROM `values`")!.sqliteValue(atIndex: 0)
                XCTAssertEqual(sqliteValue.storageClass, SQLiteStorageClass.Real)
                
                // Check built-in conversions from Real storage
                XCTAssertEqual(self.bool(sqliteValue)!, false)
                XCTAssertEqual(self.int(sqliteValue)!, 0)
                XCTAssertEqual(self.int64(sqliteValue)!, Int64(0))
                XCTAssertEqual(self.double(sqliteValue)!, 0.0)
                XCTAssertTrue(self.string(sqliteValue) == nil)
                XCTAssertTrue(self.blob(sqliteValue) == nil)
                
                return .Rollback
            }
            
            // 3.0e5 Double is turned to Real
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (realAffinity) VALUES (?)", bindings: [3.0e5])
                let sqliteValue = db.fetchOneRow("SELECT realAffinity FROM `values`")!.sqliteValue(atIndex: 0)
                XCTAssertEqual(sqliteValue.storageClass, SQLiteStorageClass.Real)
                
                // Check built-in conversions from Real storage
                XCTAssertEqual(self.bool(sqliteValue)!, true)
                XCTAssertEqual(self.int(sqliteValue)!, 300000)
                XCTAssertEqual(self.int64(sqliteValue)!, Int64(300000))
                XCTAssertEqual(self.double(sqliteValue)!, Double(300000))
                XCTAssertTrue(self.string(sqliteValue) == nil)
                XCTAssertTrue(self.blob(sqliteValue) == nil)
                
                return .Rollback
            }
            
            // 1.0e20 Double is turned to Real
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (realAffinity) VALUES (?)", bindings: [1.0e20])
                let sqliteValue = db.fetchOneRow("SELECT realAffinity FROM `values`")!.sqliteValue(atIndex: 0)
                XCTAssertEqual(sqliteValue.storageClass, SQLiteStorageClass.Real)
                
                // Check built-in conversions from Real storage (avoid Int and Int64 since 1.0e20 does not fit)
                XCTAssertEqual(self.bool(sqliteValue)!, true)
                XCTAssertEqual(self.double(sqliteValue)!, 1e20)
                XCTAssertTrue(self.string(sqliteValue) == nil)
                XCTAssertTrue(self.blob(sqliteValue) == nil)
                
                return .Rollback
            }
            
            // "3.0e+5" is turned to Real
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (realAffinity) VALUES (?)", bindings: ["3.0e+5"])
                let sqliteValue = db.fetchOneRow("SELECT realAffinity FROM `values`")!.sqliteValue(atIndex: 0)
                XCTAssertEqual(sqliteValue.storageClass, SQLiteStorageClass.Real)
                
                // Check built-in conversions from Real storage
                XCTAssertEqual(self.bool(sqliteValue)!, true)
                XCTAssertEqual(self.int(sqliteValue)!, 300000)
                XCTAssertEqual(self.int64(sqliteValue)!, Int64(300000))
                XCTAssertEqual(self.double(sqliteValue)!, Double(300000))
                XCTAssertTrue(self.string(sqliteValue) == nil)
                XCTAssertTrue(self.blob(sqliteValue) == nil)
                
                return .Rollback
            }
            
            // "1.0e+20" is turned to Real
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (realAffinity) VALUES (?)", bindings: ["1.0e+20"])
                let sqliteValue = db.fetchOneRow("SELECT realAffinity FROM `values`")!.sqliteValue(atIndex: 0)
                XCTAssertEqual(sqliteValue.storageClass, SQLiteStorageClass.Real)
                
                // Check built-in conversions from Real storage: (avoid Int and Int64 since 1.0e20 does not fit)
                XCTAssertEqual(self.bool(sqliteValue)!, true)
                XCTAssertEqual(self.double(sqliteValue)!, 1e20)
                XCTAssertTrue(self.string(sqliteValue) == nil)
                XCTAssertTrue(self.blob(sqliteValue) == nil)
                
                return .Rollback
            }
            
            // "foo" is turned to Text
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (realAffinity) VALUES (?)", bindings: ["foo"])
                let sqliteValue = db.fetchOneRow("SELECT realAffinity FROM `values`")!.sqliteValue(atIndex: 0)
                XCTAssertEqual(sqliteValue.storageClass, SQLiteStorageClass.Text)
                
                // Check built-in conversions from Text storage:
                XCTAssertTrue(self.bool(sqliteValue) == nil)
                XCTAssertTrue(self.int(sqliteValue) == nil)
                XCTAssertTrue(self.int64(sqliteValue) == nil)
                XCTAssertTrue(self.double(sqliteValue) == nil)
                XCTAssertEqual(self.string(sqliteValue)!, "foo")
                XCTAssertTrue(self.blob(sqliteValue) == nil)
                
                return .Rollback
            }
            
            // Blob is turned to Blob
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (realAffinity) VALUES (?)", bindings: [Blob("foo".dataUsingEncoding(NSUTF8StringEncoding))])
                let sqliteValue = db.fetchOneRow("SELECT realAffinity FROM `values`")!.sqliteValue(atIndex: 0)
                XCTAssertEqual(sqliteValue.storageClass, SQLiteStorageClass.Blob)
                
                // Check built-in conversions from Blob storage:
                XCTAssertTrue(self.bool(sqliteValue) == nil)
                XCTAssertTrue(self.int(sqliteValue) == nil)
                XCTAssertTrue(self.int64(sqliteValue) == nil)
                XCTAssertTrue(self.double(sqliteValue) == nil)
                XCTAssertTrue(self.string(sqliteValue) == nil)
                XCTAssertTrue(self.blob(sqliteValue)!.data .isEqualToData("foo".dataUsingEncoding(NSUTF8StringEncoding)!))
                
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
            
            // Integer is turned to Integer
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (noneAffinity) VALUES (?)", bindings: [0])
                let sqliteValue = db.fetchOneRow("SELECT noneAffinity FROM `values`")!.sqliteValue(atIndex: 0)
                XCTAssertEqual(sqliteValue.storageClass, SQLiteStorageClass.Integer)
                
                // Check built-in conversions from Integer storage
                XCTAssertEqual(self.bool(sqliteValue)!, false)
                XCTAssertEqual(self.int(sqliteValue)!, 0)
                XCTAssertEqual(self.int64(sqliteValue)!, Int64(0))
                XCTAssertEqual(self.double(sqliteValue)!, 0.0)
                XCTAssertTrue(self.string(sqliteValue) == nil)      
                XCTAssertTrue(self.blob(sqliteValue) == nil)
                
                return .Rollback
            }
            
            // Double is turned to Real
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (noneAffinity) VALUES (?)", bindings: [0.0])
                let sqliteValue = db.fetchOneRow("SELECT noneAffinity FROM `values`")!.sqliteValue(atIndex: 0)
                XCTAssertEqual(sqliteValue.storageClass, SQLiteStorageClass.Real)
                
                // Check built-in conversions from Real storage
                XCTAssertEqual(self.bool(sqliteValue)!, false)
                XCTAssertEqual(self.int(sqliteValue)!, 0)
                XCTAssertEqual(self.int64(sqliteValue)!, Int64(0))
                XCTAssertEqual(self.double(sqliteValue)!, 0.0)
                XCTAssertTrue(self.string(sqliteValue) == nil)
                XCTAssertTrue(self.blob(sqliteValue) == nil)
                
                return .Rollback
            }
            
            // "3.0e+5" is turned to Text
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (noneAffinity) VALUES (?)", bindings: ["3.0e+5"])
                let sqliteValue = db.fetchOneRow("SELECT noneAffinity FROM `values`")!.sqliteValue(atIndex: 0)
                XCTAssertEqual(sqliteValue.storageClass, SQLiteStorageClass.Text)
                
                // Check built-in conversions from Text storage
                XCTAssertTrue(self.bool(sqliteValue) == nil)
                XCTAssertTrue(self.int(sqliteValue) == nil)
                XCTAssertTrue(self.int64(sqliteValue) == nil)
                XCTAssertTrue(self.double(sqliteValue) == nil)
                XCTAssertEqual(self.string(sqliteValue)!, "3.0e+5")
                XCTAssertTrue(self.blob(sqliteValue) == nil)
                
                return .Rollback
            }
            
            // Blob is turned to Blob
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (noneAffinity) VALUES (?)", bindings: [Blob("foo".dataUsingEncoding(NSUTF8StringEncoding))])
                let sqliteValue = db.fetchOneRow("SELECT noneAffinity FROM `values`")!.sqliteValue(atIndex: 0)
                XCTAssertEqual(sqliteValue.storageClass, SQLiteStorageClass.Blob)
                
                // Check built-in conversions from Blob storage
                XCTAssertTrue(self.bool(sqliteValue) == nil)
                XCTAssertTrue(self.int(sqliteValue) == nil)
                XCTAssertTrue(self.int64(sqliteValue) == nil)
                XCTAssertTrue(self.double(sqliteValue) == nil)
                XCTAssertTrue(self.string(sqliteValue) == nil)
                XCTAssertTrue(self.blob(sqliteValue)!.data .isEqualToData("foo".dataUsingEncoding(NSUTF8StringEncoding)!))
                
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
            
            // Integer is turned to Integer
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (\(columnName)) VALUES (?)", bindings: [0])
                let sqliteValue = db.fetchOneRow("SELECT \(columnName) FROM `values`")!.sqliteValue(atIndex: 0)
                XCTAssertEqual(sqliteValue.storageClass, SQLiteStorageClass.Integer)
                
                // Check built-in conversions from Integer storage
                XCTAssertEqual(self.bool(sqliteValue)!, false)
                XCTAssertEqual(self.int(sqliteValue)!, 0)
                XCTAssertEqual(self.int64(sqliteValue)!, Int64(0))
                XCTAssertEqual(self.double(sqliteValue)!, 0.0)
                XCTAssertTrue(self.string(sqliteValue) == nil)
                XCTAssertTrue(self.blob(sqliteValue) == nil)
                
                return .Rollback
            }
            
            // 3.0e5 Double is turned to Integer
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (\(columnName)) VALUES (?)", bindings: [3.0e5])
                let sqliteValue = db.fetchOneRow("SELECT \(columnName) FROM `values`")!.sqliteValue(atIndex: 0)
                XCTAssertEqual(sqliteValue.storageClass, SQLiteStorageClass.Integer)
                
                // Check built-in conversions from Integer storage
                XCTAssertEqual(self.bool(sqliteValue)!, true)
                XCTAssertEqual(self.int(sqliteValue)!, 300000)
                XCTAssertEqual(self.int64(sqliteValue)!, Int64(300000))
                XCTAssertEqual(self.double(sqliteValue)!, Double(300000))
                XCTAssertTrue(self.string(sqliteValue) == nil)
                XCTAssertTrue(self.blob(sqliteValue) == nil)
                
                return .Rollback
            }
            
            // 1.0e20 Double is turned to Real
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (\(columnName)) VALUES (?)", bindings: [1.0e20])
                let sqliteValue = db.fetchOneRow("SELECT \(columnName) FROM `values`")!.sqliteValue(atIndex: 0)
                XCTAssertEqual(sqliteValue.storageClass, SQLiteStorageClass.Real)
                
                // Check built-in conversions from Real storage (avoid Int and Int64 since 1.0e20 does not fit)
                XCTAssertEqual(self.bool(sqliteValue)!, true)
                XCTAssertEqual(self.double(sqliteValue)!, 1e20)
                XCTAssertTrue(self.string(sqliteValue) == nil)
                XCTAssertTrue(self.blob(sqliteValue) == nil)
                
                return .Rollback
            }
            
            // "3.0e+5" is turned to Integer
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (\(columnName)) VALUES (?)", bindings: ["3.0e+5"])
                let sqliteValue = db.fetchOneRow("SELECT \(columnName) FROM `values`")!.sqliteValue(atIndex: 0)
                XCTAssertEqual(sqliteValue.storageClass, SQLiteStorageClass.Integer)
                
                // Check built-in conversions from Integer storage
                XCTAssertEqual(self.bool(sqliteValue)!, true)
                XCTAssertEqual(self.int(sqliteValue)!, 300000)
                XCTAssertEqual(self.int64(sqliteValue)!, Int64(300000))
                XCTAssertEqual(self.double(sqliteValue)!, Double(300000))
                XCTAssertTrue(self.string(sqliteValue) == nil)
                XCTAssertTrue(self.blob(sqliteValue) == nil)
                
                return .Rollback
            }
            
            // "1.0e+20" is turned to Real
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (\(columnName)) VALUES (?)", bindings: ["1.0e+20"])
                let sqliteValue = db.fetchOneRow("SELECT \(columnName) FROM `values`")!.sqliteValue(atIndex: 0)
                XCTAssertEqual(sqliteValue.storageClass, SQLiteStorageClass.Real)
                
                // Check built-in conversions from Real storage: (avoid Int and Int64 since 1.0e20 does not fit)
                XCTAssertEqual(self.bool(sqliteValue)!, true)
                XCTAssertEqual(self.double(sqliteValue)!, 1e20)
                XCTAssertTrue(self.string(sqliteValue) == nil)
                XCTAssertTrue(self.blob(sqliteValue) == nil)
                
                return .Rollback
            }
            
            // "foo" is turned to Text
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (\(columnName)) VALUES (?)", bindings: ["foo"])
                let sqliteValue = db.fetchOneRow("SELECT \(columnName) FROM `values`")!.sqliteValue(atIndex: 0)
                XCTAssertEqual(sqliteValue.storageClass, SQLiteStorageClass.Text)
                
                // Check built-in conversions from Text storage:
                XCTAssertTrue(self.bool(sqliteValue) == nil)
                XCTAssertTrue(self.int(sqliteValue) == nil)
                XCTAssertTrue(self.int64(sqliteValue) == nil)
                XCTAssertTrue(self.double(sqliteValue) == nil)
                XCTAssertEqual(self.string(sqliteValue)!, "foo")
                XCTAssertTrue(self.blob(sqliteValue) == nil)
                
                return .Rollback
            }
            
            // Blob is turned to Blob
            
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO `values` (\(columnName)) VALUES (?)", bindings: [Blob("foo".dataUsingEncoding(NSUTF8StringEncoding))])
                let sqliteValue = db.fetchOneRow("SELECT \(columnName) FROM `values`")!.sqliteValue(atIndex: 0)
                XCTAssertEqual(sqliteValue.storageClass, SQLiteStorageClass.Blob)
                
                // Check built-in conversions from Blob storage:
                XCTAssertTrue(self.bool(sqliteValue) == nil)
                XCTAssertTrue(self.int(sqliteValue) == nil)
                XCTAssertTrue(self.int64(sqliteValue) == nil)
                XCTAssertTrue(self.double(sqliteValue) == nil)
                XCTAssertTrue(self.string(sqliteValue) == nil)
                XCTAssertTrue(self.blob(sqliteValue)!.data .isEqualToData("foo".dataUsingEncoding(NSUTF8StringEncoding)!))
                
                return .Rollback
            }
        }
    }
}

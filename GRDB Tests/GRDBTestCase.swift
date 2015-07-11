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
import GRDB

struct DBDate: DatabaseValueConvertible {
    
    // NSDate conversion
    //
    // It is good to consistently use the Swift nil to represent the database
    // NULL: the date property is a non-optional NSDate, and the NSDate
    // initializer is failable:
    
    // The represented date
    let date: NSDate
    
    // Creates a DBDate from an NSDate.
    // Returns nil if and only if the NSDate is nil.
    init?(_ date: NSDate?) {
        if let date = date {
            self.date = date
        } else {
            return nil
        }
    }
    
    // DatabaseValue conversion
    //
    // DBDate represents the date as an ISO-8601 string in the database.
    
    // An ISO-8601 date formatter
    static let dateFormatter: NSDateFormatter = {
        let formatter = NSDateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        formatter.locale = NSLocale(localeIdentifier: "en_US_POSIX")
        formatter.timeZone = NSTimeZone(forSecondsFromGMT: 0)
        return formatter
    }()
    
    var databaseValue: DatabaseValue {
        return .Text(DBDate.dateFormatter.stringFromDate(date))
    }
    
    init?(databaseValue: DatabaseValue) {
        // Don't handle the raw DatabaseValue unless you know what you do.
        // It is recommended to use GRDB built-in conversions instead:
        if let string = String(databaseValue: databaseValue) {
            self.init(DBDate.dateFormatter.dateFromString(string))
        } else {
            return nil
        }
    }
}

class GRDBTestCase: XCTestCase {
    var databasePath: String!
    var dbQueue: DatabaseQueue!
    var sqlQueries: [String]!
    
    override func setUp() {
        super.setUp()
        
        sqlQueries = []
        databasePath = "/tmp/GRDB.sqlite"
        do { try NSFileManager.defaultManager().removeItemAtPath(databasePath) } catch { }
        let configuration = Configuration(trace: { (sql, bindings) in
            self.sqlQueries.append(sql)
            NSLog("GRDB: %@", sql)
            if let bindings = bindings {
                NSLog("GRDB: bindings %@", bindings.description)
            }
        })
        dbQueue = try! DatabaseQueue(path: databasePath, configuration: configuration)
    }
    
    override func tearDown() {
        super.tearDown()
        
        dbQueue = nil
        try! NSFileManager.defaultManager().removeItemAtPath(databasePath)
    }
    
    func assertNoError(@noescape test: (Void) throws -> Void) {
        do {
            try test()
        } catch let error as DatabaseError {
            XCTFail(error.description)
        } catch let error as RowModelError {
            XCTFail(error.description)
        } catch {
            XCTFail("error: \(error)")
        }
    }
}

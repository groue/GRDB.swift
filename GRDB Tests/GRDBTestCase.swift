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

class GRDBTestCase: XCTestCase {
    var databasePath: String!
    var dbQueue: DatabaseQueue!
    var sqlQueries: [String]!
    
    override func setUp() {
        super.setUp()
        
        sqlQueries = []
        databasePath = "/tmp/GRDB.sqlite"
        do { try NSFileManager.defaultManager().removeItemAtPath(databasePath) } catch { }
        let configuration = Configuration(trace: { (sql, arguments) in
            self.sqlQueries.append(sql)
            NSLog("GRDB: %@", sql)
            if let arguments = arguments {
                NSLog("GRDB: arguments %@", arguments.description)
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

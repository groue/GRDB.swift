//
//  GRDBTests.swift
//  GRDB
//
//  Created by Gwendal Roué on 01/07/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

import XCTest
import GRDB

class GRDBTests: XCTestCase {
    
    func assertNoError(@noescape test: (Void) throws -> Void) {
        do {
            try test()
        } catch let error as SQLiteError {
            if let sql = error.sql {
                XCTFail("error code \(error.code) executing \(sql): \(error.message)")
            } else {
                XCTFail("error code \(error.code): \(error.message)")
            }
        } catch {
            XCTFail("error: \(error)")
        }
    }
}

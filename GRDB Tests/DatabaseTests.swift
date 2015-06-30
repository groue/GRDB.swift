//
//  DatabaseTests.swift
//  GRDB
//
//  Created by Gwendal Roué on 30/06/2015.
//  Copyright © 2015 Stephen Celis. All rights reserved.
//

import XCTest
import GRDB

class DatabaseTests: XCTestCase {
    
    func testDatabase() {
        do {
            let database = try Database(path: "/tmp/GRDB.sqlite")
        } catch {
            
        }
    }
}

//
//  RowModelTests.swift
//  GRDB
//
//  Created by Gwendal Roué on 01/07/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

import XCTest
import GRDB

class RowModelTests : GRDBTestCase {
    override func setUp() {
        super.setUp()
        
        var migrator = DatabaseMigrator()
        
        migrator.registerMigration("createPersons", Person.setupInDatabase)
        migrator.registerMigration("createPets", Pet.setupInDatabase)
        migrator.registerMigration("createItems", Item.setupInDatabase)
        migrator.registerMigration("createCitizenships", Citizenship.setupInDatabase)
        
        assertNoError {
            try migrator.migrate(dbQueue)
        }
    }
}

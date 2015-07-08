//
//  RowModelDescriptionTests.swift
//  GRDB
//
//  Created by Gwendal Roué on 05/07/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

import XCTest
import GRDB

class EmptyRowModel : RowModel {
}

class SingleColumnRowModel : RowModel {
    var name: String?
    
    override var storedDatabaseDictionary: [String: SQLiteValueConvertible?] {
        return ["name": name]
    }
}

class DoubleColumnRowModel : RowModel {
    var name: String?
    var age: Int?
    
    override var storedDatabaseDictionary: [String: SQLiteValueConvertible?] {
        return ["name": name, "age": age]
    }
}

class RowModelDescriptionTests: RowModelTestCase {

    func testEmptyRowModelDescription() {
        let model = EmptyRowModel()
        XCTAssertEqual(model.description, "<GRDBTests.EmptyRowModel>")
    }
    
    func testSimpleRowModelDescription() {
        let model = SingleColumnRowModel()
        model.name = "foo"
        XCTAssertEqual(model.description, "<GRDBTests.SingleColumnRowModel name:\"foo\">")
    }
    
    func testDoubleColumnRowModelDescription() {
        let model = DoubleColumnRowModel()
        model.name = "foo"
        model.age = 35
        XCTAssertTrue(["<GRDBTests.DoubleColumnRowModel name:\"foo\" age:35>", "<GRDBTests.DoubleColumnRowModel age:35 name:\"foo\">"].indexOf(model.description) != nil)
    }

}

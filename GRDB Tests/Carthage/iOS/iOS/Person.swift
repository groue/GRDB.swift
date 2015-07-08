//
//  Person.swift
//  iOS
//
//  Created by Gwendal Roué on 08/07/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

import Foundation
import GRDB

class Person : RowModel {
    var id: Int64!
    var firstName: String?
    var lastName: String?
    var fullName: String {
        return " ".join([firstName, lastName].filter { $0 != nil }.map { $0! })
    }
    
    init(firstName: String? = nil, lastName: String? = nil) {
        self.firstName = firstName
        self.lastName = lastName
        super.init()
    }
    
    // MARK: - RowModel
    
    override class var databaseTable: Table? {
        return Table(named: "persons", primaryKey: .RowID("id"))
    }
    
    override func setSQLiteValue(sqliteValue: SQLiteValue, forColumn column: String) {
        switch column {
        case "id": id = sqliteValue.value()
        case "firstName": firstName = sqliteValue.value()
        case "lastName": lastName = sqliteValue.value()
        default: super.setSQLiteValue(sqliteValue, forColumn: column)
        }
    }
    
    override var storedDatabaseDictionary: [String: SQLiteValueConvertible?] {
        return [
            "id": id,
            "firstName": firstName,
            "lastName": lastName]
    }

    required init(row: Row) {
        super.init(row: row)
    }
}

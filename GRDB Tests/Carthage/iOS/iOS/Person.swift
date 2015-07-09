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
    
    override func setDatabaseValue(dbv: DatabaseValue, forColumn column: String) {
        switch column {
        case "id": id = dbv.value()
        case "firstName": firstName = dbv.value()
        case "lastName": lastName = dbv.value()
        default: super.setDatabaseValue(dbv, forColumn: column)
        }
    }
    
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return [
            "id": id,
            "firstName": firstName,
            "lastName": lastName]
    }

    required init(row: Row) {
        super.init(row: row)
    }
}

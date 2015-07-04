//
//  Bindings.swift
//  GRDB
//
//  Created by Gwendal Roué on 02/07/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

protocol BindingsImpl {
    func bindInStatement(statement: Statement)
    func dictionary(defaultColumnNames defaultColumnNames: [String]?) -> [String: SQLiteValueConvertible?]
}

public struct Bindings {
    let impl: BindingsImpl
    
    // Bindings([SQLiteValueConvertible?])
    //
    // Supported usage:
    //
    //     db.execute("INSERT ... (?,?,?)",
    //                bindings: Bindings(rowModel.databaseDictionary.values))
    public init<Sequence: SequenceType where Sequence.Generator.Element == Optional<SQLiteValueConvertible>>(_ array: Sequence) {
        impl = BindingsArrayImpl(array: Array(array))
    }
    
    // Bindings([SQLiteValueConvertible])
    //
    // No known usage yet.
    public init<Sequence: SequenceType where Sequence.Generator.Element == SQLiteValueConvertible>(_ array: Sequence) {
        impl = BindingsArrayImpl(array: array.map { $0 })
    }
    
    // Bindings(NSArray)
    //
    // This is a convenience initializer.
    //
    // Without it, the following code won't compile:
    //
    //    let statement = try db.updateStatement("INSERT INTO persons (name, age) VALUES (?, ?)")
    //    let persons = [
    //        ["Arthur", 41],
    //        ["Barbara"],
    //    ]
    //    for person in persons {
    //        statement.clearBindings()
    //        statement.bind(Bindings(person))  // Error
    //        try statement.execute()
    //    }
    public init(_ array: NSArray) {
        var values = [SQLiteValueConvertible?]()
        for item in array {
            values.append(Bindings.valueFromAnyObject(item))
        }
        self.init(values)
    }
    
    // Bindings([String: SQLiteValueConvertible?])
    //
    // Supported usage: DictionaryLiteralConvertible adoption:
    //
    //     db.execute("INSERT ... (:name, :age)",
    //                bindings: ["name"; "Arthur", "age": 41])
    public init(_ dictionary: [String: SQLiteValueConvertible?]) {
        impl = BindingsDictionaryImpl(dictionary: dictionary)
    }
    
    // Bindings(NSDictionary)
    //
    // This is a convenience initializer.
    //
    // Without it, the following code won't compile:
    //
    //    let statement = try db.updateStatement("INSERT INTO persons (name, age) VALUES (:name, :age)")
    //    let persons = [
    //        ["name": "Arthur", "age": 41],
    //        ["name": "Barbara"],
    //    ]
    //    for person in persons {
    //        statement.clearBindings()
    //        statement.bind(Bindings(person))  // Error
    //        try statement.execute()
    //    }
    public init(_ dictionary: NSDictionary) {
        var values = [String: SQLiteValueConvertible?]()
        for (key, item) in dictionary {
            if let key = key as? String {
                values[key] = Bindings.valueFromAnyObject(item)
            } else {
                fatalError("Not a String key: \(key)")
            }
        }
        self.init(values)
    }
    
    // Supported uage: Statement.bindings property
    //
    //     let statement = db.UpdateStatement("INSERT INTO persons (name, age) VALUES (?,?)"
    //     statement.bindings = ["Arthur", 41]
    //     statement.execute()
    func bindInStatement(statement: Statement) {
        impl.bindInStatement(statement)
    }
    
    // Supported usage: loading of RowModel by multiple-columns primary keys:
    //
    //     let person = db.fetchOne(Person.self, primaryKey: Bindings)
    func dictionary(defaultColumnNames defaultColumnNames: [String]?) -> [String: SQLiteValueConvertible?] {
        return impl.dictionary(defaultColumnNames: defaultColumnNames)
    }
    
    private struct BindingsArrayImpl : BindingsImpl {
        let array: [SQLiteValueConvertible?]
        init(array: [SQLiteValueConvertible?]) {
            self.array = array
        }
        func bindInStatement(statement: Statement) {
            for (index, value) in array.enumerate() {
                statement.bind(value, atIndex: index + 1)
            }
        }
        func dictionary(defaultColumnNames defaultColumnNames: [String]?) -> [String : SQLiteValueConvertible?] {
            guard let defaultColumnNames = defaultColumnNames else {
                fatalError("Missing column names")
            }
            guard defaultColumnNames.count == array.count else {
                fatalError("Columns count mismatch.")
            }
            var dictionary = [String : SQLiteValueConvertible?]()
            for (column, value) in zip(defaultColumnNames, array) {
                dictionary[column] = value
            }
            return dictionary
        }
    }
    
    private struct BindingsDictionaryImpl : BindingsImpl {
        let dictionary: [String: SQLiteValueConvertible?]
        init(dictionary: [String: SQLiteValueConvertible?]) {
            self.dictionary = dictionary
        }
        func bindInStatement(statement: Statement) {
            for (key, value) in dictionary {
                statement.bind(value, forKey: key)
            }
        }
        func dictionary( defaultColumnNames defaultColumnNames: [String]?) -> [String : SQLiteValueConvertible?] {
            return dictionary
        }
    }
    
    // IMPLEMENTATION NOTE:
    //
    // NSNumber, NSString, NSNull can't adopt SQLiteValueConvertible because
    // Swift 2 won't make it possible.
    //
    // This is why this method exists. As a convenience for init(NSArray)
    // and init(NSDictionary), themselves conveniences for the library user.
    private static func valueFromAnyObject(object: AnyObject) -> SQLiteValueConvertible? {
        
        switch object {
        case let value as SQLiteValueConvertible:
            return value
        case _ as NSNull:
            return nil
        case let string as NSString:
            return string as String
        case let number as NSNumber:
            let objCType = String.fromCString(number.objCType)!
            switch objCType {
            case "c":
                return Int64(number.charValue)
            case "C":
                return Int64(number.unsignedCharValue)
            case "s":
                return Int64(number.shortValue)
            case "S":
                return Int64(number.unsignedShortValue)
            case "i":
                return Int64(number.intValue)
            case "I":
                return Int64(number.unsignedIntValue)
            case "l":
                return Int64(number.longValue)
            case "L":
                return Int64(number.unsignedLongValue)
            case "q":
                return Int64(number.longLongValue)
            case "Q":
                return Int64(number.unsignedLongLongValue)
            case "f":
                return Double(number.floatValue)
            case "d":
                return number.doubleValue
            case "B":
                return number.boolValue
            default:
                fatalError("Not a SQLiteValueConvertible: \(object)")
            }
        default:
            fatalError("Not a SQLiteValueConvertible: \(object)")
        }
    }
}

extension Bindings : ArrayLiteralConvertible {
    // Supported usage:
    //
    //     db.selectRows("SELECT ...", bindings: ["Arthur", 41])
    public init(arrayLiteral elements: SQLiteValueConvertible?...) {
        self.init(elements)
    }
}

extension Bindings : DictionaryLiteralConvertible {
    // Supported usage:
    //
    //     db.selectRows("SELECT ...", bindings: ["name": "Arthur", "age": 41])
    public init(dictionaryLiteral elements: (String, SQLiteValueConvertible?)...) {
        var dictionary = [String: SQLiteValueConvertible?]()
        for (key, value) in elements {
            dictionary[key] = value
        }
        self.init(dictionary)
    }
}

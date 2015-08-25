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


import Foundation

/**
SQL statements can have arguments:

    INSERT INTO persons (name, age) VALUES (?, ?)
    INSERT INTO persons (name, age) VALUES (:name, :age)

To fill question mark arguments, feed StatementArguments with an array:

    db.execute("INSERT ... (?, ?)", arguments: StatementArguments(["Arthur", 41]))

Array literals are automatically converted to StatementArguments:

    db.execute("INSERT ... (?, ?)", arguments: ["Arthur", 41])

To fill named arguments, feed StatementArguments with a dictionary:

    db.execute("INSERT ... (:name, :age)", arguments: StatementArguments(["name": "Arthur", "age": 41]))

Dictionary literals are automatically converted to StatementArguments:

    db.execute("INSERT ... (:name, :age)", arguments: ["name": "Arthur", "age": 41])

GRDB.swift only supports colon-prefixed named arguments, even though SQLite
supports other syntaxes. See https://www.sqlite.org/lang_expr.html#varparam for
more information.
*/
public struct StatementArguments {
    
    // MARK: - Positional Arguments
    
    /**
    Initializes arguments from a sequence of optional values.
    
        let values: [String?] = ["foo", "bar", nil]
        db.execute("INSERT ... (?,?,?)", arguments: StatementArguments(values))
    
    - parameter sequence: A sequence of optional values that adopt the
                          DatabaseValueConvertible protocol.
    - returns: A StatementArguments.
    */
    public init<Sequence: SequenceType where Sequence.Generator.Element == Optional<DatabaseValueConvertible>>(_ sequence: Sequence) {
        impl = StatementArgumentsArrayImpl(values: Array(sequence))
    }
    
    /**
    Initializes arguments from an NSArray.
    
    The array must contain objects that adopt the DatabaseValueConvertible
    protocol, NSNull, NSNumber or NSString. A fatal error is thrown otherwise.
    
        let values: NSArray = ["foo", "bar", "baz"]
        db.execute("INSERT ... (?,?,?)", arguments: StatementArguments(values))
    
    - parameter array: An NSArray
    - returns: A StatementArguments.
    */
    public init(_ array: NSArray) {
        // IMPLEMENTATION NOTE
        //
        // This initializer is required for the following code to compile:
        //
        //    let statement = try db.updateStatement("INSERT INTO persons (name, age) VALUES (?, ?)")
        //    let persons = [   // NSArray of NSArray, actually
        //        ["Arthur", 41],
        //        ["Barbara"],
        //    ]
        //    for person in persons {
        //        try statement.execute(StatementArguments(person))   // Avoid an error here
        //    }
        var values = [DatabaseValueConvertible?]()
        for item in array {
            values.append(StatementArguments.valueFromAnyObject(item))
        }
        self.init(values)
    }
    
    
    // MARK: - Named Arguments
    
    /**
    Initializes arguments from a dictionary of optional values.
    
        let values: [String: String?] = ["firstName": nil, "lastName": "Miller"]
        db.execute("INSERT ... (:firstName, :lastName)", arguments: StatementArguments(values))
    
    GRDB.swift only supports colon-prefixed named arguments, even though SQLite
    supports other syntaxes. See https://www.sqlite.org/lang_expr.html#varparam
    for more information.
    
    - parameter dictionary: A dictionary of optional values that adopt the
                            DatabaseValueConvertible protocol.
    - returns: A StatementArguments.
    */
    public init(_ dictionary: [String: DatabaseValueConvertible?]) {
        impl = StatementArgumentsDictionaryImpl(dictionary: dictionary)
    }
    
    /**
    Initializes arguments from an NSDictionary.
    
    The dictionary must contain objects that adopt the DatabaseValueConvertible
    protocol, NSNull, NSNumber or NSString. A fatal error is thrown otherwise.
    
        let values: NSDictionary = ["firstName": "Arthur", "lastName": "Miller"]
        db.execute("INSERT ... (?,?,?)", arguments: StatementArguments(values))
    
    GRDB.swift only supports colon-prefixed named arguments, even though SQLite
    supports other syntaxes. See https://www.sqlite.org/lang_expr.html#varparam
    for more information.
    
    - parameter dictionary: An NSDictionary
    - returns: A StatementArguments.
    */
    public init(_ dictionary: NSDictionary) {
        // IMPLEMENTATION NOTE
        //
        // This initializer is required for the following code to compile:
        //
        //    let statement = try db.updateStatement("INSERT INTO persons (name, age) VALUES (:name, :age)")
        //    let persons = [   // NSArray of NSDictionary, actually
        //        ["name": "Arthur", "age": 41],
        //        ["name": "Barbara"],
        //    ]
        //    for person in persons {
        //        try statement.execute(StatementArguments(person))   // Avoid an error here
        //    }
        var values = [String: DatabaseValueConvertible?]()
        for (key, item) in dictionary {
            if let key = key as? String {
                values[key] = StatementArguments.valueFromAnyObject(item)
            } else {
                fatalError("Not a String key: \(key)")
            }
        }
        self.init(values)
    }
    
    
    // MARK: - Not Public
    
    let impl: StatementArgumentsImpl
    
    // Supported usage: Statement.arguments property
    //
    //     let statement = db.UpdateStatement("INSERT INTO persons (name, age) VALUES (?,?)"
    //     statement.execute(arguments: ["Arthur", 41])
    func bindInStatement(statement: Statement) {
        impl.bindInStatement(statement)
    }
    
    
    // MARK: - StatementArgumentsArrayImpl
    
    /// Support for positional arguments
    private struct StatementArgumentsArrayImpl : StatementArgumentsImpl {
        let values: [DatabaseValueConvertible?]
        
        init(values: [DatabaseValueConvertible?]) {
            self.values = values
        }
        
        func bindInStatement(statement: Statement) {
            for (index, value) in values.enumerate() {
                statement.bind(value, atIndex: index + 1)
            }
        }
        
        var description: String {
            return "["
                + values
                    .map { value in
                        if let value = value {
                            return String(reflecting: value)
                        } else {
                            return "nil"
                        }
                    }
                    .joinWithSeparator(", ")
                + "]"
        }
    }
    
    
    // MARK: - StatementArgumentsDictionaryImpl
    
    /// Support for named arguments
    private struct StatementArgumentsDictionaryImpl : StatementArgumentsImpl {
        let dictionary: [String: DatabaseValueConvertible?]
        
        init(dictionary: [String: DatabaseValueConvertible?]) {
            self.dictionary = dictionary
        }
        
        func bindInStatement(statement: Statement) {
            for (key, value) in dictionary {
                statement.bind(value, forKey: key)
            }
        }
        
        var description: String {
            return "["
                + dictionary.map { (key, value) in
                    if let value = value {
                        return "\(key):\(String(reflecting: value))"
                    } else {
                        return "\(key):nil"
                    }
                    }
                    .joinWithSeparator(", ")
                + "]"
        }
    }
    
    // IMPLEMENTATION NOTE:
    //
    // NSNumber, NSString, NSNull can't adopt DatabaseValueConvertible because
    // DatabaseValueConvertible has a Self reference which prevents non-final
    // classes to adopt it.
    //
    // This is why this method exists. As a convenience for init(NSArray)
    // and init(NSDictionary), themselves conveniences for the library user.
    private static func valueFromAnyObject(object: AnyObject) -> DatabaseValueConvertible? {
        
        switch object {
        case let value as DatabaseValueConvertible:
            return value
        case _ as NSNull:
            return nil
        case let data as NSData:
            return Blob(data)
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
                fatalError("Not a DatabaseValueConvertible: \(object)")
            }
        default:
            fatalError("Not a DatabaseValueConvertible: \(object)")
        }
    }
}


// The protocol for StatementArguments underlying implementation
protocol StatementArgumentsImpl : CustomStringConvertible {
    func bindInStatement(statement: Statement)
}


// MARK: - ArrayLiteralConvertible

extension StatementArguments : ArrayLiteralConvertible {
    /**
    Returns a StatementArguments from an array literal:

        db.selectRows("SELECT ...", arguments: ["Arthur", 41])
    */
    public init(arrayLiteral elements: DatabaseValueConvertible?...) {
        self.init(elements)
    }
}


// MARK: - DictionaryLiteralConvertible

extension StatementArguments : DictionaryLiteralConvertible {
    /**
    Returns a StatementArguments from a dictionary literal:
    
        db.selectRows("SELECT ...", arguments: ["name": "Arthur", "age": 41])
    */
    public init(dictionaryLiteral elements: (String, DatabaseValueConvertible?)...) {
        var dictionary = [String: DatabaseValueConvertible?]()
        for (key, value) in elements {
            dictionary[key] = value
        }
        self.init(dictionary)
    }
}


// MARK: - CustomStringConvertible

extension StatementArguments : CustomStringConvertible {
    /// A textual representation of `self`.
    public var description: String {
        return impl.description
    }
}
import Foundation

extension StatementArguments {
    
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
        //        ["Barbara", 38],
        //    ]
        //    for person in persons {
        //        try statement.execute(StatementArguments(person))   // Avoid an error here
        //    }
        var values = [DatabaseValueConvertible?]()
        for object in array {
            switch object {
            case let value as DatabaseValueConvertible:
                values.append(value)
            default:
                fatalError("Not DatabaseValueConvertible: \(object)")
            }
        }
        self.init(values)
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
        //        ["name": "Barbara", "age": 38],
        //    ]
        //    for person in persons {
        //        try statement.execute(StatementArguments(person))   // Avoid an error here
        //    }
        var values = [String: DatabaseValueConvertible?]()
        for (key, object) in dictionary {
            if let key = key as? String {
                switch object {
                case let value as DatabaseValueConvertible:
                    values[key] = value
                default:
                    fatalError("Not DatabaseValueConvertible: \(object)")
                }
            } else {
                fatalError("Not a String key: \(key)")
            }
        }
        self.init(values)
    }
}
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
            return data
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
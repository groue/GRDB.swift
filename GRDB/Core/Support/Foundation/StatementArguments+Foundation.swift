import Foundation

extension StatementArguments {
    
    // MARK: Positional Arguments
    
    /// Initializes arguments from an NSArray.
    ///
    /// The result is nil unless all objects adopt DatabaseValueConvertible
    /// (NSData, NSDate, NSNull, NSNumber, NSString, NSURL).
    ///
    ///     let values: NSArray = ["foo", "bar", "baz"]
    ///     db.execute("INSERT ... (?,?,?)", arguments: StatementArguments(values)!)
    ///
    /// - parameter array: An NSArray
    /// - returns: A StatementArguments.
    public init?(_ array: NSArray) {
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
            guard let databaseValue = DatabaseValue(object: object) else {
                return nil
            }
            values.append(databaseValue)
        }
        self.init(values)
    }
    
    
    // MARK: Named Arguments
    
    /// Initializes arguments from an NSDictionary.
    ///
    /// The result is nil unless all dictionary keys are strings, and values
    /// adopt DatabaseValueConvertible (NSData, NSDate, NSNull, NSNumber,
    /// NSString, NSURL).
    ///
    ///     let values: NSDictionary = ["firstName": "Arthur", "lastName": "Miller"]
    ///     db.execute("INSERT ... (?,?,?)", arguments: StatementArguments(values)!)
    ///
    /// - parameter dictionary: An NSDictionary
    /// - returns: A StatementArguments.
    public init?(_ dictionary: NSDictionary) {
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
        var initDictionary = [String: DatabaseValueConvertible?]()
        for (key, value) in dictionary {
            guard let columnName = key as? String else {
                return nil
            }
            guard let databaseValue = DatabaseValue(object: value) else {
                return nil
            }
            initDictionary[columnName] = databaseValue
        }
        self.init(initDictionary)
    }
}
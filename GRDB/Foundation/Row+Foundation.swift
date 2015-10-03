import Foundation

/// Foundation support for Row
extension Row {
    
    /**
    Builds a row from an NSDictionary.
    
    All keys must be strings, and values must adopt DatabaseValueConvertible:
    NSData, NSDate, NSNull, NSNumber, NSString, NSURL.
    
    - parameter dictionary: An NSDictionary.
    */
    public convenience init(dictionary: NSDictionary) {
        var initDictionary = [String: DatabaseValueConvertible?]()
        for (key, value) in dictionary {
            guard let columnName = key as? String else {
                fatalError("Dictionary key is not a string: \(key)")
            }
            guard let convertible = value as? DatabaseValueConvertible else {
                fatalError("Dictionary value is not a string: \(key)")
            }
            initDictionary[columnName] = convertible.databaseValue // Because databaseValue adopts DatabaseValueConvertible?
        }
        self.init(dictionary: initDictionary)
    }
    
    /**
    Converts a row to an NSDictionary.
    
    When the row contains duplicated column names, the dictionary contains the
    value of the leftmost column.
    
    - returns: An NSDictionary.
    */
    public func toDictionary() -> NSDictionary {
        var dictionary = [NSObject: AnyObject]()
        // Reverse so that the result dictionary contains values for the leftmost columns.
        for (columnName, databaseValue) in reverse() {
            switch databaseValue.storage {
            case .Null:
                dictionary[columnName] = NSNull()
            case .Int64(let int64):
                dictionary[columnName] = NSNumber(longLong: int64)
            case .Double(let double):
                dictionary[columnName] = NSNumber(double: double)
            case .String(let string):
                dictionary[columnName] = string as NSString
            case .Blob(let blob):
                dictionary[columnName] = blob.data
            }
        }
        return dictionary
    }
}

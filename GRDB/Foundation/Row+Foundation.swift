import Foundation

/// Foundation support for Row
extension Row {
    
    /// Builds a row from an NSDictionary.
    ///
    /// The result is nil unless all dictionary keys are strings, and values
    /// adopt DatabaseValueConvertible (NSData, NSDate, NSNull, NSNumber,
    /// NSString, NSURL).
    ///
    /// - parameter dictionary: An NSDictionary.
    public convenience init?(dictionary: NSDictionary) {
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
        self.init(dictionary: initDictionary)
    }
    
    /// Converts a row to an NSDictionary.
    ///
    /// When the row contains duplicated column names, the dictionary contains
    /// the value of the leftmost column.
    ///
    /// - returns: An NSDictionary.
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
            case .Blob(let data):
                dictionary[columnName] = data
            }
        }
        return dictionary
    }
}

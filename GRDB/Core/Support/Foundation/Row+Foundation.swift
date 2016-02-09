import Foundation

/// Foundation support for Row
extension Row {
    
    /// Builds a row from an NSDictionary.
    ///
    /// The result is nil unless all dictionary keys are strings, and values
    /// adopt DatabaseValueConvertible (NSData, NSDate, NSNull, NSNumber,
    /// NSString, NSURL).
    public convenience init?(_ dictionary: NSDictionary) {
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
    
    /// Converts a row to an NSDictionary.
    ///
    /// When the row contains duplicated column names, the dictionary contains
    /// the value of the leftmost column.
    ///
    /// - returns: An NSDictionary.
    public func toNSDictionary() -> NSDictionary {
        let dictionary = NSMutableDictionary(capacity: count)
        // Reverse so that the result dictionary contains values for the leftmost columns.
        for (columnName, databaseValue) in reverse() {
            dictionary[columnName] = databaseValue.toAnyObject()
        }
        return dictionary
    }
}

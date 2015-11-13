import Foundation

/// Foundation support for DatabaseValue
extension DatabaseValue {
    
    /// Builds a DatabaseValue from AnyObject.
    ///
    /// The result is nil unless object adopts DatabaseValueConvertible (NSData,
    /// NSDate, NSNull, NSNumber, NSString, NSURL).
    ///
    /// - parameter object: An AnyObject.
    public init?(object: AnyObject) {
        guard let convertible = object as? DatabaseValueConvertible else {
            return nil
        }
        self.init(convertible.databaseValue)
    }
}

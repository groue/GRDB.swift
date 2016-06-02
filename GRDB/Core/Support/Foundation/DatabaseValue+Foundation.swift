import Foundation

/// Foundation support for DatabaseValue
extension DatabaseValue {
    
    /// Builds a DatabaseValue from AnyObject.
    ///
    /// The result is nil unless object adopts DatabaseValueConvertible (NSData,
    /// NSDate, NSNull, NSNumber, NSString, NSURL).
    public init?(object: AnyObject) {
        guard let convertible = object as? DatabaseValueConvertible else {
            return nil
        }
        self = convertible.databaseValue
    }
    
    /// Converts a DatabaseValue to AnyObject.
    ///
    /// - returns: NSNull, NSNumber, NSString, or NSData.
    public func toAnyObject() -> AnyObject {
        switch storage {
        case .null:
            return NSNull()
        case .int64(let int64):
            return NSNumber(value: int64)
        case .double(let double):
            return NSNumber(value: double)
        case .string(let string):
            return string as NSString
        case .blob(let data):
            return data
        }
    }
}

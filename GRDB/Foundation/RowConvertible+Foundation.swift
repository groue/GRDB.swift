import Foundation

extension RowConvertible {
    
    /// NSDictionary initializer.
    ///
    /// The result is nil unless all keys are strings, and values adopt
    /// DatabaseValueConvertible (NSData, NSDate, NSNull, NSNumber, NSString,
    /// NSURL).
    ///
    /// - parameter dictionary: An NSDictionary.
    public init?(dictionary: NSDictionary) {
        guard let row = Row(dictionary: dictionary) else {
            return nil
        }
        self.init(row: row)
    }
}

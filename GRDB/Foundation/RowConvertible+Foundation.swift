import Foundation

extension RowConvertible {
    
    /// NSDictionary initializer.
    ///
    /// - parameter dictionary: An NSDictionary.
    public init(dictionary: NSDictionary) {
        let row = Row(dictionary: dictionary)
        self.init(row: row)
    }
}

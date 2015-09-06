import UIKit

// UIImage is convertible to and from DatabaseValue.
extension UIImage : DatabaseValueConvertible {
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        if let data = UIImagePNGRepresentation(self) {
            return data.databaseValue
        } else {
            return .Null
        }
    }
    
    /// Create an instance initialized to `databaseValue`.
    public static func fromDatabaseValue(databaseValue: DatabaseValue) -> Self? {
        if let data = NSData.fromDatabaseValue(databaseValue) {
            return self.init(data: data)
        } else {
            return nil
        }
    }
}

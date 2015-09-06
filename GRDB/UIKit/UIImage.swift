import UIKit

// UIImage experiment.
// This code is not included in any public target.
extension UIImage : DatabaseValueConvertible {
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        if let data = UIImagePNGRepresentation(self) {
            return data.databaseValue
        } else {
            return .Null
        }
    }
    
    /**
    Returns an UIImage initialized from *databaseValue*, if possible.
    
    - parameter databaseValue: A DatabaseValue.
    - returns: An optional UIImage.
    */
    public static func fromDatabaseValue(databaseValue: DatabaseValue) -> Self? {
        if let data = NSData.fromDatabaseValue(databaseValue) {
            return self.init(data: data)
        } else {
            return nil
        }
    }
}

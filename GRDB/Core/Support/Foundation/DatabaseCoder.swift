import Foundation

/// DatabaseCoder reads and stores objects that conform to NSCoding in
/// the database.
public struct DatabaseCoder: DatabaseValueConvertible {
    
    /// The object
    public let object: Any
    
    /// Creates a DatabaseCoder from an object that conforms to NSCoding.
    ///
    /// The result is nil if and only if *object* is nil.
    public init?(_ object: Any?) {
        guard let object = object else {
            return nil
        }
        self.object = object
    }
    
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        return NSKeyedArchiver.archivedData(withRootObject: object).databaseValue
    }
    
    /// Returns a DatabaseCoder if *databaseValue* contains an archived object.
    public static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> DatabaseCoder? {
        guard let data = Data.fromDatabaseValue(databaseValue) else {
            return nil
        }
        return DatabaseCoder(NSKeyedUnarchiver.unarchiveObject(with: data))
    }
}

/// NSURL adopts DatabaseValueConvertible
extension NSURL : DatabaseValueConvertible {
    
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        return DatabaseValue(string: absoluteString)
    }
    
    /**
    Returns an NSURL initialized from *databaseValue*, if possible.
    
    - parameter databaseValue: A DatabaseValue.
    - returns: An optional NSURL.
    */
    public static func fromDatabaseValue(databaseValue: DatabaseValue) -> Self? {
        if let string = String.fromDatabaseValue(databaseValue) {
            return self.init(string: string)
        } else {
            return nil
        }
    }
}

//public protocol DatabaseBaseURLType {
//    static var baseURL: NSURL? { get }
//}
//
//public struct DatabaseURL<Base : DatabaseBaseURLType> : DatabaseValueConvertible {
//    let URLString: String
//    
//    init(URLString: String) {
//        self.URLString = URLString
//    }
//    
//    public init?(URL: NSURL?) {
//        guard let URL = URL else {
//            return nil
//        }
//        if let baseURL = Base.baseURL {
//            let absoluteString = URL.absoluteString
//            let baseAbsoluteString = baseURL.absoluteString
//            if absoluteString.hasPrefix(baseAbsoluteString) {
//                // TODO
//                self.URLString = URL.relativeString!
//            } else {
//                self.URLString = URL.absoluteString
//            }
//        } else {
//            self.URLString = URL.absoluteString
//        }
//    }
//    
//    /// Returns a value that can be stored in the database.
//    public var databaseValue: DatabaseValue {
//        return DatabaseValue(string: URLString)
//    }
//    
//    /**
//    Returns an NSURL initialized from *databaseValue*, if possible.
//    
//    - parameter databaseValue: A DatabaseValue.
//    - returns: An optional NSURL.
//    */
//    public static func fromDatabaseValue(databaseValue: DatabaseValue) -> DatabaseURL? {
//        if let string = String.fromDatabaseValue(databaseValue) {
//            return DatabaseURL(URLString: string)
//        } else {
//            return nil
//        }
//    }
//}

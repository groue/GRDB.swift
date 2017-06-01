import Foundation

/// DatabaseValueConvertible is free for ReferenceConvertible types whose
/// ReferenceType is itself DatabaseValueConvertible.
///
///     class FooReference { ... }
///     struct Foo : ReferenceConvertible {
///         typealias ReferenceType = FooReference
///     }
///
///     // If the ReferenceType adopts DatabaseValueConvertible...
///     extension FooReference : DatabaseValueConvertible { ... }
///
///     // ... then the ReferenceConvertible type can freely adopt DatabaseValueConvertible:
///     extension Foo : DatabaseValueConvertible { /* empty */ }
extension ReferenceConvertible where Self: DatabaseValueConvertible, Self.ReferenceType: DatabaseValueConvertible {
    
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        return (self as! ReferenceType).databaseValue
    }
    
    /// Returns a value initialized from *dbValue*, if possible.
    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Self? {
        return ReferenceType.fromDatabaseValue(dbValue).flatMap { cast($0) }
    }
}

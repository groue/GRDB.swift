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
    
    /// Returns a value initialized from *databaseValue*, if possible.
    public static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> Self? {
        return ReferenceType.fromDatabaseValue(databaseValue).flatMap { cast($0) }
    }
}

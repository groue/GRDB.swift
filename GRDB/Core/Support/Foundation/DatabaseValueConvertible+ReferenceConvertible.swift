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
extension DatabaseValueConvertible where Self: ReferenceConvertible, Self.ReferenceType: DatabaseValueConvertible {
    
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        (self as! ReferenceType).databaseValue
    }
    
    /// Returns a value initialized from *dbValue*, if possible.
    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Self? {
        ReferenceType.fromDatabaseValue(dbValue).flatMap { cast($0) }
    }
}

extension DatabaseValueConvertible
where
    Self: Decodable & ReferenceConvertible,
    Self.ReferenceType: DatabaseValueConvertible
{
    public static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> Self? {
        // Preserve custom database decoding
        return ReferenceType.fromDatabaseValue(databaseValue).flatMap { cast($0) }
    }
}

extension DatabaseValueConvertible
where
    Self: Encodable & ReferenceConvertible,
    Self.ReferenceType: DatabaseValueConvertible
{
    public var databaseValue: DatabaseValue {
        // Preserve custom database encoding
        return (self as! ReferenceType).databaseValue
    }
}

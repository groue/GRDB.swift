/// DatabaseValueConvertible is free for RawRepresentable types whose raw value
/// is itself DatabaseValueConvertible.
///
///     // If the RawValue adopts DatabaseValueConvertible...
///     enum Color : Int {
///         case red
///         case white
///         case rose
///     }
///
///     // ... then the RawRepresentable type can freely adopt DatabaseValueConvertible:
///     extension Color : DatabaseValueConvertible { /* empty */ }
extension RawRepresentable where Self: DatabaseValueConvertible, Self.RawValue: DatabaseValueConvertible {
    
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        return rawValue.databaseValue
    }
    
    /// Returns a value initialized from *databaseValue*, if possible.
    public static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> Self? {
        return RawValue.fromDatabaseValue(databaseValue).flatMap { self.init(rawValue: $0) }
    }
}

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
extension DatabaseValueConvertible where Self: RawRepresentable, Self.RawValue: DatabaseValueConvertible {
    
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        return rawValue.databaseValue
    }
    
    /// Returns a value initialized from *dbValue*, if possible.
    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Self? {
        return RawValue.fromDatabaseValue(dbValue).flatMap { self.init(rawValue: $0) }
    }
}

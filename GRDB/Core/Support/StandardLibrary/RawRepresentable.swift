/// DatabaseValueConvertible is free for RawRepresentable types whose raw value
/// is itself DatabaseValueConvertible:
///
///     enum Color : Int {
///         case red
///         case white
///         case rose
///     }
///
///     // Declare DatabaseValueConvertible adoption:
///     extension Color : DatabaseValueConvertible { }
///
///     // Gain full GRDB.swift support:
///     db.execute("INSERT INTO colors (color) VALUES (?)", [Color.red])
///     let color: Color? = Color.fetchOne(db, "SELECT ...")
public extension RawRepresentable where Self: DatabaseValueConvertible, Self.RawValue: DatabaseValueConvertible {
    
    /// Returns a value that can be stored in the database.
    var databaseValue: DatabaseValue {
        return rawValue.databaseValue
    }
    
    /// Returns a value initialized from *databaseValue*, if possible.
    static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> Self? {
        return RawValue.fromDatabaseValue(databaseValue).flatMap { self.init(rawValue: $0) }
    }
}

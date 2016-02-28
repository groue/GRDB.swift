/// DatabaseValueConvertible is free for RawRepresentable types whose raw value
/// is itself DatabaseValueConvertible:
///
///     enum Color : Int {
///         case Red
///         case White
///         case Rose
///     }
///
///     // Declare DatabaseValueConvertible adoption:
///     extension Color : DatabaseValueConvertible { }
///
///     // Gain full GRDB.swift support:
///     db.execute("INSERT INTO colors (color) VALUES (?)", [Color.Red])
///     let color: Color? = Color.fetchOne(db, "SELECT ...")
public extension RawRepresentable where Self: DatabaseValueConvertible, Self.RawValue: DatabaseValueConvertible {
    
    /// Returns a value that can be stored in the database.
    var databaseValue: DatabaseValue {
        return rawValue.databaseValue
    }
    
    /// Returns a value initialized from *databaseValue*, if possible.
    static func fromDatabaseValue(databaseValue: DatabaseValue) -> Self? {
        guard let rawValue = RawValue.fromDatabaseValue(databaseValue) else {
            return nil
        }
        return self.init(rawValue: rawValue)
    }
}

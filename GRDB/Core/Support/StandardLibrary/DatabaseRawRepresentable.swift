/// Have your RawRepresentable type adopt DatabaseRawRepresentable and it
/// automatically gains DatabaseValueConvertible adoption.
///
///     enum Color : Int {
///         case Red
///         case White
///         case Rose
///     }
///
///     // Declare DatabaseRawRepresentable adoption:
///     extension Color : DatabaseRawRepresentable { }
///
///     // Gain full GRDB.swift support:
///     db.execute("INSERT INTO colors (color) VALUES (?)", [Color.Red])
///     let color: Color? = Color.fetchOne(db, "SELECT ...")
public protocol DatabaseRawRepresentable: RawRepresentable, DatabaseValueConvertible { }

public extension DatabaseRawRepresentable where RawValue: DatabaseValueConvertible {
    
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

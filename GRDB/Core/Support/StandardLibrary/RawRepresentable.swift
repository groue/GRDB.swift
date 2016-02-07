// MARK: - DatabaseIntRepresentable

/// Have your Int enum adopt DatabaseIntRepresentable and it automatically gains
/// DatabaseValueConvertible adoption.
///
///     // An Int enum:
///     enum Color : Int {
///         case Red
///         case White
///         case Rose
///     }
///
///     // Declare DatabaseIntRepresentable adoption:
///     extension Color : DatabaseIntRepresentable { }
///
///     // Gain full GRDB.swift support:
///     db.execute("INSERT INTO colors (color) VALUES (?)", [Color.Red])
///     let color: Color? = Color.fetchOne(db, "SELECT ...")
public protocol DatabaseIntRepresentable : DatabaseValueConvertible {
    var rawValue: Int { get }
    init?(rawValue: Int)
}

extension DatabaseIntRepresentable {
    
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        return rawValue.databaseValue
    }
    
    /// Returns a value initialized from *databaseValue*, if possible.
    public static func fromDatabaseValue(databaseValue: DatabaseValue) -> Self? {
        guard let int = Int.fromDatabaseValue(databaseValue) else {
            return nil
        }
        return self.init(rawValue: int)
    }
}


// MARK: - DatabaseInt32Representable

/// Have your Int32 enum adopt DatabaseInt32Representable and it automatically
/// gains DatabaseValueConvertible adoption.
///
///     // An Int enum:
///     enum Color : Int32 {
///         case Red
///         case White
///         case Rose
///     }
///
///     // Declare DatabaseInt32Representable adoption:
///     extension Color : DatabaseInt32Representable { }
///
///     // Gain full GRDB.swift support:
///     db.execute("INSERT INTO colors (color) VALUES (?)", [Color.Red])
///     let color: Color? = Color.fetchOne(db, "SELECT ...")
public protocol DatabaseInt32Representable : DatabaseValueConvertible {
    var rawValue: Int32 { get }
    init?(rawValue: Int32)
}

extension DatabaseInt32Representable {
    
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        return rawValue.databaseValue
    }
    
    /// Returns a value initialized from *databaseValue*, if possible.
    public static func fromDatabaseValue(databaseValue: DatabaseValue) -> Self? {
        guard let int = Int32.fromDatabaseValue(databaseValue) else {
            return nil
        }
        return self.init(rawValue: int)
    }
}


// MARK: - DatabaseInt64Representable

/// Have your Int64 enum adopt DatabaseInt64Representable and it automatically
/// gains DatabaseValueConvertible adoption.
///
///     // An Int enum:
///     enum Color : Int64 {
///         case Red
///         case White
///         case Rose
///     }
///
///     // Declare DatabaseInt64Representable adoption:
///     extension Color : DatabaseInt64Representable { }
///
///     // Gain full GRDB.swift support:
///     db.execute("INSERT INTO colors (color) VALUES (?)", [Color.Red])
///     let color: Color? = Color.fetchOne(db, "SELECT ...")
public protocol DatabaseInt64Representable : DatabaseValueConvertible {
    var rawValue: Int64 { get }
    init?(rawValue: Int64)
}

extension DatabaseInt64Representable {
    
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        return rawValue.databaseValue
    }
    
    /// Returns a value initialized from *databaseValue*, if possible.
    public static func fromDatabaseValue(databaseValue: DatabaseValue) -> Self? {
        guard let int = Int64.fromDatabaseValue(databaseValue) else {
            return nil
        }
        return self.init(rawValue: int)
    }
}


// MARK: - DatabaseStringRepresentable

/// Have your String enum adopt DatabaseStringRepresentable and it automatically
/// gains DatabaseValueConvertible adoption.
///
///     // A String enum:
///     enum Color : String {
///         case Red
///         case White
///         case Rose
///     }
///
///     // Declare DatabaseIntRepresentable adoption:
///     extension Color : DatabaseStringRepresentable { }
///
///     // Gain full GRDB.swift support:
///     db.execute("INSERT StringO colors (color) VALUES (?)", [Color.Red])
///     let color: Color? = Color.fetchOne(db, "SELECT ...")
public protocol DatabaseStringRepresentable : DatabaseValueConvertible {
    var rawValue: String { get }
    init?(rawValue: String)
}

extension DatabaseStringRepresentable {
    
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        return rawValue.databaseValue
    }
    
    /// Returns a value initialized from *databaseValue*, if possible.
    public static func fromDatabaseValue(databaseValue: DatabaseValue) -> Self? {
        guard let string = String.fromDatabaseValue(databaseValue) else {
            return nil
        }
        return self.init(rawValue: string)
    }
}

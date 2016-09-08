#if !USING_BUILTIN_SQLITE
    #if os(OSX)
        import SQLiteMacOSX
    #elseif os(iOS)
        #if (arch(i386) || arch(x86_64))
            import SQLiteiPhoneSimulator
        #else
            import SQLiteiPhoneOS
        #endif
    #elseif os(watchOS)
        #if (arch(i386) || arch(x86_64))
            import SQLiteWatchSimulator
        #else
            import SQLiteWatchOS
        #endif
    #endif
#endif


// MARK: - Value Types

/// Bool adopts DatabaseValueConvertible and StatementColumnConvertible.
extension Bool: DatabaseValueConvertible, StatementColumnConvertible {
    
    /// Returns a value initialized from a raw SQLite statement pointer.
    ///
    /// - parameters:
    ///     - sqliteStatement: A pointer to an SQLite statement.
    ///     - index: The column index.
    public init(sqliteStatement: SQLiteStatement, index: Int32) {
        self = sqlite3_column_int64(sqliteStatement, index) != 0
    }
    
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        return (self ? 1 : 0).databaseValue
    }
    
    /// Returns a Bool initialized from *databaseValue*, if possible.
    public static func fromDatabaseValue(databaseValue: DatabaseValue) -> Bool? {
        // IMPLEMENTATION NOTE
        //
        // https://www.sqlite.org/lang_expr.html#booleanexpr
        //
        // > # Boolean Expressions
        // >
        // > The SQL language features several contexts where an expression is
        // > evaluated and the result converted to a boolean (true or false)
        // > value. These contexts are:
        // >
        // > - the WHERE clause of a SELECT, UPDATE or DELETE statement,
        // > - the ON or USING clause of a join in a SELECT statement,
        // > - the HAVING clause of a SELECT statement,
        // > - the WHEN clause of an SQL trigger, and
        // > - the WHEN clause or clauses of some CASE expressions.
        // >
        // > To convert the results of an SQL expression to a boolean value,
        // > SQLite first casts the result to a NUMERIC value in the same way as
        // > a CAST expression. A numeric zero value (integer value 0 or real
        // > value 0.0) is considered to be false. A NULL value is still NULL.
        // > All other values are considered true.
        // >
        // > For example, the values NULL, 0.0, 0, 'english' and '0' are all
        // > considered to be false. Values 1, 1.0, 0.1, -0.1 and '1english' are
        // > considered to be true.
        //
        // OK so we have to support boolean for all storage classes?
        // Actually we won't, because of the SQLite boolean interpretation of
        // strings:
        //
        // The doc says that "english" should be false, and "1english" should
        // be true. I guess "-1english" and "0.1english" should be true also.
        // And... what about "0.0e10english"?
        //
        // Ideally, we'd ask SQLite to perform the conversion itself, and return
        // its own boolean interpretation of the string. Unfortunately, it looks
        // like it is not so easy...
        //
        // So we could take a short route, and assume all strings are false,
        // since most strings are falsey for SQLite.
        //
        // Considering all strings falsey is unfortunately very
        // counter-intuitive. This is not the correct way to tackle the boolean
        // problem.
        //
        // Instead, let's use the fact that the BOOLEAN typename has Numeric
        // affinity (https://www.sqlite.org/datatype3.html), and that the doc
        // says:
        //
        // > SQLite does not have a separate Boolean storage class. Instead,
        // > Boolean values are stored as integers 0 (false) and 1 (true).
        //
        // So we extract bools from Integer and Real only. Integer because it is
        // the natural boolean storage class, and Real because Numeric affinity
        // store big numbers as Real.
        
        switch databaseValue.storage {
        case .Int64(let int64):
            return (int64 != 0)
        case .Double(let double):
            return (double != 0.0)
        default:
            return nil
        }
    }
}

/// Int adopts DatabaseValueConvertible and StatementColumnConvertible.
extension Int: DatabaseValueConvertible, StatementColumnConvertible {
    
    /// Returns a value initialized from a raw SQLite statement pointer.
    ///
    /// - parameters:
    ///     - sqliteStatement: A pointer to an SQLite statement.
    ///     - index: The column index.
    public init(sqliteStatement: SQLiteStatement, index: Int32) {
        let int64 = sqlite3_column_int64(sqliteStatement, index)
        GRDBPrecondition(int64 >= Int64(Int.min) && int64 <= Int64(Int.max), "could not convert database value \(int64) to Int")
        self = Int(int64)
    }
    
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        return Int64(self).databaseValue
    }
    
    /// Returns an Int initialized from *databaseValue*, if possible.
    public static func fromDatabaseValue(databaseValue: DatabaseValue) -> Int? {
        switch databaseValue.storage {
        case .Int64(let int64):
            guard int64 >= Int64(Int.min) else { return nil }
            guard int64 <= Int64(Int.max) else { return nil }
            return Int(int64)
        case .Double(let double):
            // Cast from Double to Int64 to Int
            // Why? Because on 32-bits platforms we'll convert more values this way (Swift bug?)
            // - Int(Int64(-2147483648.999999))  // -2147483648
            // - Int(-2147483648.999999)         // fatal error
            guard double >= Double(Int64.min) else { return nil }
            guard double < Double(Int64.max) else { return nil }
            let int64 = Int64(double)
            guard int64 >= Int64(Int.min) else { return nil }
            guard int64 <= Int64(Int.max) else { return nil }
            return Int(int64)
        default:
            return nil
        }
    }
}

/// Int32 adopts DatabaseValueConvertible and StatementColumnConvertible.
extension Int32: DatabaseValueConvertible, StatementColumnConvertible {
    
    /// Returns a value initialized from a raw SQLite statement pointer.
    ///
    /// - parameters:
    ///     - sqliteStatement: A pointer to an SQLite statement.
    ///     - index: The column index.
    public init(sqliteStatement: SQLiteStatement, index: Int32) {
        let int64 = sqlite3_column_int64(sqliteStatement, index)
        GRDBPrecondition(int64 >= Int64(Int32.min) && int64 <= Int64(Int32.max), "could not convert database value \(int64) to Int32")
        self = Int32(int64)
    }
    
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        return Int64(self).databaseValue
    }
    
    /// Returns an Int32 initialized from *databaseValue*, if possible.
    public static func fromDatabaseValue(databaseValue: DatabaseValue) -> Int32? {
        switch databaseValue.storage {
        case .Int64(let int64):
            guard int64 >= Int64(Int32.min) else { return nil }
            guard int64 <= Int64(Int32.max) else { return nil }
            return Int32(int64)
        case .Double(let double):
            // Cast from Double to Int64 to Int32
            // Why? Because we'll convert more values this way (Swift bug?)
            // - Int32(Int64(-2147483648.999999))  // -2147483648
            // - Int32(-2147483648.999999)         // fatal error
            guard double >= Double(Int64.min) else { return nil }
            guard double < Double(Int64.max) else { return nil }
            let int64 = Int64(double)
            guard int64 >= Int64(Int32.min) else { return nil }
            guard int64 <= Int64(Int32.max) else { return nil }
            return Int32(int64)
        default:
            return nil
        }
    }
}

/// Int64 adopts DatabaseValueConvertible and StatementColumnConvertible.
extension Int64: DatabaseValueConvertible, StatementColumnConvertible {
    
    /// Returns a value initialized from a raw SQLite statement pointer.
    ///
    /// - parameters:
    ///     - sqliteStatement: A pointer to an SQLite statement.
    ///     - index: The column index.
    public init(sqliteStatement: SQLiteStatement, index: Int32) {
        self = sqlite3_column_int64(sqliteStatement, index)
    }
    
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        return DatabaseValue(storage: .Int64(self))
    }
    
    /// Returns an Int64 initialized from *databaseValue*, if possible.
    public static func fromDatabaseValue(databaseValue: DatabaseValue) -> Int64? {
        switch databaseValue.storage {
        case .Int64(let int64):
            return int64
        case .Double(let double):
            guard double >= Double(Int64.min) else { return nil }
            guard double < Double(Int64.max) else { return nil }
            return Int64(double)
        default:
            return nil
        }
    }
}

/// Double adopts DatabaseValueConvertible and StatementColumnConvertible.
extension Double: DatabaseValueConvertible, StatementColumnConvertible {
    
    /// Returns a value initialized from a raw SQLite statement pointer.
    ///
    /// - parameters:
    ///     - sqliteStatement: A pointer to an SQLite statement.
    ///     - index: The column index.
    public init(sqliteStatement: SQLiteStatement, index: Int32) {
        self = sqlite3_column_double(sqliteStatement, index)
    }
    
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        return DatabaseValue(storage: .Double(self))
    }
    
    /// Returns a Double initialized from *databaseValue*, if possible.
    public static func fromDatabaseValue(databaseValue: DatabaseValue) -> Double? {
        switch databaseValue.storage {
        case .Int64(let int64):
            return Double(int64)
        case .Double(let double):
            return double
        default:
            return nil
        }
    }
}

/// Float adopts DatabaseValueConvertible and StatementColumnConvertible.
extension Float: DatabaseValueConvertible, StatementColumnConvertible {
    
    /// Returns a value initialized from a raw SQLite statement pointer.
    ///
    /// - parameters:
    ///     - sqliteStatement: A pointer to an SQLite statement.
    ///     - index: The column index.
    public init(sqliteStatement: SQLiteStatement, index: Int32) {
        self = Float(sqlite3_column_double(sqliteStatement, index))
    }
    
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        return Double(self).databaseValue
    }
    
    /// Returns a Float initialized from *databaseValue*, if possible.
    public static func fromDatabaseValue(databaseValue: DatabaseValue) -> Float? {
        switch databaseValue.storage {
        case .Int64(let int64):
            return Float(int64)
        case .Double(let double):
            return Float(double)
        default:
            return nil
        }
    }
}

/// String adopts DatabaseValueConvertible and StatementColumnConvertible.
extension String: DatabaseValueConvertible, StatementColumnConvertible {
    
    /// Returns a value initialized from a raw SQLite statement pointer.
    ///
    /// - parameters:
    ///     - sqliteStatement: A pointer to an SQLite statement.
    ///     - index: The column index.
    public init(sqliteStatement: SQLiteStatement, index: Int32) {
        let cString = UnsafePointer<Int8>(sqlite3_column_text(sqliteStatement, Int32(index)))
        self = String.fromCString(cString)!
    }
    
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        return DatabaseValue(storage: .String(self))
    }
    
    /// Returns a String initialized from *databaseValue*, if possible.
    public static func fromDatabaseValue(databaseValue: DatabaseValue) -> String? {
        switch databaseValue.storage {
        case .String(let string):
            return string
        default:
            return nil
        }
    }
}


// MARK: - SQL Functions

extension DatabaseFunction {
    /// An SQL function that returns the Swift built-in capitalizedString
    /// String property.
    ///
    /// The function returns NULL for non-strings values.
    ///
    /// This function is automatically added by GRDB to your database
    /// connections. It is the function used by the query interface's
    /// capitalizedString:
    ///
    ///     let nameColumn = SQLColumn("name")
    ///     let request = Person.select(nameColumn.capitalizedString)
    ///     let names = String.fetchAll(dbQueue, request)   // [String]
    public static let capitalizedString = DatabaseFunction("swiftCapitalizedString", argumentCount: 1, pure: true) { databaseValues in
        guard let string = String.fromDatabaseValue(databaseValues[0]) else {
            return nil
        }
        return string.capitalizedString
    }
    
    /// An SQL function that returns the Swift built-in lowercaseString
    /// String property.
    ///
    /// The function returns NULL for non-strings values.
    ///
    /// This function is automatically added by GRDB to your database
    /// connections. It is the function used by the query interface's
    /// lowercaseString:
    ///
    ///     let nameColumn = SQLColumn("name")
    ///     let request = Person.select(nameColumn.lowercaseString)
    ///     let names = String.fetchAll(dbQueue, request)   // [String]
    public static let lowercaseString = DatabaseFunction("swiftLowercaseString", argumentCount: 1, pure: true) { databaseValues in
        guard let string = String.fromDatabaseValue(databaseValues[0]) else {
            return nil
        }
        return string.lowercaseString
    }
    
    /// An SQL function that returns the Swift built-in uppercaseString
    /// String property.
    ///
    /// The function returns NULL for non-strings values.
    ///
    /// This function is automatically added by GRDB to your database
    /// connections. It is the function used by the query interface's
    /// uppercaseString:
    ///
    ///     let nameColumn = SQLColumn("name")
    ///     let request = Person.select(nameColumn.uppercaseString)
    ///     let names = String.fetchAll(dbQueue, request)   // [String]
    public static let uppercaseString = DatabaseFunction("swiftUppercaseString", argumentCount: 1, pure: true) { databaseValues in
        guard let string = String.fromDatabaseValue(databaseValues[0]) else {
            return nil
        }
        return string.uppercaseString
    }
}

@available(iOS 9.0, OSX 10.11, *)
extension DatabaseFunction {
    /// An SQL function that returns the Swift built-in
    /// localizedCapitalizedString String property.
    ///
    /// The function returns NULL for non-strings values.
    ///
    /// This function is automatically added by GRDB to your database
    /// connections. It is the function used by the query interface's
    /// localizedCapitalizedString:
    ///
    ///     let nameColumn = SQLColumn("name")
    ///     let request = Person.select(nameColumn.localizedCapitalizedString)
    ///     let names = String.fetchAll(dbQueue, request)   // [String]
    public static let localizedCapitalizedString = DatabaseFunction("swiftLocalizedCapitalizedString", argumentCount: 1, pure: true) { databaseValues in
        guard let string = String.fromDatabaseValue(databaseValues[0]) else {
            return nil
        }
        return string.localizedCapitalizedString
    }
    
    /// An SQL function that returns the Swift built-in
    /// localizedLowercaseString String property.
    ///
    /// The function returns NULL for non-strings values.
    ///
    /// This function is automatically added by GRDB to your database
    /// connections. It is the function used by the query interface's
    /// localizedLowercaseString:
    ///
    ///     let nameColumn = SQLColumn("name")
    ///     let request = Person.select(nameColumn.localizedLowercaseString)
    ///     let names = String.fetchAll(dbQueue, request)   // [String]
    public static let localizedLowercaseString = DatabaseFunction("swiftLocalizedLowercaseString", argumentCount: 1, pure: true) { databaseValues in
        guard let string = String.fromDatabaseValue(databaseValues[0]) else {
            return nil
        }
        return string.localizedLowercaseString
    }
    
    /// An SQL function that returns the Swift built-in
    /// localizedUppercaseString String property.
    ///
    /// The function returns NULL for non-strings values.
    ///
    /// This function is automatically added by GRDB to your database
    /// connections. It is the function used by the query interface's
    /// localizedUppercaseString:
    ///
    ///     let nameColumn = SQLColumn("name")
    ///     let request = Person.select(nameColumn.localizedUppercaseString)
    ///     let names = String.fetchAll(dbQueue, request)   // [String]
    public static let localizedUppercaseString = DatabaseFunction("swiftLocalizedUppercaseString", argumentCount: 1, pure: true) { databaseValues in
        guard let string = String.fromDatabaseValue(databaseValues[0]) else {
            return nil
        }
        return string.localizedUppercaseString
    }
}


// MARK: - SQLite Collations

extension DatabaseCollation {
    // Here we define a set of predefined collations.
    //
    // We should avoid renaming those collations, because database created with
    // earlier versions of the library may have used those collations in the
    // definition of tables. A renaming would prevent SQLite to find the
    // collation.
    //
    // Yet we're not absolutely stuck: we could register support for obsolete
    // collation names with sqlite3_collation_needed().
    // See https://www.sqlite.org/capi3ref.html#sqlite3_collation_needed
    
    /// A collation, or SQL string comparison function, that compares strings
    /// according to the the Swift built-in == and <= operators.
    ///
    /// This collation is automatically added by GRDB to your database
    /// connections.
    ///
    /// You can use it when creating database tables:
    ///
    ///     let collationName = DatabaseCollation.caseInsensitiveCompare.name
    ///     dbQueue.execute(
    ///         "CREATE TABLE persons (" +
    ///             "name TEXT COLLATE \(collationName)" +
    ///         ")"
    ///     )
    public static let unicodeCompare = DatabaseCollation("swiftCompare") { (lhs, rhs) in
        return (lhs < rhs) ? .OrderedAscending : ((lhs == rhs) ? .OrderedSame : .OrderedDescending)
    }
    
    /// A collation, or SQL string comparison function, that compares strings
    /// according to the the Swift built-in caseInsensitiveCompare(_:) method.
    ///
    /// This collation is automatically added by GRDB to your database
    /// connections.
    ///
    /// You can use it when creating database tables:
    ///
    ///     let collationName = DatabaseCollation.caseInsensitiveCompare.name
    ///     dbQueue.execute(
    ///         "CREATE TABLE persons (" +
    ///             "name TEXT COLLATE \(collationName)" +
    ///         ")"
    ///     )
    public static let caseInsensitiveCompare = DatabaseCollation("swiftCaseInsensitiveCompare") { (lhs, rhs) in
        return lhs.caseInsensitiveCompare(rhs)
    }
    
    /// A collation, or SQL string comparison function, that compares strings
    /// according to the the Swift built-in localizedCaseInsensitiveCompare(_:) method.
    ///
    /// This collation is automatically added by GRDB to your database
    /// connections.
    ///
    /// You can use it when creating database tables:
    ///
    ///     let collationName = DatabaseCollation.localizedCaseInsensitiveCompare.name
    ///     dbQueue.execute(
    ///         "CREATE TABLE persons (" +
    ///             "name TEXT COLLATE \(collationName)" +
    ///         ")"
    ///     )
    public static let localizedCaseInsensitiveCompare = DatabaseCollation("swiftLocalizedCaseInsensitiveCompare") { (lhs, rhs) in
        return lhs.localizedCaseInsensitiveCompare(rhs)
    }
    
    /// A collation, or SQL string comparison function, that compares strings
    /// according to the the Swift built-in localizedCompare(_:) method.
    ///
    /// This collation is automatically added by GRDB to your database
    /// connections.
    ///
    /// You can use it when creating database tables:
    ///
    ///     let collationName = DatabaseCollation.localizedCompare.name
    ///     dbQueue.execute(
    ///         "CREATE TABLE persons (" +
    ///             "name TEXT COLLATE \(collationName)" +
    ///         ")"
    ///     )
    public static let localizedCompare = DatabaseCollation("swiftLocalizedCompare") { (lhs, rhs) in
        return lhs.localizedCompare(rhs)
    }
    
    /// A collation, or SQL string comparison function, that compares strings
    /// according to the the Swift built-in localizedStandardCompare(_:) method.
    ///
    /// This collation is automatically added by GRDB to your database
    /// connections.
    ///
    /// You can use it when creating database tables:
    ///
    ///     let collationName = DatabaseCollation.localizedStandardCompare.name
    ///     dbQueue.execute(
    ///         "CREATE TABLE persons (" +
    ///             "name TEXT COLLATE \(collationName)" +
    ///         ")"
    ///     )
    public static let localizedStandardCompare = DatabaseCollation("swiftLocalizedStandardCompare") { (lhs, rhs) in
        return lhs.localizedStandardCompare(rhs)
    }
}

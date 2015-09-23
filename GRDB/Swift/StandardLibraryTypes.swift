/// Bool adopts DatabaseValueConvertible and MetalType.
extension Bool: DatabaseValueConvertible, MetalType {
    
    public init(sqliteStatement: SQLiteStatement, index: Int32) {
        self = sqlite3_column_int64(sqliteStatement, index) != 0
    }
    
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        return DatabaseValue(int64: self ? 1 : 0)
    }
    
    /**
    Returns a Bool initialized from *databaseValue*, if possible.
    
    - parameter databaseValue: A DatabaseValue.
    - returns: An optional Bool.
    */
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

/// Int adopts DatabaseValueConvertible and MetalType.
extension Int: DatabaseValueConvertible, MetalType {
    
    public init(sqliteStatement: SQLiteStatement, index: Int32) {
        self = Int(sqlite3_column_int64(sqliteStatement, index))
    }
    
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        return DatabaseValue(int64: Int64(self))
    }
    
    /**
    Returns an Int initialized from *databaseValue*, if possible.
    
    - parameter databaseValue: A DatabaseValue.
    - returns: An optional Int.
    */
    public static func fromDatabaseValue(databaseValue: DatabaseValue) -> Int? {
        switch databaseValue.storage {
        case .Int64(let int64):
            return Int(int64)
        case .Double(let double):
            return Int(double)
        default:
            return nil
        }
    }
}

/// Int32 adopts DatabaseValueConvertible and MetalType.
extension Int32: DatabaseValueConvertible, MetalType {
    
    public init(sqliteStatement: SQLiteStatement, index: Int32) {
        self = Int32(sqlite3_column_int64(sqliteStatement, index))
    }
    
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        return DatabaseValue(int64: Int64(self))
    }
    
    /**
    Returns an Int32 initialized from *databaseValue*, if possible.
    
    - parameter databaseValue: A DatabaseValue.
    - returns: An optional Int32.
    */
    public static func fromDatabaseValue(databaseValue: DatabaseValue) -> Int32? {
        switch databaseValue.storage {
        case .Int64(let int64):
            return Int32(int64)
        case .Double(let double):
            return Int32(double)
        default:
            return nil
        }
    }
}

/// Int64 adopts DatabaseValueConvertible and MetalType.
extension Int64: DatabaseValueConvertible, MetalType {
    
    public init(sqliteStatement: SQLiteStatement, index: Int32) {
        self = sqlite3_column_int64(sqliteStatement, index)
    }
    
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        return DatabaseValue(int64: self)
    }
    
    /**
    Returns an Int64 initialized from *databaseValue*, if possible.
    
    - parameter databaseValue: A DatabaseValue.
    - returns: An optional Int64.
    */
    public static func fromDatabaseValue(databaseValue: DatabaseValue) -> Int64? {
        switch databaseValue.storage {
        case .Int64(let int64):
            return int64
        case .Double(let double):
            return Int64(double)
        default:
            return nil
        }
    }
}

/// Double adopts DatabaseValueConvertible and MetalType.
extension Double: DatabaseValueConvertible, MetalType {
    
    public init(sqliteStatement: SQLiteStatement, index: Int32) {
        self = sqlite3_column_double(sqliteStatement, index)
    }
    
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        return DatabaseValue(double: self)
    }
    
    /**
    Returns a Double initialized from *databaseValue*, if possible.
    
    - parameter databaseValue: A DatabaseValue.
    - returns: An optional Double.
    */
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

/// String adopts DatabaseValueConvertible and MetalType.
extension String: DatabaseValueConvertible, MetalType {
    
    public init(sqliteStatement: SQLiteStatement, index: Int32) {
        let cString = UnsafePointer<Int8>(sqlite3_column_text(sqliteStatement, Int32(index)))
        self = String.fromCString(cString)!
    }
    
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        return DatabaseValue(string: self)
    }
    
    /**
    Returns a String initialized from *databaseValue*, if possible.
    
    - parameter databaseValue: A DatabaseValue.
    - returns: An optional String.
    */
    public static func fromDatabaseValue(databaseValue: DatabaseValue) -> String? {
        switch databaseValue.storage {
        case .String(let string):
            return string
        default:
            return nil
        }
    }
}

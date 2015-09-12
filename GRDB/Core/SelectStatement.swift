/**
A subclass of Statement that fetches database rows.

You create SelectStatement with the Database.selectStatement() method:

    dbQueue.inDatabase { db in
        let statement = db.selectStatement("SELECT * FROM persons WHERE age > ?")
        let moreThanTwentyCount = Int.fetchOne(statement, arguments: [20])!
        let moreThanThirtyCount = Int.fetchOne(statement, arguments: [30])!
    }
*/
public final class SelectStatement : Statement {
    
    /// The number of columns in the resulting rows.
    public lazy var columnCount: Int = { [unowned self] in
        Int(sqlite3_column_count(self.sqliteStatement))
    }()
    
    /// The names of columns, ordered from left to right.
    public lazy var columnNames: [String] = { [unowned self] in
        (0..<self.columnCount).map { index in
            return String.fromCString(sqlite3_column_name(self.sqliteStatement, Int32(index)))!
        }
    }()
    
    // MARK: - Not public
    
    /**
    Returns the DatabaseValue at given index.
    
    It is the *only* method which loads data straight from SQLite.
    
    We preserve the *raw storage class* of database values, and do not use the
    SQLite built-in casting between types.
    
    This is *by design*, because a GRDB user generally consumes database values
    long after the opportunity to use SQLite casting has passed, which is during
    the statement consumption.
    
        // Rows is an Array: all rows are loaded, which means that statement has
        // been fully iterated and consumed, and any SQLite casting opportunity
        // has passed.
        let rows = Row.fetchAll(db, "SELECT ...")
    
        for row in rows {
            let itemCount: Int? = row.value(atIndex:0)   // GRDB conversion to Int
            let hasItems: Bool? = row.value(atIndex:0)   // GRDB conversion to Bool
        }
    */
    func databaseValue(atIndex index: Int) -> DatabaseValue {
        switch sqlite3_column_type(sqliteStatement, Int32(index)) {
        case SQLITE_NULL:
            return .Null;
        case SQLITE_INTEGER:
            return .Integer(sqlite3_column_int64(sqliteStatement, Int32(index)))
        case SQLITE_FLOAT:
            return .Real(sqlite3_column_double(sqliteStatement, Int32(index)))
        case SQLITE_TEXT:
            let cString = UnsafePointer<Int8>(sqlite3_column_text(sqliteStatement, Int32(index)))
            return .Text(String.fromCString(cString)!)
        case SQLITE_BLOB:
            let bytes = sqlite3_column_blob(sqliteStatement, Int32(index))
            let length = sqlite3_column_bytes(sqliteStatement, Int32(index))
            return .Blob(Blob(bytes: bytes, length: Int(length))!)
        default:
            fatalError("Unexpected SQLite column type")
        }
    }

    /**
    Builds a lazy sequence from a SelectStatement.
    
        let statement = db.selectStatement("SELECT ...")
        
        // AnySequence<Row>
        let rows = statement.fetch() { statement in return Row(statement: self) }
    
    - parameter arguments: Optional statement arguments.
    - parameter transform: A function that maps the statement to the desired
      sequence element. SQLite statements are stateful: at the moment the
      *transform* function is called, the statement has just read a row.
    - returns: A lazy sequence.
    */
    func fetch<T>(arguments arguments: StatementArguments?, transform: (SelectStatement) -> T) -> AnySequence<T> {
        if let arguments = arguments {
            self.arguments = arguments
        }

        if let trace = self.database.configuration.trace {
            trace(sql: self.sql, arguments: self.arguments)
        }
        
        return AnySequence { () -> AnyGenerator<T> in
            // IMPLEMENTATION NOTE
            //
            // Make sure sequences are consumed in the correct queue.
            //
            // Here we avoid this pattern:
            //
            //      let rows = dbQueue.inDatabase { db in
            //          try Row.fetch(db, "...")
            //      }
            //      for row in rows {   // assertion failure
            //          ...
            //      }
            //
            // Here we check that sequence.generate() is called on the correct queue.
            self.assertValidQueue("SQLite statement was not used on its database queue. Consider using the fetchAll() method instead of fetch().")
            
            // Let sequences be iterated several times.
            self.reset()
            
            return anyGenerator { () -> T? in
                // Here we check that generator.next() is called on the correct queue.
                self.assertValidQueue("SQLite statement was not used on its database queue. Consider using the fetchAll() method instead of fetch().")
                
                let code = sqlite3_step(self.sqliteStatement)
                switch code {
                case SQLITE_DONE:
                    return nil
                case SQLITE_ROW:
                    return transform(self)
                default:
                    fatalError(DatabaseError(code: code, message: self.database.lastErrorMessage, sql: self.sql, arguments: self.arguments).description)
                }
            }
        }
    }
}

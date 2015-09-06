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
    
        // All rows are loaded, which means that statement has been fully
        // consumed, and any SQLite casting opportunity has passed.
        let rows = Row.fetchAll(db, "SELECT ...")
    
        for row in rows {
            let age: Int = row.value(atIndex:0)     // the conversion actually happens in GRDB.
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
    Fetches a lazy sequence of rows.
    
        let statement = db.selectStatement("SELECT ...")
        let rows = statement.fetchRows()
    
    - parameter arguments: Optional statement arguments.
    - returns: A lazy sequence of rows.
    */
    func fetchRows(arguments arguments: StatementArguments? = nil) -> AnySequence<Row> {
        if let arguments = arguments {
            self.arguments = arguments
        }

        if let trace = self.database.configuration.trace {
            trace(sql: self.sql, arguments: self.arguments)
        }
        
        return AnySequence { () -> AnyGenerator<Row> in
            // Let row sequences be iterated several times.
            self.reset()
            
            return anyGenerator { () -> Row? in
                // Make sure values are consumed in the correct queue.
                //
                // Here we avoid this pattern:
                //
                //      let rows = dbQueue.inDatabase { db in
                //          try Row.fetch(db, "...")
                //      }
                //      for row in rows {   // fatal error!
                //          ...
                //      }
                //
                // Check that the statement was created in a database queue,
                // and then that the current database queue is the same as the
                // one where the statement was created:
                assert(self.databaseQueueID != nil)
                guard self.databaseQueueID == dispatch_get_specific(DatabaseQueue.databaseQueueIDKey) else {
                    fatalError("SelectStatement was not iterated on its database queue. Consider wrapping the results of the fetch in an Array before escaping the database queue.")
                }
                
                let code = sqlite3_step(self.sqliteStatement)
                switch code {
                case SQLITE_DONE:
                    return nil
                case SQLITE_ROW:
                    return Row(statement: self)
                default:
                    fatalDatabaseError(DatabaseError(code: code, message: self.database.lastErrorMessage, sql: self.sql, arguments: self.arguments))
                }
            }
        }
    }
}

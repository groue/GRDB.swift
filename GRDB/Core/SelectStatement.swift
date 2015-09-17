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
        return DatabaseValue(sqliteStatement: sqliteStatement, index: index)
    }

    /**
    TODO
    
    Builds a generator from a SelectStatement.
    
        let statement = db.selectStatement("SELECT ...")
        
        // AnyGenerator<Row>
        let rowGenerator = statement.generate() { Row(statement: statement) }
    
    - parameter arguments: Optional statement arguments.
    - parameter transform: A function that maps the statement to the desired
      sequence element. SQLite statements are stateful: at the moment the
      *read* function is called, the statement has just read a row.
    - returns: A lazy sequence.
    */
    func metalFetch<T>(arguments arguments: StatementArguments?, read: () -> T) -> AnySequence<T> {
        if let arguments = arguments {
            self.arguments = arguments
        }

        if let trace = self.database.configuration.trace {
            trace(sql: self.sql, arguments: self.arguments)
        }
        
        // See DatabaseQueue.inSafeDatabase().
        database.assertValid()
        
        return AnySequence { () -> AnyGenerator<T> in
            
            // Restart
            self.reset()
            
            return anyGenerator { () -> T? in
                let code = sqlite3_step(self.sqliteStatement)
                switch code {
                case SQLITE_DONE:
                    return nil
                case SQLITE_ROW:
                    return read()
                default:
                    fatalError(DatabaseError(code: code, message: self.database.lastErrorMessage, sql: self.sql, arguments: self.arguments).description)
                }
            }
        }
    }

//    /**
//    Builds a generator from a SelectStatement.
//    
//        let statement = db.selectStatement("SELECT ...")
//        
//        // AnyGenerator<Row>
//        let rowGenerator = statement.generate() { Row(statement: statement) }
//    
//    - parameter arguments: Optional statement arguments.
//    - parameter transform: A function that maps the statement to the desired
//      sequence element. SQLite statements are stateful: at the moment the
//      *read* function is called, the statement has just read a row.
//    - returns: A lazy sequence.
//    */
//    func fetch<T>(arguments arguments: StatementArguments?, read: () -> T) -> AnySequence<T> {
//        if let arguments = arguments {
//            self.arguments = arguments
//        }
//
//        if let trace = self.database.configuration.trace {
//            trace(sql: self.sql, arguments: self.arguments)
//        }
//        
//        let database = self.database
//
//        return AnySequence { () -> AnyGenerator<T> in
//            
//            // Check that generate() is called on a valid database.
//            // See DatabaseQueue.inSafeDatabase().
//            database.assertValid()
//            
//            // Restart
//            self.reset()
//            
//            return anyGenerator { () -> T? in
//                // Check that generator.next() is called on a valid database.
//                // See DatabaseQueue.inSafeDatabase().
//                database.assertValid()
//                
//                let code = sqlite3_step(self.sqliteStatement)
//                switch code {
//                case SQLITE_DONE:
//                    return nil
//                case SQLITE_ROW:
//                    return read()
//                default:
//                    fatalError(DatabaseError(code: code, message: self.database.lastErrorMessage, sql: self.sql, arguments: self.arguments).description)
//                }
//            }
//        }
//    }
}

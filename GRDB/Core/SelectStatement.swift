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
    TODO
    */
    func databaseValue(atIndex index: Int) -> DatabaseValue {
        return DatabaseValue(sqliteStatement: sqliteStatement, index: index)
    }

    /**
    TODO
    */
    func fetch<T>(arguments arguments: StatementArguments?, map: () -> T) -> DatabaseSequence<T> {
        if let arguments = arguments {
            self.arguments = arguments
        }

        if let trace = self.database.configuration.trace {
            trace(sql: self.sql, arguments: self.arguments)
        }
        
        // Check that sequence is built on a valid database.
        // See DatabaseQueue.inSafeDatabase().
        database.assertValid()
        
        return DatabaseSequence(statement: self, map: map)
    }
}

/**
TODO
*/
public struct DatabaseSequence<T>: SequenceType {
    let statement: SelectStatement
    let map: () -> T
    public func generate() -> DatabaseGenerator<T> {
        // DatabaseSequence can be restarted:
        statement.reset()
        
        return DatabaseGenerator(statement: statement, map: map)
    }
}

/**
TODO
*/
public struct DatabaseGenerator<T>: GeneratorType {
    let statement: SelectStatement
    let sqliteStatement: SQLiteStatement
    let map: () -> T
    
    init(statement: SelectStatement, map: () -> T) {
        self.statement = statement
        self.sqliteStatement = statement.sqliteStatement
        self.map = map
    }
    
    public func next() -> T? {
        let code = sqlite3_step(sqliteStatement)
        switch code {
        case SQLITE_DONE:
            return nil
        case SQLITE_ROW:
            return map()
        default:
            fatalError(DatabaseError(code: code, message: statement.database.lastErrorMessage, sql: statement.sql, arguments: statement.arguments).description)
        }
    }
}

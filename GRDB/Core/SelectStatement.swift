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
    
    /// The column names, ordered from left to right.
    public lazy var columnNames: [String] = { [unowned self] in
        (0..<self.columnCount).map { index in
            return String.fromCString(sqlite3_column_name(self.sqliteStatement, Int32(index)))!
        }
    }()
    
    // MARK: - Not public
    
    /**
    The DatabaseSequence builder.
    */
    func fetch<T>(arguments arguments: StatementArguments?, yield: () -> T) -> DatabaseSequence<T> {
        if let arguments = arguments {
            self.arguments = arguments
        }

        if let trace = self.database.configuration.trace {
            trace(sql: self.sql, arguments: self.arguments)
        }
        
        return DatabaseSequence(statement: self, yield: yield)
    }
    
    /// The column index, case insensitive.
    func indexForColumn(named name: String) -> Int? {
        return lowercaseColumnIndexes[name.lowercaseString]
    }
    
    /// Support for indexForColumn(named:)
    private lazy var lowercaseColumnIndexes: [String: Int] = { [unowned self] in
        var indexes = [String: Int]()
        let count = self.columnCount
        // Reverse so that we return indexes for the leftmost columns.
        // SELECT 1 AS a, 2 AS a -> lowercaseColumnIndexes["a”] = 0
        for (index, columnName) in self.columnNames.reverse().enumerate() {
            indexes[columnName.lowercaseString] = count - index - 1
        }
        return indexes
        }()
    
}

/**
A sequence of elements fetched from the database.
*/
public struct DatabaseSequence<T>: SequenceType {
    let statement: SelectStatement
    let yield: () -> T
    
    /// Return a *generator* over the elements of this *sequence*.
    @warn_unused_result
    public func generate() -> DatabaseGenerator<T> {
        // Check that sequence is built on a valid database.
        statement.database.assertValidQueue()
        
        // DatabaseSequence can be restarted:
        statement.reset()
        
        return DatabaseGenerator(statement: statement, yield: yield)
    }
}

/**
A generator of elements fetched from the database.
*/
public struct DatabaseGenerator<T>: GeneratorType {
    let statement: SelectStatement
    let sqliteStatement: SQLiteStatement
    let assertValidQueue: () -> ()
    let yield: () -> T
    
    init(statement: SelectStatement, yield: () -> T) {
        self.statement = statement
        self.sqliteStatement = statement.sqliteStatement
        self.yield = yield
        self.assertValidQueue = statement.database.assertValidQueue
    }
    
    /// Advance to the next element and return it, or `nil` if no next
    /// element exists.
    public func next() -> T? {
        // Check that generator is used on a valid database.
        assertValidQueue()
        
        let code = sqlite3_step(sqliteStatement)
        switch code {
        case SQLITE_DONE:
            return nil
        case SQLITE_ROW:
            return yield()
        default:
            fatalError(DatabaseError(code: code, message: statement.database.lastErrorMessage, sql: statement.sql, arguments: statement.arguments).description)
        }
    }
}

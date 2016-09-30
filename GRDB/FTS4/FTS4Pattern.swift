/// A match pattern for a FTS3 or FTS4 virtual table
public struct FTS4Pattern {
    
    /// The raw pattern string
    let rawPattern: String
    
    /// Creates a pattern from a raw pattern string; throws DatabaseError on invalid syntax.
    ///
    ///     try FTS4Pattern(rawPattern: "and") // OK
    ///     try FTS4Pattern(rawPattern: "AND") // malformed MATCH expression: [AND]
    public init(rawPattern: String) throws {
        try FTS4Pattern.checker.validate(rawPattern)
        self.rawPattern = rawPattern
    }
    
    private static let checker = Checker()
    
    struct Checker {
        private let dbQueue : DatabaseQueue
        private let statement: SelectStatement
        
        init() {
            dbQueue = DatabaseQueue()
            statement = try! dbQueue.inDatabase { db in
                try db.execute("CREATE VIRTUAL TABLE documents USING fts4()")
                return try db.makeSelectStatement("SELECT * FROM documents WHERE content MATCH ?")
            }
        }
        
        func validate(_ rawPattern: String) throws {
            do {
                try dbQueue.inDatabase { _ in
                    statement.unsafeSetArguments([rawPattern])
                    try statement.fetchSequence({}).makeIterator().step()
                }
            } catch let error as DatabaseError {
                throw DatabaseError(code: error.code, message: error.message)
            }
        }
    }
}

extension FTS4Pattern : DatabaseValueConvertible {
    /// TODO
    public var databaseValue: DatabaseValue {
        return rawPattern.databaseValue
    }
    
    /// TODO
    public static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> FTS4Pattern? {
        return String
            .fromDatabaseValue(databaseValue)
            .flatMap { try? FTS4Pattern(rawPattern: $0) }
    }
}

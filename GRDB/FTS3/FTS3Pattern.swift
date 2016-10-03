/// A match pattern for a FTS3 or FTS4 virtual table
public struct FTS3Pattern {
    
    /// The raw pattern string
    let rawPattern: String
    
    /// Creates a pattern from a raw pattern string; throws DatabaseError on invalid syntax.
    ///
    ///     try FTS3Pattern(rawPattern: "and") // OK
    ///     try FTS3Pattern(rawPattern: "AND") // malformed MATCH expression: [AND]
    public init(rawPattern: String) throws {
        try FTS3Pattern.checker.validate(rawPattern)
        self.rawPattern = rawPattern
    }
    
    /// Creates a pattern that matches any token found in the input string;
    /// returns nil if no pattern could be built.
    ///
    ///     try FTS3Pattern(matchingAnyTokenIn: "")        // nil
    ///     try FTS3Pattern(matchingAnyTokenIn: "foo bar") // foo OR bar
    ///
    /// - parameter string: The tokenized string
    /// - parameter tokenizer: The tokenizer to use
    public init?(matchingAnyTokenIn string: String, tokenizer: String) {
        let tokens = FTS3Pattern.tokens(in: string, tokenizer: tokenizer)
        let uniqueTokens = Set(tokens)
        guard !uniqueTokens.isEmpty else {
            return nil
        }
        try? self.init(rawPattern: uniqueTokens.joined(separator: " OR "))
    }
    
    /// Creates a pattern that matches all tokens found in the input string;
    /// returns nil if no pattern could be built.
    ///
    ///     try FTS3Pattern(matchingAllTokensIn: "")        // nil
    ///     try FTS3Pattern(matchingAllTokensIn: "foo bar") // foo AND bar
    ///
    /// - parameter string: The tokenized string
    /// - parameter tokenizer: The tokenizer to use
    public init?(matchingAllTokensIn string: String, tokenizer: String) {
        let tokens = FTS3Pattern.tokens(in: string, tokenizer: tokenizer)
        let uniqueTokens = Set(tokens)
        guard !uniqueTokens.isEmpty else {
            return nil
        }
        try? self.init(rawPattern: uniqueTokens.joined(separator: " AND "))
    }
    
    /// Creates a pattern that matches a contiguous string; returns nil if no
    /// pattern could be built.
    ///
    ///     try FTS3Pattern(matchingPhrase: "")        // nil
    ///     try FTS3Pattern(matchingPhrase: "foo bar") // "foo bar"
    ///
    /// - parameter string: The tokenized string
    /// - parameter tokenizer: The tokenizer to use
    public init?(matchingPhrase string: String, tokenizer: String) {
        let tokens = FTS3Pattern.tokens(in: string, tokenizer: tokenizer)
        guard !tokens.isEmpty else {
            return nil
        }
        try? self.init(rawPattern: "\"" + tokens.joined(separator: " ") + "\"")
    }
    
    private static func tokens(in string: String, tokenizer: String) -> [String] {
        return DatabaseQueue().inDatabase { db in
            try! db.execute("CREATE VIRTUAL TABLE tokens USING fts3tokenize(\(tokenizer.sqlExpression.sql))")
            return String.fetchAll(db, "SELECT token FROM tokens WHERE input = ? ORDER BY position", arguments: [string])
        }
    }
    
    private static let checker = Checker()
    
    private struct Checker {
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

extension FTS3Pattern : DatabaseValueConvertible {
    /// TODO
    public var databaseValue: DatabaseValue {
        return rawPattern.databaseValue
    }
    
    /// TODO
    public static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> FTS3Pattern? {
        return String
            .fromDatabaseValue(databaseValue)
            .flatMap { try? FTS3Pattern(rawPattern: $0) }
    }
}

/// TODO
public func ~= (_ lhs: FTS3Pattern, _ rhs: Column) -> SQLExpression {
    return SQLExpressionBinary(.match, rhs, lhs)
}

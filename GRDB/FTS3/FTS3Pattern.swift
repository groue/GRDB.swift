/// A match pattern for a FTS3 or FTS4 virtual table
public struct FTS3Pattern {
    
    /// The raw pattern string. Guaranteed to be a valid FTS3/4 pattern.
    let rawPattern: String
    
    /// Creates a pattern from a raw pattern string; throws DatabaseError on
    /// invalid syntax.
    ///
    ///     try FTS3Pattern(rawPattern: "and") // OK
    ///     try FTS3Pattern(rawPattern: "AND") // malformed MATCH expression: [AND]
    public init(rawPattern: String) throws {
        // Invalid patterns have SQLite return an error on the first
        // call to sqlite3_step() on a statement that involves that pattern.
        do {
            try DatabaseQueue().inDatabase { db in
                try db.execute("CREATE VIRTUAL TABLE documents USING fts3()")
                let statement = try db.makeSelectStatement("SELECT * FROM documents WHERE content MATCH ?")
                try statement.fetchSequence(arguments: [rawPattern], element: {}).makeIterator().step()
            }
        } catch let error as DatabaseError {
            // Hide private SQL and arguments from rethrown error
            throw DatabaseError(code: error.code, message: error.message)
        }
        
        // Pattern is valid
        self.rawPattern = rawPattern
    }
    
    /// Creates a pattern that matches any token found in the input string;
    /// returns nil if no pattern could be built.
    ///
    ///     FTS3Pattern(matchingAnyTokenIn: "")        // nil
    ///     FTS3Pattern(matchingAnyTokenIn: "foo bar") // foo OR bar
    ///
    /// - parameter string: The tokenized string
    /// - parameter tokenizer: The tokenizer to use
    public init?(matchingAnyTokenIn string: String, tokenizer: String) {
        let tokens = FTS3Pattern.tokens(in: string, tokenizer: tokenizer)
        let uniqueTokens = Set(tokens)
        guard !uniqueTokens.isEmpty else { return nil }
        try? self.init(rawPattern: uniqueTokens.joined(separator: " OR "))
    }
    
    /// Creates a pattern that matches all tokens found in the input string;
    /// returns nil if no pattern could be built.
    ///
    ///     FTS3Pattern(matchingAllTokensIn: "")        // nil
    ///     FTS3Pattern(matchingAllTokensIn: "foo bar") // foo AND bar
    ///
    /// - parameter string: The tokenized string
    /// - parameter tokenizer: The tokenizer to use
    public init?(matchingAllTokensIn string: String, tokenizer: String) {
        let tokens = FTS3Pattern.tokens(in: string, tokenizer: tokenizer)
        let uniqueTokens = Set(tokens)
        guard !uniqueTokens.isEmpty else { return nil }
        try? self.init(rawPattern: uniqueTokens.joined(separator: " AND "))
    }
    
    /// Creates a pattern that matches a contiguous string; returns nil if no
    /// pattern could be built.
    ///
    ///     FTS3Pattern(matchingPhrase: "")        // nil
    ///     FTS3Pattern(matchingPhrase: "foo bar") // "foo bar"
    ///
    /// - parameter string: The tokenized string
    /// - parameter tokenizer: The tokenizer to use
    public init?(matchingPhrase string: String, tokenizer: String) {
        let tokens = FTS3Pattern.tokens(in: string, tokenizer: tokenizer)
        guard !tokens.isEmpty else { return nil }
        try? self.init(rawPattern: "\"" + tokens.joined(separator: " ") + "\"")
    }
    
    private static func tokens(in string: String, tokenizer: String) -> [String] {
        return DatabaseQueue().inDatabase { db in
            try! db.execute("CREATE VIRTUAL TABLE tokens USING fts3tokenize(\(tokenizer.sqlExpression.sql))")
            return String.fetchAll(db, "SELECT token FROM tokens WHERE input = ? ORDER BY position", arguments: [string])
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

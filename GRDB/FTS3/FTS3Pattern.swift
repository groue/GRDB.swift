/// A full text pattern that can query FTS3 and FTS4 virtual tables.
public struct FTS3Pattern {
    
    /// The raw pattern string. Guaranteed to be a valid FTS3/4 pattern.
    let rawPattern: String
    
    /// Creates a pattern from a raw pattern string; throws DatabaseError on
    /// invalid syntax.
    ///
    /// The pattern syntax is documented at https://www.sqlite.org/fts3.html#full_text_index_queries
    ///
    ///     try FTS3Pattern(rawPattern: "and") // OK
    ///     try FTS3Pattern(rawPattern: "AND") // malformed MATCH expression: [AND]
    public init(rawPattern: String) throws {
        // Correctness above all: use SQLite to validate the pattern.
        //
        // Invalid patterns have SQLite return an error on the first
        // call to sqlite3_step() on a statement that matches against
        // that pattern.
        do {
            try DatabaseQueue().inDatabase { db in
                try db.execute("CREATE VIRTUAL TABLE documents USING fts3()")
                try db.makeSelectStatement("SELECT * FROM documents WHERE content MATCH ?")
                    .fetchSequence(arguments: [rawPattern], element: { /* void (ignored) sequence element */ })
                    .makeIterator()
                    .step() // <- invokes sqlite3_step(), throws on invalid pattern
            }
        } catch let error as DatabaseError {
            // Remove private SQL & arguments from the thrown error
            throw DatabaseError(code: error.code, message: error.message, sql: nil, arguments: nil)
        }
        
        // Pattern is valid
        self.rawPattern = rawPattern
    }
    
    /// Creates a pattern that matches any token found in the input string;
    /// returns nil if no pattern could be built.
    ///
    ///     FTS3Pattern(matchingAnyTokenIn: "")        // nil
    ///     FTS3Pattern(matchingAnyTokenIn: "foo bar") // foo OR bar
    public init?(matchingAnyTokenIn string: String) {
        // Tokenize with the simple tokenizer, because it does not lose
        // information used by other tokenizers, and turns special syntax
        // elements such as "AND" and "OR" into their neutral lowercase
        // equivalents.
        let tokens = FTS3Pattern.tokenize(string, tokenizer: "simple")
        let uniqueTokens = Set(tokens)
        guard !uniqueTokens.isEmpty else { return nil }
        try? self.init(rawPattern: uniqueTokens.joined(separator: " OR "))
    }
    
    /// Creates a pattern that matches all tokens found in the input string;
    /// returns nil if no pattern could be built.
    ///
    ///     FTS3Pattern(matchingAllTokensIn: "")        // nil
    ///     FTS3Pattern(matchingAllTokensIn: "foo bar") // foo AND bar
    public init?(matchingAllTokensIn string: String) {
        // See init(matchingAnyTokenIn:) comment on the choice of the "simple" tokenizer
        let tokens = FTS3Pattern.tokenize(string, tokenizer: "simple")
        let uniqueTokens = Set(tokens)
        guard !uniqueTokens.isEmpty else { return nil }
        try? self.init(rawPattern: uniqueTokens.joined(separator: " AND "))
    }
    
    /// Creates a pattern that matches a contiguous string; returns nil if no
    /// pattern could be built.
    ///
    ///     FTS3Pattern(matchingPhrase: "")        // nil
    ///     FTS3Pattern(matchingPhrase: "foo bar") // "foo bar"
    public init?(matchingPhrase string: String) {
        // See init(matchingAnyTokenIn:) comment on the choice of the "simple" tokenizer
        let tokens = FTS3Pattern.tokenize(string, tokenizer: "simple")
        guard !tokens.isEmpty else { return nil }
        try? self.init(rawPattern: "\"" + tokens.joined(separator: " ") + "\"")
    }
    
    /// Returns an array of tokens found in the string argument.
    ///
    ///     FTS3Pattern.tokenize("foo bar", tokenizer: "simple") // ["foo", "bar"]
    private static func tokenize(_ string: String, tokenizer: String) -> [String] {
        return DatabaseQueue().inDatabase { db in
            try! db.execute("CREATE VIRTUAL TABLE tokens USING fts3tokenize(\(tokenizer.sqlExpression.sql))")   // literal tokenizer required
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
// TODO: use match(pattern) function instead?
public func ~= (_ lhs: FTS3Pattern, _ rhs: Column) -> SQLExpression {
    return SQLExpressionBinary(.match, rhs, lhs)
}

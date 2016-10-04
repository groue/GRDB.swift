/// A full text pattern that can query FTS3 and FTS4 virtual tables.
public struct FTS3Pattern {
    
    /// The raw pattern string. Guaranteed to be a valid FTS3/4 pattern.
    public let rawPattern: String
    
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
    ///
    /// The string is tokenized with the `simple` tokenizer unless specified
    /// otherwise:
    ///
    ///     // frustration
    ///     FTS3Pattern(matchingAnyTokenIn: "frustration")
    ///     // frustrat
    ///     FTS3Pattern(matchingAnyTokenIn: "frustration", tokenizer: .porter)
    ///
    /// - parameter string: The string to turn into an FTS3 pattern
    /// - parameter tokenizer: An FTS3Tokenizer - defaults "simple"
    public init?(matchingAnyTokenIn string: String, tokenizer: FTS3Tokenizer = .simple) {
        let tokens = FTS3Pattern.tokenize(string, tokenizer: tokenizer)
        guard !tokens.isEmpty else { return nil }
        try? self.init(rawPattern: tokens.joined(separator: " OR "))
    }
    
    /// Creates a pattern that matches all tokens found in the input string;
    /// returns nil if no pattern could be built.
    ///
    ///     FTS3Pattern(matchingAllTokensIn: "")        // nil
    ///     FTS3Pattern(matchingAllTokensIn: "foo bar") // foo AND bar
    ///
    /// The string is tokenized with the `simple` tokenizer unless specified
    /// otherwise:
    ///
    ///     // frustration
    ///     FTS3Pattern(matchingAllTokensIn: "frustration")
    ///     // frustrat
    ///     FTS3Pattern(matchingAllTokensIn: "frustration", tokenizer: .porter)
    ///
    /// - parameter string: The string to turn into an FTS3 pattern
    /// - parameter tokenizer: An FTS3Tokenizer - defaults "simple"
    public init?(matchingAllTokensIn string: String, tokenizer: FTS3Tokenizer = .simple) {
        let tokens = FTS3Pattern.tokenize(string, tokenizer: tokenizer)
        guard !tokens.isEmpty else { return nil }
        try? self.init(rawPattern: tokens.joined(separator: " AND "))
    }
    
    /// Creates a pattern that matches a contiguous string; returns nil if no
    /// pattern could be built.
    ///
    ///     FTS3Pattern(matchingPhrase: "")        // nil
    ///     FTS3Pattern(matchingPhrase: "foo bar") // "foo bar"
    ///
    /// The string is tokenized with the `simple` tokenizer unless specified
    /// otherwise:
    ///
    ///     // "frustration"
    ///     FTS3Pattern(matchingPhrase: "frustration")
    ///     // "frustrat"
    ///     FTS3Pattern(matchingPhrase: "frustration", tokenizer: .porter)
    ///
    /// - parameter string: The string to turn into an FTS3 pattern
    /// - parameter tokenizer: An FTS3Tokenizer - defaults "simple"
    public init?(matchingPhrase string: String, tokenizer: FTS3Tokenizer = .simple) {
        let tokens = FTS3Pattern.tokenize(string, tokenizer: tokenizer)
        guard !tokens.isEmpty else { return nil }
        try? self.init(rawPattern: "\"" + tokens.joined(separator: " ") + "\"")
    }
    
    /// Returns an array of tokens found in the string argument.
    ///
    ///     FTS3Pattern.tokenize("foo bar", tokenizer: .simple) // ["foo", "bar"]
    private static func tokenize(_ string: String, tokenizer: FTS3Tokenizer) -> [String] {
        return DatabaseQueue().inDatabase { db in
            var tokenizerChunks: [String] = []
            tokenizerChunks.append(tokenizer.name)
            for option in tokenizer.options {
                tokenizerChunks.append("\"\(option)\"")
            }
            let tokenizerSQL = tokenizerChunks.joined(separator: ", ")
            try! db.execute("CREATE VIRTUAL TABLE tokens USING fts3tokenize(\(tokenizerSQL))")
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

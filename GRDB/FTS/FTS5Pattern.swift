public struct FTS5Pattern {
    
    /// The raw pattern string. Guaranteed to be a valid FTS5 pattern.
    public let rawPattern: String
    
    /// Creates a pattern from a raw pattern string; throws DatabaseError on
    /// invalid syntax.
    ///
    /// The pattern syntax is documented at https://www.sqlite.org/fts5.html#full_text_query_syntax
    ///
    ///     try FTS5Pattern(rawPattern: "and") // OK
    ///     try FTS5Pattern(rawPattern: "AND") // malformed MATCH expression: [AND]
    public init(rawPattern: String) throws {
        // Correctness above all: use SQLite to validate the pattern.
        //
        // Invalid patterns have SQLite return an error on the first
        // call to sqlite3_step() on a statement that matches against
        // that pattern.
        var requiredColumns: [String] = []
        while true {
            do {
                try DatabaseQueue().inDatabase { db in
                    try db.create(virtualTable: "documents", using: FTS5()) { t in
                        if requiredColumns.isEmpty {
                            t.column("content")
                        } else {
                            for column in requiredColumns {
                                t.column(column)
                            }
                        }
                    }
                    try db.makeSelectStatement("SELECT * FROM documents WHERE documents MATCH ?")
                        .fetchSequence(arguments: [rawPattern], element: { /* void (ignored) sequence element */ })
                        .makeIterator()
                        .step() // <- invokes sqlite3_step(), throws on invalid pattern
                }
                break
            } catch let error as DatabaseError {
                if let message = error.message, message.hasPrefix("no such column: ") {
                    // Column is message suffix.
                    let characters = message.characters
                    let suffixIndex = characters.index(characters.startIndex, offsetBy: 16)
                    let column = String(characters.suffix(from: suffixIndex))
                    requiredColumns.append(column)
                } else {
                    // Remove private SQL & arguments from the thrown error
                    throw DatabaseError(code: error.code, message: error.message, sql: nil, arguments: nil)
                }
            }
        }
        
        // Pattern is valid
        self.rawPattern = rawPattern
    }
    
    /// Creates a pattern that matches any token found in the input string;
    /// returns nil if no pattern could be built.
    ///
    ///     FTS5Pattern(matchingAnyTokenIn: "")        // nil
    ///     FTS5Pattern(matchingAnyTokenIn: "foo bar") // foo OR bar
    ///
    /// - parameter string: The string to turn into an FTS5 pattern
    public init?(matchingAnyTokenIn string: String) {
        // TODO: use an FTS5 tokenization API, if it exists
        let tokens = FTS3Tokenizer.simple.tokenize(string)
        guard !tokens.isEmpty else { return nil }
        try? self.init(rawPattern: tokens.joined(separator: " OR "))
    }
    
    /// Creates a pattern that matches all tokens found in the input string;
    /// returns nil if no pattern could be built.
    ///
    ///     FTS5Pattern(matchingAllTokensIn: "")        // nil
    ///     FTS5Pattern(matchingAllTokensIn: "foo bar") // foo AND bar
    ///
    /// - parameter string: The string to turn into an FTS5 pattern
    public init?(matchingAllTokensIn string: String) {
        // TODO: use an FTS5 tokenization API, if it exists
        let tokens = FTS3Tokenizer.simple.tokenize(string)
        guard !tokens.isEmpty else { return nil }
        try? self.init(rawPattern: tokens.joined(separator: " AND "))
    }
    
    /// Creates a pattern that matches a contiguous string; returns nil if no
    /// pattern could be built.
    ///
    ///     FTS5Pattern(matchingPhrase: "")        // nil
    ///     FTS5Pattern(matchingPhrase: "foo bar") // "foo bar"
    ///
    /// - parameter string: The string to turn into an FTS5 pattern
    public init?(matchingPhrase string: String) {
        // TODO: use an FTS5 tokenization API, if it exists
        let tokens = FTS3Tokenizer.simple.tokenize(string)
        guard !tokens.isEmpty else { return nil }
        try? self.init(rawPattern: "\"" + tokens.joined(separator: " ") + "\"")
    }
}

extension FTS5Pattern : DatabaseValueConvertible {
    /// TODO
    public var databaseValue: DatabaseValue {
        return rawPattern.databaseValue
    }
    
    /// TODO
    public static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> FTS5Pattern? {
        return String
            .fromDatabaseValue(databaseValue)
            .flatMap { try? FTS5Pattern(rawPattern: $0) }
    }
}

extension Column {
    /// TODO
    public func match(_ pattern: FTS5Pattern) -> SQLExpression {
        return SQLExpressionBinary(.match, self, pattern)
    }
}

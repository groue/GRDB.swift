/// A full text pattern for querying FTS3 virtual tables.
///
/// `FTS3Pattern` can be used with both ``FTS3`` and ``FTS4`` tables.
///
/// Related SQLite documentation: <https://www.sqlite.org/fts3.html#full_text_index_queries>
///
/// ## Topics
///
/// ### Creating Raw FTS3 Patterns
///
/// - ``init(rawPattern:)``
///
/// ### Creating FTS3 Patterns from User Input
///
/// - ``init(matchingAllPrefixesIn:)``
/// - ``init(matchingAllTokensIn:)``
/// - ``init(matchingAnyTokenIn:)``
/// - ``init(matchingPhrase:)``
public struct FTS3Pattern {
    /// The raw pattern string.
    ///
    /// It is guaranteed to be a valid FTS3/4 pattern.
    public let rawPattern: String
    
    /// Creates a pattern from a raw pattern string.
    ///
    /// The pattern syntax is documented at <https://www.sqlite.org/fts3.html#full_text_index_queries>
    ///
    /// For example:
    ///
    /// ```swift
    /// // OK
    /// let pattern = try FTS3Pattern(rawPattern: "and")
    ///
    /// // Throws an error: malformed MATCH expression: [AND]
    /// let pattern = try FTS3Pattern(rawPattern: "AND")
    /// ```
    ///
    /// - throws: A ``DatabaseError`` if the pattern has an invalid syntax.
    public init(rawPattern: String) throws {
        // Correctness above all: use SQLite to validate the pattern.
        //
        // Invalid patterns have SQLite return an error on the first
        // call to sqlite3_step() on a statement that matches against
        // that pattern.
        do {
            try DatabaseQueue().inDatabase { db in
                try db.execute(literal: """
                    CREATE VIRTUAL TABLE documents USING fts3();
                    SELECT * FROM documents WHERE content MATCH \(rawPattern);
                    """)
            }
        } catch let error as DatabaseError {
            // Remove private SQL & arguments from the thrown error
            throw DatabaseError(resultCode: error.extendedResultCode, message: error.message)
        }
        
        // Pattern is valid
        self.rawPattern = rawPattern
    }
    
    /// Creates a pattern that matches any token found in the input string.
    ///
    /// The result is nil if no pattern could be built.
    ///
    /// For example:
    ///
    /// ```swift
    /// FTS3Pattern(matchingAnyTokenIn: "")        // nil
    /// FTS3Pattern(matchingAnyTokenIn: "foo bar") // foo OR bar
    /// ```
    ///
    /// - parameter string: The string to turn into an FTS3 pattern.
    public init?(matchingAnyTokenIn string: String) {
        guard let tokens = try? FTS3.tokenize(string, withTokenizer: .simple),
              !tokens.isEmpty
        else { return nil }
        try? self.init(rawPattern: tokens.joined(separator: " OR "))
    }
    
    /// Creates a pattern that matches all tokens found in the input string.
    ///
    /// The result is nil if no pattern could be built.
    ///
    /// For example:
    ///
    /// ```swift
    /// FTS3Pattern(matchingAllTokensIn: "")        // nil
    /// FTS3Pattern(matchingAllTokensIn: "foo bar") // foo bar
    /// ```
    ///
    /// - parameter string: The string to turn into an FTS3 pattern.
    public init?(matchingAllTokensIn string: String) {
        guard let tokens = try? FTS3.tokenize(string, withTokenizer: .simple),
              !tokens.isEmpty
        else { return nil }
        try? self.init(rawPattern: tokens.joined(separator: " "))
    }
    
    /// Creates a pattern that matches all token prefixes found in the input
    /// string.
    ///
    /// The result is nil if no pattern could be built.
    ///
    /// For example:
    ///
    /// ```swift
    /// FTS3Pattern(matchingAllTokensIn: "")        // nil
    /// FTS3Pattern(matchingAllTokensIn: "foo bar") // foo* bar*
    /// ```
    ///
    /// - parameter string: The string to turn into an FTS3 pattern.
    public init?(matchingAllPrefixesIn string: String) {
        guard let tokens = try? FTS3.tokenize(string, withTokenizer: .simple),
              !tokens.isEmpty
        else { return nil }
        try? self.init(rawPattern: tokens.map { "\($0)*" }.joined(separator: " "))
    }
    
    /// Creates a pattern that matches a contiguous string.
    ///
    /// The result is nil if no pattern could be built.
    ///
    /// For example:
    ///
    /// ```swift
    /// FTS3Pattern(matchingPhrase: "")        // nil
    /// FTS3Pattern(matchingPhrase: "foo bar") // "foo bar"
    /// ```
    ///
    /// - parameter string: The string to turn into an FTS3 pattern.
    public init?(matchingPhrase string: String) {
        guard let tokens = try? FTS3.tokenize(string, withTokenizer: .simple),
              !tokens.isEmpty
        else { return nil }
        try? self.init(rawPattern: "\"" + tokens.joined(separator: " ") + "\"")
    }
}

extension FTS3Pattern: DatabaseValueConvertible {
    public var databaseValue: DatabaseValue {
        rawPattern.databaseValue
    }
    
    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> FTS3Pattern? {
        String
            .fromDatabaseValue(dbValue)
            .flatMap { try? FTS3Pattern(rawPattern: $0) }
    }
}

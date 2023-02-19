#if SQLITE_ENABLE_FTS5
/// A full text pattern for querying ``FTS5`` virtual tables.
///
/// Related SQLite documentation: <https://www.sqlite.org/fts5.html#full_text_query_syntax>
///
/// ## Topics
///
/// ### Creating Raw FTS5 Patterns
///
/// - ``Database/makeFTS5Pattern(rawPattern:forTable:)``
/// 
/// ### Creating FTS5 Patterns from User Input
///
/// - ``init(matchingAllPrefixesIn:)``
/// - ``init(matchingAllTokensIn:)``
/// - ``init(matchingAnyTokenIn:)``
/// - ``init(matchingPhrase:)``
/// - ``init(matchingPrefixPhrase:)``
public struct FTS5Pattern {
    
    /// The raw pattern string.
    ///
    /// It is guaranteed to be a valid FTS5 pattern.
    public let rawPattern: String
    
    /// Creates a pattern that matches any token found in the input string.
    ///
    /// The result is nil if no pattern could be built.
    ///
    /// For example:
    ///
    /// ```swift
    /// FTS5Pattern(matchingAnyTokenIn: "")        // nil
    /// FTS5Pattern(matchingAnyTokenIn: "foo bar") // foo OR bar
    /// ```
    ///
    /// - parameter string: The string to turn into an FTS5 pattern.
    public init?(matchingAnyTokenIn string: String) {
        guard let tokens = try? FTS5.tokenize(query: string), !tokens.isEmpty else {
            return nil
        }
        try? self.init(rawPattern: tokens.joined(separator: " OR "))
    }
    
    /// Creates a pattern that matches all tokens found in the input string.
    ///
    /// The result is nil if no pattern could be built.
    ///
    /// For example:
    ///
    /// ```swift
    /// FTS5Pattern(matchingAllTokensIn: "")        // nil
    /// FTS5Pattern(matchingAllTokensIn: "foo bar") // foo bar
    /// ```
    ///
    /// - parameter string: The string to turn into an FTS5 pattern.
    public init?(matchingAllTokensIn string: String) {
        guard let tokens = try? FTS5.tokenize(query: string), !tokens.isEmpty else {
            return nil
        }
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
    /// FTS5Pattern(matchingAllTokensIn: "")        // nil
    /// FTS5Pattern(matchingAllTokensIn: "foo bar") // foo* bar*
    /// ```
    ///
    /// - parameter string: The string to turn into an FTS5 pattern.
    public init?(matchingAllPrefixesIn string: String) {
        guard let tokens = try? FTS5.tokenize(query: string), !tokens.isEmpty else {
            return nil
        }
        try? self.init(rawPattern: tokens.map { "\($0)*" }.joined(separator: " "))
    }
    
    /// Creates a pattern that matches a contiguous string.
    ///
    /// The result is nil if no pattern could be built.
    ///
    /// For example:
    ///
    /// ```swift
    /// FTS5Pattern(matchingPhrase: "")        // nil
    /// FTS5Pattern(matchingPhrase: "foo bar") // "foo bar"
    /// ```
    ///
    /// - parameter string: The string to turn into an FTS5 pattern.
    public init?(matchingPhrase string: String) {
        guard let tokens = try? FTS5.tokenize(query: string), !tokens.isEmpty else {
            return nil
        }
        try? self.init(rawPattern: "\"" + tokens.joined(separator: " ") + "\"")
    }
    
    /// Creates a pattern that matches the prefix of an indexed document.
    ///
    /// The result is nil if no pattern could be built.
    ///
    /// The returned pattern matches a prefix made of full tokens: "the bat"
    /// matches "the bat is happy", but not "mind the bat", or "the batcave
    /// is dark".
    ///
    /// For example:
    ///
    /// ```swift
    /// FTS5Pattern(matchingPrefixPhrase: "")         // nil
    /// FTS5Pattern(matchingPrefixPhrase: "the word") // ^"the word"
    /// ```
    ///
    /// - parameter string: The string to turn into an FTS5 pattern
    public init?(matchingPrefixPhrase string: String) {
        guard let tokens = try? FTS5.tokenize(query: string), !tokens.isEmpty else {
            return nil
        }
        try? self.init(rawPattern: "^\"" + tokens.joined(separator: " ") + "\"")
    }
    
    init(rawPattern: String, allowedColumns: [String] = []) throws {
        // Correctness above all: use SQLite to validate the pattern.
        //
        // Invalid patterns have SQLite return an error on the first
        // call to sqlite3_step() on a statement that matches against
        // that pattern.
        do {
            try DatabaseQueue().inDatabase { db in
                try db.create(virtualTable: "document", using: FTS5()) { t in
                    if allowedColumns.isEmpty {
                        t.column("__grdb__")
                    } else {
                        for column in allowedColumns {
                            t.column(column)
                        }
                    }
                }
                try db.makeStatement(sql: "SELECT * FROM document WHERE document MATCH ?")
                    .makeCursor(arguments: [rawPattern])
                    .next() // error on next() for invalid patterns
            }
        } catch let error as DatabaseError {
            // Remove private SQL & arguments from the thrown error
            throw DatabaseError(resultCode: error.extendedResultCode, message: error.message)
        }
        
        // Pattern is valid
        self.rawPattern = rawPattern
    }
}

extension Database {
    
    // MARK: - FTS5
    
    /// Creates an FTS5 pattern from a raw pattern string.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     // OK
    ///     let pattern = try db.makeFTS5Pattern(rawPattern: "and", forTable: "document")
    ///
    ///     // Throws error: malformed MATCH expression: [AND]
    ///     let pattern = try db.makeFTS5Pattern(rawPattern: "AND", forTable: "document")
    /// }
    /// ```
    ///
    /// - parameter rawPattern: A pattern that follows the
    ///   [Full-text Query Syntax](https://www.sqlite.org/fts5.html#full_text_query_syntax).
    /// - parameter table: The full-text table that the pattern is intended to
    ///   match against.
    /// - returns: A valid FTS5 pattern.
    /// - throws: A ``DatabaseError`` if the raw pattern is invalid.
    public func makeFTS5Pattern(rawPattern: String, forTable table: String) throws -> FTS5Pattern {
        try FTS5Pattern(rawPattern: rawPattern, allowedColumns: columns(in: table).map(\.name))
    }
}

extension FTS5Pattern: DatabaseValueConvertible {
    public var databaseValue: DatabaseValue {
        rawPattern.databaseValue
    }
    
    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> FTS5Pattern? {
        String
            .fromDatabaseValue(dbValue)
            .flatMap { try? FTS5Pattern(rawPattern: $0) }
    }
}
#endif

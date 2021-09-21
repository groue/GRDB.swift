#if SQLITE_ENABLE_FTS5
/// A full text pattern that can query FTS5 virtual tables.
public struct FTS5Pattern {
    
    /// The raw pattern string. Guaranteed to be a valid FTS5 pattern.
    public let rawPattern: String
    
    /// Creates a pattern that matches any token found in the input string;
    /// returns nil if no pattern could be built.
    ///
    ///     FTS5Pattern(matchingAnyTokenIn: "")        // nil
    ///     FTS5Pattern(matchingAnyTokenIn: "foo bar") // foo OR bar
    ///
    /// - parameter string: The string to turn into an FTS5 pattern
    public init?(matchingAnyTokenIn string: String) {
        guard let tokens = try? FTS5.tokenize(query: string), !tokens.isEmpty else {
            return nil
        }
        try? self.init(rawPattern: tokens.joined(separator: " OR "))
    }
    
    /// Creates a pattern that matches all tokens found in the input string;
    /// returns nil if no pattern could be built.
    ///
    ///     FTS5Pattern(matchingAllTokensIn: "")        // nil
    ///     FTS5Pattern(matchingAllTokensIn: "foo bar") // foo bar
    ///
    /// - parameter string: The string to turn into an FTS5 pattern
    public init?(matchingAllTokensIn string: String) {
        guard let tokens = try? FTS5.tokenize(query: string), !tokens.isEmpty else {
            return nil
        }
        try? self.init(rawPattern: tokens.joined(separator: " "))
    }
    
    /// Creates a pattern that matches all token prefixes found in the input
    /// string; returns nil if no pattern could be built.
    ///
    ///     FTS3Pattern(matchingAllTokensIn: "")        // nil
    ///     FTS3Pattern(matchingAllTokensIn: "foo bar") // foo* bar*
    ///
    /// - parameter string: The string to turn into an FTS3 pattern
    public init?(matchingAllPrefixesIn string: String) {
        guard let tokens = try? FTS5.tokenize(query: string), !tokens.isEmpty else {
            return nil
        }
        try? self.init(rawPattern: tokens.map { "\($0)*" }.joined(separator: " "))
    }
    
    /// Creates a pattern that matches a contiguous string; returns nil if no
    /// pattern could be built.
    ///
    ///     FTS5Pattern(matchingPhrase: "")        // nil
    ///     FTS5Pattern(matchingPhrase: "foo bar") // "foo bar"
    ///
    /// - parameter string: The string to turn into an FTS5 pattern
    public init?(matchingPhrase string: String) {
        guard let tokens = try? FTS5.tokenize(query: string), !tokens.isEmpty else {
            return nil
        }
        try? self.init(rawPattern: "\"" + tokens.joined(separator: " ") + "\"")
    }
    
    /// Creates a pattern that matches the prefix of an indexed document;
    /// returns nil if no pattern could be built.
    ///
    ///     FTS5Pattern(matchingPrefixPhrase: "")         // nil
    ///     FTS5Pattern(matchingPrefixPhrase: "the word") // ^"the word"
    ///
    /// This pattern matches a prefix made of full tokens: "the bat" matches
    /// "the bat is happy", but not "mind the bat", or "the batcave is dark".
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
    
    /// Creates a pattern from a raw pattern string; throws DatabaseError on
    /// invalid syntax.
    ///
    /// The pattern syntax is documented at <https://www.sqlite.org/fts5.html#full_text_query_syntax>
    ///
    ///     try db.makeFTS5Pattern(rawPattern: "and", forTable: "document") // OK
    ///     try db.makeFTS5Pattern(rawPattern: "AND", forTable: "document") // malformed MATCH expression: [AND]
    public func makeFTS5Pattern(rawPattern: String, forTable table: String) throws -> FTS5Pattern {
        try FTS5Pattern(rawPattern: rawPattern, allowedColumns: columns(in: table).map(\.name))
    }
}

extension FTS5Pattern: DatabaseValueConvertible {
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        rawPattern.databaseValue
    }
    
    /// Returns an FTS5Pattern initialized from *dbValue*, if it
    /// contains a suitable value.
    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> FTS5Pattern? {
        String
            .fromDatabaseValue(dbValue)
            .flatMap { try? FTS5Pattern(rawPattern: $0) }
    }
}
#endif

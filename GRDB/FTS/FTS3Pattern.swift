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
                try db.execute(sql: "CREATE VIRTUAL TABLE documents USING fts3()")
                try db.execute(sql: "SELECT * FROM documents WHERE content MATCH ?", arguments: [rawPattern])
            }
        } catch let error as DatabaseError {
            // Remove private SQL & arguments from the thrown error
            throw DatabaseError(resultCode: error.extendedResultCode, message: error.message)
        }
        
        // Pattern is valid
        self.rawPattern = rawPattern
    }
    
    #if GRDBCUSTOMSQLITE || GRDBCIPHER
    /// Creates a pattern that matches any token found in the input string;
    /// returns nil if no pattern could be built.
    ///
    ///     FTS3Pattern(matchingAnyTokenIn: "")        // nil
    ///     FTS3Pattern(matchingAnyTokenIn: "foo bar") // foo OR bar
    ///
    /// - parameter string: The string to turn into an FTS3 pattern
    public init?(matchingAnyTokenIn string: String) {
        let tokens = FTS3TokenizerDescriptor.simple.tokenize(string)
        guard !tokens.isEmpty else { return nil }
        try? self.init(rawPattern: tokens.joined(separator: " OR "))
    }
    
    /// Creates a pattern that matches all tokens found in the input string;
    /// returns nil if no pattern could be built.
    ///
    ///     FTS3Pattern(matchingAllTokensIn: "")        // nil
    ///     FTS3Pattern(matchingAllTokensIn: "foo bar") // foo bar
    ///
    /// - parameter string: The string to turn into an FTS3 pattern
    public init?(matchingAllTokensIn string: String) {
        let tokens = FTS3TokenizerDescriptor.simple.tokenize(string)
        guard !tokens.isEmpty else { return nil }
        try? self.init(rawPattern: tokens.joined(separator: " "))
    }
    
    /// Creates a pattern that matches a contiguous string; returns nil if no
    /// pattern could be built.
    ///
    ///     FTS3Pattern(matchingPhrase: "")        // nil
    ///     FTS3Pattern(matchingPhrase: "foo bar") // "foo bar"
    ///
    /// - parameter string: The string to turn into an FTS3 pattern
    public init?(matchingPhrase string: String) {
        let tokens = FTS3TokenizerDescriptor.simple.tokenize(string)
        guard !tokens.isEmpty else { return nil }
        try? self.init(rawPattern: "\"" + tokens.joined(separator: " ") + "\"")
    }
    #else
    /// Creates a pattern that matches any token found in the input string;
    /// returns nil if no pattern could be built.
    ///
    ///     FTS3Pattern(matchingAnyTokenIn: "")        // nil
    ///     FTS3Pattern(matchingAnyTokenIn: "foo bar") // foo OR bar
    ///
    /// - parameter string: The string to turn into an FTS3 pattern
    @available(OSX 10.10, *)
    public init?(matchingAnyTokenIn string: String) {
        let tokens = FTS3TokenizerDescriptor.simple.tokenize(string)
        guard !tokens.isEmpty else { return nil }
        try? self.init(rawPattern: tokens.joined(separator: " OR "))
    }
    
    /// Creates a pattern that matches all tokens found in the input string;
    /// returns nil if no pattern could be built.
    ///
    ///     FTS3Pattern(matchingAllTokensIn: "")        // nil
    ///     FTS3Pattern(matchingAllTokensIn: "foo bar") // foo bar
    ///
    /// - parameter string: The string to turn into an FTS3 pattern
    @available(OSX 10.10, *)
    public init?(matchingAllTokensIn string: String) {
        let tokens = FTS3TokenizerDescriptor.simple.tokenize(string)
        guard !tokens.isEmpty else { return nil }
        try? self.init(rawPattern: tokens.joined(separator: " "))
    }
    
    /// Creates a pattern that matches a contiguous string; returns nil if no
    /// pattern could be built.
    ///
    ///     FTS3Pattern(matchingPhrase: "")        // nil
    ///     FTS3Pattern(matchingPhrase: "foo bar") // "foo bar"
    ///
    /// - parameter string: The string to turn into an FTS3 pattern
    @available(OSX 10.10, *)
    public init?(matchingPhrase string: String) {
        let tokens = FTS3TokenizerDescriptor.simple.tokenize(string)
        guard !tokens.isEmpty else { return nil }
        try? self.init(rawPattern: "\"" + tokens.joined(separator: " ") + "\"")
    }
    #endif
}

extension FTS3Pattern: DatabaseValueConvertible {
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        return rawPattern.databaseValue
    }
    
    /// Returns an FTS3Pattern initialized from *dbValue*, if it contains
    /// a suitable value.
    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> FTS3Pattern? {
        return String
            .fromDatabaseValue(dbValue)
            .flatMap { try? FTS3Pattern(rawPattern: $0) }
    }
}

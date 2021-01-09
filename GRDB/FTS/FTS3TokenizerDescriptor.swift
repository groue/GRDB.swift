/// An FTS3 tokenizer, suitable for FTS3 and FTS4 table definitions:
///
///     db.create(virtualTable: "book", using: FTS4()) { t in
///         t.tokenizer = .simple // FTS3TokenizerDescriptor
///     }
///
/// See https://www.sqlite.org/fts3.html#tokenizer
public struct FTS3TokenizerDescriptor {
    let name: String
    let arguments: [String]
    
    init(_ name: String, arguments: [String] = []) {
        self.name = name
        self.arguments = arguments
    }
    
    /// The "simple" tokenizer.
    ///
    ///     db.create(virtualTable: "book", using: FTS4()) { t in
    ///         t.tokenizer = .simple
    ///     }
    ///
    /// See https://www.sqlite.org/fts3.html#tokenizer
    public static let simple = FTS3TokenizerDescriptor("simple")
    
    /// The "porter" tokenizer.
    ///
    ///     db.create(virtualTable: "book", using: FTS4()) { t in
    ///         t.tokenizer = .porter
    ///     }
    ///
    /// See https://www.sqlite.org/fts3.html#tokenizer
    public static let porter = FTS3TokenizerDescriptor("porter")
    
    /// The "unicode61" tokenizer.
    ///
    ///     db.create(virtualTable: "book", using: FTS4()) { t in
    ///         t.tokenizer = .unicode61()
    ///     }
    ///
    /// - parameters:
    ///     - diacritics: By default SQLite will strip diacritics from
    ///       latin characters.
    ///     - separators: Unless empty (the default), SQLite will consider these
    ///       characters as token separators.
    ///     - tokenCharacters: Unless empty (the default), SQLite will consider
    ///       these characters as token characters.
    ///
    /// See https://www.sqlite.org/fts3.html#tokenizer
    public static func unicode61(
        diacritics: FTS3.Diacritics = .removeLegacy,
        separators: Set<Character> = [],
        tokenCharacters: Set<Character> = [])
    -> FTS3TokenizerDescriptor
    {
        _unicode61(diacritics: diacritics, separators: separators, tokenCharacters: tokenCharacters)
    }
    
    private static func _unicode61(
        diacritics: FTS3.Diacritics,
        separators: Set<Character> = [],
        tokenCharacters: Set<Character> = [])
    -> FTS3TokenizerDescriptor
    {
        var arguments: [String] = []
        switch diacritics {
        case .removeLegacy:
            break
        case .keep:
            arguments.append("remove_diacritics=0")
        #if GRDBCUSTOMSQLITE
        case .remove:
            arguments.append("remove_diacritics=2")
        #elseif !GRDBCIPHER
        case .remove:
            arguments.append("remove_diacritics=2")
        #endif
        }
        if !separators.isEmpty {
            // TODO: test "=" and "\"", "(" and ")" as separators, with
            // both FTS3Pattern(matchingAnyTokenIn:tokenizer:)
            // and Database.create(virtualTable:using:)
            arguments.append("separators=" + separators.sorted().map { String($0) }.joined())
        }
        if !tokenCharacters.isEmpty {
            // TODO: test "=" and "\"", "(" and ")" as tokenCharacters, with
            // both FTS3Pattern(matchingAnyTokenIn:tokenizer:)
            // and Database.create(virtualTable:using:)
            arguments.append("tokenchars=" + tokenCharacters.sorted().map { String($0) }.joined())
        }
        return FTS3TokenizerDescriptor("unicode61", arguments: arguments)
    }
    
    func tokenize(_ string: String) -> [String] {
        _tokenize(string)
    }
    
    /// Returns an array of tokens found in the string argument.
    ///
    ///     FTS3TokenizerDescriptor.simple.tokenize("foo bar") // ["foo", "bar"]
    private func _tokenize(_ string: String) -> [String] {
        DatabaseQueue().inDatabase { db in
            var tokenizerChunks: [String] = []
            tokenizerChunks.append(name)
            for option in arguments {
                tokenizerChunks.append("\"\(option)\"")
            }
            let tokenizerSQL = tokenizerChunks.joined(separator: ", ")
            // Assume fts3tokenize virtual table in an in-memory database always succeeds
            try! db.execute(sql: "CREATE VIRTUAL TABLE tokens USING fts3tokenize(\(tokenizerSQL))")
            return try! String.fetchAll(db, sql: """
                SELECT token FROM tokens WHERE input = ? ORDER BY position
                """, arguments: [string])
        }
    }
}

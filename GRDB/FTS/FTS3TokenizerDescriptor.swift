/// An FTS3 tokenizer, suitable for FTS3 and FTS4 table definitions:
///
///     db.create(virtualTable: "books", using: FTS4()) { t in
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
    ///     db.create(virtualTable: "books", using: FTS4()) { t in
    ///         t.tokenizer = .simple
    ///     }
    ///
    /// See https://www.sqlite.org/fts3.html#tokenizer
    public static let simple = FTS3TokenizerDescriptor("simple")
    
    /// The "porter" tokenizer.
    ///
    ///     db.create(virtualTable: "books", using: FTS4()) { t in
    ///         t.tokenizer = .porter
    ///     }
    ///
    /// See https://www.sqlite.org/fts3.html#tokenizer
    public static let porter = FTS3TokenizerDescriptor("porter")
    
    /// The "unicode61" tokenizer.
    ///
    ///     db.create(virtualTable: "books", using: FTS4()) { t in
    ///         t.tokenizer = .unicode61()
    ///     }
    ///
    /// - parameters:
    ///     - removeDiacritics: If true (the default), then SQLite will strip
    ///       diacritics from latin characters.
    ///     - separators: Unless empty (the default), SQLite will consider these
    ///       characters as token separators.
    ///     - tokenCharacters: Unless empty (the default), SQLite will consider
    ///       these characters as token characters.
    ///
    /// See https://www.sqlite.org/fts3.html#tokenizer
    public static func unicode61(removeDiacritics: Bool = true, separators: Set<Character> = [], tokenCharacters: Set<Character> = []) -> FTS3TokenizerDescriptor {
        var arguments: [String] = []
        if !removeDiacritics {
            arguments.append("remove_diacritics=0")
        }
        if !separators.isEmpty {
            // TODO: test "=" and "\"", "(" and ")" as separators, with both FTS3Pattern(matchingAnyTokenIn:tokenizer:) and Database.create(virtualTable:using:)
            arguments.append("separators=" + separators.sorted().map { String($0) }.joined(separator: ""))
        }
        if !tokenCharacters.isEmpty {
            // TODO: test "=" and "\"", "(" and ")" as tokenCharacters, with both FTS3Pattern(matchingAnyTokenIn:tokenizer:) and Database.create(virtualTable:using:)
            arguments.append("tokenchars=" + tokenCharacters.sorted().map { String($0) }.joined(separator: ""))
        }
        return FTS3TokenizerDescriptor("unicode61", arguments: arguments)
    }
    
    /// Returns an array of tokens found in the string argument.
    ///
    ///     FTS3TokenizerDescriptor.simple.tokenize("foo bar") // ["foo", "bar"]
    func tokenize(_ string: String) -> [String] {
        return DatabaseQueue().inDatabase { db in
            var tokenizerChunks: [String] = []
            tokenizerChunks.append(name)
            for option in arguments {
                tokenizerChunks.append("\"\(option)\"")
            }
            let tokenizerSQL = tokenizerChunks.joined(separator: ", ")
            try! db.execute("CREATE VIRTUAL TABLE tokens USING fts3tokenize(\(tokenizerSQL))")
            return String.fetchAll(db, "SELECT token FROM tokens WHERE input = ? ORDER BY position", arguments: [string])
        }
    }
}

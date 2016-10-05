public struct FTS3Tokenizer {
    let name: String
    let options: [String]
    
    /// Creates an FTS3 tokenizer
    public init(_ name: String, options: [String] = []) {
        self.name = name
        self.options = options
    }
    
    /// The "simple" tokenizer
    ///
    /// See https://www.sqlite.org/fts3.html#tokenizer
    public static let simple = FTS3Tokenizer("simple")
    
    /// The "porter" tokenizer
    ///
    /// See https://www.sqlite.org/fts3.html#tokenizer
    public static let porter = FTS3Tokenizer("porter")
    
    /// An "unicode61" tokenizer
    ///
    ///     FTS3Tokenizer.unicode61()
    ///
    /// See https://www.sqlite.org/fts3.html#tokenizer
    public static func unicode61(removeDiacritics: Bool = true, separators: Set<Character>? = nil, tokenCharacters: Set<Character>? = nil) -> FTS3Tokenizer {
        var options: [String] = []
        if !removeDiacritics {
            options.append("remove_diacritics=0")
        }
        if let separators = separators {
            // TODO: test "=" and "\"", "(" and ")" as separators, with both FTS3Pattern(matchingAnyTokenIn:tokenizer:) and Database.create(virtualTable:using:)
            options.append("separators=" + separators.map { String($0) }.joined(separator: ""))
        }
        if let tokenCharacters = tokenCharacters {
            // TODO: test "=" and "\"", "(" and ")" as tokenCharacters, with both FTS3Pattern(matchingAnyTokenIn:tokenizer:) and Database.create(virtualTable:using:)
            options.append("tokenchars=" + tokenCharacters.map { String($0) }.joined(separator: ""))
        }
        return FTS3Tokenizer("unicode61", options: options)
    }
    
    /// Returns an array of tokens found in the string argument.
    ///
    ///     FTS3Tokenizer.simple.tokenize("foo bar") // ["foo", "bar"]
    func tokenize(_ string: String) -> [String] {
        return DatabaseQueue().inDatabase { db in
            var tokenizerChunks: [String] = []
            tokenizerChunks.append(name)
            for option in options {
                tokenizerChunks.append("\"\(option)\"")
            }
            let tokenizerSQL = tokenizerChunks.joined(separator: ", ")
            try! db.execute("CREATE VIRTUAL TABLE tokens USING fts3tokenize(\(tokenizerSQL))")
            return String.fetchAll(db, "SELECT token FROM tokens WHERE input = ? ORDER BY position", arguments: [string])
        }
    }
}

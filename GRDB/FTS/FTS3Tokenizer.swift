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
            // TODO: test "=" and "\"" as separators
            options.append("separators=" + separators.map { String($0) }.joined(separator: ""))
        }
        if let tokenCharacters = tokenCharacters {
            // TODO: test "=" and "\"" as tokenCharacters
            options.append("tokenchars=" + tokenCharacters.map { String($0) }.joined(separator: ""))
        }
        return FTS3Tokenizer("unicode61", options: options)
    }
}

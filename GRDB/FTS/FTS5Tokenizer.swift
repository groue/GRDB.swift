/// See https://www.sqlite.org/fts5.html#tokenizers
public struct FTS5Tokenizer {
    let components: [String]
    
    private init(components: [String]) {
        assert(!components.isEmpty)
        self.components = components
    }
    
    /// Creates an FTS5 tokenizer
    public init(_ name: String, options: [String] = []) {
        self.init(components: [name] + options)
    }
    
    /// The "ascii" tokenizer
    ///
    /// See https://www.sqlite.org/fts5.html#ascii_tokenizer
    public static func ascii(separators: Set<Character>? = nil) -> FTS5Tokenizer {
        if let separators = separators {
            return FTS5Tokenizer("ascii", options: ["separators", separators.map { String($0) }.joined(separator: "").sqlExpression.sql])
        } else {
            return FTS5Tokenizer("ascii")
        }
    }
    
    /// The "porter" tokenizer
    ///
    /// See https://www.sqlite.org/fts5.html#porter_tokenizer
    public static func porter(wrapping base: FTS5Tokenizer? = nil) -> FTS5Tokenizer {
        if let base = base {
            return FTS5Tokenizer("porter", options: base.components)
        } else {
            return FTS5Tokenizer("porter")
        }
    }
    
    /// An "unicode61" tokenizer
    ///
    ///     FTS5Tokenizer.unicode61()
    ///
    /// See https://www.sqlite.org/fts5.html#unicode61_tokenizer
    public static func unicode61(removeDiacritics: Bool = true, separators: Set<Character>? = nil, tokenCharacters: Set<Character>? = nil) -> FTS5Tokenizer {
        var options: [String] = []
        if !removeDiacritics {
            options.append(contentsOf: ["remove_diacritics", "0"])
        }
        if let separators = separators, !separators.isEmpty {
            // TODO: test "=" and "\"", "(" and ")" as separators, with both FTS3Pattern(matchingAnyTokenIn:tokenizer:) and Database.create(virtualTable:using:)
            options.append(contentsOf: ["separators", separators.sorted().map { String($0) }.joined(separator: "").sqlExpression.sql])
        }
        if let tokenCharacters = tokenCharacters, !tokenCharacters.isEmpty {
            // TODO: test "=" and "\"", "(" and ")" as tokenCharacters, with both FTS3Pattern(matchingAnyTokenIn:tokenizer:) and Database.create(virtualTable:using:)
            options.append(contentsOf: ["tokenchars", tokenCharacters.sorted().map { String($0) }.joined(separator: "").sqlExpression.sql])
        }
        return FTS5Tokenizer("unicode61", options: options)
    }
}

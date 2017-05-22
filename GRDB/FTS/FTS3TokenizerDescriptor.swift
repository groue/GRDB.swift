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
    
    #if GRDBCUSTOMSQLITE || GRDBCIPHER
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
        return _unicode61(removeDiacritics: removeDiacritics, separators: separators, tokenCharacters: tokenCharacters)
    }
    #else
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
    @available(iOS 8.2, OSX 10.10, *)
    public static func unicode61(removeDiacritics: Bool = true, separators: Set<Character> = [], tokenCharacters: Set<Character> = []) -> FTS3TokenizerDescriptor {
        // query_only pragma was added in SQLite 3.8.0 http://www.sqlite.org/changes.html#version_3_8_0
        // It is available from iOS 8.2 and OS X 10.10 https://github.com/yapstudios/YapDatabase/wiki/SQLite-version-(bundled-with-OS)
        return _unicode61(removeDiacritics: removeDiacritics, separators: separators, tokenCharacters: tokenCharacters)
    }
    #endif
    
    private static func _unicode61(removeDiacritics: Bool = true, separators: Set<Character> = [], tokenCharacters: Set<Character> = []) -> FTS3TokenizerDescriptor {
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
    
    #if GRDBCUSTOMSQLITE || GRDBCIPHER
    func tokenize(_ string: String) -> [String] {
        return _tokenize(string)
    }
    #else
    @available(iOS 8.2, OSX 10.10, *)
    func tokenize(_ string: String) -> [String] {
        return _tokenize(string)
    }
    #endif

    /// Returns an array of tokens found in the string argument.
    ///
    ///     FTS3TokenizerDescriptor.simple.tokenize("foo bar") // ["foo", "bar"]
    private func _tokenize(_ string: String) -> [String] {
        // fts3tokenize was introduced in SQLite 3.7.17 https://www.sqlite.org/changes.html#version_3_7_17
        // It is available from iOS 8.2 and OS X 10.10 https://github.com/yapstudios/YapDatabase/wiki/SQLite-version-(bundled-with-OS)
        return DatabaseQueue().inDatabase { db in
            var tokenizerChunks: [String] = []
            tokenizerChunks.append(name)
            for option in arguments {
                tokenizerChunks.append("\"\(option)\"")
            }
            let tokenizerSQL = tokenizerChunks.joined(separator: ", ")
            // Assume fts3tokenize virtual table in an in-memory database always succeeds
            try! db.execute("CREATE VIRTUAL TABLE tokens USING fts3tokenize(\(tokenizerSQL))")
            return try! String.fetchAll(db, "SELECT token FROM tokens WHERE input = ? ORDER BY position", arguments: [string])
        }
    }
}

#if SQLITE_ENABLE_FTS5
    /// An FTS5 tokenizer, suitable for FTS5 table definitions:
    ///
    ///     db.create(virtualTable: "books", using: FTS5()) { t in
    ///         t.tokenizer = FTS5Tokenizer.unicode61()
    ///     }
    ///
    /// See https://www.sqlite.org/fts5.html#tokenizers
    public struct FTS5Tokenizer {
        let components: [String]
        
        private init(components: [String]) {
            assert(!components.isEmpty)
            self.components = components
        }
        
        /// Creates an FTS5 tokenizer.
        ///
        /// Unless you use a custom tokenizer, you don't need this constructor:
        ///
        /// Use FTS5Tokenizer.ascii(), FTS5Tokenizer.porter(), or
        /// FTS5Tokenizer.unicode61() instead.
        public init(_ name: String, options: [String] = []) {
            self.init(components: [name] + options)
        }
        
        /// The "ascii" tokenizer
        ///
        ///     db.create(virtualTable: "books", using: FTS5()) { t in
        ///         t.tokenizer = .ascii()
        ///     }
        ///
        /// - parameters:
        ///     - separators: Unless empty (the default), SQLite will consider
        ///       these characters as token separators.
        ///
        /// See https://www.sqlite.org/fts5.html#ascii_tokenizer
        public static func ascii(separators: Set<Character> = []) -> FTS5Tokenizer {
            if separators.isEmpty {
                return FTS5Tokenizer("ascii")
            } else {
                return FTS5Tokenizer("ascii", options: ["separators", separators.map { String($0) }.joined(separator: "").sqlExpression.sql])
            }
        }
        
        /// The "porter" tokenizer
        ///
        ///     db.create(virtualTable: "books", using: FTS5()) { t in
        ///         t.tokenizer = .porter()
        ///     }
        ///
        /// - parameters:
        ///     - base: An eventual wrapping tokenizer which replaces the
        //        default unicode61() base tokenizer.
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
        ///     db.create(virtualTable: "books", using: FTS5()) { t in
        ///         t.tokenizer = .unicode61()
        ///     }
        ///
        /// - parameters:
        ///     - removeDiacritics: If true (the default), then SQLite will
        ///       strip diacritics from latin characters.
        ///     - separators: Unless empty (the default), SQLite will consider
        ///       these characters as token separators.
        ///     - tokenCharacters: Unless empty (the default), SQLite will
        ///       consider these characters as token characters.
        ///
        /// See https://www.sqlite.org/fts5.html#unicode61_tokenizer
        public static func unicode61(removeDiacritics: Bool = true, separators: Set<Character> = [], tokenCharacters: Set<Character> = []) -> FTS5Tokenizer {
            var options: [String] = []
            if !removeDiacritics {
                options.append(contentsOf: ["remove_diacritics", "0"])
            }
            if !separators.isEmpty {
                // TODO: test "=" and "\"", "(" and ")" as separators, with both FTS3Pattern(matchingAnyTokenIn:tokenizer:) and Database.create(virtualTable:using:)
                options.append(contentsOf: ["separators", separators.sorted().map { String($0) }.joined(separator: "").sqlExpression.sql])
            }
            if !tokenCharacters.isEmpty {
                // TODO: test "=" and "\"", "(" and ")" as tokenCharacters, with both FTS3Pattern(matchingAnyTokenIn:tokenizer:) and Database.create(virtualTable:using:)
                options.append(contentsOf: ["tokenchars", tokenCharacters.sorted().map { String($0) }.joined(separator: "").sqlExpression.sql])
            }
            return FTS5Tokenizer("unicode61", options: options)
        }
    }
#endif

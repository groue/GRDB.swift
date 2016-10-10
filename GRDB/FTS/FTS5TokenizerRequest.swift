#if SQLITE_ENABLE_FTS5
    /// An FTS5 tokenizer, suitable for FTS5 table definitions:
    ///
    ///     db.create(virtualTable: "books", using: FTS5()) { t in
    ///         t.tokenizer = FTS5Tokenizer.unicode61()
    ///     }
    ///
    /// See https://www.sqlite.org/fts5.html#tokenizers
    public struct FTS5TokenizerRequest {
        /// The tokenizer components
        ///
        ///     // ["unicode61"]
        ///     FTS5TokenizerRequest.unicode61().components
        ///
        ///     // ["unicode61", "remove_diacritics", "0"]
        ///     FTS5TokenizerRequest.unicode61(removeDiacritics: false)).components
        public let components: [String]
        
        /// The tokenizer name
        ///
        ///     // "unicode61"
        ///     FTS5TokenizerRequest.unicode61().name
        ///
        ///     // "unicode61"
        ///     FTS5TokenizerRequest.unicode61(removeDiacritics: false)).name
        var name: String {
            return components[0]
        }
        
        var arguments: [String] {
            return Array(components.suffix(from: 1))
        }
        
        /// Creates an FTS5 tokenizer definition.
        ///
        ///     db.create(virtualTable: "books", using: FTS5()) { t in
        ///         let tokenizer = FTS5TokenizerRequest(components: ["porter", "unicode61", "remove_diacritics", "0"])
        ///         t.tokenizer = tokenizer
        ///     }
        ///
        /// - precondition: Components is not empty
        public init(components: [String]) {
            GRDBPrecondition(!components.isEmpty, "FTS5TokenizerRequest requires at least one component")
            assert(!components.isEmpty)
            self.components = components
        }
        
        /// Creates an FTS5 tokenizer definition.
        ///
        ///     db.create(virtualTable: "books", using: FTS5()) { t in
        ///         let tokenizer = FTS5TokenizerRequest(name: "porter", arguments: ["unicode61", "remove_diacritics", "0"])
        ///         t.tokenizer = tokenizer
        ///     }
        ///
        public init(name: String, arguments: [String] = []) {
            self.init(components: [name] + arguments)
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
        public static func ascii(separators: Set<Character> = []) -> FTS5TokenizerRequest {
            if separators.isEmpty {
                return FTS5TokenizerRequest(components: ["ascii"])
            } else {
                return FTS5TokenizerRequest(components: ["ascii", "separators", separators.map { String($0) }.joined(separator: "").sqlExpression.sql])
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
        public static func porter(wrapping base: FTS5TokenizerRequest? = nil) -> FTS5TokenizerRequest {
            if let base = base {
                return FTS5TokenizerRequest(components: ["porter"] + base.components)
            } else {
                return FTS5TokenizerRequest(components: ["porter"])
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
        public static func unicode61(removeDiacritics: Bool = true, separators: Set<Character> = [], tokenCharacters: Set<Character> = []) -> FTS5TokenizerRequest {
            var components: [String] = ["unicode61"]
            if !removeDiacritics {
                components.append(contentsOf: ["remove_diacritics", "0"])
            }
            if !separators.isEmpty {
                // TODO: test "=" and "\"", "(" and ")" as separators, with both FTS3Pattern(matchingAnyTokenIn:tokenizer:) and Database.create(virtualTable:using:)
                components.append(contentsOf: ["separators", separators.sorted().map { String($0) }.joined(separator: "").sqlExpression.sql])
            }
            if !tokenCharacters.isEmpty {
                // TODO: test "=" and "\"", "(" and ")" as tokenCharacters, with both FTS3Pattern(matchingAnyTokenIn:tokenizer:) and Database.create(virtualTable:using:)
                components.append(contentsOf: ["tokenchars", tokenCharacters.sorted().map { String($0) }.joined(separator: "").sqlExpression.sql])
            }
            return FTS5TokenizerRequest(components: components)
        }
    }
#endif

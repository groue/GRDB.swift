#if SQLITE_ENABLE_FTS5
/// The descriptor for an ``FTS5`` tokenizer.
///
/// For example:
///
/// ```swift
/// try db.create(virtualTable: "book", using: FTS5()) { t in
///     t.tokenizer = .unicode61() // FTS5TokenizerDescriptor
/// }
/// ```
///
/// Related SQLite documentation: <https://www.sqlite.org/fts5.html#tokenizers>
///
/// ## Topics
///
/// ### Creating Tokenizer Descriptors
///
/// - ``init(components:)``
/// - ``ascii(separators:tokenCharacters:)``
/// - ``porter(wrapping:)``
/// - ``unicode61(diacritics:categories:separators:tokenCharacters:)``
/// - ``FTS5/Diacritics``
///
/// ### Instantiating Tokenizers
///
/// - ``Database/makeTokenizer(_:)``
public struct FTS5TokenizerDescriptor: Sendable {
    /// The tokenizer components.
    ///
    /// For example:
    ///
    /// ```swift
    /// // ["unicode61"]
    /// FTS5TokenizerDescriptor.unicode61().components
    ///
    /// // ["unicode61", "remove_diacritics", "0"]
    /// FTS5TokenizerDescriptor.unicode61(removeDiacritics: false)).components
    /// ```
    public let components: [String]
    
    /// The tokenizer name.
    ///
    /// For example:
    ///
    /// ```swift
    /// // "unicode61"
    /// FTS5TokenizerDescriptor.unicode61().name
    ///
    /// // "unicode61"
    /// FTS5TokenizerDescriptor.unicode61(removeDiacritics: false)).name
    /// ```
    var name: String { components[0] }
    
    /// The tokenizer arguments.
    ///
    /// For example:
    ///
    /// ```swift
    /// // []
    /// FTS5TokenizerDescriptor.unicode61().components
    ///
    /// // ["remove_diacritics", "0"]
    /// FTS5TokenizerDescriptor.unicode61(removeDiacritics: false)).components
    /// ```
    var arguments: [String] {
        Array(components.suffix(from: 1))
    }
    
    /// Creates an FTS5 tokenizer descriptor.
    ///
    /// For example:
    ///
    /// ```swift
    /// try db.create(virtualTable: "book", using: FTS5()) { t in
    ///     t.tokenizer = FTS5TokenizerDescriptor(components: [
    ///         "porter",
    ///         "unicode61",
    ///         "remove_diacritics",
    ///         "0"])
    /// }
    /// ```
    ///
    /// - precondition: Components is not empty.
    public init(components: [String]) {
        GRDBPrecondition(!components.isEmpty, "FTS5TokenizerDescriptor requires at least one component")
        assert(!components.isEmpty)
        self.components = components
    }
    
    /// The "ascii" tokenizer.
    ///
    /// For example:
    ///
    /// ```swift
    /// try db.create(virtualTable: "book", using: FTS5()) { t in
    ///     t.tokenizer = .ascii()
    /// }
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/fts5.html#ascii_tokenizer>
    ///
    /// - parameters:
    ///     - separators: Unless empty (the default), SQLite will consider
    ///       these characters as token separators.
    ///     - tokenCharacters: Unless empty (the default), SQLite will
    ///       consider these characters as token characters.
    public static func ascii(
        separators: Set<Character> = [],
        tokenCharacters: Set<Character> = [])
    -> FTS5TokenizerDescriptor {
        var components: [String] = ["ascii"]
        if !separators.isEmpty {
            // TODO: test "=" and "\"", "(" and ")" as separators, with
            // both FTS3Pattern(matchingAnyTokenIn:tokenizer:)
            // and Database.create(virtualTable:using:)
            components.append("separators")
            components.append(separators.sorted().map { String($0) }.joined())
        }
        if !tokenCharacters.isEmpty {
            // TODO: test "=" and "\"", "(" and ")" as tokenCharacters, with
            // both FTS3Pattern(matchingAnyTokenIn:tokenizer:)
            // and Database.create(virtualTable:using:)
            components.append("tokenchars")
            components.append(tokenCharacters.sorted().map { String($0) }.joined())
        }
        return FTS5TokenizerDescriptor(components: components)
    }
    
    /// The "porter" tokenizer.
    ///
    /// For example:
    ///
    /// ```swift
    /// try db.create(virtualTable: "book", using: FTS5()) { t in
    ///     t.tokenizer = .porter()
    /// }
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/fts5.html#porter_tokenizer>
    ///
    /// - parameter base: An eventual wrapping tokenizer which replaces the
    ///   default unicode61() base tokenizer.
    public static func porter(wrapping base: FTS5TokenizerDescriptor? = nil) -> FTS5TokenizerDescriptor {
        if let base {
            return FTS5TokenizerDescriptor(components: ["porter"] + base.components)
        } else {
            return FTS5TokenizerDescriptor(components: ["porter"])
        }
    }
    
    /// The "unicode61" tokenizer.
    ///
    /// For example:
    ///
    /// ```swift
    /// try db.create(virtualTable: "book", using: FTS5()) { t in
    ///     t.tokenizer = .unicode61()
    /// }
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/fts5.html#unicode61_tokenizer>
    ///
    /// - parameters:
    ///     - diacritics: By default SQLite will strip diacritics from
    ///       latin characters.
    ///     - categories: Unless empty (the default), SQLite will consider
    ///       "L* N* Co" Unicode categories for tokens.
    ///     - separators: Unless empty (the default), SQLite will consider
    ///       these characters as token separators.
    ///     - tokenCharacters: Unless empty (the default), SQLite will
    ///       consider these characters as token characters.
    public static func unicode61(
        diacritics: FTS5.Diacritics = .removeLegacy,
        categories: String = "",
        separators: Set<Character> = [],
        tokenCharacters: Set<Character> = [])
    -> FTS5TokenizerDescriptor
    {
        var components: [String] = ["unicode61"]
        switch diacritics {
        case .removeLegacy:
            break
        case .keep:
            components.append(contentsOf: ["remove_diacritics", "0"])
        #if GRDBCUSTOMSQLITE
        case .remove:
            components.append(contentsOf: ["remove_diacritics", "2"])
        #elseif !GRDBCIPHER
        case .remove:
            components.append(contentsOf: ["remove_diacritics", "2"])
        #endif
        }
        if !categories.isEmpty {
            components.append("categories")
            components.append(categories)
        }
        if !separators.isEmpty {
            // TODO: test "=" and "\"", "(" and ")" as separators, with
            // both FTS3Pattern(matchingAnyTokenIn:tokenizer:)
            // and Database.create(virtualTable:using:)
            components.append("separators")
            components.append(separators.sorted().map { String($0) }.joined())
        }
        if !tokenCharacters.isEmpty {
            // TODO: test "=" and "\"", "(" and ")" as tokenCharacters, with
            // both FTS3Pattern(matchingAnyTokenIn:tokenizer:)
            // and Database.create(virtualTable:using:)
            components.append("tokenchars")
            components.append(tokenCharacters.sorted().map { String($0) }.joined())
        }
        return FTS5TokenizerDescriptor(components: components)
    }
    
    #if GRDBCUSTOMSQLITE || GRDBCIPHER
    /// The "trigram" tokenizer.
    ///
    /// For example:
    ///
    /// ```swift
    /// try db.create(virtualTable: "book", using: FTS5()) { t in
    ///     t.tokenizer = .trigram()
    /// }
    /// ```
    ///
    /// Related SQLite documentation: <https://sqlite.org/fts5.html#the_trigram_tokenizer>
    ///
    /// - parameters:
    ///     - caseSensitive: By default SQLite will perform case insensitive
    ///     matching.
    ///     - removeDiacritics: By default SQLite will not remove diacritics
    ///     before matching.
    public static func trigram(
        caseSensitive: FTS5.TrigramCaseSensitiveOption? = nil,
        removeDiacritics: FTS5.TrigramDiacriticsOption? = nil
    ) -> FTS5TokenizerDescriptor {
        var components = ["trigram"]
        if let caseSensitive {
            components.append(contentsOf: [
                "case_sensitive", String(caseSensitive.rawValue)
            ])
        }
        if let removeDiacritics {
            components.append(contentsOf: [
                "remove_diacritics", String(removeDiacritics.rawValue)
            ])
        }
        return FTS5TokenizerDescriptor(components: components)
    }
    #else
    /// The "trigram" tokenizer.
    ///
    /// For example:
    ///
    /// ```swift
    /// try db.create(virtualTable: "book", using: FTS5()) { t in
    ///     t.tokenizer = .trigram()
    /// }
    /// ```
    ///
    /// Related SQLite documentation: <https://sqlite.org/fts5.html#the_trigram_tokenizer>
    ///
    /// - parameters:
    ///     - caseSensitive: By default SQLite will perform case insensitive
    ///     matching.
    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) // SQLite 3.35.0+ (3.34 actually)
    public static func trigram(
        caseSensitive: FTS5.TrigramCaseSensitiveOption? = nil
    ) -> FTS5TokenizerDescriptor {
        var components = ["trigram"]
        if let caseSensitive {
            components.append(contentsOf: [
                "case_sensitive", String(caseSensitive.rawValue)
            ])
        }
        return FTS5TokenizerDescriptor(components: components)
    }
    
    /// The "trigram" tokenizer.
    ///
    /// For example:
    ///
    /// ```swift
    /// try db.create(virtualTable: "book", using: FTS5()) { t in
    ///     t.tokenizer = .trigram()
    /// }
    /// ```
    ///
    /// Related SQLite documentation: <https://sqlite.org/fts5.html#the_trigram_tokenizer>
    ///
    /// - parameters:
    ///     - caseSensitive: By default SQLite will perform case insensitive
    ///     matching.
    ///     - removeDiacritics: By default SQLite will not remove diacritics
    ///     before matching.
    @available(*, unavailable, message: "Requires a future OS release that includes SQLite >=3.45")
    public static func trigram(
        caseSensitive: FTS5.TrigramCaseSensitiveOption? = nil,
        removeDiacritics: FTS5.TrigramDiacriticsOption? = nil
    ) -> FTS5TokenizerDescriptor {
        var components = ["trigram"]
        if let caseSensitive {
            components.append(contentsOf: [
                "case_sensitive", String(caseSensitive.rawValue)
            ])
        }
        if let removeDiacritics {
            components.append(contentsOf: [
                "remove_diacritics", String(removeDiacritics.rawValue)
            ])
        }
        return FTS5TokenizerDescriptor(components: components)
    }
    #endif
}
#endif

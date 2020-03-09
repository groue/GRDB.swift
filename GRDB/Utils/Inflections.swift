import Foundation

extension String {
    /// "player" -> "Player"
    var uppercasingFirstCharacter: String {
        guard let first = first else {
            return self
        }
        return String(first).uppercased() + dropFirst()
    }
    
    /// "player" -> "players"
    /// "players" -> "players"
    var pluralized: String {
        Inflections.default.pluralize(self)
    }
    
    /// "player" -> "player"
    /// "players" -> "player"
    var singularized: String {
        Inflections.default.singularize(self)
    }
    
    /// "bar" -> "bar"
    /// "foo12" -> "foo"
    var digitlessRadical: String {
        String(prefix(upTo: Inflections.endIndexOfDigitlessRadical(self)))
    }
}

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// A type that controls GRDB string inflections.
public struct Inflections {
    private var pluralizeRules: [(NSRegularExpression, String)] = []
    private var singularizeRules: [(NSRegularExpression, String)] = []
    private var uncountablesRegularExpressions: [String: NSRegularExpression] = [:]
    
    // For testability
    var uncountables: Set<String> {
        Set(uncountablesRegularExpressions.keys)
    }
    
    // MARK: - Initialization
    
    public init() {
    }
    
    // MARK: - Configuration
    
    /// Appends a pluralization rule.
    ///
    ///     var inflections = Inflections()
    ///     inflections.plural("$", "s")
    ///     inflections.pluralize("player") // "players"
    ///
    /// - parameters:
    ///     - pattern: A regular expression pattern.
    ///     - options: Regular expression options (defaults to
    ///       `[.caseInsensitive]`).
    ///     - template: A replacement template string.
    public mutating func plural(
        _ pattern: String,
        options: NSRegularExpression.Options = [.caseInsensitive],
        _ template: String)
    {
        let reg = try! NSRegularExpression(pattern: pattern, options: options)
        pluralizeRules.append((reg, template))
    }
    
    /// Appends a singularization rule.
    ///
    ///     var inflections = Inflections()
    ///     inflections.singular("s$", "")
    ///     inflections.singularize("players") // "player"
    ///
    /// - parameters:
    ///     - pattern: A regular expression pattern.
    ///     - options: Regular expression options (defaults to
    ///       `[.caseInsensitive]`).
    ///     - template: A replacement template string.
    public mutating func singular(
        _ pattern: String,
        options: NSRegularExpression.Options = [.caseInsensitive],
        _ template: String)
    {
        let reg = try! NSRegularExpression(pattern: pattern, options: options)
        singularizeRules.append((reg, template))
    }
    
    /// Appends uncountable words.
    ///
    ///     var inflections = Inflections()
    ///     inflections.plural("$", "s")
    ///     inflections.uncountableWords(["foo"])
    ///     inflections.pluralize("foo") // "foo"
    ///     inflections.pluralize("bar") // "bars"
    public mutating func uncountableWords(_ words: [String]) {
        for word in words {
            uncountableWord(word)
        }
    }
    
    /// Appends an irregular singular/plural pair.
    ///
    ///     var inflections = Inflections()
    ///     inflections.plural("$", "s")
    ///     inflections.irregularSuffix("man", "men")
    ///     inflections.pluralize("man")      // "men"
    ///     inflections.singularizes("women") // "woman"
    ///
    /// - parameters:
    ///     - singular: The singular form.
    ///     - plural: The plural form.
    public mutating func irregularSuffix(_ singular: String, _ plural: String) {
        let s0 = singular.first!
        let srest = singular.dropFirst()
        
        let p0 = plural.first!
        let prest = plural.dropFirst()
        
        if s0.uppercased() == p0.uppercased() {
            self.plural("(\(s0))\(srest)$", options: [.caseInsensitive], "$1\(prest)")
            self.plural("(\(p0))\(prest)$", options: [.caseInsensitive], "$1\(prest)")
            
            self.singular("(\(s0))\(srest)$", options: [.caseInsensitive], "$1\(srest)")
            self.singular("(\(p0))\(prest)$", options: [.caseInsensitive], "$1\(srest)")
        } else {
            self.plural("\(s0.uppercased())(?i)\(srest)$", options: [], p0.uppercased() + prest)
            self.plural("\(s0.lowercased())(?i)\(srest)$", options: [], p0.lowercased() + prest)
            self.plural("\(p0.uppercased())(?i)\(prest)$", options: [], p0.uppercased() + prest)
            self.plural("\(p0.lowercased())(?i)\(prest)$", options: [], p0.lowercased() + prest)
            
            self.singular("\(s0.uppercased())(?i)\(srest)$", options: [], s0.uppercased() + srest)
            self.singular("\(s0.lowercased())(?i)\(srest)$", options: [], s0.lowercased() + srest)
            self.singular("\(p0.uppercased())(?i)\(prest)$", options: [], s0.uppercased() + srest)
            self.singular("\(p0.lowercased())(?i)\(prest)$", options: [], s0.lowercased() + srest)
        }
    }
    
    // MARK: - Inflections
    
    /// Returns a pluralized string.
    ///
    ///     Inflections.default.pluralize("player") // "players"
    public func pluralize(_ string: String) -> String {
        inflectString(string, with: pluralizeRules)
    }
    
    /// Returns a singularized string.
    public func singularize(_ string: String) -> String {
        inflectString(string, with: singularizeRules)
    }
    
    // MARK: - Utils
    
    /// Appends an uncountable word.
    ///
    ///     var inflections = Inflections()
    ///     inflections.plural("$", "s")
    ///     inflections.uncountableWord("foo")
    ///     inflections.pluralize("foo") // "foo"
    ///     inflections.pluralize("bar") // "bars"
    private mutating func uncountableWord(_ word: String) {
        let escWord = NSRegularExpression.escapedPattern(for: word)
        uncountablesRegularExpressions[word] = try! NSRegularExpression(
            pattern: "\\b\(escWord)\\Z",
            options: [.caseInsensitive])
    }
    
    private func isUncountable(_ string: String) -> Bool {
        let range = NSRange(location: 0, length: string.utf16.count)
        for (_, reg) in uncountablesRegularExpressions {
            if reg.firstMatch(in: string, options: [], range: range) != nil {
                return true
            }
        }
        return false
    }
    
    private func inflectString(_ string: String, with rules: [(NSRegularExpression, String)]) -> String {
        let indexOfLastWord = Inflections.startIndexOfLastWord(string)
        let endIndexOfDigitlessRadical = Inflections.endIndexOfDigitlessRadical(string)
        let lastWord = String(string[indexOfLastWord..<endIndexOfDigitlessRadical])
        if isUncountable(lastWord) {
            return string
        }
        return """
            \(string.prefix(upTo: indexOfLastWord))\
            \(inflectWord(lastWord, with: rules))\
            \(string.suffix(from: endIndexOfDigitlessRadical))
            """
    }
    
    private func inflectWord(_ string: String, with rules: [(NSRegularExpression, String)]) -> String {
        if string.isEmpty {
            return string
        }
        let range = NSRange(string.startIndex..<string.endIndex, in: string)
        for (reg, template) in rules.reversed() {
            let result = NSMutableString(string: string)
            let matchCount = reg.replaceMatches(in: result, options: [], range: range, withTemplate: template)
            if matchCount > 0 {
                return String(result)
            }
        }
        return string
    }
    
    /// startIndexOfLastWord("foo")     -> "foo"
    /// startIndexOfLastWord("foo bar") -> "bar"
    /// startIndexOfLastWord("foo_bar") -> "bar"
    /// startIndexOfLastWord("fooBar")  -> "Bar"
    static func startIndexOfLastWord(_ string: String) -> String.Index {
        let range = NSRange(string.startIndex..<string.endIndex, in: string)
        
        let index1: String.Index? = wordBoundaryReg.firstMatch(in: string, options: [], range: range).flatMap {
            if $0.range.location == NSNotFound { return nil }
            return Range($0.range, in: string)?.lowerBound
        }
        let index2: String.Index? = underscoreBoundaryReg.firstMatch(in: string, options: [], range: range).flatMap {
            if $0.range.location == NSNotFound { return nil }
            return Range($0.range, in: string).map { string.index(after: $0.lowerBound) }
        }
        let index3: String.Index? = caseBoundaryReg.firstMatch(in: string, options: [], range: range).flatMap {
            if $0.range.location == NSNotFound { return nil }
            return Range($0.range, in: string).map { string.index(after: $0.lowerBound) }
        }
        
        return [index1, index2, index3].compactMap { $0 }.max() ?? string.startIndex
    }
    
    /// "bar" -> "bar"
    /// "foo12" -> "foo"
    static func endIndexOfDigitlessRadical(_ string: String) -> String.Index {
        let digits: ClosedRange<Character> = "0"..."9"
        return string                               // "foo12"
            .reversed()                             // "21oof"
            .prefix(while: { digits.contains($0) }) // "21"
            .endIndex                               // reversed(foo^12)
            .base                                   // foo^12
    }
    
    private static let wordBoundaryReg = try! NSRegularExpression(pattern: "\\b\\w+$", options: [])
    private static let underscoreBoundaryReg = try! NSRegularExpression(pattern: "_[^_]+$", options: [])
    private static let caseBoundaryReg = try! NSRegularExpression(pattern: "[^A-Z][A-Z]+[a-z1-9]+$", options: [])
}

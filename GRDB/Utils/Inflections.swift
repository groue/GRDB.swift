// Copyright (C) 2019 Gwendal Roué
//
// Permission is hereby granted, free of charge, to any person obtaining a
// copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to
// the following conditions:
//
// The above copyright notice and this permission notice shall be included
// in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
// OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
// IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
// CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
// TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
// SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
// =============================================================================
//
// Copyright (c) 2005-2019 David Heinemeier Hansson
//
// Permission is hereby granted, free of charge, to any person obtaining
// a copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to
// the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
// LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
// OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
// WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import Foundation

extension String {
    var uppercasingFirstCharacter: String {
        guard let first = first else {
            return self
        }
        return String(first).uppercased() + dropFirst()
    }
    
    var pluralized: String {
        return Inflections.default.pluralize(self)
    }
    
    var singularized: String {
        return Inflections.default.singularize(self)
    }
}

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
public struct Inflections {
    private var pluralizeRules: [(NSRegularExpression, String)] = []
    private var singularizeRules: [(NSRegularExpression, String)] = []
    private var uncountablesRegularExpressions: [String: NSRegularExpression] = [:]
    var uncountables: Set<String> {
        return Set(uncountablesRegularExpressions.keys)
    }
    
    public init() {
    }
    
    /// Appends a pluralization rule.
    ///
    ///     var inflections = Inflections()
    ///     inflections.plural("$", "s")
    ///     inflections.pluralize("foo") // "foos"
    ///     inflections.pluralize("bar") // "bars"
    public mutating func plural(_ pattern: String, options: NSRegularExpression.Options = [.caseInsensitive], _ template: String) {
        let reg = try! NSRegularExpression(pattern: pattern, options: options)
        pluralizeRules.append((reg, template))
    }
    
    /// Appends a singularization rule.
    ///
    ///     var inflections = Inflections()
    ///     inflections.singular("s$", "")
    ///     inflections.singularize("foos") // "foo"
    ///     inflections.singularize("bars") // "bar"
    public mutating func singular(_ pattern: String, options: NSRegularExpression.Options = [.caseInsensitive], _ template: String) {
        let reg = try! NSRegularExpression(pattern: pattern, options: options)
        singularizeRules.append((reg, template))
    }
    
    /// Appends uncountable words.
    ///
    ///     var inflections = Inflections()
    ///     inflections.plural("$", "s")
    ///     inflections.uncountable("foo")
    ///     inflections.pluralize("foo") // "foo"
    ///     inflections.pluralize("bar") // "bars"
    public mutating func uncountable(_ words: String...) {
        for word in words {
            let escWord = NSRegularExpression.escapedPattern(for: word)
            uncountablesRegularExpressions[word] = try! NSRegularExpression(pattern: "\\b\(escWord)\\Z", options: [.caseInsensitive])
        }
    }
    
    /// Appends an irregular singular/plural pair.
    ///
    ///     var inflections = Inflections()
    ///     inflections.plural("$", "s")
    ///     inflections.irregular("man", "men")
    ///     inflections.pluralize("man")      // "men"
    ///     inflections.singularizes("women") // "woman"
    public mutating func irregular(_ singular: String, _ plural: String) {
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
    
    /// Returns a pluralized string.
    public func pluralize(_ string: String) -> String {
        let indexOfLastWord = Inflections.indexOfLastWord(string)
        let lastWord = String(string.suffix(from: indexOfLastWord))
        if isUncountable(lastWord) {
            return string
        }
        return string.prefix(upTo: indexOfLastWord) + inflect(lastWord, with: pluralizeRules)
    }
    
    /// Returns a singularized string.
    public func singularize(_ string: String) -> String {
        let indexOfLastWord = Inflections.indexOfLastWord(string)
        let lastWord = String(string.suffix(from: indexOfLastWord))
        if isUncountable(lastWord) {
            return string
        }
        return string.prefix(upTo: indexOfLastWord) + inflect(lastWord, with: singularizeRules)
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
    
    private func inflect(_ string: String, with rules: [(NSRegularExpression, String)]) -> String {
        if string.isEmpty {
            return string
        }
        let range = NSRange(string.startIndex..<string.endIndex, in: string)
        for (reg, template) in rules.reversed() {
            let result = NSMutableString(string: string)
            let count = reg.replaceMatches(in: result, options: [], range: range, withTemplate: template)
            if count > 0 {
                return String(result)
            }
        }
        return string
    }
    
    /// indexOfLastWord("foo")     -> "foo"
    /// indexOfLastWord("foo bar") -> "bar"
    /// indexOfLastWord("foo_bar") -> "bar"
    /// indexOfLastWord("fooBar")  -> "Bar"
    static func indexOfLastWord(_ string: String) -> String.Index {
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
    
    private static let wordBoundaryReg = try! NSRegularExpression(pattern: "\\b\\w+$", options: [])
    private static let underscoreBoundaryReg = try! NSRegularExpression(pattern: "_[^_]+$", options: [])
    private static let caseBoundaryReg = try! NSRegularExpression(pattern: "[^A-Z][A-Z]+[a-z1-9]+$", options: [])
}

extension Inflections {
    /// The default inflections
    public static var `default`: Inflections = {
        // Defines the standard inflection rules. These are the starting point
        // for new projects and are not considered complete. The current set of
        // inflection rules is frozen. This means, we do not change them to
        // become more complete. This is a safety measure to keep existing
        // applications from breaking.
        //
        // https://github.com/rails/rails/blob/b2eb1d1c55a59fee1e6c4cba7030d8ceb524267c/activesupport/lib/active_support/inflections.rb
        
        var inflections = Inflections()
        
        inflections.plural("$", "s")
        inflections.plural("s$", "s")
        inflections.plural("^(ax|test)is$", "$1es")
        inflections.plural("(octop|vir)us$", "$1i")
        inflections.plural("(octop|vir)i$", "$1i")
        inflections.plural("(alias|status)$", "$1es")
        inflections.plural("(bu)s$", "$1ses")
        inflections.plural("(buffal|tomat)o$", "$1oes")
        inflections.plural("([ti])um$", "$1a")
        inflections.plural("([ti])a$", "$1a")
        inflections.plural("sis$", "ses")
        inflections.plural("(?:([^f])fe|([lr])f)$", "$1$2ves")
        inflections.plural("(hive)$", "$1s")
        inflections.plural("([^aeiouy]|qu)y$", "$1ies")
        inflections.plural("(x|ch|ss|sh)$", "$1es")
        inflections.plural("(matr|vert|ind)(?:ix|ex)$", "$1ices")
        inflections.plural("^(m|l)ouse$", "$1ice")
        inflections.plural("^(m|l)ice$", "$1ice")
        inflections.plural("^(ox)$", "$1en")
        inflections.plural("^(oxen)$", "$1")
        inflections.plural("(quiz)$", "$1zes")
        inflections.plural("(canva)s$", "$1ses")

        inflections.singular("s$", "")
        inflections.singular("(ss)$", "$1")
        inflections.singular("(n)ews$", "$1ews")
        inflections.singular("([ti])a$", "$1um")
        inflections.singular("((a)naly|(b)a|(d)iagno|(p)arenthe|(p)rogno|(s)ynop|(t)he)(sis|ses)$", "$1sis")
        inflections.singular("(^analy)(sis|ses)$", "$1sis")
        inflections.singular("([^f])ves$", "$1fe")
        inflections.singular("(hive)s$", "$1")
        inflections.singular("(tive)s$", "$1")
        inflections.singular("([lr])ves$", "$1f")
        inflections.singular("([^aeiouy]|qu)ies$", "$1y")
        inflections.singular("(s)eries$", "$1eries")
        inflections.singular("(m)ovies$", "$1ovie")
        inflections.singular("(x|ch|ss|sh)es$", "$1")
        inflections.singular("^(m|l)ice$", "$1ouse")
        inflections.singular("(bus)(es)?$", "$1")
        inflections.singular("(o)es$", "$1")
        inflections.singular("(shoe)s$", "$1")
        inflections.singular("(cris|test)(is|es)$", "$1is")
        inflections.singular("^(a)x[ie]s$", "$1xis")
        inflections.singular("(octop|vir)(us|i)$", "$1us")
        inflections.singular("(alias|status)(es)?$", "$1")
        inflections.singular("^(ox)en$", "$1")
        inflections.singular("(vert|ind)ices$", "$1ex")
        inflections.singular("(matr)ices$", "$1ix")
        inflections.singular("(quiz)zes$", "$1")
        inflections.singular("(database)s$", "$1")
        inflections.singular("(canvas)(es)?$", "$1")
        
        inflections.uncountable(
            "equipment",
            "information",
            "rice",
            "money",
            "species",
            "fish",
            "sheep",
            "jeans",
            "police")
        
        inflections.irregular("person", "people")
        inflections.irregular("man", "men")
        inflections.irregular("child", "children")
        inflections.irregular("sex", "sexes")
        inflections.irregular("move", "moves")
        inflections.irregular("zombie", "zombies")
        inflections.irregular("specimen", "specimens")
        
        return inflections
    }()
}

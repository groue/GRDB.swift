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

struct Inflections {
    private var pluralizeRules: [(NSRegularExpression, String)] = []
    private var singularizeRules: [(NSRegularExpression, String)] = []
    private var uncountablesRegularExpressions: [String: NSRegularExpression] = [:]
    var uncountables: Set<String> {
        return Set(uncountablesRegularExpressions.keys)
    }
    
    public init() {
    }
    
    public mutating func plural(_ pattern: String, options: NSRegularExpression.Options = [.caseInsensitive], _ template: String) {
        let reg = try! NSRegularExpression(pattern: pattern, options: options)
        pluralizeRules.append((reg, template))
    }
    
    public mutating func singular(_ pattern: String, options: NSRegularExpression.Options = [.caseInsensitive], _ template: String) {
        let reg = try! NSRegularExpression(pattern: pattern, options: options)
        singularizeRules.append((reg, template))
    }
    
    public mutating func uncountable(_ words: String...) {
        for word in words {
            let escWord = NSRegularExpression.escapedPattern(for: word)
            uncountablesRegularExpressions[word] = try! NSRegularExpression(pattern: "\\b\(escWord)\\Z", options: [.caseInsensitive])
        }
    }
    
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
    
    func isUncountable(_ string: String) -> Bool {
        let range = NSRange(location: 0, length: string.utf16.count)
        for (_, reg) in uncountablesRegularExpressions {
            if reg.firstMatch(in: string, options: [], range: range) != nil {
                return true
            }
        }
        return false
    }
    
    public func pluralize(_ string: String) -> String {
        if isUncountable(string) {
            return string
        }
        return inflect(string, with: pluralizeRules)
    }
    
    public func singularize(_ string: String) -> String {
        if isUncountable(string) {
            return string
        }
        return inflect(string, with: singularizeRules)
    }
    
    private func inflect(_ string: String, with rules: [(NSRegularExpression, String)]) -> String {
        if string.isEmpty {
            return string
        }
        let range = NSRange(location: 0, length: string.utf16.count)
        for (reg, template) in rules.reversed() {
            let result = NSMutableString(string: string)
            let count = reg.replaceMatches(in: result, options: [], range: range, withTemplate: template)
            if count > 0 {
                return String(result)
            }
        }
        return string
    }
}

extension Inflections {
    static var `default`: Inflections = {
        // Defines the standard inflection rules. These are the starting point
        // for new projects and are not considered complete. The current set of
        // inflection rules is frozen. This means, we do not change them to
        // become more complete. This is a safety measure to keep existing
        // applications from breaking.
        
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
        inflections.singular("^(ox)en", "$1")
        inflections.singular("(vert|ind)ices$", "$1ex")
        inflections.singular("(matr)ices$", "$1ix")
        inflections.singular("(quiz)zes$", "$1")
        inflections.singular("(database)s$", "$1")
        
        inflections.uncountable(
            "equipment",
            "information",
            "rice",
            "money",
            "species",
            "series",
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
        
        return inflections
    }()
}

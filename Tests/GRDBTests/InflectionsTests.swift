import XCTest
#if GRDBCUSTOMSQLITE
    @testable import GRDBCustomSQLite
#else
    @testable import GRDB
#endif

// https://github.com/rails/rails/blob/v6.0.0.rc1/activesupport/test/inflector_test.rb
class InflectionsTests: GRDBTestCase {
    private var originalInflections: Inflections?

    override func setUp() {
        // Dups the singleton before each test, restoring the original inflections later.
        originalInflections = Inflections.default
    }
    
    override func tearDown() {
        Inflections.default = originalInflections!
    }
    
    private var inflectionTestCases: InflectionTestCases {
        let url = Bundle(for: type(of: self)).url(forResource: "InflectionsTests", withExtension: "json")!
        let data = try! Data(contentsOf: url)
        return try! JSONDecoder().decode(InflectionTestCases.self, from: data)
    }
    
    func testIndexOfLastWord() {
        func lastWord(_ string: String) -> String {
            return String(string.suffix(from: Inflections.indexOfLastWord(string)))
        }
        XCTAssertEqual(lastWord(""), "")
        XCTAssertEqual(lastWord(" "), " ")
        XCTAssertEqual(lastWord("_"), "_")
        XCTAssertEqual(lastWord("foo"), "foo")
        XCTAssertEqual(lastWord("Foo"), "Foo")
        XCTAssertEqual(lastWord("FOO"), "FOO")
        XCTAssertEqual(lastWord("foo bar"), "bar")
        XCTAssertEqual(lastWord("Foo Bar"), "Bar")
        XCTAssertEqual(lastWord("FOO BAR"), "BAR")
        XCTAssertEqual(lastWord("foo_bar"), "bar")
        XCTAssertEqual(lastWord("Foo_Bar"), "Bar")
        XCTAssertEqual(lastWord("FOO_BAR"), "BAR")
        XCTAssertEqual(lastWord("foobar"), "foobar")
        XCTAssertEqual(lastWord("FooBar"), "Bar")
        XCTAssertEqual(lastWord("FOOBAR"), "FOOBAR")
        XCTAssertEqual(lastWord("foo1"), "foo1")
        XCTAssertEqual(lastWord("Foo1"), "Foo1")
        XCTAssertEqual(lastWord("FOO1"), "FOO1")
        XCTAssertEqual(lastWord("foo bar1"), "bar1")
        XCTAssertEqual(lastWord("Foo Bar1"), "Bar1")
        XCTAssertEqual(lastWord("FOO BAR1"), "BAR1")
        XCTAssertEqual(lastWord("foo_bar1"), "bar1")
        XCTAssertEqual(lastWord("Foo_Bar1"), "Bar1")
        XCTAssertEqual(lastWord("FOO_BAR1"), "BAR1")
        XCTAssertEqual(lastWord("foobar1"), "foobar1")
        XCTAssertEqual(lastWord("FooBar1"), "Bar1")
        XCTAssertEqual(lastWord("FOOBAR1"), "FOOBAR1")
    }
    
    func testPluralizePlurals() {
        XCTAssertEqual("plurals".pluralized, "plurals")
        XCTAssertEqual("Plurals".pluralized, "Plurals")
    }
    
    func testPluralizeEmptyString() {
        XCTAssertEqual("".pluralized, "")
    }
    
    func testUncountabilityOfASCIIWord() {
        let word = "HTTP"
        Inflections.default.uncountable(word)
        XCTAssertEqual(word.pluralized, word)
        XCTAssertEqual(word.singularized, word)
        XCTAssertEqual(word.pluralized, word.singularized)
    }
    
    func testUncountabilityOfNonASCIIWord() {
        let word = "猫"
        Inflections.default.uncountable(word)
        XCTAssertEqual(word.pluralized, word)
        XCTAssertEqual(word.singularized, word)
        XCTAssertEqual(word.pluralized, word.singularized)
    }

    func testUncountableWords() {
        for word in Inflections.default.uncountables {
            XCTAssertEqual(word.pluralized, word)
            XCTAssertEqual(word.singularized, word)
            XCTAssertEqual(word.pluralized, word.singularized)
        }
    }
    
    func testUncountableCapitalizedWords() {
        for word in Inflections.default.uncountables {
            XCTAssertEqual(word.capitalized.pluralized, word.capitalized)
            XCTAssertEqual(word.capitalized.singularized, word.capitalized)
            XCTAssertEqual(word.capitalized.pluralized, word.capitalized.singularized)
        }
    }
    
    func testUncountableUppercasedWords() {
        for word in Inflections.default.uncountables {
            XCTAssertEqual(word.uppercased().pluralized, word.uppercased())
            XCTAssertEqual(word.uppercased().singularized, word.uppercased())
            XCTAssertEqual(word.uppercased().pluralized, word.uppercased().singularized)
        }
    }
    
    func testUncountableWordIsNotGreedy() {
        let uncountableWord = "ors"
        let countableWord = "sponsor"
        
        Inflections.default.uncountable(uncountableWord)
        
        XCTAssertEqual(uncountableWord.singularized, uncountableWord)
        XCTAssertEqual(uncountableWord.pluralized, uncountableWord)
        XCTAssertEqual(uncountableWord.pluralized, uncountableWord.singularized)

        XCTAssertEqual(countableWord.singularized, "sponsor")
        XCTAssertEqual(countableWord.pluralized, "sponsors")
        XCTAssertEqual(countableWord.pluralized.singularized, "sponsor")
    }
    
    func testPluralizeSingularWord() {
        for (singular, plural) in inflectionTestCases.testCases["SingularToPlural"]! {
            XCTAssertEqual(singular.pluralized, plural)
            XCTAssertEqual(singular.capitalized.pluralized, plural.capitalized)
            
            let prefixedSingular = "prefixed" + singular.capitalized
            let prefixedPlural = "prefixed" + plural.capitalized
            XCTAssertEqual(prefixedSingular.pluralized, prefixedPlural)
        }
    }
    
    func testSingularizePluralWord() {
        for (singular, plural) in inflectionTestCases.testCases["SingularToPlural"]! {
            XCTAssertEqual(plural.singularized, singular)
            XCTAssertEqual(plural.capitalized.singularized, singular.capitalized)
            
            let prefixedSingular = "prefixed" + singular.capitalized
            let prefixedPlural = "prefixed" + plural.capitalized
            XCTAssertEqual(prefixedPlural.singularized, prefixedSingular)
        }
    }
    
    func testPluralizePluralWord() {
        for (_, plural) in inflectionTestCases.testCases["SingularToPlural"]! {
            XCTAssertEqual(plural.pluralized, plural)
            XCTAssertEqual(plural.capitalized.pluralized, plural.capitalized)
            
            let prefixedPlural = "prefixed" + plural.capitalized
            XCTAssertEqual(prefixedPlural.pluralized, prefixedPlural)
        }
    }
    
    func testSingularizeSingularWord() {
        for (singular, _) in inflectionTestCases.testCases["SingularToPlural"]! {
            XCTAssertEqual(singular.singularized, singular)
            XCTAssertEqual(singular.capitalized.singularized, singular.capitalized)
            
            let prefixedSingular = "prefixed" + singular.capitalized
            XCTAssertEqual(prefixedSingular.singularized, prefixedSingular)
        }
    }
    
    func testIrregularityBetweenSingularAndPlural() {
        for (singular, plural) in inflectionTestCases.testCases["Irregularities"]! {
            Inflections.default.irregular(singular, plural)
            XCTAssertEqual(plural.singularized, singular)
            XCTAssertEqual(singular.pluralized, plural)
            XCTAssertEqual(singular.singularized, singular)
            XCTAssertEqual(plural.pluralized, plural)
            
            let prefixedSingular = "prefixed" + singular.capitalized
            let prefixedPlural = "prefixed" + plural.capitalized
            XCTAssertEqual(prefixedPlural.singularized, prefixedSingular)
            XCTAssertEqual(prefixedSingular.pluralized, prefixedPlural)
            XCTAssertEqual(prefixedSingular.singularized, prefixedSingular)
            XCTAssertEqual(prefixedPlural.pluralized, prefixedPlural)
        }
    }
}

struct InflectionTestCases: Decodable {
    var testCases: [String: [(String, String)]]
    
    struct AnyCodingKey: CodingKey {
        var stringValue: String
        var intValue: Int? { return nil }

        init?(stringValue: String) {
            self.stringValue = stringValue
        }
        
        init?(intValue: Int) {
            return nil
        }
    }
    
    init(from decoder: Decoder) throws {
        var testCases: [String: [(String, String)]] = [:]
        let container = try decoder.container(keyedBy: AnyCodingKey.self)
        for key in container.allKeys {
            let nested = try container.nestedContainer(keyedBy: AnyCodingKey.self, forKey: key)
            for wordKey in nested.allKeys {
                let otherWord = try nested.decode(String.self, forKey: wordKey)
                testCases[key.stringValue, default: []].append((wordKey.stringValue, otherWord))
            }
        }
        self.testCases = testCases
    }
}

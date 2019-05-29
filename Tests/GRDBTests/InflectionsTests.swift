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
    
    // Until SPM tests can load resources, disable this test for SPM.
    #if !SWIFT_PACKAGE
    private var inflectionTestCases: InflectionTestCases {
        let url = Bundle(for: type(of: self)).url(forResource: "InflectionsTests", withExtension: "json")!
        let data = try! Data(contentsOf: url)
        return try! JSONDecoder().decode(InflectionTestCases.self, from: data)
    }
    #endif
    
    func testStartIndexOfLastWord() {
        func lastWord(_ string: String) -> String {
            return String(string.suffix(from: Inflections.startIndexOfLastWord(string)))
        }
        XCTAssertEqual(lastWord(""), "")
        XCTAssertEqual(lastWord(" "), " ")
        XCTAssertEqual(lastWord("_"), "_")
        
        XCTAssertEqual(lastWord("player"), "player")
        XCTAssertEqual(lastWord("Player"), "Player")
        XCTAssertEqual(lastWord("PLAYER"), "PLAYER")
        
        XCTAssertEqual(lastWord(" player"), "player")
        XCTAssertEqual(lastWord(" Player"), "Player")
        XCTAssertEqual(lastWord(" PLAYER"), "PLAYER")
        
        XCTAssertEqual(lastWord("_player"), "player")
        XCTAssertEqual(lastWord("_Player"), "Player")
        XCTAssertEqual(lastWord("_PLAYER"), "PLAYER")
        
        XCTAssertEqual(lastWord("player score"), "score")
        XCTAssertEqual(lastWord("player Score"), "Score")
        XCTAssertEqual(lastWord("Player Score"), "Score")
        XCTAssertEqual(lastWord("PLAYER SCORE"), "SCORE")
        
        XCTAssertEqual(lastWord("player_score"), "score")
        XCTAssertEqual(lastWord("player_Score"), "Score")
        XCTAssertEqual(lastWord("Player_Score"), "Score")
        XCTAssertEqual(lastWord("PLAYER_SCORE"), "SCORE")
        
        XCTAssertEqual(lastWord("playerScore"), "Score")
        XCTAssertEqual(lastWord("PlayerScore"), "Score")
        
        XCTAssertEqual(lastWord("best player score"), "score")
        XCTAssertEqual(lastWord("best player Score"), "Score")
        XCTAssertEqual(lastWord("Best Player Score"), "Score")
        XCTAssertEqual(lastWord("BEST PLAYER SCORE"), "SCORE")
        
        XCTAssertEqual(lastWord("best_player_score"), "score")
        XCTAssertEqual(lastWord("best_player_Score"), "Score")
        XCTAssertEqual(lastWord("Best_Player_Score"), "Score")
        XCTAssertEqual(lastWord("BEST_PLAYER_SCORE"), "SCORE")
        
        XCTAssertEqual(lastWord("bestPlayerScore"), "Score")
        XCTAssertEqual(lastWord("BestPlayerScore"), "Score")
        
        XCTAssertEqual(lastWord("player1"), "player1")
        XCTAssertEqual(lastWord("Player1"), "Player1")
        XCTAssertEqual(lastWord("PLAYER1"), "PLAYER1")
        
        XCTAssertEqual(lastWord("player score1"), "score1")
        XCTAssertEqual(lastWord("player Score1"), "Score1")
        XCTAssertEqual(lastWord("Player Score1"), "Score1")
        XCTAssertEqual(lastWord("PLAYER SCORE1"), "SCORE1")
        
        XCTAssertEqual(lastWord("player_score1"), "score1")
        XCTAssertEqual(lastWord("player_Score1"), "Score1")
        XCTAssertEqual(lastWord("Player_Score1"), "Score1")
        XCTAssertEqual(lastWord("PLAYER_SCORE1"), "SCORE1")
        
        XCTAssertEqual(lastWord("playerScore1"), "Score1")
        XCTAssertEqual(lastWord("PlayerScore1"), "Score1")
    }
    
    func testDigitlessRadical() {
        XCTAssertEqual("".digitlessRadical, "")
        XCTAssertEqual("player".digitlessRadical, "player")
        XCTAssertEqual("player0".digitlessRadical, "player")
        XCTAssertEqual("player123".digitlessRadical, "player")
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
        Inflections.default.uncountableWords([word])
        XCTAssertEqual(word.pluralized, word)
        XCTAssertEqual(word.singularized, word)
        XCTAssertEqual(word.pluralized, word.singularized)
    }
    
    func testUncountabilityOfNonASCIIWord() {
        let word = "猫"
        Inflections.default.uncountableWords([word])
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
        
        Inflections.default.uncountableWords([uncountableWord])
        
        XCTAssertEqual(uncountableWord.singularized, uncountableWord)
        XCTAssertEqual(uncountableWord.pluralized, uncountableWord)
        XCTAssertEqual(uncountableWord.pluralized, uncountableWord.singularized)
        
        XCTAssertEqual(countableWord.singularized, "sponsor")
        XCTAssertEqual(countableWord.pluralized, "sponsors")
        XCTAssertEqual(countableWord.pluralized.singularized, "sponsor")
    }
    
    // Until SPM tests can load resources, disable this test for SPM.
    #if !SWIFT_PACKAGE
    func testPluralizeSingularWord() {
        for (singular, plural) in inflectionTestCases.testCases["SingularToPlural"]! {
            XCTAssertEqual(singular.pluralized, plural)
            XCTAssertEqual(singular.capitalized.pluralized, plural.capitalized)
            
            let prefixedSingular = "prefixed" + singular.capitalized
            let prefixedPlural = "prefixed" + plural.capitalized
            XCTAssertEqual(prefixedSingular.pluralized, prefixedPlural)
            
            let suffixedSingular = singular + "123"
            let suffixedPlural = plural + "123"
            XCTAssertEqual(suffixedSingular.pluralized, suffixedPlural)
        }
    }
    #endif
    
    // Until SPM tests can load resources, disable this test for SPM.
    #if !SWIFT_PACKAGE
    func testSingularizePluralWord() {
        for (singular, plural) in inflectionTestCases.testCases["SingularToPlural"]! {
            XCTAssertEqual(plural.singularized, singular)
            XCTAssertEqual(plural.capitalized.singularized, singular.capitalized)
            
            let prefixedSingular = "prefixed" + singular.capitalized
            let prefixedPlural = "prefixed" + plural.capitalized
            XCTAssertEqual(prefixedPlural.singularized, prefixedSingular)
            
            let suffixedSingular = singular + "123"
            let suffixedPlural = plural + "123"
            XCTAssertEqual(suffixedPlural.singularized, suffixedSingular)
        }
    }
    #endif
    
    // Until SPM tests can load resources, disable this test for SPM.
    #if !SWIFT_PACKAGE
    func testPluralizePluralWord() {
        for (_, plural) in inflectionTestCases.testCases["SingularToPlural"]! {
            XCTAssertEqual(plural.pluralized, plural)
            XCTAssertEqual(plural.capitalized.pluralized, plural.capitalized)
            
            let prefixedPlural = "prefixed" + plural.capitalized
            XCTAssertEqual(prefixedPlural.pluralized, prefixedPlural)
            
            let suffixedPlural = plural + "123"
            XCTAssertEqual(suffixedPlural.pluralized, suffixedPlural)
        }
    }
    #endif
    
    // Until SPM tests can load resources, disable this test for SPM.
    #if !SWIFT_PACKAGE
    func testSingularizeSingularWord() {
        for (singular, _) in inflectionTestCases.testCases["SingularToPlural"]! {
            XCTAssertEqual(singular.singularized, singular)
            XCTAssertEqual(singular.capitalized.singularized, singular.capitalized)
            
            let prefixedSingular = "prefixed" + singular.capitalized
            XCTAssertEqual(prefixedSingular.singularized, prefixedSingular)
            
            let suffixedSingular = singular + "123"
            XCTAssertEqual(suffixedSingular.singularized, suffixedSingular)
        }
    }
    #endif
    
    // Until SPM tests can load resources, disable this test for SPM.
    #if !SWIFT_PACKAGE
    func testIrregularityBetweenSingularAndPlural() {
        for (singular, plural) in inflectionTestCases.testCases["Irregularities"]! {
            Inflections.default.irregularSuffix(singular, plural)
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
            
            let suffixedSingular = singular + "123"
            let suffixedPlural = plural + "123"
            XCTAssertEqual(suffixedPlural.singularized, suffixedSingular)
            XCTAssertEqual(suffixedSingular.pluralized, suffixedPlural)
            XCTAssertEqual(suffixedSingular.singularized, suffixedSingular)
            XCTAssertEqual(suffixedPlural.pluralized, suffixedPlural)
        }
    }
    #endif
}

// Until SPM tests can load resources, disable this test for SPM.
#if !SWIFT_PACKAGE
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
#endif

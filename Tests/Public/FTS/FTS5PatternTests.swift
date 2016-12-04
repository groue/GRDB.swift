import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class FTS5PatternTests: GRDBTestCase {
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
        try dbWriter.write { db in
            try db.create(virtualTable: "books", using: FTS5()) { t in
                t.column("title")
                t.column("author")
                t.column("body")
            }
            try db.execute("INSERT INTO books (title, author, body) VALUES (?, ?, ?)", arguments: ["Moby Dick", "Herman Melville", "Call me Ishmael. Some years ago--never mind how long precisely--having little or no money in my purse, and nothing particular to interest me on shore, I thought I would sail about a little and see the watery part of the world."])
            try db.execute("INSERT INTO books (title, author, body) VALUES (?, ?, ?)", arguments: ["Red Mars", "Kim Stanley Robinson", "History is not evolution! It is a false analogy! Evolution is a matter of environment and chance, acting over millions of years. But history is a matter of environment and choice, acting within lifetimes, and sometimes within years, or months, or days! History is Lamarckian!"])
            try db.execute("INSERT INTO books (title, author, body) VALUES (?, ?, ?)", arguments: ["Querelle de Brest", "Jean Genet", "L’idée de mer évoque souvent l’idée de mer, de marins. Mer et marins ne se présentent pas alors avec la précision d’une image, le meurtre plutôt fait en nous l’émotion déferler par vagues."])
            try db.execute("INSERT INTO books (title, author, body) VALUES (?, ?, ?)", arguments: ["Éden, Éden, Éden", "Pierre Guyotat", "/ Les soldats, casqués, jambes ouvertes, foulent, muscles retenus, les nouveau-nés emmaillotés dans les châles écarlates, violets : les bébés roulent hors des bras des femmes accroupies sur les tôles mitraillées des G. M. C. ;"])
        }
    }
    
    func testValidFTS5Pattern() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                // Couples (raw pattern, expected count of matching rows)
                let validRawPatterns: [(String, Int)] = [
                    // Token queries
                    ("Moby", 1),
                    ("écarlates", 1),
                    ("fooéı👨👨🏿🇫🇷🇨🇮", 0),
                    // Prefix queries
                    ("*", 1),   // weird
                    ("Robin*", 1),
                    // Phrase queries
                    ("\"foulent muscles\"", 1),
                    ("\"Kim Stan* Robin*\"", 0),
                    // NEAR queries
                    ("NEAR(\"history\" \"evolution\")", 1),
                    // Logical queries
                    ("years NOT months", 1),
                    ("years AND months", 1),
                    ("years OR months", 2),
                    // column queries
                    ("title:brest", 1)
                ]
                for (rawPattern, expectedCount) in validRawPatterns {
                    let pattern = try db.makeFTS5Pattern(rawPattern: rawPattern, forTable: "books")
                    let count = try Int.fetchOne(db, "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: [pattern])!
                    XCTAssertEqual(count, expectedCount, "Expected pattern \(String(reflecting: rawPattern)) to yield \(expectedCount) results")
                }
            }
        }
    }
    
    func testInvalidFTS5Pattern() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                let invalidRawPatterns = ["", "?!", "^", "^foo", "NOT", "(", "AND", "OR", "\"", "missing:foo"]
                for rawPattern in invalidRawPatterns {
                    do {
                        _ = try db.makeFTS5Pattern(rawPattern: rawPattern, forTable: "books")
                        XCTFail("Expected pattern to be invalid: \(String(reflecting: rawPattern))")
                    } catch is DatabaseError {
                    } catch {
                        XCTFail("Expected DatabaseError, not \(error)")
                    }
                }
            }
        }
    }
    
    func testFTS5PatternWithAnyToken() {
        let wrongInputs = ["", "*", "^", " ", "(", "()", "\"", "?!"]
        for string in wrongInputs {
            if let pattern = FTS5Pattern(matchingAnyTokenIn: string) {
                let rawPattern = String.fromDatabaseValue(pattern.databaseValue)!
                XCTFail("Unexpected raw pattern \(String(reflecting: rawPattern)) from string \(String(reflecting: string))")
            }
        }
        
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                // Couples (pattern, expected raw pattern, expected count of matching rows)
                let cases = [
                    ("écarlates", "écarlates", 1),
                    ("^Moby*", "moby", 1),
                    (" \t\nyears \t\nmonths \t\n", "years OR months", 2),
                    ("\"years months days\"", "years OR months OR days", 2),
                    ("FOOÉı👨👨🏿🇫🇷🇨🇮", "fooÉı👨👨🏿🇫🇷🇨🇮", 0),
                ]
                for (string, expectedRawPattern, expectedCount) in cases {
                    if let pattern = FTS5Pattern(matchingAnyTokenIn: string) {
                        let rawPattern = String.fromDatabaseValue(pattern.databaseValue)!
                        XCTAssertEqual(rawPattern, expectedRawPattern)
                        let count = try Int.fetchOne(db, "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: [pattern])!
                        XCTAssertEqual(count, expectedCount, "Expected pattern \(String(reflecting: rawPattern)) to yield \(expectedCount) results")
                    }
                }
            }
        }
    }
    
    func testFTS5PatternWithAllTokens() {
        let wrongInputs = ["", "*", "^", " ", "(", "()", "\"", "?!"]
        for string in wrongInputs {
            if let pattern = FTS5Pattern(matchingAllTokensIn: string) {
                let rawPattern = String.fromDatabaseValue(pattern.databaseValue)!
                XCTFail("Unexpected raw pattern \(String(reflecting: rawPattern)) from string \(String(reflecting: string))")
            }
        }
        
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                // Couples (pattern, expected raw pattern, expected count of matching rows)
                let cases = [
                    ("écarlates", "écarlates", 1),
                    ("^Moby*", "moby", 1),
                    (" \t\nyears \t\nmonths \t\n", "years months", 1),
                    ("\"years months days\"", "years months days", 1),
                    ("FOOÉı👨👨🏿🇫🇷🇨🇮", "fooÉı👨👨🏿🇫🇷🇨🇮", 0),
                    ]
                for (string, expectedRawPattern, expectedCount) in cases {
                    if let pattern = FTS5Pattern(matchingAllTokensIn: string) {
                        let rawPattern = String.fromDatabaseValue(pattern.databaseValue)!
                        XCTAssertEqual(rawPattern, expectedRawPattern)
                        let count = try Int.fetchOne(db, "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: [pattern])!
                        XCTAssertEqual(count, expectedCount, "Expected pattern \(String(reflecting: rawPattern)) to yield \(expectedCount) results")
                    }
                }
            }
        }
    }
    
    func testFTS5PatternWithPhrase() {
        let wrongInputs = ["", "*", "^", " ", "(", "()", "\"", "?!"]
        for string in wrongInputs {
            if let pattern = FTS5Pattern(matchingPhrase: string) {
                let rawPattern = String.fromDatabaseValue(pattern.databaseValue)!
                XCTFail("Unexpected raw pattern \(String(reflecting: rawPattern)) from string \(String(reflecting: string))")
            }
        }
        
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                // Couples (pattern, expected raw pattern, expected count of matching rows)
                let cases = [
                    ("écarlates", "\"écarlates\"", 1),
                    ("^Moby*", "\"moby\"", 1),
                    (" \t\nyears \t\nmonths \t\n", "\"years months\"", 0),
                    ("\"years months days\"", "\"years months days\"", 0),
                    ("FOOÉı👨👨🏿🇫🇷🇨🇮", "\"fooÉı👨👨🏿🇫🇷🇨🇮\"", 0),
                    ]
                for (string, expectedRawPattern, expectedCount) in cases {
                    if let pattern = FTS5Pattern(matchingPhrase: string) {
                        let rawPattern = String.fromDatabaseValue(pattern.databaseValue)!
                        XCTAssertEqual(rawPattern, expectedRawPattern)
                        let count = try Int.fetchOne(db, "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: [pattern])!
                        XCTAssertEqual(count, expectedCount, "Expected pattern \(String(reflecting: rawPattern)) to yield \(expectedCount) results")
                    }
                }
            }
        }
    }
}

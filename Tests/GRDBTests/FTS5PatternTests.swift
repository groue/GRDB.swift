#if SQLITE_ENABLE_FTS5
import XCTest
import GRDB

class FTS5PatternTests: GRDBTestCase {
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
        try dbWriter.write { db in
            try db.create(virtualTable: "books", using: FTS5()) { t in
                t.column("title")
                t.column("author")
                t.column("body")
            }
            try db.execute(sql: "INSERT INTO books (title, author, body) VALUES (?, ?, ?)", arguments: ["Moby-Dick", "Herman Melville", "Call me Ishmael. Some years ago--never mind how long precisely--having little or no money in my purse, and nothing particular to interest me on shore, I thought I would sail about a little and see the watery part of the world."])
            try db.execute(sql: "INSERT INTO books (title, author, body) VALUES (?, ?, ?)", arguments: ["Red Mars", "Kim Stanley Robinson", "History is not evolution! It is a false analogy! Evolution is a matter of environment and chance, acting over millions of years. But history is a matter of environment and choice, acting within lifetimes, and sometimes within years, or months, or days! History is Lamarckian!"])
            try db.execute(sql: "INSERT INTO books (title, author, body) VALUES (?, ?, ?)", arguments: ["Querelle de Brest", "Jean Genet", "L’idée de mer évoque souvent l’idée de mer, de marins. Mer et marins ne se présentent pas alors avec la précision d’une image, le meurtre plutôt fait en nous l’émotion déferler par vagues."])
            try db.execute(sql: "INSERT INTO books (title, author, body) VALUES (?, ?, ?)", arguments: ["Éden, Éden, Éden", "Pierre Guyotat", "/ Les soldats, casqués, jambes ouvertes, foulent, muscles retenus, les nouveau-nés emmaillotés dans les châles écarlates, violets : les bébés roulent hors des bras des femmes accroupies sur les tôles mitraillées des G. M. C. ;"])
        }
    }
    
    func testValidFTS5Pattern() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            // Couples (raw pattern, expected count of matching rows)
            let validRawPatterns: [(String, Int)] = [
                // Token queries
                ("Moby", 1),
                ("écarlates", 1),
                ("fooéı👨👨🏿🇫🇷🇨🇮", 0),
                // Prefix queries
                // ("*", 1),   // No longer valid on SQLite 3.30.1
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
                let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: [pattern])!
                XCTAssertEqual(count, expectedCount, "Expected pattern \(String(reflecting: rawPattern)) to yield \(expectedCount) results")
            }
        }
    }
    
    func testFTS5Tokenize() throws {
        // Empty query
        try XCTAssertEqual(FTS5.tokenize(""), [])
        try XCTAssertEqual(FTS5.tokenize("", withTokenizer: .ascii()), [])
        try XCTAssertEqual(FTS5.tokenize("", withTokenizer: .porter()), [])
        try XCTAssertEqual(FTS5.tokenize("", withTokenizer: .unicode61()), [])
        try XCTAssertEqual(FTS5.tokenize("", withTokenizer: .unicode61(diacritics: .keep)), [])
        
        try XCTAssertEqual(FTS5.tokenize("?!"), [])
        try XCTAssertEqual(FTS5.tokenize("?!", withTokenizer: .ascii()), [])
        try XCTAssertEqual(FTS5.tokenize("?!", withTokenizer: .porter()), [])
        try XCTAssertEqual(FTS5.tokenize("?!", withTokenizer: .unicode61()), [])
        try XCTAssertEqual(FTS5.tokenize("?!", withTokenizer: .unicode61(diacritics: .keep)), [])
        
        // Token queries
        try XCTAssertEqual(FTS5.tokenize("Moby"), ["moby"])
        try XCTAssertEqual(FTS5.tokenize("Moby", withTokenizer: .ascii()), ["moby"])
        try XCTAssertEqual(FTS5.tokenize("Moby", withTokenizer: .porter()), ["mobi"])
        try XCTAssertEqual(FTS5.tokenize("Moby", withTokenizer: .unicode61()), ["moby"])
        try XCTAssertEqual(FTS5.tokenize("Moby", withTokenizer: .unicode61(diacritics: .keep)), ["moby"])
        
        try XCTAssertEqual(FTS5.tokenize("écarlates"), ["écarlates"])
        try XCTAssertEqual(FTS5.tokenize("écarlates", withTokenizer: .ascii()), ["écarlates"])
        try XCTAssertEqual(FTS5.tokenize("écarlates", withTokenizer: .porter()), ["ecarl"])
        try XCTAssertEqual(FTS5.tokenize("écarlates", withTokenizer: .unicode61()), ["ecarlates"])
        try XCTAssertEqual(FTS5.tokenize("écarlates", withTokenizer: .unicode61(diacritics: .keep)), ["écarlates"])
        
        try XCTAssertEqual(FTS5.tokenize("fooéı👨👨🏿🇫🇷🇨🇮"), ["fooéı👨👨🏿🇫🇷🇨🇮"])
        try XCTAssertEqual(FTS5.tokenize("fooéı👨👨🏿🇫🇷🇨🇮", withTokenizer: .ascii()), ["fooéı👨👨🏿🇫🇷🇨🇮"])
        try XCTAssertEqual(FTS5.tokenize("fooéı👨👨🏿🇫🇷🇨🇮", withTokenizer: .porter()), ["fooeı", "🏿"]) // ¯\_(ツ)_/¯
        try XCTAssertEqual(FTS5.tokenize("fooéı👨👨🏿🇫🇷🇨🇮", withTokenizer: .unicode61()), ["fooeı", "🏿"]) // ¯\_(ツ)_/¯
        try XCTAssertEqual(FTS5.tokenize("fooéı👨👨🏿🇫🇷🇨🇮", withTokenizer: .unicode61(diacritics: .keep)), ["fooéı", "🏿"]) // ¯\_(ツ)_/¯
        
        try XCTAssertEqual(FTS5.tokenize("SQLite database"), ["sqlite", "database"])
        try XCTAssertEqual(FTS5.tokenize("SQLite database", withTokenizer: .ascii()), ["sqlite", "database"])
        try XCTAssertEqual(FTS5.tokenize("SQLite database", withTokenizer: .porter()), ["sqlite", "databas"])
        try XCTAssertEqual(FTS5.tokenize("SQLite database", withTokenizer: .unicode61()), ["sqlite", "database"])
        try XCTAssertEqual(FTS5.tokenize("SQLite database", withTokenizer: .unicode61(diacritics: .keep)), ["sqlite", "database"])
        
        try XCTAssertEqual(FTS5.tokenize("Édouard Manet"), ["Édouard", "manet"])
        try XCTAssertEqual(FTS5.tokenize("Édouard Manet", withTokenizer: .ascii()), ["Édouard", "manet"])
        try XCTAssertEqual(FTS5.tokenize("Édouard Manet", withTokenizer: .porter()), ["edouard", "manet"])
        try XCTAssertEqual(FTS5.tokenize("Édouard Manet", withTokenizer: .unicode61()), ["edouard", "manet"])
        try XCTAssertEqual(FTS5.tokenize("Édouard Manet", withTokenizer: .unicode61(diacritics: .keep)), ["édouard", "manet"])
        
        // Prefix queries
        try XCTAssertEqual(FTS5.tokenize("*"), [])
        try XCTAssertEqual(FTS5.tokenize("*", withTokenizer: .ascii()), [])
        try XCTAssertEqual(FTS5.tokenize("*", withTokenizer: .porter()), [])
        try XCTAssertEqual(FTS5.tokenize("*", withTokenizer: .unicode61()), [])
        try XCTAssertEqual(FTS5.tokenize("*", withTokenizer: .unicode61(diacritics: .keep)), [])
        
        try XCTAssertEqual(FTS5.tokenize("Robin*"), ["robin"])
        try XCTAssertEqual(FTS5.tokenize("Robin*", withTokenizer: .ascii()), ["robin"])
        try XCTAssertEqual(FTS5.tokenize("Robin*", withTokenizer: .porter()), ["robin"])
        try XCTAssertEqual(FTS5.tokenize("Robin*", withTokenizer: .unicode61()), ["robin"])
        try XCTAssertEqual(FTS5.tokenize("Robin*", withTokenizer: .unicode61(diacritics: .keep)), ["robin"])
        
        // Phrase queries
        try XCTAssertEqual(FTS5.tokenize("\"foulent muscles\""), ["foulent", "muscles"])
        try XCTAssertEqual(FTS5.tokenize("\"foulent muscles\"", withTokenizer: .ascii()), ["foulent", "muscles"])
        try XCTAssertEqual(FTS5.tokenize("\"foulent muscles\"", withTokenizer: .porter()), ["foulent", "muscl"])
        try XCTAssertEqual(FTS5.tokenize("\"foulent muscles\"", withTokenizer: .unicode61()), ["foulent", "muscles"])
        try XCTAssertEqual(FTS5.tokenize("\"foulent muscles\"", withTokenizer: .unicode61(diacritics: .keep)), ["foulent", "muscles"])
        
        try XCTAssertEqual(FTS5.tokenize("\"Kim Stan* Robin*\""), ["kim", "stan", "robin"])
        try XCTAssertEqual(FTS5.tokenize("\"Kim Stan* Robin*\"", withTokenizer: .ascii()), ["kim", "stan", "robin"])
        try XCTAssertEqual(FTS5.tokenize("\"Kim Stan* Robin*\"", withTokenizer: .porter()), ["kim", "stan", "robin"])
        try XCTAssertEqual(FTS5.tokenize("\"Kim Stan* Robin*\"", withTokenizer: .unicode61()), ["kim", "stan", "robin"])
        try XCTAssertEqual(FTS5.tokenize("\"Kim Stan* Robin*\"", withTokenizer: .unicode61(diacritics: .keep)), ["kim", "stan", "robin"])
        
        // Logical queries
        try XCTAssertEqual(FTS5.tokenize("years AND months"), ["years", "and", "months"])
        try XCTAssertEqual(FTS5.tokenize("years AND months", withTokenizer: .ascii()), ["years", "and", "months"])
        try XCTAssertEqual(FTS5.tokenize("years AND months", withTokenizer: .porter()), ["year", "and", "month"])
        try XCTAssertEqual(FTS5.tokenize("years AND months", withTokenizer: .unicode61()), ["years", "and", "months"])
        try XCTAssertEqual(FTS5.tokenize("years AND months", withTokenizer: .unicode61(diacritics: .keep)), ["years", "and", "months"])
        
        // column queries
        try XCTAssertEqual(FTS5.tokenize("title:brest"), ["title", "brest"])
        try XCTAssertEqual(FTS5.tokenize("title:brest", withTokenizer: .ascii()), ["title", "brest"])
        try XCTAssertEqual(FTS5.tokenize("title:brest", withTokenizer: .porter()), ["titl", "brest"])
        try XCTAssertEqual(FTS5.tokenize("title:brest", withTokenizer: .unicode61()), ["title", "brest"])
        try XCTAssertEqual(FTS5.tokenize("title:brest", withTokenizer: .unicode61(diacritics: .keep)), ["title", "brest"])
    }
    
    func testInvalidFTS5Pattern() throws {
        let dbQueue = try makeDatabaseQueue()
        dbQueue.inDatabase { db in
            let invalidRawPatterns = ["", "?!", "^", "NOT", "(", "AND", "OR", "\"", "missing:foo"]
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
    
    func testFTS5PatternWithAnyToken() throws {
        let wrongInputs = ["", "*", "^", " ", "(", "()", "\"", "?!"]
        for string in wrongInputs {
            if let pattern = FTS5Pattern(matchingAnyTokenIn: string) {
                let rawPattern = String.fromDatabaseValue(pattern.databaseValue)!
                XCTFail("Unexpected raw pattern \(String(reflecting: rawPattern)) from string \(String(reflecting: string))")
            }
        }
        
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
                    let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: [pattern])!
                    XCTAssertEqual(count, expectedCount, "Expected pattern \(String(reflecting: rawPattern)) to yield \(expectedCount) results")
                }
            }
        }
    }
    
    func testFTS5PatternWithAllTokens() throws {
        let wrongInputs = ["", "*", "^", " ", "(", "()", "\"", "?!"]
        for string in wrongInputs {
            if let pattern = FTS5Pattern(matchingAllTokensIn: string) {
                let rawPattern = String.fromDatabaseValue(pattern.databaseValue)!
                XCTFail("Unexpected raw pattern \(String(reflecting: rawPattern)) from string \(String(reflecting: string))")
            }
        }
        
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
                    let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: [pattern])!
                    XCTAssertEqual(count, expectedCount, "Expected pattern \(String(reflecting: rawPattern)) to yield \(expectedCount) results")
                }
            }
        }
    }
    
    func testFTS5PatternWithAllPrefixes() throws {
        let wrongInputs = ["", "*", "^", " ", "(", "()", "\"", "?!"]
        for string in wrongInputs {
            if let pattern = FTS5Pattern(matchingAllPrefixesIn: string) {
                let rawPattern = String.fromDatabaseValue(pattern.databaseValue)!
                XCTFail("Unexpected raw pattern \(String(reflecting: rawPattern)) from string \(String(reflecting: string))")
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            // Couples (pattern, expected raw pattern, expected count of matching rows)
            let cases = [
                ("écarlate", "écarlate*", 1),
                ("^Mob*", "mob*", 1),
                (" \t\nyear \t\nmonth \t\n", "year* month*", 1),
                ("\"year month day\"", "year* month* day*", 1),
                ("FOOÉı👨👨🏿🇫🇷", "fooÉı👨👨🏿🇫🇷*", 0),
            ]
            for (string, expectedRawPattern, expectedCount) in cases {
                if let pattern = FTS5Pattern(matchingAllPrefixesIn: string) {
                    let rawPattern = String.fromDatabaseValue(pattern.databaseValue)!
                    XCTAssertEqual(rawPattern, expectedRawPattern)
                    let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: [pattern])!
                    XCTAssertEqual(count, expectedCount, "Expected pattern \(String(reflecting: rawPattern)) to yield \(expectedCount) results")
                }
            }
        }
    }
    
    func testFTS5PatternWithPhrase() throws {
        let wrongInputs = ["", "*", "^", " ", "(", "()", "\"", "?!"]
        for string in wrongInputs {
            if let pattern = FTS5Pattern(matchingPhrase: string) {
                let rawPattern = String.fromDatabaseValue(pattern.databaseValue)!
                XCTFail("Unexpected raw pattern \(String(reflecting: rawPattern)) from string \(String(reflecting: string))")
            }
        }
        
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
                    let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: [pattern])!
                    XCTAssertEqual(count, expectedCount, "Expected pattern \(String(reflecting: rawPattern)) to yield \(expectedCount) results")
                }
            }
        }
    }
    
    func testFTS5PatternWithPrefixPhrase() throws {
        let wrongInputs = ["", "*", "^", " ", "(", "()", "\"", "?!"]
        for string in wrongInputs {
            if let pattern = FTS5Pattern(matchingPrefixPhrase: string) {
                let rawPattern = String.fromDatabaseValue(pattern.databaseValue)!
                XCTFail("Unexpected raw pattern \(String(reflecting: rawPattern)) from string \(String(reflecting: string))")
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            // Couples (pattern, expected raw pattern, expected count of matching rows)
            let cases = [
                ("écarlates", "^\"écarlates\"", 0),
                ("^Moby-dick*", "^\"moby dick\"", 1),
                ("not evolution", "^\"not evolution\"", 0),
                ("HISTORY IS", "^\"history is\"", 1),
                (" \t\nyears \t\nmonths \t\n", "^\"years months\"", 0),
                ("\"years months days\"", "^\"years months days\"", 0),
                ("FOOÉı👨👨🏿🇫🇷🇨🇮", "^\"fooÉı👨👨🏿🇫🇷🇨🇮\"", 0),
            ]
            for (string, expectedRawPattern, expectedCount) in cases {
                if let pattern = FTS5Pattern(matchingPrefixPhrase: string) {
                    let rawPattern = String.fromDatabaseValue(pattern.databaseValue)!
                    XCTAssertEqual(rawPattern, expectedRawPattern)
                    let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: [pattern])!
                    XCTAssertEqual(count, expectedCount, "Expected pattern \(String(reflecting: rawPattern)) to yield \(expectedCount) results")
                }
            }
        }
    }
}
#endif

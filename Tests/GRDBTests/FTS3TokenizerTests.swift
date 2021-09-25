import XCTest
import GRDB

class FTS3TokenizerTests: GRDBTestCase {
    
    private func match(_ db: Database, _ content: String, _ query: String) -> Bool {
        try! db.execute(sql: "INSERT INTO documents VALUES (?)", arguments: [content])
        defer {
            try! db.execute(sql: "DELETE FROM documents")
        }
        return try! Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: [query])! > 0
    }
    
    func testSimpleTokenizer() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS3()) { t in
                t.tokenizer = .simple
            }
            
            // simple match
            XCTAssertTrue(match(db, "abcDÉF", "abcDÉF"))
            
            // English stemming
            XCTAssertFalse(match(db, "database", "databases"))
            
            // diacritics in latin characters
            XCTAssertFalse(match(db, "eéÉ", "Èèe"))
            
            // unicode case
            XCTAssertFalse(match(db, "jérôme", "JÉRÔME"))
        }
    }

    func testPorterTokenizer() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS3()) { t in
                t.tokenizer = .porter
            }
            
            // simple match
            XCTAssertTrue(match(db, "abcDÉF", "abcDÉF"))
            
            // English stemming
            XCTAssertTrue(match(db, "database", "databases"))
            
            // diacritics in latin characters
            XCTAssertFalse(match(db, "eéÉ", "Èèe"))
            
            // unicode case
            XCTAssertFalse(match(db, "jérôme", "JÉRÔME"))
        }
    }

    func testUnicode61Tokenizer() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS3()) { t in
                t.tokenizer = .unicode61()
            }
            
            // simple match
            XCTAssertTrue(match(db, "abcDÉF", "abcDÉF"))
            
            // English stemming
            XCTAssertFalse(match(db, "database", "databases"))
            
            // diacritics in latin characters
            XCTAssertTrue(match(db, "eéÉ", "Èèe"))
            
            // unicode case
            XCTAssertTrue(match(db, "jérôme", "JÉRÔME"))
        }
    }

    func testUnicode61TokenizerDiacriticsKeep() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS3()) { t in
                t.tokenizer = .unicode61(diacritics: .keep)
            }
            
            // simple match
            XCTAssertTrue(match(db, "abcDÉF", "abcDÉF"))
            
            // English stemming
            XCTAssertFalse(match(db, "database", "databases"))
            
            // diacritics in latin characters
            XCTAssertFalse(match(db, "eéÉ", "Èèe"))
            
            // unicode case
            XCTAssertTrue(match(db, "jérôme", "JÉRÔME"))
        }
    }
    
    #if GRDBCUSTOMSQLITE
    func testUnicode61TokenizerDiacriticsRemove() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS3()) { t in
                t.tokenizer = .unicode61(diacritics: .remove)
            }
            
            // simple match
            XCTAssertTrue(match(db, "abcDÉF", "abcDÉF"))
            
            // English stemming
            XCTAssertFalse(match(db, "database", "databases"))
            
            // diacritics in latin characters
            XCTAssertTrue(match(db, "eéÉ", "Èèe"))
            
            // unicode case
            XCTAssertTrue(match(db, "jérôme", "JÉRÔME"))
        }
    }
    #endif

    func testUnicode61TokenizerSeparators() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS3()) { t in
                t.tokenizer = .unicode61(separators: ["X"])
            }
            
            XCTAssertTrue(match(db, "abcXdef", "abcXdef"))
            XCTAssertTrue(match(db, "abcXdef", "defXabc"))
            XCTAssertTrue(match(db, "abcXdef", "abc"))
            XCTAssertTrue(match(db, "abcXdef", "def"))
        }
    }

    func testUnicode61TokenizerTokenCharacters() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS3()) { t in
                t.tokenizer = .unicode61(tokenCharacters: Set(".-"))
            }
            
            XCTAssertTrue(match(db, "2016-10-04.txt", "2016-10-04.txt"))
            XCTAssertFalse(match(db, "2016-10-04.txt", "2016"))
            XCTAssertFalse(match(db, "2016-10-04.txt", "txt"))
        }
    }
    
    func testTokenize() {
        // Empty query
        XCTAssertEqual(FTS3.tokenize(""), [])
        XCTAssertEqual(FTS3.tokenize("", withTokenizer: .simple), [])
        XCTAssertEqual(FTS3.tokenize("", withTokenizer: .porter), [])
        XCTAssertEqual(FTS3.tokenize("", withTokenizer: .unicode61()), [])
        XCTAssertEqual(FTS3.tokenize("", withTokenizer: .unicode61(diacritics: .keep)), [])
        
        XCTAssertEqual(FTS3.tokenize("?!"), [])
        XCTAssertEqual(FTS3.tokenize("?!", withTokenizer: .simple), [])
        XCTAssertEqual(FTS3.tokenize("?!", withTokenizer: .porter), [])
        XCTAssertEqual(FTS3.tokenize("?!", withTokenizer: .unicode61()), [])
        XCTAssertEqual(FTS3.tokenize("?!", withTokenizer: .unicode61(diacritics: .keep)), [])
        
        // Token queries
        XCTAssertEqual(FTS3.tokenize("Moby"), ["moby"])
        XCTAssertEqual(FTS3.tokenize("Moby", withTokenizer: .simple), ["moby"])
        XCTAssertEqual(FTS3.tokenize("Moby", withTokenizer: .porter), ["mobi"])
        XCTAssertEqual(FTS3.tokenize("Moby", withTokenizer: .unicode61()), ["moby"])
        XCTAssertEqual(FTS3.tokenize("Moby", withTokenizer: .unicode61(diacritics: .keep)), ["moby"])
        
        XCTAssertEqual(FTS3.tokenize("écarlates"), ["écarlates"])
        XCTAssertEqual(FTS3.tokenize("écarlates", withTokenizer: .simple), ["écarlates"])
        XCTAssertEqual(FTS3.tokenize("écarlates", withTokenizer: .porter), ["écarlates"])
        XCTAssertEqual(FTS3.tokenize("écarlates", withTokenizer: .unicode61()), ["ecarlates"])
        XCTAssertEqual(FTS3.tokenize("écarlates", withTokenizer: .unicode61(diacritics: .keep)), ["écarlates"])
        
        XCTAssertEqual(FTS3.tokenize("fooéı👨👨🏿🇫🇷🇨🇮"), ["fooéı👨👨🏿🇫🇷🇨🇮"])
        XCTAssertEqual(FTS3.tokenize("fooéı👨👨🏿🇫🇷🇨🇮", withTokenizer: .simple), ["fooéı👨👨🏿🇫🇷🇨🇮"])
        XCTAssertEqual(FTS3.tokenize("fooéı👨👨🏿🇫🇷🇨🇮", withTokenizer: .porter), ["fooéı👇�🇨🇮"]) // ¯\_(ツ)_/¯
        XCTAssertEqual(FTS3.tokenize("fooéı👨👨🏿🇫🇷🇨🇮", withTokenizer: .unicode61()), ["fooeı", "🏿"]) // ¯\_(ツ)_/¯
        XCTAssertEqual(FTS3.tokenize("fooéı👨👨🏿🇫🇷🇨🇮", withTokenizer: .unicode61(diacritics: .keep)), ["fooéı", "🏿"]) // ¯\_(ツ)_/¯
        
        XCTAssertEqual(FTS3.tokenize("SQLite database"), ["sqlite", "database"])
        XCTAssertEqual(FTS3.tokenize("SQLite database", withTokenizer: .simple), ["sqlite", "database"])
        XCTAssertEqual(FTS3.tokenize("SQLite database", withTokenizer: .porter), ["sqlite", "databas"])
        XCTAssertEqual(FTS3.tokenize("SQLite database", withTokenizer: .unicode61()), ["sqlite", "database"])
        XCTAssertEqual(FTS3.tokenize("SQLite database", withTokenizer: .unicode61(diacritics: .keep)), ["sqlite", "database"])
        
        XCTAssertEqual(FTS3.tokenize("Édouard Manet"), ["Édouard", "manet"])
        XCTAssertEqual(FTS3.tokenize("Édouard Manet", withTokenizer: .simple), ["Édouard", "manet"])
        XCTAssertEqual(FTS3.tokenize("Édouard Manet", withTokenizer: .porter), ["Édouard", "manet"])
        XCTAssertEqual(FTS3.tokenize("Édouard Manet", withTokenizer: .unicode61()), ["edouard", "manet"])
        XCTAssertEqual(FTS3.tokenize("Édouard Manet", withTokenizer: .unicode61(diacritics: .keep)), ["édouard", "manet"])
        
        // Prefix queries
        XCTAssertEqual(FTS3.tokenize("*"), [])
        XCTAssertEqual(FTS3.tokenize("*", withTokenizer: .simple), [])
        XCTAssertEqual(FTS3.tokenize("*", withTokenizer: .porter), [])
        XCTAssertEqual(FTS3.tokenize("*", withTokenizer: .unicode61()), [])
        XCTAssertEqual(FTS3.tokenize("*", withTokenizer: .unicode61(diacritics: .keep)), [])
        
        XCTAssertEqual(FTS3.tokenize("Robin*"), ["robin"])
        XCTAssertEqual(FTS3.tokenize("Robin*", withTokenizer: .simple), ["robin"])
        XCTAssertEqual(FTS3.tokenize("Robin*", withTokenizer: .porter), ["robin"])
        XCTAssertEqual(FTS3.tokenize("Robin*", withTokenizer: .unicode61()), ["robin"])
        XCTAssertEqual(FTS3.tokenize("Robin*", withTokenizer: .unicode61(diacritics: .keep)), ["robin"])
        
        // Phrase queries
        XCTAssertEqual(FTS3.tokenize("\"foulent muscles\""), ["foulent", "muscles"])
        XCTAssertEqual(FTS3.tokenize("\"foulent muscles\"", withTokenizer: .simple), ["foulent", "muscles"])
        XCTAssertEqual(FTS3.tokenize("\"foulent muscles\"", withTokenizer: .porter), ["foulent", "muscl"])
        XCTAssertEqual(FTS3.tokenize("\"foulent muscles\"", withTokenizer: .unicode61()), ["foulent", "muscles"])
        XCTAssertEqual(FTS3.tokenize("\"foulent muscles\"", withTokenizer: .unicode61(diacritics: .keep)), ["foulent", "muscles"])
        
        XCTAssertEqual(FTS3.tokenize("\"Kim Stan* Robin*\""), ["kim", "stan", "robin"])
        XCTAssertEqual(FTS3.tokenize("\"Kim Stan* Robin*\"", withTokenizer: .simple), ["kim", "stan", "robin"])
        XCTAssertEqual(FTS3.tokenize("\"Kim Stan* Robin*\"", withTokenizer: .porter), ["kim", "stan", "robin"])
        XCTAssertEqual(FTS3.tokenize("\"Kim Stan* Robin*\"", withTokenizer: .unicode61()), ["kim", "stan", "robin"])
        XCTAssertEqual(FTS3.tokenize("\"Kim Stan* Robin*\"", withTokenizer: .unicode61(diacritics: .keep)), ["kim", "stan", "robin"])
        
        // Logical queries
        XCTAssertEqual(FTS3.tokenize("years AND months"), ["years", "and", "months"])
        XCTAssertEqual(FTS3.tokenize("years AND months", withTokenizer: .simple), ["years", "and", "months"])
        XCTAssertEqual(FTS3.tokenize("years AND months", withTokenizer: .porter), ["year", "and", "month"])
        XCTAssertEqual(FTS3.tokenize("years AND months", withTokenizer: .unicode61()), ["years", "and", "months"])
        XCTAssertEqual(FTS3.tokenize("years AND months", withTokenizer: .unicode61(diacritics: .keep)), ["years", "and", "months"])
        
        // column queries
        XCTAssertEqual(FTS3.tokenize("title:brest"), ["title", "brest"])
        XCTAssertEqual(FTS3.tokenize("title:brest", withTokenizer: .simple), ["title", "brest"])
        XCTAssertEqual(FTS3.tokenize("title:brest", withTokenizer: .porter), ["titl", "brest"])
        XCTAssertEqual(FTS3.tokenize("title:brest", withTokenizer: .unicode61()), ["title", "brest"])
        XCTAssertEqual(FTS3.tokenize("title:brest", withTokenizer: .unicode61(diacritics: .keep)), ["title", "brest"])
    }
}

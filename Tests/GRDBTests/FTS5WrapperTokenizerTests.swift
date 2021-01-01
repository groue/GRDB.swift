#if SQLITE_ENABLE_FTS5
import XCTest
import Foundation
import GRDB

// A custom wrapper tokenizer that ignores some tokens
private final class StopWordsTokenizer : FTS5WrapperTokenizer {
    static let name = "stopWords"
    var wrappedTokenizer: FTS5Tokenizer
    
    init(db: Database, arguments: [String]) throws {
        if arguments.isEmpty {
            wrappedTokenizer = try db.makeTokenizer(.unicode61())
        } else {
            wrappedTokenizer = try db.makeTokenizer(FTS5TokenizerDescriptor(components: arguments))
        }
    }
    
    func ignores(_ token: String) -> Bool { token == "bar" }
    
    func accept(token: String, flags: FTS5TokenFlags, for tokenization: FTS5Tokenization, tokenCallback: FTS5WrapperTokenCallback) throws {
        // Notify token unless ignored
        if !ignores(token){
            try tokenCallback(token, flags)
        }
    }
}

// A custom wrapper tokenizer that converts tokens to LatinAscii so that "fi" can match "ﬁ" (U+FB01: LATIN SMALL LIGATURE FI), "ß", "ss", and "æ", "ae".
private final class LatinAsciiTokenizer : FTS5WrapperTokenizer {
    static let name = "latinascii"
    let wrappedTokenizer: FTS5Tokenizer
    
    init(db: Database, arguments: [String]) throws {
        wrappedTokenizer = try db.makeTokenizer(.unicode61())
    }
    
    func accept(token: String, flags: FTS5TokenFlags, for tokenization: FTS5Tokenization, tokenCallback: FTS5WrapperTokenCallback) throws {
        // Convert token to Latin-ASCII and lowercase
        if #available(OSX 10.11, *) {
            if let token = token.applyingTransform(StringTransform("Latin-ASCII; Lower"), reverse: false) {
                try tokenCallback(token, flags)
            }
        } else {
            if let token = CFStringCreateMutableCopy(kCFAllocatorDefault, 0, token as CFString) {
                CFStringTransform(token, nil, "Latin-ASCII; Lower" as CFString, false)
                try tokenCallback(token as String, flags)
            }
        }
    }
}

// A custom wrapper tokenizer that defines synonyms
private final class SynonymsTokenizer : FTS5WrapperTokenizer {
    static let name = "synonyms"
    let wrappedTokenizer: FTS5Tokenizer
    let synonyms: [Set<String>] = [["first", "1st"]]
    
    init(db: Database, arguments: [String]) throws {
        if arguments.isEmpty {
            wrappedTokenizer = try db.makeTokenizer(.unicode61())
        } else {
            wrappedTokenizer = try db.makeTokenizer(FTS5TokenizerDescriptor(components: arguments))
        }
    }
    
    func synonyms(for token: String) -> Set<String>? {
        synonyms.first { $0.contains(token) }
    }
    
    func accept(token: String, flags: FTS5TokenFlags, for tokenization: FTS5Tokenization, tokenCallback: FTS5WrapperTokenCallback) throws {
        if tokenization.contains(.query) {
            // Don't look for synonyms when tokenizing queries, as advised by
            // https://www.sqlite.org/fts5.html#synonym_support
            try tokenCallback(token, flags)
            return
        }
        
        guard let synonyms = synonyms(for: token) else {
            // Token has no synonym
            try tokenCallback(token, flags)
            return
        }
        
        for (index, synonym) in synonyms.enumerated() {
            // Notify each synonym, and set the colocated flag for all but
            // the first, as documented by
            // https://www.sqlite.org/fts5.html#synonym_support
            let synonymFlags = (index == 0) ? flags : flags.union(.colocated)
            try tokenCallback(synonym, synonymFlags)
        }
    }
}

class CustomizedUnicode61WrappingTokenizer: FTS5WrapperTokenizer {
    static let name = "custom_unicode61"
    let wrappedTokenizer: FTS5Tokenizer
    
    required init(db: Database, arguments: [String]) throws {
        wrappedTokenizer = try db.makeTokenizer(.unicode61(diacritics: .removeLegacy, separators: ["X"]))
    }
    
    func accept(token: String, flags: FTS5TokenFlags, for tokenization: FTS5Tokenization, tokenCallback: (String, FTS5TokenFlags) throws -> Void) throws {
        try tokenCallback(token, [])
    }
}

class FTS5WrapperTokenizerTests: GRDBTestCase {
    
    func testStopWordsTokenizerDatabaseQueue() throws {
        let dbQueue = try makeDatabaseQueue()
        
        try dbQueue.inDatabase { db in
            db.add(tokenizer: StopWordsTokenizer.self)
            try db.create(virtualTable: "documents", using: FTS5()) { t in
                t.tokenizer = StopWordsTokenizer.tokenizerDescriptor()
                t.column("content")
            }
            
            try db.execute(sql: "INSERT INTO documents VALUES (?)", arguments: ["foo bar"])
            try db.execute(sql: "INSERT INTO documents VALUES (?)", arguments: ["foo baz"])
            
            // foo is not ignored
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["foo"]), 2)
            // bar is ignored
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["bar"]), 0)
            // bar is ignored in queries too: the "foo bar baz" phrase matches the "foo baz" content
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["\"foo bar baz\""]), 1)
        }
    }

    func testStopWordsTokenizerDatabasePool() throws {
        dbConfiguration.prepareDatabase { db in
            db.add(tokenizer: StopWordsTokenizer.self)
        }
        let dbPool = try makeDatabaseQueue()
        
        try dbPool.write { db in
            try db.create(virtualTable: "documents", using: FTS5()) { t in
                t.tokenizer = StopWordsTokenizer.tokenizerDescriptor()
                t.column("content")
            }
            
            try db.execute(sql: "INSERT INTO documents VALUES (?)", arguments: ["foo bar"])
            try db.execute(sql: "INSERT INTO documents VALUES (?)", arguments: ["foo baz"])
            
            // foo is not ignored
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["foo"]), 2)
            // bar is ignored
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["bar"]), 0)
            // bar is ignored in queries too: the "foo bar baz" phrase matches the "foo baz" content
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["\"foo bar baz\""]), 1)
        }
        
        try dbPool.read { db in
            // foo is not ignored
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["foo"]), 2)
            // bar is ignored
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["bar"]), 0)
            // bar is ignored in queries too: the "foo bar baz" phrase matches the "foo baz" content
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["\"foo bar baz\""]), 1)
        }
    }

    func testLatinAsciiTokenizer() throws {
        let dbQueue = try makeDatabaseQueue()
        
        // Without Latin ASCII conversion
        try dbQueue.inDatabase { db in
            db.add(tokenizer: LatinAsciiTokenizer.self)
            try db.create(virtualTable: "documents", using: FTS5()) { t in
                t.tokenizer = .unicode61()
                t.column("content")
            }
            
            try db.execute(sql: "INSERT INTO documents VALUES (?)", arguments: ["aimé \u{FB01}délité Encyclopædia Großmann Diyarbakır"])
            
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["aimé \u{FB01}délité Encyclopædia Großmann Diyarbakır"]), 1)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["aime fidelite encyclopaedia grossmann diyarbakir"]), 0)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["aime\u{0301} \u{FB01}de\u{0301}lite\u{0301} Encyclopædia Großmann Diyarbakır"]), 1)
            
            try db.drop(table: "documents")
        }
        
        // With Latin ASCII conversion
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS5()) { t in
                t.tokenizer = LatinAsciiTokenizer.tokenizerDescriptor()
                t.column("content")
            }
            
            try db.execute(sql: "INSERT INTO documents VALUES (?)", arguments: ["aimé \u{FB01}délité Encyclopædia Großmann Diyarbakır"]) // U+FB01: LATIN SMALL LIGATURE FI
            
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["aimé \u{FB01}délité Encyclopædia Großmann Diyarbakır"]), 1)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["aime fidelite encyclopaedia grossmann diyarbakir"]), 1)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["aime\u{0301} \u{FB01}de\u{0301}lite\u{0301} Encyclopædia Großmann Diyarbakır"]), 1)
            
            try db.drop(table: "documents")
        }
    }

    func testSynonymsTokenizer() throws {
        let dbQueue = try makeDatabaseQueue()
        
        try dbQueue.inDatabase { db in
            db.add(tokenizer: SynonymsTokenizer.self)
            try db.create(virtualTable: "documents", using: FTS5()) { t in
                t.tokenizer = SynonymsTokenizer.tokenizerDescriptor()
                t.column("content")
            }
            
            try db.execute(sql: "INSERT INTO documents VALUES (?)", arguments: ["first foo"])
            try db.execute(sql: "INSERT INTO documents VALUES (?)", arguments: ["1st bar"])
            
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["first"]), 2)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["1st"]), 2)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["\"first foo\""]), 1)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["\"1st foo\""]), 1)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["\"first bar\""]), 1)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["\"1st bar\""]), 1)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["fi*"]), 2)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["1s*"]), 2)
        }
    }

    func testCustomizedUnicode61WrappingTokenizer() throws {
        let dbQueue = try makeDatabaseQueue()
        
        try dbQueue.inDatabase { db in
            db.add(tokenizer: CustomizedUnicode61WrappingTokenizer.self)
            try db.create(virtualTable: "documents", using: FTS5()) { t in
                t.tokenizer = CustomizedUnicode61WrappingTokenizer.tokenizerDescriptor()
                t.column("content")
            }
            
            try db.execute(sql: "INSERT INTO documents VALUES (?)", arguments: ["abcXdef"])
            
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["abc"]), 1)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["def"]), 1)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["abcXdef"]), 1)
        }
    }
}
#endif

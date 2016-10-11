import XCTest
import Foundation
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

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
    
    func ignores(_ token: String) -> Bool {
        return token == "bar"
    }
    
    func customizesTokenization(flags: FTS5TokenizationFlags) -> Bool {
        return true
    }
    
    func accept(token: String, flags: FTS5TokenFlags, tokenCallback: FTS5WrapperTokenCallback) throws {
        // Notify token unless ignored
        if !ignores(token){
            try tokenCallback(token, flags)
        }
    }
}

// A custom wrapper tokenizer that converts tokens to NFKC so that "fi" can match "ﬁ" (U+FB01: LATIN SMALL LIGATURE FI)
private final class NFKCTokenizer : FTS5WrapperTokenizer {
    static let name = "nfkc"
    let wrappedTokenizer: FTS5Tokenizer
    
    init(db: Database, arguments: [String]) throws {
        if arguments.isEmpty {
            wrappedTokenizer = try db.makeTokenizer(.unicode61())
        } else {
            wrappedTokenizer = try db.makeTokenizer(FTS5TokenizerDescriptor(components: arguments))
        }
    }
    
    func customizesTokenization(flags: FTS5TokenizationFlags) -> Bool {
        return true
    }
    
    func accept(token: String, flags: FTS5TokenFlags, tokenCallback: FTS5WrapperTokenCallback) throws {
        // Convert token to NFKC
        try tokenCallback(token.precomposedStringWithCompatibilityMapping, flags)
    }
}

// A custom wrapper tokenizer that defines synonyms
private final class SynonymsTokenizer : FTS5WrapperTokenizer {
    static let name = "synonyms"
    let wrappedTokenizer: FTS5Tokenizer
    
    init(db: Database, arguments: [String]) throws {
        if arguments.isEmpty {
            wrappedTokenizer = try db.makeTokenizer(.unicode61())
        } else {
            wrappedTokenizer = try db.makeTokenizer(FTS5TokenizerDescriptor(components: arguments))
        }
    }
    
    func synonyms(for token: String) -> Set<String>? {
        let synonyms: [Set<String>] = [["first", "1st"]]
        return synonyms.first(where: { $0.contains(token) })
    }
    
    func customizesTokenization(flags: FTS5TokenizationFlags) -> Bool {
        // Don't look for synonyms when tokenizing queries, as advised by
        // https://www.sqlite.org/fts5.html#synonym_support
        return !flags.contains(.query)
    }
    
    func accept(token: String, flags: FTS5TokenFlags, tokenCallback: FTS5WrapperTokenCallback) throws {
        if let synonyms = synonyms(for: token) {
            for (index, synonym) in synonyms.enumerated() {
                // Notify each synonym, and set the colocated flag for all but
                // the first, as documented by
                // https://www.sqlite.org/fts5.html#synonym_support
                let synonymFlags = (index == 0) ? flags : flags.union(.colocated)
                try tokenCallback(synonym, synonymFlags)
            }
        } else {
            // Token has no synonym
            try tokenCallback(token, flags)
        }
    }
}

class FTS5WrapperTokenizerTests: GRDBTestCase {
    
    func testStopWordsTokenizerDatabaseQueue() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.add(tokenizer: StopWordsTokenizer.self)
            
            try dbQueue.inDatabase { db in
                try db.create(virtualTable: "documents", using: FTS5()) { t in
                    t.tokenizer = StopWordsTokenizer.tokenizerDescriptor()
                    t.column("content")
                }
                
                try db.execute("INSERT INTO documents VALUES (?)", arguments: ["foo bar"])
                try db.execute("INSERT INTO documents VALUES (?)", arguments: ["foo baz"])
                
                // foo is not ignored
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["foo"]), 2)
                // bar is ignored
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["bar"]), 0)
                // bar is ignored in queries too: the "foo bar baz" phrase matches the "foo baz" content
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["\"foo bar baz\""]), 1)
            }
        }
    }
    
    func testStopWordsTokenizerDatabasePool() {
        assertNoError {
            let dbPool = try makeDatabaseQueue()
            dbPool.add(tokenizer: StopWordsTokenizer.self)
            
            try dbPool.write { db in
                try db.create(virtualTable: "documents", using: FTS5()) { t in
                    t.tokenizer = StopWordsTokenizer.tokenizerDescriptor()
                    t.column("content")
                }
                
                try db.execute("INSERT INTO documents VALUES (?)", arguments: ["foo bar"])
                try db.execute("INSERT INTO documents VALUES (?)", arguments: ["foo baz"])
                
                // foo is not ignored
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["foo"]), 2)
                // bar is ignored
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["bar"]), 0)
                // bar is ignored in queries too: the "foo bar baz" phrase matches the "foo baz" content
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["\"foo bar baz\""]), 1)
            }
            
            dbPool.read { db in
                // foo is not ignored
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["foo"]), 2)
                // bar is ignored
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["bar"]), 0)
                // bar is ignored in queries too: the "foo bar baz" phrase matches the "foo baz" content
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["\"foo bar baz\""]), 1)
            }
        }
    }
    
    func testNFKCTokenizer() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.add(tokenizer: NFKCTokenizer.self)
            
            // Without NFKC conversion
            try dbQueue.inDatabase { db in
                try db.create(virtualTable: "documents", using: FTS5()) { t in
                    t.tokenizer = .unicode61()
                    t.column("content")
                }
                
                try db.execute("INSERT INTO documents VALUES (?)", arguments: ["aimé\u{FB01}"]) // U+FB01: LATIN SMALL LIGATURE FI
                
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["aimé\u{FB01}"]), 1)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["aimefi"]), 0)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["aim\u{00E9}fi"]), 0)
                
                try db.drop(table: "documents")
            }
            
            // With NFKC conversion wrapping unicode61 (the default)
            try dbQueue.inDatabase { db in
                try db.create(virtualTable: "documents", using: FTS5()) { t in
                    t.tokenizer = NFKCTokenizer.tokenizerDescriptor()
                    t.column("content")
                }
                
                try db.execute("INSERT INTO documents VALUES (?)", arguments: ["aimé\u{FB01}"]) // U+FB01: LATIN SMALL LIGATURE FI
                
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["aimé\u{FB01}"]), 1)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["aimefi"]), 1)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["aim\u{00E9}fi"]), 1)
                
                try db.drop(table: "documents")
            }
            
            // With NFKC conversion wrapping ascii
            try dbQueue.inDatabase { db in
                try db.create(virtualTable: "documents", using: FTS5()) { t in
                    let ascii = FTS5TokenizerDescriptor.ascii()
                    t.tokenizer = NFKCTokenizer.tokenizerDescriptor(arguments: ascii.components)
                    t.column("content")
                }
                
                try db.execute("INSERT INTO documents VALUES (?)", arguments: ["aimé\u{FB01}"]) // U+FB01: LATIN SMALL LIGATURE FI
                
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["aimé\u{FB01}"]), 1)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["aimefi"]), 0)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["aim\u{00E9}fi"]), 1)
                
                try db.drop(table: "documents")
            }
        }
    }
    
    func testSynonymTokenizer() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.add(tokenizer: SynonymsTokenizer.self)
            
            try dbQueue.inDatabase { db in
                try db.create(virtualTable: "documents", using: FTS5()) { t in
                    t.tokenizer = SynonymsTokenizer.tokenizerDescriptor()
                    t.column("content")
                }
                
                try db.execute("INSERT INTO documents VALUES (?)", arguments: ["first foo"])
                try db.execute("INSERT INTO documents VALUES (?)", arguments: ["1st bar"])
                
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["first"]), 2)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["1st"]), 2)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["\"first foo\""]), 1)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["\"1st foo\""]), 1)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["\"first bar\""]), 1)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["\"1st bar\""]), 1)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["fi*"]), 2)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["1s*"]), 2)
            }
        }
    }
}

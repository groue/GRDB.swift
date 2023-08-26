#if SQLITE_ENABLE_FTS5
import XCTest
import Foundation
import GRDB

// A custom tokenizer that ignores some tokens
private final class StopWordsTokenizer : FTS5CustomTokenizer {
    static let name = "stopWords"
    let wrappedTokenizer: any FTS5Tokenizer
    let ignoredTokens: [String]
    
    init(db: Database, arguments: [String]) throws {
        if arguments.isEmpty {
            wrappedTokenizer = try db.makeTokenizer(.unicode61())
        } else {
            wrappedTokenizer = try db.makeTokenizer(FTS5TokenizerDescriptor(components: arguments))
        }
        // TODO: find a way to provide stop words through arguments
        ignoredTokens = ["bar"]
    }
    
    deinit {
        // TODO: test that deinit is called
    }
    
    func tokenize(context: UnsafeMutableRawPointer?, tokenization: FTS5Tokenization, pText: UnsafePointer<CChar>?, nText: Int32, tokenCallback: @escaping FTS5TokenCallback) -> Int32 {
        
        // The way we implement stop words is by letting wrappedTokenizer do its
        // job but intercepting its tokens before they feed SQLite.
        //
        // `tokenCallback` is @convention(c). This requires a little setup in
        // order to transfer context.
        struct CustomContext {
            let ignoredTokens: [String]
            let context: UnsafeMutableRawPointer
            let tokenCallback: FTS5TokenCallback
        }
        var customContext = CustomContext(ignoredTokens: ignoredTokens, context: context!, tokenCallback: tokenCallback)
        return withUnsafeMutablePointer(to: &customContext) { customContextPointer in
            // Invoke wrappedTokenizer, but intercept raw tokens
            return wrappedTokenizer.tokenize(context: customContextPointer, tokenization: tokenization, pText: pText, nText: nText) { (customContextPointer, flags, pToken, nToken, iStart, iEnd) in
                // Extract context
                let customContext = customContextPointer!.assumingMemoryBound(to: CustomContext.self).pointee
                
                // Extract token
                guard let token = pToken.flatMap({ String(data: Data(bytesNoCopy: UnsafeMutableRawPointer(mutating: $0), count: Int(nToken), deallocator: .none), encoding: .utf8) }) else {
                    return 0 // SQLITE_OK
                }
                
                // Ignore stop words
                if customContext.ignoredTokens.contains(token) {
                    return 0 // SQLITE_OK
                }
                
                // Notify token
                return customContext.tokenCallback(customContext.context, flags, pToken, nToken, iStart, iEnd)
            }
        }
    }
}

// A custom tokenizer that converts tokens to NFKC so that "fi" can match "ﬁ" (U+FB01: LATIN SMALL LIGATURE FI)
private final class NFKCTokenizer : FTS5CustomTokenizer {
    static let name = "nfkc"
    let wrappedTokenizer: any FTS5Tokenizer
    
    init(db: Database, arguments: [String]) throws {
        if arguments.isEmpty {
            wrappedTokenizer = try db.makeTokenizer(.unicode61())
        } else {
            wrappedTokenizer = try db.makeTokenizer(FTS5TokenizerDescriptor(components: arguments))
        }
    }
    
    deinit {
        // TODO: test that deinit is called
    }
    
    func tokenize(context: UnsafeMutableRawPointer?, tokenization: FTS5Tokenization, pText: UnsafePointer<CChar>?, nText: Int32, tokenCallback: @escaping FTS5TokenCallback) -> Int32 {
        
        // The way we implement NFKC conversion is by letting wrappedTokenizer
        // do its job, but intercepting its tokens before they feed SQLite.
        //
        // `tokenCallback` is @convention(c). This requires a little setup in
        // order to transfer context.
        struct CustomContext {
            let context: UnsafeMutableRawPointer
            let tokenCallback: FTS5TokenCallback
        }
        var customContext = CustomContext(context: context!, tokenCallback: tokenCallback)
        return withUnsafeMutablePointer(to: &customContext) { customContextPointer in
            // Invoke wrappedTokenizer, but intercept raw tokens
            return wrappedTokenizer.tokenize(context: customContextPointer, tokenization: tokenization, pText: pText, nText: nText) { (customContextPointer, flags, pToken, nToken, iStart, iEnd) in
                // Extract context
                let customContext = customContextPointer!.assumingMemoryBound(to: CustomContext.self).pointee
                
                // Extract token
                guard let token = pToken.flatMap({ String(data: Data(bytesNoCopy: UnsafeMutableRawPointer(mutating: $0), count: Int(nToken), deallocator: .none), encoding: .utf8) }) else {
                    return 0 // SQLITE_OK
                }
                
                // Convert to NFKC
                let nfkc = token.precomposedStringWithCompatibilityMapping
                
                // Notify NFKC token
                return ContiguousArray(nfkc.utf8).withUnsafeBufferPointer { buffer in
                    guard let addr = buffer.baseAddress else {
                        return 0 // SQLITE_OK
                    }
                    let pToken = UnsafeMutableRawPointer(mutating: addr).assumingMemoryBound(to: CChar.self)
                    let nToken = Int32(buffer.count)
                    return customContext.tokenCallback(customContext.context, flags, pToken, nToken, iStart, iEnd)
                }
            }
        }
    }
}

// A custom tokenizer that defines synonyms
private final class SynonymsTokenizer : FTS5CustomTokenizer {
    static let name = "synonyms"
    let wrappedTokenizer: any FTS5Tokenizer
    let synonyms: [Set<String>]
    
    init(db: Database, arguments: [String]) throws {
        if arguments.isEmpty {
            wrappedTokenizer = try db.makeTokenizer(.unicode61())
        } else {
            wrappedTokenizer = try db.makeTokenizer(FTS5TokenizerDescriptor(components: arguments))
        }
        synonyms = [["first", "1st"]]
    }
    
    deinit {
        // TODO: test that deinit is called
    }
    
    func tokenize(context: UnsafeMutableRawPointer?, tokenization: FTS5Tokenization, pText: UnsafePointer<CChar>?, nText: Int32, tokenCallback: @escaping FTS5TokenCallback) -> Int32 {
        // Don't look for synonyms when tokenizing queries, as advised by
        // https://www.sqlite.org/fts5.html#synonym_support
        if tokenization.contains(.query) {
            return wrappedTokenizer.tokenize(context: context, tokenization: tokenization, pText: pText, nText: nText, tokenCallback: tokenCallback)
        }
        
        // The way we implement synonyms support is by letting wrappedTokenizer
        // do its job, but intercepting its tokens before they feed SQLite.
        //
        // `tokenCallback` is @convention(c). This requires a little setup in
        // order to transfer context.
        struct CustomContext {
            let synonyms: [Set<String>]
            let context: UnsafeMutableRawPointer
            let tokenCallback: FTS5TokenCallback
        }
        var customContext = CustomContext(synonyms: synonyms, context: context!, tokenCallback: tokenCallback)
        
        return withUnsafeMutablePointer(to: &customContext) { customContextPointer in
            // Invoke wrappedTokenizer, but intercept raw tokens
            return wrappedTokenizer.tokenize(context: customContextPointer, tokenization: tokenization, pText: pText, nText: nText) { (customContextPointer, flags, pToken, nToken, iStart, iEnd) in
                // Extract context
                let customContext = customContextPointer!.assumingMemoryBound(to: CustomContext.self).pointee
                
                // Extract token
                guard let token = pToken.flatMap({ String(data: Data(bytesNoCopy: UnsafeMutableRawPointer(mutating: $0), count: Int(nToken), deallocator: .none), encoding: .utf8) }) else {
                    return 0 // SQLITE_OK
                }
                
                guard let synonyms = customContext.synonyms.first(where: { $0.contains(token) })?.sorted() else {
                    // No synonym
                    return customContext.tokenCallback(customContext.context, flags, pToken, nToken, iStart, iEnd)
                }
                
                // Notify each synonym
                for (index, synonym) in synonyms.enumerated() {
                    let code = ContiguousArray(synonym.utf8).withUnsafeBufferPointer { buffer -> Int32 in
                        guard let addr = buffer.baseAddress else {
                            return 0 // SQLITE_OK
                        }
                        let pToken = UnsafeMutableRawPointer(mutating: addr).assumingMemoryBound(to: CChar.self)
                        let nToken = Int32(buffer.count)
                        // Set FTS5_TOKEN_COLOCATED for all but first token
                        let synonymFlags = (index == 0) ? flags : flags | 1 // 1: FTS5_TOKEN_COLOCATED
                        return customContext.tokenCallback(customContext.context, synonymFlags, pToken, nToken, iStart, iEnd)
                    }
                    if code != 0 { // SQLITE_OK
                        return code
                    }
                }
                return 0 // SQLITE_OK
            }
        }
    }
}

class FTS5CustomTokenizerTests: GRDBTestCase {
    
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
        let dbPool = try makeDatabasePool()
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
    
    func testStopWordsTokenizer_tokenize() throws {
        try makeDatabaseQueue().inDatabase { db in
            db.add(tokenizer: StopWordsTokenizer.self)
            let tokenizer = try db.makeTokenizer(StopWordsTokenizer.tokenizerDescriptor())
            try XCTAssertEqual(tokenizer.tokenize(query: "foo bar baz").map(\.token), ["foo", "baz"])
        }
    }
    
    func testNFKCTokenizer() throws {
        let dbQueue = try makeDatabaseQueue()
        
        // Without NFKC conversion
        try dbQueue.inDatabase { db in
            db.add(tokenizer: NFKCTokenizer.self)
            try db.create(virtualTable: "documents", using: FTS5()) { t in
                t.tokenizer = .unicode61()
                t.column("content")
            }
            
            try db.execute(sql: "INSERT INTO documents VALUES (?)", arguments: ["aimé\u{FB01}"]) // U+FB01: LATIN SMALL LIGATURE FI
            
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["aimé\u{FB01}"]), 1)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["aimefi"]), 0)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["aim\u{00E9}fi"]), 0)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["aime\u{0301}\u{FB01}"]), 1)
            
            try db.drop(table: "documents")
        }
        
        // With NFKC conversion wrapping unicode61 (the default)
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS5()) { t in
                t.tokenizer = NFKCTokenizer.tokenizerDescriptor()
                t.column("content")
            }
            
            try db.execute(sql: "INSERT INTO documents VALUES (?)", arguments: ["aimé\u{FB01}"]) // U+FB01: LATIN SMALL LIGATURE FI
            
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["aimé\u{FB01}"]), 1)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["aimefi"]), 1)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["aim\u{00E9}fi"]), 1)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["aime\u{0301}\u{FB01}"]), 1)
            
            try db.drop(table: "documents")
        }
        
        // With NFKC conversion wrapping ascii
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS5()) { t in
                let ascii = FTS5TokenizerDescriptor.ascii()
                t.tokenizer = NFKCTokenizer.tokenizerDescriptor(arguments: ascii.components)
                t.column("content")
            }
            
            try db.execute(sql: "INSERT INTO documents VALUES (?)", arguments: ["aimé\u{FB01}"]) // U+FB01: LATIN SMALL LIGATURE FI
            
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["aimé\u{FB01}"]), 1)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["aimefi"]), 0)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["aim\u{00E9}fi"]), 1)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["aime\u{0301}\u{FB01}"]), 1)
            
            try db.drop(table: "documents")
        }
    }
    
    func testNFKCTokenizer_tokenize() throws {
        try makeDatabaseQueue().inDatabase { db in
            db.add(tokenizer: NFKCTokenizer.self)
            let tokenizer = try db.makeTokenizer(NFKCTokenizer.tokenizerDescriptor())
            try XCTAssertEqual(tokenizer.tokenize(query: "foo aimé\u{FB01}").map(\.token), ["foo", "aimefi"]) // U+FB01: LATIN SMALL LIGATURE FI
        }
    }
    
    func testSynonymTokenizer() throws {
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
    
    func testSynonymsTokenizer_tokenize() throws {
        try makeDatabaseQueue().inDatabase { db in
            db.add(tokenizer: SynonymsTokenizer.self)
            let tokenizer = try db.makeTokenizer(SynonymsTokenizer.tokenizerDescriptor())
            
            try XCTAssertEqual(tokenizer.tokenize(query: "foo first 1st").map(\.token), ["foo", "first", "1st"])
            try XCTAssertEqual(tokenizer.tokenize(query: "foo first 1st").map(\.flags), [[], [], []])
            
            try XCTAssertEqual(tokenizer.tokenize(document: "foo first 1st").map(\.token), ["foo", "1st", "first", "1st", "first"])
            try XCTAssertEqual(tokenizer.tokenize(document: "foo first 1st").map(\.flags), [[], [], .colocated, [], .colocated])
        }
    }
}
#endif

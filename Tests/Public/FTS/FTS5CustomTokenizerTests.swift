import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

// A custom tokenizer that ignores some tokens
private final class StopWordsTokenizer : FTS5CustomTokenizer {
    static let name = "stopWords"
    
    let porter: FTS5Tokenizer
    let ignoredTokens: [String]
    
    init(db: Database, arguments: [String]) throws {
        // TODO: test wrapped tokenizer options
        porter = try db.makeTokenizer(.porter())
        // TODO: find a way to provide stop words through arguments
        ignoredTokens = ["bar"]
    }
    
    deinit {
        print("StopWordsTokenizer deinit")
    }
    
    func tokenize(_ context: UnsafeMutableRawPointer?, _ flags: FTS5TokenizeFlags, _ pText: UnsafePointer<Int8>?, _ nText: Int32, _ xToken: FTS5TokenCallback?) -> Int32 {
        
        // The way we implement stop words is by letting porter do its job, but
        // intercepting its tokens before they feed SQLite.
        
        struct WrapperContext {
            let ignoredTokens: [String]
            let context: UnsafeMutableRawPointer
            let xToken: FTS5TokenCallback
        }
        var wrapperContext = WrapperContext(ignoredTokens: ignoredTokens, context: context!, xToken: xToken!)
        
        return withUnsafeMutablePointer(to: &wrapperContext) { wrapperContextPointer in
            // Intercept raw porter tokens, and strip stop words
            return porter.tokenize(wrapperContextPointer, flags, pText, nText) { (wrapperContextPointer, flags, pToken, nToken, iStart, iEnd) in
                // Extract context
                let wrapperContext = wrapperContextPointer!.assumingMemoryBound(to: WrapperContext.self).pointee
                
                // Extract token
                let token = pToken.flatMap {
                    String(data: Data(bytesNoCopy: UnsafeMutableRawPointer(mutating: $0), count: Int(nToken), deallocator: .none), encoding: .utf8)
                }
                
                // Ignore stop words
                if let token = token, wrapperContext.ignoredTokens.contains(token) {
                    return 0 // SQLITE_OK
                }
                
                // Notify token
                return wrapperContext.xToken(wrapperContext.context, flags, pToken, nToken, iStart, iEnd)
            }
        }
    }
}

class FTS5CustomTokenizerTests: GRDBTestCase {
    
    func testDatabaseQueue() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.add(tokenizer: StopWordsTokenizer.self)
            
            try dbQueue.inDatabase { db in
                try db.create(virtualTable: "documents", using: FTS5()) { t in
                    // TODO: improve this API
                    t.tokenizer = StopWordsTokenizer.tokenizer()
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
    
    func testDatabasePool() {
        assertNoError {
            let dbPool = try makeDatabaseQueue()
            dbPool.add(tokenizer: StopWordsTokenizer.self)
            
            try dbPool.write { db in
                try db.create(virtualTable: "documents", using: FTS5()) { t in
                    t.tokenizer = StopWordsTokenizer.tokenizer(arguments: ["foo", "bar"])
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
}

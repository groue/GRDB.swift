import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class FTS5TokenizerTests: GRDBTestCase {
    
    private func match(_ db: Database, _ content: String, _ query: String) -> Bool {
        try! db.execute("INSERT INTO documents VALUES (?)", arguments: [content])
        defer {
            try! db.execute("DELETE FROM documents")
        }
        return Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: [query])! > 0
    }
    
    func testAsciiTokenizer() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(virtualTable: "documents", using: FTS5()) { t in
                    t.tokenizer = .ascii()
                    t.column("content")
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
    }
    
    func testDefaultPorterTokenizer() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(virtualTable: "documents", using: FTS5()) { t in
                    t.tokenizer = .porter()
                    t.column("content")
                }
                
                // simple match
                XCTAssertTrue(match(db, "abcDÉF", "abcDÉF"))
                
                // English stemming
                XCTAssertTrue(match(db, "database", "databases"))
                
                // diacritics in latin characters
                XCTAssertTrue(match(db, "eéÉ", "Èèe"))
                
                // unicode case
                XCTAssertTrue(match(db, "jérôme", "JÉRÔME"))
            }
        }
    }
    
    func testPorterOnAsciiTokenizer() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(virtualTable: "documents", using: FTS5()) { t in
                    t.tokenizer = .porter(wrapping: .ascii())
                    t.column("content")
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
    }
    
    func testPorterOnUnicode61Tokenizer() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(virtualTable: "documents", using: FTS5()) { t in
                    t.tokenizer = .porter(wrapping: .unicode61())
                    t.column("content")
                }
                
                // simple match
                XCTAssertTrue(match(db, "abcDÉF", "abcDÉF"))
                
                // English stemming
                XCTAssertTrue(match(db, "database", "databases"))
                
                // diacritics in latin characters
                XCTAssertTrue(match(db, "eéÉ", "Èèe"))
                
                // unicode case
                XCTAssertTrue(match(db, "jérôme", "JÉRÔME"))
            }
        }
    }
    
    func testUnicode61Tokenizer() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(virtualTable: "documents", using: FTS5()) { t in
                    t.tokenizer = .unicode61()
                    t.column("content")
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
    }
    
    func testUnicode61TokenizerRemoveDiacritics() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(virtualTable: "documents", using: FTS5()) { t in
                    t.tokenizer = .unicode61(removeDiacritics: false)
                    t.column("content")
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
    }
    
    func testUnicode61TokenizerSeparators() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(virtualTable: "documents", using: FTS5()) { t in
                    t.tokenizer = .unicode61(separators: ["X"])
                    t.column("content")
                }
                
                XCTAssertTrue(match(db, "abcXdef", "abcXdef"))
                XCTAssertFalse(match(db, "abcXdef", "defXabc")) // likely a bug in FTS5. FTS3 handles that well.
                XCTAssertTrue(match(db, "abcXdef", "abc"))
                XCTAssertTrue(match(db, "abcXdef", "def"))
            }
        }
    }
    
    func testUnicode61TokenizerTokenCharacters() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(virtualTable: "documents", using: FTS5()) { t in
                    t.tokenizer = .unicode61(tokenCharacters: Set(".-".characters))
                    t.column("content")
                }
                
                XCTAssertTrue(match(db, "2016-10-04.txt", "\"2016-10-04.txt\""))
                XCTAssertFalse(match(db, "2016-10-04.txt", "2016"))
                XCTAssertFalse(match(db, "2016-10-04.txt", "txt"))
            }
        }
    }
}

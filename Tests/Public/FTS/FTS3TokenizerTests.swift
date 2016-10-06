import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class FTS3TokenizerTests: GRDBTestCase {
    
    private func match(_ db: Database, _ content: String, _ query: String) -> Bool {
        try! db.execute("INSERT INTO documents VALUES (?)", arguments: [content])
        defer {
            try! db.execute("DELETE FROM documents")
        }
        return Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: [query])! > 0
    }
    
    func testSimpleTokenizer() {
        assertNoError {
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
    }
    
    func testPorterTokenizer() {
        assertNoError {
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
    }
    
    func testUnicode61Tokenizer() {
        assertNoError {
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
    }
    
    func testUnicode61TokenizerRemoveDiacritics() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(virtualTable: "documents", using: FTS3()) { t in
                    t.tokenizer = .unicode61(removeDiacritics: false)
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
                try db.create(virtualTable: "documents", using: FTS3()) { t in
                    t.tokenizer = .unicode61(separators: ["X"])
                }
                
                XCTAssertTrue(match(db, "abcXdef", "abcXdef"))
                XCTAssertTrue(match(db, "abcXdef", "defXabc"))
                XCTAssertTrue(match(db, "abcXdef", "abc"))
                XCTAssertTrue(match(db, "abcXdef", "def"))
            }
        }
    }
    
    func testUnicode61TokenizerTokenCharacters() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(virtualTable: "documents", using: FTS3()) { t in
                    t.tokenizer = .unicode61(tokenCharacters: Set(".-".characters))
                }
                
                XCTAssertTrue(match(db, "2016-10-04.txt", "2016-10-04.txt"))
                XCTAssertFalse(match(db, "2016-10-04.txt", "2016"))
                XCTAssertFalse(match(db, "2016-10-04.txt", "txt"))
            }
        }
    }
}

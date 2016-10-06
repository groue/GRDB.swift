import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class FTS5TableBuilderTests: GRDBTestCase {
    
    func testWithoutBody() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(virtualTable: "documents", using: FTS5()) { t in
                    t.column("content")
                }
                XCTAssertTrue(sqlQueries.contains("CREATE VIRTUAL TABLE \"documents\" USING fts5(content)"))
                
                try db.execute("INSERT INTO documents VALUES (?)", arguments: ["abc"])
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["abc"])!, 1)
            }
        }
    }
    
    func testOptions() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(virtualTable: "documents", ifNotExists: true, using: FTS5()) { t in
                    t.column("content")
                }
                XCTAssertTrue(sqlQueries.contains("CREATE VIRTUAL TABLE IF NOT EXISTS \"documents\" USING fts5(content)"))
                
                try db.execute("INSERT INTO documents VALUES (?)", arguments: ["abc"])
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["abc"])!, 1)
            }
        }
    }
    
    func testAsciiTokenizer() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(virtualTable: "documents", using: FTS5()) { t in
                    t.tokenizer = .ascii()
                    t.column("content")
                }
                XCTAssertTrue(sqlQueries.contains("CREATE VIRTUAL TABLE \"documents\" USING fts5(content, tokenize='ascii')"))
                
                // simple match
                try db.execute("INSERT INTO documents VALUES (?)", arguments: ["abcDÉF"])
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["abcDÉF"])!, 1)
                try db.execute("DELETE FROM documents")
                
                // English stemming
                try db.execute("INSERT INTO documents VALUES (?)", arguments: ["database"])
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["databases"])!, 0)
                try db.execute("DELETE FROM documents")
                
                // diacritics in latin characters
                try db.execute("INSERT INTO documents VALUES (?)", arguments: ["eéÉ"])
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["Èèe"])!, 0)
                try db.execute("DELETE FROM documents")
                
                // unicode case
                try db.execute("INSERT INTO documents VALUES (?)", arguments: ["jérôme"])
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["JÉRÔME"])!, 0)
                try db.execute("DELETE FROM documents")
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
                XCTAssertTrue(sqlQueries.contains("CREATE VIRTUAL TABLE \"documents\" USING fts5(content, tokenize='porter')"))
                
                // simple match
                try db.execute("INSERT INTO documents VALUES (?)", arguments: ["abcDÉF"])
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["abcDÉF"])!, 1)
                try db.execute("DELETE FROM documents")
                
                // English stemming
                try db.execute("INSERT INTO documents VALUES (?)", arguments: ["database"])
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["databases"])!, 1)
                try db.execute("DELETE FROM documents")
                
                // diacritics in latin characters
                try db.execute("INSERT INTO documents VALUES (?)", arguments: ["eéÉ"])
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["Èèe"])!, 1)
                try db.execute("DELETE FROM documents")
                
                // unicode case
                try db.execute("INSERT INTO documents VALUES (?)", arguments: ["jérôme"])
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["JÉRÔME"])!, 1)
                try db.execute("DELETE FROM documents")
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
                XCTAssertTrue(sqlQueries.contains("CREATE VIRTUAL TABLE \"documents\" USING fts5(content, tokenize='porter ascii')"))
                
                // simple match
                try db.execute("INSERT INTO documents VALUES (?)", arguments: ["abcDÉF"])
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["abcDÉF"])!, 1)
                try db.execute("DELETE FROM documents")
                
                // English stemming
                try db.execute("INSERT INTO documents VALUES (?)", arguments: ["database"])
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["databases"])!, 1)
                try db.execute("DELETE FROM documents")
                
                // diacritics in latin characters
                try db.execute("INSERT INTO documents VALUES (?)", arguments: ["eéÉ"])
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["Èèe"])!, 0)
                try db.execute("DELETE FROM documents")
                
                // unicode case
                try db.execute("INSERT INTO documents VALUES (?)", arguments: ["jérôme"])
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["JÉRÔME"])!, 0)
                try db.execute("DELETE FROM documents")
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
                XCTAssertTrue(sqlQueries.contains("CREATE VIRTUAL TABLE \"documents\" USING fts5(content, tokenize='porter unicode61')"))
                
                // simple match
                try db.execute("INSERT INTO documents VALUES (?)", arguments: ["abcDÉF"])
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["abcDÉF"])!, 1)
                try db.execute("DELETE FROM documents")
                
                // English stemming
                try db.execute("INSERT INTO documents VALUES (?)", arguments: ["database"])
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["databases"])!, 1)
                try db.execute("DELETE FROM documents")
                
                // diacritics in latin characters
                try db.execute("INSERT INTO documents VALUES (?)", arguments: ["eéÉ"])
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["Èèe"])!, 1)
                try db.execute("DELETE FROM documents")
                
                // unicode case
                try db.execute("INSERT INTO documents VALUES (?)", arguments: ["jérôme"])
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["JÉRÔME"])!, 1)
                try db.execute("DELETE FROM documents")
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
                XCTAssertTrue(sqlQueries.contains("CREATE VIRTUAL TABLE \"documents\" USING fts5(content, tokenize='unicode61')"))
                
                // simple match
                try db.execute("INSERT INTO documents VALUES (?)", arguments: ["abcDÉF"])
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["abcDÉF"])!, 1)
                try db.execute("DELETE FROM documents")
                
                // English stemming
                try db.execute("INSERT INTO documents VALUES (?)", arguments: ["database"])
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["databases"])!, 0)
                try db.execute("DELETE FROM documents")
                
                // diacritics in latin characters
                try db.execute("INSERT INTO documents VALUES (?)", arguments: ["eéÉ"])
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["Èèe"])!, 1)
                try db.execute("DELETE FROM documents")
                
                // unicode case
                try db.execute("INSERT INTO documents VALUES (?)", arguments: ["jérôme"])
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["JÉRÔME"])!, 1)
                try db.execute("DELETE FROM documents")
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
                XCTAssertTrue(sqlQueries.contains("CREATE VIRTUAL TABLE \"documents\" USING fts5(content, tokenize='unicode61 remove_diacritics 0')"))
                
                // simple match
                try db.execute("INSERT INTO documents VALUES (?)", arguments: ["abcDÉF"])
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["abcDÉF"])!, 1)
                try db.execute("DELETE FROM documents")
                
                // English stemming
                try db.execute("INSERT INTO documents VALUES (?)", arguments: ["database"])
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["databases"])!, 0)
                try db.execute("DELETE FROM documents")
                
                // diacritics in latin characters
                try db.execute("INSERT INTO documents VALUES (?)", arguments: ["eéÉ"])
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["Èèe"])!, 0)
                try db.execute("DELETE FROM documents")
                
                // unicode case
                try db.execute("INSERT INTO documents VALUES (?)", arguments: ["jérôme"])
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["JÉRÔME"])!, 1)
                try db.execute("DELETE FROM documents")
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
                XCTAssertTrue(sqlQueries.contains("CREATE VIRTUAL TABLE \"documents\" USING fts5(content, tokenize='unicode61 separators ''X''')"))
                
                try db.execute("INSERT INTO documents VALUES (?)", arguments: ["abcXdef"])
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["abcXdef"])!, 1)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["abc"])!, 1)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["def"])!, 1)
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
                XCTAssertTrue(sqlQueries.contains("CREATE VIRTUAL TABLE \"documents\" USING fts5(content, tokenize='unicode61 tokenchars ''.-''')") || sqlQueries.contains("CREATE VIRTUAL TABLE \"documents\" USING fts5(content, tokenize='unicode61 tokenchars ''-.''')"))
                
                try db.execute("INSERT INTO documents VALUES (?)", arguments: ["2016-10-04.txt"])
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["\"2016-10-04.txt\""])!, 1)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["2016"])!, 0)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["txt"])!, 0)
            }
        }
    }
    
    func testColumns() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(virtualTable: "books", using: FTS5()) { t in
                    t.column("author")
                    t.column("title")
                    t.column("body")
                }
                XCTAssertTrue(sqlQueries.contains("CREATE VIRTUAL TABLE \"books\" USING fts5(author, title, body)"))
                
                try db.execute("INSERT INTO books VALUES (?, ?, ?)", arguments: ["Melville", "Moby Dick", "Call me Ishmael."])
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: ["Melville"])!, 1)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: ["title:Melville"])!, 0)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: ["author:Melville"])!, 1)
            }
        }
    }
}

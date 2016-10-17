import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class FTS4TableBuilderTests: GRDBTestCase {
    
    override func setUp() {
        super.setUp()
        
        dbConfiguration.trace = { [unowned self] sql in
            // Ignore virtual table logs
            if !sql.hasPrefix("--") {
                self.sqlQueries.append(sql)
            }
        }
    }
    
    func testWithoutBody() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(virtualTable: "documents", using: FTS4())
                assertDidExecute(sql: "CREATE VIRTUAL TABLE \"documents\" USING fts4")
                
                try db.execute("INSERT INTO documents VALUES (?)", arguments: ["abc"])
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["abc"])!, 1)
            }
        }
    }
    
    func testOptions() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(virtualTable: "documents", ifNotExists: true, using: FTS4())
                assertDidExecute(sql: "CREATE VIRTUAL TABLE IF NOT EXISTS \"documents\" USING fts4")
                
                try db.execute("INSERT INTO documents VALUES (?)", arguments: ["abc"])
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["abc"])!, 1)
            }
        }
    }
    
    func testSimpleTokenizer() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(virtualTable: "documents", using: FTS4()) { t in
                    t.tokenizer = .simple
                }
                assertDidExecute(sql: "CREATE VIRTUAL TABLE \"documents\" USING fts4(tokenize=simple)")
            }
        }
    }
    
    func testPorterTokenizer() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(virtualTable: "documents", using: FTS4()) { t in
                    t.tokenizer = .porter
                }
                assertDidExecute(sql: "CREATE VIRTUAL TABLE \"documents\" USING fts4(tokenize=porter)")
            }
        }
    }
    
    func testUnicode61Tokenizer() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(virtualTable: "documents", using: FTS4()) { t in
                    t.tokenizer = .unicode61()
                }
                assertDidExecute(sql: "CREATE VIRTUAL TABLE \"documents\" USING fts4(tokenize=unicode61)")
            }
        }
    }
    
    func testUnicode61TokenizerRemoveDiacritics() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(virtualTable: "documents", using: FTS4()) { t in
                    t.tokenizer = .unicode61(removeDiacritics: false)
                }
                assertDidExecute(sql: "CREATE VIRTUAL TABLE \"documents\" USING fts4(tokenize=unicode61 \"remove_diacritics=0\")")
            }
        }
    }
    
    func testUnicode61TokenizerSeparators() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(virtualTable: "documents", using: FTS4()) { t in
                    t.tokenizer = .unicode61(separators: ["X"])
                }
                assertDidExecute(sql: "CREATE VIRTUAL TABLE \"documents\" USING fts4(tokenize=unicode61 \"separators=X\")")
            }
        }
    }
    
    func testUnicode61TokenizerTokenCharacters() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(virtualTable: "documents", using: FTS4()) { t in
                    t.tokenizer = .unicode61(tokenCharacters: Set(".-".characters))
                }
                assertDidExecute(sql: "CREATE VIRTUAL TABLE \"documents\" USING fts4(tokenize=unicode61 \"tokenchars=-.\")")
            }
        }
    }
    
    func testColumns() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(virtualTable: "books", using: FTS4()) { t in
                    t.column("author")
                    t.column("title")
                    t.column("body")
                }
                assertDidExecute(sql: "CREATE VIRTUAL TABLE \"books\" USING fts4(author, title, body)")
                
                try db.execute("INSERT INTO books VALUES (?, ?, ?)", arguments: ["Melville", "Moby Dick", "Call me Ishmael."])
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: ["Melville"])!, 1)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: ["title:Melville"])!, 0)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM books WHERE title MATCH ?", arguments: ["Melville"])!, 0)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: ["author:Melville"])!, 1)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM books WHERE author MATCH ?", arguments: ["Melville"])!, 1)
            }
        }
    }
    
    func testNotIndexedColumns() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(virtualTable: "books", using: FTS4()) { t in
                    t.column("author").notIndexed()
                    t.column("title")
                    t.column("body").notIndexed()
                }
                assertDidExecute(sql: "CREATE VIRTUAL TABLE \"books\" USING fts4(author, notindexed=author, title, body, notindexed=body)")
                
                try db.execute("INSERT INTO books VALUES (?, ?, ?)", arguments: ["Melville", "Moby Dick", "Call me Ishmael."])
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: ["Dick"])!, 1)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: ["title:Dick"])!, 1)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM books WHERE title MATCH ?", arguments: ["Dick"])!, 1)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: ["author:Dick"])!, 0)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM books WHERE author MATCH ?", arguments: ["Dick"])!, 0)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: ["Melville"])!, 0)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: ["title:Melville"])!, 0)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM books WHERE title MATCH ?", arguments: ["Melville"])!, 0)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: ["author:Melville"])!, 0)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM books WHERE author MATCH ?", arguments: ["Melville"])!, 0)
            }
        }
    }
    
    func testFTS4Options() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(virtualTable: "documents", using: FTS4()) { t in
                    t.content = ""
                    t.compress = "zip"
                    t.uncompress = "unzip"
                    t.matchinfo = "fts3"
                    t.prefixes = [2, 4]
                    t.column("content")
                    t.column("lid").asLanguageId()
                }
                print(sqlQueries)
                assertDidExecute(sql: "CREATE VIRTUAL TABLE \"documents\" USING fts4(content, languageid=\"lid\", content=\"\", compress=\"zip\", uncompress=\"unzip\", matchinfo=\"fts3\", prefix=\"2,4\")")
                
                try db.execute("INSERT INTO documents (docid, content, lid) VALUES (?, ?, ?)", arguments: [1, "abc", 0])
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ? AND lid=0", arguments: ["abc"])!, 1)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ? AND lid=1", arguments: ["abc"])!, 0)
            }
        }
    }
    
    func testFTS5Synchronization() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(table: "documents") { t in
                    t.column("id", .integer).primaryKey()
                    t.column("content", .text)
                }
                try db.execute("INSERT INTO documents (content) VALUES (?)", arguments: ["foo"])
                try db.create(virtualTable: "ft_documents", using: FTS4()) { t in
                    t.synchronize(withTable: "documents")
                    t.column("content")
                }
                
                // Prepopulated
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM ft_documents WHERE ft_documents MATCH ?", arguments: ["foo"])!, 1)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM ft_documents WHERE ft_documents MATCH ?", arguments: ["bar"])!, 0)
                
                // Synchronized on update
                try db.execute("UPDATE documents SET content = ?", arguments: ["bar"])
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM ft_documents WHERE ft_documents MATCH ?", arguments: ["foo"])!, 0)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM ft_documents WHERE ft_documents MATCH ?", arguments: ["bar"])!, 1)
                
                // Synchronized on insert
                try db.execute("INSERT INTO documents (content) VALUES (?)", arguments: ["foo"])
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM ft_documents WHERE ft_documents MATCH ?", arguments: ["foo"])!, 1)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM ft_documents WHERE ft_documents MATCH ?", arguments: ["bar"])!, 1)
                
                // Synchronized on delete
                try db.execute("DELETE FROM documents WHERE content = ?", arguments: ["foo"])
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM ft_documents WHERE ft_documents MATCH ?", arguments: ["foo"])!, 0)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM ft_documents WHERE ft_documents MATCH ?", arguments: ["bar"])!, 1)
            }
        }
    }
}

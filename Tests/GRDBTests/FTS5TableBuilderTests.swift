#if SQLITE_ENABLE_FTS5
import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

/// sourcery: disableTests
class FTS5TableBuilderTests: GRDBTestCase {
    
    override func setUp() {
        super.setUp()
        
        dbConfiguration.trace = { [unowned self] sql in
            // Ignore virtual table logs
            if !sql.hasPrefix("--") {
                self.sqlQueries.append(sql)
            }
        }
    }
    
    func testWithoutBody() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS5()) { t in
                t.column("content")
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE \"documents\" USING fts5(content)")
            
            try db.execute("INSERT INTO documents VALUES (?)", arguments: ["abc"])
            XCTAssertEqual(try Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["abc"])!, 1)
        }
    }

    func testOptions() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", ifNotExists: true, using: FTS5()) { t in
                t.column("content")
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE IF NOT EXISTS \"documents\" USING fts5(content)")
            
            try db.execute("INSERT INTO documents VALUES (?)", arguments: ["abc"])
            XCTAssertEqual(try Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["abc"])!, 1)
        }
    }

    func testAsciiTokenizer() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS5()) { t in
                t.tokenizer = .ascii()
                t.column("content")
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE \"documents\" USING fts5(content, tokenize='ascii')")
        }
    }

    func testDefaultPorterTokenizer() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS5()) { t in
                t.tokenizer = .porter()
                t.column("content")
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE \"documents\" USING fts5(content, tokenize='porter')")
        }
    }

    func testPorterOnAsciiTokenizer() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS5()) { t in
                t.tokenizer = .porter(wrapping: .ascii())
                t.column("content")
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE \"documents\" USING fts5(content, tokenize='porter ascii')")
        }
    }

    func testPorterOnUnicode61Tokenizer() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS5()) { t in
                t.tokenizer = .porter(wrapping: .unicode61())
                t.column("content")
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE \"documents\" USING fts5(content, tokenize='porter unicode61')")
        }
    }

    func testUnicode61Tokenizer() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS5()) { t in
                t.tokenizer = .unicode61()
                t.column("content")
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE \"documents\" USING fts5(content, tokenize='unicode61')")
        }
    }

    func testUnicode61TokenizerRemoveDiacritics() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS5()) { t in
                t.tokenizer = .unicode61(removeDiacritics: false)
                t.column("content")
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE \"documents\" USING fts5(content, tokenize='unicode61 remove_diacritics 0')")
        }
    }

    func testUnicode61TokenizerSeparators() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS5()) { t in
                t.tokenizer = .unicode61(separators: ["X"])
                t.column("content")
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE \"documents\" USING fts5(content, tokenize='unicode61 separators ''X''')")
        }
    }

    func testUnicode61TokenizerTokenCharacters() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS5()) { t in
                t.tokenizer = .unicode61(tokenCharacters: Set(".-".characters))
                t.column("content")
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE \"documents\" USING fts5(content, tokenize='unicode61 tokenchars ''-.''')")
        }
    }

    func testColumns() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "books", using: FTS5()) { t in
                t.column("author")
                t.column("title")
                t.column("body")
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE \"books\" USING fts5(author, title, body)")
            
            try db.execute("INSERT INTO books VALUES (?, ?, ?)", arguments: ["Melville", "Moby Dick", "Call me Ishmael."])
            XCTAssertEqual(try Int.fetchOne(db, "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: ["Melville"])!, 1)
            XCTAssertEqual(try Int.fetchOne(db, "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: ["title:Melville"])!, 0)
            XCTAssertEqual(try Int.fetchOne(db, "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: ["author:Melville"])!, 1)
        }
    }

    func testNotIndexedColumns() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "books", using: FTS5()) { t in
                t.column("author").notIndexed()
                t.column("title")
                t.column("body").notIndexed()
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE \"books\" USING fts5(author UNINDEXED, title, body UNINDEXED)")
            
            try db.execute("INSERT INTO books VALUES (?, ?, ?)", arguments: ["Melville", "Moby Dick", "Call me Ishmael."])
            XCTAssertEqual(try Int.fetchOne(db, "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: ["Dick"])!, 1)
            XCTAssertEqual(try Int.fetchOne(db, "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: ["title:Dick"])!, 1)
            XCTAssertEqual(try Int.fetchOne(db, "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: ["author:Dick"])!, 0)
            XCTAssertEqual(try Int.fetchOne(db, "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: ["Melville"])!, 0)
            XCTAssertEqual(try Int.fetchOne(db, "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: ["title:Melville"])!, 0)
            XCTAssertEqual(try Int.fetchOne(db, "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: ["author:Melville"])!, 0)
        }
    }

    func testFTS5Options() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS5()) { t in
                t.content = ""
                t.prefixes = [2, 4]
                t.columnSize = 0
                t.detail = "column"
                t.column("content")
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE \"documents\" USING fts5(content, content='', prefix='2 4', columnSize=0, detail=column)")
        }
    }

    func testFTS5Synchronization() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "documents") { t in
                t.column("id", .integer).primaryKey()
                t.column("content", .text)
            }
            try db.execute("INSERT INTO documents (content) VALUES (?)", arguments: ["foo"])
            try db.create(virtualTable: "ft_documents", using: FTS5()) { t in
                t.synchronize(withTable: "documents")
                t.column("content")
            }
            
            // Prepopulated
            XCTAssertEqual(try Int.fetchOne(db, "SELECT COUNT(*) FROM ft_documents WHERE ft_documents MATCH ?", arguments: ["foo"])!, 1)
            XCTAssertEqual(try Int.fetchOne(db, "SELECT COUNT(*) FROM ft_documents WHERE ft_documents MATCH ?", arguments: ["bar"])!, 0)
            
            // Synchronized on update
            try db.execute("UPDATE documents SET content = ?", arguments: ["bar"])
            XCTAssertEqual(try Int.fetchOne(db, "SELECT COUNT(*) FROM ft_documents WHERE ft_documents MATCH ?", arguments: ["foo"])!, 0)
            XCTAssertEqual(try Int.fetchOne(db, "SELECT COUNT(*) FROM ft_documents WHERE ft_documents MATCH ?", arguments: ["bar"])!, 1)
            
            // Synchronized on insert
            try db.execute("INSERT INTO documents (content) VALUES (?)", arguments: ["foo"])
            XCTAssertEqual(try Int.fetchOne(db, "SELECT COUNT(*) FROM ft_documents WHERE ft_documents MATCH ?", arguments: ["foo"])!, 1)
            XCTAssertEqual(try Int.fetchOne(db, "SELECT COUNT(*) FROM ft_documents WHERE ft_documents MATCH ?", arguments: ["bar"])!, 1)
            
            // Synchronized on delete
            try db.execute("DELETE FROM documents WHERE content = ?", arguments: ["foo"])
            XCTAssertEqual(try Int.fetchOne(db, "SELECT COUNT(*) FROM ft_documents WHERE ft_documents MATCH ?", arguments: ["foo"])!, 0)
            XCTAssertEqual(try Int.fetchOne(db, "SELECT COUNT(*) FROM ft_documents WHERE ft_documents MATCH ?", arguments: ["bar"])!, 1)
        }
    }
}
#endif

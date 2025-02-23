#if SQLITE_ENABLE_FTS5
import XCTest
import GRDB

class FTS5TableBuilderTests: GRDBTestCase {
    func testWithoutBody() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS5()) { t in
                t.column("content")
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE \"documents\" USING fts5(content)")
            
            try db.execute(sql: "INSERT INTO documents VALUES (?)", arguments: ["abc"])
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["abc"])!, 1)
        }
    }

    func test_option_ifNotExists() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", options: .ifNotExists, using: FTS5()) { t in
                t.column("content")
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE IF NOT EXISTS \"documents\" USING fts5(content)")
            
            try db.execute(sql: "INSERT INTO documents VALUES (?)", arguments: ["abc"])
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["abc"])!, 1)
        }
    }

    func test_option_temporary() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", options: .temporary, using: FTS5()) { t in
                t.column("content")
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE temp.\"documents\" USING fts5(content)")
            
            try db.execute(sql: "INSERT INTO documents VALUES (?)", arguments: ["abc"])
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["abc"])!, 1)
        }
    }

    func testLegacyOptions() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", ifNotExists: true, using: FTS5()) { t in
                t.column("content")
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE IF NOT EXISTS \"documents\" USING fts5(content)")
            
            try db.execute(sql: "INSERT INTO documents VALUES (?)", arguments: ["abc"])
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["abc"])!, 1)
        }
    }

    func testAsciiTokenizer() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS5()) { t in
                t.tokenizer = .ascii()
                t.column("content")
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE \"documents\" USING fts5(content, tokenize='''ascii''')")
        }
    }

    func testAsciiTokenizerSeparators() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS5()) { t in
                t.tokenizer = .ascii(separators: ["X"])
                t.column("content")
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE \"documents\" USING fts5(content, tokenize='''ascii'' ''separators'' ''X''')")
        }
    }

    func testAsciiTokenizerTokenCharacters() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS5()) { t in
                t.tokenizer = .ascii(tokenCharacters: Set(".-"))
                t.column("content")
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE \"documents\" USING fts5(content, tokenize='''ascii'' ''tokenchars'' ''-.''')")
        }
    }

    func testDefaultPorterTokenizer() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS5()) { t in
                t.tokenizer = .porter()
                t.column("content")
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE \"documents\" USING fts5(content, tokenize='''porter''')")
        }
    }

    func testPorterOnAsciiTokenizer() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS5()) { t in
                t.tokenizer = .porter(wrapping: .ascii())
                t.column("content")
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE \"documents\" USING fts5(content, tokenize='''porter'' ''ascii''')")
        }
    }

    func testPorterOnUnicode61Tokenizer() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS5()) { t in
                t.tokenizer = .porter(wrapping: .unicode61())
                t.column("content")
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE \"documents\" USING fts5(content, tokenize='''porter'' ''unicode61''')")
        }
    }

    func testUnicode61Tokenizer() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS5()) { t in
                t.tokenizer = .unicode61()
                t.column("content")
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE \"documents\" USING fts5(content, tokenize='''unicode61''')")
        }
    }

    func testUnicode61TokenizerDiacriticsKeep() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS5()) { t in
                t.tokenizer = .unicode61(diacritics: .keep)
                t.column("content")
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE \"documents\" USING fts5(content, tokenize='''unicode61'' ''remove_diacritics'' ''0''')")
        }
    }

    #if GRDBCUSTOMSQLITE
    func testUnicode61TokenizerDiacriticsRemove() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS5()) { t in
                t.tokenizer = .unicode61(diacritics: .remove)
                t.column("content")
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE \"documents\" USING fts5(content, tokenize='''unicode61'' ''remove_diacritics'' ''2''')")
        }
    }
    #elseif !GRDBCIPHER
    func testUnicode61TokenizerDiacriticsRemove() throws {
        guard #available(iOS 14, macOS 10.16, tvOS 14, *) else {
            throw XCTSkip()
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS5()) { t in
                t.tokenizer = .unicode61(diacritics: .remove)
                t.column("content")
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE \"documents\" USING fts5(content, tokenize='''unicode61'' ''remove_diacritics'' ''2''')")
        }
    }
    #endif

    func testUnicode61TokenizerSeparators() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS5()) { t in
                t.tokenizer = .unicode61(separators: ["X"])
                t.column("content")
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE \"documents\" USING fts5(content, tokenize='''unicode61'' ''separators'' ''X''')")
        }
    }

    func testUnicode61TokenizerTokenCharacters() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS5()) { t in
                t.tokenizer = .unicode61(tokenCharacters: Set(".-"))
                t.column("content")
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE \"documents\" USING fts5(content, tokenize='''unicode61'' ''tokenchars'' ''-.''')")
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
            
            try db.execute(sql: "INSERT INTO books VALUES (?, ?, ?)", arguments: ["Melville", "Moby Dick", "Call me Ishmael."])
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: ["Melville"])!, 1)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: ["title:Melville"])!, 0)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: ["author:Melville"])!, 1)
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
            
            try db.execute(sql: "INSERT INTO books VALUES (?, ?, ?)", arguments: ["Melville", "Moby Dick", "Call me Ishmael."])
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: ["Dick"])!, 1)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: ["title:Dick"])!, 1)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: ["author:Dick"])!, 0)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: ["Melville"])!, 0)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: ["title:Melville"])!, 0)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: ["author:Melville"])!, 0)
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
                t.primaryKey("id", .integer)
                t.column("content", .text)
            }
            try db.execute(sql: "INSERT INTO documents (content) VALUES (?)", arguments: ["foo"])
            try db.create(virtualTable: "ft_documents", using: FTS5()) { t in
                t.synchronize(withTable: "documents")
                t.column("content")
            }
            
            // Prepopulated
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM ft_documents WHERE ft_documents MATCH ?", arguments: ["foo"])!, 1)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM ft_documents WHERE ft_documents MATCH ?", arguments: ["bar"])!, 0)
            
            // Synchronized on update
            try db.execute(sql: "UPDATE documents SET content = ?", arguments: ["bar"])
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM ft_documents WHERE ft_documents MATCH ?", arguments: ["foo"])!, 0)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM ft_documents WHERE ft_documents MATCH ?", arguments: ["bar"])!, 1)
            
            // Synchronized on insert
            try db.execute(sql: "INSERT INTO documents (content) VALUES (?)", arguments: ["foo"])
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM ft_documents WHERE ft_documents MATCH ?", arguments: ["foo"])!, 1)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM ft_documents WHERE ft_documents MATCH ?", arguments: ["bar"])!, 1)
            
            // Synchronized on delete
            try db.execute(sql: "DELETE FROM documents WHERE content = ?", arguments: ["foo"])
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM ft_documents WHERE ft_documents MATCH ?", arguments: ["foo"])!, 0)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM ft_documents WHERE ft_documents MATCH ?", arguments: ["bar"])!, 1)
        }
    }
    
    func testFTS5Synchronization_with_ifNotExists_option() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.writeWithoutTransaction { db in
            try db.create(table: "documents") { t in
                t.primaryKey("id", .integer)
                t.column("content", .text)
            }
            assertDidExecute(sql: "CREATE TABLE \"documents\" (\"id\" INTEGER PRIMARY KEY, \"content\" TEXT)")
            try db.create(virtualTable: "ft_documents", options: .ifNotExists, using: FTS5()) { t in
                t.synchronize(withTable: "documents")
                t.column("content")
            }
            
            assertDidExecute(sql: """
                CREATE VIRTUAL TABLE IF NOT EXISTS "ft_documents" USING fts5(content, content='documents', content_rowid='id')
                """)
            assertDidExecute(sql: """
                CREATE TRIGGER IF NOT EXISTS "__ft_documents_ai" AFTER INSERT ON "documents" BEGIN
                    INSERT INTO "ft_documents"("rowid", "content") VALUES (new."id", new."content");
                END
                """)
        }
    }
    
    func testFTS5SynchronizationCleanup() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "documents") { t in
                t.primaryKey("id", .integer)
                t.column("content", .text)
            }
            try db.execute(sql: "INSERT INTO documents (content) VALUES (?)", arguments: ["foo"])
            try db.create(virtualTable: "ft_documents", using: FTS5()) { t in
                t.synchronize(withTable: "documents")
                t.column("content")
            }
            
            try db.drop(table: "ft_documents")
            try db.dropFTS5SynchronizationTriggers(forTable: "ft_documents")
            
            // It is possible to modify the content table
            try db.execute(sql: "UPDATE documents SET content = ?", arguments: ["bar"])
            try db.execute(sql: "INSERT INTO documents (content) VALUES (?)", arguments: ["foo"])
            try db.execute(sql: "DELETE FROM documents WHERE content = ?", arguments: ["foo"])
            
            // It is possible to recreate the FT table
            try db.create(virtualTable: "ft_documents", using: FTS5()) { t in
                t.synchronize(withTable: "documents")
                t.column("content")
            }
        }
    }

    func testFTS5SynchronizationCleanupWithLegacySupport() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "documents") { t in
                t.primaryKey("id", .integer)
                t.column("content", .text)
            }
            try db.execute(sql: "INSERT INTO documents (content) VALUES (?)", arguments: ["foo"])
            try db.create(virtualTable: "ft_documents", using: FTS5()) { t in
                t.synchronize(withTable: "documents")
                t.column("content")
            }
            
            try db.drop(table: "ft_documents")
            try db.dropFTS5SynchronizationTriggers(forTable: "documents") // legacy GRDB <= 2.3.1
            try db.dropFTS5SynchronizationTriggers(forTable: "ft_documents")
            
            // It is possible to modify the content table
            try db.execute(sql: "UPDATE documents SET content = ?", arguments: ["bar"])
            try db.execute(sql: "INSERT INTO documents (content) VALUES (?)", arguments: ["foo"])
            try db.execute(sql: "DELETE FROM documents WHERE content = ?", arguments: ["foo"])
            
            // It is possible to recreate the FT table
            try db.create(virtualTable: "ft_documents", using: FTS5()) { t in
                t.synchronize(withTable: "documents")
                t.column("content")
            }
        }
    }
    
    // Regression test for <https://github.com/groue/GRDB.swift/issues/1390>
    func testIssue1390() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        guard Database.sqliteLibVersionNumber >= 3035000 else {
            throw XCTSkip("UPSERT is not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("UPSERT is not available")
        }
#endif
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            struct Content: Codable, Hashable, PersistableRecord {
                var id: String
                var text: String
            }
            
            try db.create(table: "content") { t in
                t.primaryKey("id", .text)
                t.column("text", .text)
            }

            try db.create(virtualTable: "fts", using: FTS5()) { t in
                t.tokenizer = .porter()
                t.synchronize(withTable: "content")
                t.column("id").notIndexed()
                t.column("text")
            }
            
            try db.inTransaction {
                try Content(id: "foobar", text: "baz").upsert(db)
                return .commit
            }
        }
    }
}
#endif

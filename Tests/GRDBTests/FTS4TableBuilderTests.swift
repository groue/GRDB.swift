import XCTest
#if GRDBCUSTOMSQLITE
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
    
    func testWithoutBody() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS4())
            assertDidExecute(sql: "CREATE VIRTUAL TABLE \"documents\" USING fts4")
            
            try db.execute(sql: "INSERT INTO documents VALUES (?)", arguments: ["abc"])
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["abc"])!, 1)
        }
    }

    func testOptions() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", ifNotExists: true, using: FTS4())
            assertDidExecute(sql: "CREATE VIRTUAL TABLE IF NOT EXISTS \"documents\" USING fts4")
            
            try db.execute(sql: "INSERT INTO documents VALUES (?)", arguments: ["abc"])
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["abc"])!, 1)
        }
    }

    func testSimpleTokenizer() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS4()) { t in
                t.tokenizer = .simple
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE \"documents\" USING fts4(tokenize=simple)")
        }
    }

    func testPorterTokenizer() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS4()) { t in
                t.tokenizer = .porter
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE \"documents\" USING fts4(tokenize=porter)")
        }
    }

    func testUnicode61Tokenizer() throws {
        #if !GRDBCUSTOMSQLITE && !GRDBCIPHER
            guard #available(iOS 8.2, OSX 10.10, *) else {
                return
            }
        #endif
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS4()) { t in
                t.tokenizer = .unicode61()
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE \"documents\" USING fts4(tokenize=unicode61)")
        }
    }

    func testUnicode61TokenizerDiacriticsKeep() throws {
        #if !GRDBCUSTOMSQLITE && !GRDBCIPHER
            guard #available(iOS 8.2, OSX 10.10, *) else {
                return
            }
        #endif
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS4()) { t in
                t.tokenizer = .unicode61(diacritics: .keep)
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE \"documents\" USING fts4(tokenize=unicode61 \"remove_diacritics=0\")")
        }
    }
    
    #if GRDBCUSTOMSQLITE
    func testUnicode61TokenizerDiacriticsRemove() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS4()) { t in
                t.tokenizer = .unicode61(diacritics: .remove)
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE \"documents\" USING fts4(tokenize=unicode61 \"remove_diacritics=2\")")
        }
    }
    #endif

    func testUnicode61TokenizerSeparators() throws {
        #if !GRDBCUSTOMSQLITE && !GRDBCIPHER
            guard #available(iOS 8.2, OSX 10.10, *) else {
                return
            }
        #endif
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS4()) { t in
                t.tokenizer = .unicode61(separators: ["X"])
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE \"documents\" USING fts4(tokenize=unicode61 \"separators=X\")")
        }
    }

    func testUnicode61TokenizerTokenCharacters() throws {
        #if !GRDBCUSTOMSQLITE && !GRDBCIPHER
            guard #available(iOS 8.2, OSX 10.10, *) else {
                return
            }
        #endif
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS4()) { t in
                t.tokenizer = .unicode61(tokenCharacters: Set(".-"))
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE \"documents\" USING fts4(tokenize=unicode61 \"tokenchars=-.\")")
        }
    }

    func testColumns() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "books", using: FTS4()) { t in
                t.column("author")
                t.column("title")
                t.column("body")
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE \"books\" USING fts4(author, title, body)")
            
            try db.execute(sql: "INSERT INTO books VALUES (?, ?, ?)", arguments: ["Melville", "Moby Dick", "Call me Ishmael."])
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: ["Melville"])!, 1)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: ["title:Melville"])!, 0)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM books WHERE title MATCH ?", arguments: ["Melville"])!, 0)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: ["author:Melville"])!, 1)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM books WHERE author MATCH ?", arguments: ["Melville"])!, 1)
        }
    }

    func testNotIndexedColumns() throws {
        #if !GRDBCUSTOMSQLITE && !GRDBCIPHER
            guard #available(iOS 8.2, OSX 10.10, *) else {
                return
            }
        #endif
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "books", using: FTS4()) { t in
                t.column("author").notIndexed()
                t.column("title")
                t.column("body").notIndexed()
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE \"books\" USING fts4(author, notindexed=author, title, body, notindexed=body)")
            
            try db.execute(sql: "INSERT INTO books VALUES (?, ?, ?)", arguments: ["Melville", "Moby Dick", "Call me Ishmael."])
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: ["Dick"])!, 1)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: ["title:Dick"])!, 1)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM books WHERE title MATCH ?", arguments: ["Dick"])!, 1)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: ["author:Dick"])!, 0)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM books WHERE author MATCH ?", arguments: ["Dick"])!, 0)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: ["Melville"])!, 0)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: ["title:Melville"])!, 0)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM books WHERE title MATCH ?", arguments: ["Melville"])!, 0)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: ["author:Melville"])!, 0)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM books WHERE author MATCH ?", arguments: ["Melville"])!, 0)
        }
    }

    func testFTS4Options() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.writeWithoutTransaction { db in
            try db.create(virtualTable: "documents", using: FTS4()) { t in
                t.content = ""
                t.compress = "zip"
                t.uncompress = "unzip"
                t.matchinfo = "fts3"
                t.prefixes = [2, 4]
                t.column("content")
                t.column("lid").asLanguageId()
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE \"documents\" USING fts4(content, languageid=\"lid\", content=\"\", compress=\"zip\", uncompress=\"unzip\", matchinfo=\"fts3\", prefix=\"2,4\")")
            
            try db.execute(sql: "INSERT INTO documents (docid, content, lid) VALUES (?, ?, ?)", arguments: [1, "abc", 0])
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ? AND lid=0", arguments: ["abc"])!, 1)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ? AND lid=1", arguments: ["abc"])!, 0)
        }
    }

    func testFTS4Synchronization() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "documents") { t in
                t.column("id", .integer).primaryKey()
                t.column("content", .text)
            }
            try db.execute(sql: "INSERT INTO documents (content) VALUES (?)", arguments: ["foo"])
            try db.create(virtualTable: "ft_documents", using: FTS4()) { t in
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

    func testFTS4SynchronizationCleanup() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "documents") { t in
                t.column("id", .integer).primaryKey()
                t.column("content", .text)
            }
            try db.execute(sql: "INSERT INTO documents (content) VALUES (?)", arguments: ["foo"])
            try db.create(virtualTable: "ft_documents", using: FTS4()) { t in
                t.synchronize(withTable: "documents")
                t.column("content")
            }
            
            try db.drop(table: "ft_documents")
            try db.dropFTS4SynchronizationTriggers(forTable: "ft_documents")
            
            // It is possible to modify the content table
            try db.execute(sql: "UPDATE documents SET content = ?", arguments: ["bar"])
            try db.execute(sql: "INSERT INTO documents (content) VALUES (?)", arguments: ["foo"])
            try db.execute(sql: "DELETE FROM documents WHERE content = ?", arguments: ["foo"])
            
            // It is possible to recreate the FT table
            try db.create(virtualTable: "ft_documents", using: FTS4()) { t in
                t.synchronize(withTable: "documents")
                t.column("content")
            }
        }
    }

    func testFTS4SynchronizationCleanupWithLegacySupport() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "documents") { t in
                t.column("id", .integer).primaryKey()
                t.column("content", .text)
            }
            try db.execute(sql: "INSERT INTO documents (content) VALUES (?)", arguments: ["foo"])
            try db.create(virtualTable: "ft_documents", using: FTS4()) { t in
                t.synchronize(withTable: "documents")
                t.column("content")
            }
            
            try db.drop(table: "ft_documents")
            try db.dropFTS4SynchronizationTriggers(forTable: "documents") // legacy GRDB <= 2.3.1
            try db.dropFTS4SynchronizationTriggers(forTable: "ft_documents")
            
            // It is possible to modify the content table
            try db.execute(sql: "UPDATE documents SET content = ?", arguments: ["bar"])
            try db.execute(sql: "INSERT INTO documents (content) VALUES (?)", arguments: ["foo"])
            try db.execute(sql: "DELETE FROM documents WHERE content = ?", arguments: ["foo"])
            
            // It is possible to recreate the FT table
            try db.create(virtualTable: "ft_documents", using: FTS4()) { t in
                t.synchronize(withTable: "documents")
                t.column("content")
            }
        }
    }
    
    func testFTS4Compression() throws {
        // Based on https://github.com/groue/GRDB.swift/issues/369
        var compressCalled = false
        var uncompressCalled = false
        
        let dbPool = try makeDatabasePool()
        dbPool.add(function: DatabaseFunction("zipit", argumentCount: 1, pure: true, function: { dbValues in
            compressCalled = true
            return dbValues[0]
        }))
        dbPool.add(function: DatabaseFunction("unzipit", argumentCount: 1, pure: true, function: { dbValues in
            uncompressCalled = true
            return dbValues[0]
        }))
        
        try dbPool.write { db in
            try db.create(virtualTable: "documents", using: FTS4()) { t in
                t.compress = "zipit"
                t.uncompress = "unzipit"
                t.column("content")
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE \"documents\" USING fts4(content, compress=\"zipit\", uncompress=\"unzipit\")")
            
            try db.execute(sql: "INSERT INTO documents (content) VALUES (?)", arguments: ["abc"])
            XCTAssertTrue(compressCalled)
        }
        
        try dbPool.read { db in
            _ = try Row.fetchOne(db, sql: "SELECT * FROM documents")
            XCTAssertTrue(uncompressCalled)
        }
    }
}

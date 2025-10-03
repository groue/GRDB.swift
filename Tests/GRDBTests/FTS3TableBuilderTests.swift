import XCTest
import GRDB

class FTS3TableBuilderTests: GRDBTestCase {
    func testWithoutBody() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS3())
            assertDidExecute(sql: "CREATE VIRTUAL TABLE \"documents\" USING fts3")
            
            try db.execute(sql: "INSERT INTO documents VALUES (?)", arguments: ["abc"])
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["abc"])!, 1)
        }
    }

    func test_option_ifNotExists() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", options: .ifNotExists, using: FTS3())
            assertDidExecute(sql: "CREATE VIRTUAL TABLE IF NOT EXISTS \"documents\" USING fts3")
            
            try db.execute(sql: "INSERT INTO documents VALUES (?)", arguments: ["abc"])
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["abc"])!, 1)
        }
    }

    func test_option_temporary() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", options: .temporary, using: FTS3())
            assertDidExecute(sql: "CREATE VIRTUAL TABLE temp.\"documents\" USING fts3")
            
            try db.execute(sql: "INSERT INTO documents VALUES (?)", arguments: ["abc"])
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["abc"])!, 1)
        }
    }

    func testLegacyOptions() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", ifNotExists: true, using: FTS3())
            assertDidExecute(sql: "CREATE VIRTUAL TABLE IF NOT EXISTS \"documents\" USING fts3")
            
            try db.execute(sql: "INSERT INTO documents VALUES (?)", arguments: ["abc"])
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["abc"])!, 1)
        }
    }

    func testSimpleTokenizer() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS3()) { t in
                t.tokenizer = .simple
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE \"documents\" USING fts3(tokenize=simple)")
        }
    }

    func testPorterTokenizer() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS3()) { t in
                t.tokenizer = .porter
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE \"documents\" USING fts3(tokenize=porter)")
        }
    }

    func testUnicode61Tokenizer() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS3()) { t in
                t.tokenizer = .unicode61()
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE \"documents\" USING fts3(tokenize=unicode61)")
        }
    }

    func testUnicode61TokenizerDiacriticsKeep() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS3()) { t in
                t.tokenizer = .unicode61(diacritics: .keep)
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE \"documents\" USING fts3(tokenize=unicode61 \"remove_diacritics=0\")")
        }
    }

    #if GRDBCUSTOMSQLITE
    func testUnicode61TokenizerDiacriticsRemove() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS3()) { t in
                t.tokenizer = .unicode61(diacritics: .remove)
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE \"documents\" USING fts3(tokenize=unicode61 \"remove_diacritics=2\")")
        }
    }
    #elseif !SQLITE_HAS_CODEC
    func testUnicode61TokenizerDiacriticsRemove() throws {
        guard #available(iOS 14, macOS 10.16, tvOS 14, *) else {
            throw XCTSkip()
        }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS3()) { t in
                t.tokenizer = .unicode61(diacritics: .remove)
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE \"documents\" USING fts3(tokenize=unicode61 \"remove_diacritics=2\")")
        }
    }
    #endif

    func testUnicode61TokenizerSeparators() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS3()) { t in
                t.tokenizer = .unicode61(separators: ["X"])
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE \"documents\" USING fts3(tokenize=unicode61 \"separators=X\")")
        }
    }

    func testUnicode61TokenizerTokenCharacters() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "documents", using: FTS3()) { t in
                t.tokenizer = .unicode61(tokenCharacters: Set(".-"))
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE \"documents\" USING fts3(tokenize=unicode61 \"tokenchars=-.\")")
        }
    }

    func testColumns() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "books", using: FTS3()) { t in
                t.column("author")
                t.column("title")
                t.column("body")
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE \"books\" USING fts3(author, title, body)")
            
            try db.execute(sql: "INSERT INTO books VALUES (?, ?, ?)", arguments: ["Melville", "Moby Dick", "Call me Ishmael."])
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: ["Melville"])!, 1)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: ["title:Melville"])!, 0)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM books WHERE title MATCH ?", arguments: ["Melville"])!, 0)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM books WHERE books MATCH ?", arguments: ["author:Melville"])!, 1)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM books WHERE author MATCH ?", arguments: ["Melville"])!, 1)
        }
    }
}

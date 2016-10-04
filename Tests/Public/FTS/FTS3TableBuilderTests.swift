import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class FTS3TableBuilderTests: GRDBTestCase {
    
    func testColumns() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(virtualTable: "books", using: FTS3()) { t in
                    t.column("author")
                    t.column("title")
                    t.column("body")
                }
                XCTAssertTrue(sqlQueries.contains("CREATE VIRTUAL TABLE \"books\" USING FTS3(author, title, body)"))
            }
        }
    }
    
    func testWithoutBody() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(virtualTable: "documents", using: FTS3())
                XCTAssertTrue(sqlQueries.contains("CREATE VIRTUAL TABLE \"documents\" USING FTS3"))
            }
        }
    }
    
    func testOptions() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(virtualTable: "documents", ifNotExists: true, using: FTS3())
                XCTAssertTrue(sqlQueries.contains("CREATE VIRTUAL TABLE IF NOT EXISTS \"documents\" USING FTS3"))
            }
        }
    }
    
    func testSimpleTokenizer() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(virtualTable: "documents", using: FTS3()) { t in
                    t.tokenizer = .simple
                }
                XCTAssertTrue(sqlQueries.contains("CREATE VIRTUAL TABLE \"documents\" USING FTS3(tokenize=simple)"))
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
                XCTAssertTrue(sqlQueries.contains("CREATE VIRTUAL TABLE \"documents\" USING FTS3(tokenize=porter)"))
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
                XCTAssertTrue(sqlQueries.contains("CREATE VIRTUAL TABLE \"documents\" USING FTS3(tokenize=unicode61)"))
                
                try db.execute("INSERT INTO documents VALUES (?)", arguments: ["eéèÉÈ"])
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["eeeee"])!, 1)
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
                XCTAssertTrue(sqlQueries.contains("CREATE VIRTUAL TABLE \"documents\" USING FTS3(tokenize=unicode61 \"remove_diacritics=0\")"))
                
                try db.execute("INSERT INTO documents VALUES (?)", arguments: ["eéèÉÈ"])
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["eeeee"])!, 0)
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
                XCTAssertTrue(sqlQueries.contains("CREATE VIRTUAL TABLE \"documents\" USING FTS3(tokenize=unicode61 \"separators=X\")"))
                
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
                try db.create(virtualTable: "documents", using: FTS3()) { t in
                    t.tokenizer = .unicode61(tokenCharacters: Set(".-".characters))
                }
                XCTAssertTrue(sqlQueries.contains("CREATE VIRTUAL TABLE \"documents\" USING FTS3(tokenize=unicode61 \"tokenchars=.-\")") || sqlQueries.contains("CREATE VIRTUAL TABLE \"documents\" USING FTS3(tokenize=unicode61 \"tokenchars=-.\")"))
                
                try db.execute("INSERT INTO documents VALUES (?)", arguments: ["2016-10-04.txt"])
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["2016-10-04.txt"])!, 1)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["2016"])!, 0)
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["txt"])!, 0)
            }
        }
    }
}

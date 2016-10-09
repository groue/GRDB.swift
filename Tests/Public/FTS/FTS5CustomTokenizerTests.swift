import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

final class CustomTokenizer : FTS5TokenizerDefinition {
    
    init(db: Database, arguments: [String]) throws {
        print(arguments)
    }
    
    deinit {
        print("CustomTokenizer deinit")
    }
}

class FTS5CustomTokenizerTests: GRDBTestCase {
    
    func testCustomTokenizer() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.add(tokenizer: CustomTokenizer.self, name: "custom")
                try db.create(virtualTable: "documents", using: FTS5()) { t in
                    t.tokenizer = FTS5Tokenizer("custom", arguments: ["foo", "bar"])
                    t.column("content")
                }
                try db.execute("INSERT INTO documents VALUES (?)", arguments: ["foo bar"])
                try db.execute("INSERT INTO documents VALUES (?)", arguments: ["foo"])
                let countFoo = Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["foo"])
                print(countFoo)
                let countBar = Int.fetchOne(db, "SELECT COUNT(*) FROM documents WHERE documents MATCH ?", arguments: ["bar"])
                print(countBar)
            }
        }
    }
}

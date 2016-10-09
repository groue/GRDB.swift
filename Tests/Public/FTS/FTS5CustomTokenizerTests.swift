import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private final class CustomTokenizer : FTS5CustomTokenizer {
    static let name = "custom"
    
    let porter: FTS5Tokenizer
    
    init(db: Database, arguments: [String]) throws {
        porter = try db.makeTokenizer(.porter())
        print(arguments)
    }
    
    deinit {
        print("CustomTokenizer deinit")
    }
    
    func tokenize(_ context: UnsafeMutableRawPointer?, _ flags: Int32, _ pText: UnsafePointer<Int8>?, _ nText: Int32, _ xToken: FTS5TokenCallback?) -> Int32 {
        return porter.tokenize(context, flags, pText, nText, xToken)
    }
}

class FTS5CustomTokenizerTests: GRDBTestCase {
    
    func testCustomTokenizer() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.add(tokenizer: CustomTokenizer.self)
                try db.create(virtualTable: "documents", using: FTS5()) { t in
                    t.tokenizer = CustomTokenizer.tokenizer(arguments: ["foo", "bar"])
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

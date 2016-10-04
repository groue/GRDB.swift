import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private struct FTS3TokenizeModule : VirtualTableModule {
    let moduleName = "FTS3TOKENIZE"
    typealias TableDefinition = FTS3TokenizeTableDefinition
}

private final class FTS3TokenizeTableDefinition : VirtualTableDefinition {
    var tokenizer: String?
    
    var moduleArguments: [String] {
        guard let tokenizer = tokenizer else { return [] }
        return [tokenizer]
    }
}

class VirtualTableBuilderTests: GRDBTestCase {
    
    func testCustomVirtualTableModule() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(virtualTable: "test", using: FTS3TokenizeModule()) { t in
                    t.tokenizer = "simple"
                }
                XCTAssertEqual(lastSQLQuery, "CREATE VIRTUAL TABLE \"test\" USING FTS3TOKENIZE(simple)")
            }
        }
    }
}

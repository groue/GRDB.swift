import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private struct FTS3TokenizeModule : VirtualTableModule {
    let moduleName = "fts3tokenize"
    
    func makeTableDefinition() -> FTS3TokenizeTableDefinition {
        return FTS3TokenizeTableDefinition()
    }
    
    func moduleArguments(for definition: FTS3TokenizeTableDefinition, in db: Database) -> [String] {
        guard let tokenizer = definition.tokenizer else {
            return []
        }
        return [tokenizer]
    }
    
    func database(_ db: Database, didCreate tableName: String, using definition: FTS3TokenizeTableDefinition) throws {
    }
}

private struct ThrowingFTS3TokenizeModule : VirtualTableModule {
    let moduleName = "fts3tokenize"
    
    func makeTableDefinition() -> FTS3TokenizeTableDefinition {
        return FTS3TokenizeTableDefinition()
    }
    
    func moduleArguments(for definition: FTS3TokenizeTableDefinition, in db: Database) -> [String] {
        guard let tokenizer = definition.tokenizer else {
            return []
        }
        return [tokenizer]
    }
    
    func database(_ db: Database, didCreate tableName: String, using definition: FTS3TokenizeTableDefinition) throws {
        throw DatabaseError(code: 123)
    }
}

private final class FTS3TokenizeTableDefinition {
    var tokenizer: String?
}

class VirtualTableModuleTests: GRDBTestCase {
    
    func testCustomVirtualTableModule() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(virtualTable: "test", using: FTS3TokenizeModule()) { t in
                    t.tokenizer = "simple"
                }
                assertDidExecute(sql: "CREATE VIRTUAL TABLE \"test\" USING fts3tokenize(simple)")
                XCTAssertTrue(db.tableExists("test"))
            }
        }
    }
    
    func testThrowingCustomVirtualTableModule() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                do {
                    try db.create(virtualTable: "test", using: ThrowingFTS3TokenizeModule()) { t in
                        t.tokenizer = "simple"
                    }
                    XCTFail("Expected DatabaseError")
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.code, 123)
                }
                assertDidExecute(sql: "CREATE VIRTUAL TABLE \"test\" USING fts3tokenize(simple)")
                XCTAssertFalse(db.tableExists("test"))
            }
        }
    }
}

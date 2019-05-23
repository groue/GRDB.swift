import XCTest
#if GRDBCUSTOMSQLITE
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
        throw DatabaseError(resultCode: ResultCode(rawValue: 123))
    }
}

private final class FTS3TokenizeTableDefinition {
    var tokenizer: String?
}

class VirtualTableModuleTests: GRDBTestCase {
    
    func testCustomVirtualTableModule() throws {
        // fts3tokenize was introduced in SQLite 3.7.17 https://www.sqlite.org/changes.html#version_3_7_17
        // It is available from iOS 8.2 and OS X 10.10 https://github.com/yapstudios/YapDatabase/wiki/SQLite-version-(bundled-with-OS)
        #if !GRDBCUSTOMSQLITE && !GRDBCIPHER
            guard #available(iOS 8.2, OSX 10.10, *) else {
                return
            }
        #endif
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "test", using: FTS3TokenizeModule()) { t in
                t.tokenizer = "simple"
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE \"test\" USING fts3tokenize(simple)")
            XCTAssertTrue(try db.tableExists("test"))
        }
    }

    func testThrowingCustomVirtualTableModule() throws {
        // fts3tokenize was introduced in SQLite 3.7.17 https://www.sqlite.org/changes.html#version_3_7_17
        // It is available from iOS 8.2 and OS X 10.10 https://github.com/yapstudios/YapDatabase/wiki/SQLite-version-(bundled-with-OS)
        #if !GRDBCUSTOMSQLITE && !GRDBCIPHER
            guard #available(iOS 8.2, OSX 10.10, *) else {
                return
            }
        #endif
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            do {
                try db.create(virtualTable: "test", using: ThrowingFTS3TokenizeModule()) { t in
                    t.tokenizer = "simple"
                }
                XCTFail("Expected DatabaseError")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode.rawValue, 123)
            }
            assertDidExecute(sql: "CREATE VIRTUAL TABLE \"test\" USING fts3tokenize(simple)")
            XCTAssertFalse(try db.tableExists("test"))
        }
    }
}

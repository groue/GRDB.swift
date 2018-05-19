import XCTest
#if GRDBCIPHER
    @testable import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    @testable import GRDBCustomSQLite
#else
    @testable import GRDB
#endif

private struct Person : FetchableRecord, TableRecord {
    static let databaseTableName = "persons"
    init(row: Row) {
    }
}

class RecordUniqueIndexTests: GRDBTestCase {
    
    func testKeyFilterAcceptsUniqueIndex() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute("CREATE TABLE persons (id INTEGER PRIMARY KEY, name TEXT, email TEXT UNIQUE)")
            
            _ = try Person.filter(keys: [["id": nil]]).fetchOne(db)
            _ = try Person.filter(keys: [["email": nil]]).fetchOne(db)
        }
    }
}

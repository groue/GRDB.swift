import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class TableMappingTests: GRDBTestCase {
    
    func testPrimaryKeyRowComparatorWithIntegerPrimaryKey() throws {
        struct Person : TableMapping {
            static let databaseTableName = "persons"
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "persons") { t in
                t.column("id", .integer).primaryKey()
                t.column("name", .text)
            }
            
            let comparator = try Person.primaryKeyRowComparator(db)
            let row0: Row = ["id": nil, "name": "Unsaved"]
            let row1: Row = ["id": 1, "name": "Arthur"]
            let row2: Row = ["id": 1, "name": "Arthur"]
            let row3: Row = ["id": 2, "name": "Barbara"]
            XCTAssertFalse(comparator(row0, row0))
            XCTAssertTrue(comparator(row1, row2))
            XCTAssertFalse(comparator(row1, row3))
        }
    }
    
    func testPrimaryKeyRowComparatorWithHiddenRowIDPrimaryKey() throws {
        struct Person : TableMapping {
            static let databaseTableName = "persons"
            static let selectsRowID = true
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "persons") { t in
                t.column("name", .text)
            }
            
            let comparator = try Person.primaryKeyRowComparator(db)
            let row0: Row = ["rowid": nil, "name": "Unsaved"]
            let row1: Row = ["rowid": 1, "name": "Arthur"]
            let row2: Row = ["rowid": 1, "name": "Arthur"]
            let row3: Row = ["rowid": 2, "name": "Barbara"]
            XCTAssertFalse(comparator(row0, row0))
            XCTAssertTrue(comparator(row1, row2))
            XCTAssertFalse(comparator(row1, row3))
        }
    }
}

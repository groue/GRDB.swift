import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class DatabaseCollationTests: GRDBTestCase {
    
    func testDefaultCollations() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE strings (id INTEGER PRIMARY KEY, name TEXT)")
            try db.execute(sql: "INSERT INTO strings VALUES (1, '1')")
            try db.execute(sql: "INSERT INTO strings VALUES (2, '2')")
            try db.execute(sql: "INSERT INTO strings VALUES (3, '10')")
            try db.execute(sql: "INSERT INTO strings VALUES (4, 'a')")
            try db.execute(sql: "INSERT INTO strings VALUES (5, 'à')")
            try db.execute(sql: "INSERT INTO strings VALUES (6, 'A')")
            try db.execute(sql: "INSERT INTO strings VALUES (7, 'Z')")
            try db.execute(sql: "INSERT INTO strings VALUES (8, 'z')")
            
            // Swift 4.2 and Swift 4.1 don't sort strings in the same way
            if "z" < "à" {
                XCTAssertEqual(
                    try Int.fetchAll(db, sql: "SELECT id FROM strings ORDER BY name COLLATE \(DatabaseCollation.unicodeCompare.name), id"),
                    [1,3,2,6,7,4,8,5])
            } else {
                XCTAssertEqual(
                    try Int.fetchAll(db, sql: "SELECT id FROM strings ORDER BY name COLLATE \(DatabaseCollation.unicodeCompare.name), id"),
                    [1,3,2,6,7,4,5,8])
            }
            XCTAssertEqual(
                try Int.fetchAll(db, sql: "SELECT id FROM strings ORDER BY name COLLATE \(DatabaseCollation.caseInsensitiveCompare.name), id"),
                [1,3,2,4,6,5,7,8])
            XCTAssertEqual(
                try Int.fetchAll(db, sql: "SELECT id FROM strings ORDER BY name COLLATE \(DatabaseCollation.localizedCaseInsensitiveCompare.name), id"),
                [1,3,2,4,6,5,7,8])
            XCTAssertEqual(
                try Int.fetchAll(db, sql: "SELECT id FROM strings ORDER BY name COLLATE \(DatabaseCollation.localizedCompare.name), id"),
                [1,3,2,4,6,5,8,7])
            XCTAssertEqual(
                try Int.fetchAll(db, sql: "SELECT id FROM strings ORDER BY name COLLATE \(DatabaseCollation.localizedStandardCompare.name), id"),
                [1,2,3,4,6,5,8,7])
        }
    }

    func testCollation() throws {
        let dbQueue = try makeDatabaseQueue()
        let collation = DatabaseCollation("localized_standard") { (string1, string2) in
            let length1 = string1.utf8.count
            let length2 = string2.utf8.count
            if length1 == length2 {
                return (string1 as NSString).compare(string2)
            } else if length1 < length2 {
                return .orderedAscending
            } else {
                return .orderedDescending
            }
        }
        dbQueue.add(collation: collation)
        
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE strings (id INTEGER PRIMARY KEY, name TEXT COLLATE LOCALIZED_STANDARD)")
            try db.execute(sql: "INSERT INTO strings VALUES (1, 'a')")
            try db.execute(sql: "INSERT INTO strings VALUES (2, 'aa')")
            try db.execute(sql: "INSERT INTO strings VALUES (3, 'aaa')")
            try db.execute(sql: "INSERT INTO strings VALUES (4, 'b')")
            try db.execute(sql: "INSERT INTO strings VALUES (5, 'bb')")
            try db.execute(sql: "INSERT INTO strings VALUES (6, 'bbb')")
            try db.execute(sql: "INSERT INTO strings VALUES (7, 'c')")
            try db.execute(sql: "INSERT INTO strings VALUES (8, 'cc')")
            try db.execute(sql: "INSERT INTO strings VALUES (9, 'ccc')")
            
            let ids = try Int.fetchAll(db, sql: "SELECT id FROM strings ORDER BY NAME")
            XCTAssertEqual(ids, [1,4,7,2,5,8,3,6,9])
        }
    }
}

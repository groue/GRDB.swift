import XCTest
import GRDB

class DatabaseCollationTests: GRDBTestCase {
    
    func testDefaultCollations() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: """
                CREATE TABLE strings (id INTEGER PRIMARY KEY, name TEXT);
                INSERT INTO strings VALUES (1, '1');
                INSERT INTO strings VALUES (2, '2');
                INSERT INTO strings VALUES (3, '10');
                INSERT INTO strings VALUES (4, 'a');
                INSERT INTO strings VALUES (5, 'à');
                INSERT INTO strings VALUES (6, 'A');
                INSERT INTO strings VALUES (7, 'Z');
                INSERT INTO strings VALUES (8, 'z');
                INSERT INTO strings VALUES (9, '');
                INSERT INTO strings VALUES (10, NULL);
                INSERT INTO strings VALUES (11, x'42FF'); -- Invalid UTF8 "B�"
                """)
            
            // Note that "B�" is always last. We can observe that SQLite
            // does not invoke the collation for invalid UTF8 strings.
            XCTAssertEqual(
                try Int.fetchAll(db, sql: "SELECT id FROM strings ORDER BY name COLLATE \(DatabaseCollation.unicodeCompare.name), id"),
                [10,9,1,3,2,6,7,4,8,5,11])
            XCTAssertEqual(
                try Int.fetchAll(db, sql: "SELECT id FROM strings ORDER BY name COLLATE \(DatabaseCollation.caseInsensitiveCompare.name), id"),
                [10,9,1,3,2,4,6,5,7,8,11])
            XCTAssertEqual(
                try Int.fetchAll(db, sql: "SELECT id FROM strings ORDER BY name COLLATE \(DatabaseCollation.localizedCaseInsensitiveCompare.name), id"),
                [10,9,1,3,2,4,6,5,7,8,11])
            XCTAssertEqual(
                try Int.fetchAll(db, sql: "SELECT id FROM strings ORDER BY name COLLATE \(DatabaseCollation.localizedCompare.name), id"),
                [10,9,1,3,2,4,6,5,8,7,11])
            XCTAssertEqual(
                try Int.fetchAll(db, sql: "SELECT id FROM strings ORDER BY name COLLATE \(DatabaseCollation.localizedStandardCompare.name), id"),
                [10,9,1,2,3,4,6,5,8,7,11])
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
        
        try dbQueue.inDatabase { db in
            db.add(collation: collation)
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

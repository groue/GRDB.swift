import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class DatabaseCollationTests: GRDBTestCase {
    
	func testDefaultCollations() throws {
		let dbQueue = try makeDatabaseQueue()
		try dbQueue.inDatabase { db in
			try db.execute("CREATE TABLE strings (id INTEGER PRIMARY KEY, name TEXT)")
			
			let strings = ["1", "2", "10", "a", "à", "A", "Z", "z"]
			for string in strings {
				try db.execute("INSERT INTO strings (name) VALUES (?)", arguments: [string])
			}
			
			func assert(collation: DatabaseCollation, ordersLike comparison: (String, String) -> ComparisonResult) throws {
				let dbStrings = try String.fetchAll(db, "SELECT name FROM strings ORDER BY name COLLATE \(collation.name)")
				let swiftStrings = strings.sorted { comparison($0, $1) == .orderedAscending }
				for (dbString, swiftString) in zip(dbStrings, swiftStrings) {
					XCTAssert(comparison(dbString, swiftString) == .orderedSame)
				}
			}
			
			try assert(collation: .unicodeCompare, ordersLike: {
				if $0 < $1 { return .orderedAscending }
				else if $0 == $1 { return .orderedSame }
				else { return .orderedDescending }
			})
			try assert(collation: .caseInsensitiveCompare, ordersLike: {
				$0.caseInsensitiveCompare($1)
			})
			try assert(collation: .localizedCaseInsensitiveCompare, ordersLike: {
				$0.localizedCaseInsensitiveCompare($1)
			})
			try assert(collation: .localizedCompare, ordersLike: {
				$0.localizedCompare($1)
			})
			try assert(collation: .localizedStandardCompare, ordersLike: {
				$0.localizedStandardCompare($1)
			})
		}
	}

    func testCollation() throws {
        let dbQueue = try makeDatabaseQueue()
        let collation = DatabaseCollation("localized_standard") { (string1, string2) in
            let length1 = string1.utf8.count
            let length2 = string2.utf8.count
            if length1 == length2 {
                return string1.compare(string2)
            } else if length1 < length2 {
                return .orderedAscending
            } else {
                return .orderedDescending
            }
        }
        dbQueue.add(collation: collation)
        
        try dbQueue.inDatabase { db in
            try db.execute("CREATE TABLE strings (id INTEGER PRIMARY KEY, name TEXT COLLATE LOCALIZED_STANDARD)")
            try db.execute("INSERT INTO strings VALUES (1, 'a')")
            try db.execute("INSERT INTO strings VALUES (2, 'aa')")
            try db.execute("INSERT INTO strings VALUES (3, 'aaa')")
            try db.execute("INSERT INTO strings VALUES (4, 'b')")
            try db.execute("INSERT INTO strings VALUES (5, 'bb')")
            try db.execute("INSERT INTO strings VALUES (6, 'bbb')")
            try db.execute("INSERT INTO strings VALUES (7, 'c')")
            try db.execute("INSERT INTO strings VALUES (8, 'cc')")
            try db.execute("INSERT INTO strings VALUES (9, 'ccc')")
            
            let ids = try Int.fetchAll(db, "SELECT id FROM strings ORDER BY NAME")
            XCTAssertEqual(ids, [1,4,7,2,5,8,3,6,9])
        }
    }
}

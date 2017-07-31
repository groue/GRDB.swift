import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private struct Col {
    static let id = Column("id")
    static let name = Column("name")
    static let age = Column("age")
    static let readerId = Column("readerId")
}

private struct Reader : TableMapping {
    static let databaseTableName = "readers"
}
private let tableRequest = Reader.all()

class QueryInterfaceRequestTests: GRDBTestCase {

    var collation: DatabaseCollation!
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
        collation = DatabaseCollation("localized_case_insensitive") { (lhs, rhs) in
            return (lhs as NSString).localizedCaseInsensitiveCompare(rhs)
        }
        dbWriter.add(collation: collation)
        
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createReaders") { db in
            try db.execute("""
                CREATE TABLE readers (
                    id INTEGER PRIMARY KEY,
                    name TEXT NOT NULL,
                    age INT)
                """)
        }
        try migrator.migrate(dbWriter)
    }
    
    
    // MARK: - Fetch rows
    
    func testFetchRowFromRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute("INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Arthur", 42])
            try db.execute("INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Barbara", 36])
            
            do {
                let rows = try Row.fetchAll(db, tableRequest)
                XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"readers\"")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0]["id"] as Int64, 1)
                XCTAssertEqual(rows[0]["name"] as String, "Arthur")
                XCTAssertEqual(rows[0]["age"] as Int, 42)
                XCTAssertEqual(rows[1]["id"] as Int64, 2)
                XCTAssertEqual(rows[1]["name"] as String, "Barbara")
                XCTAssertEqual(rows[1]["age"] as Int, 36)
            }
            
            do {
                let row = try Row.fetchOne(db, tableRequest)!
                XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"readers\"")
                XCTAssertEqual(row["id"] as Int64, 1)
                XCTAssertEqual(row["name"] as String, "Arthur")
                XCTAssertEqual(row["age"] as Int, 42)
            }
            
            do {
                var names: [String] = []
                let rows = try Row.fetchCursor(db, tableRequest)
                while let row = try rows.next() {
                    names.append(row["name"])
                }
                XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"readers\"")
                XCTAssertEqual(names, ["Arthur", "Barbara"])
            }
        }
    }


    // MARK: - Count

    func testFetchCount() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            XCTAssertEqual(try tableRequest.fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM \"readers\"")
            
            XCTAssertEqual(try tableRequest.reversed().fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM \"readers\"")
            
            XCTAssertEqual(try tableRequest.order(Col.name).fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM \"readers\"")
            
            XCTAssertEqual(try tableRequest.limit(10).fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM (SELECT * FROM \"readers\" LIMIT 10)")
            
            XCTAssertEqual(try tableRequest.filter(Col.age == 42).fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM \"readers\" WHERE (\"age\" = 42)")
            
            XCTAssertEqual(try tableRequest.distinct().fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM (SELECT DISTINCT * FROM \"readers\")")
            
            XCTAssertEqual(try tableRequest.select(Col.name).fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM \"readers\"")
            
            XCTAssertEqual(try tableRequest.select(Col.name).distinct().fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(DISTINCT \"name\") FROM \"readers\"")
            
            XCTAssertEqual(try tableRequest.select(Col.age * 2).distinct().fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(DISTINCT (\"age\" * 2)) FROM \"readers\"")
            
            XCTAssertEqual(try tableRequest.select((Col.age * 2).aliased("ignored")).distinct().fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(DISTINCT (\"age\" * 2)) FROM \"readers\"")
            
            XCTAssertEqual(try tableRequest.select(Col.name, Col.age).fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM \"readers\"")
            
            XCTAssertEqual(try tableRequest.select(Col.name, Col.age).distinct().fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM (SELECT DISTINCT \"name\", \"age\" FROM \"readers\")")
            
            XCTAssertEqual(try tableRequest.select(max(Col.age)).group(Col.name).fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM (SELECT MAX(\"age\") FROM \"readers\" GROUP BY \"name\")")
        }
    }


    // MARK: - Select

    func testSelectLiteral() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute("INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Arthur", 42])
            try db.execute("INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Barbara", 36])
            
            let request = tableRequest.select(sql: "name, id - 1")
            let rows = try Row.fetchAll(db, request)
            XCTAssertEqual(lastSQLQuery, "SELECT name, id - 1 FROM \"readers\"")
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0][0] as String, "Arthur")
            XCTAssertEqual(rows[0][1] as Int64, 0)
            XCTAssertEqual(rows[1][0] as String, "Barbara")
            XCTAssertEqual(rows[1][1] as Int64, 1)
        }
    }

    func testSelectLiteralWithPositionalArguments() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute("INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Arthur", 42])
            try db.execute("INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Barbara", 36])
            
            let request = tableRequest.select(sql: "name, id - ?", arguments: [1])
            let rows = try Row.fetchAll(db, request)
            XCTAssertEqual(lastSQLQuery, "SELECT name, id - 1 FROM \"readers\"")
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0][0] as String, "Arthur")
            XCTAssertEqual(rows[0][1] as Int64, 0)
            XCTAssertEqual(rows[1][0] as String, "Barbara")
            XCTAssertEqual(rows[1][1] as Int64, 1)
        }
    }

    func testSelectLiteralWithNamedArguments() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute("INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Arthur", 42])
            try db.execute("INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Barbara", 36])
            
            let request = tableRequest.select(sql: "name, id - :n", arguments: ["n": 1])
            let rows = try Row.fetchAll(db, request)
            XCTAssertEqual(lastSQLQuery, "SELECT name, id - 1 FROM \"readers\"")
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0][0] as String, "Arthur")
            XCTAssertEqual(rows[0][1] as Int64, 0)
            XCTAssertEqual(rows[1][0] as String, "Barbara")
            XCTAssertEqual(rows[1][1] as Int64, 1)
        }
    }

    func testSelect() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute("INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Arthur", 42])
            try db.execute("INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Barbara", 36])
            
            let request = tableRequest.select(Col.name, Col.id - 1)
            let rows = try Row.fetchAll(db, request)
            XCTAssertEqual(lastSQLQuery, "SELECT \"name\", (\"id\" - 1) FROM \"readers\"")
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0][0] as String, "Arthur")
            XCTAssertEqual(rows[0][1] as Int64, 0)
            XCTAssertEqual(rows[1][0] as String, "Barbara")
            XCTAssertEqual(rows[1][1] as Int64, 1)
        }
    }

    func testSelectAliased() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute("INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Arthur", 42])
            
            let request = tableRequest.select(Col.name.aliased("nom"), (Col.age + 1).aliased("agePlusOne"))
            let row = try Row.fetchOne(db, request)!
            XCTAssertEqual(lastSQLQuery, "SELECT \"name\" AS \"nom\", (\"age\" + 1) AS \"agePlusOne\" FROM \"readers\"")
            XCTAssertEqual(row["nom"] as String, "Arthur")
            XCTAssertEqual(row["agePlusOne"] as Int, 43)
        }
    }

    func testMultipleSelect() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(Col.age).select(Col.name)),
            "SELECT \"name\" FROM \"readers\"")
    }
    
    
    // MARK: - Distinct
    
    func testDistinct() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(Col.name).distinct()),
            "SELECT DISTINCT \"name\" FROM \"readers\"")
    }
    
    
    // MARK: - Filter
    
    func testFilterLiteral() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(sql: "id <> 1")),
            "SELECT * FROM \"readers\" WHERE id <> 1")
    }
    
    func testFilterLiteralWithPositionalArguments() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(sql: "id <> ?", arguments: [1])),
            "SELECT * FROM \"readers\" WHERE id <> 1")
    }
    
    func testFilterLiteralWithNamedArguments() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(sql: "id <> :id", arguments: ["id": 1])),
            "SELECT * FROM \"readers\" WHERE id <> 1")
    }
    
    func testFilter() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(true)),
            "SELECT * FROM \"readers\" WHERE 1")
    }

    func testMultipleFilter() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(true).filter(false)),
            "SELECT * FROM \"readers\" WHERE (1 AND 0)")
    }
    
    
    // MARK: - Group
    
    func testGroupLiteral() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.group(sql: "age, lower(name)")),
            "SELECT * FROM \"readers\" GROUP BY age, lower(name)")
    }
    
    func testGroupLiteralWithPositionalArguments() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.group(sql: "age + ?, lower(name)", arguments: [1])),
            "SELECT * FROM \"readers\" GROUP BY age + 1, lower(name)")
    }
    
    func testGroupLiteralWithNamedArguments() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.group(sql: "age + :n, lower(name)", arguments: ["n": 1])),
            "SELECT * FROM \"readers\" GROUP BY age + 1, lower(name)")
    }
    
    func testGroup() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.group(Col.age)),
            "SELECT * FROM \"readers\" GROUP BY \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.group(Col.age, Col.name)),
            "SELECT * FROM \"readers\" GROUP BY \"age\", \"name\"")
    }
    
    func testMultipleGroup() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.group(Col.age).group(Col.name)),
            "SELECT * FROM \"readers\" GROUP BY \"name\"")
    }
    
    
    // MARK: - Having
    
    func testHavingLiteral() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.group(Col.name).having(sql: "min(age) > 18")),
            "SELECT * FROM \"readers\" GROUP BY \"name\" HAVING min(age) > 18")
    }
    
    func testHavingLiteralWithPositionalArguments() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.group(Col.name).having(sql: "min(age) > ?", arguments: [18])),
            "SELECT * FROM \"readers\" GROUP BY \"name\" HAVING min(age) > 18")
    }
    
    func testHavingLiteralWithNamedArguments() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.group(Col.name).having(sql: "min(age) > :age", arguments: ["age": 18])),
            "SELECT * FROM \"readers\" GROUP BY \"name\" HAVING min(age) > 18")
    }
    
    func testHaving() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.group(Col.name).having(min(Col.age) > 18)),
            "SELECT * FROM \"readers\" GROUP BY \"name\" HAVING (MIN(\"age\") > 18)")
    }
    
    func testMultipleHaving() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.group(Col.name).having(min(Col.age) > 18).having(max(Col.age) < 50)),
                "SELECT * FROM \"readers\" GROUP BY \"name\" HAVING ((MIN(\"age\") > 18) AND (MAX(\"age\") < 50))")
    }
    
    
    // MARK: - Sort
    
    func testSortLiteral() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.order(sql: "lower(name) desc")),
            "SELECT * FROM \"readers\" ORDER BY lower(name) desc")
    }
    
    func testSortLiteralWithPositionalArguments() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.order(sql: "age + ?", arguments: [1])),
            "SELECT * FROM \"readers\" ORDER BY age + 1")
    }
    
    func testSortLiteralWithNamedArguments() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.order(sql: "age + :age", arguments: ["age": 1])),
            "SELECT * FROM \"readers\" ORDER BY age + 1")
    }
    
    func testSort() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.order(Col.age)),
            "SELECT * FROM \"readers\" ORDER BY \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.order(Col.age.asc)),
            "SELECT * FROM \"readers\" ORDER BY \"age\" ASC")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.order(Col.age.desc)),
            "SELECT * FROM \"readers\" ORDER BY \"age\" DESC")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.order(Col.age, Col.name.desc)),
            "SELECT * FROM \"readers\" ORDER BY \"age\", \"name\" DESC")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.order(abs(Col.age))),
            "SELECT * FROM \"readers\" ORDER BY ABS(\"age\")")
    }
    
    func testSortWithCollation() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.order(Col.name.collating(.nocase))),
            "SELECT * FROM \"readers\" ORDER BY \"name\" COLLATE NOCASE")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.order(Col.name.collating(.nocase).asc)),
            "SELECT * FROM \"readers\" ORDER BY \"name\" COLLATE NOCASE ASC")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.order(Col.name.collating(collation))),
            "SELECT * FROM \"readers\" ORDER BY \"name\" COLLATE localized_case_insensitive")
    }
    
    func testMultipleSort() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.order(Col.age).order(Col.name)),
            "SELECT * FROM \"readers\" ORDER BY \"name\"")
    }
    
    
    // MARK: - Reverse
    
    func testReverse() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.reversed()),
            "SELECT * FROM \"readers\" ORDER BY \"rowid\" DESC")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.order(Col.age).reversed()),
            "SELECT * FROM \"readers\" ORDER BY \"age\" DESC")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.order(Col.age.asc).reversed()),
            "SELECT * FROM \"readers\" ORDER BY \"age\" DESC")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.order(Col.age.desc).reversed()),
            "SELECT * FROM \"readers\" ORDER BY \"age\" ASC")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.order(Col.age, Col.name.desc).reversed()),
            "SELECT * FROM \"readers\" ORDER BY \"age\" DESC, \"name\" ASC")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.order(abs(Col.age)).reversed()),
            "SELECT * FROM \"readers\" ORDER BY ABS(\"age\") DESC")
    }
    
    func testReverseWithCollation() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.order(Col.name.collating(.nocase)).reversed()),
            "SELECT * FROM \"readers\" ORDER BY \"name\" COLLATE NOCASE DESC")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.order(Col.name.collating(.nocase).asc).reversed()),
            "SELECT * FROM \"readers\" ORDER BY \"name\" COLLATE NOCASE DESC")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.order(Col.name.collating(collation)).reversed()),
            "SELECT * FROM \"readers\" ORDER BY \"name\" COLLATE localized_case_insensitive DESC")
    }
    
    func testMultipleReverse() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.reversed().reversed()),
            "SELECT * FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.order(Col.age, Col.name).reversed().reversed()),
            "SELECT * FROM \"readers\" ORDER BY \"age\", \"name\"")
    }
    
    
    // MARK: - Limit
    
    func testLimit() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.limit(1)),
            "SELECT * FROM \"readers\" LIMIT 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.limit(1, offset: 2)),
            "SELECT * FROM \"readers\" LIMIT 1 OFFSET 2")
    }
    
    func testMultipleLimit() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.limit(1, offset: 2).limit(3)),
            "SELECT * FROM \"readers\" LIMIT 3")
    }
    
    
    // MARK: - Delete
    
    func testDelete() throws {
        let dbQueue = try makeDatabaseQueue()
        
        try dbQueue.inDatabase { db in
            try tableRequest.deleteAll(db)
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"readers\"")
            
            try tableRequest.filter(Col.age == 42).deleteAll(db)
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"readers\" WHERE (\"age\" = 42)")
            
            try tableRequest.filter(sql: "id = 1").deleteAll(db)
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"readers\" WHERE id = 1")
            
            try tableRequest.select(Col.name).deleteAll(db)
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"readers\"")
            
            try tableRequest.distinct().deleteAll(db)
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"readers\"")
            
            try tableRequest.order(Col.name).deleteAll(db)
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"readers\"")
        }
    }
}

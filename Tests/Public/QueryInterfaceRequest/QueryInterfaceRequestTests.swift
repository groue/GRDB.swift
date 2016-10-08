import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
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
            try db.execute(
                "CREATE TABLE readers (" +
                    "id INTEGER PRIMARY KEY, " +
                    "name TEXT NOT NULL, " +
                    "age INT" +
                ")")
        }
        try migrator.migrate(dbWriter)
    }
    
    
    // MARK: - Fetch rows
    
    func testFetchRowFromRequest() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Arthur", 42])
                try db.execute("INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Barbara", 36])
                
                do {
                    let rows = Row.fetchAll(db, tableRequest)
                    XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"readers\"")
                    XCTAssertEqual(rows.count, 2)
                    XCTAssertEqual(rows[0].value(named: "id") as Int64, 1)
                    XCTAssertEqual(rows[0].value(named: "name") as String, "Arthur")
                    XCTAssertEqual(rows[0].value(named: "age") as Int, 42)
                    XCTAssertEqual(rows[1].value(named: "id") as Int64, 2)
                    XCTAssertEqual(rows[1].value(named: "name") as String, "Barbara")
                    XCTAssertEqual(rows[1].value(named: "age") as Int, 36)
                }
                
                do {
                    let row = Row.fetchOne(db, tableRequest)!
                    XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"readers\"")
                    XCTAssertEqual(row.value(named: "id") as Int64, 1)
                    XCTAssertEqual(row.value(named: "name") as String, "Arthur")
                    XCTAssertEqual(row.value(named: "age") as Int, 42)
                }
                
                do {
                    var names: [String] = []
                    for row in Row.fetch(db, tableRequest) {
                        names.append(row.value(named: "name"))
                    }
                    XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"readers\"")
                    XCTAssertEqual(names, ["Arthur", "Barbara"])
                }
            }
        }
    }
    
    
    // MARK: - Count
    
    func testFetchCount() {
        let dbQueue = try! makeDatabaseQueue()
        dbQueue.inDatabase { db in
            XCTAssertEqual(tableRequest.fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM \"readers\"")
            
            XCTAssertEqual(tableRequest.reversed().fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM \"readers\"")
            
            XCTAssertEqual(tableRequest.order(Col.name).fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM \"readers\"")
            
            XCTAssertEqual(tableRequest.limit(10).fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM (SELECT * FROM \"readers\" LIMIT 10)")
            
            XCTAssertEqual(tableRequest.filter(Col.age == 42).fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM \"readers\" WHERE (\"age\" = 42)")
            
            XCTAssertEqual(tableRequest.distinct().fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM (SELECT DISTINCT * FROM \"readers\")")
            
            XCTAssertEqual(tableRequest.select(Col.name).fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM \"readers\"")
            
            XCTAssertEqual(tableRequest.select(Col.name).distinct().fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(DISTINCT \"name\") FROM \"readers\"")
            
            XCTAssertEqual(tableRequest.select(Col.age * 2).distinct().fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(DISTINCT (\"age\" * 2)) FROM \"readers\"")
            
            XCTAssertEqual(tableRequest.select((Col.age * 2).aliased("ignored")).distinct().fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(DISTINCT (\"age\" * 2)) FROM \"readers\"")
            
            XCTAssertEqual(tableRequest.select(Col.name, Col.age).fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM \"readers\"")
            
            XCTAssertEqual(tableRequest.select(Col.name, Col.age).distinct().fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM (SELECT DISTINCT \"name\", \"age\" FROM \"readers\")")
            
            XCTAssertEqual(tableRequest.select(max(Col.age)).group(Col.name).fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM (SELECT MAX(\"age\") FROM \"readers\" GROUP BY \"name\")")
        }
    }
    
    
    // MARK: - Select
    
    func testSelectLiteral() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Arthur", 42])
                try db.execute("INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Barbara", 36])
                
                let request = tableRequest.select(sql: "name, id - 1")
                let rows = Row.fetchAll(db, request)
                XCTAssertEqual(lastSQLQuery, "SELECT name, id - 1 FROM \"readers\"")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0].value(atIndex: 0) as String, "Arthur")
                XCTAssertEqual(rows[0].value(atIndex: 1) as Int64, 0)
                XCTAssertEqual(rows[1].value(atIndex: 0) as String, "Barbara")
                XCTAssertEqual(rows[1].value(atIndex: 1) as Int64, 1)
            }
        }
    }
    
    func testSelectLiteralWithPositionalArguments() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Arthur", 42])
                try db.execute("INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Barbara", 36])
                
                let request = tableRequest.select(sql: "name, id - ?", arguments: [1])
                let rows = Row.fetchAll(db, request)
                XCTAssertEqual(lastSQLQuery, "SELECT name, id - 1 FROM \"readers\"")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0].value(atIndex: 0) as String, "Arthur")
                XCTAssertEqual(rows[0].value(atIndex: 1) as Int64, 0)
                XCTAssertEqual(rows[1].value(atIndex: 0) as String, "Barbara")
                XCTAssertEqual(rows[1].value(atIndex: 1) as Int64, 1)
            }
        }
    }
    
    func testSelectLiteralWithNamedArguments() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Arthur", 42])
                try db.execute("INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Barbara", 36])
                
                let request = tableRequest.select(sql: "name, id - :n", arguments: ["n": 1])
                let rows = Row.fetchAll(db, request)
                XCTAssertEqual(lastSQLQuery, "SELECT name, id - 1 FROM \"readers\"")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0].value(atIndex: 0) as String, "Arthur")
                XCTAssertEqual(rows[0].value(atIndex: 1) as Int64, 0)
                XCTAssertEqual(rows[1].value(atIndex: 0) as String, "Barbara")
                XCTAssertEqual(rows[1].value(atIndex: 1) as Int64, 1)
            }
        }
    }
    
    func testSelect() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Arthur", 42])
                try db.execute("INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Barbara", 36])
                
                let request = tableRequest.select(Col.name, Col.id - 1)
                let rows = Row.fetchAll(db, request)
                XCTAssertEqual(lastSQLQuery, "SELECT \"name\", (\"id\" - 1) FROM \"readers\"")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0].value(atIndex: 0) as String, "Arthur")
                XCTAssertEqual(rows[0].value(atIndex: 1) as Int64, 0)
                XCTAssertEqual(rows[1].value(atIndex: 0) as String, "Barbara")
                XCTAssertEqual(rows[1].value(atIndex: 1) as Int64, 1)
            }
        }
    }
    
    func testSelectAliased() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Arthur", 42])
                
                let request = tableRequest.select(Col.name.aliased("nom"), (Col.age + 1).aliased("agePlusOne"))
                let row = Row.fetchOne(db, request)!
                XCTAssertEqual(lastSQLQuery, "SELECT \"name\" AS \"nom\", (\"age\" + 1) AS \"agePlusOne\" FROM \"readers\"")
                XCTAssertEqual(row.value(named: "nom") as String, "Arthur")
                XCTAssertEqual(row.value(named: "agePlusOne") as Int, 43)
            }
        }
    }
    
    func testMultipleSelect() {
        let dbQueue = try! makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(Col.age).select(Col.name)),
            "SELECT \"name\" FROM \"readers\"")
    }
    
    
    // MARK: - Distinct
    
    func testDistinct() {
        let dbQueue = try! makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(Col.name).distinct()),
            "SELECT DISTINCT \"name\" FROM \"readers\"")
    }
    
    
    // MARK: - Filter
    
    func testFilterLiteral() {
        let dbQueue = try! makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(sql: "id <> 1")),
            "SELECT * FROM \"readers\" WHERE id <> 1")
    }
    
    func testFilterLiteralWithPositionalArguments() {
        let dbQueue = try! makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(sql: "id <> ?", arguments: [1])),
            "SELECT * FROM \"readers\" WHERE id <> 1")
    }
    
    func testFilterLiteralWithNamedArguments() {
        let dbQueue = try! makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(sql: "id <> :id", arguments: ["id": 1])),
            "SELECT * FROM \"readers\" WHERE id <> 1")
    }
    
    func testFilter() {
        let dbQueue = try! makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(true)),
            "SELECT * FROM \"readers\" WHERE 1")
    }

    func testMultipleFilter() {
        let dbQueue = try! makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(true).filter(false)),
            "SELECT * FROM \"readers\" WHERE (1 AND 0)")
    }
    
    
    // MARK: - Group
    
    func testGroupLiteral() {
        let dbQueue = try! makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.group(sql: "age, lower(name)")),
            "SELECT * FROM \"readers\" GROUP BY age, lower(name)")
    }
    
    func testGroupLiteralWithPositionalArguments() {
        let dbQueue = try! makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.group(sql: "age + ?, lower(name)", arguments: [1])),
            "SELECT * FROM \"readers\" GROUP BY age + 1, lower(name)")
    }
    
    func testGroupLiteralWithNamedArguments() {
        let dbQueue = try! makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.group(sql: "age + :n, lower(name)", arguments: ["n": 1])),
            "SELECT * FROM \"readers\" GROUP BY age + 1, lower(name)")
    }
    
    func testGroup() {
        let dbQueue = try! makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.group(Col.age)),
            "SELECT * FROM \"readers\" GROUP BY \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.group(Col.age, Col.name)),
            "SELECT * FROM \"readers\" GROUP BY \"age\", \"name\"")
    }
    
    func testMultipleGroup() {
        let dbQueue = try! makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.group(Col.age).group(Col.name)),
            "SELECT * FROM \"readers\" GROUP BY \"name\"")
    }
    
    
    // MARK: - Having
    
    func testHavingLiteral() {
        let dbQueue = try! makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.group(Col.name).having(sql: "min(age) > 18")),
            "SELECT * FROM \"readers\" GROUP BY \"name\" HAVING min(age) > 18")
    }
    
    func testHavingLiteralWithPositionalArguments() {
        let dbQueue = try! makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.group(Col.name).having(sql: "min(age) > ?", arguments: [18])),
            "SELECT * FROM \"readers\" GROUP BY \"name\" HAVING min(age) > 18")
    }
    
    func testHavingLiteralWithNamedArguments() {
        let dbQueue = try! makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.group(Col.name).having(sql: "min(age) > :age", arguments: ["age": 18])),
            "SELECT * FROM \"readers\" GROUP BY \"name\" HAVING min(age) > 18")
    }
    
    func testHaving() {
        let dbQueue = try! makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.group(Col.name).having(min(Col.age) > 18)),
            "SELECT * FROM \"readers\" GROUP BY \"name\" HAVING (MIN(\"age\") > 18)")
    }
    
    func testMultipleHaving() {
        let dbQueue = try! makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.group(Col.name).having(min(Col.age) > 18).having(max(Col.age) < 50)),
                "SELECT * FROM \"readers\" GROUP BY \"name\" HAVING ((MIN(\"age\") > 18) AND (MAX(\"age\") < 50))")
    }
    
    
    // MARK: - Sort
    
    func testSortLiteral() {
        let dbQueue = try! makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.order(sql: "lower(name) desc")),
            "SELECT * FROM \"readers\" ORDER BY lower(name) desc")
    }
    
    func testSortLiteralWithPositionalArguments() {
        let dbQueue = try! makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.order(sql: "age + ?", arguments: [1])),
            "SELECT * FROM \"readers\" ORDER BY age + 1")
    }
    
    func testSortLiteralWithNamedArguments() {
        let dbQueue = try! makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.order(sql: "age + :age", arguments: ["age": 1])),
            "SELECT * FROM \"readers\" ORDER BY age + 1")
    }
    
    func testSort() {
        let dbQueue = try! makeDatabaseQueue()
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
    
    func testSortWithCollation() {
        let dbQueue = try! makeDatabaseQueue()
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
    
    func testMultipleSort() {
        let dbQueue = try! makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.order(Col.age).order(Col.name)),
            "SELECT * FROM \"readers\" ORDER BY \"name\"")
    }
    
    
    // MARK: - Reverse
    
    func testReverse() {
        let dbQueue = try! makeDatabaseQueue()
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
    
    func testReverseWithCollation() {
        let dbQueue = try! makeDatabaseQueue()
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
    
    func testMultipleReverse() {
        let dbQueue = try! makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.reversed().reversed()),
            "SELECT * FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.order(Col.age, Col.name).reversed().reversed()),
            "SELECT * FROM \"readers\" ORDER BY \"age\", \"name\"")
    }
    
    
    // MARK: - Limit
    
    func testLimit() {
        let dbQueue = try! makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.limit(1)),
            "SELECT * FROM \"readers\" LIMIT 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.limit(1, offset: 2)),
            "SELECT * FROM \"readers\" LIMIT 1 OFFSET 2")
    }
    
    func testMultipleLimit() {
        let dbQueue = try! makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.limit(1, offset: 2).limit(3)),
            "SELECT * FROM \"readers\" LIMIT 3")
    }
    
    
    // MARK: - Delete
    
    func testDelete() {
        assertNoError {
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
}

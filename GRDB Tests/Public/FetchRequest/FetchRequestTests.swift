import XCTest
import GRDB

private struct Col {
    static let id = SQLColumn("id")
    static let name = SQLColumn("name")
    static let age = SQLColumn("age")
    static let readerId = SQLColumn("readerId")
}

private let tableRequest = FetchRequest<Void>(tableName: "readers")

class FetchRequestTests: GRDBTestCase {

    var collation: DatabaseCollation!
    
    override func setUp() {
        super.setUp()
        
        collation = DatabaseCollation("localized_case_insensitive") { (lhs, rhs) in
            return (lhs as NSString).localizedCaseInsensitiveCompare(rhs)
        }
        dbQueue.inDatabase { db in
            db.addCollation(self.collation)
        }
        
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createReaders") { db in
            try db.execute(
                "CREATE TABLE readers (" +
                    "id INTEGER PRIMARY KEY, " +
                    "name TEXT NOT NULL, " +
                    "age INT" +
                ")")
        }
        try! migrator.migrate(dbQueue)
    }
    
    
    // MARK: - Fetch rows
    
    func testFetchRowFromRequest() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Arthur", 42])
                try db.execute("INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Barbara", 36])
                
                do {
                    let rows = Row.fetchAll(db, tableRequest)
                    XCTAssertEqual(self.lastSQLQuery, "SELECT * FROM \"readers\"")
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
                    XCTAssertEqual(self.lastSQLQuery, "SELECT * FROM \"readers\"")
                    XCTAssertEqual(row.value(named: "id") as Int64, 1)
                    XCTAssertEqual(row.value(named: "name") as String, "Arthur")
                    XCTAssertEqual(row.value(named: "age") as Int, 42)
                }
                
                do {
                    var names: [String] = []
                    for row in Row.fetch(db, tableRequest) {
                        names.append(row.value(named: "name"))
                    }
                    XCTAssertEqual(self.lastSQLQuery, "SELECT * FROM \"readers\"")
                    XCTAssertEqual(names, ["Arthur", "Barbara"])
                }
            }
        }
    }
    
    
    // MARK: - Count
    
    func testFetchCount() {
        assertNoError {
            try dbQueue.inDatabase { db in
                XCTAssertEqual(tableRequest.fetchCount(db), 0)
                XCTAssertEqual(self.lastSQLQuery, "SELECT COUNT(*) FROM \"readers\"")
                
                let readers: [(String, Int?)] = [
                    ("Arthur", 42),
                    ("Barbara", 36),
                    ("Craig", 42),
                    ("Craig", 42),
                    ("Daniel", nil)]
                for (name, age) in readers {
                    try db.execute("INSERT INTO readers (name, age) VALUES (?, ?)", arguments: [name, age])
                }
                
                XCTAssertEqual(tableRequest.fetchCount(db), 5)
                XCTAssertEqual(self.lastSQLQuery, "SELECT COUNT(*) FROM \"readers\"")
                
                XCTAssertEqual(tableRequest.filter(Col.age == 42).fetchCount(db), 3)
                XCTAssertEqual(self.lastSQLQuery, "SELECT COUNT(*) FROM \"readers\" WHERE (\"age\" = 42)")
                
                XCTAssertEqual(tableRequest.fetchCount(db, Col.age), 4)
                XCTAssertEqual(self.lastSQLQuery, "SELECT COUNT(\"age\") FROM \"readers\"")
                
                XCTAssertEqual(tableRequest.fetchCount(db, Col.age ?? 0), 5)
                XCTAssertEqual(self.lastSQLQuery, "SELECT COUNT(IFNULL(\"age\", 0)) FROM \"readers\"")
                
                XCTAssertEqual(tableRequest.fetchCount(db, distinct: Col.age), 2)
                XCTAssertEqual(self.lastSQLQuery, "SELECT COUNT(DISTINCT \"age\") FROM \"readers\"")
                
                XCTAssertEqual(tableRequest.fetchCount(db, distinct: Col.age / Col.age), 1)
                XCTAssertEqual(self.lastSQLQuery, "SELECT COUNT(DISTINCT (\"age\" / \"age\")) FROM \"readers\"")
            }
        }
    }
    
    
    // MARK: - Select
    
    func testSelectLiteral() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Arthur", 42])
                try db.execute("INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Barbara", 36])
                
                let request = tableRequest.select(sql: "name, id - 1")
                let rows = Row.fetchAll(db, request)
                XCTAssertEqual(self.lastSQLQuery, "SELECT name, id - 1 FROM \"readers\"")
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
            try dbQueue.inDatabase { db in
                try db.execute("INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Arthur", 42])
                try db.execute("INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Barbara", 36])
                
                let request = tableRequest.select(Col.name, Col.id - 1)
                let rows = Row.fetchAll(db, request)
                XCTAssertEqual(self.lastSQLQuery, "SELECT \"name\", (\"id\" - 1) FROM \"readers\"")
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
            try dbQueue.inDatabase { db in
                try db.execute("INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Arthur", 42])
                
                let request = tableRequest.select(Col.name.aliased("nom"), (Col.age + 1).aliased("agePlusOne"))
                let row = Row.fetchOne(db, request)!
                XCTAssertEqual(self.lastSQLQuery, "SELECT \"name\" AS \"nom\", (\"age\" + 1) AS \"agePlusOne\" FROM \"readers\"")
                XCTAssertEqual(row.value(named: "nom") as String, "Arthur")
                XCTAssertEqual(row.value(named: "agePlusOne") as Int, 43)
            }
        }
    }
    
    func testMultipleSelect() {
        XCTAssertEqual(
            sql(tableRequest.select(Col.age).select(Col.name)),
            "SELECT \"name\" FROM \"readers\"")
    }
    
    
    // MARK: - Distinct
    
    func testDistinct() {
        XCTAssertEqual(
            sql(tableRequest.select(Col.name).distinct),
            "SELECT DISTINCT \"name\" FROM \"readers\"")
    }
    
    
    // MARK: - Filter
    
    func testFilterLiteral() {
        XCTAssertEqual(
            sql(tableRequest.filter(sql: "id <> 1")),
            "SELECT * FROM \"readers\" WHERE id <> 1")
    }
    
    func testFilter() {
        XCTAssertEqual(
            sql(tableRequest.filter(true)),
            "SELECT * FROM \"readers\" WHERE 1")
    }

    func testMultipleFilter() {
        XCTAssertEqual(
            sql(tableRequest.filter(true).filter(false)),
            "SELECT * FROM \"readers\" WHERE (1 AND 0)")
    }
    
    
    // MARK: - Group
    
    func testGroupLiteral() {
        XCTAssertEqual(
            sql(tableRequest.group(sql: "age, lower(name)")),
            "SELECT * FROM \"readers\" GROUP BY age, lower(name)")
    }
    
    func testGroup() {
        XCTAssertEqual(
            sql(tableRequest.group(Col.age)),
            "SELECT * FROM \"readers\" GROUP BY \"age\"")
        XCTAssertEqual(
            sql(tableRequest.group(Col.age, Col.name)),
            "SELECT * FROM \"readers\" GROUP BY \"age\", \"name\"")
    }
    
    func testMultipleGroup() {
        XCTAssertEqual(
            sql(tableRequest.group(Col.age).group(Col.name)),
            "SELECT * FROM \"readers\" GROUP BY \"name\"")
    }
    
    
    // MARK: - Having
    
    func testHavingLiteral() {
        XCTAssertEqual(
            sql(tableRequest.group(Col.name).having(sql: "min(age) > 18")),
            "SELECT * FROM \"readers\" GROUP BY \"name\" HAVING min(age) > 18")
    }
    
    func testHaving() {
        XCTAssertEqual(
            sql(tableRequest.group(Col.name).having(min(Col.age) > 18)),
            "SELECT * FROM \"readers\" GROUP BY \"name\" HAVING (MIN(\"age\") > 18)")
    }
    
    func testMultipleHaving() {
        XCTAssertEqual(
            sql(tableRequest.group(Col.name).having(min(Col.age) > 18).having(max(Col.age) < 50)),
                "SELECT * FROM \"readers\" GROUP BY \"name\" HAVING ((MIN(\"age\") > 18) AND (MAX(\"age\") < 50))")
    }
    
    
    // MARK: - Sort
    
    func testSortLiteral() {
        XCTAssertEqual(
            sql(tableRequest.order(sql: "lower(age) desc")),
            "SELECT * FROM \"readers\" ORDER BY lower(age) desc")
    }
    
    func testSort() {
        XCTAssertEqual(
            sql(tableRequest.order(Col.age)),
            "SELECT * FROM \"readers\" ORDER BY \"age\"")
        XCTAssertEqual(
            sql(tableRequest.order(Col.age.asc)),
            "SELECT * FROM \"readers\" ORDER BY \"age\" ASC")
        XCTAssertEqual(
            sql(tableRequest.order(Col.age.desc)),
            "SELECT * FROM \"readers\" ORDER BY \"age\" DESC")
        XCTAssertEqual(
            sql(tableRequest.order(Col.age, Col.name.desc)),
            "SELECT * FROM \"readers\" ORDER BY \"age\", \"name\" DESC")
        XCTAssertEqual(
            sql(tableRequest.order(abs(Col.age))),
            "SELECT * FROM \"readers\" ORDER BY ABS(\"age\")")
    }
    
    func testSortWithCollation() {
        XCTAssertEqual(
            sql(tableRequest.order(Col.name.collating("NOCASE"))),
            "SELECT * FROM \"readers\" ORDER BY \"name\" COLLATE NOCASE")
        XCTAssertEqual(
            sql(tableRequest.order(Col.name.collating("NOCASE").asc)),
            "SELECT * FROM \"readers\" ORDER BY \"name\" COLLATE NOCASE ASC")
        XCTAssertEqual(
            sql(tableRequest.order(Col.name.collating(collation))),
            "SELECT * FROM \"readers\" ORDER BY \"name\" COLLATE localized_case_insensitive")
    }
    
    func testMultipleSort() {
        XCTAssertEqual(
            sql(tableRequest.order(Col.age).order(Col.name)),
            "SELECT * FROM \"readers\" ORDER BY \"age\", \"name\"")
    }
    
    
    // MARK: - Reverse
    
    func testReverse() {
        XCTAssertEqual(
            sql(tableRequest.reverse()),
            "SELECT * FROM \"readers\" ORDER BY \"id\" DESC")
        XCTAssertEqual(
            sql(tableRequest.order(Col.age).reverse()),
            "SELECT * FROM \"readers\" ORDER BY \"age\" DESC")
        XCTAssertEqual(
            sql(tableRequest.order(Col.age.asc).reverse()),
            "SELECT * FROM \"readers\" ORDER BY \"age\" DESC")
        XCTAssertEqual(
            sql(tableRequest.order(Col.age.desc).reverse()),
            "SELECT * FROM \"readers\" ORDER BY \"age\" ASC")
        XCTAssertEqual(
            sql(tableRequest.order(Col.age, Col.name.desc).reverse()),
            "SELECT * FROM \"readers\" ORDER BY \"age\" DESC, \"name\" ASC")
        XCTAssertEqual(
            sql(tableRequest.order(abs(Col.age)).reverse()),
            "SELECT * FROM \"readers\" ORDER BY ABS(\"age\") DESC")
    }
    
    func testReverseWithCollation() {
        XCTAssertEqual(
            sql(tableRequest.order(Col.name.collating("NOCASE")).reverse()),
            "SELECT * FROM \"readers\" ORDER BY \"name\" COLLATE NOCASE DESC")
        XCTAssertEqual(
            sql(tableRequest.order(Col.name.collating("NOCASE").asc).reverse()),
            "SELECT * FROM \"readers\" ORDER BY \"name\" COLLATE NOCASE DESC")
        XCTAssertEqual(
            sql(tableRequest.order(Col.name.collating(collation)).reverse()),
            "SELECT * FROM \"readers\" ORDER BY \"name\" COLLATE localized_case_insensitive DESC")
    }
    
    func testMultipleReverse() {
        XCTAssertEqual(
            sql(tableRequest.reverse().reverse()),
            "SELECT * FROM \"readers\"")
        XCTAssertEqual(
            sql(tableRequest.order(Col.age).order(Col.name).reverse().reverse()),
            "SELECT * FROM \"readers\" ORDER BY \"age\", \"name\"")
    }
    
    
    // MARK: - Limit
    
    func testLimit() {
        XCTAssertEqual(
            sql(tableRequest.limit(1)),
            "SELECT * FROM \"readers\" LIMIT 1")
        XCTAssertEqual(
            sql(tableRequest.limit(1, offset: 2)),
            "SELECT * FROM \"readers\" LIMIT 1 OFFSET 2")
    }
    
    func testMultipleLimit() {
        XCTAssertEqual(
            sql(tableRequest.limit(1, offset: 2).limit(3)),
            "SELECT * FROM \"readers\" LIMIT 3")
    }
}

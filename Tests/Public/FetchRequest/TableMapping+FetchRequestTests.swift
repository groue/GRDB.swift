import XCTest
import GRDB

private struct Col {
    static let id = SQLColumn("id")
    static let name = SQLColumn("name")
    static let age = SQLColumn("age")
    static let readerId = SQLColumn("readerId")
}

private struct Reader : TableMapping {
    static func databaseTableName() -> String {
        return "readers"
    }
}


class TableMappingFetchRequestTests: GRDBTestCase {
    
    override func setUp() {
        super.setUp()
        
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
    
    
    // MARK: - Count
    
    func testFetchCount() {
        dbQueue.inDatabase { db in
            XCTAssertEqual(Reader.fetchCount(db), 0)
            XCTAssertEqual(self.lastSQLQuery, "SELECT COUNT(*) FROM \"readers\"")
            
            XCTAssertEqual(Reader.all().reverse().fetchCount(db), 0)
            XCTAssertEqual(self.lastSQLQuery, "SELECT COUNT(*) FROM \"readers\"")
            
            XCTAssertEqual(Reader.order(Col.name).fetchCount(db), 0)
            XCTAssertEqual(self.lastSQLQuery, "SELECT COUNT(*) FROM \"readers\"")
            
            XCTAssertEqual(Reader.limit(10).fetchCount(db), 0)
            XCTAssertEqual(self.lastSQLQuery, "SELECT COUNT(*) FROM (SELECT * FROM \"readers\" LIMIT 10)")
            
            XCTAssertEqual(Reader.filter(Col.age == 42).fetchCount(db), 0)
            XCTAssertEqual(self.lastSQLQuery, "SELECT COUNT(*) FROM \"readers\" WHERE (\"age\" = 42)")
            
            XCTAssertEqual(Reader.all().distinct.fetchCount(db), 0)
            XCTAssertEqual(self.lastSQLQuery, "SELECT COUNT(*) FROM (SELECT DISTINCT * FROM \"readers\")")
            
            XCTAssertEqual(Reader.select(Col.name).fetchCount(db), 0)
            XCTAssertEqual(self.lastSQLQuery, "SELECT COUNT(*) FROM \"readers\"")
            
            XCTAssertEqual(Reader.select(Col.name).distinct.fetchCount(db), 0)
            XCTAssertEqual(self.lastSQLQuery, "SELECT COUNT(DISTINCT \"name\") FROM \"readers\"")
            
            XCTAssertEqual(Reader.select(Col.age * 2).distinct.fetchCount(db), 0)
            XCTAssertEqual(self.lastSQLQuery, "SELECT COUNT(DISTINCT (\"age\" * 2)) FROM \"readers\"")
            
            XCTAssertEqual(Reader.select((Col.age * 2).aliased("ignored")).distinct.fetchCount(db), 0)
            XCTAssertEqual(self.lastSQLQuery, "SELECT COUNT(DISTINCT (\"age\" * 2)) FROM \"readers\"")
            
            XCTAssertEqual(Reader.select(Col.name, Col.age).fetchCount(db), 0)
            XCTAssertEqual(self.lastSQLQuery, "SELECT COUNT(*) FROM \"readers\"")
            
            XCTAssertEqual(Reader.select(Col.name, Col.age).distinct.fetchCount(db), 0)
            XCTAssertEqual(self.lastSQLQuery, "SELECT COUNT(*) FROM (SELECT DISTINCT \"name\", \"age\" FROM \"readers\")")
            
            XCTAssertEqual(Reader.select(max(Col.age)).group(Col.name).fetchCount(db), 0)
            XCTAssertEqual(self.lastSQLQuery, "SELECT COUNT(*) FROM (SELECT MAX(\"age\") FROM \"readers\" GROUP BY \"name\")")
        }
    }
    
    
    // MARK: - Select
    
    func testSelectLiteral() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Arthur", 42])
                try db.execute("INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Barbara", 36])
                
                let request = Reader.select(sql: "name, id - 1")
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
                
                let request = Reader.select(Col.name, Col.id - 1)
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
    
    func testMultipleSelect() {
        XCTAssertEqual(
            sql(Reader.select(Col.age).select(Col.name)),
            "SELECT \"name\" FROM \"readers\"")
    }
    
    
    // MARK: - Filter
    
    func testFilterLiteral() {
        XCTAssertEqual(
            sql(Reader.filter(sql: "id <> 1")),
            "SELECT * FROM \"readers\" WHERE id <> 1")
    }
    
    func testFilter() {
        XCTAssertEqual(
            sql(Reader.filter(true)),
            "SELECT * FROM \"readers\" WHERE 1")
    }
    
    func testMultipleFilter() {
        XCTAssertEqual(
            sql(Reader.filter(true).filter(false)),
            "SELECT * FROM \"readers\" WHERE (1 AND 0)")
    }
    
    
    // MARK: - Sort
    
    func testSortLiteral() {
        XCTAssertEqual(
            sql(Reader.order(sql: "lower(age) desc")),
            "SELECT * FROM \"readers\" ORDER BY lower(age) desc")
    }
    
    func testSort() {
        XCTAssertEqual(
            sql(Reader.order(Col.age)),
            "SELECT * FROM \"readers\" ORDER BY \"age\"")
        XCTAssertEqual(
            sql(Reader.order(Col.age.asc)),
            "SELECT * FROM \"readers\" ORDER BY \"age\" ASC")
        XCTAssertEqual(
            sql(Reader.order(Col.age.desc)),
            "SELECT * FROM \"readers\" ORDER BY \"age\" DESC")
        XCTAssertEqual(
            sql(Reader.order(Col.age, Col.name.desc)),
            "SELECT * FROM \"readers\" ORDER BY \"age\", \"name\" DESC")
        XCTAssertEqual(
            sql(Reader.order(abs(Col.age))),
            "SELECT * FROM \"readers\" ORDER BY ABS(\"age\")")
    }
    
    func testMultipleSort() {
        XCTAssertEqual(
            sql(Reader.order(Col.age).order(Col.name)),
            "SELECT * FROM \"readers\" ORDER BY \"age\", \"name\"")
    }
    
    
    // MARK: - Limit
    
    func testLimit() {
        XCTAssertEqual(
            sql(Reader.limit(1)),
            "SELECT * FROM \"readers\" LIMIT 1")
        XCTAssertEqual(
            sql(Reader.limit(1, offset: 2)),
            "SELECT * FROM \"readers\" LIMIT 1 OFFSET 2")
    }
    
    func testMultipleLimit() {
        XCTAssertEqual(
            sql(Reader.limit(1, offset: 2).limit(3)),
            "SELECT * FROM \"readers\" LIMIT 3")
    }
}

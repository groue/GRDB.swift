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

class SQLSupportTests: GRDBTestCase {
    
    var collation: DatabaseCollation!
    var customFunction: DatabaseFunction!
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
        collation = DatabaseCollation("localized_case_insensitive") { (lhs, rhs) in
            return (lhs as NSString).localizedCaseInsensitiveCompare(rhs)
        }
        dbWriter.add(collation: collation)
        
        customFunction = DatabaseFunction("avgOf", pure: true) { databaseValues in
            let sum = databaseValues.flatMap { $0.value() as Int? }.reduce(0, +)
            return Double(sum) / Double(databaseValues.count)
        }
        dbWriter.add(function: self.customFunction)
        
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
    
    
    // MARK: - Boolean expressions
    
    func testContains() {
        let dbQueue = try! makeDatabaseQueue()
        
        // emptyArray.contains(): 0
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter([Int]().contains(Col.id))),
            "SELECT * FROM \"readers\" WHERE 0")
        
        // Array.contains(): IN operator
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter([1,2,3].contains(Col.id))),
            "SELECT * FROM \"readers\" WHERE (\"id\" IN (1, 2, 3))")
        
        // Array.contains(): IN operator
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter([Col.id].contains(Col.id))),
            "SELECT * FROM \"readers\" WHERE (\"id\" IN (\"id\"))")
        
        // Sequence.contains(): IN operator
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(AnySequence([1,2,3]).contains(Col.id))),
            "SELECT * FROM \"readers\" WHERE (\"id\" IN (1, 2, 3))")
        
        // Sequence.contains(): IN operator
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(AnySequence([Col.id]).contains(Col.id))),
            "SELECT * FROM \"readers\" WHERE (\"id\" IN (\"id\"))")
        
        // !Sequence.contains(): NOT IN operator
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(![1,2,3].contains(Col.id))),
            "SELECT * FROM \"readers\" WHERE (\"id\" NOT IN (1, 2, 3))")
        
        // !!Sequence.contains(): IN operator
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(![1,2,3].contains(Col.id)))),
            "SELECT * FROM \"readers\" WHERE (\"id\" IN (1, 2, 3))")
        
        // Range.contains(): BETWEEN operator
        do {
            let range = 1..<10
            XCTAssertEqual(
                sql(dbQueue, tableRequest.filter(range.contains(Col.id))),
                "SELECT * FROM \"readers\" WHERE (\"id\" BETWEEN 1 AND 9)")
        }
        
        // Range.contains(): BETWEEN operator
        do {
            let range = 1...10
            XCTAssertEqual(
                sql(dbQueue, tableRequest.filter(range.contains(Col.id))),
                "SELECT * FROM \"readers\" WHERE (\"id\" BETWEEN 1 AND 10)")
        }
        
        // ClosedInterval: BETWEEN operator
        do {
            let closedInterval = "A"..."z"
            XCTAssertEqual(
                sql(dbQueue, tableRequest.filter(closedInterval.contains(Col.name))),
                "SELECT * FROM \"readers\" WHERE (\"name\" BETWEEN 'A' AND 'z')")
        }
        
        // HalfOpenInterval:  min <= x < max
        do {
            let halfOpenInterval = "A"..<"z"
            XCTAssertEqual(
                sql(dbQueue, tableRequest.filter(halfOpenInterval.contains(Col.name))),
                "SELECT * FROM \"readers\" WHERE ((\"name\" >= 'A') AND (\"name\" < 'z'))")
        }
        
        // Subquery
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(tableRequest.select(Col.id).contains(Col.id))),
            "SELECT * FROM \"readers\" WHERE (\"id\" IN (SELECT \"id\" FROM \"readers\"))")
        
        // Subquery
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!tableRequest.select(Col.id).contains(Col.id))),
            "SELECT * FROM \"readers\" WHERE (\"id\" NOT IN (SELECT \"id\" FROM \"readers\"))")
    }
    
    func testContainsWithCollation() {
        let dbQueue = try! makeDatabaseQueue()
        
        // Array.contains(): IN operator
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(["arthur", "barbara"].contains(Col.name.collating(.nocase)))),
            "SELECT * FROM \"readers\" WHERE (\"name\" IN ('arthur', 'barbara') COLLATE NOCASE)")
        
        // Sequence.contains(): IN operator
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(AnySequence(["arthur", "barbara"]).contains(Col.name.collating(.nocase)))),
            "SELECT * FROM \"readers\" WHERE (\"name\" IN ('arthur', 'barbara') COLLATE NOCASE)")
        
        // Sequence.contains(): IN operator
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(AnySequence([Col.name]).contains(Col.name.collating(.nocase)))),
            "SELECT * FROM \"readers\" WHERE (\"name\" IN (\"name\") COLLATE NOCASE)")
        
        // ClosedInterval: BETWEEN operator
        let closedInterval = "A"..."z"
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(closedInterval.contains(Col.name.collating(.nocase)))),
            "SELECT * FROM \"readers\" WHERE (\"name\" BETWEEN 'A' AND 'z' COLLATE NOCASE)")
        
        // HalfOpenInterval:  min <= x < max
        let halfOpenInterval = "A"..<"z"
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(halfOpenInterval.contains(Col.name.collating(.nocase)))),
            "SELECT * FROM \"readers\" WHERE ((\"name\" >= 'A' COLLATE NOCASE) AND (\"name\" < 'z' COLLATE NOCASE))")
    }
    
    func testGreaterThan() {
        let dbQueue = try! makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age > 10)),
            "SELECT * FROM \"readers\" WHERE (\"age\" > 10)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(10 > Col.age)),
            "SELECT * FROM \"readers\" WHERE (10 > \"age\")")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(10 > 10)),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age > Col.age)),
            "SELECT * FROM \"readers\" WHERE (\"age\" > \"age\")")
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name > "B")),
            "SELECT * FROM \"readers\" WHERE (\"name\" > 'B')")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter("B" > Col.name)),
            "SELECT * FROM \"readers\" WHERE ('B' > \"name\")")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter("B" > "B")),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name > Col.name)),
            "SELECT * FROM \"readers\" WHERE (\"name\" > \"name\")")
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.group(Col.name).having(average(Col.age) + 10 > 20)),
            "SELECT * FROM \"readers\" GROUP BY \"name\" HAVING ((AVG(\"age\") + 10) > 20)")
    }
    
    func testGreaterThanWithCollation() {
        let dbQueue = try! makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name.collating(.nocase) > "fOo")),
            "SELECT * FROM \"readers\" WHERE (\"name\" > 'fOo' COLLATE NOCASE)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name.collating(collation) > "fOo")),
            "SELECT * FROM \"readers\" WHERE (\"name\" > 'fOo' COLLATE localized_case_insensitive)")
    }
    
    func testGreaterThanOrEqual() {
        let dbQueue = try! makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age >= 10)),
            "SELECT * FROM \"readers\" WHERE (\"age\" >= 10)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(10 >= Col.age)),
            "SELECT * FROM \"readers\" WHERE (10 >= \"age\")")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(10 >= 10)),
            "SELECT * FROM \"readers\" WHERE 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age >= Col.age)),
            "SELECT * FROM \"readers\" WHERE (\"age\" >= \"age\")")
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name >= "B")),
            "SELECT * FROM \"readers\" WHERE (\"name\" >= 'B')")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter("B" >= Col.name)),
            "SELECT * FROM \"readers\" WHERE ('B' >= \"name\")")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter("B" >= "B")),
            "SELECT * FROM \"readers\" WHERE 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name >= Col.name)),
            "SELECT * FROM \"readers\" WHERE (\"name\" >= \"name\")")
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.group(Col.name).having(average(Col.age) + 10 >= 20)),
            "SELECT * FROM \"readers\" GROUP BY \"name\" HAVING ((AVG(\"age\") + 10) >= 20)")
    }
    
    func testGreaterThanOrEqualWithCollation() {
        let dbQueue = try! makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name.collating(.nocase) >= "fOo")),
            "SELECT * FROM \"readers\" WHERE (\"name\" >= 'fOo' COLLATE NOCASE)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name.collating(collation) >= "fOo")),
            "SELECT * FROM \"readers\" WHERE (\"name\" >= 'fOo' COLLATE localized_case_insensitive)")
    }
    
    func testLessThan() {
        let dbQueue = try! makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age < 10)),
            "SELECT * FROM \"readers\" WHERE (\"age\" < 10)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(10 < Col.age)),
            "SELECT * FROM \"readers\" WHERE (10 < \"age\")")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(10 < 10)),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age < Col.age)),
            "SELECT * FROM \"readers\" WHERE (\"age\" < \"age\")")
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name < "B")),
            "SELECT * FROM \"readers\" WHERE (\"name\" < 'B')")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter("B" < Col.name)),
            "SELECT * FROM \"readers\" WHERE ('B' < \"name\")")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter("B" < "B")),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name < Col.name)),
            "SELECT * FROM \"readers\" WHERE (\"name\" < \"name\")")
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.group(Col.name).having(average(Col.age) + 10 < 20)),
            "SELECT * FROM \"readers\" GROUP BY \"name\" HAVING ((AVG(\"age\") + 10) < 20)")
    }
    
    func testLessThanWithCollation() {
        let dbQueue = try! makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name.collating(.nocase) < "fOo")),
            "SELECT * FROM \"readers\" WHERE (\"name\" < 'fOo' COLLATE NOCASE)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name.collating(collation) < "fOo")),
            "SELECT * FROM \"readers\" WHERE (\"name\" < 'fOo' COLLATE localized_case_insensitive)")
    }
    
    func testLessThanOrEqual() {
        let dbQueue = try! makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age <= 10)),
            "SELECT * FROM \"readers\" WHERE (\"age\" <= 10)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(10 <= Col.age)),
            "SELECT * FROM \"readers\" WHERE (10 <= \"age\")")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(10 <= 10)),
            "SELECT * FROM \"readers\" WHERE 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age <= Col.age)),
            "SELECT * FROM \"readers\" WHERE (\"age\" <= \"age\")")
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name <= "B")),
            "SELECT * FROM \"readers\" WHERE (\"name\" <= 'B')")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter("B" <= Col.name)),
            "SELECT * FROM \"readers\" WHERE ('B' <= \"name\")")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter("B" <= "B")),
            "SELECT * FROM \"readers\" WHERE 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name <= Col.name)),
            "SELECT * FROM \"readers\" WHERE (\"name\" <= \"name\")")
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.group(Col.name).having(average(Col.age) + 10 <= 20)),
            "SELECT * FROM \"readers\" GROUP BY \"name\" HAVING ((AVG(\"age\") + 10) <= 20)")
    }
    
    func testLessThanOrEqualWithCollation() {
        let dbQueue = try! makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name.collating(.nocase) <= "fOo")),
            "SELECT * FROM \"readers\" WHERE (\"name\" <= 'fOo' COLLATE NOCASE)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name.collating(collation) <= "fOo")),
            "SELECT * FROM \"readers\" WHERE (\"name\" <= 'fOo' COLLATE localized_case_insensitive)")
    }
    
    func testEqual() {
        let dbQueue = try! makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age == 10)),
            "SELECT * FROM \"readers\" WHERE (\"age\" = 10)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age == (10 as Int?))),
            "SELECT * FROM \"readers\" WHERE (\"age\" = 10)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(10 == Col.age)),
            "SELECT * FROM \"readers\" WHERE (10 = \"age\")")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter((10 as Int?) == Col.age)),
            "SELECT * FROM \"readers\" WHERE (10 = \"age\")")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(10 == 10)),
            "SELECT * FROM \"readers\" WHERE 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age == Col.age)),
            "SELECT * FROM \"readers\" WHERE (\"age\" = \"age\")")
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age == nil)),
            "SELECT * FROM \"readers\" WHERE (\"age\" IS NULL)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(nil == Col.age)),
            "SELECT * FROM \"readers\" WHERE (\"age\" IS NULL)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age == Col.age)),
            "SELECT * FROM \"readers\" WHERE (\"age\" = \"age\")")
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name == "B")),
            "SELECT * FROM \"readers\" WHERE (\"name\" = 'B')")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter("B" == Col.name)),
            "SELECT * FROM \"readers\" WHERE ('B' = \"name\")")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter("B" == "B")),
            "SELECT * FROM \"readers\" WHERE 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name == Col.name)),
            "SELECT * FROM \"readers\" WHERE (\"name\" = \"name\")")
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age == true)),
            "SELECT * FROM \"readers\" WHERE \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(true == Col.age)),
            "SELECT * FROM \"readers\" WHERE \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age == false)),
            "SELECT * FROM \"readers\" WHERE NOT \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(false == Col.age)),
            "SELECT * FROM \"readers\" WHERE NOT \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(true == true)),
            "SELECT * FROM \"readers\" WHERE 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(false == false)),
            "SELECT * FROM \"readers\" WHERE 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(true == false)),
            "SELECT * FROM \"readers\" WHERE 0")
    }
    
    func testEqualWithCollation() {
        let dbQueue = try! makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name.collating(.nocase) == "fOo")),
            "SELECT * FROM \"readers\" WHERE (\"name\" = 'fOo' COLLATE NOCASE)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name.collating(.nocase) == ("fOo" as String?))),
            "SELECT * FROM \"readers\" WHERE (\"name\" = 'fOo' COLLATE NOCASE)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name.collating(.nocase) == nil)),
            "SELECT * FROM \"readers\" WHERE (\"name\" IS NULL COLLATE NOCASE)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name.collating(collation) == "fOo")),
            "SELECT * FROM \"readers\" WHERE (\"name\" = 'fOo' COLLATE localized_case_insensitive)")
    }
    
    func testNotEqual() {
        let dbQueue = try! makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age != 10)),
            "SELECT * FROM \"readers\" WHERE (\"age\" <> 10)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age != (10 as Int?))),
            "SELECT * FROM \"readers\" WHERE (\"age\" <> 10)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(10 != Col.age)),
            "SELECT * FROM \"readers\" WHERE (10 <> \"age\")")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter((10 as Int?) != Col.age)),
            "SELECT * FROM \"readers\" WHERE (10 <> \"age\")")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(10 != 10)),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age != Col.age)),
            "SELECT * FROM \"readers\" WHERE (\"age\" <> \"age\")")
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age != nil)),
            "SELECT * FROM \"readers\" WHERE (\"age\" IS NOT NULL)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(nil != Col.age)),
            "SELECT * FROM \"readers\" WHERE (\"age\" IS NOT NULL)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age != Col.age)),
            "SELECT * FROM \"readers\" WHERE (\"age\" <> \"age\")")
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name != "B")),
            "SELECT * FROM \"readers\" WHERE (\"name\" <> 'B')")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter("B" != Col.name)),
            "SELECT * FROM \"readers\" WHERE ('B' <> \"name\")")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter("B" != "B")),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name != Col.name)),
            "SELECT * FROM \"readers\" WHERE (\"name\" <> \"name\")")
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age != true)),
            "SELECT * FROM \"readers\" WHERE NOT \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(true != Col.age)),
            "SELECT * FROM \"readers\" WHERE NOT \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age != false)),
            "SELECT * FROM \"readers\" WHERE \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(false != Col.age)),
            "SELECT * FROM \"readers\" WHERE \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(true != true)),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(false != false)),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(true != false)),
            "SELECT * FROM \"readers\" WHERE 1")
    }
    
    func testNotEqualWithCollation() {
        let dbQueue = try! makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name.collating(.nocase) != "fOo")),
            "SELECT * FROM \"readers\" WHERE (\"name\" <> 'fOo' COLLATE NOCASE)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name.collating(.nocase) != ("fOo" as String?))),
            "SELECT * FROM \"readers\" WHERE (\"name\" <> 'fOo' COLLATE NOCASE)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name.collating(.nocase) != nil)),
            "SELECT * FROM \"readers\" WHERE (\"name\" IS NOT NULL COLLATE NOCASE)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name.collating(collation) != "fOo")),
            "SELECT * FROM \"readers\" WHERE (\"name\" <> 'fOo' COLLATE localized_case_insensitive)")
    }
    
    func testNotEqualWithSwiftNotOperator() {
        let dbQueue = try! makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(Col.age == 10))),
            "SELECT * FROM \"readers\" WHERE (\"age\" <> 10)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(10 == Col.age))),
            "SELECT * FROM \"readers\" WHERE (10 <> \"age\")")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(10 == 10))),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(Col.age == Col.age))),
            "SELECT * FROM \"readers\" WHERE (\"age\" <> \"age\")")
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(Col.age == nil))),
            "SELECT * FROM \"readers\" WHERE (\"age\" IS NOT NULL)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(nil == Col.age))),
            "SELECT * FROM \"readers\" WHERE (\"age\" IS NOT NULL)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(Col.age == Col.age))),
            "SELECT * FROM \"readers\" WHERE (\"age\" <> \"age\")")
    }
    
    func testIs() {
        let dbQueue = try! makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age === 10)),
            "SELECT * FROM \"readers\" WHERE (\"age\" IS 10)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(10 === Col.age)),
            "SELECT * FROM \"readers\" WHERE (10 IS \"age\")")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age === Col.age)),
            "SELECT * FROM \"readers\" WHERE (\"age\" IS \"age\")")
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age === nil)),
            "SELECT * FROM \"readers\" WHERE (\"age\" IS NULL)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(nil === Col.age)),
            "SELECT * FROM \"readers\" WHERE (\"age\" IS NULL)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age === Col.age)),
            "SELECT * FROM \"readers\" WHERE (\"age\" IS \"age\")")
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name === "B")),
            "SELECT * FROM \"readers\" WHERE (\"name\" IS 'B')")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter("B" === Col.name)),
            "SELECT * FROM \"readers\" WHERE ('B' IS \"name\")")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name === Col.name)),
            "SELECT * FROM \"readers\" WHERE (\"name\" IS \"name\")")
    }
    
    func testIsWithCollation() {
        let dbQueue = try! makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name.collating(.nocase) === "fOo")),
            "SELECT * FROM \"readers\" WHERE (\"name\" IS 'fOo' COLLATE NOCASE)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name.collating(collation) === "fOo")),
            "SELECT * FROM \"readers\" WHERE (\"name\" IS 'fOo' COLLATE localized_case_insensitive)")
    }
    
    func testIsNot() {
        let dbQueue = try! makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age !== 10)),
            "SELECT * FROM \"readers\" WHERE (\"age\" IS NOT 10)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(10 !== Col.age)),
            "SELECT * FROM \"readers\" WHERE (10 IS NOT \"age\")")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age !== Col.age)),
            "SELECT * FROM \"readers\" WHERE (\"age\" IS NOT \"age\")")
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age !== nil)),
            "SELECT * FROM \"readers\" WHERE (\"age\" IS NOT NULL)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(nil !== Col.age)),
            "SELECT * FROM \"readers\" WHERE (\"age\" IS NOT NULL)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age !== Col.age)),
            "SELECT * FROM \"readers\" WHERE (\"age\" IS NOT \"age\")")
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name !== "B")),
            "SELECT * FROM \"readers\" WHERE (\"name\" IS NOT 'B')")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter("B" !== Col.name)),
            "SELECT * FROM \"readers\" WHERE ('B' IS NOT \"name\")")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name !== Col.name)),
            "SELECT * FROM \"readers\" WHERE (\"name\" IS NOT \"name\")")
    }
    
    func testIsNotWithCollation() {
        let dbQueue = try! makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name.collating(.nocase) !== "fOo")),
            "SELECT * FROM \"readers\" WHERE (\"name\" IS NOT 'fOo' COLLATE NOCASE)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name.collating(collation) !== "fOo")),
            "SELECT * FROM \"readers\" WHERE (\"name\" IS NOT 'fOo' COLLATE localized_case_insensitive)")
    }
    
    func testIsNotWithSwiftNotOperator() {
        let dbQueue = try! makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(Col.age === 10))),
            "SELECT * FROM \"readers\" WHERE (\"age\" IS NOT 10)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(10 === Col.age))),
            "SELECT * FROM \"readers\" WHERE (10 IS NOT \"age\")")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(Col.age === Col.age))),
            "SELECT * FROM \"readers\" WHERE (\"age\" IS NOT \"age\")")
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(Col.age === nil))),
            "SELECT * FROM \"readers\" WHERE (\"age\" IS NOT NULL)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(nil === Col.age))),
            "SELECT * FROM \"readers\" WHERE (\"age\" IS NOT NULL)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(Col.age === Col.age))),
            "SELECT * FROM \"readers\" WHERE (\"age\" IS NOT \"age\")")
    }
    
    func testExists() {
        let dbQueue = try! makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(tableRequest.exists())),
            "SELECT * FROM \"readers\" WHERE (EXISTS (SELECT * FROM \"readers\"))")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!tableRequest.exists())),
            "SELECT * FROM \"readers\" WHERE (NOT EXISTS (SELECT * FROM \"readers\"))")
    }
    
    func testLogicalOperators() {
        let dbQueue = try! makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!Col.age)),
            "SELECT * FROM \"readers\" WHERE NOT \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age && true)),
            "SELECT * FROM \"readers\" WHERE (\"age\" AND 1)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(true && Col.age)),
            "SELECT * FROM \"readers\" WHERE (1 AND \"age\")")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age || false)),
            "SELECT * FROM \"readers\" WHERE (\"age\" OR 0)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(false || Col.age)),
            "SELECT * FROM \"readers\" WHERE (0 OR \"age\")")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age != nil || Col.name != nil)),
            "SELECT * FROM \"readers\" WHERE ((\"age\" IS NOT NULL) OR (\"name\" IS NOT NULL))")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age != nil || Col.name != nil && Col.id != nil)),
            "SELECT * FROM \"readers\" WHERE ((\"age\" IS NOT NULL) OR ((\"name\" IS NOT NULL) AND (\"id\" IS NOT NULL)))")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter((Col.age != nil || Col.name != nil) && Col.id != nil)),
            "SELECT * FROM \"readers\" WHERE (((\"age\" IS NOT NULL) OR (\"name\" IS NOT NULL)) AND (\"id\" IS NOT NULL))")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(Col.age > 18) && !(Col.name > "foo"))),
            "SELECT * FROM \"readers\" WHERE (NOT (\"age\" > 18) AND NOT (\"name\" > 'foo'))")
    }
    
    
    // MARK: - String functions
    
    func testStringFunctions() {
        let dbQueue = try! makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(Col.name.capitalized)),
            "SELECT swiftCapitalizedString(\"name\") FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(Col.name.lowercased)),
            "SELECT swiftLowercaseString(\"name\") FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(Col.name.uppercased)),
            "SELECT swiftUppercaseString(\"name\") FROM \"readers\"")
        
        if #available(iOS 9.0, OSX 10.11, *) {
            XCTAssertEqual(
                sql(dbQueue, tableRequest.select(Col.name.localizedCapitalized)),
                "SELECT swiftLocalizedCapitalizedString(\"name\") FROM \"readers\"")
            XCTAssertEqual(
                sql(dbQueue, tableRequest.select(Col.name.localizedLowercased)),
                "SELECT swiftLocalizedLowercaseString(\"name\") FROM \"readers\"")
            XCTAssertEqual(
                sql(dbQueue, tableRequest.select(Col.name.localizedUppercased)),
                "SELECT swiftLocalizedUppercaseString(\"name\") FROM \"readers\"")
        }
    }
    
    
    // MARK: - Arithmetic expressions
    
    func testPrefixMinusOperator() {
        let dbQueue = try! makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(-Col.age)),
            "SELECT * FROM \"readers\" WHERE -\"age\"")
    }
    
    func testInfixMinusOperator() {
        let dbQueue = try! makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age - 2)),
            "SELECT * FROM \"readers\" WHERE (\"age\" - 2)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(2 - Col.age)),
            "SELECT * FROM \"readers\" WHERE (2 - \"age\")")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(2 - 2)),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age - Col.age)),
            "SELECT * FROM \"readers\" WHERE (\"age\" - \"age\")")
    }
    
    func testInfixPlusOperator() {
        let dbQueue = try! makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age + 2)),
            "SELECT * FROM \"readers\" WHERE (\"age\" + 2)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(2 + Col.age)),
            "SELECT * FROM \"readers\" WHERE (2 + \"age\")")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(2 + 2)),
            "SELECT * FROM \"readers\" WHERE 4")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age + Col.age)),
            "SELECT * FROM \"readers\" WHERE (\"age\" + \"age\")")
    }
    
    func testInfixMultiplyOperator() {
        let dbQueue = try! makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age * 2)),
            "SELECT * FROM \"readers\" WHERE (\"age\" * 2)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(2 * Col.age)),
            "SELECT * FROM \"readers\" WHERE (2 * \"age\")")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(2 * 2)),
            "SELECT * FROM \"readers\" WHERE 4")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age * Col.age)),
            "SELECT * FROM \"readers\" WHERE (\"age\" * \"age\")")
    }
    
    func testInfixDivideOperator() {
        let dbQueue = try! makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age / 2)),
            "SELECT * FROM \"readers\" WHERE (\"age\" / 2)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(2 / Col.age)),
            "SELECT * FROM \"readers\" WHERE (2 / \"age\")")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(2 / 2)),
            "SELECT * FROM \"readers\" WHERE 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age / Col.age)),
            "SELECT * FROM \"readers\" WHERE (\"age\" / \"age\")")
    }
    
    func testCompoundArithmeticExpression() {
        let dbQueue = try! makeDatabaseQueue()
        
        // Int / Double
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age / 2.0)),
            "SELECT * FROM \"readers\" WHERE (\"age\" / 2.0)")
        // Double / Int
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(2.0 / Col.age)),
            "SELECT * FROM \"readers\" WHERE (2.0 / \"age\")")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age + 2 * 5)),
            "SELECT * FROM \"readers\" WHERE (\"age\" + 10)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age * 2 + 5)),
            "SELECT * FROM \"readers\" WHERE ((\"age\" * 2) + 5)")
    }
    
    
    // MARK: - IFNULL expression
    
    func testIfNull() {
        let dbQueue = try! makeDatabaseQueue()
        
        var optInt: Int? = nil
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age ?? 2)),
            "SELECT * FROM \"readers\" WHERE IFNULL(\"age\", 2)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(optInt ?? Col.age)),
            "SELECT * FROM \"readers\" WHERE \"age\"")
        optInt = 1
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(optInt ?? Col.age)),
            "SELECT * FROM \"readers\" WHERE 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age ?? Col.age)),
            "SELECT * FROM \"readers\" WHERE IFNULL(\"age\", \"age\")")
    }
    
    
    // MARK: - Aggregated expressions
    
    func testCountExpression() {
        let dbQueue = try! makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(count(Col.age))),
            "SELECT COUNT(\"age\") FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(count(Col.age ?? 0))),
            "SELECT COUNT(IFNULL(\"age\", 0)) FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(count(distinct: Col.age))),
            "SELECT COUNT(DISTINCT \"age\") FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(count(distinct: Col.age / Col.age))),
            "SELECT COUNT(DISTINCT (\"age\" / \"age\")) FROM \"readers\"")
    }
    
    func testAvgExpression() {
        let dbQueue = try! makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(average(Col.age))),
            "SELECT AVG(\"age\") FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(average(Col.age / 2))),
            "SELECT AVG((\"age\" / 2)) FROM \"readers\"")
    }
    
    func testLengthExpression() {
        let dbQueue = try! makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(length(Col.name))),
            "SELECT LENGTH(\"name\") FROM \"readers\"")
    }
    
    func testMinExpression() {
        let dbQueue = try! makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(min(Col.age))),
            "SELECT MIN(\"age\") FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(min(Col.age / 2))),
            "SELECT MIN((\"age\" / 2)) FROM \"readers\"")
    }
    
    func testMaxExpression() {
        let dbQueue = try! makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(max(Col.age))),
            "SELECT MAX(\"age\") FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(max(Col.age / 2))),
            "SELECT MAX((\"age\" / 2)) FROM \"readers\"")
    }
    
    func testSumExpression() {
        let dbQueue = try! makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(sum(Col.age))),
            "SELECT SUM(\"age\") FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(sum(Col.age / 2))),
            "SELECT SUM((\"age\" / 2)) FROM \"readers\"")
    }
    
    
    // MARK: - LIKE operator
    
    func testLikeOperator() {
        let dbQueue = try! makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name.like("%foo"))),
            "SELECT * FROM \"readers\" WHERE (\"name\" LIKE '%foo')")
    }
    
    
    // MARK: - Function
    
    func testCustomFunction() {
        let dbQueue = try! makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(customFunction.apply(Col.age, 1, 2))),
            "SELECT avgOf(\"age\", 1, 2) FROM \"readers\"")
    }
}

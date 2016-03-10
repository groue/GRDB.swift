import XCTest
import GRDB

private struct Col {
    static let id = SQLColumn("id")
    static let name = SQLColumn("name")
    static let age = SQLColumn("age")
    static let readerId = SQLColumn("readerId")
}

private let tableRequest = FetchRequest<Void>(tableName: "readers")

class SQLSupportTests: GRDBTestCase {
    
    var collation: DatabaseCollation!
    var customFunction: DatabaseFunction!
    
    override func setUp() {
        super.setUp()
        
        collation = DatabaseCollation("localized_case_insensitive") { (lhs, rhs) in
            return (lhs as NSString).localizedCaseInsensitiveCompare(rhs)
        }
        dbQueue.addCollation(collation)
        
        customFunction = DatabaseFunction("avgOf", pure: true) { databaseValues in
            let sum = databaseValues.flatMap { $0.value() as Int? }.reduce(0, combine: +)
            return Double(sum) / Double(databaseValues.count)
        }
        dbQueue.addFunction(self.customFunction)
        
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
    
    
    // MARK: - Boolean expressions
    
    func testContains() {
        // emptyArray.contains(): 0
        XCTAssertEqual(
            sql(tableRequest.filter([Int]().contains(Col.id))),
            "SELECT * FROM \"readers\" WHERE 0")
        
        // Array.contains(): IN operator
        XCTAssertEqual(
            sql(tableRequest.filter([1,2,3].contains(Col.id))),
            "SELECT * FROM \"readers\" WHERE (\"id\" IN (1, 2, 3))")
        
        // Array.contains(): IN operator
        XCTAssertEqual(
            sql(tableRequest.filter([Col.id].contains(Col.id))),
            "SELECT * FROM \"readers\" WHERE (\"id\" IN (\"id\"))")
        
        // Sequence.contains(): IN operator
        XCTAssertEqual(
            sql(tableRequest.filter(AnySequence([1,2,3]).contains(Col.id))),
            "SELECT * FROM \"readers\" WHERE (\"id\" IN (1, 2, 3))")
        
        // Sequence.contains(): IN operator
        XCTAssertEqual(
            sql(tableRequest.filter(AnySequence([Col.id]).contains(Col.id))),
            "SELECT * FROM \"readers\" WHERE (\"id\" IN (\"id\"))")
        
        // !Sequence.contains(): NOT IN operator
        XCTAssertEqual(
            sql(tableRequest.filter(![1,2,3].contains(Col.id))),
            "SELECT * FROM \"readers\" WHERE (\"id\" NOT IN (1, 2, 3))")
        
        // !!Sequence.contains(): IN operator
        XCTAssertEqual(
            sql(tableRequest.filter(!(![1,2,3].contains(Col.id)))),
            "SELECT * FROM \"readers\" WHERE (\"id\" IN (1, 2, 3))")
        
        // Range.contains(): BETWEEN operator
        var range: Range<Int64> = 1..<10
        XCTAssertEqual(
            sql(tableRequest.filter(range.contains(Col.id))),
            "SELECT * FROM \"readers\" WHERE (\"id\" BETWEEN 1 AND 9)")
        
        // Range.contains(): BETWEEN operator
        range = 1...10
        XCTAssertEqual(
            sql(tableRequest.filter(range.contains(Col.id))),
            "SELECT * FROM \"readers\" WHERE (\"id\" BETWEEN 1 AND 10)")
        
        // ClosedInterval: BETWEEN operator
        let closedInterval: ClosedInterval<String> = "A"..."z"
        XCTAssertEqual(
            sql(tableRequest.filter(closedInterval.contains(Col.name))),
            "SELECT * FROM \"readers\" WHERE (\"name\" BETWEEN 'A' AND 'z')")
        
        // HalfOpenInterval:  min <= x < max
        let halfOpenInterval: HalfOpenInterval<String> = "A"..<"z"
        XCTAssertEqual(
            sql(tableRequest.filter(halfOpenInterval.contains(Col.name))),
            "SELECT * FROM \"readers\" WHERE ((\"name\" >= 'A') AND (\"name\" < 'z'))")
        
        // Subquery
        XCTAssertEqual(
            sql(tableRequest.filter(tableRequest.select(Col.id).contains(Col.id))),
            "SELECT * FROM \"readers\" WHERE (\"id\" IN (SELECT \"id\" FROM \"readers\"))")
        
        // Subquery
        XCTAssertEqual(
            sql(tableRequest.filter(!tableRequest.select(Col.id).contains(Col.id))),
            "SELECT * FROM \"readers\" WHERE (\"id\" NOT IN (SELECT \"id\" FROM \"readers\"))")
    }
    
    func testContainsWithCollation() {
        // Array.contains(): IN operator
        XCTAssertEqual(
            sql(tableRequest.filter(["arthur", "barbara"].contains(Col.name.collating("NOCASE")))),
            "SELECT * FROM \"readers\" WHERE (\"name\" IN ('arthur', 'barbara') COLLATE NOCASE)")
        
        // Sequence.contains(): IN operator
        XCTAssertEqual(
            sql(tableRequest.filter(AnySequence(["arthur", "barbara"]).contains(Col.name.collating("NOCASE")))),
            "SELECT * FROM \"readers\" WHERE (\"name\" IN ('arthur', 'barbara') COLLATE NOCASE)")
        
        // Sequence.contains(): IN operator
        XCTAssertEqual(
            sql(tableRequest.filter(AnySequence([Col.name]).contains(Col.name.collating("NOCASE")))),
            "SELECT * FROM \"readers\" WHERE (\"name\" IN (\"name\") COLLATE NOCASE)")
        
        // ClosedInterval: BETWEEN operator
        let closedInterval: ClosedInterval<String> = "A"..."z"
        XCTAssertEqual(
            sql(tableRequest.filter(closedInterval.contains(Col.name.collating("NOCASE")))),
            "SELECT * FROM \"readers\" WHERE (\"name\" BETWEEN 'A' AND 'z' COLLATE NOCASE)")
        
        // HalfOpenInterval:  min <= x < max
        let halfOpenInterval: HalfOpenInterval<String> = "A"..<"z"
        XCTAssertEqual(
            sql(tableRequest.filter(halfOpenInterval.contains(Col.name.collating("NOCASE")))),
            "SELECT * FROM \"readers\" WHERE ((\"name\" >= 'A' COLLATE NOCASE) AND (\"name\" < 'z' COLLATE NOCASE))")
    }
    
    func testGreaterThan() {
        // TODO: test compound expressions such as `average(Col.age) + 10 > 20`
        
        XCTAssertEqual(
            sql(tableRequest.filter(Col.age > 10)),
            "SELECT * FROM \"readers\" WHERE (\"age\" > 10)")
        XCTAssertEqual(
            sql(tableRequest.filter(10 > Col.age)),
            "SELECT * FROM \"readers\" WHERE (10 > \"age\")")
        XCTAssertEqual(
            sql(tableRequest.filter(10 > 10)),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(tableRequest.filter(Col.age > Col.age)),
            "SELECT * FROM \"readers\" WHERE (\"age\" > \"age\")")
        
        XCTAssertEqual(
            sql(tableRequest.filter(Col.name > "B")),
            "SELECT * FROM \"readers\" WHERE (\"name\" > 'B')")
        XCTAssertEqual(
            sql(tableRequest.filter("B" > Col.name)),
            "SELECT * FROM \"readers\" WHERE ('B' > \"name\")")
        XCTAssertEqual(
            sql(tableRequest.filter("B" > "B")),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(tableRequest.filter(Col.name > Col.name)),
            "SELECT * FROM \"readers\" WHERE (\"name\" > \"name\")")
    }
    
    func testGreaterThanWithCollation() {
        XCTAssertEqual(
            sql(tableRequest.filter(Col.name.collating("NOCASE") > "fOo")),
            "SELECT * FROM \"readers\" WHERE (\"name\" > 'fOo' COLLATE NOCASE)")
        XCTAssertEqual(
            sql(tableRequest.filter(Col.name.collating(collation) > "fOo")),
            "SELECT * FROM \"readers\" WHERE (\"name\" > 'fOo' COLLATE localized_case_insensitive)")
    }
    
    func testGreaterThanOrEqual() {
        // TODO: test compound expressions such as `average(Col.age) + 10 > 20`
        
        XCTAssertEqual(
            sql(tableRequest.filter(Col.age >= 10)),
            "SELECT * FROM \"readers\" WHERE (\"age\" >= 10)")
        XCTAssertEqual(
            sql(tableRequest.filter(10 >= Col.age)),
            "SELECT * FROM \"readers\" WHERE (10 >= \"age\")")
        XCTAssertEqual(
            sql(tableRequest.filter(10 >= 10)),
            "SELECT * FROM \"readers\" WHERE 1")
        XCTAssertEqual(
            sql(tableRequest.filter(Col.age >= Col.age)),
            "SELECT * FROM \"readers\" WHERE (\"age\" >= \"age\")")
        
        XCTAssertEqual(
            sql(tableRequest.filter(Col.name >= "B")),
            "SELECT * FROM \"readers\" WHERE (\"name\" >= 'B')")
        XCTAssertEqual(
            sql(tableRequest.filter("B" >= Col.name)),
            "SELECT * FROM \"readers\" WHERE ('B' >= \"name\")")
        XCTAssertEqual(
            sql(tableRequest.filter("B" >= "B")),
            "SELECT * FROM \"readers\" WHERE 1")
        XCTAssertEqual(
            sql(tableRequest.filter(Col.name >= Col.name)),
            "SELECT * FROM \"readers\" WHERE (\"name\" >= \"name\")")
    }
    
    func testGreaterThanOrEqualWithCollation() {
        XCTAssertEqual(
            sql(tableRequest.filter(Col.name.collating("NOCASE") >= "fOo")),
            "SELECT * FROM \"readers\" WHERE (\"name\" >= 'fOo' COLLATE NOCASE)")
        XCTAssertEqual(
            sql(tableRequest.filter(Col.name.collating(collation) >= "fOo")),
            "SELECT * FROM \"readers\" WHERE (\"name\" >= 'fOo' COLLATE localized_case_insensitive)")
    }
    
    func testLessThan() {
        // TODO: test compound expressions such as `average(Col.age) + 10 > 20`
        
        XCTAssertEqual(
            sql(tableRequest.filter(Col.age < 10)),
            "SELECT * FROM \"readers\" WHERE (\"age\" < 10)")
        XCTAssertEqual(
            sql(tableRequest.filter(10 < Col.age)),
            "SELECT * FROM \"readers\" WHERE (10 < \"age\")")
        XCTAssertEqual(
            sql(tableRequest.filter(10 < 10)),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(tableRequest.filter(Col.age < Col.age)),
            "SELECT * FROM \"readers\" WHERE (\"age\" < \"age\")")
        
        XCTAssertEqual(
            sql(tableRequest.filter(Col.name < "B")),
            "SELECT * FROM \"readers\" WHERE (\"name\" < 'B')")
        XCTAssertEqual(
            sql(tableRequest.filter("B" < Col.name)),
            "SELECT * FROM \"readers\" WHERE ('B' < \"name\")")
        XCTAssertEqual(
            sql(tableRequest.filter("B" < "B")),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(tableRequest.filter(Col.name < Col.name)),
            "SELECT * FROM \"readers\" WHERE (\"name\" < \"name\")")
    }
    
    func testLessThanWithCollation() {
        XCTAssertEqual(
            sql(tableRequest.filter(Col.name.collating("NOCASE") < "fOo")),
            "SELECT * FROM \"readers\" WHERE (\"name\" < 'fOo' COLLATE NOCASE)")
        XCTAssertEqual(
            sql(tableRequest.filter(Col.name.collating(collation) < "fOo")),
            "SELECT * FROM \"readers\" WHERE (\"name\" < 'fOo' COLLATE localized_case_insensitive)")
    }
    
    func testLessThanOrEqual() {
        // TODO: test compound expressions such as `average(Col.age) + 10 > 20`
        
        XCTAssertEqual(
            sql(tableRequest.filter(Col.age <= 10)),
            "SELECT * FROM \"readers\" WHERE (\"age\" <= 10)")
        XCTAssertEqual(
            sql(tableRequest.filter(10 <= Col.age)),
            "SELECT * FROM \"readers\" WHERE (10 <= \"age\")")
        XCTAssertEqual(
            sql(tableRequest.filter(10 <= 10)),
            "SELECT * FROM \"readers\" WHERE 1")
        XCTAssertEqual(
            sql(tableRequest.filter(Col.age <= Col.age)),
            "SELECT * FROM \"readers\" WHERE (\"age\" <= \"age\")")
        
        XCTAssertEqual(
            sql(tableRequest.filter(Col.name <= "B")),
            "SELECT * FROM \"readers\" WHERE (\"name\" <= 'B')")
        XCTAssertEqual(
            sql(tableRequest.filter("B" <= Col.name)),
            "SELECT * FROM \"readers\" WHERE ('B' <= \"name\")")
        XCTAssertEqual(
            sql(tableRequest.filter("B" <= "B")),
            "SELECT * FROM \"readers\" WHERE 1")
        XCTAssertEqual(
            sql(tableRequest.filter(Col.name <= Col.name)),
            "SELECT * FROM \"readers\" WHERE (\"name\" <= \"name\")")
    }
    
    func testLessThanOrEqualWithCollation() {
        XCTAssertEqual(
            sql(tableRequest.filter(Col.name.collating("NOCASE") <= "fOo")),
            "SELECT * FROM \"readers\" WHERE (\"name\" <= 'fOo' COLLATE NOCASE)")
        XCTAssertEqual(
            sql(tableRequest.filter(Col.name.collating(collation) <= "fOo")),
            "SELECT * FROM \"readers\" WHERE (\"name\" <= 'fOo' COLLATE localized_case_insensitive)")
    }
    
    func testEqual() {
        XCTAssertEqual(
            sql(tableRequest.filter(Col.age == 10)),
            "SELECT * FROM \"readers\" WHERE (\"age\" = 10)")
        XCTAssertEqual(
            sql(tableRequest.filter(Col.age == (10 as Int?))),
            "SELECT * FROM \"readers\" WHERE (\"age\" = 10)")
        XCTAssertEqual(
            sql(tableRequest.filter(10 == Col.age)),
            "SELECT * FROM \"readers\" WHERE (10 = \"age\")")
        XCTAssertEqual(
            sql(tableRequest.filter((10 as Int?) == Col.age)),
            "SELECT * FROM \"readers\" WHERE (10 = \"age\")")
        XCTAssertEqual(
            sql(tableRequest.filter(10 == 10)),
            "SELECT * FROM \"readers\" WHERE 1")
        XCTAssertEqual(
            sql(tableRequest.filter(Col.age == Col.age)),
            "SELECT * FROM \"readers\" WHERE (\"age\" = \"age\")")
        
        XCTAssertEqual(
            sql(tableRequest.filter(Col.age == nil)),
            "SELECT * FROM \"readers\" WHERE (\"age\" IS NULL)")
        XCTAssertEqual(
            sql(tableRequest.filter(nil == Col.age)),
            "SELECT * FROM \"readers\" WHERE (\"age\" IS NULL)")
        XCTAssertEqual(
            sql(tableRequest.filter(Col.age == Col.age)),
            "SELECT * FROM \"readers\" WHERE (\"age\" = \"age\")")
        
        XCTAssertEqual(
            sql(tableRequest.filter(Col.name == "B")),
            "SELECT * FROM \"readers\" WHERE (\"name\" = 'B')")
        XCTAssertEqual(
            sql(tableRequest.filter("B" == Col.name)),
            "SELECT * FROM \"readers\" WHERE ('B' = \"name\")")
        XCTAssertEqual(
            sql(tableRequest.filter("B" == "B")),
            "SELECT * FROM \"readers\" WHERE 1")
        XCTAssertEqual(
            sql(tableRequest.filter(Col.name == Col.name)),
            "SELECT * FROM \"readers\" WHERE (\"name\" = \"name\")")
    }
    
    func testEqualWithCollation() {
        XCTAssertEqual(
            sql(tableRequest.filter(Col.name.collating("NOCASE") == "fOo")),
            "SELECT * FROM \"readers\" WHERE (\"name\" = 'fOo' COLLATE NOCASE)")
        XCTAssertEqual(
            sql(tableRequest.filter(Col.name.collating("NOCASE") == ("fOo" as String?))),
            "SELECT * FROM \"readers\" WHERE (\"name\" = 'fOo' COLLATE NOCASE)")
        XCTAssertEqual(
            sql(tableRequest.filter(Col.name.collating("NOCASE") == nil)),
            "SELECT * FROM \"readers\" WHERE (\"name\" IS NULL COLLATE NOCASE)")
        XCTAssertEqual(
            sql(tableRequest.filter(Col.name.collating(collation) == "fOo")),
            "SELECT * FROM \"readers\" WHERE (\"name\" = 'fOo' COLLATE localized_case_insensitive)")
    }
    
    func testNotEqual() {
        XCTAssertEqual(
            sql(tableRequest.filter(Col.age != 10)),
            "SELECT * FROM \"readers\" WHERE (\"age\" <> 10)")
        XCTAssertEqual(
            sql(tableRequest.filter(Col.age != (10 as Int?))),
            "SELECT * FROM \"readers\" WHERE (\"age\" <> 10)")
        XCTAssertEqual(
            sql(tableRequest.filter(10 != Col.age)),
            "SELECT * FROM \"readers\" WHERE (10 <> \"age\")")
        XCTAssertEqual(
            sql(tableRequest.filter((10 as Int?) != Col.age)),
            "SELECT * FROM \"readers\" WHERE (10 <> \"age\")")
        XCTAssertEqual(
            sql(tableRequest.filter(10 != 10)),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(tableRequest.filter(Col.age != Col.age)),
            "SELECT * FROM \"readers\" WHERE (\"age\" <> \"age\")")
        
        XCTAssertEqual(
            sql(tableRequest.filter(Col.age != nil)),
            "SELECT * FROM \"readers\" WHERE (\"age\" IS NOT NULL)")
        XCTAssertEqual(
            sql(tableRequest.filter(nil != Col.age)),
            "SELECT * FROM \"readers\" WHERE (\"age\" IS NOT NULL)")
        XCTAssertEqual(
            sql(tableRequest.filter(Col.age != Col.age)),
            "SELECT * FROM \"readers\" WHERE (\"age\" <> \"age\")")
        
        XCTAssertEqual(
            sql(tableRequest.filter(Col.name != "B")),
            "SELECT * FROM \"readers\" WHERE (\"name\" <> 'B')")
        XCTAssertEqual(
            sql(tableRequest.filter("B" != Col.name)),
            "SELECT * FROM \"readers\" WHERE ('B' <> \"name\")")
        XCTAssertEqual(
            sql(tableRequest.filter("B" != "B")),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(tableRequest.filter(Col.name != Col.name)),
            "SELECT * FROM \"readers\" WHERE (\"name\" <> \"name\")")
    }
    
    func testNotEqualWithCollation() {
        XCTAssertEqual(
            sql(tableRequest.filter(Col.name.collating("NOCASE") != "fOo")),
            "SELECT * FROM \"readers\" WHERE (\"name\" <> 'fOo' COLLATE NOCASE)")
        XCTAssertEqual(
            sql(tableRequest.filter(Col.name.collating("NOCASE") != ("fOo" as String?))),
            "SELECT * FROM \"readers\" WHERE (\"name\" <> 'fOo' COLLATE NOCASE)")
        XCTAssertEqual(
            sql(tableRequest.filter(Col.name.collating("NOCASE") != nil)),
            "SELECT * FROM \"readers\" WHERE (\"name\" IS NOT NULL COLLATE NOCASE)")
        XCTAssertEqual(
            sql(tableRequest.filter(Col.name.collating(collation) != "fOo")),
            "SELECT * FROM \"readers\" WHERE (\"name\" <> 'fOo' COLLATE localized_case_insensitive)")
    }
    
    func testNotEqualWithSwiftNotOperator() {
        XCTAssertEqual(
            sql(tableRequest.filter(!(Col.age == 10))),
            "SELECT * FROM \"readers\" WHERE (\"age\" <> 10)")
        XCTAssertEqual(
            sql(tableRequest.filter(!(10 == Col.age))),
            "SELECT * FROM \"readers\" WHERE (10 <> \"age\")")
        XCTAssertEqual(
            sql(tableRequest.filter(!(10 == 10))),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(tableRequest.filter(!(Col.age == Col.age))),
            "SELECT * FROM \"readers\" WHERE (\"age\" <> \"age\")")
        
        XCTAssertEqual(
            sql(tableRequest.filter(!(Col.age == nil))),
            "SELECT * FROM \"readers\" WHERE (\"age\" IS NOT NULL)")
        XCTAssertEqual(
            sql(tableRequest.filter(!(nil == Col.age))),
            "SELECT * FROM \"readers\" WHERE (\"age\" IS NOT NULL)")
        XCTAssertEqual(
            sql(tableRequest.filter(!(Col.age == Col.age))),
            "SELECT * FROM \"readers\" WHERE (\"age\" <> \"age\")")
    }
    
    func testIs() {
        XCTAssertEqual(
            sql(tableRequest.filter(Col.age === 10)),
            "SELECT * FROM \"readers\" WHERE (\"age\" IS 10)")
        XCTAssertEqual(
            sql(tableRequest.filter(10 === Col.age)),
            "SELECT * FROM \"readers\" WHERE (10 IS \"age\")")
        XCTAssertEqual(
            sql(tableRequest.filter(10 === 10)),
            "SELECT * FROM \"readers\" WHERE 1")
        XCTAssertEqual(
            sql(tableRequest.filter(Col.age === Col.age)),
            "SELECT * FROM \"readers\" WHERE (\"age\" IS \"age\")")
        
        XCTAssertEqual(
            sql(tableRequest.filter(Col.age === nil)),
            "SELECT * FROM \"readers\" WHERE (\"age\" IS NULL)")
        XCTAssertEqual(
            sql(tableRequest.filter(nil === Col.age)),
            "SELECT * FROM \"readers\" WHERE (\"age\" IS NULL)")
        XCTAssertEqual(
            sql(tableRequest.filter(Col.age === Col.age)),
            "SELECT * FROM \"readers\" WHERE (\"age\" IS \"age\")")
        
        XCTAssertEqual(
            sql(tableRequest.filter(Col.name === "B")),
            "SELECT * FROM \"readers\" WHERE (\"name\" IS 'B')")
        XCTAssertEqual(
            sql(tableRequest.filter("B" === Col.name)),
            "SELECT * FROM \"readers\" WHERE ('B' IS \"name\")")
        XCTAssertEqual(
            sql(tableRequest.filter("B" === "B")),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(tableRequest.filter(Col.name === Col.name)),
            "SELECT * FROM \"readers\" WHERE (\"name\" IS \"name\")")
    }
    
    func testIsWithCollation() {
        XCTAssertEqual(
            sql(tableRequest.filter(Col.name.collating("NOCASE") === "fOo")),
            "SELECT * FROM \"readers\" WHERE (\"name\" IS 'fOo' COLLATE NOCASE)")
        XCTAssertEqual(
            sql(tableRequest.filter(Col.name.collating(collation) === "fOo")),
            "SELECT * FROM \"readers\" WHERE (\"name\" IS 'fOo' COLLATE localized_case_insensitive)")
    }
    
    func testIsNot() {
        XCTAssertEqual(
            sql(tableRequest.filter(Col.age !== 10)),
            "SELECT * FROM \"readers\" WHERE (\"age\" IS NOT 10)")
        XCTAssertEqual(
            sql(tableRequest.filter(10 !== Col.age)),
            "SELECT * FROM \"readers\" WHERE (10 IS NOT \"age\")")
        XCTAssertEqual(
            sql(tableRequest.filter(10 !== 10)),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(tableRequest.filter(Col.age !== Col.age)),
            "SELECT * FROM \"readers\" WHERE (\"age\" IS NOT \"age\")")
        
        XCTAssertEqual(
            sql(tableRequest.filter(Col.age !== nil)),
            "SELECT * FROM \"readers\" WHERE (\"age\" IS NOT NULL)")
        XCTAssertEqual(
            sql(tableRequest.filter(nil !== Col.age)),
            "SELECT * FROM \"readers\" WHERE (\"age\" IS NOT NULL)")
        XCTAssertEqual(
            sql(tableRequest.filter(Col.age !== Col.age)),
            "SELECT * FROM \"readers\" WHERE (\"age\" IS NOT \"age\")")
        
        XCTAssertEqual(
            sql(tableRequest.filter(Col.name !== "B")),
            "SELECT * FROM \"readers\" WHERE (\"name\" IS NOT 'B')")
        XCTAssertEqual(
            sql(tableRequest.filter("B" !== Col.name)),
            "SELECT * FROM \"readers\" WHERE ('B' IS NOT \"name\")")
        XCTAssertEqual(
            sql(tableRequest.filter("B" !== "B")),
            "SELECT * FROM \"readers\" WHERE 1")
        XCTAssertEqual(
            sql(tableRequest.filter(Col.name !== Col.name)),
            "SELECT * FROM \"readers\" WHERE (\"name\" IS NOT \"name\")")
    }
    
    func testIsNotWithCollation() {
        XCTAssertEqual(
            sql(tableRequest.filter(Col.name.collating("NOCASE") !== "fOo")),
            "SELECT * FROM \"readers\" WHERE (\"name\" IS NOT 'fOo' COLLATE NOCASE)")
        XCTAssertEqual(
            sql(tableRequest.filter(Col.name.collating(collation) !== "fOo")),
            "SELECT * FROM \"readers\" WHERE (\"name\" IS NOT 'fOo' COLLATE localized_case_insensitive)")
    }
    
    func testIsNotWithSwiftNotOperator() {
        XCTAssertEqual(
            sql(tableRequest.filter(!(Col.age === 10))),
            "SELECT * FROM \"readers\" WHERE (\"age\" IS NOT 10)")
        XCTAssertEqual(
            sql(tableRequest.filter(!(10 === Col.age))),
            "SELECT * FROM \"readers\" WHERE (10 IS NOT \"age\")")
        XCTAssertEqual(
            sql(tableRequest.filter(!(10 === 10))),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(tableRequest.filter(!(Col.age === Col.age))),
            "SELECT * FROM \"readers\" WHERE (\"age\" IS NOT \"age\")")
        
        XCTAssertEqual(
            sql(tableRequest.filter(!(Col.age === nil))),
            "SELECT * FROM \"readers\" WHERE (\"age\" IS NOT NULL)")
        XCTAssertEqual(
            sql(tableRequest.filter(!(nil === Col.age))),
            "SELECT * FROM \"readers\" WHERE (\"age\" IS NOT NULL)")
        XCTAssertEqual(
            sql(tableRequest.filter(!(Col.age === Col.age))),
            "SELECT * FROM \"readers\" WHERE (\"age\" IS NOT \"age\")")
    }
    
    func testExists() {
        XCTAssertEqual(
            sql(tableRequest.filter(tableRequest.exists)),
            "SELECT * FROM \"readers\" WHERE (EXISTS (SELECT * FROM \"readers\"))")
        XCTAssertEqual(
            sql(tableRequest.filter(!tableRequest.exists)),
            "SELECT * FROM \"readers\" WHERE (NOT EXISTS (SELECT * FROM \"readers\"))")
    }
    
    func testLogicalOperators() {
        XCTAssertEqual(
            sql(tableRequest.filter(!Col.age)),
            "SELECT * FROM \"readers\" WHERE (NOT \"age\")")
        XCTAssertEqual(
            sql(tableRequest.filter(Col.age && true)),
            "SELECT * FROM \"readers\" WHERE (\"age\" AND 1)")
        XCTAssertEqual(
            sql(tableRequest.filter(true && Col.age)),
            "SELECT * FROM \"readers\" WHERE (1 AND \"age\")")
        XCTAssertEqual(
            sql(tableRequest.filter(Col.age || false)),
            "SELECT * FROM \"readers\" WHERE (\"age\" OR 0)")
        XCTAssertEqual(
            sql(tableRequest.filter(false || Col.age)),
            "SELECT * FROM \"readers\" WHERE (0 OR \"age\")")
        XCTAssertEqual(
            sql(tableRequest.filter(Col.age != nil || Col.name != nil)),
            "SELECT * FROM \"readers\" WHERE ((\"age\" IS NOT NULL) OR (\"name\" IS NOT NULL))")
        XCTAssertEqual(
            sql(tableRequest.filter(Col.age != nil || Col.name != nil && Col.id != nil)),
            "SELECT * FROM \"readers\" WHERE ((\"age\" IS NOT NULL) OR ((\"name\" IS NOT NULL) AND (\"id\" IS NOT NULL)))")
        XCTAssertEqual(
            sql(tableRequest.filter((Col.age != nil || Col.name != nil) && Col.id != nil)),
            "SELECT * FROM \"readers\" WHERE (((\"age\" IS NOT NULL) OR (\"name\" IS NOT NULL)) AND (\"id\" IS NOT NULL))")
    }
    
    
    // MARK: - String expressions
    
    func testLowercaseString() {
        XCTAssertEqual(
            sql(tableRequest.filter(Col.name.lowercaseString == "foo")),
            "SELECT * FROM \"readers\" WHERE (LOWER(\"name\") = 'foo')")
    }
    
    func testUppercaseString() {
        XCTAssertEqual(
            sql(tableRequest.filter(Col.name.uppercaseString == "FOO")),
            "SELECT * FROM \"readers\" WHERE (UPPER(\"name\") = 'FOO')")
    }
    
    
    // MARK: - Arithmetic expressions
    
    func testPrefixMinusOperator() {
        XCTAssertEqual(
            sql(tableRequest.filter(-Col.age)),
            "SELECT * FROM \"readers\" WHERE -\"age\"")
    }
    
    func testInfixMinusOperator() {
        XCTAssertEqual(
            sql(tableRequest.filter(Col.age - 2)),
            "SELECT * FROM \"readers\" WHERE (\"age\" - 2)")
        XCTAssertEqual(
            sql(tableRequest.filter(2 - Col.age)),
            "SELECT * FROM \"readers\" WHERE (2 - \"age\")")
        XCTAssertEqual(
            sql(tableRequest.filter(2 - 2)),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(tableRequest.filter(Col.age - Col.age)),
            "SELECT * FROM \"readers\" WHERE (\"age\" - \"age\")")
    }
    
    func testInfixPlusOperator() {
        XCTAssertEqual(
            sql(tableRequest.filter(Col.age + 2)),
            "SELECT * FROM \"readers\" WHERE (\"age\" + 2)")
        XCTAssertEqual(
            sql(tableRequest.filter(2 + Col.age)),
            "SELECT * FROM \"readers\" WHERE (2 + \"age\")")
        XCTAssertEqual(
            sql(tableRequest.filter(2 + 2)),
            "SELECT * FROM \"readers\" WHERE 4")
        XCTAssertEqual(
            sql(tableRequest.filter(Col.age + Col.age)),
            "SELECT * FROM \"readers\" WHERE (\"age\" + \"age\")")
    }
    
    func testInfixMultiplyOperator() {
        XCTAssertEqual(
            sql(tableRequest.filter(Col.age * 2)),
            "SELECT * FROM \"readers\" WHERE (\"age\" * 2)")
        XCTAssertEqual(
            sql(tableRequest.filter(2 * Col.age)),
            "SELECT * FROM \"readers\" WHERE (2 * \"age\")")
        XCTAssertEqual(
            sql(tableRequest.filter(2 * 2)),
            "SELECT * FROM \"readers\" WHERE 4")
        XCTAssertEqual(
            sql(tableRequest.filter(Col.age * Col.age)),
            "SELECT * FROM \"readers\" WHERE (\"age\" * \"age\")")
    }
    
    func testInfixDivideOperator() {
        XCTAssertEqual(
            sql(tableRequest.filter(Col.age / 2)),
            "SELECT * FROM \"readers\" WHERE (\"age\" / 2)")
        XCTAssertEqual(
            sql(tableRequest.filter(2 / Col.age)),
            "SELECT * FROM \"readers\" WHERE (2 / \"age\")")
        XCTAssertEqual(
            sql(tableRequest.filter(2 / 2)),
            "SELECT * FROM \"readers\" WHERE 1")
        XCTAssertEqual(
            sql(tableRequest.filter(Col.age / Col.age)),
            "SELECT * FROM \"readers\" WHERE (\"age\" / \"age\")")
    }
    
    func testCompoundArithmeticExpression() {
        // Int / Double
        XCTAssertEqual(
            sql(tableRequest.filter(Col.age / 2.0)),
            "SELECT * FROM \"readers\" WHERE (\"age\" / 2.0)")
        // Double / Int
        XCTAssertEqual(
            sql(tableRequest.filter(2.0 / Col.age)),
            "SELECT * FROM \"readers\" WHERE (2.0 / \"age\")")
        XCTAssertEqual(
            sql(tableRequest.filter(Col.age + 2 * 5)),
            "SELECT * FROM \"readers\" WHERE (\"age\" + 10)")
        XCTAssertEqual(
            sql(tableRequest.filter(Col.age * 2 + 5)),
            "SELECT * FROM \"readers\" WHERE ((\"age\" * 2) + 5)")
    }
    
    
    // MARK: - IFNULL expression
    
    func testIfNull() {
        var optInt: Int? = nil
        let int: Int = 1
        XCTAssertEqual(
            sql(tableRequest.filter(Col.age ?? 2)),
            "SELECT * FROM \"readers\" WHERE IFNULL(\"age\", 2)")
        XCTAssertEqual(
            sql(tableRequest.filter(optInt ?? Col.age)),
            "SELECT * FROM \"readers\" WHERE \"age\"")
        optInt = 1
        XCTAssertEqual(
            sql(tableRequest.filter(optInt ?? Col.age)),
            "SELECT * FROM \"readers\" WHERE IFNULL(1, \"age\")")
        XCTAssertEqual(
            sql(tableRequest.filter(int ?? Col.age)),
            "SELECT * FROM \"readers\" WHERE IFNULL(1, \"age\")")
        XCTAssertEqual(
            sql(tableRequest.filter(3 ?? 2)),
            "SELECT * FROM \"readers\" WHERE 3")
        XCTAssertEqual(
            sql(tableRequest.filter(Col.age ?? Col.age)),
            "SELECT * FROM \"readers\" WHERE IFNULL(\"age\", \"age\")")
    }
    
    
    // MARK: - Aggregated expressions
    
    func testCountExpression() {
        XCTAssertEqual(
            sql(tableRequest.select(count(Col.age))),
            "SELECT COUNT(\"age\") FROM \"readers\"")
        XCTAssertEqual(
            sql(tableRequest.select(count(Col.age ?? 0))),
            "SELECT COUNT(IFNULL(\"age\", 0)) FROM \"readers\"")
        XCTAssertEqual(
            sql(tableRequest.select(count(distinct: Col.age))),
            "SELECT COUNT(DISTINCT \"age\") FROM \"readers\"")
        XCTAssertEqual(
            sql(tableRequest.select(count(distinct: Col.age / Col.age))),
            "SELECT COUNT(DISTINCT (\"age\" / \"age\")) FROM \"readers\"")
    }
    
    func testAvgExpression() {
        XCTAssertEqual(
            sql(tableRequest.select(average(Col.age))),
            "SELECT AVG(\"age\") FROM \"readers\"")
        XCTAssertEqual(
            sql(tableRequest.select(average(Col.age / 2))),
            "SELECT AVG((\"age\" / 2)) FROM \"readers\"")
    }
    
    func testMinExpression() {
        XCTAssertEqual(
            sql(tableRequest.select(min(Col.age))),
            "SELECT MIN(\"age\") FROM \"readers\"")
        XCTAssertEqual(
            sql(tableRequest.select(min(Col.age / 2))),
            "SELECT MIN((\"age\" / 2)) FROM \"readers\"")
    }
    
    func testMaxExpression() {
        XCTAssertEqual(
            sql(tableRequest.select(max(Col.age))),
            "SELECT MAX(\"age\") FROM \"readers\"")
        XCTAssertEqual(
            sql(tableRequest.select(max(Col.age / 2))),
            "SELECT MAX((\"age\" / 2)) FROM \"readers\"")
    }
    
    func testSumExpression() {
        XCTAssertEqual(
            sql(tableRequest.select(sum(Col.age))),
            "SELECT SUM(\"age\") FROM \"readers\"")
        XCTAssertEqual(
            sql(tableRequest.select(sum(Col.age / 2))),
            "SELECT SUM((\"age\" / 2)) FROM \"readers\"")
    }
    
    
    // MARK: - Function
    
    func testCustomFunction() {
        XCTAssertEqual(
            sql(tableRequest.select(customFunction.apply(Col.age, 1, 2))),
            "SELECT avgOf(\"age\", 1, 2) FROM \"readers\"")
    }
}

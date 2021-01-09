import XCTest
@testable import GRDB

private struct Col {
    static let id = Column("id")
    static let name = Column("name")
    static let age = Column("age")
    static let readerId = Column("readerId")
}

private struct Reader : TableRecord {
    static let databaseTableName = "readers"
}
private let tableRequest = Reader.all()

class QueryInterfaceExpressionsTests: GRDBTestCase {
    
    let collation = DatabaseCollation("localized_case_insensitive") { (lhs, rhs) in
        return (lhs as NSString).localizedCaseInsensitiveCompare(rhs)
    }
    
    let customFunction = DatabaseFunction("avgOf", pure: true) { dbValues in
        let sum = dbValues.compactMap { Int.fromDatabaseValue($0) }.reduce(0, +)
        return Double(sum) / Double(dbValues.count)
    }
    
    override func setUp() {
        super.setUp()
        dbConfiguration.prepareDatabase { db in
            db.add(collation: self.collation)
            db.add(function: self.customFunction)
        }
    }
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createReaders") { db in
            try db.execute(sql: """
                CREATE TABLE readers (
                    id INTEGER PRIMARY KEY,
                    name TEXT NOT NULL,
                    age INT)
                """)
        }
        try migrator.migrate(dbWriter)
    }
    
    
    // MARK: - Boolean expressions
    
    func testContains() throws {
        let dbQueue = try makeDatabaseQueue()
        
        // emptyArray.contains(): 0
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter([Int]().contains(Col.id))),
            "SELECT * FROM \"readers\" WHERE 0")
        
        // !emptyArray.contains(): 0
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(![Int]().contains(Col.id))),
            "SELECT * FROM \"readers\" WHERE 1")
        
        // Array.contains(): = operator
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter([1].contains(Col.id))),
            "SELECT * FROM \"readers\" WHERE \"id\" = 1")
        
        // Array.contains(): IN operator
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter([1,2,3].contains(Col.id))),
            "SELECT * FROM \"readers\" WHERE \"id\" IN (1, 2, 3)")
        
        // Array.contains(): IN operator
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter([Col.id].contains(Col.id))),
            "SELECT * FROM \"readers\" WHERE \"id\" = \"id\"")
        
        // EmptyCollection.contains(): 0
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(EmptyCollection<Int>().contains(Col.id))),
            "SELECT * FROM \"readers\" WHERE 0")
        
        // !EmptyCollection.contains(): 1
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!EmptyCollection<Int>().contains(Col.id))),
            "SELECT * FROM \"readers\" WHERE 1")
        
        // Sequence.contains(): = operator
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(AnySequence([1]).contains(Col.id))),
            "SELECT * FROM \"readers\" WHERE \"id\" = 1")
        
        // Sequence.contains(): IN operator
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(AnySequence([1,2,3]).contains(Col.id))),
            "SELECT * FROM \"readers\" WHERE \"id\" IN (1, 2, 3)")
        
        // Sequence.contains(): IN operator
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(AnySequence([Col.id]).contains(Col.id))),
            "SELECT * FROM \"readers\" WHERE \"id\" = \"id\"")
        
        // !Sequence.contains(): <> operator
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(![1].contains(Col.id))),
            "SELECT * FROM \"readers\" WHERE \"id\" <> 1")
        
        // !Sequence.contains(): NOT IN operator
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(![1,2,3].contains(Col.id))),
            "SELECT * FROM \"readers\" WHERE \"id\" NOT IN (1, 2, 3)")
        
        // !!Sequence.contains(): = operator
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(![1].contains(Col.id)))),
            "SELECT * FROM \"readers\" WHERE \"id\" = 1")
        
        // !!Sequence.contains(): IN operator
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(![1,2,3].contains(Col.id)))),
            "SELECT * FROM \"readers\" WHERE \"id\" IN (1, 2, 3)")
        
        // CountableRange.contains(): min <= x < max
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter((1..<10).contains(Col.id))),
            "SELECT * FROM \"readers\" WHERE (\"id\" >= 1) AND (\"id\" < 10)")
        
        // CountableClosedRange.contains(): BETWEEN operator
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter((1...10).contains(Col.id))),
            "SELECT * FROM \"readers\" WHERE \"id\" BETWEEN 1 AND 10")
        
        // !CountableClosedRange.contains(): BETWEEN operator
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(1...10).contains(Col.id))),
            "SELECT * FROM \"readers\" WHERE \"id\" NOT BETWEEN 1 AND 10")
        
        // Range.contains(): min <= x < max
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter((1.1..<10.9).contains(Col.id))),
            "SELECT * FROM \"readers\" WHERE (\"id\" >= 1.1) AND (\"id\" < 10.9)")
        
        // Range.contains(): min <= x < max
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(("A"..<"z").contains(Col.name))),
            "SELECT * FROM \"readers\" WHERE (\"name\" >= 'A') AND (\"name\" < 'z')")
        
        // ClosedRange.contains(): BETWEEN operator
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter((1.1...10.9).contains(Col.id))),
            "SELECT * FROM \"readers\" WHERE \"id\" BETWEEN 1.1 AND 10.9")
        
        // ClosedRange.contains(): BETWEEN operator
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(("A"..."z").contains(Col.name))),
            "SELECT * FROM \"readers\" WHERE \"name\" BETWEEN 'A' AND 'z'")
        
        // !ClosedRange.contains(): NOT BETWEEN operator
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!("A"..."z").contains(Col.name))),
            "SELECT * FROM \"readers\" WHERE \"name\" NOT BETWEEN 'A' AND 'z'")
    }
    
    func testContainsWithCollation() throws {
        let dbQueue = try makeDatabaseQueue()
        
        // Array.contains(): IN operator
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(["arthur", "barbara"].contains(Col.name.collating(.nocase)))),
            "SELECT * FROM \"readers\" WHERE \"name\" IN ('arthur', 'barbara') COLLATE NOCASE")
        
        // Sequence.contains(): IN operator
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(AnySequence(["arthur", "barbara"]).contains(Col.name.collating(.nocase)))),
            "SELECT * FROM \"readers\" WHERE \"name\" IN ('arthur', 'barbara') COLLATE NOCASE")
        
        // Sequence.contains(): = operator
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(AnySequence([Col.name]).contains(Col.name.collating(.nocase)))),
            "SELECT * FROM \"readers\" WHERE \"name\" = \"name\" COLLATE NOCASE")
        
        // Sequence.contains(): false
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(EmptyCollection<Int>().contains(Col.name.collating(.nocase)))),
            "SELECT * FROM \"readers\" WHERE 0 COLLATE NOCASE")

        // ClosedInterval: BETWEEN operator
        let closedInterval = "A"..."z"
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(closedInterval.contains(Col.name.collating(.nocase)))),
            "SELECT * FROM \"readers\" WHERE \"name\" BETWEEN 'A' AND 'z' COLLATE NOCASE")
        
        // HalfOpenInterval:  min <= x < max
        let halfOpenInterval = "A"..<"z"
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(halfOpenInterval.contains(Col.name.collating(.nocase)))),
            "SELECT * FROM \"readers\" WHERE (\"name\" >= 'A' COLLATE NOCASE) AND (\"name\" < 'z' COLLATE NOCASE)")
    }
    
    func testSubqueryContains() throws {
        let dbQueue = try makeDatabaseQueue()
        
        do {
            let subquery = tableRequest.select(Col.age).filter(Col.name != nil).distinct()
            XCTAssertEqual(
                sql(dbQueue, tableRequest.filter(subquery.contains(Col.age))),
                """
                SELECT * FROM "readers" WHERE "age" IN \
                (SELECT DISTINCT "age" FROM "readers" WHERE "name" IS NOT NULL)
                """)
        }
        
        do {
            let subquery = SQLRequest<Int>(sql: "SELECT ? UNION SELECT ?", arguments: [1, 2])
            XCTAssertEqual(
                sql(dbQueue, tableRequest.filter(subquery.contains(Col.age + 1))),
                """
                SELECT * FROM "readers" WHERE ("age" + 1) IN (SELECT 1 UNION SELECT 2)
                """)
        }
        
        do {
            let subquery1 = tableRequest.select(max(Col.age))
            let subquery2 = tableRequest.filter(Col.age == subquery1)
            XCTAssertEqual(
                sql(dbQueue, tableRequest.filter(subquery2.select(Col.id).contains(Col.id))),
                """
                SELECT * FROM "readers" WHERE "id" IN (\
                SELECT "id" FROM "readers" WHERE "age" = (\
                SELECT MAX("age") FROM "readers"))
                """)
        }
    }
    
    func testGreaterThan() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age > 10)),
            "SELECT * FROM \"readers\" WHERE \"age\" > 10")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(10 > Col.age)),
            "SELECT * FROM \"readers\" WHERE 10 > \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { _ in 10 > 10 }),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age > Col.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" > \"age\"")
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name > "B")),
            "SELECT * FROM \"readers\" WHERE \"name\" > 'B'")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter("B" > Col.name)),
            "SELECT * FROM \"readers\" WHERE 'B' > \"name\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { _ in "B" > "B" }),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name > Col.name)),
            "SELECT * FROM \"readers\" WHERE \"name\" > \"name\"")
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.group(Col.name).having(average(Col.age) + 10 > 20)),
            "SELECT * FROM \"readers\" GROUP BY \"name\" HAVING (AVG(\"age\") + 10) > 20")
    }
    
    func testGreaterThanWithCollation() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name.collating(.nocase) > "fOo")),
            "SELECT * FROM \"readers\" WHERE \"name\" > 'fOo' COLLATE NOCASE")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name.collating(collation) > "fOo")),
            "SELECT * FROM \"readers\" WHERE \"name\" > 'fOo' COLLATE localized_case_insensitive")
    }
    
    func testGreaterThanOrEqual() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age >= 10)),
            "SELECT * FROM \"readers\" WHERE \"age\" >= 10")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(10 >= Col.age)),
            "SELECT * FROM \"readers\" WHERE 10 >= \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { _ in 10 >= 10 }),
            "SELECT * FROM \"readers\" WHERE 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age >= Col.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" >= \"age\"")
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name >= "B")),
            "SELECT * FROM \"readers\" WHERE \"name\" >= 'B'")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter("B" >= Col.name)),
            "SELECT * FROM \"readers\" WHERE 'B' >= \"name\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { _ in "B" >= "B" }),
            "SELECT * FROM \"readers\" WHERE 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name >= Col.name)),
            "SELECT * FROM \"readers\" WHERE \"name\" >= \"name\"")
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.group(Col.name).having(average(Col.age) + 10 >= 20)),
            "SELECT * FROM \"readers\" GROUP BY \"name\" HAVING (AVG(\"age\") + 10) >= 20")
    }
    
    func testGreaterThanOrEqualWithCollation() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name.collating(.nocase) >= "fOo")),
            "SELECT * FROM \"readers\" WHERE \"name\" >= 'fOo' COLLATE NOCASE")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name.collating(collation) >= "fOo")),
            "SELECT * FROM \"readers\" WHERE \"name\" >= 'fOo' COLLATE localized_case_insensitive")
    }
    
    func testLessThan() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age < 10)),
            "SELECT * FROM \"readers\" WHERE \"age\" < 10")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(10 < Col.age)),
            "SELECT * FROM \"readers\" WHERE 10 < \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { _ in 10 < 10 }),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age < Col.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" < \"age\"")
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name < "B")),
            "SELECT * FROM \"readers\" WHERE \"name\" < 'B'")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter("B" < Col.name)),
            "SELECT * FROM \"readers\" WHERE 'B' < \"name\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { _ in "B" < "B" }),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name < Col.name)),
            "SELECT * FROM \"readers\" WHERE \"name\" < \"name\"")
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.group(Col.name).having(average(Col.age) + 10 < 20)),
            "SELECT * FROM \"readers\" GROUP BY \"name\" HAVING (AVG(\"age\") + 10) < 20")
    }
    
    func testLessThanWithCollation() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name.collating(.nocase) < "fOo")),
            "SELECT * FROM \"readers\" WHERE \"name\" < 'fOo' COLLATE NOCASE")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name.collating(collation) < "fOo")),
            "SELECT * FROM \"readers\" WHERE \"name\" < 'fOo' COLLATE localized_case_insensitive")
    }
    
    func testLessThanOrEqual() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age <= 10)),
            "SELECT * FROM \"readers\" WHERE \"age\" <= 10")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(10 <= Col.age)),
            "SELECT * FROM \"readers\" WHERE 10 <= \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { _ in 10 <= 10 }),
            "SELECT * FROM \"readers\" WHERE 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age <= Col.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" <= \"age\"")
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name <= "B")),
            "SELECT * FROM \"readers\" WHERE \"name\" <= 'B'")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter("B" <= Col.name)),
            "SELECT * FROM \"readers\" WHERE 'B' <= \"name\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { _ in "B" <= "B" }),
            "SELECT * FROM \"readers\" WHERE 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name <= Col.name)),
            "SELECT * FROM \"readers\" WHERE \"name\" <= \"name\"")
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.group(Col.name).having(average(Col.age) + 10 <= 20)),
            "SELECT * FROM \"readers\" GROUP BY \"name\" HAVING (AVG(\"age\") + 10) <= 20")
    }
    
    func testLessThanOrEqualWithCollation() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name.collating(.nocase) <= "fOo")),
            "SELECT * FROM \"readers\" WHERE \"name\" <= 'fOo' COLLATE NOCASE")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name.collating(collation) <= "fOo")),
            "SELECT * FROM \"readers\" WHERE \"name\" <= 'fOo' COLLATE localized_case_insensitive")
    }
    
    func testEqual() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age == 10)),
            "SELECT * FROM \"readers\" WHERE \"age\" = 10")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age == (10 as Int?))),
            "SELECT * FROM \"readers\" WHERE \"age\" = 10")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(10 == Col.age)),
            "SELECT * FROM \"readers\" WHERE 10 = \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter((10 as Int?) == Col.age)),
            "SELECT * FROM \"readers\" WHERE 10 = \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { _ in 10 == 10 }),
            "SELECT * FROM \"readers\" WHERE 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age == Col.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" = \"age\"")
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age == nil)),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age == DatabaseValue.null)),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(nil == Col.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(DatabaseValue.null == Col.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age == Col.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" = \"age\"")
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name == "B")),
            "SELECT * FROM \"readers\" WHERE \"name\" = 'B'")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter("B" == Col.name)),
            "SELECT * FROM \"readers\" WHERE 'B' = \"name\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { _ in "B" == "B" }),
            "SELECT * FROM \"readers\" WHERE 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name == Col.name)),
            "SELECT * FROM \"readers\" WHERE \"name\" = \"name\"")
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age == true)),
            "SELECT * FROM \"readers\" WHERE \"age\" = 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(true == Col.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" = 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age == false)),
            "SELECT * FROM \"readers\" WHERE \"age\" = 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(false == Col.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" = 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { _ in true == true }),
            "SELECT * FROM \"readers\" WHERE 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { _ in false == false }),
            "SELECT * FROM \"readers\" WHERE 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { _ in true == false }),
            "SELECT * FROM \"readers\" WHERE 0")
    }
    
    func testEqualWithCollation() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name.collating(.nocase) == "fOo")),
            "SELECT * FROM \"readers\" WHERE \"name\" = 'fOo' COLLATE NOCASE")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name.collating(.nocase) == ("fOo" as String?))),
            "SELECT * FROM \"readers\" WHERE \"name\" = 'fOo' COLLATE NOCASE")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name.collating(.nocase) == nil)),
            "SELECT * FROM \"readers\" WHERE \"name\" IS NULL COLLATE NOCASE")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name.collating(.nocase) == DatabaseValue.null)),
            "SELECT * FROM \"readers\" WHERE \"name\" IS NULL COLLATE NOCASE")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name.collating(collation) == "fOo")),
            "SELECT * FROM \"readers\" WHERE \"name\" = 'fOo' COLLATE localized_case_insensitive")
    }
    
    func testSubqueryEqual() throws {
        let dbQueue = try makeDatabaseQueue()
        
        do {
            let subquery = tableRequest.select(max(Col.age))
            XCTAssertEqual(
                sql(dbQueue, tableRequest.filter(Col.age == subquery)),
                """
                SELECT * FROM "readers" WHERE "age" = (SELECT MAX("age") FROM "readers")
                """)
        }
        
        do {
            let subquery = SQLRequest<Int>(sql: "SELECT MAX(age + ?) FROM readers", arguments: [1])
            XCTAssertEqual(
                sql(dbQueue, tableRequest.filter((Col.age + 2) == subquery)),
                """
                SELECT * FROM "readers" WHERE ("age" + 2) = (SELECT MAX(age + 1) FROM readers)
                """)
        }
    }
    
    func testSubqueryWithOuterAlias() throws {
        let dbQueue = try makeDatabaseQueue()
        
        try dbQueue.write { db in
            try db.create(table: "parent") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("parentId", .integer).references("parent")
            }
            try db.create(table: "child") { t in
                t.column("childParentId", .integer).references("parent")
            }
        }
        
        struct Parent: TableRecord {
            static let parent = belongsTo(Parent.self)
        }
        struct Child: TableRecord { }
        
        do {
            let parentAlias = TableAlias()
            // Some ugly subquery whose only purpose is to use a table alias
            // which requires disambiguation in the parent query.
            let subquery = Child.select(sql: "COUNT(*)").filter(Column("childParentId") == parentAlias[Column("id")])
            let request = Parent
                .joining(optional: Parent.parent.aliased(parentAlias))
                .filter(subquery > 1)
            XCTAssertEqual(
                sql(dbQueue, request),
                """
                SELECT "parent1".* FROM "parent" "parent1" \
                LEFT JOIN "parent" "parent2" ON "parent2"."id" = "parent1"."parentId" \
                WHERE (SELECT COUNT(*) FROM "child" WHERE "childParentId" = "parent2"."id") > 1
                """)
        }
    }

    func testNotEqual() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age != 10)),
            "SELECT * FROM \"readers\" WHERE \"age\" <> 10")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age != (10 as Int?))),
            "SELECT * FROM \"readers\" WHERE \"age\" <> 10")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(10 != Col.age)),
            "SELECT * FROM \"readers\" WHERE 10 <> \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter((10 as Int?) != Col.age)),
            "SELECT * FROM \"readers\" WHERE 10 <> \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { _ in 10 != 10 }),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age != Col.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" <> \"age\"")
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(Col.age == 10))),
            "SELECT * FROM \"readers\" WHERE \"age\" <> 10")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(Col.age == (10 as Int?)))),
            "SELECT * FROM \"readers\" WHERE \"age\" <> 10")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(10 == Col.age))),
            "SELECT * FROM \"readers\" WHERE 10 <> \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!((10 as Int?) == Col.age))),
            "SELECT * FROM \"readers\" WHERE 10 <> \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { _ in !(10 == 10) }),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(Col.age == Col.age))),
            "SELECT * FROM \"readers\" WHERE \"age\" <> \"age\"")

        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age != nil)),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age != DatabaseValue.null)),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(nil != Col.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(DatabaseValue.null != Col.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age != Col.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" <> \"age\"")
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(Col.age == nil))),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(Col.age == DatabaseValue.null))),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(nil == Col.age))),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(DatabaseValue.null == Col.age))),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(Col.age == Col.age))),
            "SELECT * FROM \"readers\" WHERE \"age\" <> \"age\"")

        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name != "B")),
            "SELECT * FROM \"readers\" WHERE \"name\" <> 'B'")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter("B" != Col.name)),
            "SELECT * FROM \"readers\" WHERE 'B' <> \"name\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { _ in "B" != "B" }),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name != Col.name)),
            "SELECT * FROM \"readers\" WHERE \"name\" <> \"name\"")
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(Col.name == "B"))),
            "SELECT * FROM \"readers\" WHERE \"name\" <> 'B'")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!("B" == Col.name))),
            "SELECT * FROM \"readers\" WHERE 'B' <> \"name\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { _ in !("B" == "B") }),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(Col.name == Col.name))),
            "SELECT * FROM \"readers\" WHERE \"name\" <> \"name\"")
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age != true)),
            "SELECT * FROM \"readers\" WHERE \"age\" <> 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(true != Col.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" <> 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age != false)),
            "SELECT * FROM \"readers\" WHERE \"age\" <> 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(false != Col.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" <> 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { _ in true != true }),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { _ in false != false }),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { _ in true != false }),
            "SELECT * FROM \"readers\" WHERE 1")
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(Col.age == true))),
            "SELECT * FROM \"readers\" WHERE \"age\" <> 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(true == Col.age))),
            "SELECT * FROM \"readers\" WHERE \"age\" <> 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(Col.age == false))),
            "SELECT * FROM \"readers\" WHERE \"age\" <> 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(false == Col.age))),
            "SELECT * FROM \"readers\" WHERE \"age\" <> 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { _ in !(true == true) }),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { _ in !(false == false) }),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { _ in !(true == false) }),
            "SELECT * FROM \"readers\" WHERE 1")
    }
    
    func testNotEqualWithCollation() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name.collating(.nocase) != "fOo")),
            "SELECT * FROM \"readers\" WHERE \"name\" <> 'fOo' COLLATE NOCASE")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name.collating(.nocase) != ("fOo" as String?))),
            "SELECT * FROM \"readers\" WHERE \"name\" <> 'fOo' COLLATE NOCASE")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name.collating(.nocase) != nil)),
            "SELECT * FROM \"readers\" WHERE \"name\" IS NOT NULL COLLATE NOCASE")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name.collating(.nocase) != DatabaseValue.null)),
            "SELECT * FROM \"readers\" WHERE \"name\" IS NOT NULL COLLATE NOCASE")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name.collating(collation) != "fOo")),
            "SELECT * FROM \"readers\" WHERE \"name\" <> 'fOo' COLLATE localized_case_insensitive")
    }
    
    func testNotEqualWithSwiftNotOperator() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(Col.age == 10))),
            "SELECT * FROM \"readers\" WHERE \"age\" <> 10")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(10 == Col.age))),
            "SELECT * FROM \"readers\" WHERE 10 <> \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { _ in !(10 == 10) }),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(Col.age == Col.age))),
            "SELECT * FROM \"readers\" WHERE \"age\" <> \"age\"")
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(Col.age == nil))),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(Col.age == DatabaseValue.null))),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(nil == Col.age))),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(DatabaseValue.null == Col.age))),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(Col.age == Col.age))),
            "SELECT * FROM \"readers\" WHERE \"age\" <> \"age\"")
    }
    
    func testIs() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age === 10)),
            "SELECT * FROM \"readers\" WHERE \"age\" IS 10")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(10 === Col.age)),
            "SELECT * FROM \"readers\" WHERE 10 IS \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age === Col.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" IS \"age\"")
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age === nil)),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(nil === Col.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age === Col.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" IS \"age\"")
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name === "B")),
            "SELECT * FROM \"readers\" WHERE \"name\" IS 'B'")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter("B" === Col.name)),
            "SELECT * FROM \"readers\" WHERE 'B' IS \"name\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name === Col.name)),
            "SELECT * FROM \"readers\" WHERE \"name\" IS \"name\"")
    }
    
    func testIsWithCollation() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name.collating(.nocase) === "fOo")),
            "SELECT * FROM \"readers\" WHERE \"name\" IS 'fOo' COLLATE NOCASE")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name.collating(collation) === "fOo")),
            "SELECT * FROM \"readers\" WHERE \"name\" IS 'fOo' COLLATE localized_case_insensitive")
    }
    
    func testIsNot() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age !== 10)),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT 10")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(10 !== Col.age)),
            "SELECT * FROM \"readers\" WHERE 10 IS NOT \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age !== Col.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT \"age\"")
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age !== nil)),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(nil !== Col.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age !== Col.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT \"age\"")
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name !== "B")),
            "SELECT * FROM \"readers\" WHERE \"name\" IS NOT 'B'")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter("B" !== Col.name)),
            "SELECT * FROM \"readers\" WHERE 'B' IS NOT \"name\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name !== Col.name)),
            "SELECT * FROM \"readers\" WHERE \"name\" IS NOT \"name\"")
    }
    
    func testIsNotWithCollation() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name.collating(.nocase) !== "fOo")),
            "SELECT * FROM \"readers\" WHERE \"name\" IS NOT 'fOo' COLLATE NOCASE")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name.collating(collation) !== "fOo")),
            "SELECT * FROM \"readers\" WHERE \"name\" IS NOT 'fOo' COLLATE localized_case_insensitive")
    }
    
    func testIsNotWithSwiftNotOperator() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(Col.age === 10))),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT 10")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(10 === Col.age))),
            "SELECT * FROM \"readers\" WHERE 10 IS NOT \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(Col.age === Col.age))),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT \"age\"")
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(Col.age === nil))),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(nil === Col.age))),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(Col.age === Col.age))),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT \"age\"")
    }
    
    func testLogicalOperators() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!Col.age)),
            "SELECT * FROM \"readers\" WHERE NOT \"age\"")
        // Make sure NOT NOT "hack" is available in order to produce 0 or 1
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(!Col.age))),
            "SELECT * FROM \"readers\" WHERE NOT (NOT \"age\")")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age && true)),
            "SELECT * FROM \"readers\" WHERE \"age\" AND 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(true && Col.age)),
            "SELECT * FROM \"readers\" WHERE 1 AND \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age || false)),
            "SELECT * FROM \"readers\" WHERE \"age\" OR 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(false || Col.age)),
            "SELECT * FROM \"readers\" WHERE 0 OR \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age != nil || Col.name == nil)),
            "SELECT * FROM \"readers\" WHERE (\"age\" IS NOT NULL) OR (\"name\" IS NULL)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age != nil || Col.name != nil && Col.id != nil)),
            "SELECT * FROM \"readers\" WHERE (\"age\" IS NOT NULL) OR ((\"name\" IS NOT NULL) AND (\"id\" IS NOT NULL))")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter((Col.age != nil || Col.name != nil) && Col.id != nil)),
            "SELECT * FROM \"readers\" WHERE ((\"age\" IS NOT NULL) OR (\"name\" IS NOT NULL)) AND (\"id\" IS NOT NULL)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(Col.age > 18) && !(Col.name > "foo"))),
            "SELECT * FROM \"readers\" WHERE (NOT (\"age\" > 18)) AND (NOT (\"name\" > 'foo'))")
    }
    
    func testJoinedOperatorAnd() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter([].joined(operator: .and))),
            "SELECT * FROM \"readers\" WHERE 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter([].joined(operator: .and) || false)),
            "SELECT * FROM \"readers\" WHERE 1 OR 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter([false.databaseValue].joined(operator: .and))),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter([false.databaseValue].joined(operator: .and) || false)),
            "SELECT * FROM \"readers\" WHERE 0 OR 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter([Col.id == 1].joined(operator: .and))),
            "SELECT * FROM \"readers\" WHERE \"id\" = 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter([Col.id == 1].joined(operator: .and) || false)),
            "SELECT * FROM \"readers\" WHERE (\"id\" = 1) OR 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter([Col.id == 1, Col.name != nil].joined(operator: .and))),
            "SELECT * FROM \"readers\" WHERE (\"id\" = 1) AND (\"name\" IS NOT NULL)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter([Col.id == 1, Col.name != nil].joined(operator: .and) || false)),
            "SELECT * FROM \"readers\" WHERE ((\"id\" = 1) AND (\"name\" IS NOT NULL)) OR 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter([Col.id == 1, Col.name != nil, Col.age == nil].joined(operator: .and))),
            "SELECT * FROM \"readers\" WHERE (\"id\" = 1) AND (\"name\" IS NOT NULL) AND (\"age\" IS NULL)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter([Col.id == 1, Col.name != nil, Col.age == nil].joined(operator: .and) || false)),
            "SELECT * FROM \"readers\" WHERE ((\"id\" = 1) AND (\"name\" IS NOT NULL) AND (\"age\" IS NULL)) OR 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(![Col.id == 1, Col.name != nil, Col.age == nil].joined(operator: .and))),
            "SELECT * FROM \"readers\" WHERE NOT ((\"id\" = 1) AND (\"name\" IS NOT NULL) AND (\"age\" IS NULL))")
    }
    
    func testJoinedOperatorOr() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter([].joined(operator: .or))),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter([].joined(operator: .or) && true)),
            "SELECT * FROM \"readers\" WHERE 0 AND 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter([true.databaseValue].joined(operator: .or))),
            "SELECT * FROM \"readers\" WHERE 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter([true.databaseValue].joined(operator: .or) && true)),
            "SELECT * FROM \"readers\" WHERE 1 AND 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter([Col.id == 1].joined(operator: .or))),
            "SELECT * FROM \"readers\" WHERE \"id\" = 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter([Col.id == 1].joined(operator: .or) && true)),
            "SELECT * FROM \"readers\" WHERE (\"id\" = 1) AND 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter([Col.id == 1, Col.name != nil].joined(operator: .or))),
            "SELECT * FROM \"readers\" WHERE (\"id\" = 1) OR (\"name\" IS NOT NULL)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter([Col.id == 1, Col.name != nil].joined(operator: .or) && true)),
            "SELECT * FROM \"readers\" WHERE ((\"id\" = 1) OR (\"name\" IS NOT NULL)) AND 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter([Col.id == 1, Col.name != nil, Col.age == nil].joined(operator: .or))),
            "SELECT * FROM \"readers\" WHERE (\"id\" = 1) OR (\"name\" IS NOT NULL) OR (\"age\" IS NULL)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter([Col.id == 1, Col.name != nil, Col.age == nil].joined(operator: .or) && true)),
            "SELECT * FROM \"readers\" WHERE ((\"id\" = 1) OR (\"name\" IS NOT NULL) OR (\"age\" IS NULL)) AND 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(![Col.id == 1, Col.name != nil, Col.age == nil].joined(operator: .or))),
            "SELECT * FROM \"readers\" WHERE NOT ((\"id\" = 1) OR (\"name\" IS NOT NULL) OR (\"age\" IS NULL))")
    }

    
    // MARK: - String functions
    
    func testStringFunctions() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(Col.name.capitalized)),
            "SELECT swiftCapitalizedString(\"name\") FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(Col.name.lowercased)),
            "SELECT swiftLowercaseString(\"name\") FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(Col.name.uppercased)),
            "SELECT swiftUppercaseString(\"name\") FROM \"readers\"")
        
        if #available(OSX 10.11, *) {
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
    
    func testPrefixMinusOperator() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(-Col.age)),
            "SELECT * FROM \"readers\" WHERE -\"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(-(Col.age + 1))),
            "SELECT * FROM \"readers\" WHERE -(\"age\" + 1)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(-(-Col.age + 1))),
            "SELECT * FROM \"readers\" WHERE -((-\"age\") + 1)")
    }
    
    func testInfixSubtractOperator() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age - 2)),
            "SELECT * FROM \"readers\" WHERE \"age\" - 2")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(2 - Col.age)),
            "SELECT * FROM \"readers\" WHERE 2 - \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { _ in 2 - 2 }),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age - Col.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" - \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter((Col.age - Col.age) - 1)),
            "SELECT * FROM \"readers\" WHERE (\"age\" - \"age\") - 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(1 - [Col.age > 1, Col.age == nil].joined(operator: .and))),
            "SELECT * FROM \"readers\" WHERE 1 - ((\"age\" > 1) AND (\"age\" IS NULL))")
    }
    
    func testInfixAddOperator() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age + 2)),
            "SELECT * FROM \"readers\" WHERE \"age\" + 2")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(2 + Col.age)),
            "SELECT * FROM \"readers\" WHERE 2 + \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { _ in 2 + 2 }),
            "SELECT * FROM \"readers\" WHERE 4")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age + Col.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" + \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(1 + (Col.age + Col.age))),
            "SELECT * FROM \"readers\" WHERE 1 + (\"age\" + \"age\")")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(1 + [Col.age > 1, Col.age == nil].joined(operator: .and))),
            "SELECT * FROM \"readers\" WHERE 1 + ((\"age\" > 1) AND (\"age\" IS NULL))")
    }
    
    func testJoinedAddOperator() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select([].joined(operator: .add))),
            "SELECT 0 FROM \"readers\"")

        XCTAssertEqual(
            sql(dbQueue, tableRequest.select([Col.age, Col.age].joined(operator: .add))),
            "SELECT \"age\" + \"age\" FROM \"readers\"")
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select([Col.age, 2.databaseValue, Col.age].joined(operator: .add))),
            "SELECT \"age\" + 2 + \"age\" FROM \"readers\"")

        // Not flattened
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select([
                [Col.age, 1.databaseValue].joined(operator: .add),
                [2.databaseValue, Col.age].joined(operator: .add),
                ].joined(operator: .add))),
            "SELECT (\"age\" + 1) + (2 + \"age\") FROM \"readers\"")
    }
    
    func testInfixMultiplyOperator() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age * 2)),
            "SELECT * FROM \"readers\" WHERE \"age\" * 2")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(2 * Col.age)),
            "SELECT * FROM \"readers\" WHERE 2 * \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { _ in 2 * 2 }),
            "SELECT * FROM \"readers\" WHERE 4")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age * Col.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" * \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(2 * (Col.age * Col.age))),
            "SELECT * FROM \"readers\" WHERE 2 * (\"age\" * \"age\")")
    }
    
    func testJoinedMultiplyOperator() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select([].joined(operator: .multiply))),
            "SELECT 1 FROM \"readers\"")

        XCTAssertEqual(
            sql(dbQueue, tableRequest.select([Col.age, Col.age].joined(operator: .multiply))),
            "SELECT \"age\" * \"age\" FROM \"readers\"")
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select([Col.age, 2.databaseValue, Col.age].joined(operator: .multiply))),
            "SELECT \"age\" * 2 * \"age\" FROM \"readers\"")

        // Not flattened
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select([
                [Col.age, 1.databaseValue].joined(operator: .multiply),
                [2.databaseValue, Col.age].joined(operator: .multiply),
                ].joined(operator: .multiply))),
            "SELECT (\"age\" * 1) * (2 * \"age\") FROM \"readers\"")
    }
    
    func testInfixDivideOperator() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age / 2)),
            "SELECT * FROM \"readers\" WHERE \"age\" / 2")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(2 / Col.age)),
            "SELECT * FROM \"readers\" WHERE 2 / \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { _ in 2 / 2 }),
            "SELECT * FROM \"readers\" WHERE 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age / Col.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" / \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(1 / (Col.age / Col.age))),
            "SELECT * FROM \"readers\" WHERE 1 / (\"age\" / \"age\")")
    }
    
    func testCompoundArithmeticExpression() throws {
        let dbQueue = try makeDatabaseQueue()
        
        // Int / Double
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age / 2.0)),
            "SELECT * FROM \"readers\" WHERE \"age\" / 2.0")
        // Double / Int
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(2.0 / Col.age)),
            "SELECT * FROM \"readers\" WHERE 2.0 / \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age + 2 * 5)),
            "SELECT * FROM \"readers\" WHERE \"age\" + 10")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age * 2 + 5)),
            "SELECT * FROM \"readers\" WHERE (\"age\" * 2) + 5")
    }
    
    
    // MARK: - IFNULL expression
    
    func testIfNull() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age ?? 2)),
            "SELECT * FROM \"readers\" WHERE IFNULL(\"age\", 2)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.age ?? Col.age)),
            "SELECT * FROM \"readers\" WHERE IFNULL(\"age\", \"age\")")
    }
    
    
    // MARK: - Aggregated expressions
    
    func testCountExpression() throws {
        let dbQueue = try makeDatabaseQueue()
        
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
            "SELECT COUNT(DISTINCT \"age\" / \"age\") FROM \"readers\"")
    }
    
    func testAvgExpression() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(average(Col.age))),
            "SELECT AVG(\"age\") FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(average(Col.age / 2))),
            "SELECT AVG(\"age\" / 2) FROM \"readers\"")
    }
    
    func testLengthExpression() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(length(Col.name))),
            "SELECT LENGTH(\"name\") FROM \"readers\"")
    }
    
    func testMinExpression() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(min(Col.age))),
            "SELECT MIN(\"age\") FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(min(Col.age / 2))),
            "SELECT MIN(\"age\" / 2) FROM \"readers\"")
    }
    
    func testMaxExpression() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(max(Col.age))),
            "SELECT MAX(\"age\") FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(max(Col.age / 2))),
            "SELECT MAX(\"age\" / 2) FROM \"readers\"")
    }
    
    func testSumExpression() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(sum(Col.age))),
            "SELECT SUM(\"age\") FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(sum(Col.age / 2))),
            "SELECT SUM(\"age\" / 2) FROM \"readers\"")
    }
    
    
    // MARK: - LIKE operator
    
    func testLikeOperator() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name.like("%foo"))),
            "SELECT * FROM \"readers\" WHERE \"name\" LIKE '%foo'")
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!Col.name.like("%foo"))),
            "SELECT * FROM \"readers\" WHERE \"name\" NOT LIKE '%foo'")
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name.like("%foo") == true)),
            "SELECT * FROM \"readers\" WHERE (\"name\" LIKE '%foo') = 1")
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Col.name.like("%foo") == false)),
            "SELECT * FROM \"readers\" WHERE (\"name\" LIKE '%foo') = 0")
    }
    
    
    // MARK: - || concat operator
    
    func testConcatOperator() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select([Col.name, Col.name].joined(operator: .concat))),
            """
            SELECT "name" || "name" FROM "readers"
            """)
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter([Col.name, Col.name].joined(operator: .concat) == "foo")),
            """
            SELECT * FROM "readers" WHERE ("name" || "name") = 'foo'
            """)
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select([Col.name, " ".databaseValue, Col.name].joined(operator: .concat))),
            """
            SELECT "name" || ' ' || "name" FROM "readers"
            """)
        
        // Flattened
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select([
                [Col.name, "a".databaseValue].joined(operator: .concat),
                ["b".databaseValue, Col.name].joined(operator: .concat),
                ].joined(operator: .concat))),
            """
            SELECT "name" || 'a' || 'b' || "name" FROM "readers"
            """)
    }

    
    // MARK: - Function
    
    func testCustomFunction() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(customFunction(Col.age, 1, 2))),
            "SELECT avgOf(\"age\", 1, 2) FROM \"readers\"")
    }
    
    // MARK: - SQLExpressionFastPrimaryKey
    
    func testFastPrimaryKeyExpression() throws {
        struct IntegerPrimaryKeyRecord: TableRecord { }
        struct UUIDRecord: TableRecord { }
        struct UUIDRecordWithoutRowID: TableRecord { }
        struct RowIDRecord: TableRecord { }
        struct CompoundPrimaryKeyRecord: TableRecord { }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.execute(sql: """
                CREATE TABLE integerPrimaryKeyRecord (id INTEGER PRIMARY KEY);
                CREATE TABLE uuidRecord (uuid TEXT PRIMARY KEY);
                CREATE TABLE uuidRecordWithoutRowID (uuid TEXT PRIMARY KEY) WITHOUT ROWID;
                CREATE TABLE rowIDRecord (name TEXT);
                CREATE TABLE compoundPrimaryKeyRecord (a INTEGER, b INTEGER, PRIMARY KEY (a, b));
                """)
            
            try assertEqualSQL(db, IntegerPrimaryKeyRecord.select(SQLExpressionFastPrimaryKey()), """
                SELECT "id" FROM "integerPrimaryKeyRecord"
                """)
            try assertEqualSQL(db, UUIDRecord.select(SQLExpressionFastPrimaryKey()), """
                SELECT "rowid" FROM "uuidRecord"
                """)
            try assertEqualSQL(db, UUIDRecordWithoutRowID.select(SQLExpressionFastPrimaryKey()), """
                SELECT "uuid" FROM "uuidRecordWithoutRowID"
                """)
            try assertEqualSQL(db, RowIDRecord.select(SQLExpressionFastPrimaryKey()), """
                SELECT "rowid" FROM "rowIDRecord"
                """)
            try assertEqualSQL(db, CompoundPrimaryKeyRecord.select(SQLExpressionFastPrimaryKey()), """
                SELECT "rowid" FROM "compoundPrimaryKeyRecord"
                """)
        }
    }
}

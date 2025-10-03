import XCTest
@testable import GRDB

private struct Reader : TableRecord {
    static let databaseTableName = "readers"
    
    struct Columns {
        static let id = Column("id")
        static let name = Column("name")
        static let age = Column("age")
        static let readerId = Column("readerId")
    }
}
private typealias Columns = Reader.Columns
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
    
    override func setup(_ dbWriter: some DatabaseWriter) throws {
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
            sql(dbQueue, tableRequest.filter([Int]().contains(Columns.id))),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { [Int]().contains($0.id) }),
            "SELECT * FROM \"readers\" WHERE 0")

        // !emptyArray.contains(): 0
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(![Int]().contains(Columns.id))),
            "SELECT * FROM \"readers\" WHERE 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { ![Int]().contains($0.id) }),
            "SELECT * FROM \"readers\" WHERE 1")

        // Array.contains(): = operator
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter([1].contains(Columns.id))),
            "SELECT * FROM \"readers\" WHERE \"id\" = 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { [1].contains($0.id) }),
            "SELECT * FROM \"readers\" WHERE \"id\" = 1")

        // Array.contains(): IN operator
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter([1,2,3].contains(Columns.id))),
            "SELECT * FROM \"readers\" WHERE \"id\" IN (1, 2, 3)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { [1,2,3].contains($0.id) }),
            "SELECT * FROM \"readers\" WHERE \"id\" IN (1, 2, 3)")

        // Array.contains(): IN operator
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter([Columns.id].contains(Columns.id))),
            "SELECT * FROM \"readers\" WHERE \"id\" = \"id\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { [$0.id].contains($0.id) }),
            "SELECT * FROM \"readers\" WHERE \"id\" = \"id\"")

        // EmptyCollection.contains(): 0
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(EmptyCollection<Int>().contains(Columns.id))),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { EmptyCollection<Int>().contains($0.id) }),
            "SELECT * FROM \"readers\" WHERE 0")

        // !EmptyCollection.contains(): 1
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!EmptyCollection<Int>().contains(Columns.id))),
            "SELECT * FROM \"readers\" WHERE 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { !EmptyCollection<Int>().contains($0.id) }),
            "SELECT * FROM \"readers\" WHERE 1")

        // Sequence.contains(): = operator
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(AnySequence([1]).contains(Columns.id))),
            "SELECT * FROM \"readers\" WHERE \"id\" = 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { AnySequence([1]).contains($0.id) }),
            "SELECT * FROM \"readers\" WHERE \"id\" = 1")

        // Sequence.contains(): IN operator
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(AnySequence([1,2,3]).contains(Columns.id))),
            "SELECT * FROM \"readers\" WHERE \"id\" IN (1, 2, 3)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { AnySequence([1,2,3]).contains($0.id) }),
            "SELECT * FROM \"readers\" WHERE \"id\" IN (1, 2, 3)")

        // Sequence.contains(): IN operator
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(AnySequence([Columns.id]).contains(Columns.id))),
            "SELECT * FROM \"readers\" WHERE \"id\" = \"id\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { AnySequence([$0.id]).contains($0.id) }),
            "SELECT * FROM \"readers\" WHERE \"id\" = \"id\"")

        // !Sequence.contains(): <> operator
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(![1].contains(Columns.id))),
            "SELECT * FROM \"readers\" WHERE \"id\" <> 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { ![1].contains($0.id) }),
            "SELECT * FROM \"readers\" WHERE \"id\" <> 1")

        // !Sequence.contains(): NOT IN operator
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(![1,2,3].contains(Columns.id))),
            "SELECT * FROM \"readers\" WHERE \"id\" NOT IN (1, 2, 3)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { ![1,2,3].contains($0.id) }),
            "SELECT * FROM \"readers\" WHERE \"id\" NOT IN (1, 2, 3)")

        // !!Sequence.contains(): = operator
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(![1].contains(Columns.id)))),
            "SELECT * FROM \"readers\" WHERE \"id\" = 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { !(![1].contains($0.id)) }),
            "SELECT * FROM \"readers\" WHERE \"id\" = 1")

        // !!Sequence.contains(): IN operator
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(![1,2,3].contains(Columns.id)))),
            "SELECT * FROM \"readers\" WHERE \"id\" IN (1, 2, 3)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { !(![1,2,3].contains($0.id)) }),
            "SELECT * FROM \"readers\" WHERE \"id\" IN (1, 2, 3)")

        // CountableRange.contains(): min <= x < max
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter((1..<10).contains(Columns.id))),
            "SELECT * FROM \"readers\" WHERE (\"id\" >= 1) AND (\"id\" < 10)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { (1..<10).contains($0.id) }),
            "SELECT * FROM \"readers\" WHERE (\"id\" >= 1) AND (\"id\" < 10)")

        // CountableClosedRange.contains(): BETWEEN operator
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter((1...10).contains(Columns.id))),
            "SELECT * FROM \"readers\" WHERE \"id\" BETWEEN 1 AND 10")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { (1...10).contains($0.id) }),
            "SELECT * FROM \"readers\" WHERE \"id\" BETWEEN 1 AND 10")

        // !CountableClosedRange.contains(): BETWEEN operator
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(1...10).contains(Columns.id))),
            "SELECT * FROM \"readers\" WHERE \"id\" NOT BETWEEN 1 AND 10")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { !(1...10).contains($0.id) }),
            "SELECT * FROM \"readers\" WHERE \"id\" NOT BETWEEN 1 AND 10")

        // Range.contains(): min <= x < max
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter((1.1..<10.9).contains(Columns.id))),
            "SELECT * FROM \"readers\" WHERE (\"id\" >= 1.1) AND (\"id\" < 10.9)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { (1.1..<10.9).contains($0.id) }),
            "SELECT * FROM \"readers\" WHERE (\"id\" >= 1.1) AND (\"id\" < 10.9)")

        // Range.contains(): min <= x < max
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(("A"..<"z").contains(Columns.name))),
            "SELECT * FROM \"readers\" WHERE (\"name\" >= 'A') AND (\"name\" < 'z')")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { ("A"..<"z").contains($0.name) }),
            "SELECT * FROM \"readers\" WHERE (\"name\" >= 'A') AND (\"name\" < 'z')")

        // ClosedRange.contains(): BETWEEN operator
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter((1.1...10.9).contains(Columns.id))),
            "SELECT * FROM \"readers\" WHERE \"id\" BETWEEN 1.1 AND 10.9")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { (1.1...10.9).contains($0.id) }),
            "SELECT * FROM \"readers\" WHERE \"id\" BETWEEN 1.1 AND 10.9")

        // ClosedRange.contains(): BETWEEN operator
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(("A"..."z").contains(Columns.name))),
            "SELECT * FROM \"readers\" WHERE \"name\" BETWEEN 'A' AND 'z'")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { ("A"..."z").contains($0.name) }),
            "SELECT * FROM \"readers\" WHERE \"name\" BETWEEN 'A' AND 'z'")

        // !ClosedRange.contains(): NOT BETWEEN operator
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!("A"..."z").contains(Columns.name))),
            "SELECT * FROM \"readers\" WHERE \"name\" NOT BETWEEN 'A' AND 'z'")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { !("A"..."z").contains($0.name) }),
            "SELECT * FROM \"readers\" WHERE \"name\" NOT BETWEEN 'A' AND 'z'")
    }
    
    func testContainsCollated() throws {
        let dbQueue = try makeDatabaseQueue()
        
        try dbQueue.read { db in
            // Reminder of the SQLite behavior
            // https://sqlite.org/datatype3.html#assigning_collating_sequences_from_sql
            // > If an explicit collating sequence is required on an IN operator
            // > it should be applied to the left operand, like this:
            // > "x COLLATE nocase IN (y,z, ...)".
            try XCTAssertFalse(Bool.fetchOne(db, sql: "SELECT 'arthur' IN ('ARTHUR') COLLATE NOCASE")!)
            try XCTAssertTrue(Bool.fetchOne(db, sql: "SELECT 'arthur' COLLATE NOCASE IN ('ARTHUR')")!)
        }
        
        // Array.contains(): IN operator
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(["arthur", "barbara"].contains(Columns.name.collating(.nocase)))),
            "SELECT * FROM \"readers\" WHERE (\"name\" COLLATE NOCASE) IN ('arthur', 'barbara')")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { ["arthur", "barbara"].contains($0.name.collating(.nocase)) }),
            "SELECT * FROM \"readers\" WHERE (\"name\" COLLATE NOCASE) IN ('arthur', 'barbara')")

        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!["arthur", "barbara"].contains(Columns.name.collating(.nocase)))),
            "SELECT * FROM \"readers\" WHERE (\"name\" COLLATE NOCASE) NOT IN ('arthur', 'barbara')")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { !["arthur", "barbara"].contains($0.name.collating(.nocase)) }),
            "SELECT * FROM \"readers\" WHERE (\"name\" COLLATE NOCASE) NOT IN ('arthur', 'barbara')")

        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter((["arthur", "barbara"] as [any SQLExpressible]).contains(Columns.name.collating(.nocase)))),
            "SELECT * FROM \"readers\" WHERE (\"name\" COLLATE NOCASE) IN ('arthur', 'barbara')")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { (["arthur", "barbara"] as [any SQLExpressible]).contains($0.name.collating(.nocase)) }),
            "SELECT * FROM \"readers\" WHERE (\"name\" COLLATE NOCASE) IN ('arthur', 'barbara')")

        // Sequence.contains(): IN operator
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(AnySequence(["arthur", "barbara"]).contains(Columns.name.collating(.nocase)))),
            "SELECT * FROM \"readers\" WHERE (\"name\" COLLATE NOCASE) IN ('arthur', 'barbara')")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { AnySequence(["arthur", "barbara"]).contains($0.name.collating(.nocase)) }),
            "SELECT * FROM \"readers\" WHERE (\"name\" COLLATE NOCASE) IN ('arthur', 'barbara')")

        // Sequence.contains(): = operator
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(AnySequence([Columns.name]).contains(Columns.name.collating(.nocase)))),
            "SELECT * FROM \"readers\" WHERE \"name\" = \"name\" COLLATE NOCASE")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { AnySequence([$0.name]).contains($0.name.collating(.nocase)) }),
            "SELECT * FROM \"readers\" WHERE \"name\" = \"name\" COLLATE NOCASE")

        // Sequence.contains(): false
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(EmptyCollection<Int>().contains(Columns.name.collating(.nocase)))),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { EmptyCollection<Int>().contains($0.name.collating(.nocase)) }),
            "SELECT * FROM \"readers\" WHERE 0")

        // ClosedInterval: BETWEEN operator
        let closedInterval = "A"..."z"
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(closedInterval.contains(Columns.name.collating(.nocase)))),
            "SELECT * FROM \"readers\" WHERE \"name\" BETWEEN 'A' AND 'z' COLLATE NOCASE")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { closedInterval.contains($0.name.collating(.nocase)) }),
            "SELECT * FROM \"readers\" WHERE \"name\" BETWEEN 'A' AND 'z' COLLATE NOCASE")

        // HalfOpenInterval:  min <= x < max
        let halfOpenInterval = "A"..<"z"
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(halfOpenInterval.contains(Columns.name.collating(.nocase)))),
            "SELECT * FROM \"readers\" WHERE (\"name\" >= 'A' COLLATE NOCASE) AND (\"name\" < 'z' COLLATE NOCASE)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { halfOpenInterval.contains($0.name.collating(.nocase)) }),
            "SELECT * FROM \"readers\" WHERE (\"name\" >= 'A' COLLATE NOCASE) AND (\"name\" < 'z' COLLATE NOCASE)")
    }
    
    func testCollatedContains() throws {
        let dbQueue = try makeDatabaseQueue()
        
        try dbQueue.read { db in
            // Reminder of the SQLite behavior
            // https://sqlite.org/datatype3.html#assigning_collating_sequences_from_sql
            // > If an explicit collating sequence is required on an IN operator
            // > it should be applied to the left operand, like this:
            // > "x COLLATE nocase IN (y,z, ...)".
            try XCTAssertFalse(Bool.fetchOne(db, sql: "SELECT 'arthur' IN ('ARTHUR') COLLATE NOCASE")!)
            try XCTAssertTrue(Bool.fetchOne(db, sql: "SELECT 'arthur' COLLATE NOCASE IN ('ARTHUR')")!)
        }
        
        // Array.contains(): IN operator
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(["arthur", "barbara"].contains(Columns.name).collating(.nocase))),
            "SELECT * FROM \"readers\" WHERE (\"name\" COLLATE NOCASE) IN ('arthur', 'barbara')")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { ["arthur", "barbara"].contains($0.name).collating(.nocase) }),
            "SELECT * FROM \"readers\" WHERE (\"name\" COLLATE NOCASE) IN ('arthur', 'barbara')")

        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!["arthur", "barbara"].contains(Columns.name).collating(.nocase))),
            "SELECT * FROM \"readers\" WHERE (\"name\" COLLATE NOCASE) NOT IN ('arthur', 'barbara')")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { !["arthur", "barbara"].contains($0.name).collating(.nocase) }),
            "SELECT * FROM \"readers\" WHERE (\"name\" COLLATE NOCASE) NOT IN ('arthur', 'barbara')")

        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter((["arthur", "barbara"] as [any SQLExpressible]).contains(Columns.name).collating(.nocase))),
            "SELECT * FROM \"readers\" WHERE (\"name\" COLLATE NOCASE) IN ('arthur', 'barbara')")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { (["arthur", "barbara"] as [any SQLExpressible]).contains($0.name).collating(.nocase) }),
            "SELECT * FROM \"readers\" WHERE (\"name\" COLLATE NOCASE) IN ('arthur', 'barbara')")

        // Sequence.contains(): IN operator
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(AnySequence(["arthur", "barbara"]).contains(Columns.name).collating(.nocase))),
            "SELECT * FROM \"readers\" WHERE (\"name\" COLLATE NOCASE) IN ('arthur', 'barbara')")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { AnySequence(["arthur", "barbara"]).contains($0.name).collating(.nocase) }),
            "SELECT * FROM \"readers\" WHERE (\"name\" COLLATE NOCASE) IN ('arthur', 'barbara')")

        // Sequence.contains(): = operator
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(AnySequence([Columns.name]).contains(Columns.name).collating(.nocase))),
            "SELECT * FROM \"readers\" WHERE \"name\" = \"name\" COLLATE NOCASE")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { AnySequence([$0.name]).contains($0.name).collating(.nocase) }),
            "SELECT * FROM \"readers\" WHERE \"name\" = \"name\" COLLATE NOCASE")

        // Sequence.contains(): false
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(EmptyCollection<Int>().contains(Columns.name).collating(.nocase))),
            "SELECT * FROM \"readers\" WHERE 0 COLLATE NOCASE")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { EmptyCollection<Int>().contains($0.name).collating(.nocase) }),
            "SELECT * FROM \"readers\" WHERE 0 COLLATE NOCASE")

        // ClosedInterval: BETWEEN operator
        let closedInterval = "A"..."z"
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(closedInterval.contains(Columns.name).collating(.nocase))),
            "SELECT * FROM \"readers\" WHERE \"name\" BETWEEN 'A' AND 'z' COLLATE NOCASE")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { closedInterval.contains($0.name).collating(.nocase) }),
            "SELECT * FROM \"readers\" WHERE \"name\" BETWEEN 'A' AND 'z' COLLATE NOCASE")

        // HalfOpenInterval:  min <= x < max
        let halfOpenInterval = "A"..<"z"
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(halfOpenInterval.contains(Columns.name).collating(.nocase))),
            "SELECT * FROM \"readers\" WHERE (\"name\" >= 'A' COLLATE NOCASE) AND (\"name\" < 'z' COLLATE NOCASE)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { halfOpenInterval.contains($0.name).collating(.nocase) }),
            "SELECT * FROM \"readers\" WHERE (\"name\" >= 'A' COLLATE NOCASE) AND (\"name\" < 'z' COLLATE NOCASE)")
    }

    func testSubqueryContains() throws {
        let dbQueue = try makeDatabaseQueue()
        
        do {
            let subquery = tableRequest.select(Columns.age).filter(Columns.name != nil).distinct()
            XCTAssertEqual(
                sql(dbQueue, tableRequest.filter(subquery.contains(Columns.age))),
                """
                SELECT * FROM "readers" WHERE "age" IN \
                (SELECT DISTINCT "age" FROM "readers" WHERE "name" IS NOT NULL)
                """)
        }
        
        do {
            let subquery = tableRequest.select { $0.age }.filter { $0.name != nil }.distinct()
            XCTAssertEqual(
                sql(dbQueue, tableRequest.filter { subquery.contains($0.age) }),
                """
                SELECT * FROM "readers" WHERE "age" IN \
                (SELECT DISTINCT "age" FROM "readers" WHERE "name" IS NOT NULL)
                """)
        }
        
        do {
            let subquery = SQLRequest<Int>(sql: "SELECT ? UNION SELECT ?", arguments: [1, 2])
            XCTAssertEqual(
                sql(dbQueue, tableRequest.filter(subquery.contains(Columns.age + 1))),
                """
                SELECT * FROM "readers" WHERE ("age" + 1) IN (SELECT 1 UNION SELECT 2)
                """)
        }
        
        do {
            let subquery = SQLRequest<Int>(sql: "SELECT ? UNION SELECT ?", arguments: [1, 2])
            XCTAssertEqual(
                sql(dbQueue, tableRequest.filter { subquery.contains($0.age + 1) }),
                """
                SELECT * FROM "readers" WHERE ("age" + 1) IN (SELECT 1 UNION SELECT 2)
                """)
        }
        
        do {
            let subquery1 = tableRequest.select(max(Columns.age))
            let subquery2 = tableRequest.filter(Columns.age == subquery1)
            XCTAssertEqual(
                sql(dbQueue, tableRequest.filter(subquery2.select(Columns.id).contains(Columns.id))),
                """
                SELECT * FROM "readers" WHERE "id" IN (\
                SELECT "id" FROM "readers" WHERE "age" = (\
                SELECT MAX("age") FROM "readers"))
                """)
        }
        
        do {
            let subquery1 = tableRequest.select { max($0.age) }
            let subquery2 = tableRequest.filter { $0.age == subquery1 }
            XCTAssertEqual(
                sql(dbQueue, tableRequest.filter { subquery2.select($0.id).contains($0.id) }),
                """
                SELECT * FROM "readers" WHERE "id" IN (\
                SELECT "id" FROM "readers" WHERE "age" = (\
                SELECT MAX("age") FROM "readers"))
                """)
        }
    }
    
    func testSubqueryExists() throws {
        let dbQueue = try makeDatabaseQueue()
        
        do {
            try dbQueue.write { db in
                try db.create(table: "team") { t in
                    t.autoIncrementedPrimaryKey("id")
                }
                try db.create(table: "player") { t in
                    t.column("teamID", .integer).references("team")
                }
                struct Player: TableRecord {
                    enum Columns {
                        static let teamID = Column("teamID")
                    }
                }
                struct Team: TableRecord {
                    enum Columns {
                        static let id = Column("id")
                    }
                }
                
                do {
                    let teamAlias = TableAlias()
                    let player = Player.filter(Column("teamID") == teamAlias[Column("id")])
                    let teams = Team.aliased(teamAlias).filter(player.exists())
                    try assertEqualSQL(db, teams, """
                        SELECT * FROM "team" WHERE EXISTS (SELECT * FROM "player" WHERE "teamID" = "team"."id")
                        """)
                }
                #if compiler(>=6.1)
                do {
                    let teamAlias = TableAlias<Team>()
                    let player = Player.filter { $0.teamID == teamAlias.id }
                    let teams = Team.aliased(teamAlias).filter(player.exists())
                    try assertEqualSQL(db, teams, """
                        SELECT * FROM "team" WHERE EXISTS (SELECT * FROM "player" WHERE "teamID" = "team"."id")
                        """)
                }
                #endif
            }
        }
        
        do {
            let alias = TableAlias(name: "r")
            let subquery = tableRequest.filter(Columns.age > alias[Columns.age])
            XCTAssertEqual(
                sql(dbQueue, tableRequest.aliased(alias).filter(subquery.exists())),
                """
                SELECT "r".* FROM "readers" "r" WHERE EXISTS (SELECT * FROM "readers" WHERE "age" > "r"."age")
                """)
        }
        
        do {
            let alias = TableAlias(name: "r")
            let subquery = tableRequest.filter { $0.age > alias[$0.age] }
            XCTAssertEqual(
                sql(dbQueue, tableRequest.aliased(alias).filter(subquery.exists())),
                """
                SELECT "r".* FROM "readers" "r" WHERE EXISTS (SELECT * FROM "readers" WHERE "age" > "r"."age")
                """)
        }
        
        do {
            let alias = TableAlias(name: "r")
            let subquery = tableRequest.filter(Columns.age > alias[Columns.age])
            XCTAssertEqual(
                sql(dbQueue, tableRequest.aliased(alias).filter(!subquery.exists())),
                """
                SELECT "r".* FROM "readers" "r" WHERE NOT EXISTS (SELECT * FROM "readers" WHERE "age" > "r"."age")
                """)
        }
        
        do {
            let alias = TableAlias(name: "r")
            let subquery = tableRequest.filter { $0.age > alias[$0.age] }
            XCTAssertEqual(
                sql(dbQueue, tableRequest.aliased(alias).filter(!subquery.exists())),
                """
                SELECT "r".* FROM "readers" "r" WHERE NOT EXISTS (SELECT * FROM "readers" WHERE "age" > "r"."age")
                """)
        }
        
        do {
            let alias = TableAlias(name: "r")
            let subquery = SQLRequest<Row>("SELECT * FROM readers WHERE age > \(alias[Columns.age])")
            XCTAssertEqual(
                sql(dbQueue, tableRequest.aliased(alias).filter(subquery.exists())),
                """
                SELECT "r".* FROM "readers" "r" WHERE EXISTS (SELECT * FROM readers WHERE age > "r"."age")
                """)
        }
    }

    func testGreaterThan() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age > 10)),
            "SELECT * FROM \"readers\" WHERE \"age\" > 10")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age > 10 }),
            "SELECT * FROM \"readers\" WHERE \"age\" > 10")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(10 > Columns.age)),
            "SELECT * FROM \"readers\" WHERE 10 > \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { 10 > $0.age }),
            "SELECT * FROM \"readers\" WHERE 10 > \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filterWhenConnected { _ in 10 > 10 }),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age > Columns.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" > \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age > $0.age }),
            "SELECT * FROM \"readers\" WHERE \"age\" > \"age\"")

        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.name > "B")),
            "SELECT * FROM \"readers\" WHERE \"name\" > 'B'")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.name > "B" }),
            "SELECT * FROM \"readers\" WHERE \"name\" > 'B'")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter("B" > Columns.name)),
            "SELECT * FROM \"readers\" WHERE 'B' > \"name\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { "B" > $0.name }),
            "SELECT * FROM \"readers\" WHERE 'B' > \"name\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filterWhenConnected { _ in "B" > "B" }),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.name > Columns.name)),
            "SELECT * FROM \"readers\" WHERE \"name\" > \"name\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.name > $0.name }),
            "SELECT * FROM \"readers\" WHERE \"name\" > \"name\"")

        XCTAssertEqual(
            sql(dbQueue, tableRequest.group(Columns.name).having(average(Columns.age) + 10 > 20)),
            "SELECT * FROM \"readers\" GROUP BY \"name\" HAVING (AVG(\"age\") + 10) > 20")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.group { $0.name }.having { average($0.age) + 10 > 20 }),
            "SELECT * FROM \"readers\" GROUP BY \"name\" HAVING (AVG(\"age\") + 10) > 20")
    }
    
    func testGreaterThanWithCollation() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.name.collating(.nocase) > "fOo")),
            "SELECT * FROM \"readers\" WHERE \"name\" > 'fOo' COLLATE NOCASE")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.name.collating(.nocase) > "fOo" }),
            "SELECT * FROM \"readers\" WHERE \"name\" > 'fOo' COLLATE NOCASE")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.name.collating(collation) > "fOo")),
            "SELECT * FROM \"readers\" WHERE \"name\" > 'fOo' COLLATE localized_case_insensitive")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.name.collating(collation) > "fOo" }),
            "SELECT * FROM \"readers\" WHERE \"name\" > 'fOo' COLLATE localized_case_insensitive")
    }
    
    func testGreaterThanOrEqual() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age >= 10)),
            "SELECT * FROM \"readers\" WHERE \"age\" >= 10")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age >= 10 }),
            "SELECT * FROM \"readers\" WHERE \"age\" >= 10")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(10 >= Columns.age)),
            "SELECT * FROM \"readers\" WHERE 10 >= \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { 10 >= $0.age }),
            "SELECT * FROM \"readers\" WHERE 10 >= \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filterWhenConnected { _ in 10 >= 10 }),
            "SELECT * FROM \"readers\" WHERE 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age >= Columns.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" >= \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age >= Columns.age }),
            "SELECT * FROM \"readers\" WHERE \"age\" >= \"age\"")

        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.name >= "B")),
            "SELECT * FROM \"readers\" WHERE \"name\" >= 'B'")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.name >= "B" }),
            "SELECT * FROM \"readers\" WHERE \"name\" >= 'B'")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter("B" >= Columns.name)),
            "SELECT * FROM \"readers\" WHERE 'B' >= \"name\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { "B" >= $0.name }),
            "SELECT * FROM \"readers\" WHERE 'B' >= \"name\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filterWhenConnected { _ in "B" >= "B" }),
            "SELECT * FROM \"readers\" WHERE 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.name >= Columns.name)),
            "SELECT * FROM \"readers\" WHERE \"name\" >= \"name\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.name >= $0.name }),
            "SELECT * FROM \"readers\" WHERE \"name\" >= \"name\"")

        XCTAssertEqual(
            sql(dbQueue, tableRequest.group(Columns.name).having(average(Columns.age) + 10 >= 20)),
            "SELECT * FROM \"readers\" GROUP BY \"name\" HAVING (AVG(\"age\") + 10) >= 20")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.group { $0.name }.having { average($0.age) + 10 >= 20 }),
            "SELECT * FROM \"readers\" GROUP BY \"name\" HAVING (AVG(\"age\") + 10) >= 20")
    }
    
    func testGreaterThanOrEqualWithCollation() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.name.collating(.nocase) >= "fOo")),
            "SELECT * FROM \"readers\" WHERE \"name\" >= 'fOo' COLLATE NOCASE")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.name.collating(.nocase) >= "fOo" }),
            "SELECT * FROM \"readers\" WHERE \"name\" >= 'fOo' COLLATE NOCASE")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.name.collating(collation) >= "fOo")),
            "SELECT * FROM \"readers\" WHERE \"name\" >= 'fOo' COLLATE localized_case_insensitive")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.name.collating(collation) >= "fOo" }),
            "SELECT * FROM \"readers\" WHERE \"name\" >= 'fOo' COLLATE localized_case_insensitive")
    }
    
    func testLessThan() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age < 10)),
            "SELECT * FROM \"readers\" WHERE \"age\" < 10")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age < 10 }),
            "SELECT * FROM \"readers\" WHERE \"age\" < 10")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(10 < Columns.age)),
            "SELECT * FROM \"readers\" WHERE 10 < \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { 10 < $0.age }),
            "SELECT * FROM \"readers\" WHERE 10 < \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filterWhenConnected { _ in 10 < 10 }),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age < Columns.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" < \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age < $0.age }),
            "SELECT * FROM \"readers\" WHERE \"age\" < \"age\"")

        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.name < "B")),
            "SELECT * FROM \"readers\" WHERE \"name\" < 'B'")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.name < "B" }),
            "SELECT * FROM \"readers\" WHERE \"name\" < 'B'")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter("B" < Columns.name)),
            "SELECT * FROM \"readers\" WHERE 'B' < \"name\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { "B" < $0.name }),
            "SELECT * FROM \"readers\" WHERE 'B' < \"name\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filterWhenConnected { _ in "B" < "B" }),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.name < Columns.name)),
            "SELECT * FROM \"readers\" WHERE \"name\" < \"name\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.name < $0.name }),
            "SELECT * FROM \"readers\" WHERE \"name\" < \"name\"")

        XCTAssertEqual(
            sql(dbQueue, tableRequest.group(Columns.name).having(average(Columns.age) + 10 < 20)),
            "SELECT * FROM \"readers\" GROUP BY \"name\" HAVING (AVG(\"age\") + 10) < 20")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.group { $0.name }.having { average($0.age) + 10 < 20 }),
            "SELECT * FROM \"readers\" GROUP BY \"name\" HAVING (AVG(\"age\") + 10) < 20")
    }
    
    func testLessThanWithCollation() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.name.collating(.nocase) < "fOo")),
            "SELECT * FROM \"readers\" WHERE \"name\" < 'fOo' COLLATE NOCASE")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.name.collating(.nocase) < "fOo" }),
            "SELECT * FROM \"readers\" WHERE \"name\" < 'fOo' COLLATE NOCASE")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.name.collating(collation) < "fOo")),
            "SELECT * FROM \"readers\" WHERE \"name\" < 'fOo' COLLATE localized_case_insensitive")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.name.collating(collation) < "fOo" }),
            "SELECT * FROM \"readers\" WHERE \"name\" < 'fOo' COLLATE localized_case_insensitive")
    }
    
    func testLessThanOrEqual() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age <= 10)),
            "SELECT * FROM \"readers\" WHERE \"age\" <= 10")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age <= 10 }),
            "SELECT * FROM \"readers\" WHERE \"age\" <= 10")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(10 <= Columns.age)),
            "SELECT * FROM \"readers\" WHERE 10 <= \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { 10 <= $0.age }),
            "SELECT * FROM \"readers\" WHERE 10 <= \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filterWhenConnected { _ in 10 <= 10 }),
            "SELECT * FROM \"readers\" WHERE 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age <= Columns.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" <= \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age <= $0.age }),
            "SELECT * FROM \"readers\" WHERE \"age\" <= \"age\"")

        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.name <= "B")),
            "SELECT * FROM \"readers\" WHERE \"name\" <= 'B'")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.name <= "B" }),
            "SELECT * FROM \"readers\" WHERE \"name\" <= 'B'")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter("B" <= Columns.name)),
            "SELECT * FROM \"readers\" WHERE 'B' <= \"name\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { "B" <= $0.name }),
            "SELECT * FROM \"readers\" WHERE 'B' <= \"name\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filterWhenConnected { _ in "B" <= "B" }),
            "SELECT * FROM \"readers\" WHERE 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.name <= Columns.name)),
            "SELECT * FROM \"readers\" WHERE \"name\" <= \"name\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.name <= $0.name }),
            "SELECT * FROM \"readers\" WHERE \"name\" <= \"name\"")

        XCTAssertEqual(
            sql(dbQueue, tableRequest.group(Columns.name).having(average(Columns.age) + 10 <= 20)),
            "SELECT * FROM \"readers\" GROUP BY \"name\" HAVING (AVG(\"age\") + 10) <= 20")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.group { $0.name }.having { average($0.age) + 10 <= 20 }),
            "SELECT * FROM \"readers\" GROUP BY \"name\" HAVING (AVG(\"age\") + 10) <= 20")
    }
    
    func testLessThanOrEqualWithCollation() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.name.collating(.nocase) <= "fOo")),
            "SELECT * FROM \"readers\" WHERE \"name\" <= 'fOo' COLLATE NOCASE")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.name.collating(.nocase) <= "fOo" }),
            "SELECT * FROM \"readers\" WHERE \"name\" <= 'fOo' COLLATE NOCASE")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.name.collating(collation) <= "fOo")),
            "SELECT * FROM \"readers\" WHERE \"name\" <= 'fOo' COLLATE localized_case_insensitive")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.name.collating(collation) <= "fOo" }),
            "SELECT * FROM \"readers\" WHERE \"name\" <= 'fOo' COLLATE localized_case_insensitive")
    }
    
    func testEqual() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age == 10)),
            "SELECT * FROM \"readers\" WHERE \"age\" = 10")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age == 10 }),
            "SELECT * FROM \"readers\" WHERE \"age\" = 10")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age == (10 as Int?))),
            "SELECT * FROM \"readers\" WHERE \"age\" = 10")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age == (10 as Int?) }),
            "SELECT * FROM \"readers\" WHERE \"age\" = 10")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(10 == Columns.age)),
            "SELECT * FROM \"readers\" WHERE 10 = \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { 10 == $0.age }),
            "SELECT * FROM \"readers\" WHERE 10 = \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter((10 as Int?) == Columns.age)),
            "SELECT * FROM \"readers\" WHERE 10 = \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { (10 as Int?) == $0.age }),
            "SELECT * FROM \"readers\" WHERE 10 = \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filterWhenConnected { _ in 10 == 10 }),
            "SELECT * FROM \"readers\" WHERE 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age == Columns.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" = \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age == $0.age }),
            "SELECT * FROM \"readers\" WHERE \"age\" = \"age\"")

        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age == nil)),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age == nil }),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age == DatabaseValue.null)),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age == DatabaseValue.null }),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(nil == Columns.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { nil == $0.age }),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(DatabaseValue.null == Columns.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { DatabaseValue.null == $0.age }),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age == Columns.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" = \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age == $0.age }),
            "SELECT * FROM \"readers\" WHERE \"age\" = \"age\"")

        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.name == "B")),
            "SELECT * FROM \"readers\" WHERE \"name\" = 'B'")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.name == "B" }),
            "SELECT * FROM \"readers\" WHERE \"name\" = 'B'")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter("B" == Columns.name)),
            "SELECT * FROM \"readers\" WHERE 'B' = \"name\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { "B" == $0.name }),
            "SELECT * FROM \"readers\" WHERE 'B' = \"name\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filterWhenConnected { _ in "B" == "B" }),
            "SELECT * FROM \"readers\" WHERE 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.name == Columns.name)),
            "SELECT * FROM \"readers\" WHERE \"name\" = \"name\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.name == $0.name }),
            "SELECT * FROM \"readers\" WHERE \"name\" = \"name\"")

        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age == true)),
            "SELECT * FROM \"readers\" WHERE \"age\" = 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age == true }),
            "SELECT * FROM \"readers\" WHERE \"age\" = 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(true == Columns.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" = 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { true == $0.age }),
            "SELECT * FROM \"readers\" WHERE \"age\" = 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age == false)),
            "SELECT * FROM \"readers\" WHERE \"age\" = 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age == false }),
            "SELECT * FROM \"readers\" WHERE \"age\" = 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(false == Columns.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" = 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { false == $0.age }),
            "SELECT * FROM \"readers\" WHERE \"age\" = 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filterWhenConnected { _ in true == true }),
            "SELECT * FROM \"readers\" WHERE 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filterWhenConnected { _ in false == false }),
            "SELECT * FROM \"readers\" WHERE 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filterWhenConnected { _ in true == false }),
            "SELECT * FROM \"readers\" WHERE 0")
    }
    
    func testEqualWithCollation() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.name.collating(.nocase) == "fOo")),
            "SELECT * FROM \"readers\" WHERE \"name\" = 'fOo' COLLATE NOCASE")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.name.collating(.nocase) == "fOo" }),
            "SELECT * FROM \"readers\" WHERE \"name\" = 'fOo' COLLATE NOCASE")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.name.collating(.nocase) == ("fOo" as String?))),
            "SELECT * FROM \"readers\" WHERE \"name\" = 'fOo' COLLATE NOCASE")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.name.collating(.nocase) == ("fOo" as String?) }),
            "SELECT * FROM \"readers\" WHERE \"name\" = 'fOo' COLLATE NOCASE")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.name.collating(.nocase) == nil)),
            "SELECT * FROM \"readers\" WHERE \"name\" IS NULL COLLATE NOCASE")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.name.collating(.nocase) == nil }),
            "SELECT * FROM \"readers\" WHERE \"name\" IS NULL COLLATE NOCASE")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.name.collating(.nocase) == DatabaseValue.null)),
            "SELECT * FROM \"readers\" WHERE \"name\" IS NULL COLLATE NOCASE")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.name.collating(.nocase) == DatabaseValue.null }),
            "SELECT * FROM \"readers\" WHERE \"name\" IS NULL COLLATE NOCASE")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.name.collating(collation) == "fOo")),
            "SELECT * FROM \"readers\" WHERE \"name\" = 'fOo' COLLATE localized_case_insensitive")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.name.collating(collation) == "fOo" }),
            "SELECT * FROM \"readers\" WHERE \"name\" = 'fOo' COLLATE localized_case_insensitive")
    }
    
    func testSubqueryEqual() throws {
        let dbQueue = try makeDatabaseQueue()
        
        do {
            let subquery = tableRequest.select(max(Columns.age))
            XCTAssertEqual(
                sql(dbQueue, tableRequest.filter(Columns.age == subquery)),
                """
                SELECT * FROM "readers" WHERE "age" = (SELECT MAX("age") FROM "readers")
                """)
        }
        
        do {
            let subquery = tableRequest.select { max($0.age) }
            XCTAssertEqual(
                sql(dbQueue, tableRequest.filter { $0.age == subquery }),
                """
                SELECT * FROM "readers" WHERE "age" = (SELECT MAX("age") FROM "readers")
                """)
        }
        
        do {
            let subquery = SQLRequest<Int>(sql: "SELECT MAX(age + ?) FROM readers", arguments: [1])
            XCTAssertEqual(
                sql(dbQueue, tableRequest.filter((Columns.age + 2) == subquery)),
                """
                SELECT * FROM "readers" WHERE ("age" + 2) = (SELECT MAX(age + 1) FROM readers)
                """)
        }
        
        do {
            let subquery = SQLRequest<Int>(sql: "SELECT MAX(age + ?) FROM readers", arguments: [1])
            XCTAssertEqual(
                sql(dbQueue, tableRequest.filter { ($0.age + 2) == subquery }),
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
                t.belongsTo("parent")
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
            sql(dbQueue, tableRequest.filter(Columns.age != 10)),
            "SELECT * FROM \"readers\" WHERE \"age\" <> 10")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age != 10 }),
            "SELECT * FROM \"readers\" WHERE \"age\" <> 10")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age != (10 as Int?))),
            "SELECT * FROM \"readers\" WHERE \"age\" <> 10")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age != (10 as Int?) }),
            "SELECT * FROM \"readers\" WHERE \"age\" <> 10")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(10 != Columns.age)),
            "SELECT * FROM \"readers\" WHERE 10 <> \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { 10 != $0.age }),
            "SELECT * FROM \"readers\" WHERE 10 <> \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter((10 as Int?) != Columns.age)),
            "SELECT * FROM \"readers\" WHERE 10 <> \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { (10 as Int?) != $0.age }),
            "SELECT * FROM \"readers\" WHERE 10 <> \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filterWhenConnected { _ in 10 != 10 }),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age != Columns.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" <> \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age != $0.age }),
            "SELECT * FROM \"readers\" WHERE \"age\" <> \"age\"")

        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(Columns.age == 10))),
            "SELECT * FROM \"readers\" WHERE \"age\" <> 10")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { !($0.age == 10) }),
            "SELECT * FROM \"readers\" WHERE \"age\" <> 10")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(Columns.age == (10 as Int?)))),
            "SELECT * FROM \"readers\" WHERE \"age\" <> 10")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { !($0.age == (10 as Int?)) }),
            "SELECT * FROM \"readers\" WHERE \"age\" <> 10")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(10 == Columns.age))),
            "SELECT * FROM \"readers\" WHERE 10 <> \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { !(10 == $0.age) }),
            "SELECT * FROM \"readers\" WHERE 10 <> \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!((10 as Int?) == Columns.age))),
            "SELECT * FROM \"readers\" WHERE 10 <> \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { !((10 as Int?) == $0.age) }),
            "SELECT * FROM \"readers\" WHERE 10 <> \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filterWhenConnected { _ in !(10 == 10) }),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(Columns.age == Columns.age))),
            "SELECT * FROM \"readers\" WHERE \"age\" <> \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { !($0.age == $0.age) }),
            "SELECT * FROM \"readers\" WHERE \"age\" <> \"age\"")

        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age != nil)),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age != nil }),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age != DatabaseValue.null)),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age != DatabaseValue.null }),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(nil != Columns.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { nil != $0.age }),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(DatabaseValue.null != Columns.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { DatabaseValue.null != $0.age }),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age != Columns.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" <> \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age != $0.age }),
            "SELECT * FROM \"readers\" WHERE \"age\" <> \"age\"")

        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(Columns.age == nil))),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { !($0.age == nil) }),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(Columns.age == DatabaseValue.null))),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { !($0.age == DatabaseValue.null) }),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(nil == Columns.age))),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { !(nil == $0.age) }),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(DatabaseValue.null == Columns.age))),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { !(DatabaseValue.null == $0.age) }),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(Columns.age == Columns.age))),
            "SELECT * FROM \"readers\" WHERE \"age\" <> \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { !($0.age == $0.age) }),
            "SELECT * FROM \"readers\" WHERE \"age\" <> \"age\"")

        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.name != "B")),
            "SELECT * FROM \"readers\" WHERE \"name\" <> 'B'")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.name != "B" }),
            "SELECT * FROM \"readers\" WHERE \"name\" <> 'B'")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter("B" != Columns.name)),
            "SELECT * FROM \"readers\" WHERE 'B' <> \"name\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { "B" != $0.name }),
            "SELECT * FROM \"readers\" WHERE 'B' <> \"name\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filterWhenConnected { _ in "B" != "B" }),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.name != Columns.name)),
            "SELECT * FROM \"readers\" WHERE \"name\" <> \"name\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.name != $0.name }),
            "SELECT * FROM \"readers\" WHERE \"name\" <> \"name\"")

        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(Columns.name == "B"))),
            "SELECT * FROM \"readers\" WHERE \"name\" <> 'B'")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { !($0.name == "B") }),
            "SELECT * FROM \"readers\" WHERE \"name\" <> 'B'")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!("B" == Columns.name))),
            "SELECT * FROM \"readers\" WHERE 'B' <> \"name\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { !("B" == $0.name) }),
            "SELECT * FROM \"readers\" WHERE 'B' <> \"name\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filterWhenConnected { _ in !("B" == "B") }),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(Columns.name == Columns.name))),
            "SELECT * FROM \"readers\" WHERE \"name\" <> \"name\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { !($0.name == $0.name) }),
            "SELECT * FROM \"readers\" WHERE \"name\" <> \"name\"")

        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age != true)),
            "SELECT * FROM \"readers\" WHERE \"age\" <> 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age != true }),
            "SELECT * FROM \"readers\" WHERE \"age\" <> 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(true != Columns.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" <> 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { true != $0.age }),
            "SELECT * FROM \"readers\" WHERE \"age\" <> 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age != false)),
            "SELECT * FROM \"readers\" WHERE \"age\" <> 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age != false }),
            "SELECT * FROM \"readers\" WHERE \"age\" <> 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(false != Columns.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" <> 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { false != $0.age }),
            "SELECT * FROM \"readers\" WHERE \"age\" <> 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filterWhenConnected { _ in true != true }),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filterWhenConnected { _ in false != false }),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filterWhenConnected { _ in true != false }),
            "SELECT * FROM \"readers\" WHERE 1")
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(Columns.age == true))),
            "SELECT * FROM \"readers\" WHERE \"age\" <> 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { !($0.age == true) }),
            "SELECT * FROM \"readers\" WHERE \"age\" <> 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(true == Columns.age))),
            "SELECT * FROM \"readers\" WHERE \"age\" <> 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { !(true == $0.age) }),
            "SELECT * FROM \"readers\" WHERE \"age\" <> 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(Columns.age == false))),
            "SELECT * FROM \"readers\" WHERE \"age\" <> 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { !($0.age == false) }),
            "SELECT * FROM \"readers\" WHERE \"age\" <> 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(false == Columns.age))),
            "SELECT * FROM \"readers\" WHERE \"age\" <> 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { !(false == $0.age) }),
            "SELECT * FROM \"readers\" WHERE \"age\" <> 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filterWhenConnected { _ in !(true == true) }),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filterWhenConnected { _ in !(false == false) }),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filterWhenConnected { _ in !(true == false) }),
            "SELECT * FROM \"readers\" WHERE 1")
    }
    
    func testNotEqualWithCollation() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.name.collating(.nocase) != "fOo")),
            "SELECT * FROM \"readers\" WHERE \"name\" <> 'fOo' COLLATE NOCASE")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.name.collating(.nocase) != "fOo" }),
            "SELECT * FROM \"readers\" WHERE \"name\" <> 'fOo' COLLATE NOCASE")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.name.collating(.nocase) != ("fOo" as String?))),
            "SELECT * FROM \"readers\" WHERE \"name\" <> 'fOo' COLLATE NOCASE")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.name.collating(.nocase) != ("fOo" as String?) }),
            "SELECT * FROM \"readers\" WHERE \"name\" <> 'fOo' COLLATE NOCASE")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.name.collating(.nocase) != nil)),
            "SELECT * FROM \"readers\" WHERE \"name\" IS NOT NULL COLLATE NOCASE")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.name.collating(.nocase) != nil }),
            "SELECT * FROM \"readers\" WHERE \"name\" IS NOT NULL COLLATE NOCASE")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.name.collating(.nocase) != DatabaseValue.null)),
            "SELECT * FROM \"readers\" WHERE \"name\" IS NOT NULL COLLATE NOCASE")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.name.collating(.nocase) != DatabaseValue.null }),
            "SELECT * FROM \"readers\" WHERE \"name\" IS NOT NULL COLLATE NOCASE")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.name.collating(collation) != "fOo")),
            "SELECT * FROM \"readers\" WHERE \"name\" <> 'fOo' COLLATE localized_case_insensitive")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.name.collating(collation) != "fOo" }),
            "SELECT * FROM \"readers\" WHERE \"name\" <> 'fOo' COLLATE localized_case_insensitive")
    }
    
    func testNotEqualWithSwiftNotOperator() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(Columns.age == 10))),
            "SELECT * FROM \"readers\" WHERE \"age\" <> 10")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { !($0.age == 10) }),
            "SELECT * FROM \"readers\" WHERE \"age\" <> 10")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(10 == Columns.age))),
            "SELECT * FROM \"readers\" WHERE 10 <> \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { !(10 == $0.age) }),
            "SELECT * FROM \"readers\" WHERE 10 <> \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filterWhenConnected { _ in !(10 == 10) }),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(Columns.age == Columns.age))),
            "SELECT * FROM \"readers\" WHERE \"age\" <> \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { !($0.age == $0.age) }),
            "SELECT * FROM \"readers\" WHERE \"age\" <> \"age\"")

        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(Columns.age == nil))),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { !($0.age == nil) }),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(Columns.age == DatabaseValue.null))),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { !($0.age == DatabaseValue.null) }),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(nil == Columns.age))),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { !(nil == $0.age) }),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(DatabaseValue.null == Columns.age))),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { !(DatabaseValue.null == $0.age) }),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(Columns.age == Columns.age))),
            "SELECT * FROM \"readers\" WHERE \"age\" <> \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { !($0.age == $0.age) }),
            "SELECT * FROM \"readers\" WHERE \"age\" <> \"age\"")
    }
    
    func testIs() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age === 10)),
            "SELECT * FROM \"readers\" WHERE \"age\" IS 10")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age === 10 }),
            "SELECT * FROM \"readers\" WHERE \"age\" IS 10")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(10 === Columns.age)),
            "SELECT * FROM \"readers\" WHERE 10 IS \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { 10 === $0.age }),
            "SELECT * FROM \"readers\" WHERE 10 IS \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age === Columns.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" IS \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age === $0.age }),
            "SELECT * FROM \"readers\" WHERE \"age\" IS \"age\"")

        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age === nil)),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age === nil }),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(nil === Columns.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { nil === $0.age }),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age === Columns.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" IS \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age === $0.age }),
            "SELECT * FROM \"readers\" WHERE \"age\" IS \"age\"")

        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.name === "B")),
            "SELECT * FROM \"readers\" WHERE \"name\" IS 'B'")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.name === "B" }),
            "SELECT * FROM \"readers\" WHERE \"name\" IS 'B'")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter("B" === Columns.name)),
            "SELECT * FROM \"readers\" WHERE 'B' IS \"name\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { "B" === $0.name }),
            "SELECT * FROM \"readers\" WHERE 'B' IS \"name\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.name === Columns.name)),
            "SELECT * FROM \"readers\" WHERE \"name\" IS \"name\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.name === $0.name }),
            "SELECT * FROM \"readers\" WHERE \"name\" IS \"name\"")
    }
    
    func testIsWithCollation() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.name.collating(.nocase) === "fOo")),
            "SELECT * FROM \"readers\" WHERE \"name\" IS 'fOo' COLLATE NOCASE")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.name.collating(.nocase) === "fOo" }),
            "SELECT * FROM \"readers\" WHERE \"name\" IS 'fOo' COLLATE NOCASE")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.name.collating(collation) === "fOo")),
            "SELECT * FROM \"readers\" WHERE \"name\" IS 'fOo' COLLATE localized_case_insensitive")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.name.collating(collation) === "fOo" }),
            "SELECT * FROM \"readers\" WHERE \"name\" IS 'fOo' COLLATE localized_case_insensitive")
    }
    
    func testIsNot() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age !== 10)),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT 10")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age !== 10 }),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT 10")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(10 !== Columns.age)),
            "SELECT * FROM \"readers\" WHERE 10 IS NOT \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { 10 !== $0.age }),
            "SELECT * FROM \"readers\" WHERE 10 IS NOT \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age !== Columns.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age !== $0.age }),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT \"age\"")

        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age !== nil)),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age !== nil }),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(nil !== Columns.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { nil !== $0.age }),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age !== Columns.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age !== $0.age }),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT \"age\"")

        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.name !== "B")),
            "SELECT * FROM \"readers\" WHERE \"name\" IS NOT 'B'")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.name !== "B" }),
            "SELECT * FROM \"readers\" WHERE \"name\" IS NOT 'B'")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter("B" !== Columns.name)),
            "SELECT * FROM \"readers\" WHERE 'B' IS NOT \"name\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { "B" !== $0.name }),
            "SELECT * FROM \"readers\" WHERE 'B' IS NOT \"name\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.name !== Columns.name)),
            "SELECT * FROM \"readers\" WHERE \"name\" IS NOT \"name\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.name !== $0.name }),
            "SELECT * FROM \"readers\" WHERE \"name\" IS NOT \"name\"")
    }
    
    func testIsNotWithCollation() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.name.collating(.nocase) !== "fOo")),
            "SELECT * FROM \"readers\" WHERE \"name\" IS NOT 'fOo' COLLATE NOCASE")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.name.collating(.nocase) !== "fOo" }),
            "SELECT * FROM \"readers\" WHERE \"name\" IS NOT 'fOo' COLLATE NOCASE")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.name.collating(collation) !== "fOo")),
            "SELECT * FROM \"readers\" WHERE \"name\" IS NOT 'fOo' COLLATE localized_case_insensitive")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.name.collating(collation) !== "fOo" }),
            "SELECT * FROM \"readers\" WHERE \"name\" IS NOT 'fOo' COLLATE localized_case_insensitive")
    }
    
    func testIsNotWithSwiftNotOperator() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(Columns.age === 10))),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT 10")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { !($0.age === 10) }),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT 10")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(10 === Columns.age))),
            "SELECT * FROM \"readers\" WHERE 10 IS NOT \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { !(10 === $0.age) }),
            "SELECT * FROM \"readers\" WHERE 10 IS NOT \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(Columns.age === Columns.age))),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { !($0.age === $0.age) }),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT \"age\"")

        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(Columns.age === nil))),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { !($0.age === nil) }),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(nil === Columns.age))),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { !(nil === $0.age) }),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT NULL")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(Columns.age === Columns.age))),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { !($0.age === $0.age) }),
            "SELECT * FROM \"readers\" WHERE \"age\" IS NOT \"age\"")
    }
    
    func testLogicalOperators() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!Columns.age)),
            "SELECT * FROM \"readers\" WHERE NOT \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { !$0.age }),
            "SELECT * FROM \"readers\" WHERE NOT \"age\"")
        // Make sure NOT NOT "hack" is available in order to produce 0 or 1
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(!Columns.age))),
            "SELECT * FROM \"readers\" WHERE NOT (NOT \"age\")")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { !(!$0.age) }),
            "SELECT * FROM \"readers\" WHERE NOT (NOT \"age\")")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age && true)),
            "SELECT * FROM \"readers\" WHERE \"age\" AND 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age && true }),
            "SELECT * FROM \"readers\" WHERE \"age\" AND 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(true && Columns.age)),
            "SELECT * FROM \"readers\" WHERE 1 AND \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { true && $0.age }),
            "SELECT * FROM \"readers\" WHERE 1 AND \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age || false)),
            "SELECT * FROM \"readers\" WHERE \"age\" OR 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age || false }),
            "SELECT * FROM \"readers\" WHERE \"age\" OR 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(false || Columns.age)),
            "SELECT * FROM \"readers\" WHERE 0 OR \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { false || $0.age }),
            "SELECT * FROM \"readers\" WHERE 0 OR \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age != nil || Columns.name == nil)),
            "SELECT * FROM \"readers\" WHERE (\"age\" IS NOT NULL) OR (\"name\" IS NULL)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age != nil || $0.name == nil }),
            "SELECT * FROM \"readers\" WHERE (\"age\" IS NOT NULL) OR (\"name\" IS NULL)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age != nil || Columns.name != nil && Columns.id != nil)),
            "SELECT * FROM \"readers\" WHERE (\"age\" IS NOT NULL) OR ((\"name\" IS NOT NULL) AND (\"id\" IS NOT NULL))")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age != nil || $0.name != nil && $0.id != nil }),
            "SELECT * FROM \"readers\" WHERE (\"age\" IS NOT NULL) OR ((\"name\" IS NOT NULL) AND (\"id\" IS NOT NULL))")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter((Columns.age != nil || Columns.name != nil) && Columns.id != nil)),
            "SELECT * FROM \"readers\" WHERE ((\"age\" IS NOT NULL) OR (\"name\" IS NOT NULL)) AND (\"id\" IS NOT NULL)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { ($0.age != nil || $0.name != nil) && $0.id != nil }),
            "SELECT * FROM \"readers\" WHERE ((\"age\" IS NOT NULL) OR (\"name\" IS NOT NULL)) AND (\"id\" IS NOT NULL)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!(Columns.age > 18) && !(Columns.name > "foo"))),
            "SELECT * FROM \"readers\" WHERE (NOT (\"age\" > 18)) AND (NOT (\"name\" > 'foo'))")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { !($0.age > 18) && !($0.name > "foo") }),
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
            sql(dbQueue, tableRequest.filter([Columns.id == 1].joined(operator: .and))),
            "SELECT * FROM \"readers\" WHERE \"id\" = 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { [$0.id == 1].joined(operator: .and) }),
            "SELECT * FROM \"readers\" WHERE \"id\" = 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter([Columns.id == 1].joined(operator: .and) || false)),
            "SELECT * FROM \"readers\" WHERE (\"id\" = 1) OR 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { [$0.id == 1].joined(operator: .and) || false }),
            "SELECT * FROM \"readers\" WHERE (\"id\" = 1) OR 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter([Columns.id == 1, Columns.name != nil].joined(operator: .and))),
            "SELECT * FROM \"readers\" WHERE (\"id\" = 1) AND (\"name\" IS NOT NULL)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { [$0.id == 1, $0.name != nil].joined(operator: .and) }),
            "SELECT * FROM \"readers\" WHERE (\"id\" = 1) AND (\"name\" IS NOT NULL)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter([Columns.id == 1, Columns.name != nil].joined(operator: .and) || false)),
            "SELECT * FROM \"readers\" WHERE ((\"id\" = 1) AND (\"name\" IS NOT NULL)) OR 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { [$0.id == 1, $0.name != nil].joined(operator: .and) || false }),
            "SELECT * FROM \"readers\" WHERE ((\"id\" = 1) AND (\"name\" IS NOT NULL)) OR 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter([Columns.id == 1, Columns.name != nil, Columns.age == nil].joined(operator: .and))),
            "SELECT * FROM \"readers\" WHERE (\"id\" = 1) AND (\"name\" IS NOT NULL) AND (\"age\" IS NULL)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { (columns: Reader.DatabaseComponents) in [columns.id == 1, columns.name != nil, columns.age == nil].joined(operator: .and) }),
            "SELECT * FROM \"readers\" WHERE (\"id\" = 1) AND (\"name\" IS NOT NULL) AND (\"age\" IS NULL)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter([Columns.id == 1, Columns.name != nil, Columns.age == nil].joined(operator: .and) || false)),
            "SELECT * FROM \"readers\" WHERE ((\"id\" = 1) AND (\"name\" IS NOT NULL) AND (\"age\" IS NULL)) OR 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { (columns: Reader.DatabaseComponents) in [columns.id == 1, columns.name != nil, columns.age == nil].joined(operator: .and) || false }),
            "SELECT * FROM \"readers\" WHERE ((\"id\" = 1) AND (\"name\" IS NOT NULL) AND (\"age\" IS NULL)) OR 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(![Columns.id == 1, Columns.name != nil, Columns.age == nil].joined(operator: .and))),
            "SELECT * FROM \"readers\" WHERE NOT ((\"id\" = 1) AND (\"name\" IS NOT NULL) AND (\"age\" IS NULL))")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { (columns: Reader.DatabaseComponents) in ![columns.id == 1, columns.name != nil, columns.age == nil].joined(operator: .and) }),
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
            sql(dbQueue, tableRequest.filter([Columns.id == 1].joined(operator: .or))),
            "SELECT * FROM \"readers\" WHERE \"id\" = 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { [$0.id == 1].joined(operator: .or) }),
            "SELECT * FROM \"readers\" WHERE \"id\" = 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter([Columns.id == 1].joined(operator: .or) && true)),
            "SELECT * FROM \"readers\" WHERE (\"id\" = 1) AND 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { [$0.id == 1].joined(operator: .or) && true }),
            "SELECT * FROM \"readers\" WHERE (\"id\" = 1) AND 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter([Columns.id == 1, Columns.name != nil].joined(operator: .or))),
            "SELECT * FROM \"readers\" WHERE (\"id\" = 1) OR (\"name\" IS NOT NULL)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { [$0.id == 1, $0.name != nil].joined(operator: .or) }),
            "SELECT * FROM \"readers\" WHERE (\"id\" = 1) OR (\"name\" IS NOT NULL)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter([Columns.id == 1, Columns.name != nil].joined(operator: .or) && true)),
            "SELECT * FROM \"readers\" WHERE ((\"id\" = 1) OR (\"name\" IS NOT NULL)) AND 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { [$0.id == 1, $0.name != nil].joined(operator: .or) && true }),
            "SELECT * FROM \"readers\" WHERE ((\"id\" = 1) OR (\"name\" IS NOT NULL)) AND 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter([Columns.id == 1, Columns.name != nil, Columns.age == nil].joined(operator: .or))),
            "SELECT * FROM \"readers\" WHERE (\"id\" = 1) OR (\"name\" IS NOT NULL) OR (\"age\" IS NULL)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { (columns: Reader.DatabaseComponents) in [columns.id == 1, columns.name != nil, columns.age == nil].joined(operator: .or) }),
            "SELECT * FROM \"readers\" WHERE (\"id\" = 1) OR (\"name\" IS NOT NULL) OR (\"age\" IS NULL)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter([Columns.id == 1, Columns.name != nil, Columns.age == nil].joined(operator: .or) && true)),
            "SELECT * FROM \"readers\" WHERE ((\"id\" = 1) OR (\"name\" IS NOT NULL) OR (\"age\" IS NULL)) AND 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { (columns: Reader.DatabaseComponents) in [columns.id == 1, columns.name != nil, columns.age == nil].joined(operator: .or) && true }),
            "SELECT * FROM \"readers\" WHERE ((\"id\" = 1) OR (\"name\" IS NOT NULL) OR (\"age\" IS NULL)) AND 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(![Columns.id == 1, Columns.name != nil, Columns.age == nil].joined(operator: .or))),
            "SELECT * FROM \"readers\" WHERE NOT ((\"id\" = 1) OR (\"name\" IS NOT NULL) OR (\"age\" IS NULL))")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { (columns: Reader.DatabaseComponents) in ![columns.id == 1, columns.name != nil, columns.age == nil].joined(operator: .or) }),
            "SELECT * FROM \"readers\" WHERE NOT ((\"id\" = 1) OR (\"name\" IS NOT NULL) OR (\"age\" IS NULL))")
    }

    
    // MARK: - String functions
    
    func testStringFunctions() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(Columns.name.capitalized)),
            "SELECT swiftCapitalizedString(\"name\") FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { $0.name.capitalized }),
            "SELECT swiftCapitalizedString(\"name\") FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(Columns.name.lowercased)),
            "SELECT swiftLowercaseString(\"name\") FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { $0.name.lowercased }),
            "SELECT swiftLowercaseString(\"name\") FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(Columns.name.uppercased)),
            "SELECT swiftUppercaseString(\"name\") FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { $0.name.uppercased }),
            "SELECT swiftUppercaseString(\"name\") FROM \"readers\"")

        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(Columns.name.localizedCapitalized)),
            "SELECT swiftLocalizedCapitalizedString(\"name\") FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { $0.name.localizedCapitalized }),
            "SELECT swiftLocalizedCapitalizedString(\"name\") FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(Columns.name.localizedLowercased)),
            "SELECT swiftLocalizedLowercaseString(\"name\") FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { $0.name.localizedLowercased }),
            "SELECT swiftLocalizedLowercaseString(\"name\") FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(Columns.name.localizedUppercased)),
            "SELECT swiftLocalizedUppercaseString(\"name\") FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { $0.name.localizedUppercased }),
            "SELECT swiftLocalizedUppercaseString(\"name\") FROM \"readers\"")
    }
    
    
    // MARK: - Arithmetic expressions
    
    func testPrefixMinusOperator() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(-Columns.age)),
            "SELECT * FROM \"readers\" WHERE -\"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { -$0.age }),
            "SELECT * FROM \"readers\" WHERE -\"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(-(Columns.age + 1))),
            "SELECT * FROM \"readers\" WHERE -(\"age\" + 1)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { -($0.age + 1) }),
            "SELECT * FROM \"readers\" WHERE -(\"age\" + 1)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(-(-Columns.age + 1))),
            "SELECT * FROM \"readers\" WHERE -((-\"age\") + 1)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { -(-$0.age + 1) }),
            "SELECT * FROM \"readers\" WHERE -((-\"age\") + 1)")
    }
    
    func testInfixSubtractOperator() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age - 2)),
            "SELECT * FROM \"readers\" WHERE \"age\" - 2")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age - 2 }),
            "SELECT * FROM \"readers\" WHERE \"age\" - 2")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(2 - Columns.age)),
            "SELECT * FROM \"readers\" WHERE 2 - \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { 2 - $0.age }),
            "SELECT * FROM \"readers\" WHERE 2 - \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filterWhenConnected { _ in 2 - 2 }),
            "SELECT * FROM \"readers\" WHERE 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age - Columns.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" - \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age - $0.age }),
            "SELECT * FROM \"readers\" WHERE \"age\" - \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter((Columns.age - Columns.age) - 1)),
            "SELECT * FROM \"readers\" WHERE (\"age\" - \"age\") - 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { ($0.age - $0.age) - 1 }),
            "SELECT * FROM \"readers\" WHERE (\"age\" - \"age\") - 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(1 - [Columns.age > 1, Columns.age == nil].joined(operator: .and))),
            "SELECT * FROM \"readers\" WHERE 1 - ((\"age\" > 1) AND (\"age\" IS NULL))")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { 1 - [$0.age > 1, $0.age == nil].joined(operator: .and) }),
            "SELECT * FROM \"readers\" WHERE 1 - ((\"age\" > 1) AND (\"age\" IS NULL))")
    }
    
    func testInfixAddOperator() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age + 2)),
            "SELECT * FROM \"readers\" WHERE \"age\" + 2")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age + 2 }),
            "SELECT * FROM \"readers\" WHERE \"age\" + 2")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(2 + Columns.age)),
            "SELECT * FROM \"readers\" WHERE 2 + \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { 2 + $0.age }),
            "SELECT * FROM \"readers\" WHERE 2 + \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filterWhenConnected { _ in 2 + 2 }),
            "SELECT * FROM \"readers\" WHERE 4")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age + Columns.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" + \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age + $0.age }),
            "SELECT * FROM \"readers\" WHERE \"age\" + \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(1 + (Columns.age + Columns.age))),
            "SELECT * FROM \"readers\" WHERE 1 + (\"age\" + \"age\")")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { 1 + ($0.age + $0.age) }),
            "SELECT * FROM \"readers\" WHERE 1 + (\"age\" + \"age\")")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(1 + [Columns.age > 1, Columns.age == nil].joined(operator: .and))),
            "SELECT * FROM \"readers\" WHERE 1 + ((\"age\" > 1) AND (\"age\" IS NULL))")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { 1 + [$0.age > 1, $0.age == nil].joined(operator: .and) }),
            "SELECT * FROM \"readers\" WHERE 1 + ((\"age\" > 1) AND (\"age\" IS NULL))")
    }
    
    func testJoinedAddOperator() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select([].joined(operator: .add))),
            "SELECT 0 FROM \"readers\"")

        XCTAssertEqual(
            sql(dbQueue, tableRequest.select([Columns.age, Columns.age].joined(operator: .add))),
            "SELECT \"age\" + \"age\" FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { [$0.age, $0.age].joined(operator: .add) }),
            "SELECT \"age\" + \"age\" FROM \"readers\"")

        XCTAssertEqual(
            sql(dbQueue, tableRequest.select([Columns.age, 2.databaseValue, Columns.age].joined(operator: .add))),
            "SELECT \"age\" + 2 + \"age\" FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { [$0.age, 2.databaseValue, $0.age].joined(operator: .add) }),
            "SELECT \"age\" + 2 + \"age\" FROM \"readers\"")

        // Not flattened
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select([
                [Columns.age, 1.databaseValue].joined(operator: .add),
                [2.databaseValue, Columns.age].joined(operator: .add),
                ].joined(operator: .add))),
            "SELECT (\"age\" + 1) + (2 + \"age\") FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { [
                [$0.age, 1.databaseValue].joined(operator: .add),
                [2.databaseValue, $0.age].joined(operator: .add),
            ].joined(operator: .add)
            }),
            "SELECT (\"age\" + 1) + (2 + \"age\") FROM \"readers\"")
    }
    
    func testInfixMultiplyOperator() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age * 2)),
            "SELECT * FROM \"readers\" WHERE \"age\" * 2")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age * 2 }),
            "SELECT * FROM \"readers\" WHERE \"age\" * 2")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(2 * Columns.age)),
            "SELECT * FROM \"readers\" WHERE 2 * \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { 2 * $0.age }),
            "SELECT * FROM \"readers\" WHERE 2 * \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filterWhenConnected { _ in 2 * 2 }),
            "SELECT * FROM \"readers\" WHERE 4")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age * Columns.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" * \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age * $0.age }),
            "SELECT * FROM \"readers\" WHERE \"age\" * \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(2 * (Columns.age * Columns.age))),
            "SELECT * FROM \"readers\" WHERE 2 * (\"age\" * \"age\")")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { 2 * ($0.age * $0.age) }),
            "SELECT * FROM \"readers\" WHERE 2 * (\"age\" * \"age\")")
    }
    
    func testJoinedMultiplyOperator() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select([].joined(operator: .multiply))),
            "SELECT 1 FROM \"readers\"")

        XCTAssertEqual(
            sql(dbQueue, tableRequest.select([Columns.age, Columns.age].joined(operator: .multiply))),
            "SELECT \"age\" * \"age\" FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { [$0.age, $0.age].joined(operator: .multiply) }),
            "SELECT \"age\" * \"age\" FROM \"readers\"")

        XCTAssertEqual(
            sql(dbQueue, tableRequest.select([Columns.age, 2.databaseValue, Columns.age].joined(operator: .multiply))),
            "SELECT \"age\" * 2 * \"age\" FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { [$0.age, 2.databaseValue, $0.age].joined(operator: .multiply) }),
            "SELECT \"age\" * 2 * \"age\" FROM \"readers\"")

        // Not flattened
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select([
                [Columns.age, 1.databaseValue].joined(operator: .multiply),
                [2.databaseValue, Columns.age].joined(operator: .multiply),
                ].joined(operator: .multiply))),
            "SELECT (\"age\" * 1) * (2 * \"age\") FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { [
                [$0.age, 1.databaseValue].joined(operator: .multiply),
                [2.databaseValue, $0.age].joined(operator: .multiply),
            ].joined(operator: .multiply)
            }),
            "SELECT (\"age\" * 1) * (2 * \"age\") FROM \"readers\"")
    }
    
    func testInfixDivideOperator() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age / 2)),
            "SELECT * FROM \"readers\" WHERE \"age\" / 2")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age / 2 }),
            "SELECT * FROM \"readers\" WHERE \"age\" / 2")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(2 / Columns.age)),
            "SELECT * FROM \"readers\" WHERE 2 / \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { 2 / $0.age }),
            "SELECT * FROM \"readers\" WHERE 2 / \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filterWhenConnected { _ in 2 / 2 }),
            "SELECT * FROM \"readers\" WHERE 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age / Columns.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" / \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age / $0.age }),
            "SELECT * FROM \"readers\" WHERE \"age\" / \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(1 / (Columns.age / Columns.age))),
            "SELECT * FROM \"readers\" WHERE 1 / (\"age\" / \"age\")")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { 1 / ($0.age / $0.age) }),
            "SELECT * FROM \"readers\" WHERE 1 / (\"age\" / \"age\")")
    }
    
    func testCompoundArithmeticExpression() throws {
        let dbQueue = try makeDatabaseQueue()
        
        // Int / Double
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age / 2.0)),
            "SELECT * FROM \"readers\" WHERE \"age\" / 2.0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age / 2.0 }),
            "SELECT * FROM \"readers\" WHERE \"age\" / 2.0")
        // Double / Int
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(2.0 / Columns.age)),
            "SELECT * FROM \"readers\" WHERE 2.0 / \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { 2.0 / $0.age }),
            "SELECT * FROM \"readers\" WHERE 2.0 / \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age + 2 * 5)),
            "SELECT * FROM \"readers\" WHERE \"age\" + 10")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age + 2 * 5 }),
            "SELECT * FROM \"readers\" WHERE \"age\" + 10")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age * 2 + 5)),
            "SELECT * FROM \"readers\" WHERE (\"age\" * 2) + 5")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age * 2 + 5 }),
            "SELECT * FROM \"readers\" WHERE (\"age\" * 2) + 5")
    }
    
    
    // MARK: - Bitwise expressions
    
    func testPrefixBitwiseNotOperator() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(~Columns.age)),
            "SELECT * FROM \"readers\" WHERE ~\"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { ~$0.age }),
            "SELECT * FROM \"readers\" WHERE ~\"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(~(Columns.age + 1))),
            "SELECT * FROM \"readers\" WHERE ~(\"age\" + 1)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { ~($0.age + 1) }),
            "SELECT * FROM \"readers\" WHERE ~(\"age\" + 1)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(~(~Columns.age + 1))),
            "SELECT * FROM \"readers\" WHERE ~((~\"age\") + 1)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { ~(~$0.age + 1) }),
            "SELECT * FROM \"readers\" WHERE ~((~\"age\") + 1)")
    }
    
    func testInfixLeftShiftOperator() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age << 2)),
            "SELECT * FROM \"readers\" WHERE \"age\" << 2")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age << 2 }),
            "SELECT * FROM \"readers\" WHERE \"age\" << 2")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(2 << Columns.age)),
            "SELECT * FROM \"readers\" WHERE 2 << \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { 2 << $0.age }),
            "SELECT * FROM \"readers\" WHERE 2 << \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filterWhenConnected { _ in 2 << 2 }),
            "SELECT * FROM \"readers\" WHERE 8")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age << Columns.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" << \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age << $0.age }),
            "SELECT * FROM \"readers\" WHERE \"age\" << \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter((Columns.age << Columns.age) << 1)),
            "SELECT * FROM \"readers\" WHERE (\"age\" << \"age\") << 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { ($0.age << $0.age) << 1 }),
            "SELECT * FROM \"readers\" WHERE (\"age\" << \"age\") << 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(1 << [Columns.age > 1, Columns.age == nil].joined(operator: .and))),
            "SELECT * FROM \"readers\" WHERE 1 << ((\"age\" > 1) AND (\"age\" IS NULL))")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { 1 << [$0.age > 1, $0.age == nil].joined(operator: .and) }),
            "SELECT * FROM \"readers\" WHERE 1 << ((\"age\" > 1) AND (\"age\" IS NULL))")
    }
    
    func testInfixRightShiftOperator() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age >> 2)),
            "SELECT * FROM \"readers\" WHERE \"age\" >> 2")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age >> 2 }),
            "SELECT * FROM \"readers\" WHERE \"age\" >> 2")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(2 >> Columns.age)),
            "SELECT * FROM \"readers\" WHERE 2 >> \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { 2 >> $0.age }),
            "SELECT * FROM \"readers\" WHERE 2 >> \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filterWhenConnected { _ in 8 >> 2 }),
            "SELECT * FROM \"readers\" WHERE 2")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age >> Columns.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" >> \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age >> $0.age }),
            "SELECT * FROM \"readers\" WHERE \"age\" >> \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter((Columns.age >> Columns.age) >> 1)),
            "SELECT * FROM \"readers\" WHERE (\"age\" >> \"age\") >> 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { ($0.age >> $0.age) >> 1 }),
            "SELECT * FROM \"readers\" WHERE (\"age\" >> \"age\") >> 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(1 >> [Columns.age > 1, Columns.age == nil].joined(operator: .and))),
            "SELECT * FROM \"readers\" WHERE 1 >> ((\"age\" > 1) AND (\"age\" IS NULL))")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { 1 >> [$0.age > 1, $0.age == nil].joined(operator: .and) }),
            "SELECT * FROM \"readers\" WHERE 1 >> ((\"age\" > 1) AND (\"age\" IS NULL))")
    }
    
    func testInfixBitwiseAndOperator() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age & 2)),
            "SELECT * FROM \"readers\" WHERE \"age\" & 2")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age & 2 }),
            "SELECT * FROM \"readers\" WHERE \"age\" & 2")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(2 & Columns.age)),
            "SELECT * FROM \"readers\" WHERE 2 & \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { 2 & $0.age }),
            "SELECT * FROM \"readers\" WHERE 2 & \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filterWhenConnected { _ in 2 & 2 }),
            "SELECT * FROM \"readers\" WHERE 2")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age & Columns.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" & \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age & $0.age }),
            "SELECT * FROM \"readers\" WHERE \"age\" & \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(2 & (Columns.age & Columns.age))),
            "SELECT * FROM \"readers\" WHERE 2 & \"age\" & \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { 2 & ($0.age & $0.age) }),
            "SELECT * FROM \"readers\" WHERE 2 & \"age\" & \"age\"")
    }
    
    func testJoinedBitwiseAndOperator() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select([].joined(operator: .bitwiseAnd))),
            "SELECT -1 FROM \"readers\"")

        XCTAssertEqual(
            sql(dbQueue, tableRequest.select([Columns.age, Columns.age].joined(operator: .bitwiseAnd))),
            "SELECT \"age\" & \"age\" FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { [$0.age, $0.age].joined(operator: .bitwiseAnd) }),
            "SELECT \"age\" & \"age\" FROM \"readers\"")

        XCTAssertEqual(
            sql(dbQueue, tableRequest.select([Columns.age, 2.databaseValue, Columns.age].joined(operator: .bitwiseAnd))),
            "SELECT \"age\" & 2 & \"age\" FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { [$0.age, 2.databaseValue, $0.age].joined(operator: .bitwiseAnd) }),
            "SELECT \"age\" & 2 & \"age\" FROM \"readers\"")

        // Flattened
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select([
                [Columns.age, 1.databaseValue].joined(operator: .bitwiseAnd),
                [2.databaseValue, Columns.age].joined(operator: .bitwiseAnd),
                ].joined(operator: .bitwiseAnd))),
            "SELECT \"age\" & 1 & 2 & \"age\" FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { [
                [$0.age, 1.databaseValue].joined(operator: .bitwiseAnd),
                [2.databaseValue, $0.age].joined(operator: .bitwiseAnd),
            ].joined(operator: .bitwiseAnd)
            }),
            "SELECT \"age\" & 1 & 2 & \"age\" FROM \"readers\"")
    }
    
    func testInfixBitwiseOrOperator() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age | 2)),
            "SELECT * FROM \"readers\" WHERE \"age\" | 2")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age | 2 }),
            "SELECT * FROM \"readers\" WHERE \"age\" | 2")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(2 | Columns.age)),
            "SELECT * FROM \"readers\" WHERE 2 | \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { 2 | $0.age }),
            "SELECT * FROM \"readers\" WHERE 2 | \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filterWhenConnected { _ in 2 | 2 }),
            "SELECT * FROM \"readers\" WHERE 2")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age | Columns.age)),
            "SELECT * FROM \"readers\" WHERE \"age\" | \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age | $0.age }),
            "SELECT * FROM \"readers\" WHERE \"age\" | \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(2 | (Columns.age | Columns.age))),
            "SELECT * FROM \"readers\" WHERE 2 | \"age\" | \"age\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { 2 | ($0.age | $0.age) }),
            "SELECT * FROM \"readers\" WHERE 2 | \"age\" | \"age\"")
    }
    
    func testJoinedBitwiseOrOperator() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select([].joined(operator: .bitwiseOr))),
            "SELECT 0 FROM \"readers\"")

        XCTAssertEqual(
            sql(dbQueue, tableRequest.select([Columns.age, Columns.age].joined(operator: .bitwiseOr))),
            "SELECT \"age\" | \"age\" FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { [$0.age, $0.age].joined(operator: .bitwiseOr) }),
            "SELECT \"age\" | \"age\" FROM \"readers\"")

        XCTAssertEqual(
            sql(dbQueue, tableRequest.select([Columns.age, 2.databaseValue, Columns.age].joined(operator: .bitwiseOr))),
            "SELECT \"age\" | 2 | \"age\" FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { [$0.age, 2.databaseValue, $0.age].joined(operator: .bitwiseOr) }),
            "SELECT \"age\" | 2 | \"age\" FROM \"readers\"")

        // Flattened
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select([
                [Columns.age, 1.databaseValue].joined(operator: .bitwiseOr),
                [2.databaseValue, Columns.age].joined(operator: .bitwiseOr),
                ].joined(operator: .bitwiseOr))),
            "SELECT \"age\" | 1 | 2 | \"age\" FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { [
                [$0.age, 1.databaseValue].joined(operator: .bitwiseOr),
                [2.databaseValue, $0.age].joined(operator: .bitwiseOr),
            ].joined(operator: .bitwiseOr)
            }),
            "SELECT \"age\" | 1 | 2 | \"age\" FROM \"readers\"")
    }

    // MARK: - IFNULL expression
    
    func testIfNull() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age ?? 2)),
            "SELECT * FROM \"readers\" WHERE IFNULL(\"age\", 2)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age ?? 2 }),
            "SELECT * FROM \"readers\" WHERE IFNULL(\"age\", 2)")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.age ?? Columns.age)),
            "SELECT * FROM \"readers\" WHERE IFNULL(\"age\", \"age\")")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.age ?? $0.age }),
            "SELECT * FROM \"readers\" WHERE IFNULL(\"age\", \"age\")")
    }
    
    
    // MARK: - Aggregated expressions
    
    func testCountExpression() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(count(Columns.age))),
            "SELECT COUNT(\"age\") FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { count($0.age) }),
            "SELECT COUNT(\"age\") FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(count(Columns.age ?? 0))),
            "SELECT COUNT(IFNULL(\"age\", 0)) FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { count($0.age ?? 0) }),
            "SELECT COUNT(IFNULL(\"age\", 0)) FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(count(distinct: Columns.age))),
            "SELECT COUNT(DISTINCT \"age\") FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { count(distinct: $0.age) }),
            "SELECT COUNT(DISTINCT \"age\") FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(count(distinct: Columns.age / Columns.age))),
            "SELECT COUNT(DISTINCT \"age\" / \"age\") FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { count(distinct: $0.age / $0.age) }),
            "SELECT COUNT(DISTINCT \"age\" / \"age\") FROM \"readers\"")
    }
    
    func testAvgExpression() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(average(Columns.age))),
            "SELECT AVG(\"age\") FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { average($0.age) }),
            "SELECT AVG(\"age\") FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(average(Columns.age / 2))),
            "SELECT AVG(\"age\" / 2) FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { average($0.age / 2) }),
            "SELECT AVG(\"age\" / 2) FROM \"readers\"")
    }
    
    func testAvgExpression_filter() throws {
        #if GRDBCUSTOMSQLITE || SQLITE_HAS_CODEC
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3030000 else {
            throw XCTSkip("FILTER clause on aggregate functions is not available")
        }
        #else
        guard #available(iOS 14, macOS 10.16, tvOS 14, *) else {
            throw XCTSkip("FILTER clause on aggregate functions is not available")
        }
        #endif
        
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(average(Columns.age, filter: Columns.age > 0))),
            "SELECT AVG(\"age\") FILTER (WHERE \"age\" > 0) FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { average($0.age, filter: $0.age > 0) }),
            "SELECT AVG(\"age\") FILTER (WHERE \"age\" > 0) FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(average(Columns.age / 2, filter: Columns.age > 0))),
            "SELECT AVG(\"age\" / 2) FILTER (WHERE \"age\" > 0) FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { average($0.age / 2, filter: $0.age > 0) }),
            "SELECT AVG(\"age\" / 2) FILTER (WHERE \"age\" > 0) FROM \"readers\"")
    }
    
    func testCastExpression() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(cast(Columns.name, as: .blob))),
            "SELECT CAST(\"name\" AS BLOB) FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { cast($0.name, as: .blob) }),
            "SELECT CAST(\"name\" AS BLOB) FROM \"readers\"")
    }
    
    func testCoalesceExpression() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(coalesce([]))),
            "SELECT NULL FROM \"readers\"")

        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(coalesce([Columns.name]))),
            "SELECT \"name\" FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { coalesce([$0.name]) }),
            "SELECT \"name\" FROM \"readers\"")

        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(coalesce([Columns.name, Columns.age]))),
            "SELECT COALESCE(\"name\", \"age\") FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { coalesce([$0.name, $0.age]) }),
            "SELECT COALESCE(\"name\", \"age\") FROM \"readers\"")
    }
    
    func testLengthExpression() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(length(Columns.name))),
            "SELECT LENGTH(\"name\") FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { length($0.name) }),
            "SELECT LENGTH(\"name\") FROM \"readers\"")
    }
    
    func testMultiArgumentMinExpression() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(min(Columns.age, 1000))),
            "SELECT MIN(\"age\", 1000) FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { min($0.age, 1000) }),
            "SELECT MIN(\"age\", 1000) FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(min(Columns.age, 1000, Columns.id))),
            "SELECT MIN(\"age\", 1000, \"id\") FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { min($0.age, 1000, $0.id) }),
            "SELECT MIN(\"age\", 1000, \"id\") FROM \"readers\"")
    }
    
    func testAggregateMinExpression() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(min(Columns.age))),
            "SELECT MIN(\"age\") FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { min($0.age) }),
            "SELECT MIN(\"age\") FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(min(Columns.age / 2))),
            "SELECT MIN(\"age\" / 2) FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { min($0.age / 2) }),
            "SELECT MIN(\"age\" / 2) FROM \"readers\"")
    }
    
    func testAggregateMinExpression_filter() throws {
        #if GRDBCUSTOMSQLITE || SQLITE_HAS_CODEC
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3030000 else {
            throw XCTSkip("FILTER clause on aggregate functions is not available")
        }
        #else
        guard #available(iOS 14, macOS 10.16, tvOS 14, *) else {
            throw XCTSkip("FILTER clause on aggregate functions is not available")
        }
        #endif
        
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(min(Columns.age, filter: Columns.age > 0))),
            "SELECT MIN(\"age\") FILTER (WHERE \"age\" > 0) FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { min($0.age, filter: $0.age > 0) }),
            "SELECT MIN(\"age\") FILTER (WHERE \"age\" > 0) FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(min(Columns.age / 2, filter: Columns.age > 0))),
            "SELECT MIN(\"age\" / 2) FILTER (WHERE \"age\" > 0) FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { min($0.age / 2, filter: $0.age > 0) }),
            "SELECT MIN(\"age\" / 2) FILTER (WHERE \"age\" > 0) FROM \"readers\"")
    }
    
    func testMultiArgumentMaxExpression() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(max(Columns.age, 1000))),
            "SELECT MAX(\"age\", 1000) FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { max($0.age, 1000) }),
            "SELECT MAX(\"age\", 1000) FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(max(Columns.age, 1000, Columns.id))),
            "SELECT MAX(\"age\", 1000, \"id\") FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { max($0.age, 1000, $0.id) }),
            "SELECT MAX(\"age\", 1000, \"id\") FROM \"readers\"")
    }
    
    func testAggregateMaxExpression() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(max(Columns.age))),
            "SELECT MAX(\"age\") FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { max($0.age) }),
            "SELECT MAX(\"age\") FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(max(Columns.age / 2))),
            "SELECT MAX(\"age\" / 2) FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { max($0.age / 2) }),
            "SELECT MAX(\"age\" / 2) FROM \"readers\"")
    }
    
    func testAggregateMaxExpression_filter() throws {
        #if GRDBCUSTOMSQLITE || SQLITE_HAS_CODEC
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3030000 else {
            throw XCTSkip("FILTER clause on aggregate functions is not available")
        }
        #else
        guard #available(iOS 14, macOS 10.16, tvOS 14, *) else {
            throw XCTSkip("FILTER clause on aggregate functions is not available")
        }
        #endif
        
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(max(Columns.age, filter: Columns.age < 0))),
            "SELECT MAX(\"age\") FILTER (WHERE \"age\" < 0) FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { max($0.age, filter: $0.age < 0) }),
            "SELECT MAX(\"age\") FILTER (WHERE \"age\" < 0) FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(max(Columns.age / 2, filter: Columns.age < 0))),
            "SELECT MAX(\"age\" / 2) FILTER (WHERE \"age\" < 0) FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { max($0.age / 2, filter: $0.age < 0) }),
            "SELECT MAX(\"age\" / 2) FILTER (WHERE \"age\" < 0) FROM \"readers\"")
    }
    
    func testSumExpression() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(sum(Columns.age))),
            "SELECT SUM(\"age\") FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { sum($0.age) }),
            "SELECT SUM(\"age\") FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(sum(Columns.age / 2))),
            "SELECT SUM(\"age\" / 2) FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { sum($0.age / 2) }),
            "SELECT SUM(\"age\" / 2) FROM \"readers\"")
    }
    
    func testSumExpression_filter() throws {
        #if GRDBCUSTOMSQLITE || SQLITE_HAS_CODEC
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3030000 else {
            throw XCTSkip("FILTER clause on aggregate functions is not available")
        }
        #else
        guard #available(iOS 14, macOS 10.16, tvOS 14, *) else {
            throw XCTSkip("FILTER clause on aggregate functions is not available")
        }
        #endif
        
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(sum(Columns.age, filter: Columns.age > 0))),
            "SELECT SUM(\"age\") FILTER (WHERE \"age\" > 0) FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { sum($0.age, filter: $0.age > 0) }),
            "SELECT SUM(\"age\") FILTER (WHERE \"age\" > 0) FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(sum(Columns.age / 2, filter: Columns.age > 0))),
            "SELECT SUM(\"age\" / 2) FILTER (WHERE \"age\" > 0) FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { sum($0.age / 2, filter: $0.age > 0) }),
            "SELECT SUM(\"age\" / 2) FILTER (WHERE \"age\" > 0) FROM \"readers\"")
    }
    
#if GRDBCUSTOMSQLITE || SQLITE_HAS_CODEC
    func testSumExpression_order() throws {
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3044000 else {
            throw XCTSkip("ORDER BY clause on aggregate functions is not available")
        }
        
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(sum(Columns.age, orderBy: Columns.age))),
            "SELECT SUM(\"age\" ORDER BY \"age\") FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { sum($0.age, orderBy: $0.age) }),
            "SELECT SUM(\"age\" ORDER BY \"age\") FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(sum(Columns.age / 2, orderBy: Columns.age.desc))),
            "SELECT SUM(\"age\" / 2 ORDER BY \"age\" DESC) FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { sum($0.age / 2, orderBy: $0.age.desc) }),
            "SELECT SUM(\"age\" / 2 ORDER BY \"age\" DESC) FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(sum(Columns.age, orderBy: Columns.age, filter: Columns.age > 0))),
            "SELECT SUM(\"age\" ORDER BY \"age\") FILTER (WHERE \"age\" > 0) FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { sum($0.age, orderBy: $0.age, filter: $0.age > 0) }),
            "SELECT SUM(\"age\" ORDER BY \"age\") FILTER (WHERE \"age\" > 0) FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(sum(Columns.age / 2, orderBy: Columns.age.desc, filter: Columns.age > 0))),
            "SELECT SUM(\"age\" / 2 ORDER BY \"age\" DESC) FILTER (WHERE \"age\" > 0) FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { sum($0.age / 2, orderBy: $0.age.desc, filter: $0.age > 0) }),
            "SELECT SUM(\"age\" / 2 ORDER BY \"age\" DESC) FILTER (WHERE \"age\" > 0) FROM \"readers\"")
    }
#endif
    
    func testTotalExpression() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(total(Columns.age))),
            "SELECT TOTAL(\"age\") FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { total($0.age) }),
            "SELECT TOTAL(\"age\") FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(total(Columns.age / 2))),
            "SELECT TOTAL(\"age\" / 2) FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { total($0.age / 2) }),
            "SELECT TOTAL(\"age\" / 2) FROM \"readers\"")
    }
    
    func testTotalExpression_filter() throws {
        #if GRDBCUSTOMSQLITE || SQLITE_HAS_CODEC
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3030000 else {
            throw XCTSkip("FILTER clause on aggregate functions is not available")
        }
        #else
        guard #available(iOS 14, macOS 10.16, tvOS 14, *) else {
            throw XCTSkip("FILTER clause on aggregate functions is not available")
        }
        #endif
        
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(total(Columns.age, filter: Columns.age > 0))),
            "SELECT TOTAL(\"age\") FILTER (WHERE \"age\" > 0) FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { total($0.age, filter: $0.age > 0) }),
            "SELECT TOTAL(\"age\") FILTER (WHERE \"age\" > 0) FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(total(Columns.age / 2, filter: Columns.age > 0))),
            "SELECT TOTAL(\"age\" / 2) FILTER (WHERE \"age\" > 0) FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { total($0.age / 2, filter: $0.age > 0) }),
            "SELECT TOTAL(\"age\" / 2) FILTER (WHERE \"age\" > 0) FROM \"readers\"")
    }
    
#if GRDBCUSTOMSQLITE || SQLITE_HAS_CODEC
    func testTotalExpression_order() throws {
        // Prevent SQLCipher failures
        guard Database.sqliteLibVersionNumber >= 3044000 else {
            throw XCTSkip("ORDER BY clause on aggregate functions is not available")
        }
        
        let dbQueue = try makeDatabaseQueue()

        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(total(Columns.age, orderBy: Columns.age))),
            "SELECT TOTAL(\"age\" ORDER BY \"age\") FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { total($0.age, orderBy: $0.age) }),
            "SELECT TOTAL(\"age\" ORDER BY \"age\") FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(total(Columns.age / 2, orderBy: Columns.age.desc))),
            "SELECT TOTAL(\"age\" / 2 ORDER BY \"age\" DESC) FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { total($0.age / 2, orderBy: $0.age.desc) }),
            "SELECT TOTAL(\"age\" / 2 ORDER BY \"age\" DESC) FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(total(Columns.age, orderBy: Columns.age, filter: Columns.age > 0))),
            "SELECT TOTAL(\"age\" ORDER BY \"age\") FILTER (WHERE \"age\" > 0) FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { total($0.age, orderBy: $0.age, filter: $0.age > 0) }),
            "SELECT TOTAL(\"age\" ORDER BY \"age\") FILTER (WHERE \"age\" > 0) FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(total(Columns.age / 2, orderBy: Columns.age.desc, filter: Columns.age > 0))),
            "SELECT TOTAL(\"age\" / 2 ORDER BY \"age\" DESC) FILTER (WHERE \"age\" > 0) FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { total($0.age / 2, orderBy: $0.age.desc, filter: $0.age > 0) }),
            "SELECT TOTAL(\"age\" / 2 ORDER BY \"age\" DESC) FILTER (WHERE \"age\" > 0) FROM \"readers\"")
    }
#endif
    
    // MARK: - LIKE operator
    
    func testLikeOperator() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.name.like("%foo"))),
            "SELECT * FROM \"readers\" WHERE \"name\" LIKE '%foo'")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.name.like("%foo") }),
            "SELECT * FROM \"readers\" WHERE \"name\" LIKE '%foo'")

        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!Columns.name.like("%foo"))),
            "SELECT * FROM \"readers\" WHERE \"name\" NOT LIKE '%foo'")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { !$0.name.like("%foo") }),
            "SELECT * FROM \"readers\" WHERE \"name\" NOT LIKE '%foo'")

        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.name.like("%foo") == true)),
            "SELECT * FROM \"readers\" WHERE (\"name\" LIKE '%foo') = 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.name.like("%foo") == true }),
            "SELECT * FROM \"readers\" WHERE (\"name\" LIKE '%foo') = 1")

        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.name.like("%foo") == false)),
            "SELECT * FROM \"readers\" WHERE (\"name\" LIKE '%foo') = 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.name.like("%foo") == false }),
            "SELECT * FROM \"readers\" WHERE (\"name\" LIKE '%foo') = 0")

        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.name.like("%foo", escape: "\\"))),
            "SELECT * FROM \"readers\" WHERE \"name\" LIKE '%foo' ESCAPE '\\'")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.name.like("%foo", escape: "\\") }),
            "SELECT * FROM \"readers\" WHERE \"name\" LIKE '%foo' ESCAPE '\\'")

        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(!Columns.name.like("%foo", escape: "\\"))),
            "SELECT * FROM \"readers\" WHERE \"name\" NOT LIKE '%foo' ESCAPE '\\'")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { !$0.name.like("%foo", escape: "\\") }),
            "SELECT * FROM \"readers\" WHERE \"name\" NOT LIKE '%foo' ESCAPE '\\'")

        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.name.like("%foo", escape: "\\") == true)),
            "SELECT * FROM \"readers\" WHERE (\"name\" LIKE '%foo' ESCAPE '\\') = 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.name.like("%foo", escape: "\\") == true }),
            "SELECT * FROM \"readers\" WHERE (\"name\" LIKE '%foo' ESCAPE '\\') = 1")

        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(Columns.name.like("%foo", escape: "\\") == false)),
            "SELECT * FROM \"readers\" WHERE (\"name\" LIKE '%foo' ESCAPE '\\') = 0")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { $0.name.like("%foo", escape: "\\") == false }),
            "SELECT * FROM \"readers\" WHERE (\"name\" LIKE '%foo' ESCAPE '\\') = 0")
    }
    
    
    // MARK: - || concat operator
    
    func testConcatOperator() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select([Columns.name, Columns.name].joined(operator: .concat))),
            """
            SELECT "name" || "name" FROM "readers"
            """)
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { [$0.name, $0.name].joined(operator: .concat) }),
            """
            SELECT "name" || "name" FROM "readers"
            """)

        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter([Columns.name, Columns.name].joined(operator: .concat) == "foo")),
            """
            SELECT * FROM "readers" WHERE ("name" || "name") = 'foo'
            """)
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter { [$0.name, $0.name].joined(operator: .concat) == "foo" }),
            """
            SELECT * FROM "readers" WHERE ("name" || "name") = 'foo'
            """)

        XCTAssertEqual(
            sql(dbQueue, tableRequest.select([Columns.name, " ".databaseValue, Columns.name].joined(operator: .concat))),
            """
            SELECT "name" || ' ' || "name" FROM "readers"
            """)
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { [$0.name, " ".databaseValue, $0.name].joined(operator: .concat) }),
            """
            SELECT "name" || ' ' || "name" FROM "readers"
            """)

        // Flattened
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select([
                [Columns.name, "a".databaseValue].joined(operator: .concat),
                ["b".databaseValue, Columns.name].joined(operator: .concat),
                ].joined(operator: .concat))),
            """
            SELECT "name" || 'a' || 'b' || "name" FROM "readers"
            """)
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { [
                [$0.name, "a".databaseValue].joined(operator: .concat),
                ["b".databaseValue, $0.name].joined(operator: .concat),
            ].joined(operator: .concat)
            }),
            """
            SELECT "name" || 'a' || 'b' || "name" FROM "readers"
            """)
    }

    
    // MARK: - Function
    
    func testCustomFunction() throws {
        let dbQueue = try makeDatabaseQueue()
        
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(customFunction(Columns.age, 1, 2))),
            "SELECT avgOf(\"age\", 1, 2) FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select { customFunction($0.age, 1, 2) }),
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
            
            try assertEqualSQL(db, IntegerPrimaryKeyRecord.select(SQLExpression.fastPrimaryKey), """
                SELECT "id" FROM "integerPrimaryKeyRecord"
                """)
            try assertEqualSQL(db, UUIDRecord.select(SQLExpression.fastPrimaryKey), """
                SELECT "rowid" FROM "uuidRecord"
                """)
            try assertEqualSQL(db, UUIDRecordWithoutRowID.select(SQLExpression.fastPrimaryKey), """
                SELECT "uuid" FROM "uuidRecordWithoutRowID"
                """)
            try assertEqualSQL(db, RowIDRecord.select(SQLExpression.fastPrimaryKey), """
                SELECT "rowid" FROM "rowIDRecord"
                """)
            try assertEqualSQL(db, CompoundPrimaryKeyRecord.select(SQLExpression.fastPrimaryKey), """
                SELECT "rowid" FROM "compoundPrimaryKeyRecord"
                """)
        }
    }
}

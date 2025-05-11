import XCTest
import GRDB

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

class TableRecordQueryInterfaceRequestTests: GRDBTestCase {
    
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
    
    
    // MARK: - Count
    
    func testFetchCount() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            XCTAssertEqual(try Reader.fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM \"readers\"")
            
            XCTAssertEqual(try Reader.all().reversed().fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM \"readers\"")
            
            XCTAssertEqual(try Reader.order(Columns.name).fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM \"readers\"")
            XCTAssertEqual(try Reader.order { $0.name }.fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM \"readers\"")
            
            XCTAssertEqual(try Reader.limit(10).fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM (SELECT * FROM \"readers\" LIMIT 10)")
            
            XCTAssertEqual(try Reader.filter(Columns.age == 42).fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM \"readers\" WHERE \"age\" = 42")
            XCTAssertEqual(try Reader.filter { $0.age == 42 }.fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM \"readers\" WHERE \"age\" = 42")
            
            XCTAssertEqual(try Reader.all().distinct().fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM (SELECT DISTINCT * FROM \"readers\")")
            
            XCTAssertEqual(try Reader.select(Columns.name).fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM \"readers\"")
            XCTAssertEqual(try Reader.select { $0.name }.fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM \"readers\"")
            
            XCTAssertEqual(try Reader.select(Columns.name).distinct().fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(DISTINCT \"name\") FROM \"readers\"")
            XCTAssertEqual(try Reader.select { $0.name }.distinct().fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(DISTINCT \"name\") FROM \"readers\"")
            
            XCTAssertEqual(try Reader.select(Columns.age * 2).distinct().fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(DISTINCT \"age\" * 2) FROM \"readers\"")
            XCTAssertEqual(try Reader.select { $0.age * 2 }.distinct().fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(DISTINCT \"age\" * 2) FROM \"readers\"")
            
            XCTAssertEqual(try Reader.select((Columns.age * 2).forKey("ignored")).distinct().fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(DISTINCT \"age\" * 2) FROM \"readers\"")
            XCTAssertEqual(try Reader.select { ($0.age * 2).forKey("ignored") }.distinct().fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(DISTINCT \"age\" * 2) FROM \"readers\"")
            
            XCTAssertEqual(try Reader.select(Columns.name, Columns.age).fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM \"readers\"")
            XCTAssertEqual(try Reader.select { [$0.name, $0.age] }.fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM \"readers\"")
            
            XCTAssertEqual(try Reader.select(Columns.name, Columns.age).distinct().fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM (SELECT DISTINCT \"name\", \"age\" FROM \"readers\")")
            XCTAssertEqual(try Reader.select { [$0.name, $0.age] }.distinct().fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM (SELECT DISTINCT \"name\", \"age\" FROM \"readers\")")
            
            XCTAssertEqual(try Reader.select(max(Columns.age)).group(Columns.name).fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM (SELECT MAX(\"age\") FROM \"readers\" GROUP BY \"name\")")
            XCTAssertEqual(try Reader.select { max($0.age) }.group { $0.name }.fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM (SELECT MAX(\"age\") FROM \"readers\" GROUP BY \"name\")")
            
            XCTAssertEqual(try Reader.select(.allColumns(excluding: [] as [String])).fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM \"readers\"")
            
            XCTAssertEqual(try Reader.select(.allColumns(excluding: [] as [String])).distinct().fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM (SELECT DISTINCT * FROM \"readers\")")
            
            XCTAssertEqual(try Reader.select(.allColumns(excluding: ["name"])).fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM \"readers\"")
            
            XCTAssertEqual(try Reader.select(.allColumns(excluding: ["name"])).distinct().fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM (SELECT DISTINCT \"id\", \"age\" FROM \"readers\")")
            
            XCTAssertEqual(try Reader.select(.allColumns(excluding: ["id", "name"])).fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM \"readers\"")
            
            XCTAssertEqual(try Reader.select(.allColumns(excluding: ["id", "name"])).distinct().fetchCount(db), 0)
            // This test tests for a missed optimization, because
            // SELECT COUNT(DISTINCT age) FROM readers would be correct as well.
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM (SELECT DISTINCT \"age\" FROM \"readers\")")
            
            XCTAssertEqual(try Reader.select(.allColumns(excluding: ["unknown"])).fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM \"readers\"")
            
            XCTAssertEqual(try Reader.select(.allColumns(excluding: ["unknown"])).distinct().fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM (SELECT DISTINCT * FROM \"readers\")")
        }
    }


    // MARK: - Select

    func testSelectLiteral() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Arthur", 42])
            try db.execute(sql: "INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Barbara", 36])
            
            let request = Reader.select(sql: "name, id - 1")
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
            try db.execute(sql: "INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Arthur", 42])
            try db.execute(sql: "INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Barbara", 36])
            
            let request = Reader.select(sql: "name, id - ?", arguments: [1])
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
            try db.execute(sql: "INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Arthur", 42])
            try db.execute(sql: "INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Barbara", 36])
            
            let request = Reader.select(sql: "name, id - :n", arguments: ["n": 1])
            let rows = try Row.fetchAll(db, request)
            XCTAssertEqual(lastSQLQuery, "SELECT name, id - 1 FROM \"readers\"")
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0][0] as String, "Arthur")
            XCTAssertEqual(rows[0][1] as Int64, 0)
            XCTAssertEqual(rows[1][0] as String, "Barbara")
            XCTAssertEqual(rows[1][1] as Int64, 1)
        }
    }
    
    func testSelectSQLLiteral() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Arthur", 42])
            try db.execute(sql: "INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Barbara", 36])
            
            func test(_ request: QueryInterfaceRequest<Reader>) throws {
                let rows = try Row.fetchAll(db, request)
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0][0] as String, "O'Brien")
                XCTAssertEqual(rows[0][1] as Int64, 0)
                XCTAssertEqual(rows[1][0] as String, "O'Brien")
                XCTAssertEqual(rows[1][1] as Int64, 1)
            }
            try test(Reader.select(literal: SQL(sql: ":name, id - :value", arguments: ["name": "O'Brien", "value": 1])))
            // Interpolation
            try test(Reader.select(literal: "\("O'Brien"), id - \(1)"))
        }
    }
    
    func testSelect() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Arthur", 42])
            try db.execute(sql: "INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Barbara", 36])
            
            do {
                let request = Reader.select(Columns.name, Columns.id - 1)
                let rows = try Row.fetchAll(db, request)
                XCTAssertEqual(lastSQLQuery, "SELECT \"name\", \"id\" - 1 FROM \"readers\"")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0][0] as String, "Arthur")
                XCTAssertEqual(rows[0][1] as Int64, 0)
                XCTAssertEqual(rows[1][0] as String, "Barbara")
                XCTAssertEqual(rows[1][1] as Int64, 1)
            }
            do {
                let request = Reader.select { [$0.name, $0.id - 1] }
                let rows = try Row.fetchAll(db, request)
                XCTAssertEqual(lastSQLQuery, "SELECT \"name\", \"id\" - 1 FROM \"readers\"")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0][0] as String, "Arthur")
                XCTAssertEqual(rows[0][1] as Int64, 0)
                XCTAssertEqual(rows[1][0] as String, "Barbara")
                XCTAssertEqual(rows[1][1] as Int64, 1)
            }
        }
    }

    func testMultipleSelect() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, Reader.select(Columns.age).select(Columns.name)),
            "SELECT \"name\" FROM \"readers\"")
        XCTAssertEqual(
            sql(dbQueue, Reader.select { $0.age }.select { $0.name }),
            "SELECT \"name\" FROM \"readers\"")
    }
    
    
    // MARK: - Filter
    
    func testFilterLiteral() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, Reader.filter(sql: "id <> 1")),
            "SELECT * FROM \"readers\" WHERE id <> 1")
    }
    
    func testFilterLiteralWithPositionalArguments() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, Reader.filter(sql: "id <> ?", arguments: [1])),
            "SELECT * FROM \"readers\" WHERE id <> 1")
    }
    
    func testFilterLiteralWithNamedArguments() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, Reader.filter(sql: "id <> :id", arguments: ["id": 1])),
            "SELECT * FROM \"readers\" WHERE id <> 1")
    }
    
    func testFilter() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, Reader.filter(true.databaseValue)),
            "SELECT * FROM \"readers\" WHERE 1")
    }
    
    func testMultipleFilter() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, Reader.filter(true.databaseValue).filter(false.databaseValue)),
            "SELECT * FROM \"readers\" WHERE 1 AND 0")
    }
    
    
    // MARK: - Sort
    
    func testSortLiteral() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, Reader.order(sql: "lower(name) desc")),
            "SELECT * FROM \"readers\" ORDER BY lower(name) desc")
    }
    
    func testSortLiteralWithPositionalArguments() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, Reader.order(sql: "age + ?", arguments: [1])),
            "SELECT * FROM \"readers\" ORDER BY age + 1")
    }
    
    func testSortLiteralWithNamedArguments() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, Reader.order(sql: "age + :age", arguments: ["age": 1])),
            "SELECT * FROM \"readers\" ORDER BY age + 1")
    }
    
    func testSort() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, Reader.order(Columns.age)),
            "SELECT * FROM \"readers\" ORDER BY \"age\"")
        XCTAssertEqual(
            sql(dbQueue, Reader.order { $0.age }),
            "SELECT * FROM \"readers\" ORDER BY \"age\"")
        #if compiler(>=6.1)
        XCTAssertEqual(
            sql(dbQueue, Reader.order(\.age)),
            "SELECT * FROM \"readers\" ORDER BY \"age\"")
        #endif
        
        XCTAssertEqual(
            sql(dbQueue, Reader.order(Columns.age.asc)),
            "SELECT * FROM \"readers\" ORDER BY \"age\" ASC")
        XCTAssertEqual(
            sql(dbQueue, Reader.order { $0.age.asc }),
            "SELECT * FROM \"readers\" ORDER BY \"age\" ASC")
        #if compiler(>=6.1)
        XCTAssertEqual(
            sql(dbQueue, Reader.order(\.age.asc)),
            "SELECT * FROM \"readers\" ORDER BY \"age\" ASC")
        #endif
        
        XCTAssertEqual(
            sql(dbQueue, Reader.order(Columns.age.desc)),
            "SELECT * FROM \"readers\" ORDER BY \"age\" DESC")
        XCTAssertEqual(
            sql(dbQueue, Reader.order { $0.age.desc }),
            "SELECT * FROM \"readers\" ORDER BY \"age\" DESC")
        #if compiler(>=6.1)
        XCTAssertEqual(
            sql(dbQueue, Reader.order(\.age.desc)),
            "SELECT * FROM \"readers\" ORDER BY \"age\" DESC")
        #endif
        
        XCTAssertEqual(
            sql(dbQueue, Reader.order(Columns.age, Columns.name.desc)),
            "SELECT * FROM \"readers\" ORDER BY \"age\", \"name\" DESC")
        XCTAssertEqual(
            sql(dbQueue, Reader.order { [$0.age, $0.name.desc] }),
            "SELECT * FROM \"readers\" ORDER BY \"age\", \"name\" DESC")
        
        XCTAssertEqual(
            sql(dbQueue, Reader.order(abs(Columns.age))),
            "SELECT * FROM \"readers\" ORDER BY ABS(\"age\")")
        XCTAssertEqual(
            sql(dbQueue, Reader.order { abs($0.age) }),
            "SELECT * FROM \"readers\" ORDER BY ABS(\"age\")")
        
        #if GRDBCUSTOMSQLITE
        XCTAssertEqual(
            sql(dbQueue, Reader.order(Columns.age.ascNullsLast)),
            "SELECT * FROM \"readers\" ORDER BY \"age\" ASC NULLS LAST")
        XCTAssertEqual(
            sql(dbQueue, Reader.order { $0.age.ascNullsLast }),
            "SELECT * FROM \"readers\" ORDER BY \"age\" ASC NULLS LAST")
        #if compiler(>=6.1)
        XCTAssertEqual(
            sql(dbQueue, Reader.order(\.age.ascNullsLast)),
            "SELECT * FROM \"readers\" ORDER BY \"age\" ASC NULLS LAST")
        #endif
        
        XCTAssertEqual(
            sql(dbQueue, Reader.order(Columns.age.descNullsFirst)),
            "SELECT * FROM \"readers\" ORDER BY \"age\" DESC NULLS FIRST")
        XCTAssertEqual(
            sql(dbQueue, Reader.order { $0.age.descNullsFirst }),
            "SELECT * FROM \"readers\" ORDER BY \"age\" DESC NULLS FIRST")
        #if compiler(>=6.1)
        XCTAssertEqual(
            sql(dbQueue, Reader.order(\.age.descNullsFirst)),
            "SELECT * FROM \"readers\" ORDER BY \"age\" DESC NULLS FIRST")
        #endif
        #elseif !GRDBCIPHER
        if #available(iOS 14, macOS 10.16, tvOS 14, *) {
            XCTAssertEqual(
                sql(dbQueue, Reader.order(Columns.age.ascNullsLast)),
                "SELECT * FROM \"readers\" ORDER BY \"age\" ASC NULLS LAST")
            XCTAssertEqual(
                sql(dbQueue, Reader.order { $0.age.ascNullsLast }),
                "SELECT * FROM \"readers\" ORDER BY \"age\" ASC NULLS LAST")
            #if compiler(>=6.1)
            XCTAssertEqual(
                sql(dbQueue, Reader.order(\.age.ascNullsLast)),
                "SELECT * FROM \"readers\" ORDER BY \"age\" ASC NULLS LAST")
            #endif
            
            XCTAssertEqual(
                sql(dbQueue, Reader.order(Columns.age.descNullsFirst)),
                "SELECT * FROM \"readers\" ORDER BY \"age\" DESC NULLS FIRST")
            XCTAssertEqual(
                sql(dbQueue, Reader.order { $0.age.descNullsFirst }),
                "SELECT * FROM \"readers\" ORDER BY \"age\" DESC NULLS FIRST")
            #if compiler(>=6.1)
            XCTAssertEqual(
                sql(dbQueue, Reader.order(\.age.descNullsFirst)),
                "SELECT * FROM \"readers\" ORDER BY \"age\" DESC NULLS FIRST")
            #endif
        }
        #endif
    }
    
    func testMultipleSort() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, Reader.order(Columns.age).order(Columns.name)),
            "SELECT * FROM \"readers\" ORDER BY \"name\"")
        XCTAssertEqual(
            sql(dbQueue, Reader.order { $0.age }.order { $0.name }),
            "SELECT * FROM \"readers\" ORDER BY \"name\"")
    }
    
    
    // MARK: - Limit
    
    func testLimit() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, Reader.limit(1)),
            "SELECT * FROM \"readers\" LIMIT 1")
        XCTAssertEqual(
            sql(dbQueue, Reader.limit(1, offset: 2)),
            "SELECT * FROM \"readers\" LIMIT 1 OFFSET 2")
    }
    
    func testMultipleLimit() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, Reader.limit(1, offset: 2).limit(3)),
            "SELECT * FROM \"readers\" LIMIT 3")
    }
    
    // MARK: - Exists
    
    func testExists() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inTransaction { db in
            struct Player: TableRecord { }
            try db.create(table: "player") { t in
                t.column("a").unique()
                t.column("b")
                t.column("c")
                t.uniqueKey(["b", "c"])
            }
            
            try XCTAssertFalse(Player.exists(db, key: 1))
            XCTAssertEqual(lastSQLQuery, "SELECT EXISTS (SELECT * FROM \"player\" WHERE \"rowid\" = 1)")
            
            try XCTAssertFalse(Player.exists(db, key: ["a": 1]))
            XCTAssertEqual(lastSQLQuery, "SELECT EXISTS (SELECT * FROM \"player\" WHERE \"a\" = 1)")
            
            try XCTAssertFalse(Player.exists(db, key: ["a": 1, "b": 2]))
            XCTAssertEqual(lastSQLQuery, "SELECT EXISTS (SELECT * FROM \"player\" WHERE (\"a\" = 1) AND (\"b\" = 2))")
            
            try XCTAssertFalse(Player.exists(db, key: ["b": 1, "c": 2]))
            XCTAssertEqual(lastSQLQuery, "SELECT EXISTS (SELECT * FROM \"player\" WHERE (\"b\" = 1) AND (\"c\" = 2))")
            
            return .rollback
        }
        
        try dbQueue.inTransaction { db in
            struct Player: TableRecord { }
            try db.create(table: "player") { t in
                t.primaryKey("a", .integer)
            }
            
            try XCTAssertFalse(Player.exists(db, key: 1))
            XCTAssertEqual(lastSQLQuery, "SELECT EXISTS (SELECT * FROM \"player\" WHERE \"a\" = 1)")
            
            try XCTAssertFalse(Player.exists(db, key: ["a": 2]))
            XCTAssertEqual(lastSQLQuery, "SELECT EXISTS (SELECT * FROM \"player\" WHERE \"a\" = 2)")
            
            return .rollback
        }
        
        try dbQueue.inTransaction { db in
            struct Player: TableRecord { }
            try db.create(table: "player") { t in
                t.primaryKey("id", .text)
            }
            
            try XCTAssertFalse(Player.exists(db, key: "foo"))
            XCTAssertEqual(lastSQLQuery, "SELECT EXISTS (SELECT * FROM \"player\" WHERE \"id\" = 'foo')")
            
            try XCTAssertFalse(Player.exists(db, key: ["id": "bar"]))
            XCTAssertEqual(lastSQLQuery, "SELECT EXISTS (SELECT * FROM \"player\" WHERE \"id\" = 'bar')")
            
            return .rollback
        }
    }
    
    func testExistsIdentifiable() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inTransaction { db in
            struct Player: TableRecord, Identifiable {
                var id: Int64
            }
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            
            try XCTAssertFalse(Player.exists(db, id: 1))
            XCTAssertEqual(lastSQLQuery, "SELECT EXISTS (SELECT * FROM \"player\" WHERE \"id\" = 1)")
            
            return .rollback
        }
        try dbQueue.inTransaction { db in
            struct Player: TableRecord, Identifiable {
                var id: Int64?
            }
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            
            try XCTAssertFalse(Player.exists(db, id: 1))
            XCTAssertEqual(lastSQLQuery, "SELECT EXISTS (SELECT * FROM \"player\" WHERE \"id\" = 1)")
            
            clearSQLQueries()
            try XCTAssertFalse(Player.exists(db, id: nil))
            XCTAssertNil(lastSQLQuery) // Database not hit
            
            return .rollback
        }
        try dbQueue.inTransaction { db in
            struct Player: TableRecord, Identifiable {
                var id: String
            }
            try db.create(table: "player") { t in
                t.primaryKey("id", .text)
            }
            
            try XCTAssertFalse(Player.exists(db, id: "foo"))
            XCTAssertEqual(lastSQLQuery, "SELECT EXISTS (SELECT * FROM \"player\" WHERE \"id\" = 'foo')")
            
            return .rollback
        }
    }
}

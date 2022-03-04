import XCTest
import GRDB

private struct Col {
    static let id = Column("id")
    static let name = Column("name")
    static let age = Column("age")
    static let readerId = Column("readerId")
}

private struct Reader : TableRecord {
    static let databaseTableName = "readers"
}

class TableRecordQueryInterfaceRequestTests: GRDBTestCase {
    
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
    
    
    // MARK: - Count
    
    func testFetchCount() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            XCTAssertEqual(try Reader.fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM \"readers\"")
            
            XCTAssertEqual(try Reader.all().reversed().fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM \"readers\"")
            
            XCTAssertEqual(try Reader.order(Col.name).fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM \"readers\"")
            
            XCTAssertEqual(try Reader.limit(10).fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM (SELECT * FROM \"readers\" LIMIT 10)")
            
            XCTAssertEqual(try Reader.filter(Col.age == 42).fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM \"readers\" WHERE \"age\" = 42")
            
            XCTAssertEqual(try Reader.all().distinct().fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM (SELECT DISTINCT * FROM \"readers\")")
            
            XCTAssertEqual(try Reader.select(Col.name).fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM \"readers\"")
            
            XCTAssertEqual(try Reader.select(Col.name).distinct().fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(DISTINCT \"name\") FROM \"readers\"")
            
            XCTAssertEqual(try Reader.select(Col.age * 2).distinct().fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(DISTINCT \"age\" * 2) FROM \"readers\"")
            
            XCTAssertEqual(try Reader.select((Col.age * 2).forKey("ignored")).distinct().fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(DISTINCT \"age\" * 2) FROM \"readers\"")
            
            XCTAssertEqual(try Reader.select(Col.name, Col.age).fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM \"readers\"")
            
            XCTAssertEqual(try Reader.select(Col.name, Col.age).distinct().fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM (SELECT DISTINCT \"name\", \"age\" FROM \"readers\")")
            
            XCTAssertEqual(try Reader.select(max(Col.age)).group(Col.name).fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM (SELECT MAX(\"age\") FROM \"readers\" GROUP BY \"name\")")
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
            try XCTAssertEqual(rows[0][0] as String, "Arthur")
            try XCTAssertEqual(rows[0][1] as Int64, 0)
            try XCTAssertEqual(rows[1][0] as String, "Barbara")
            try XCTAssertEqual(rows[1][1] as Int64, 1)
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
            try XCTAssertEqual(rows[0][0] as String, "Arthur")
            try XCTAssertEqual(rows[0][1] as Int64, 0)
            try XCTAssertEqual(rows[1][0] as String, "Barbara")
            try XCTAssertEqual(rows[1][1] as Int64, 1)
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
            try XCTAssertEqual(rows[0][0] as String, "Arthur")
            try XCTAssertEqual(rows[0][1] as Int64, 0)
            try XCTAssertEqual(rows[1][0] as String, "Barbara")
            try XCTAssertEqual(rows[1][1] as Int64, 1)
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
                try XCTAssertEqual(rows[0][0] as String, "O'Brien")
                try XCTAssertEqual(rows[0][1] as Int64, 0)
                try XCTAssertEqual(rows[1][0] as String, "O'Brien")
                try XCTAssertEqual(rows[1][1] as Int64, 1)
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
            
            let request = Reader.select(Col.name, Col.id - 1)
            let rows = try Row.fetchAll(db, request)
            XCTAssertEqual(lastSQLQuery, "SELECT \"name\", \"id\" - 1 FROM \"readers\"")
            XCTAssertEqual(rows.count, 2)
            try XCTAssertEqual(rows[0][0] as String, "Arthur")
            try XCTAssertEqual(rows[0][1] as Int64, 0)
            try XCTAssertEqual(rows[1][0] as String, "Barbara")
            try XCTAssertEqual(rows[1][1] as Int64, 1)
        }
    }

    func testMultipleSelect() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, Reader.select(Col.age).select(Col.name)),
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
            sql(dbQueue, Reader.order(Col.age)),
            "SELECT * FROM \"readers\" ORDER BY \"age\"")
        XCTAssertEqual(
            sql(dbQueue, Reader.order(Col.age.asc)),
            "SELECT * FROM \"readers\" ORDER BY \"age\" ASC")
        XCTAssertEqual(
            sql(dbQueue, Reader.order(Col.age.desc)),
            "SELECT * FROM \"readers\" ORDER BY \"age\" DESC")
        XCTAssertEqual(
            sql(dbQueue, Reader.order(Col.age, Col.name.desc)),
            "SELECT * FROM \"readers\" ORDER BY \"age\", \"name\" DESC")
        XCTAssertEqual(
            sql(dbQueue, Reader.order(abs(Col.age))),
            "SELECT * FROM \"readers\" ORDER BY ABS(\"age\")")
        #if GRDBCUSTOMSQLITE
        XCTAssertEqual(
            sql(dbQueue, Reader.order(Col.age.ascNullsLast)),
            "SELECT * FROM \"readers\" ORDER BY \"age\" ASC NULLS LAST")
        XCTAssertEqual(
            sql(dbQueue, Reader.order(Col.age.descNullsFirst)),
            "SELECT * FROM \"readers\" ORDER BY \"age\" DESC NULLS FIRST")
        #elseif !GRDBCIPHER
        if #available(OSX 10.16, iOS 14, tvOS 14, watchOS 7, *) {
            XCTAssertEqual(
                sql(dbQueue, Reader.order(Col.age.ascNullsLast)),
                "SELECT * FROM \"readers\" ORDER BY \"age\" ASC NULLS LAST")
            XCTAssertEqual(
                sql(dbQueue, Reader.order(Col.age.descNullsFirst)),
                "SELECT * FROM \"readers\" ORDER BY \"age\" DESC NULLS FIRST")
        }
        #endif
    }
    
    func testMultipleSort() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, Reader.order(Col.age).order(Col.name)),
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
                t.column("a", .integer).notNull().primaryKey()
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
                t.column("id", .text).notNull().primaryKey()
            }
            
            try XCTAssertFalse(Player.exists(db, key: "foo"))
            XCTAssertEqual(lastSQLQuery, "SELECT EXISTS (SELECT * FROM \"player\" WHERE \"id\" = 'foo')")
            
            try XCTAssertFalse(Player.exists(db, key: ["id": "bar"]))
            XCTAssertEqual(lastSQLQuery, "SELECT EXISTS (SELECT * FROM \"player\" WHERE \"id\" = 'bar')")
            
            return .rollback
        }
    }
    
    func testExistsIdentifiable() throws {
        guard #available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6, *) else {
            throw XCTSkip("Identifiable is not available")
        }
        
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
            
            sqlQueries.removeAll()
            try XCTAssertFalse(Player.exists(db, id: nil))
            XCTAssertNil(lastSQLQuery) // Database not hit

            return .rollback
        }
        try dbQueue.inTransaction { db in
            struct Player: TableRecord, Identifiable {
                var id: String
            }
            try db.create(table: "player") { t in
                t.column("id", .text).notNull().primaryKey()
            }
            
            try XCTAssertFalse(Player.exists(db, id: "foo"))
            XCTAssertEqual(lastSQLQuery, "SELECT EXISTS (SELECT * FROM \"player\" WHERE \"id\" = 'foo')")
            
            return .rollback
        }
    }
}

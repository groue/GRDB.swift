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
private let tableRequest = Reader.all()

class QueryInterfaceRequestTests: GRDBTestCase {
    
    let collation = DatabaseCollation("localized_case_insensitive") { (lhs, rhs) in
        return (lhs as NSString).localizedCaseInsensitiveCompare(rhs)
    }
    
    override func setUp() {
        super.setUp()
        dbConfiguration.prepareDatabase { db in
            db.add(collation: self.collation)
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
    
    // MARK: - Preparation
    
    func testSimpleRequestDoesNotUseAnyRowAdapter() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let adapter = try Reader.all().makePreparedRequest(db, forSingleResult: false).adapter
            XCTAssertNil(adapter)
        }
    }
    
    // MARK: - Fetch rows
    
    func testFetchRowFromRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Arthur", 42])
            try db.execute(sql: "INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Barbara", 36])
            
            do {
                let rows = try Row.fetchAll(db, tableRequest)
                XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"readers\"")
                XCTAssertEqual(rows.count, 2)
                try XCTAssertEqual(rows[0]["id"] as Int64, 1)
                try XCTAssertEqual(rows[0]["name"] as String, "Arthur")
                try XCTAssertEqual(rows[0]["age"] as Int, 42)
                try XCTAssertEqual(rows[1]["id"] as Int64, 2)
                try XCTAssertEqual(rows[1]["name"] as String, "Barbara")
                try XCTAssertEqual(rows[1]["age"] as Int, 36)
            }
            
            do {
                let row = try Row.fetchOne(db, tableRequest)!
                XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"readers\" LIMIT 1")
                try XCTAssertEqual(row["id"] as Int64, 1)
                try XCTAssertEqual(row["name"] as String, "Arthur")
                try XCTAssertEqual(row["age"] as Int, 42)
            }
            
            do {
                var names: [String] = []
                let rows = try Row.fetchCursor(db, tableRequest)
                while let row = try rows.next() {
                    try names.append(row["name"])
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
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM \"readers\" WHERE \"age\" = 42")
            
            XCTAssertEqual(try tableRequest.distinct().fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM (SELECT DISTINCT * FROM \"readers\")")
            
            XCTAssertEqual(try tableRequest.select(Col.name).fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM \"readers\"")
            
            XCTAssertEqual(try tableRequest.select(Col.name).distinct().fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(DISTINCT \"name\") FROM \"readers\"")
            
            XCTAssertEqual(try tableRequest.select(Col.age * 2).distinct().fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(DISTINCT \"age\" * 2) FROM \"readers\"")
            
            XCTAssertEqual(try tableRequest.select((Col.age * 2).forKey("ignored")).distinct().fetchCount(db), 0)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(DISTINCT \"age\" * 2) FROM \"readers\"")
            
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
            try db.execute(sql: "INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Arthur", 42])
            try db.execute(sql: "INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Barbara", 36])
            
            let request = tableRequest.select(sql: "name, id - 1")
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
            
            let request = tableRequest.select(sql: "name, id - ?", arguments: [1])
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
            
            let request = tableRequest.select(sql: "name, id - :n", arguments: ["n": 1])
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
            try test(tableRequest.select(literal: SQL(sql: ":name, id - :value", arguments: ["name": "O'Brien", "value": 1])))
            // Interpolation
            try test(tableRequest.select(literal: "\("O'Brien"), id - \(1)"))
        }
    }
    
    func testSelect() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Arthur", 42])
            try db.execute(sql: "INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Barbara", 36])
            
            let request = tableRequest.select(Col.name, Col.id - 1)
            let rows = try Row.fetchAll(db, request)
            XCTAssertEqual(lastSQLQuery, "SELECT \"name\", \"id\" - 1 FROM \"readers\"")
            XCTAssertEqual(rows.count, 2)
            try XCTAssertEqual(rows[0][0] as String, "Arthur")
            try XCTAssertEqual(rows[0][1] as Int64, 0)
            try XCTAssertEqual(rows[1][0] as String, "Barbara")
            try XCTAssertEqual(rows[1][1] as Int64, 1)
        }
    }
    
    func testSelectionCustomKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Arthur", 42])
            
            let request = tableRequest.select(Col.name.forKey("nom"), (Col.age + 1).forKey("agePlusOne"))
            let row = try Row.fetchOne(db, request)!
            XCTAssertEqual(lastSQLQuery, "SELECT \"name\" AS \"nom\", \"age\" + 1 AS \"agePlusOne\" FROM \"readers\" LIMIT 1")
            try XCTAssertEqual(row["nom"] as String, "Arthur")
            try XCTAssertEqual(row["agePlusOne"] as Int, 43)
        }
    }
    
    func testAnnotated() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            do {
                let request = Reader.annotated(with: [Col.id - 1])
                _ = try Row.fetchAll(db, request)
                XCTAssertEqual(lastSQLQuery, "SELECT *, \"id\" - 1 FROM \"readers\"")
            }
            do {
                let request = Reader.annotated(with: Col.id - 1, Col.id + 1)
                _ = try Row.fetchAll(db, request)
                XCTAssertEqual(lastSQLQuery, "SELECT *, \"id\" - 1, \"id\" + 1 FROM \"readers\"")
            }
            do {
                let request = tableRequest.annotated(with: [Col.id - 1])
                _ = try Row.fetchAll(db, request)
                XCTAssertEqual(lastSQLQuery, "SELECT *, \"id\" - 1 FROM \"readers\"")
            }
            do {
                let request = tableRequest.annotated(with: Col.id - 1, Col.id + 1)
                _ = try Row.fetchAll(db, request)
                XCTAssertEqual(lastSQLQuery, "SELECT *, \"id\" - 1, \"id\" + 1 FROM \"readers\"")
            }
            do {
                let request = tableRequest.select(Col.name).annotated(with: [Col.id - 1])
                _ = try Row.fetchAll(db, request)
                XCTAssertEqual(lastSQLQuery, "SELECT \"name\", \"id\" - 1 FROM \"readers\"")
            }
            do {
                let request = tableRequest.select(Col.name).annotated(with: Col.id - 1, Col.id + 1)
                _ = try Row.fetchAll(db, request)
                XCTAssertEqual(lastSQLQuery, "SELECT \"name\", \"id\" - 1, \"id\" + 1 FROM \"readers\"")
            }
        }
    }
    
    func testAnnotatedWithForeignColumn() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "author") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text)
            }
            try db.create(table: "book") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("authorId", .integer).references("author")
            }
            try db.execute(sql: """
                INSERT INTO author(id, name) VALUES (1, 'Arthur');
                INSERT INTO book(id, authorId) VALUES (2, 1);
                """)
            struct Author: TableRecord { }
            struct Book: TableRecord {
                static let author = belongsTo(Author.self)
            }
            
            let alias = TableAlias()
            let request = Book
                .annotated(with: alias[Column("name")])
                .joining(required: Book.author.aliased(alias))
            let rows = try Row.fetchCursor(db, request)
            while let row = try rows.next() {
                // Just some sanity checks that the "author"."name" SQL column is
                // simply exposed as "name" in Swift code:
                XCTAssertEqual(row, ["id":2, "authorId":1, "name":"Arthur"])
                XCTAssertEqual(Set(row.columnNames), ["id", "authorId", "name"])
                try XCTAssertEqual(row["name"], "Arthur")
            }
            XCTAssertEqual(lastSQLQuery, """
                SELECT "book".*, "author"."name" \
                FROM "book" \
                JOIN "author" ON "author"."id" = "book"."authorId"
                """)
        }
    }
    
    func testMultipleSelect() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.select(Col.age).select(Col.name)),
            "SELECT \"name\" FROM \"readers\"")
    }
    
    func testSelectAs() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Arthur", 42])
            
            // select(..., as: String.self)
            do {
                // Type.select(..., as:)
                do {
                    // variadic
                    do {
                        let value = try Reader
                            .select(Col.name, as: String.self)
                            .fetchOne(db)!
                        XCTAssertEqual(value, "Arthur")
                    }
                    // array
                    do {
                        let value = try Reader
                            .select([Col.name], as: String.self)
                            .fetchOne(db)!
                        XCTAssertEqual(value, "Arthur")
                    }
                    // `SQL` literal
                    do {
                        let value = try Reader
                            .select(literal: SQL(sql: "? AS name", arguments: ["O'Brien"]), as: String.self)
                            .fetchOne(db)!
                        XCTAssertEqual(value, "O'Brien")
                    }
                    // `SQL` literal with interpolation
                    do {
                        let value = try Reader
                            .select(literal: "\("O'Brien") AS name", as: String.self)
                            .fetchOne(db)!
                        XCTAssertEqual(value, "O'Brien")
                    }
                    // raw sql without argument
                    do {
                        let value = try Reader
                            .select(sql: "name", as: String.self)
                            .fetchOne(db)!
                        XCTAssertEqual(value, "Arthur")
                    }
                }
                // request.select(..., as:)
                do {
                    // variadic
                    do {
                        let value = try Reader
                            .all()
                            .select(Col.name, as: String.self)
                            .fetchOne(db)!
                        XCTAssertEqual(value, "Arthur")
                    }
                    // array
                    do {
                        let value = try Reader
                            .all()
                            .select([Col.name], as: String.self)
                            .fetchOne(db)!
                        XCTAssertEqual(value, "Arthur")
                    }
                    // `SQL` literal
                    do {
                        let value = try Reader
                            .all()
                            .select(literal: SQL(sql: "? AS name", arguments: ["O'Brien"]), as: String.self)
                            .fetchOne(db)!
                        XCTAssertEqual(value, "O'Brien")
                    }
                    // `SQL` literal with interpolation
                    do {
                        let value = try Reader
                            .all()
                            .select(literal: "\("O'Brien") AS name", as: String.self)
                            .fetchOne(db)!
                        XCTAssertEqual(value, "O'Brien")
                    }
                    // raw sql without argument
                    do {
                        let value = try Reader
                            .all()
                            .select(sql: "name", as: String.self)
                            .fetchOne(db)!
                        XCTAssertEqual(value, "Arthur")
                    }
                }
            }
            
            // select(..., as: Row.self)
            do {
                // Type.select(..., as:)
                do {
                    // variadic
                    do {
                        let value = try Reader
                            .select(Col.name, Col.age, as: Row.self)
                            .fetchOne(db)!
                        XCTAssertEqual(value, ["name": "Arthur", "age": 42])
                    }
                    // array
                    do {
                        let value = try Reader
                            .select([Col.name, Col.age], as: Row.self)
                            .fetchOne(db)!
                        XCTAssertEqual(value, ["name": "Arthur", "age": 42])
                    }
                    // `SQL` literal with named argument
                    do {
                        let value = try Reader
                            .select(literal: SQL(sql: "name, :age AS age", arguments: ["age": 22]), as: Row.self)
                            .fetchOne(db)!
                        XCTAssertEqual(value, ["name": "Arthur", "age": 22])
                    }
                    // `SQL` literal with interpolation
                    do {
                        let value = try Reader
                            .select(literal: "\("O'Brien") AS name, \(22) AS age", as: Row.self)
                            .fetchOne(db)!
                        XCTAssertEqual(value, ["name": "O'Brien", "age": 22])
                    }
                    // raw sql with named argument
                    do {
                        let value = try Reader
                            .select(sql: "name, :age AS age", arguments: ["age": 22], as: Row.self)
                            .fetchOne(db)!
                        XCTAssertEqual(value, ["name": "Arthur", "age": 22])
                    }
                }
                // request.select(..., as:)
                do {
                    // variadic
                    do {
                        let value = try Reader
                            .all()
                            .select(Col.name, Col.age, as: Row.self)
                            .fetchOne(db)!
                        XCTAssertEqual(value, ["name": "Arthur", "age": 42])
                    }
                    // array
                    do {
                        let value = try Reader
                            .all()
                            .select([Col.name, Col.age], as: Row.self)
                            .fetchOne(db)!
                        XCTAssertEqual(value, ["name": "Arthur", "age": 42])
                    }
                    // `SQL` literal with positional argument
                    do {
                        let value = try Reader
                            .all()
                            .select(literal: SQL(sql: "name, ? AS age", arguments: [22]), as: Row.self)
                            .fetchOne(db)!
                        XCTAssertEqual(value, ["name": "Arthur", "age": 22])
                    }
                    // `SQL` literal with interpolation
                    do {
                        let value = try Reader
                            .all()
                            .select(literal: "\("O'Brien") AS name, \(22) AS age", as: Row.self)
                            .fetchOne(db)!
                        XCTAssertEqual(value, ["name": "O'Brien", "age": 22])
                    }
                    // raw sql with positional argument
                    do {
                        let value = try Reader
                            .all()
                            .select(sql: "name, ? AS age", arguments: [22], as: Row.self)
                            .fetchOne(db)!
                        XCTAssertEqual(value, ["name": "Arthur", "age": 22])
                    }
                }
            }
        }
    }
    
    // This test passes if this method compiles
    func testSelectAsTypeInference() {
        _ = Reader.select(Col.name) as QueryInterfaceRequest<String>
        _ = Reader.select([Col.name]) as QueryInterfaceRequest<String>
        _ = Reader.select(sql: "name") as QueryInterfaceRequest<String>
        _ = Reader.select(literal: SQL(sql: "name")) as QueryInterfaceRequest<String>
        _ = Reader.all().select(Col.name) as QueryInterfaceRequest<String>
        _ = Reader.all().select([Col.name]) as QueryInterfaceRequest<String>
        _ = Reader.all().select(sql: "name") as QueryInterfaceRequest<String>
        _ = Reader.all().select(literal: SQL(sql: "name")) as QueryInterfaceRequest<String>
        
        func makeRequest() -> QueryInterfaceRequest<String> {
            Reader.select(Col.name)
        }
        
        // Those should be, without any ambiguuity, requests of Reader.
        do {
            let request = Reader.select(Col.name)
            _ = request as QueryInterfaceRequest<Reader>
        }
        do {
            let request = Reader.select([Col.name])
            _ = request as QueryInterfaceRequest<Reader>
        }
        do {
            let request = Reader.select(sql: "name")
            _ = request as QueryInterfaceRequest<Reader>
        }
        do {
            let request = Reader.select(literal: SQL(sql: "name"))
            _ = request as QueryInterfaceRequest<Reader>
        }
        do {
            let request = Reader.all().select(Col.name)
            _ = request as QueryInterfaceRequest<Reader>
        }
        do {
            let request = Reader.all().select([Col.name])
            _ = request as QueryInterfaceRequest<Reader>
        }
        do {
            let request = Reader.all().select(sql: "name")
            _ = request as QueryInterfaceRequest<Reader>
        }
        do {
            let request = Reader.all().select(literal: SQL(sql: "name"))
            _ = request as QueryInterfaceRequest<Reader>
        }
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
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(sql: "id <> 1").filter(true.databaseValue)),
            "SELECT * FROM \"readers\" WHERE (id <> 1) AND 1")
    }
    
    func testFilterLiteralWithPositionalArguments() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(sql: "id <> ?", arguments: [1])),
            "SELECT * FROM \"readers\" WHERE id <> 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(sql: "id <> ?", arguments: [1]).filter(true.databaseValue)),
            "SELECT * FROM \"readers\" WHERE (id <> 1) AND 1")
    }
    
    func testFilterLiteralWithNamedArguments() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(sql: "id <> :id", arguments: ["id": 1])),
            "SELECT * FROM \"readers\" WHERE id <> 1")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(sql: "id <> :id", arguments: ["id": 1]).filter(true.databaseValue)),
            "SELECT * FROM \"readers\" WHERE (id <> 1) AND 1")
    }
    
    func testFilterLiteralWithMixedArguments() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest
                .filter(sql: "age > :age", arguments: ["age": 20])
                .filter(sql: "name = ?", arguments: ["arthur"])),
            "SELECT * FROM \"readers\" WHERE (age > 20) AND (name = 'arthur')")
        XCTAssertEqual(
            sql(dbQueue, tableRequest
                .filter(sql: "age > ?", arguments: [20])
                .filter(sql: "name = :name", arguments: ["name": "arthur"])),
            "SELECT * FROM \"readers\" WHERE (age > 20) AND (name = 'arthur')")
    }
    
    func testFilter() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(true.databaseValue)),
            "SELECT * FROM \"readers\" WHERE 1")
    }
    
    func testMultipleFilter() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.filter(true.databaseValue).filter(false.databaseValue)),
            "SELECT * FROM \"readers\" WHERE 1 AND 0")
    }
    
    // Regression test for https://github.com/groue/GRDB.swift/issues/812
    func testFilterOnView() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.execute(sql: "CREATE VIEW v AS SELECT * FROM readers")
            struct ViewRecord: TableRecord, FetchableRecord, Decodable {
                static let databaseTableName = "v"
            }
            _ = try ViewRecord.filter(Column("id") == 1).fetchOne(db)
            XCTAssertEqual(
                lastSQLQuery,
                "SELECT * FROM \"v\" WHERE \"id\" = 1 LIMIT 1")
        }
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
            "SELECT * FROM \"readers\" GROUP BY \"name\" HAVING MIN(\"age\") > 18")
    }
    
    func testMultipleHaving() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(
            sql(dbQueue, tableRequest.group(Col.name).having(min(Col.age) > 18).having(max(Col.age) < 50)),
            "SELECT * FROM \"readers\" GROUP BY \"name\" HAVING (MIN(\"age\") > 18) AND (MAX(\"age\") < 50)")
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
        #if GRDBCUSTOMSQLITE
        XCTAssertEqual(
            sql(dbQueue, tableRequest.order(Col.age.ascNullsLast)),
            "SELECT * FROM \"readers\" ORDER BY \"age\" ASC NULLS LAST")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.order(Col.age.descNullsFirst)),
            "SELECT * FROM \"readers\" ORDER BY \"age\" DESC NULLS FIRST")
        #elseif !GRDBCIPHER
        if #available(OSX 10.16, iOS 14, tvOS 14, watchOS 7, *) {
            XCTAssertEqual(
                sql(dbQueue, tableRequest.order(Col.age.ascNullsLast)),
                "SELECT * FROM \"readers\" ORDER BY \"age\" ASC NULLS LAST")
            XCTAssertEqual(
                sql(dbQueue, tableRequest.order(Col.age.descNullsFirst)),
                "SELECT * FROM \"readers\" ORDER BY \"age\" DESC NULLS FIRST")
        }
        #endif
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
        #if GRDBCUSTOMSQLITE
        XCTAssertEqual(
            sql(dbQueue, tableRequest.order(Col.name.collating(.nocase).ascNullsLast)),
            "SELECT * FROM \"readers\" ORDER BY \"name\" COLLATE NOCASE ASC NULLS LAST")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.order(Col.name.collating(.nocase).descNullsFirst)),
            "SELECT * FROM \"readers\" ORDER BY \"name\" COLLATE NOCASE DESC NULLS FIRST")
        #elseif !GRDBCIPHER
        if #available(OSX 10.16, iOS 14, tvOS 14, watchOS 7, *) {
            XCTAssertEqual(
                sql(dbQueue, tableRequest.order(Col.name.collating(.nocase).ascNullsLast)),
                "SELECT * FROM \"readers\" ORDER BY \"name\" COLLATE NOCASE ASC NULLS LAST")
            XCTAssertEqual(
                sql(dbQueue, tableRequest.order(Col.name.collating(.nocase).descNullsFirst)),
                "SELECT * FROM \"readers\" ORDER BY \"name\" COLLATE NOCASE DESC NULLS FIRST")
        }
        #endif
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
            "SELECT * FROM \"readers\"")
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
        #if GRDBCUSTOMSQLITE
        XCTAssertEqual(
            sql(dbQueue, tableRequest.order(Col.age.descNullsFirst).reversed()),
            "SELECT * FROM \"readers\" ORDER BY \"age\" ASC NULLS LAST")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.order(Col.age.ascNullsLast).reversed()),
            "SELECT * FROM \"readers\" ORDER BY \"age\" DESC NULLS FIRST")
        #elseif !GRDBCIPHER
        if #available(OSX 10.16, iOS 14, tvOS 14, watchOS 7, *) {
            XCTAssertEqual(
                sql(dbQueue, tableRequest.order(Col.age.descNullsFirst).reversed()),
                "SELECT * FROM \"readers\" ORDER BY \"age\" ASC NULLS LAST")
            XCTAssertEqual(
                sql(dbQueue, tableRequest.order(Col.age.ascNullsLast).reversed()),
                "SELECT * FROM \"readers\" ORDER BY \"age\" DESC NULLS FIRST")
        }
        #endif
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
        #if GRDBCUSTOMSQLITE
        XCTAssertEqual(
            sql(dbQueue, tableRequest.order(Col.name.collating(.nocase).ascNullsLast).reversed()),
            "SELECT * FROM \"readers\" ORDER BY \"name\" COLLATE NOCASE DESC NULLS FIRST")
        XCTAssertEqual(
            sql(dbQueue, tableRequest.order(Col.name.collating(.nocase).descNullsFirst).reversed()),
            "SELECT * FROM \"readers\" ORDER BY \"name\" COLLATE NOCASE ASC NULLS LAST")
        #elseif !GRDBCIPHER
        if #available(OSX 10.16, iOS 14, tvOS 14, watchOS 7, *) {
            XCTAssertEqual(
                sql(dbQueue, tableRequest.order(Col.name.collating(.nocase).ascNullsLast).reversed()),
                "SELECT * FROM \"readers\" ORDER BY \"name\" COLLATE NOCASE DESC NULLS FIRST")
            XCTAssertEqual(
                sql(dbQueue, tableRequest.order(Col.name.collating(.nocase).descNullsFirst).reversed()),
                "SELECT * FROM \"readers\" ORDER BY \"name\" COLLATE NOCASE ASC NULLS LAST")
        }
        #endif
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
    
    // MARK: - FetchOne Optimization
    
    func testFetchOneLimitOptimization() throws {
        // Test that we avoid emitting "LIMIT 1" when possible
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            do {
                _ = try Row.fetchOne(db, tableRequest.filter(key: 1))
                XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"readers\" WHERE \"id\" = 1")
            }
            do {
                _ = try Row.fetchOne(db, tableRequest.filter(Column("id") == 1))
                XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"readers\" WHERE \"id\" = 1")
            }
            do {
                _ = try Row.fetchOne(db, tableRequest.filter(Column("id") == nil))
                XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"readers\" WHERE \"id\" IS NULL")
            }
            do {
                _ = try Row.fetchOne(db, tableRequest.filter(Column("name") == "Arthur"))
                XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"readers\" WHERE \"name\" = \'Arthur\' LIMIT 1")
            }
            do {
                _ = try Row.fetchOne(db, tableRequest.filter(Column("id") == 1 && Column("name") == "Arthur"))
                XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"readers\" WHERE (\"id\" = 1) AND (\"name\" = \'Arthur\')")
            }
            do {
                _ = try Row.fetchOne(db, tableRequest.filter(Column("id") == 1).filter(Column("name") == "Arthur"))
                XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"readers\" WHERE (\"id\" = 1) AND (\"name\" = \'Arthur\')")
            }
            do {
                _ = try Row.fetchOne(db, tableRequest.filter(Column("id")))
                XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"readers\" WHERE \"id\" LIMIT 1")
            }
            do {
                _ = try Row.fetchOne(db, tableRequest.filter(Column("id") != 1))
                XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"readers\" WHERE \"id\" <> 1 LIMIT 1")
            }
            do {
                _ = try Row.fetchOne(db, tableRequest.filter(Column("id") == 1 && Column("id") == 2))
                XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"readers\" WHERE (\"id\" = 1) AND (\"id\" = 2)")
            }
            do {
                _ = try Row.fetchOne(db, tableRequest.filter(Column("id") == 1 || Column("id") == 2))
                XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"readers\" WHERE (\"id\" = 1) OR (\"id\" = 2) LIMIT 1")
            }
            do {
                _ = try Row.fetchOne(db, tableRequest.select(max(Column("id"))))
                XCTAssertEqual(lastSQLQuery, "SELECT MAX(\"id\") FROM \"readers\"")
            }
            do {
                _ = try Row.fetchOne(db, tableRequest.select(min(Column("age")).forKey("minAge"), max(Column("age")).forKey("maxAge")))
                XCTAssertEqual(lastSQLQuery, "SELECT MIN(\"age\") AS \"minAge\", MAX(\"age\") AS \"maxAge\" FROM \"readers\"")
            }
            do {
                _ = try Row.fetchOne(db, tableRequest.select(max(Column("age") + 1)))
                XCTAssertEqual(lastSQLQuery, "SELECT MAX(\"age\" + 1) FROM \"readers\"")
            }
            do {
                _ = try Row.fetchOne(db, tableRequest.select(max(Column("age")) + 1))
                XCTAssertEqual(lastSQLQuery, "SELECT MAX(\"age\") + 1 FROM \"readers\"")
            }
        }
    }
    
    // MARK: - Exists
    
    func testIsEmpty() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try XCTAssertTrue(tableRequest.isEmpty(db))
            XCTAssertEqual(lastSQLQuery, "SELECT EXISTS (SELECT * FROM \"readers\")")

            try db.execute(sql: "INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Arthur", 42])
            try db.execute(sql: "INSERT INTO readers (name, age) VALUES (?, ?)", arguments: ["Barbara", 36])
            
            try XCTAssertFalse(tableRequest.isEmpty(db))
            XCTAssertEqual(lastSQLQuery, "SELECT EXISTS (SELECT * FROM \"readers\")")

            try XCTAssertFalse(tableRequest.filter(Column("name") == "Arthur").isEmpty(db))
            XCTAssertEqual(lastSQLQuery, "SELECT EXISTS (SELECT * FROM \"readers\" WHERE \"name\" = 'Arthur')")
        }
    }
}

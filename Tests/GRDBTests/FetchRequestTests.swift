import XCTest
import GRDB

class FetchRequestTests: GRDBTestCase {
    
    func testRequestFetchRows() throws {
        struct CustomRequest: FetchRequest {
            typealias RowDecoder = Row
            func requestSQL(_ context: SQLGenerationContext, forSingleResult singleResult: Bool) throws -> String {
                "SELECT * FROM table1"
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "table1") { t in
                t.column("id", .integer).primaryKey()
            }
            try db.execute(sql: "INSERT INTO table1 DEFAULT VALUES")
            try db.execute(sql: "INSERT INTO table1 DEFAULT VALUES")
            
            let request = CustomRequest()
            let rows = try request.fetchAll(db)
            XCTAssertEqual(lastSQLQuery, "SELECT * FROM table1")
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0], ["id": 1])
            XCTAssertEqual(rows[1], ["id": 2])
        }
    }
    
    func testRequestFetchValues() throws {
        struct CustomRequest : FetchRequest {
            typealias RowDecoder = Int
            func requestSQL(_ context: SQLGenerationContext, forSingleResult singleResult: Bool) throws -> String {
                "SELECT id FROM table1"
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "table1") { t in
                t.column("id", .integer).primaryKey()
            }
            try db.execute(sql: "INSERT INTO table1 DEFAULT VALUES")
            try db.execute(sql: "INSERT INTO table1 DEFAULT VALUES")
            
            let request = CustomRequest()
            let ints = try request.fetchAll(db)
            XCTAssertEqual(lastSQLQuery, "SELECT id FROM table1")
            XCTAssertEqual(ints.count, 2)
            XCTAssertEqual(ints[0], 1)
            XCTAssertEqual(ints[1], 2)
        }
    }
    
    func testRequestFetchRecords() throws {
        struct CustomRecord: FetchableRecord, Decodable {
            var id: Int
        }
        struct CustomRequest : FetchRequest {
            typealias RowDecoder = CustomRecord
            func requestSQL(_ context: SQLGenerationContext, forSingleResult singleResult: Bool) throws -> String {
                "SELECT id FROM table1"
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "table1") { t in
                t.column("id", .integer).primaryKey()
            }
            try db.execute(sql: "INSERT INTO table1 DEFAULT VALUES")
            try db.execute(sql: "INSERT INTO table1 DEFAULT VALUES")
            
            let request = CustomRequest()
            let records = try request.fetchAll(db)
            XCTAssertEqual(lastSQLQuery, "SELECT id FROM table1")
            XCTAssertEqual(records.count, 2)
            XCTAssertEqual(records[0].id, 1)
            XCTAssertEqual(records[1].id, 2)
        }
    }
    
    func testRequestFetchCount() throws {
        struct CustomRequest : FetchRequest {
            typealias RowDecoder = Row
            func requestSQL(_ context: SQLGenerationContext, forSingleResult singleResult: Bool) throws -> String {
                "SELECT * FROM table1"
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "table1") { t in
                t.column("id", .integer).primaryKey()
            }
            try db.execute(sql: "INSERT INTO table1 DEFAULT VALUES")
            try db.execute(sql: "INSERT INTO table1 DEFAULT VALUES")
            
            let request = CustomRequest()
            let count = try request.fetchCount(db)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM (SELECT * FROM table1)")
            XCTAssertEqual(count, 2)
        }
    }
    
    func testRequestCustomizedFetchCount() throws {
        struct CustomRequest : FetchRequest {
            typealias RowDecoder = Row
            func requestSQL(_ context: SQLGenerationContext, forSingleResult singleResult: Bool) throws -> String {
                "INVALID"
            }
            
            func fetchCount(_ db: Database) throws -> Int { 2 }
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "table1") { t in
                t.column("id", .integer).primaryKey()
            }
            try db.execute(sql: "INSERT INTO table1 DEFAULT VALUES")
            try db.execute(sql: "INSERT INTO table1 DEFAULT VALUES")
            
            let request = CustomRequest()
            let count = try request.fetchCount(db)
            XCTAssertEqual(lastSQLQuery, "INSERT INTO table1 DEFAULT VALUES")
            XCTAssertEqual(count, 2)
        }
    }
    
    // Test for the `singleResult` parameter of
    // FetchRequest.prepare(_:singleResult:)
    func testSingleResultHint() throws {
        struct CustomRequest<T>: FetchRequest {
            typealias RowDecoder = T
            func requestSQL(_ context: SQLGenerationContext, forSingleResult singleResult: Bool) throws -> String {
                if singleResult {
                    return "SELECT 'single' AS hint"
                } else {
                    return "SELECT 'multiple' AS hint"
                }
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            // Row
            do {
                do {
                    let request = CustomRequest<Row>()
                    do {
                        let rows = try request.fetchAll(db)
                        XCTAssertEqual(rows.count, 1)
                        XCTAssertEqual(rows[0], ["hint": "multiple"])
                    }
                    do {
                        let rows = try request.fetchCursor(db)
                        while let row = try rows.next() {
                            XCTAssertEqual(row, ["hint": "multiple"])
                        }
                    }
                    do {
                        let row = try request.fetchOne(db)!
                        XCTAssertEqual(row, ["hint": "single"])
                    }
                }
                do {
                    let request = CustomRequest<Void>()
                    do {
                        let rows = try Row.fetchAll(db, request)
                        XCTAssertEqual(rows.count, 1)
                        XCTAssertEqual(rows[0], ["hint": "multiple"])
                    }
                    do {
                        let rows = try Row.fetchCursor(db, request)
                        while let row = try rows.next() {
                            XCTAssertEqual(row, ["hint": "multiple"])
                        }
                    }
                    do {
                        let row = try Row.fetchOne(db, request)!
                        XCTAssertEqual(row, ["hint": "single"])
                    }
                }
            }
            
            // DatabaseValueConvertible
            do {
                struct Value: DatabaseValueConvertible {
                    var string: String
                    var databaseValue: DatabaseValue { string.databaseValue }
                    static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Value? {
                        String.fromDatabaseValue(dbValue).map(Value.init)
                    }
                }
                do {
                    let request = CustomRequest<Value>()
                    do {
                        let values = try request.fetchAll(db)
                        XCTAssertEqual(values.count, 1)
                        XCTAssertEqual(values[0].string, "multiple")
                    }
                    do {
                        let values = try request.fetchCursor(db)
                        while let value = try values.next() {
                            XCTAssertEqual(value.string, "multiple")
                        }
                    }
                    do {
                        let value = try request.fetchOne(db)!
                        XCTAssertEqual(value.string, "single")
                    }
                }
                do {
                    let request = CustomRequest<Void>()
                    do {
                        let values = try Value.fetchAll(db, request)
                        XCTAssertEqual(values.count, 1)
                        XCTAssertEqual(values[0].string, "multiple")
                    }
                    do {
                        let values = try Value.fetchCursor(db, request)
                        while let value = try values.next() {
                            XCTAssertEqual(value.string, "multiple")
                        }
                    }
                    do {
                        let value = try Value.fetchOne(db, request)!
                        XCTAssertEqual(value.string, "single")
                    }
                }
            }
            
            // DatabaseValueConvertible + StatementColumnConvertible
            do {
                struct Value: DatabaseValueConvertible, StatementColumnConvertible {
                    var string: String
                    init(string: String) {
                        self.string = string
                    }
                    init(sqliteStatement: SQLiteStatement, index: Int32) {
                        self.init(string: String(sqliteStatement: sqliteStatement, index: index))
                    }
                    var databaseValue: DatabaseValue { string.databaseValue }
                    static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Value? {
                        String.fromDatabaseValue(dbValue).map { Value(string: $0) }
                    }
                }
                do {
                    let request = CustomRequest<Value>()
                    do {
                        let values = try request.fetchAll(db)
                        XCTAssertEqual(values.count, 1)
                        XCTAssertEqual(values[0].string, "multiple")
                    }
                    do {
                        let values = try request.fetchCursor(db)
                        while let value = try values.next() {
                            XCTAssertEqual(value.string, "multiple")
                        }
                    }
                    do {
                        let value = try request.fetchOne(db)!
                        XCTAssertEqual(value.string, "single")
                    }
                }
                do {
                    let request = CustomRequest<Void>()
                    do {
                        let values = try Value.fetchAll(db, request)
                        XCTAssertEqual(values.count, 1)
                        XCTAssertEqual(values[0].string, "multiple")
                    }
                    do {
                        let values = try Value.fetchCursor(db, request)
                        while let value = try values.next() {
                            XCTAssertEqual(value.string, "multiple")
                        }
                    }
                    do {
                        let value = try Value.fetchOne(db, request)!
                        XCTAssertEqual(value.string, "single")
                    }
                }
            }
            
            // FetchableRecord
            do {
                struct Record: FetchableRecord {
                    var string: String
                    init(row: Row) {
                        string = row[0]
                    }
                }
                do {
                    let request = CustomRequest<Record>()
                    do {
                        let records = try request.fetchAll(db)
                        XCTAssertEqual(records.count, 1)
                        XCTAssertEqual(records[0].string, "multiple")
                    }
                    do {
                        let records = try request.fetchCursor(db)
                        while let record = try records.next() {
                            XCTAssertEqual(record.string, "multiple")
                        }
                    }
                    do {
                        let record = try request.fetchOne(db)!
                        XCTAssertEqual(record.string, "single")
                    }
                }
                do {
                    let request = CustomRequest<Void>()
                    do {
                        let records = try Record.fetchAll(db, request)
                        XCTAssertEqual(records.count, 1)
                        XCTAssertEqual(records[0].string, "multiple")
                    }
                    do {
                        let records = try Record.fetchCursor(db, request)
                        while let record = try records.next() {
                            XCTAssertEqual(record.string, "multiple")
                        }
                    }
                    do {
                        let record = try Record.fetchOne(db, request)!
                        XCTAssertEqual(record.string, "single")
                    }
                }
            }
        }
    }
    
    func testSingleResultHintIsNotUsedForDefaultFetchCount() throws {
        struct CustomRequest: FetchRequest {
            typealias RowDecoder = Void
            func requestSQL(_ context: SQLGenerationContext, forSingleResult singleResult: Bool) throws -> String {
                if singleResult { fatalError("not implemented") }
                return "SELECT 'multiple'"
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            let request = CustomRequest()
            _ = try request.fetchCount(db)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM (SELECT 'multiple')")
        }
    }
    
    func testSingleResultHintIsNotUsedForDefaultDatabaseRegion() throws {
        struct CustomRequest: FetchRequest {
            typealias RowDecoder = Void
            func requestSQL(_ context: SQLGenerationContext, forSingleResult singleResult: Bool) throws -> String {
                if singleResult { fatalError("not implemented") }
                return "SELECT * FROM multiple"
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.execute(sql: "CREATE TABLE multiple(a)")
            
            let request = CustomRequest()
            let region = try request.databaseRegion(db)
            XCTAssertEqual(region.description, "multiple(a)")
        }
    }
    
    func testSQLLiteralBasedFetchRequest() throws {
        // Here we test that users can implement their own FetchRequest type.
        struct CustomRequest : FetchRequest {
            typealias RowDecoder = String
            
            func requestSQL(_ context: SQLGenerationContext, forSingleResult singleResult: Bool) throws -> String {
                let literal: SQLLiteral = "SELECT \("O'Brien")"
                return try literal.sql(context)
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let value = try CustomRequest().fetchOne(db)
            XCTAssertEqual(value, "O'Brien")
            XCTAssertEqual(lastSQLQuery, "SELECT 'O''Brien'")
        }
    }
    
    func testFetchRequestDerivedFromPreparedRequest() throws {
        // Here we test that we can derive requestSQL(_:forSingleResult:) from
        // makePreparedRequest(_:forSingleResult:).
        //
        // This is an upgrade path from GRDB4 to GRDB5.
        //
        // We also test that the same SQLLiteral can be used in both
        // makePreparedRequest() and requestSQL() (see testSQLLiteralBasedFetchRequest)
        struct CustomRequest : FetchRequest {
            typealias RowDecoder = Row
            
            func requestSQL(_ context: SQLGenerationContext, forSingleResult singleResult: Bool) throws -> String {
                try makePreparedRequest(context.db, forSingleResult: singleResult).requestSQL(context)
            }
            
            func makePreparedRequest(_ db: Database, forSingleResult singleResult: Bool) throws -> PreparedRequest {
                let literal: SQLLiteral = "SELECT \("O'Brien")"
                let statement = try db.makeSelectStatement(literal: literal)
                return PreparedRequest(statement: statement)
            }
        }

        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let request = CustomRequest()
            _ = try SQLRequest<Row>("SELECT * FROM (\(request))").fetchAll(db)
            XCTAssertEqual(lastSQLQuery, "SELECT * FROM (SELECT 'O''Brien')")
        }
    }
    
    func testFetchRequestInconsistency() throws {
        // What happens when requestSQL(_:forSingleResult:)
        // and makePreparedRequest(_:forSingleResult:) do not agree?
        struct Table1: TableRecord { }
        struct Table2: TableRecord { }
        struct CustomRequest : FetchRequest {
            typealias RowDecoder = Row
            func requestSQL(_ context: SQLGenerationContext, forSingleResult singleResult: Bool) throws -> String {
                try Table1.all().requestSQL(context, forSingleResult: singleResult)
            }
            func makePreparedRequest(_ db: Database, forSingleResult singleResult: Bool) throws -> PreparedRequest {
                try Table2.all().makePreparedRequest(db, forSingleResult: singleResult)
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "table1") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "table2") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            
            let request = CustomRequest()
            
            // DatabaseRegionConvertible
            let region = try request.databaseRegion(db)
            XCTAssertEqual(region.description, "table1(*)")
            
            // FetchRequest
            _ = try request.fetchAll(db)
            XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"table2\"")
            
            _ = try request.fetchCount(db)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM (SELECT * FROM \"table1\")")
            
            // SQLExpression
            _ = try SQLRequest<Row>("SELECT \(request == 1)").fetchAll(db)
            XCTAssertEqual(lastSQLQuery, "SELECT (SELECT * FROM \"table1\") = 1")
            
            // SQLCollection
            _ = try SQLRequest<Row>("SELECT \(request.contains(1))").fetchAll(db)
            XCTAssertEqual(lastSQLQuery, "SELECT 1 IN (SELECT * FROM \"table1\")")
            
            // SQLRequestProtocol
            _ = try SQLRequest<Row>("SELECT * FROM (\(request))").fetchAll(db)
            XCTAssertEqual(lastSQLQuery, "SELECT * FROM (SELECT * FROM \"table1\")")
        }
    }
    
    func testRequestAsSQLExpression() throws {
        struct CustomRequest : FetchRequest {
            typealias RowDecoder = Row
            func requestSQL(_ context: SQLGenerationContext, forSingleResult singleResult: Bool) throws -> String {
                "SELECT id FROM table1"
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "table1") { t in
                t.column("id", .integer).primaryKey()
            }
            
            let derivedExpression = CustomRequest() > 0
            let sqlRequest: SQLRequest<Row> = "SELECT \(derivedExpression)"
            let statement = try sqlRequest.makePreparedRequest(db, forSingleResult: false).statement
            XCTAssertEqual(statement.sql, "SELECT (SELECT id FROM table1) > ?")
        }
    }
    
    func testRequestAsSQLCollection() throws {
        struct CustomRequest : FetchRequest {
            typealias RowDecoder = Row
            func requestSQL(_ context: SQLGenerationContext, forSingleResult singleResult: Bool) throws -> String {
                "SELECT id FROM table1"
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "table1") { t in
                t.column("id", .integer).primaryKey()
            }
            
            let derivedExpression = CustomRequest().contains(0)
            let sqlRequest: SQLRequest<Row> = "SELECT \(derivedExpression)"
            let statement = try sqlRequest.makePreparedRequest(db, forSingleResult: false).statement
            XCTAssertEqual(statement.sql, "SELECT ? IN (SELECT id FROM table1)")
        }
    }
    
    func testRequestInterpolation() throws {
        struct CustomRequest : FetchRequest {
            typealias RowDecoder = Row
            func requestSQL(_ context: SQLGenerationContext, forSingleResult singleResult: Bool) throws -> String {
                "SELECT id FROM table1"
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "table1") { t in
                t.column("id", .integer).primaryKey()
            }
            
            let sqlRequest: SQLRequest<Row> = "SELECT * FROM (\(CustomRequest()))"
            let statement = try sqlRequest.makePreparedRequest(db, forSingleResult: false).statement
            XCTAssertEqual(statement.sql, "SELECT * FROM (SELECT id FROM table1)")
        }
    }
}

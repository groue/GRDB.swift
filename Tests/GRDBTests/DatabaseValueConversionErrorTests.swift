import XCTest
#if GRDBCUSTOMSQLITE
    @testable import GRDBCustomSQLite
#else
    @testable import GRDB
#endif

// Those tests are tightly coupled to GRDB decoding code.
// Each test comes with the (commented) crashing code snippets that trigger it.
class DatabaseValueConversionErrorTests: GRDBTestCase {
    func testFetchableRecord1() throws {
        struct Record: FetchableRecord {
            var name: String
            
            init(row: Row) {
                name = row["name"]
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        
        // conversion error
        try dbQueue.read { db in
            let statement = try db.makeSelectStatement(sql: "SELECT ? AS name")
            statement.arguments = [nil]
            let row = try Row.fetchOne(statement)!
            
            // _ = Record(row: row)
            XCTAssertEqual(
                conversionErrorMessage(
                    to: String.self,
                    from: row["name"],
                    conversionContext: ValueConversionContext(row).atColumn("name")),
                "could not convert database value NULL to String (column: `name`, column index: 0, row: [name:NULL])")
            
            // TODO: this test is obsolete since 566f42e8d07e57a0d9c4aec452e3ad7ed15dd59b
            // _ = try Record.fetchOne(statement)
            try Row.fetchCursor(statement).forEach { row in
                XCTAssertEqual(
                    conversionErrorMessage(
                        to: String.self,
                        from: row["name"],
                        conversionContext: ValueConversionContext(row).atColumn("name")),
                    "could not convert database value NULL to String (column: `name`, column index: 0, row: [name:NULL], sql: `SELECT ? AS name`, arguments: [NULL])")
            }
        }
        
        // missing column
        try dbQueue.read { db in
            let statement = try db.makeSelectStatement(sql: "SELECT ? AS unused")
            statement.arguments = ["ignored"]
            let row = try Row.fetchOne(statement)!
            
            // _ = Record(row: row)
            XCTAssertEqual(
                conversionErrorMessage(
                    to: String.self,
                    from: row["name"],
                    conversionContext: ValueConversionContext(row).atColumn("name")),
                "could not read String from missing column `name` (row: [unused:\"ignored\"])")
            
            // _ = try Record.fetchOne(statement)
            try Row.fetchCursor(statement).forEach { row in
                XCTAssertEqual(
                    conversionErrorMessage(
                        to: String.self,
                        from: row["name"],
                        conversionContext: ValueConversionContext(row).atColumn("name")),
                    "could not read String from missing column `name` (row: [unused:\"ignored\"], sql: `SELECT ? AS unused`, arguments: [\"ignored\"])")
            }
        }
    }
    
    func testFetchableRecord2() throws {
        enum Value: String, DatabaseValueConvertible, Decodable {
            case valid
        }
        
        struct Record: FetchableRecord {
            var value: Value
            
            init(row: Row) {
                value = row["value"]
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        
        // conversion error
        try dbQueue.read { db in
            let statement = try db.makeSelectStatement(sql: "SELECT 1, ? AS value")
            statement.arguments = ["invalid"]
            let row = try Row.fetchOne(statement)!
            
            // _ = Record(row: row)
            XCTAssertEqual(
                conversionErrorMessage(
                    to: Value.self,
                    from: row["value"],
                    conversionContext: ValueConversionContext(row).atColumn("value")),
                "could not convert database value \"invalid\" to \(Value.self) (column: `value`, column index: 1, row: [1:1 value:\"invalid\"])")
            
            // _ = try Record.fetchOne(statement)
            try Row.fetchCursor(statement).forEach { row in
                XCTAssertEqual(
                    conversionErrorMessage(
                        to: Value.self,
                        from: row["value"],
                        conversionContext: ValueConversionContext(row).atColumn("value")),
                    "could not convert database value \"invalid\" to \(Value.self) (column: `value`, column index: 1, row: [1:1 value:\"invalid\"], sql: `SELECT 1, ? AS value`, arguments: [\"invalid\"])")
            }
        }
        
        // missing column
        try dbQueue.read { db in
            let statement = try db.makeSelectStatement(sql: "SELECT ? AS unused")
            statement.arguments = ["ignored"]
            let row = try Row.fetchOne(statement)!
            
            // _ = Record(row: row)
            XCTAssertEqual(
                conversionErrorMessage(
                    to: Value.self,
                    from: row["value"],
                    conversionContext: ValueConversionContext(row).atColumn("value")),
                "could not read \(Value.self) from missing column `value` (row: [unused:\"ignored\"])")
            
            // _ = try Record.fetchOne(statement)
            try Row.fetchCursor(statement).forEach { row in
                XCTAssertEqual(
                    conversionErrorMessage(
                        to: Value.self,
                        from: row["value"],
                        conversionContext: ValueConversionContext(row).atColumn("value")),
                    "could not read \(Value.self) from missing column `value` (row: [unused:\"ignored\"], sql: `SELECT ? AS unused`, arguments: [\"ignored\"])")
            }
        }
    }

    func testDecodableFetchableRecord1() throws {
        struct Record: Decodable, FetchableRecord {
            var name: String
            var team: String
        }
        
        let dbQueue = try makeDatabaseQueue()
        
        // conversion error
        try dbQueue.read { db in
            let statement = try db.makeSelectStatement(sql: "SELECT NULL AS name, ? AS team")
            statement.arguments = ["invalid"]
            let row = try Row.fetchOne(statement)!
            
            // _ = Record(row: row)
            XCTAssertEqual(
                conversionErrorMessage(
                    to: String.self,
                    from: row["name"],
                    conversionContext: ValueConversionContext(row).atColumn("name")),
                "could not convert database value NULL to String (column: `name`, column index: 0, row: [name:NULL team:\"invalid\"])")
            
            // TODO: this test is obsolete since 566f42e8d07e57a0d9c4aec452e3ad7ed15dd59b
            // _ = try Record.fetchOne(statement)
            try Row.fetchCursor(statement).forEach { row in
                XCTAssertEqual(
                    conversionErrorMessage(
                        to: String.self,
                        from: row["name"],
                        conversionContext: ValueConversionContext(row).atColumn("name")),
                    "could not convert database value NULL to String (column: `name`, column index: 0, row: [name:NULL team:\"invalid\"], sql: `SELECT NULL AS name, ? AS team`, arguments: [\"invalid\"])")
            }
        }
        
        // missing column
        try dbQueue.read { db in
            let statement = try db.makeSelectStatement(sql: "SELECT ? AS unused")
            statement.arguments = ["ignored"]
            let row = try Row.fetchOne(statement)!

            // _ = Record(row: row)
            XCTAssertEqual(
                conversionErrorMessage(
                    to: String.self,
                    from: row["name"],
                    conversionContext: ValueConversionContext(row).atColumn("name")),
                "could not read String from missing column `name` (row: [unused:\"ignored\"])")
            
            // _ = try Record.fetchOne(statement)
            try Row.fetchCursor(statement).forEach { row in
                XCTAssertEqual(
                    conversionErrorMessage(
                        to: String.self,
                        from: row["name"],
                        conversionContext: ValueConversionContext(row).atColumn("name")),
                    "could not read String from missing column `name` (row: [unused:\"ignored\"], sql: `SELECT ? AS unused`, arguments: [\"ignored\"])")
            }
        }
    }
    
    func testDecodableFetchableRecord2() throws {
        enum Value: String, DatabaseValueConvertible, Decodable {
            case valid
        }
        
        struct Record: Decodable, FetchableRecord {
            var value: Value
        }

        let dbQueue = try makeDatabaseQueue()
        
        // conversion error
        try dbQueue.read { db in
            let statement = try db.makeSelectStatement(sql: "SELECT NULL AS name, ? AS value")
            statement.arguments = ["invalid"]
            let row = try Row.fetchOne(statement)!
            
            // _ = Record(row: row)
            XCTAssertEqual(
                conversionErrorMessage(
                    to: Value.self,
                    from: row["value"],
                    conversionContext: ValueConversionContext(row).atColumn("value")),
                "could not convert database value \"invalid\" to \(Value.self) (column: `value`, column index: 1, row: [name:NULL value:\"invalid\"])")
            
            // _ = try Record.fetchOne(statement)
            try Row.fetchCursor(statement).forEach { row in
                XCTAssertEqual(
                    conversionErrorMessage(
                        to: Value.self,
                        from: row["value"],
                        conversionContext: ValueConversionContext(row).atColumn("value")),
                    "could not convert database value \"invalid\" to \(Value.self) (column: `value`, column index: 1, row: [name:NULL value:\"invalid\"], sql: `SELECT NULL AS name, ? AS value`, arguments: [\"invalid\"])")
            }
        }
        
        // missing column
        try dbQueue.read { db in
            let statement = try db.makeSelectStatement(sql: "SELECT ? AS unused")
            statement.arguments = ["ignored"]
            let row = try Row.fetchOne(statement)!

            // _ = Record(row: row)
            XCTAssertEqual(
                conversionErrorMessage(
                    to: Value.self,
                    from: row["value"],
                    conversionContext: ValueConversionContext(row).atColumn("value")),
                "could not read \(Value.self) from missing column `value` (row: [unused:\"ignored\"])")
            
            // _ = try Record.fetchOne(statement)
            try Row.fetchCursor(statement).forEach { row in
                XCTAssertEqual(
                    conversionErrorMessage(
                        to: Value.self,
                        from: row["value"],
                        conversionContext: ValueConversionContext(row).atColumn("value")),
                    "could not read \(Value.self) from missing column `value` (row: [unused:\"ignored\"], sql: `SELECT ? AS unused`, arguments: [\"ignored\"])")
            }
        }
    }
    
    func testDecodableFetchableRecord3() throws {
        enum Value: String, Decodable {
            case valid
        }
        
        struct Record: Decodable, FetchableRecord {
            var value: Value
        }
        
        let dbQueue = try makeDatabaseQueue()
        
        // conversion error
        try dbQueue.read { db in
            let statement = try db.makeSelectStatement(sql: "SELECT NULL AS name, ? AS value")
            statement.arguments = ["invalid"]
            let row = try Row.fetchOne(statement)!
            
            // TODO: this test is obsolete since 566f42e8d07e57a0d9c4aec452e3ad7ed15dd59b
            // _ = Record(row: row)
            XCTAssertEqual(
                conversionErrorMessage(
                    to: Value.self,
                    from: row["value"],
                    conversionContext: ValueConversionContext(row).atColumn("value")),
                "could not convert database value \"invalid\" to \(Value.self) (column: `value`, column index: 1, row: [name:NULL value:\"invalid\"])")
            
            // TODO: this test is obsolete since 566f42e8d07e57a0d9c4aec452e3ad7ed15dd59b
            // _ = try Record.fetchOne(statement)
            try Row.fetchCursor(statement).forEach { row in
                XCTAssertEqual(
                    conversionErrorMessage(
                        to: Value.self,
                        from: row["value"],
                        conversionContext: ValueConversionContext(row).atColumn("value")),
                    "could not convert database value \"invalid\" to \(Value.self) (column: `value`, column index: 1, row: [name:NULL value:\"invalid\"], sql: `SELECT NULL AS name, ? AS value`, arguments: [\"invalid\"])")
            }
        }
        
        // missing column
        try dbQueue.read { db in
            let statement = try db.makeSelectStatement(sql: "SELECT ? AS unused")
            statement.arguments = ["ignored"]
            let row = try Row.fetchOne(statement)!

            // _ = Record(row: row)
            XCTAssertEqual(
                conversionErrorMessage(
                    to: Value.self,
                    from: row["value"],
                    conversionContext: ValueConversionContext(row).atColumn("value")),
                "could not read \(Value.self) from missing column `value` (row: [unused:\"ignored\"])")
            
            // _ = try Record.fetchOne(statement)
            try Row.fetchCursor(statement).forEach { row in
                XCTAssertEqual(
                    conversionErrorMessage(
                        to: Value.self,
                        from: row["value"],
                        conversionContext: ValueConversionContext(row).atColumn("value")),
                    "could not read \(Value.self) from missing column `value` (row: [unused:\"ignored\"], sql: `SELECT ? AS unused`, arguments: [\"ignored\"])")
            }
        }
    }
    
    func testStatementColumnConvertible1() throws {
        // Those tests are tightly coupled to GRDB decoding code.
        // Each test comes with one or several commented crashing code snippets that trigger it.
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            let statement = try db.makeSelectStatement(sql: "SELECT NULL AS name, ? AS team")
            statement.arguments = ["invalid"]
            let row = try Row.fetchOne(statement)!
            
            // TODO: this test is obsolete since 566f42e8d07e57a0d9c4aec452e3ad7ed15dd59b
            // _ = try String.fetchAll(statement)
            try statement.makeCursor().forEach {
                XCTAssertEqual(
                    conversionErrorMessage(
                        to: String.self,
                        from: .null,
                        conversionContext: ValueConversionContext(statement).atColumn(0)),
                    "could not convert database value NULL to String (column: `name`, column index: 0, row: [name:NULL team:\"invalid\"], sql: `SELECT NULL AS name, ? AS team`, arguments: [\"invalid\"])")
            }
            
            // _ = row["name"] as String
            XCTAssertEqual(
                conversionErrorMessage(
                    to: String.self,
                    from: row["name"],
                    conversionContext: ValueConversionContext(row).atColumn("name")),
                "could not convert database value NULL to String (column: `name`, column index: 0, row: [name:NULL team:\"invalid\"])")
            
            // _ = row[0] as String
            XCTAssertEqual(
                conversionErrorMessage(
                    to: String.self,
                    from: row[0],
                    conversionContext: ValueConversionContext(row).atColumn(0)),
                "could not convert database value NULL to String (column: `name`, column index: 0, row: [name:NULL team:\"invalid\"])")
        }
    }
    
    func testStatementColumnConvertible2() throws {
        // Those tests are tightly coupled to GRDB decoding code.
        // Each test comes with one or several commented crashing code snippets that trigger it.
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            let statement = try db.makeSelectStatement(sql: "SELECT ? AS foo")
            statement.arguments = [1000]
            let row = try Row.fetchOne(statement)!
            
            // _ = try Row.fetchCursor(statement).map { $0["missing"] as Int8 }.next()
            try Row.fetchCursor(statement).forEach { row in
                XCTAssertEqual(
                    conversionErrorMessage(
                        to: Int8.self,
                        from: nil,
                        conversionContext: ValueConversionContext(row).atColumn("missing")),
                    "could not read Int8 from missing column `missing` (row: [foo:1000], sql: `SELECT ? AS foo`, arguments: [1000])")
            }
            
            // _ = try Int8.fetchAll(statement)
            try statement.makeCursor().forEach {
                let sqliteStatement = statement.sqliteStatement
                XCTAssertEqual(
                    conversionErrorMessage(
                        to: Int8.self,
                        from: DatabaseValue(sqliteStatement: sqliteStatement, index: 0),
                        conversionContext: ValueConversionContext(Row(sqliteStatement: sqliteStatement)).atColumn(0)),
                    "could not convert database value 1000 to Int8 (column: `foo`, column index: 0, row: [foo:1000], sql: `SELECT ? AS foo`)")
            }
            
            // _ = row["foo"] as Int8
            XCTAssertEqual(
                conversionErrorMessage(
                    to: Int8.self,
                    from: row["foo"],
                    conversionContext: ValueConversionContext(row).atColumn("foo")),
                "could not convert database value 1000 to Int8 (column: `foo`, column index: 0, row: [foo:1000])")
            
            // _ = row[0] as Int8
            XCTAssertEqual(
                conversionErrorMessage(
                    to: Int8.self,
                    from: row[0],
                    conversionContext: ValueConversionContext(row).atColumn(0)),
                "could not convert database value 1000 to Int8 (column: `foo`, column index: 0, row: [foo:1000])")
        }
    }
    
    func testDecodableDatabaseValueConvertible() throws {
        enum Value: String, DatabaseValueConvertible, Decodable {
            case valid
        }
        
        // Those tests are tightly coupled to GRDB decoding code.
        // Each test comes with one or several commented crashing code snippets that trigger it.
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            let statement = try db.makeSelectStatement(sql: "SELECT NULL AS name, ? AS team")
            statement.arguments = ["invalid"]
            let row = try Row.fetchOne(statement)!
            
            // _ = try Value.fetchAll(statement)
            try statement.makeCursor().forEach {
                XCTAssertEqual(
                    conversionErrorMessage(
                        to: Value.self,
                        from: DatabaseValue(sqliteStatement: statement.sqliteStatement, index: 0),
                        conversionContext: ValueConversionContext(statement).atColumn(0)),
                    "could not convert database value NULL to \(Value.self) (column: `name`, column index: 0, row: [name:NULL team:\"invalid\"], sql: `SELECT NULL AS name, ? AS team`, arguments: [\"invalid\"])")
            }
            
            // _ = try Value.fetchOne(statement, adapter: SuffixRowAdapter(fromIndex: 1))
            let adapter = SuffixRowAdapter(fromIndex: 1)
            let columnIndex = try adapter.baseColumnIndex(atIndex: 0, layout: statement)
            try statement.makeCursor().forEach { _ in
                XCTAssertEqual(
                    conversionErrorMessage(
                        to: Value.self,
                        from: DatabaseValue(sqliteStatement: statement.sqliteStatement, index: Int32(columnIndex)),
                        conversionContext: ValueConversionContext(statement).atColumn(columnIndex)),
                    "could not convert database value \"invalid\" to \(Value.self) (column: `team`, column index: 1, row: [name:NULL team:\"invalid\"], sql: `SELECT NULL AS name, ? AS team`, arguments: [\"invalid\"])")
            }
            
            // _ = row["name"] as Value
            XCTAssertEqual(
                conversionErrorMessage(
                    to: Value.self,
                    from: row["name"],
                    conversionContext: ValueConversionContext(row).atColumn("name")),
                "could not convert database value NULL to \(Value.self) (column: `name`, column index: 0, row: [name:NULL team:\"invalid\"])")
            
            // _ = row[0] as Value
            XCTAssertEqual(
                conversionErrorMessage(
                    to: Value.self,
                    from: row[0],
                    conversionContext: ValueConversionContext(row).atColumn(0)),
                "could not convert database value NULL to \(Value.self) (column: `name`, column index: 0, row: [name:NULL team:\"invalid\"])")
        }
    }
}

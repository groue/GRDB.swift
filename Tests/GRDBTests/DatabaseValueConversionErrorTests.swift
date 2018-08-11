import XCTest
#if GRDBCIPHER
    @testable import GRDBCipher
#elseif GRDBCUSTOMSQLITE
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
            let statement = try db.makeSelectStatement("SELECT ? AS name")
            statement.arguments = [nil]
            let row = try Row.fetchOne(statement)!
            
            // _ = Record(row: row)
            XCTAssertEqual(
                conversionErrorMessage(
                    to: String.self,
                    from: row["name"],
                    debugInfo: ValueConversionDebuggingInfo(.row(row), .columnName("name"))),
                "could not convert database value NULL to String (column: `name`, column index: 0, row: [name:NULL])")
            
            // _ = try Record.fetchOne(statement)
            try Row.fetchCursor(statement).forEach { row in
                XCTAssertEqual(
                    conversionErrorMessage(
                        to: String.self,
                        from: row["name"],
                        debugInfo: ValueConversionDebuggingInfo(.row(row), .columnName("name"))),
                    "could not convert database value NULL to String (column: `name`, column index: 0, row: [name:NULL], statement: `SELECT ? AS name`, arguments: [NULL])")
            }
        }
        
        // missing column
        try dbQueue.read { db in
            let statement = try db.makeSelectStatement("SELECT ? AS unused")
            statement.arguments = ["ignored"]
            let row = try Row.fetchOne(statement)!
            
            // _ = Record(row: row)
            XCTAssertEqual(
                conversionErrorMessage(
                    to: String.self,
                    from: row["name"],
                    debugInfo: ValueConversionDebuggingInfo(.row(row), .columnName("name"))),
                "could not read String from missing column `name` (row: [unused:\"ignored\"])")
            
            // _ = try Record.fetchOne(statement)
            try Row.fetchCursor(statement).forEach { row in
                XCTAssertEqual(
                    conversionErrorMessage(
                        to: String.self,
                        from: row["name"],
                        debugInfo: ValueConversionDebuggingInfo(.row(row), .columnName("name"))),
                    "could not read String from missing column `name` (row: [unused:\"ignored\"], statement: `SELECT ? AS unused`, arguments: [\"ignored\"])")
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
            let statement = try db.makeSelectStatement("SELECT 1, ? AS value")
            statement.arguments = ["invalid"]
            let row = try Row.fetchOne(statement)!
            
            // _ = Record(row: row)
            XCTAssertEqual(
                conversionErrorMessage(
                    to: Value.self,
                    from: row["value"],
                    debugInfo: ValueConversionDebuggingInfo(.row(row), .columnName("value"))),
                "could not convert database value \"invalid\" to \(Value.self) (column: `value`, column index: 1, row: [1:1 value:\"invalid\"])")
            
            // _ = try Record.fetchOne(statement)
            try Row.fetchCursor(statement).forEach { row in
                XCTAssertEqual(
                    conversionErrorMessage(
                        to: Value.self,
                        from: row["value"],
                        debugInfo: ValueConversionDebuggingInfo(.row(row), .columnName("value"))),
                    "could not convert database value \"invalid\" to \(Value.self) (column: `value`, column index: 1, row: [1:1 value:\"invalid\"], statement: `SELECT 1, ? AS value`, arguments: [\"invalid\"])")
            }
        }
        
        // missing column
        try dbQueue.read { db in
            let statement = try db.makeSelectStatement("SELECT ? AS unused")
            statement.arguments = ["ignored"]
            let row = try Row.fetchOne(statement)!
            
            // _ = Record(row: row)
            XCTAssertEqual(
                conversionErrorMessage(
                    to: Value.self,
                    from: row["value"],
                    debugInfo: ValueConversionDebuggingInfo(.row(row), .columnName("value"))),
                "could not read \(Value.self) from missing column `value` (row: [unused:\"ignored\"])")
            
            // _ = try Record.fetchOne(statement)
            try Row.fetchCursor(statement).forEach { row in
                XCTAssertEqual(
                    conversionErrorMessage(
                        to: Value.self,
                        from: row["value"],
                        debugInfo: ValueConversionDebuggingInfo(.row(row), .columnName("value"))),
                    "could not read \(Value.self) from missing column `value` (row: [unused:\"ignored\"], statement: `SELECT ? AS unused`, arguments: [\"ignored\"])")
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
            let statement = try db.makeSelectStatement("SELECT NULL AS name, ? AS team")
            statement.arguments = ["invalid"]
            let row = try Row.fetchOne(statement)!
            
            // _ = Record(row: row)
            XCTAssertEqual(
                conversionErrorMessage(
                    to: String.self,
                    from: row["name"],
                    debugInfo: ValueConversionDebuggingInfo(.row(row), .columnName("name"))),
                "could not convert database value NULL to String (column: `name`, column index: 0, row: [name:NULL team:\"invalid\"])")
            
            // _ = try Record.fetchOne(statement)
            try Row.fetchCursor(statement).forEach { row in
                XCTAssertEqual(
                    conversionErrorMessage(
                        to: String.self,
                        from: row["name"],
                        debugInfo: ValueConversionDebuggingInfo(.row(row), .columnName("name"))),
                    "could not convert database value NULL to String (column: `name`, column index: 0, row: [name:NULL team:\"invalid\"], statement: `SELECT NULL AS name, ? AS team`, arguments: [\"invalid\"])")
            }
        }
        
        // missing column
        try dbQueue.read { db in
            let statement = try db.makeSelectStatement("SELECT ? AS unused")
            statement.arguments = ["ignored"]
            let row = try Row.fetchOne(statement)!

            // _ = Record(row: row)
            XCTAssertEqual(
                conversionErrorMessage(
                    to: String.self,
                    from: row["name"],
                    debugInfo: ValueConversionDebuggingInfo(.row(row), .columnName("name"))),
                "could not read String from missing column `name` (row: [unused:\"ignored\"])")
            
            // _ = try Record.fetchOne(statement)
            try Row.fetchCursor(statement).forEach { row in
                XCTAssertEqual(
                    conversionErrorMessage(
                        to: String.self,
                        from: row["name"],
                        debugInfo: ValueConversionDebuggingInfo(.row(row), .columnName("name"))),
                    "could not read String from missing column `name` (row: [unused:\"ignored\"], statement: `SELECT ? AS unused`, arguments: [\"ignored\"])")
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
            let statement = try db.makeSelectStatement("SELECT NULL AS name, ? AS value")
            statement.arguments = ["invalid"]
            let row = try Row.fetchOne(statement)!
            
            // _ = Record(row: row)
            XCTAssertEqual(
                conversionErrorMessage(
                    to: Value.self,
                    from: row["value"],
                    debugInfo: ValueConversionDebuggingInfo(.row(row), .columnName("value"))),
                "could not convert database value \"invalid\" to \(Value.self) (column: `value`, column index: 1, row: [name:NULL value:\"invalid\"])")
            
            // _ = try Record.fetchOne(statement)
            try Row.fetchCursor(statement).forEach { row in
                XCTAssertEqual(
                    conversionErrorMessage(
                        to: Value.self,
                        from: row["value"],
                        debugInfo: ValueConversionDebuggingInfo(.row(row), .columnName("value"))),
                    "could not convert database value \"invalid\" to \(Value.self) (column: `value`, column index: 1, row: [name:NULL value:\"invalid\"], statement: `SELECT NULL AS name, ? AS value`, arguments: [\"invalid\"])")
            }
        }
        
        // missing column
        try dbQueue.read { db in
            let statement = try db.makeSelectStatement("SELECT ? AS unused")
            statement.arguments = ["ignored"]
            let row = try Row.fetchOne(statement)!

            // _ = Record(row: row)
            XCTAssertEqual(
                conversionErrorMessage(
                    to: Value.self,
                    from: row["value"],
                    debugInfo: ValueConversionDebuggingInfo(.row(row), .columnName("value"))),
                "could not read \(Value.self) from missing column `value` (row: [unused:\"ignored\"])")
            
            // _ = try Record.fetchOne(statement)
            try Row.fetchCursor(statement).forEach { row in
                XCTAssertEqual(
                    conversionErrorMessage(
                        to: Value.self,
                        from: row["value"],
                        debugInfo: ValueConversionDebuggingInfo(.row(row), .columnName("value"))),
                    "could not read \(Value.self) from missing column `value` (row: [unused:\"ignored\"], statement: `SELECT ? AS unused`, arguments: [\"ignored\"])")
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
            let statement = try db.makeSelectStatement("SELECT NULL AS name, ? AS value")
            statement.arguments = ["invalid"]
            let row = try Row.fetchOne(statement)!
            
            // _ = Record(row: row)
            XCTAssertEqual(
                conversionErrorMessage(
                    to: Value.self,
                    from: row["value"],
                    debugInfo: ValueConversionDebuggingInfo(.row(row), .columnName("value"))),
                "could not convert database value \"invalid\" to \(Value.self) (column: `value`, column index: 1, row: [name:NULL value:\"invalid\"])")
            
            // _ = try Record.fetchOne(statement)
            try Row.fetchCursor(statement).forEach { row in
                XCTAssertEqual(
                    conversionErrorMessage(
                        to: Value.self,
                        from: row["value"],
                        debugInfo: ValueConversionDebuggingInfo(.row(row), .columnName("value"))),
                    "could not convert database value \"invalid\" to \(Value.self) (column: `value`, column index: 1, row: [name:NULL value:\"invalid\"], statement: `SELECT NULL AS name, ? AS value`, arguments: [\"invalid\"])")
            }
        }
        
        // missing column
        try dbQueue.read { db in
            let statement = try db.makeSelectStatement("SELECT ? AS unused")
            statement.arguments = ["ignored"]
            let row = try Row.fetchOne(statement)!

            // _ = Record(row: row)
            XCTAssertEqual(
                conversionErrorMessage(
                    to: Value.self,
                    from: row["value"],
                    debugInfo: ValueConversionDebuggingInfo(.row(row), .columnName("value"))),
                "could not read \(Value.self) from missing column `value` (row: [unused:\"ignored\"])")
            
            // _ = try Record.fetchOne(statement)
            try Row.fetchCursor(statement).forEach { row in
                XCTAssertEqual(
                    conversionErrorMessage(
                        to: Value.self,
                        from: row["value"],
                        debugInfo: ValueConversionDebuggingInfo(.row(row), .columnName("value"))),
                    "could not read \(Value.self) from missing column `value` (row: [unused:\"ignored\"], statement: `SELECT ? AS unused`, arguments: [\"ignored\"])")
            }
        }
    }
    
    func testStatementColumnConvertible() throws {
        // Those tests are tightly coupled to GRDB decoding code.
        // Each test comes with one or several commented crashing code snippets that trigger it.
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            let statement = try db.makeSelectStatement("SELECT NULL AS name, ? AS team")
            statement.arguments = ["invalid"]
            let row = try Row.fetchOne(statement)!
            
            // _ = try String.fetchAll(statement)
            try statement.makeCursor().forEach {
                XCTAssertEqual(
                    conversionErrorMessage(
                        to: String.self,
                        from: .null,
                        debugInfo: ValueConversionDebuggingInfo(.statement(statement), .columnIndex(0))),
                    "could not convert database value NULL to String (column: `name`, column index: 0, row: [name:NULL team:\"invalid\"], statement: `SELECT NULL AS name, ? AS team`, arguments: [\"invalid\"])")
            }
            
            // _ = row["name"] as String
            XCTAssertEqual(
                conversionErrorMessage(
                    to: String.self,
                    from: row["name"],
                    debugInfo: ValueConversionDebuggingInfo(.row(row), .columnName("name"))),
                "could not convert database value NULL to String (column: `name`, column index: 0, row: [name:NULL team:\"invalid\"])")
            
            // _ = row[0] as String
            XCTAssertEqual(
                conversionErrorMessage(
                    to: String.self,
                    from: row[0],
                    debugInfo: ValueConversionDebuggingInfo(.row(row), .columnIndex(0))),
                "could not convert database value NULL to String (column: `name`, column index: 0, row: [name:NULL team:\"invalid\"])")
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
            let statement = try db.makeSelectStatement("SELECT NULL AS name, ? AS team")
            statement.arguments = ["invalid"]
            let row = try Row.fetchOne(statement)!
            
            // _ = try Value.fetchAll(statement)
            try statement.makeCursor().forEach {
                XCTAssertEqual(
                    conversionErrorMessage(
                        to: Value.self,
                        from: DatabaseValue(sqliteStatement: statement.sqliteStatement, index: 0),
                        debugInfo: ValueConversionDebuggingInfo(.statement(statement), .columnIndex(0))),
                    "could not convert database value NULL to \(Value.self) (column: `name`, column index: 0, row: [name:NULL team:\"invalid\"], statement: `SELECT NULL AS name, ? AS team`, arguments: [\"invalid\"])")
            }
            
            // _ = try Value.fetchOne(statement, adapter: SuffixRowAdapter(fromIndex: 1))
            let adapter = SuffixRowAdapter(fromIndex: 1)
            let columnIndex = try adapter.baseColumnIndex(atIndex: 0, layout: statement)
            try statement.makeCursor().forEach { _ in
                XCTAssertEqual(
                    conversionErrorMessage(
                        to: Value.self,
                        from: DatabaseValue(sqliteStatement: statement.sqliteStatement, index: Int32(columnIndex)),
                        debugInfo: ValueConversionDebuggingInfo(.statement(statement), .columnIndex(columnIndex))),
                    "could not convert database value \"invalid\" to \(Value.self) (column: `team`, column index: 1, row: [name:NULL team:\"invalid\"], statement: `SELECT NULL AS name, ? AS team`, arguments: [\"invalid\"])")
            }
            
            // _ = row["name"] as Value
            XCTAssertEqual(
                conversionErrorMessage(
                    to: Value.self,
                    from: row["name"],
                    debugInfo: ValueConversionDebuggingInfo(.row(row), .columnName("name"))),
                "could not convert database value NULL to \(Value.self) (column: `name`, column index: 0, row: [name:NULL team:\"invalid\"])")
            
            // _ = row[0] as Value
            XCTAssertEqual(
                conversionErrorMessage(
                    to: Value.self,
                    from: row[0],
                    debugInfo: ValueConversionDebuggingInfo(.row(row), .columnIndex(0))),
                "could not convert database value NULL to \(Value.self) (column: `name`, column index: 0, row: [name:NULL team:\"invalid\"])")
        }
    }
}

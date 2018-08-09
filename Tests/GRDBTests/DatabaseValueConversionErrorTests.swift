import XCTest
#if GRDBCIPHER
    @testable import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    @testable import GRDBCustomSQLite
#else
    @testable import GRDB
#endif

class DatabaseValueConversionErrorTests: GRDBTestCase {
    struct Record1: Codable, FetchableRecord {
        var name: String
        var team: String
    }
    
    struct Record2: FetchableRecord {
        var name: String
        var team: String
        
        init(row: Row) {
            name = row["name"]
            team = row["team"]
        }
    }
    
    struct Record3: Codable, FetchableRecord {
        var team: Value1
    }
    
    struct Record4: FetchableRecord {
        var team: Value1
        
        init(row: Row) {
            team = row["team"]
        }
    }
    
    enum Value1: String, DatabaseValueConvertible, Codable {
        case valid
    }
    
    func testConversionErrorMessage() throws {
        // Those tests are tightly coupled to GRDB decoding code.
        // Each test comes with a (commented) crashing code that triggers it.
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            let statement = try db.makeSelectStatement("SELECT NULL AS name, ? AS team")
            statement.arguments = ["invalid"]
            let row = try Row.fetchOne(statement)!
            
            // _ = Record1(row: row)
            XCTAssertEqual(
                conversionErrorMessage(
                    to: String.self,
                    from: row["name"],
                    debugInfo: ValueConversionDebuggingInfo(.row(row), .columnName("name"))),
                "could not convert database value NULL to String (column: `name`, column index: 0, row: [name:NULL team:\"invalid\"])")
            
            // _ = try Record1.fetchOne(statement)
            try Row.fetchCursor(statement).forEach { row in
                XCTAssertEqual(
                    conversionErrorMessage(
                        to: String.self,
                        from: row["name"],
                        debugInfo: ValueConversionDebuggingInfo(.row(row), .columnName("name"))),
                    "could not convert database value NULL to String (column: `name`, column index: 0, row: [name:NULL team:\"invalid\"], statement: `SELECT NULL AS name, ? AS team`, arguments: [\"invalid\"])")
            }
            
            // _ = Record2(row: row)
            XCTAssertEqual(
                conversionErrorMessage(
                    to: String.self,
                    from: row["name"],
                    debugInfo: ValueConversionDebuggingInfo(.row(row), .columnName("name"))),
                "could not convert database value NULL to String (column: `name`, column index: 0, row: [name:NULL team:\"invalid\"])")
            
            // _ = try Record2.fetchOne(statement)
            try Row.fetchCursor(statement).forEach { row in
                XCTAssertEqual(
                    conversionErrorMessage(
                        to: String.self,
                        from: row["name"],
                        debugInfo: ValueConversionDebuggingInfo(.row(row), .columnName("name"))),
                    "could not convert database value NULL to String (column: `name`, column index: 0, row: [name:NULL team:\"invalid\"], statement: `SELECT NULL AS name, ? AS team`, arguments: [\"invalid\"])")
            }
            
            // _ = Record3(row: row)
            XCTAssertEqual(
                conversionErrorMessage(
                    to: Value1.self,
                    from: row["team"],
                    debugInfo: ValueConversionDebuggingInfo(.row(row), .columnName("team"))),
                "could not convert database value \"invalid\" to Value1 (column: `team`, column index: 1, row: [name:NULL team:\"invalid\"])")
            
            // _ = try Record3.fetchOne(statement)
            try Row.fetchCursor(statement).forEach { row in
                XCTAssertEqual(
                    conversionErrorMessage(
                        to: Value1.self,
                        from: row["team"],
                        debugInfo: ValueConversionDebuggingInfo(.row(row), .columnName("team"))),
                    "could not convert database value \"invalid\" to Value1 (column: `team`, column index: 1, row: [name:NULL team:\"invalid\"], statement: `SELECT NULL AS name, ? AS team`, arguments: [\"invalid\"])")
            }
            
            // _ = Record4(row: row)
            XCTAssertEqual(
                conversionErrorMessage(
                    to: Value1.self,
                    from: row["team"],
                    debugInfo: ValueConversionDebuggingInfo(.row(row), .columnName("team"))),
                "could not convert database value \"invalid\" to Value1 (column: `team`, column index: 1, row: [name:NULL team:\"invalid\"])")
            
            // _ = try Record4.fetchOne(statement)
            try Row.fetchCursor(statement).forEach { row in
                XCTAssertEqual(
                    conversionErrorMessage(
                        to: Value1.self,
                        from: row["team"],
                        debugInfo: ValueConversionDebuggingInfo(.row(row), .columnName("team"))),
                    "could not convert database value \"invalid\" to Value1 (column: `team`, column index: 1, row: [name:NULL team:\"invalid\"], statement: `SELECT NULL AS name, ? AS team`, arguments: [\"invalid\"])")
            }
            
            // _ = try String.fetchAll(statement)
            try statement.makeCursor().forEach {
                XCTAssertEqual(
                    conversionErrorMessage(
                        to: String.self,
                        from: .null,
                        debugInfo: ValueConversionDebuggingInfo(.statement(statement), .columnIndex(0))),
                    "could not convert database value NULL to String (column: `name`, column index: 0, row: [name:NULL team:\"invalid\"], statement: `SELECT NULL AS name, ? AS team`, arguments: [\"invalid\"])")
            }
            
//            // could not convert database value NULL to String (column: `name`, column index: 0, row: [name:NULL team:"invalid"])
//            _ = row["name"] as String
//
//            // could not convert database value NULL to String (column: `name`, column index: 0, row: [name:NULL team:"invalid"])
//            _ = row[0] as String
//
//            // could not convert database value NULL to Value1 (column: `name`, column index: 0, row: [name:NULL team:"invalid"], statement: `SELECT NULL AS name, ? AS team`, arguments: ["invalid"])
//            _ = try Value1.fetchAll(statement)
//
//            // could not convert database value "invalid" to Value1 (column: `team`, column index: 1, row: [name:NULL team:"invalid"], statement: `SELECT NULL AS name, ? AS team`, arguments: ["invalid"])
//            _ = try Value1.fetchOne(statement, adapter: SuffixRowAdapter(fromIndex: 1))
//
//            // could not convert database value NULL to Value1 (column: `name`, column index: 0, row: [name:NULL team:"invalid"])
//            _ = row["name"] as Value1
//
//            // could not convert database value NULL to Value1 (column: `name`, column index: 0, row: [name:NULL team:"invalid"])
//            _ = row[0] as Value1
        }
    }
}

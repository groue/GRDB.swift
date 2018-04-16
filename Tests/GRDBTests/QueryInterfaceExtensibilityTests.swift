import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

// Tests for sample code in Documentation/ExtendingGRDB.md

// STRFTIME

extension SQLFunctionName {
    /// The `STRFTIME` SQL function
    static let strftime = SQLFunctionName("STRFTIME")
}

/// Returns an expression that evaluates the `STRFTIME` SQL function.
///
///     // STRFTIME('%Y', date)
///     strftime("%Y", Column("date"))
func strftime(_ format: String, _ date: SQLSpecificExpressible) -> SQLExpression {
    return SQLExpressionFunction(.strftime, arguments: format, date)
}


// MATCH

extension SQLBinaryOperator {
    /// The `MATCH` binary operator
    static let match = SQLBinaryOperator("MATCH")
}

func ~= (_ lhs: SQLExpressible, _ rhs: Column) -> SQLExpression {
    return SQLExpressionBinary(.match, rhs, lhs)
}


// CAST

func cast(_ value: SQLExpressible, as type: Database.ColumnType) -> SQLExpression {
    // Turn the value into a literal expression
    let literal: SQLExpressionLiteral = value.sqlExpression.literal
    
    // Build our "CAST(value AS type)" sql snippet
    let sql = "CAST(\(literal.sql) AS \(type.rawValue))"
    
    // And return a new literal expression, preserving input arguments
    return SQLExpressionLiteral(sql, arguments: literal.arguments)
}



class QueryInterfaceExtensibilityTests: GRDBTestCase {
    
    func testStrftime() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "records") { t in
                t.column("date", .datetime)
            }
            struct Record : TableRecord {
                static let databaseTableName = "records"
            }
            
            let date = Date(timeIntervalSince1970: 0)
            try db.execute("INSERT INTO records (date) VALUES (?)", arguments: [date])
            
            let request = Record.select(strftime("%Y", Column("date")))
            let year = try Int.fetchOne(db, request)
            XCTAssertEqual(year, 1970)
            XCTAssertEqual(self.lastSQLQuery, "SELECT STRFTIME('%Y', \"date\") FROM \"records\"")
        }
    }

    func testMatch() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute("CREATE VIRTUAL TABLE records USING fts3(content TEXT)")
            struct Record : TableRecord {
                static let databaseTableName = "records"
            }
            
            try db.execute("INSERT INTO records (content) VALUES (?)", arguments: ["foo"])
            try db.execute("INSERT INTO records (content) VALUES (?)", arguments: ["foo bar"])
            try db.execute("INSERT INTO records (content) VALUES (?)", arguments: ["bar"])
            
            let request = Record.filter("foo" ~= Column("content"))
            let count = try request.fetchCount(db)
            XCTAssertEqual(count, 2)
        }
    }

    func testCast() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "records") { t in
                t.column("text", .text)
            }
            struct Record : TableRecord {
                static let databaseTableName = "records"
            }
            
            try db.execute("INSERT INTO records (text) VALUES (?)", arguments: ["foo"])
            
            let request = Record.select(cast(Column("text"), as: .blob))
            let dbValue = try DatabaseValue.fetchOne(db, request)!
            switch dbValue.storage {
            case .blob:
                break
            default:
                XCTFail("Expected data blob")
            }
            XCTAssertEqual(self.lastSQLQuery, "SELECT (CAST(\"text\" AS BLOB)) FROM \"records\"")
        }
    }
}

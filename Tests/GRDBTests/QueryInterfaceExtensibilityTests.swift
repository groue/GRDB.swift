import XCTest
#if GRDBCUSTOMSQLITE
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

private func castDeprecated(_ value: SQLExpressible, as type: Database.ColumnType) -> SQLExpression {
    let literal = value.sqlExpression.sqlLiteral
    let castLiteral = literal.mapSQL { sql in
        "CAST(\(sql) AS \(type.rawValue))"
    }
    return SQLExpressionLiteral(literal: castLiteral)
}

private func cast(_ value: SQLExpressible, as type: Database.ColumnType) -> SQLExpression {
    return SQLLiteral(value.sqlExpression)
        .mapSQL({ sql in "CAST(\(sql) AS \(type.rawValue))" })
        .sqlExpression
}

#if swift(>=5.0)
private func castInterpolated<T: SQLExpressible>(_ value: T, as type: Database.ColumnType) -> SQLExpression {
    return SQLLiteral("CAST(\(value) AS \(sql: type.rawValue))").sqlExpression
}
#endif


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
            try db.execute(sql: "INSERT INTO records (date) VALUES (?)", arguments: [date])
            
            let request = Record.select(strftime("%Y", Column("date")))
            let year = try Int.fetchOne(db, request)
            XCTAssertEqual(year, 1970)
            XCTAssertEqual(self.lastSQLQuery, "SELECT STRFTIME('%Y', \"date\") FROM \"records\" LIMIT 1")
        }
    }

    func testMatch() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE VIRTUAL TABLE records USING fts3(content TEXT)")
            struct Record : TableRecord {
                static let databaseTableName = "records"
            }
            
            try db.execute(sql: "INSERT INTO records (content) VALUES (?)", arguments: ["foo"])
            try db.execute(sql: "INSERT INTO records (content) VALUES (?)", arguments: ["foo bar"])
            try db.execute(sql: "INSERT INTO records (content) VALUES (?)", arguments: ["bar"])
            
            let request = Record.filter("foo" ~= Column("content"))
            let count = try request.fetchCount(db)
            XCTAssertEqual(count, 2)
        }
    }

    func testCastDeprecated() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "records") { t in
                t.column("text", .text)
            }
            struct Record : TableRecord {
                static let databaseTableName = "records"
            }
            
            try db.execute(sql: "INSERT INTO records (text) VALUES (?)", arguments: ["foo"])
            
            do {
                let request = Record.select(castDeprecated(Column("text"), as: .blob))
                let dbValue = try DatabaseValue.fetchOne(db, request)!
                switch dbValue.storage {
                case .blob:
                    break
                default:
                    XCTFail("Expected data blob")
                }
                XCTAssertEqual(self.lastSQLQuery, "SELECT CAST(\"text\" AS BLOB) FROM \"records\" LIMIT 1")
            }
            do {
                let request = Record.select(castDeprecated(Column("text"), as: .blob) && true)
                _ = try DatabaseValue.fetchOne(db, request)!
                XCTAssertEqual(self.lastSQLQuery, "SELECT (CAST(\"text\" AS BLOB)) AND 1 FROM \"records\" LIMIT 1")
            }
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
            
            try db.execute(sql: "INSERT INTO records (text) VALUES (?)", arguments: ["foo"])
            
            do {
                let request = Record.select(cast(Column("text"), as: .blob))
                let dbValue = try DatabaseValue.fetchOne(db, request)!
                switch dbValue.storage {
                case .blob:
                    break
                default:
                    XCTFail("Expected data blob")
                }
                XCTAssertEqual(self.lastSQLQuery, "SELECT CAST(\"text\" AS BLOB) FROM \"records\" LIMIT 1")
            }
            do {
                let request = Record.select(cast(Column("text"), as: .blob) && true)
                _ = try DatabaseValue.fetchOne(db, request)!
                XCTAssertEqual(self.lastSQLQuery, "SELECT (CAST(\"text\" AS BLOB)) AND 1 FROM \"records\" LIMIT 1")
            }
        }
    }
    
    #if swift(>=5.0)
    func testCastInterpolated() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "records") { t in
                t.column("text", .text)
            }
            struct Record : TableRecord {
                static let databaseTableName = "records"
            }
            
            try db.execute(sql: "INSERT INTO records (text) VALUES (?)", arguments: ["foo"])
            
            do {
                let request = Record.select(castInterpolated(Column("text"), as: .blob))
                let dbValue = try DatabaseValue.fetchOne(db, request)!
                switch dbValue.storage {
                case .blob:
                    break
                default:
                    XCTFail("Expected data blob")
                }
                XCTAssertEqual(self.lastSQLQuery, "SELECT CAST(\"text\" AS BLOB) FROM \"records\" LIMIT 1")
            }
            do {
                let request = Record.select(castInterpolated(Column("text"), as: .blob) && true)
                _ = try DatabaseValue.fetchOne(db, request)!
                XCTAssertEqual(self.lastSQLQuery, "SELECT (CAST(\"text\" AS BLOB)) AND 1 FROM \"records\" LIMIT 1")
            }
        }
    }
    #endif
}

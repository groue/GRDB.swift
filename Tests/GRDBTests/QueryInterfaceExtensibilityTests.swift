import XCTest
import GRDB

private func myCast<T: SQLExpressible>(_ value: T, as type: Database.ColumnType) -> SQLExpression {
    SQL("CAST(\(value) AS \(sql: type.rawValue))").sqlExpression
}

class QueryInterfaceExtensibilityTests: GRDBTestCase {
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
                let request = Record.select(myCast(Column("text"), as: .blob))
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
                let request = Record.select(myCast(Column("text"), as: .blob) && true)
                _ = try DatabaseValue.fetchOne(db, request)!
                XCTAssertEqual(self.lastSQLQuery, "SELECT (CAST(\"text\" AS BLOB)) AND 1 FROM \"records\" LIMIT 1")
            }
        }
    }
}

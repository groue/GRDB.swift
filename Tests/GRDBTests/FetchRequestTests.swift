import XCTest
import GRDB

class FetchRequestTests: GRDBTestCase {
    func testRequestFetchCount() throws {
        let request: SQLRequest<Int> = "SELECT * FROM table1"
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "table1") { t in
                t.column("id", .integer).primaryKey()
            }
            try db.execute(sql: "INSERT INTO table1 DEFAULT VALUES")
            try db.execute(sql: "INSERT INTO table1 DEFAULT VALUES")
            
            let count = try request.fetchCount(db)
            XCTAssertEqual(lastSQLQuery, "SELECT COUNT(*) FROM (SELECT * FROM table1)")
            XCTAssertEqual(count, 2)
        }
    }
    
    func testRequestAsSQLExpression() throws {
        let request: SQLRequest<Int> = "SELECT id FROM table1"
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "table1") { t in
                t.column("id", .integer).primaryKey()
            }
            
            let derivedExpression = request > 0
            let sqlRequest: SQLRequest<Row> = "SELECT \(derivedExpression)"
            let statement = try sqlRequest.makePreparedRequest(db, forSingleResult: false).statement
            XCTAssertEqual(statement.sql, "SELECT (SELECT id FROM table1) > ?")
        }
    }
    
    func testRequestAsSQLCollection() throws {
        let request: SQLRequest<Int> = "SELECT id FROM table1"
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "table1") { t in
                t.column("id", .integer).primaryKey()
            }
            
            do {
                let derivedExpression = request.contains(0)
                let sqlRequest: SQLRequest<Row> = "SELECT \(derivedExpression)"
                let statement = try sqlRequest.makePreparedRequest(db, forSingleResult: false).statement
                XCTAssertEqual(statement.sql, "SELECT ? IN (SELECT id FROM table1)")
            }
            
            do {
                let derivedExpression = request.contains("arthur".databaseValue.collating(.nocase))
                let sqlRequest: SQLRequest<Row> = "SELECT \(derivedExpression)"
                let statement = try sqlRequest.makePreparedRequest(db, forSingleResult: false).statement
                XCTAssertEqual(statement.sql, "SELECT (? COLLATE NOCASE) IN (SELECT id FROM table1)")
            }
        }
    }
    
    func testRequestInterpolation() throws {
        let request: SQLRequest<Int> = "SELECT id FROM table1"
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "table1") { t in
                t.column("id", .integer).primaryKey()
            }
            
            let sqlRequest: SQLRequest<Row> = "SELECT * FROM (\(request))"
            let statement = try sqlRequest.makePreparedRequest(db, forSingleResult: false).statement
            XCTAssertEqual(statement.sql, "SELECT * FROM (SELECT id FROM table1)")
        }
    }
}

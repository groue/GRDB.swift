import XCTest
import GRDB

class TransactionDateTests: GRDBTestCase {
    func testTransactionDateOutsideOfTransaction() throws {
        let dates = [
            Date.distantPast,
            Date(),
            Date.distantFuture,
        ]
        var dateIterator = dates.makeIterator()
        dbConfiguration.transactionClock = .custom { _ in
            dateIterator.next()!
        }
        
        var collectedDates: [Date] = []
        try makeDatabaseQueue().inDatabase { db in
            try collectedDates.append(db.transactionDate)
            try collectedDates.append(db.transactionDate)
            try collectedDates.append(db.transactionDate)
        }
        XCTAssertEqual(collectedDates, dates)
    }
    
    func testTransactionDateInsideTransaction_commit() throws {
        let dates = [
            Date.distantPast,
            Date(),
            Date.distantFuture,
        ]
        var dateIterator = dates.makeIterator()
        dbConfiguration.transactionClock = .custom { _ in
            dateIterator.next()!
        }
        
        var collectedDates: [Date] = []
        try makeDatabaseQueue().inDatabase { db in
            try collectedDates.append(db.transactionDate)
            try db.execute(sql: "BEGIN")
            try collectedDates.append(db.transactionDate)
            try collectedDates.append(db.transactionDate)
            try db.execute(sql: "COMMIT")
            try collectedDates.append(db.transactionDate)
        }
        XCTAssertEqual(collectedDates, [dates[0], dates[1], dates[1], dates[2]])
    }
    
    func testTransactionDateInsideTransaction_rollback() throws {
        let dates = [
            Date.distantPast,
            Date(),
            Date.distantFuture,
        ]
        var dateIterator = dates.makeIterator()
        dbConfiguration.transactionClock = .custom { _ in
            dateIterator.next()!
        }
        
        var collectedDates: [Date] = []
        try makeDatabaseQueue().inDatabase { db in
            try collectedDates.append(db.transactionDate)
            try db.execute(sql: "BEGIN")
            try collectedDates.append(db.transactionDate)
            try collectedDates.append(db.transactionDate)
            try db.execute(sql: "ROLLBACK")
            try collectedDates.append(db.transactionDate)
        }
        XCTAssertEqual(collectedDates, [dates[0], dates[1], dates[1], dates[2]])
    }
    
    func testTransactionDateInsideTransaction_rollbackingError() throws {
        let dates = [
            Date.distantPast,
            Date(),
            Date.distantFuture,
        ]
        var dateIterator = dates.makeIterator()
        dbConfiguration.transactionClock = .custom { _ in
            dateIterator.next()!
        }
        
        var collectedDates: [Date] = []
        try makeDatabaseQueue().inDatabase { db in
            try collectedDates.append(db.transactionDate)
            try db.execute(sql: "BEGIN")
            try collectedDates.append(db.transactionDate)
            try collectedDates.append(db.transactionDate)
            try? db.execute(sql: """
                CREATE TABLE t(id INTEGER PRIMARY KEY ON CONFLICT ROLLBACK);
                INSERT INTO t VALUES (1);
                INSERT INTO t VALUES (1); -- fails and rollbacks
                """)
            try collectedDates.append(db.transactionDate)
        }
        XCTAssertEqual(collectedDates, [dates[0], dates[1], dates[1], dates[2]])
    }
}

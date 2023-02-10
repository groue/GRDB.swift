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
    
    func testTransactionDateInsideTransaction() throws {
        let dates = [
            Date.distantPast,
            Date(timeIntervalSince1970: 0),
            Date(timeIntervalSinceReferenceDate: 0),
            Date(),
            Date.distantPast,
            Date.distantFuture,
        ]
        var dateIterator = dates.makeIterator()
        dbConfiguration.transactionClock = .custom { _ in
            dateIterator.next()!
        }
        
        try makeDatabaseQueue().inDatabase { db in
            do {
                // Dates are constant within a transaction block
                var collectedDates: [Date] = []
                try db.inTransaction {
                    try collectedDates.append(db.transactionDate)
                    try collectedDates.append(db.transactionDate)
                    return .commit
                }
                XCTAssertEqual(collectedDates, [dates[0], dates[0]])
            }
            
            do {
                // Dates are no longer constant when transaction has completed
                try XCTAssertEqual(db.transactionDate, dates[1])
            }
            
            do {
                // Dates are constant within a transaction
                var collectedDates: [Date] = []
                try db.beginTransaction()
                try collectedDates.append(db.transactionDate)
                try collectedDates.append(db.transactionDate)
                try db.rollback()
                XCTAssertEqual(collectedDates, [dates[2], dates[2]])
            }

            do {
                // Dates are no longer constant when transaction has completed
                try XCTAssertEqual(db.transactionDate, dates[3])
            }

            do {
                // Dates are constant within a transaction
                var collectedDates: [Date] = []
                try db.execute(sql: "BEGIN")
                try collectedDates.append(db.transactionDate)
                try collectedDates.append(db.transactionDate)
                try db.execute(sql: "COMMIT")
                XCTAssertEqual(collectedDates, [dates[4], dates[4]])
            }

            do {
                // Dates are no longer constant when transaction has completed
                try XCTAssertEqual(db.transactionDate, dates[5])
            }
        }
    }
}


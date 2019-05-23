import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class DatabaseAfterNextTransactionCommitTests: GRDBTestCase {
    
    func testTransactionCompletions() throws {
        // implicit transaction
        try assertTransaction(start: "", end: "CREATE TABLE t(a)", isNotifiedAs: .commit)
        
        // explicit commit
        try assertTransaction(start: "BEGIN DEFERRED TRANSACTION", end: "COMMIT", isNotifiedAs: .commit)
        try assertTransaction(start: "BEGIN DEFERRED TRANSACTION; CREATE TABLE t(a)", end: "COMMIT", isNotifiedAs: .commit)
        try assertTransaction(start: "BEGIN IMMEDIATE TRANSACTION", end: "COMMIT", isNotifiedAs: .commit)
        try assertTransaction(start: "BEGIN IMMEDIATE TRANSACTION; CREATE TABLE t(a)", end: "COMMIT", isNotifiedAs: .commit)
        try assertTransaction(start: "BEGIN EXCLUSIVE TRANSACTION", end: "COMMIT", isNotifiedAs: .commit)
        try assertTransaction(start: "BEGIN EXCLUSIVE TRANSACTION; CREATE TABLE t(a)", end: "COMMIT", isNotifiedAs: .commit)
        try assertTransaction(start: "SAVEPOINT test", end: "COMMIT", isNotifiedAs: .commit)
        try assertTransaction(start: "SAVEPOINT test; CREATE TABLE t(a)", end: "COMMIT", isNotifiedAs: .commit)
        try assertTransaction(start: "SAVEPOINT test; ROLLBACK TRANSACTION TO SAVEPOINT test", end: "RELEASE SAVEPOINT test", isNotifiedAs: .commit)
        try assertTransaction(start: "SAVEPOINT test; CREATE TABLE t(a); ROLLBACK TRANSACTION TO SAVEPOINT test", end: "RELEASE SAVEPOINT test", isNotifiedAs: .commit)
        try assertTransaction(start: "SAVEPOINT test", end: "RELEASE SAVEPOINT test", isNotifiedAs: .commit)
        try assertTransaction(start: "SAVEPOINT test; CREATE TABLE t(a)", end: "RELEASE SAVEPOINT test", isNotifiedAs: .commit)
        
        // explicit rollback
        try assertTransaction(start: "BEGIN DEFERRED TRANSACTION", end: "ROLLBACK", isNotifiedAs: .rollback)
        try assertTransaction(start: "BEGIN DEFERRED TRANSACTION; CREATE TABLE t(a)", end: "ROLLBACK", isNotifiedAs: .rollback)
        try assertTransaction(start: "BEGIN IMMEDIATE TRANSACTION", end: "ROLLBACK", isNotifiedAs: .rollback)
        try assertTransaction(start: "BEGIN IMMEDIATE TRANSACTION; CREATE TABLE t(a)", end: "ROLLBACK", isNotifiedAs: .rollback)
        try assertTransaction(start: "BEGIN EXCLUSIVE TRANSACTION", end: "ROLLBACK", isNotifiedAs: .rollback)
        try assertTransaction(start: "BEGIN EXCLUSIVE TRANSACTION; CREATE TABLE t(a)", end: "ROLLBACK", isNotifiedAs: .rollback)
        try assertTransaction(start: "SAVEPOINT test", end: "ROLLBACK", isNotifiedAs: .rollback)
        try assertTransaction(start: "SAVEPOINT test; CREATE TABLE t(a)", end: "ROLLBACK", isNotifiedAs: .rollback)
    }
    
    func assertTransaction(start startSQL: String, end endSQL: String, isNotifiedAs expectedCompletion: Database.TransactionCompletion) throws {
        try assertTransaction_registerBefore(start: startSQL, end: endSQL, isNotifiedAs: expectedCompletion)
        try assertTransaction_registerBetween(start: startSQL, end: endSQL, isNotifiedAs: expectedCompletion)
    }
    
    func assertTransaction_registerBefore(start startSQL: String, end endSQL: String, isNotifiedAs expectedCompletion: Database.TransactionCompletion) throws {
        class Witness { }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.writeWithoutTransaction { db in
            var transactionCount = 0
            weak var deallocationWitness: Witness? = nil
            do {
                let witness = Witness()
                deallocationWitness = witness
                db.afterNextTransactionCommit { _ in
                    // use witness
                    withExtendedLifetime(witness, { })
                    transactionCount += 1
                }
            }
            
            XCTAssertNotNil(deallocationWitness)
            XCTAssertEqual(transactionCount, 0)
            try db.execute(sql: startSQL)
            try db.execute(sql: endSQL)
            switch expectedCompletion {
            case .commit:
                XCTAssertEqual(transactionCount, 1, "\(startSQL); \(endSQL)")
            case .rollback:
                XCTAssertEqual(transactionCount, 0, "\(startSQL); \(endSQL)")
            }
            XCTAssertNil(deallocationWitness)
            
            try db.inTransaction {
                try db.execute(sql: "DROP TABLE IF EXISTS t; CREATE TABLE t(a); ")
                return .commit
            }
            switch expectedCompletion {
            case .commit:
                XCTAssertEqual(transactionCount, 1, "\(startSQL); \(endSQL)")
            case .rollback:
                XCTAssertEqual(transactionCount, 0, "\(startSQL); \(endSQL)")
            }
        }
    }
    
    func assertTransaction_registerBetween(start startSQL: String, end endSQL: String, isNotifiedAs expectedCompletion: Database.TransactionCompletion) throws {
        class Witness { }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.writeWithoutTransaction { db in
            var transactionCount = 0
            try db.execute(sql: startSQL)
            
            weak var deallocationWitness: Witness? = nil
            do {
                let witness = Witness()
                deallocationWitness = witness
                db.afterNextTransactionCommit { _ in
                    // use witness
                    withExtendedLifetime(witness, { })
                    transactionCount += 1
                }
            }
            
            XCTAssertNotNil(deallocationWitness)
            XCTAssertEqual(transactionCount, 0)
            try db.execute(sql: endSQL)
            switch expectedCompletion {
            case .commit:
                XCTAssertEqual(transactionCount, 1, "\(startSQL); \(endSQL)")
            case .rollback:
                XCTAssertEqual(transactionCount, 0, "\(startSQL); \(endSQL)")
            }
            XCTAssertNil(deallocationWitness)
            
            try db.inTransaction {
                try db.execute(sql: "DROP TABLE IF EXISTS t; CREATE TABLE t(a); ")
                return .commit
            }
            switch expectedCompletion {
            case .commit:
                XCTAssertEqual(transactionCount, 1, "\(startSQL); \(endSQL)")
            case .rollback:
                XCTAssertEqual(transactionCount, 0, "\(startSQL); \(endSQL)")
            }
        }
    }
}

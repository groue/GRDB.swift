import XCTest
import GRDB

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
            var commitCount = 0
            weak var deallocationWitness: Witness? = nil
            do {
                let witness = Witness()
                deallocationWitness = witness
                // Usage test: single closure (the onCommit one)
                db.afterNextTransaction { _ in
                    // use witness
                    withExtendedLifetime(witness, { })
                    commitCount += 1
                }
            }
            
            XCTAssertNotNil(deallocationWitness)
            XCTAssertEqual(commitCount, 0)
            try db.execute(sql: startSQL)
            try db.execute(sql: endSQL)
            switch expectedCompletion {
            case .commit:
                XCTAssertEqual(commitCount, 1, "\(startSQL); \(endSQL)")
            case .rollback:
                XCTAssertEqual(commitCount, 0, "\(startSQL); \(endSQL)")
            }
            XCTAssertNil(deallocationWitness)
            
            try db.inTransaction {
                try db.execute(sql: "DROP TABLE IF EXISTS t; CREATE TABLE t(a); ")
                return .commit
            }
            switch expectedCompletion {
            case .commit:
                XCTAssertEqual(commitCount, 1, "\(startSQL); \(endSQL)")
            case .rollback:
                XCTAssertEqual(commitCount, 0, "\(startSQL); \(endSQL)")
            }
        }
    }
    
    func assertTransaction_registerBetween(start startSQL: String, end endSQL: String, isNotifiedAs expectedCompletion: Database.TransactionCompletion) throws {
        class Witness { }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.writeWithoutTransaction { db in
            var commitCount = 0
            var rollbackCount = 0
            try db.execute(sql: startSQL)
            
            weak var deallocationWitness: Witness? = nil
            do {
                let witness = Witness()
                deallocationWitness = witness
                // Usage test: both closure
                db.afterNextTransaction(
                    onCommit: { _ in
                        // use witness
                        withExtendedLifetime(witness, { })
                        commitCount += 1
                    },
                    onRollback: { _ in
                        // use witness
                        withExtendedLifetime(witness, { })
                        rollbackCount += 1
                    })
            }
            
            XCTAssertNotNil(deallocationWitness)
            XCTAssertEqual(commitCount, 0)
            try db.execute(sql: endSQL)
            switch expectedCompletion {
            case .commit:
                XCTAssertEqual(commitCount, 1, "\(startSQL); \(endSQL)")
                XCTAssertEqual(rollbackCount, 0, "\(startSQL); \(endSQL)")
            case .rollback:
                XCTAssertEqual(commitCount, 0, "\(startSQL); \(endSQL)")
                XCTAssertEqual(rollbackCount, 1, "\(startSQL); \(endSQL)")
            }
            XCTAssertNil(deallocationWitness)
            
            try db.inTransaction {
                try db.execute(sql: "DROP TABLE IF EXISTS t; CREATE TABLE t(a); ")
                return .commit
            }
            switch expectedCompletion {
            case .commit:
                XCTAssertEqual(commitCount, 1, "\(startSQL); \(endSQL)")
                XCTAssertEqual(rollbackCount, 0, "\(startSQL); \(endSQL)")
            case .rollback:
                XCTAssertEqual(commitCount, 0, "\(startSQL); \(endSQL)")
                XCTAssertEqual(rollbackCount, 1, "\(startSQL); \(endSQL)")
            }
        }
    }
}

import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class DatabaseAfterCommitTests: GRDBTestCase {
    
    func testDatabaseAfterCommit() throws {
        class Witness { }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var transactionCount = 0
            weak var deallocationWitness: Witness? = nil
            do {
                let witness = Witness()
                deallocationWitness = witness
                db.afterCommit {
                    // use witness
                    withExtendedLifetime(witness, { })
                    transactionCount += 1
                }
            }
            
            XCTAssertEqual(transactionCount, 0)
            
            try db.inTransaction { .commit }
            XCTAssertEqual(transactionCount, 1)
            XCTAssertNil(deallocationWitness)
            
            try db.inTransaction { .commit }
            XCTAssertEqual(transactionCount, 1)
        }
    }
    
    func testDatabaseAfterCommitWithRollback() throws {
        class Witness { }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var transactionCount = 0
            weak var deallocationWitness: Witness? = nil
            do {
                let witness = Witness()
                deallocationWitness = witness
                db.afterCommit {
                    // use witness
                    withExtendedLifetime(witness, { })
                    transactionCount += 1
                }
            }
            
            XCTAssertEqual(transactionCount, 0)
            
            try db.inTransaction { .rollback }
            XCTAssertEqual(transactionCount, 0)
            XCTAssertNil(deallocationWitness)
            
            try db.inTransaction { .commit }
            XCTAssertEqual(transactionCount, 0)
        }
    }
}

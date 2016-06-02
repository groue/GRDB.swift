import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class StatementColumnConvertibleCrashTests: GRDBCrashTestCase {
    
    func testCrashFetchStatementColumnConvertibleFromStatement() {
        assertCrash("could not convert NULL to Int.") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                
                let statement = try db.makeSelectStatement("SELECT int FROM ints ORDER BY int")
                let sequence = Int.fetch(statement)
                for _ in sequence { }
            }
        }
    }
    
    func testCrashFetchAllStatementColumnConvertibleFromStatement() {
        assertCrash("could not convert NULL to Int.") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                
                let statement = try db.makeSelectStatement("SELECT int FROM ints ORDER BY int")
                _ = Int.fetchAll(statement)
            }
        }
    }
    
    func testCrashFetchStatementColumnConvertibleFromDatabase() {
        assertCrash("could not convert NULL to Int.") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                
                let sequence = Int.fetch(db, "SELECT int FROM ints ORDER BY int")
                for _ in sequence { }
            }
        }
    }
    
    func testCrashFetchAllStatementColumnConvertibleFromDatabase() {
        assertCrash("could not convert NULL to Int.") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                
                _ = Int.fetchAll(db, "SELECT int FROM ints ORDER BY int")
            }
        }
    }
    
}

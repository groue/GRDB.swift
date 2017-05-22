import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
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
                let sequence = try Int.fetch(statement)
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
                _ = try Int.fetchAll(statement)
            }
        }
    }
    
    func testCrashFetchStatementColumnConvertibleFromDatabase() {
        assertCrash("could not convert NULL to Int.") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                
                let sequence = try Int.fetch(db, "SELECT int FROM ints ORDER BY int")
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
                
                _ = try Int.fetchAll(db, "SELECT int FROM ints ORDER BY int")
            }
        }
    }
    
}

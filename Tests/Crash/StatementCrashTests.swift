import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class StatementCrashTests: GRDBCrashTestCase {
    
    func testInvalidStatementArguments() {
        assertCrash("SQLite error 1 with statement `INSERT INTO persons (name, age) VALUES (:name, :age)`: missing statement argument(s): age") {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE persons (name TEXT, age INT)")
                try! db.execute(sql: "INSERT INTO persons (name, age) VALUES (:name, :age)", arguments: ["name": "Arthur"])
            }
        }
        
        assertCrash("SQLite error 21 with statement `INSERT INTO persons (name, age) VALUES ('Arthur', ?);`: wrong number of statement arguments: 0") {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE persons (name TEXT, age INT)")
                try db.execute(sql: """
                    INSERT INTO persons (name, age) VALUES ('Arthur', ?);
                    INSERT INTO persons (name, age) VALUES ('Barbara', ?);
                    """)
            }
        }
        
        assertCrash("SQLite error 21 with statement `INSERT INTO persons (name, age) VALUES ('Barbara', ?);`: wrong number of statement arguments: 0") {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE persons (name TEXT, age INT)")
                try db.execute(sql: """
                    INSERT INTO persons (name, age) VALUES ('Arthur', ?);
                    INSERT INTO persons (name, age) VALUES ('Barbara', ?);
                    """, arguments: [41])
            }
        }
        
        assertCrash("SQLite error 21 with statement `INSERT INTO persons (name, age) VALUES ('Arthur', :age1);`: missing statement argument(s): age1") {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE persons (name TEXT, age INT)")
                try db.execute(sql: """
                    INSERT INTO persons (name, age) VALUES ('Arthur', :age1);
                    INSERT INTO persons (name, age) VALUES ('Barbara', :age2);
                    """)
            }
        }
        
        assertCrash("SQLite error 21 with statement `INSERT INTO persons (name, age) VALUES ('Barbara', :age2);`: missing statement argument(s): age2") {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE persons (name TEXT, age INT)")
                try db.execute(sql: """
                    INSERT INTO persons (name, age) VALUES ('Arthur', :age1);
                    INSERT INTO persons (name, age) VALUES ('Barbara', :age2);
                    """, arguments: ["age1": 41])
            }
        }
        
        assertCrash("SQLite error 21: wrong number of statement arguments: 3") {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE persons (name TEXT, age INT)")
                try db.execute(sql: """
                    INSERT INTO persons (name, age) VALUES ('Arthur', :age1);
                    INSERT INTO persons (name, age) VALUES ('Arthur', :age2);
                    """, arguments: [41, 32, 17])
            }
        }
        
        assertCrash("SQLite error 21: wrong number of statement arguments: 3") {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE persons (name TEXT, age INT)")
                try db.execute(sql: """
                    INSERT INTO persons (name, age) VALUES ('Arthur', ?);
                    INSERT INTO persons (name, age) VALUES ('Arthur', ?);
                    """, arguments: [41, 32, 17])
            }
        }
    }
    
}

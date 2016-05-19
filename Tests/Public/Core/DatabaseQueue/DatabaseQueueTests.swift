import XCTest
import GRDB

class DatabaseQueueTests: GRDBTestCase {

    func testSwiftCompiler() {
        // Here we test that Swift compiler compiles some various usages of
        // DatabaseQueue.inDatabase { ... }
        let dbQueue = DatabaseQueue()
        
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE foo (id INTEGER PRIMARY KEY")
            }
        }
        
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE foo (id INTEGER PRIMARY KEY")
                try db.execute("CREATE TABLE bar (id INTEGER PRIMARY KEY")
            }
        }
        
        do {
            dbQueue.inDatabase { db in
                let x = 1
            }
        }
        
        do {
            let x = dbQueue.inDatabase { db in
                1
            }
        }
        
        do {
            dbQueue.inDatabase { db in
                1
            }
        }
        
        do {
            let x = dbQueue.inDatabase { db in
                let a = 1
                let b = 2
                return a + b
            }
        }
        
        do {
            dbQueue.inDatabase { db in
                let a = 1
                let b = 2
                return a + b
            }
        }
    }
}

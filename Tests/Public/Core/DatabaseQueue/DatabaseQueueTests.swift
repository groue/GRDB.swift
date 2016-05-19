import XCTest
#if SQLITE_HAS_CODEC
    import GRDBCipher
#else
    import GRDB
#endif

class DatabaseQueueTests: GRDBTestCase {
    
    func testInvalidFileFormat() {
        assertNoError {
            do {
                let testBundle = NSBundle(forClass: self.dynamicType)
                let path = testBundle.pathForResource("Betty", ofType: "jpeg")!
                guard NSData(contentsOfFile: path) != nil else {
                    XCTFail("Missing file")
                    return
                }
                _ = try DatabaseQueue(path: path)
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.code, 26) // SQLITE_NOTADB
                XCTAssertEqual(error.message!.lowercaseString, "file is encrypted or is not a database") // lowercaseString: accept multiple SQLite version
                XCTAssertTrue(error.sql == nil)
                XCTAssertEqual(error.description.lowercaseString, "sqlite error 26: file is encrypted or is not a database")
            }
        }
    }

    func testSwiftCompiler() {
        // Here we test that Swift compiler compiles some various usages of
        // DatabaseQueue.inDatabase { ... }
        //
        // Goal: fix https://github.com/groue/GRDB.swift/issues/54
        
//        assertNoError {
//            let dbQueue = DatabaseQueue()
//            try dbQueue.inDatabase { db in
//                try db.execute("CREATE TABLE foo (id INTEGER PRIMARY KEY")
//            }
//        }
//        
//        assertNoError {
//            let dbQueue = DatabaseQueue()
//            try dbQueue.inDatabase { db in
//                try db.execute("CREATE TABLE foo (id INTEGER PRIMARY KEY")
//                try db.execute("CREATE TABLE bar (id INTEGER PRIMARY KEY")
//            }
//        }
//        
//        assertNoError {
//            let dbQueue = DatabaseQueue()
//            // TODO: make it compile
//            try dbQueue.inDatabase { db in
//                try db.execute("CREATE TABLE foo (id INTEGER PRIMARY KEY")
//                return 1
//            }
//        }
//        
//        assertNoError {
//            let dbQueue = DatabaseQueue()
//            // TODO: make it compile
//            let x = try dbQueue.inDatabase { db in
//                try db.execute("CREATE TABLE foo (id INTEGER PRIMARY KEY")
//                return 1
//            }
//        }
//        
//        do {
//            let dbQueue = DatabaseQueue()
//            dbQueue.inDatabase { db in
//                let x = 1
//            }
//        }
//        
//        do {
//            let dbQueue = DatabaseQueue()
//            let x = dbQueue.inDatabase { db in
//                1
//            }
//        }
//        
//        do {
//            let dbQueue = DatabaseQueue()
//            dbQueue.inDatabase { db in
//                1
//            }
//        }
//        
//        do {
//            let dbQueue = DatabaseQueue()
//            // TODO: make it compile
//            let x = dbQueue.inDatabase { db in
//                let a = 1
//                let b = 2
//                return a + b
//            }
//        }
//        
//        do {
//            // TODO: make it compile
//            dbQueue.inDatabase { db in
//                let a = 1
//                let b = 2
//                return a + b
//            }
//        }
    }
}

import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class FetchableParent : DatabaseValueConvertible, CustomStringConvertible {
    var databaseValue: DatabaseValue {
        return "Parent".databaseValue
    }
    
    class func fromDatabaseValue(_ databaseValue: DatabaseValue) -> Self? {
        return self.init()
    }
    
    required init() {
    }
    
    var description: String { return "Parent" }
}

class FetchableChild : FetchableParent {
    /// Returns a value that can be stored in the database.
    override var databaseValue: DatabaseValue {
        return "Child".databaseValue
    }
    
    override var description: String { return "Child" }
}

class DatabaseValueConvertibleSubclassTests: GRDBTestCase {
    
    func testParent() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE parents (name TEXT)")
                try db.execute("INSERT INTO parents (name) VALUES (?)", arguments: [FetchableParent()])
                let string = String.fetchOne(db, "SELECT * FROM parents")!
                XCTAssertEqual(string, "Parent")
                let parent = FetchableParent.fetchOne(db, "SELECT * FROM parents")!
                XCTAssertEqual(parent.description, "Parent")
                let parents = FetchableParent.fetchAll(db, "SELECT * FROM parents")
                XCTAssertEqual(parents.first!.description, "Parent")
            }
        }
    }
    
    func testChild() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE children (name TEXT)")
                try db.execute("INSERT INTO children (name) VALUES (?)", arguments: [FetchableChild()])
                let string = String.fetchOne(db, "SELECT * FROM children")!
                XCTAssertEqual(string, "Child")
                let child = FetchableChild.fetchOne(db, "SELECT * FROM children")!
                XCTAssertEqual(child.description, "Child")
                let children = FetchableChild.fetchAll(db, "SELECT * FROM children")
                XCTAssertEqual(children.first!.description, "Child")
            }
        }
    }
}

import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private class FetchableParent : DatabaseValueConvertible, CustomStringConvertible {
    var databaseValue: DatabaseValue {
        return "Parent".databaseValue
    }
    
    class func fromDatabaseValue(_ dbValue: DatabaseValue) -> Self? {
        return self.init()
    }
    
    required init() {
    }
    
    var description: String { return "Parent" }
}

private class FetchableChild : FetchableParent {
    /// Returns a value that can be stored in the database.
    override var databaseValue: DatabaseValue {
        return "Child".databaseValue
    }
    
    override var description: String { return "Child" }
}

class DatabaseValueConvertibleSubclassTests: GRDBTestCase {
    
    func testParent() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute("CREATE TABLE parents (name TEXT)")
            try db.execute("INSERT INTO parents (name) VALUES (?)", arguments: [FetchableParent()])
            let string = try String.fetchOne(db, "SELECT * FROM parents")!
            XCTAssertEqual(string, "Parent")
            let parent = try FetchableParent.fetchOne(db, "SELECT * FROM parents")!
            XCTAssertEqual(parent.description, "Parent")
            let parents = try FetchableParent.fetchAll(db, "SELECT * FROM parents")
            XCTAssertEqual(parents.first!.description, "Parent")
        }
    }

    func testChild() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute("CREATE TABLE children (name TEXT)")
            try db.execute("INSERT INTO children (name) VALUES (?)", arguments: [FetchableChild()])
            let string = try String.fetchOne(db, "SELECT * FROM children")!
            XCTAssertEqual(string, "Child")
            let child = try FetchableChild.fetchOne(db, "SELECT * FROM children")!
            XCTAssertEqual(child.description, "Child")
            let children = try FetchableChild.fetchAll(db, "SELECT * FROM children")
            XCTAssertEqual(children.first!.description, "Child")
        }
    }
}

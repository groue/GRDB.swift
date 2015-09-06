import XCTest
import GRDB

class FetchableParent : DatabaseValueConvertible, CustomStringConvertible {
    /// Returns a value that can be stored in the database.
    var databaseValue: DatabaseValue {
        return DatabaseValue.Text("Parent")
    }
    
    /// Create an instance initialized to `databaseValue`.
    class func fromDatabaseValue(databaseValue: DatabaseValue) -> Self? {
        return self.init()
    }
    
    required init() {
    }
    
    var description: String { return "Parent" }
}

class FetchableChild : FetchableParent {
    /// Returns a value that can be stored in the database.
    override var databaseValue: DatabaseValue {
        return DatabaseValue.Text("Child")
    }
    
    override var description: String { return "Child" }
}

class DatabaseValueConvertibleSubclassTests: GRDBTestCase {
    
    func testParent() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE parents (name TEXT)")
                try db.execute("INSERT INTO parents (name) VALUES (?)", arguments: [FetchableParent()])
                let string = String.fetchOne(db, "SELECT * FROM parents")!
                XCTAssertEqual(string, "Parent")
                let parent = FetchableParent.fetchOne(db, "SELECT * FROM parents")!
                XCTAssertEqual(parent.description, "Parent")
            }
        }
    }
    
    func testChild() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE children (name TEXT)")
                try db.execute("INSERT INTO children (name) VALUES (?)", arguments: [FetchableChild()])
                let string = String.fetchOne(db, "SELECT * FROM children")!
                XCTAssertEqual(string, "Child")
                let child = FetchableChild.fetchOne(db, "SELECT * FROM children")!
                XCTAssertEqual(child.description, "Child")
            }
        }
    }
}

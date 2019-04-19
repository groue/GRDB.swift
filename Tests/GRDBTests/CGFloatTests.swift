import XCTest
import CoreGraphics
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class CGFloatTests: GRDBTestCase {
    
    func testCGFLoat() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE points (x DOUBLE, y DOUBLE)")
            
            let x: CGFloat = 1
            let y: CGFloat? = nil
            try db.execute(sql: "INSERT INTO points VALUES (?,?)", arguments: [x, y])
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM points")!
            let fetchedX: CGFloat = row["x"]
            let fetchedY: CGFloat? = row["y"]
            XCTAssertEqual(x, fetchedX)
            XCTAssertTrue(fetchedY == nil)
        }
    }
}

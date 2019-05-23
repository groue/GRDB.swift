import XCTest
import GRDB

class DateParsingTests: XCTestCase {
    
    /// Selects many dates
    let request = """
        WITH RECURSIVE
            cnt(x) AS (
                SELECT 1
                UNION ALL
                SELECT x+1 FROM cnt
                LIMIT 50000
            )
        SELECT '2018-04-20 14:47:12.345' FROM cnt;
        """
    
    func testParseDateComponents() {
        measure {
            try! DatabaseQueue().inDatabase { db in
                let cursor = try DatabaseDateComponents.fetchCursor(db, sql: request)
                while try cursor.next() != nil { }
            }
        }
    }
    
    func testParseDate() {
        measure {
            try! DatabaseQueue().inDatabase { db in
                let cursor = try Date.fetchCursor(db, sql: request)
                while try cursor.next() != nil { }
            }
        }
    }
}

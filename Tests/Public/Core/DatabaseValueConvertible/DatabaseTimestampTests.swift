import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

struct DatabaseTimestamp: DatabaseValueConvertible {
    
    // NSDate conversion
    //
    // We consistently use the Swift nil to represent the database NULL: the
    // date property is a non-optional NSDate, and the NSDate initializer is
    // failable:
    
    /// The represented date
    let date: NSDate
    
    /// Creates a DatabaseTimestamp from an NSDate.
    /// The result is nil if and only if *date* is nil.
    init?(_ date: NSDate?) {
        guard let date = date else {
            return nil
        }
        self.date = date
    }
    
    
    // DatabaseValueConvertible adoption
    
    /// Returns a value that can be stored in the database.
    var databaseValue: DatabaseValue {
        return date.timeIntervalSince1970.databaseValue
    }
    
    /// Returns a value initialized from *databaseValue*, if possible.
    static func fromDatabaseValue(databaseValue: DatabaseValue) -> DatabaseTimestamp? {
        // Double itself adopts DatabaseValueConvertible. So let's avoid
        // handling the raw DatabaseValue, and use built-in Double conversion:
        guard let timeInterval = Double.fromDatabaseValue(databaseValue) else {
            // No Double, no NSDate!
            return nil
        }
        return DatabaseTimestamp(NSDate(timeIntervalSince1970: timeInterval))
    }
}


class DatabaseTimestampTests: GRDBTestCase {

    func testDatabaseTimestamp() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE dates (date DATETIME)")
                let storedDate = NSDate()
                try db.execute("INSERT INTO dates (date) VALUES (?)", arguments: [DatabaseTimestamp(storedDate)])
                let fetchedDate = DatabaseTimestamp.fetchOne(db, "SELECT date FROM dates")!.date
                let delta = storedDate.timeIntervalSinceDate(fetchedDate)
                XCTAssertTrue(abs(delta) < 0.1)
            }
        }
    }
}

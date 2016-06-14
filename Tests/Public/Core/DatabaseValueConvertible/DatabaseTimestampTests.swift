import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

struct DatabaseTimestamp: DatabaseValueConvertible {
    
    // Date conversion
    //
    // We consistently use the Swift nil to represent the database NULL: the
    // date property is a non-optional Date, and the Date initializer is
    // failable:
    
    /// The represented date
    let date: Date
    
    /// Creates a DatabaseTimestamp from an Date.
    /// The result is nil if and only if *date* is nil.
    init?(_ date: Date?) {
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
    static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> DatabaseTimestamp? {
        // Double itself adopts DatabaseValueConvertible. So let's avoid
        // handling the raw DatabaseValue, and use built-in Double conversion:
        guard let timeInterval = Double.fromDatabaseValue(databaseValue) else {
            // No Double, no Date!
            return nil
        }
        return DatabaseTimestamp(Date(timeIntervalSince1970: timeInterval))
    }
}


class DatabaseTimestampTests: GRDBTestCase {

    func testDatabaseTimestamp() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE dates (date DATETIME)")
                let storedDate = Date()
                try db.execute("INSERT INTO dates (date) VALUES (?)", arguments: [DatabaseTimestamp(storedDate)])
                let fetchedDate = DatabaseTimestamp.fetchOne(db, "SELECT date FROM dates")!.date
                let delta = storedDate.timeIntervalSince(fetchedDate)
                XCTAssertTrue(abs(delta) < 0.1)
            }
        }
    }
}

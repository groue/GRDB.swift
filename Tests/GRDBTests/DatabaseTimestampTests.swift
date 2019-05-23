import XCTest
#if GRDBCUSTOMSQLITE
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
    
    /// Returns a value initialized from *dbValue*, if possible.
    static func fromDatabaseValue(_ dbValue: DatabaseValue) -> DatabaseTimestamp? {
        // Double itself adopts DatabaseValueConvertible. So let's avoid
        // handling the raw DatabaseValue, and use built-in Double conversion:
        guard let timeInterval = Double.fromDatabaseValue(dbValue) else {
            // No Double, no Date!
            return nil
        }
        return DatabaseTimestamp(Date(timeIntervalSince1970: timeInterval))
    }
}


class DatabaseTimestampTests: GRDBTestCase {

    func testDatabaseTimestamp() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE dates (date DATETIME)")
            let storedDate = Date()
            try db.execute(sql: "INSERT INTO dates (date) VALUES (?)", arguments: [DatabaseTimestamp(storedDate)])
            let fetchedDate = try DatabaseTimestamp.fetchOne(db, sql: "SELECT date FROM dates")!.date
            let delta = storedDate.timeIntervalSince(fetchedDate)
            XCTAssertTrue(abs(delta) < 0.1)
        }
    }
}

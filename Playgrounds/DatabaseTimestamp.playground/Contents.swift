// To run this playground, select and build the GRDBOSX scheme.

import GRDB

struct DatabaseTimestamp: DatabaseValueConvertible {
    
    // NSDate conversion
    //
    // Value types should consistently use the Swift nil to represent the
    // database NULL: the date property is a non-optional NSDate.
    let date: NSDate
    
    // As a convenience, the NSDate initializer accepts an optional NSDate, and
    // is failable: the result is nil if and only if *date* is nil.
    init?(_ date: NSDate?) {
        guard let date = date else {
            return nil
        }
        self.date = date
    }
    
    
    // DatabaseValueConvertible adoption
    
    /// Returns a value that can be stored in the database.
    var databaseValue: DatabaseValue {
        // Double itself adopts DatabaseValueConvertible:
        return date.timeIntervalSince1970.databaseValue
    }
    
    /// Returns a value initialized from *databaseValue*, if possible.
    static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> DatabaseTimestamp? {
        // Double itself adopts DatabaseValueConvertible:
        guard let timeInterval = Double.fromDatabaseValue(databaseValue) else {
            // No Double, no NSDate!
            return nil
        }
        return DatabaseTimestamp(NSDate(timeIntervalSince1970: timeInterval))
    }
}


var configuration = Configuration()
configuration.trace = { print($0) }
let dbQueue = DatabaseQueue(configuration: configuration)   // Memory database
var migrator = DatabaseMigrator()
migrator.registerMigration("createEvents") { db in
    try db.execute(
        "CREATE TABLE events (" +
            "date DATETIME " +
        ")")
}
try! migrator.migrate(dbQueue)

try! dbQueue.inDatabase { db in
    try db.execute("INSERT INTO events (date) VALUES (?)", arguments: [DatabaseTimestamp(NSDate())])
    let row = Row.fetchOne(db, "SELECT * FROM events")!
    let timestamp: Double = row.value(named: "date")
    let date = (row.value(named: "date") as DatabaseTimestamp).date
    print("timestamp: \(timestamp)")
    print("date: \(date)")
}

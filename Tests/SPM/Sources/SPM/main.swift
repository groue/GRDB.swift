import GRDB
import CSQLite

let CVersion = String(cString: sqlite3_libversion())
print("SQLite version from C API: \(CVersion)")

let SQLVersion = try! DatabaseQueue().read { db in
    try String.fetchOne(db, "SELECT sqlite_version()")!
}
print("SQLite version from SQL function: \(SQLVersion)")

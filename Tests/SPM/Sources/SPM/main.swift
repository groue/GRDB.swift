import GRDB
import CSQLite

let cVersion = String(cString: sqlite3_libversion())
print("SQLite version from C API: \(cVersion)")

let sqlVersion = try! DatabaseQueue().read { db in
    try String.fetchOne(db, sql: "SELECT sqlite_version()")!
}
print("SQLite version from SQL function: \(sqlVersion)")

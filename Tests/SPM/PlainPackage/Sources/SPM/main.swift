import GRDB
import SQLite3

let cVersion = String(cString: sqlite3_libversion())
print("SQLite version from C API: \(cVersion)")

let sqlVersion = try! DatabaseQueue().read { db in
    try String.fetchOne(db, sql: "SELECT sqlite_version()")!
}
print("SQLite version from SQL function: \(sqlVersion)")

try! DatabaseQueue().write { db in
    try db.execute(literal: """
        CREATE TABLE t(a);
        INSERT INTO t VALUES(\("O'Brien"));
        """)
    let swiftVersion = try String.fetchOne(db, sql: "SELECT a FROM t")!
    print("Swift string from SQL: \(swiftVersion)")
}

import GRDB
import CSQLite

let cVersion = String(cString: sqlite3_libversion())
print("SQLite version from C API: \(cVersion)")

let sqlVersion = try! DatabaseQueue().read { db in
    try String.fetchOne(db, sql: "SELECT sqlite_version()")!
}
print("SQLite version from SQL function: \(sqlVersion)")

#if swift(>=5.0)
try! DatabaseQueue().write { db in
    try db.execute(literal: """
        CREATE TABLE t(a);
        INSERT INTO t VALUES(\("5"));
        """)
    let swiftVersion = String.fetchOne(db, sql: "SELECT a FROM t")!
    print("Swift version from SQL: \(swiftVersion)")
}
#endif

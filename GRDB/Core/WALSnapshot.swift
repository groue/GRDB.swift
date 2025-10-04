#if SQLITE_ENABLE_SNAPSHOT
// Import C SQLite functions
#if GRDBCIPHER // CocoaPods (SQLCipher subspec)
import SQLCipher
#elseif GRDBFRAMEWORK // GRDB.xcodeproj or CocoaPods (standard subspec)
import SQLite3
#elseif GRDBCUSTOMSQLITE // GRDBCustom Framework
// #elseif SomeTrait
// import ...
#else // Default SPM trait must be the default. It impossible to detect from Xcode.
import GRDBSQLite
#endif

/// An instance of WALSnapshot records the state of a WAL mode database for some
/// specific point in history.
///
/// We use `WALSnapshot` to help `ValueObservation` check for changes
/// that would happen between the initial fetch, and the start of the
/// actual observation. This class has no other purpose, and is not intended to
/// become public.
///
/// See <https://www.sqlite.org/c3ref/snapshot.html>.
final class WALSnapshot: @unchecked Sendable {
    // @unchecked because sqlite3_snapshot has no threading requirements.
    // <https://www.sqlite.org/c3ref/snapshot.html>
    let sqliteSnapshot: UnsafeMutablePointer<sqlite3_snapshot>
    
    init(_ db: Database) throws {
        var sqliteSnapshot: UnsafeMutablePointer<sqlite3_snapshot>?
        let code = withUnsafeMutablePointer(to: &sqliteSnapshot) {
            return sqlite3_snapshot_get(db.sqliteConnection, "main", $0)
        }
        guard code == SQLITE_OK else {
            // <https://www.sqlite.org/c3ref/snapshot_get.html>
            //
            // > The following must be true for sqlite3_snapshot_get() to succeed. [...]
            // >
            // > 1. The database handle must not be in autocommit mode.
            // > 2. Schema S of database connection D must be a WAL
            // >    mode database.
            // > 3. There must not be a write transaction open on schema S
            // >    of database connection D.
            // > 4. One or more transactions must have been written to the
            // >    current wal file since it was created on disk (by any
            // >    connection). This means that a snapshot cannot be taken
            // >    on a wal mode database with no wal file immediately
            // >    after it is first opened. At least one transaction must
            // >    be written to it first.
            
            // Test condition 1:
            if sqlite3_get_autocommit(db.sqliteConnection) != 0 {
                throw DatabaseError(resultCode: code, message: """
                    Can't create snapshot because database is in autocommit mode.
                    """)
            }
            
            // Test condition 2:
            if let journalMode = try? String.fetchOne(db, sql: "PRAGMA journal_mode"),
               journalMode != "wal"
            {
                throw DatabaseError(resultCode: code, message: """
                    Can't create snapshot because database is not in WAL mode.
                    """)
            }
            
            // Condition 3 can't happen because GRDB only calls this
            // initializer from read transactions.
            //
            // Hence it is condition 4 that is false:
            throw DatabaseError(resultCode: code, message: """
                Can't create snapshot from a missing or empty wal file.
                """)
        }
        guard let sqliteSnapshot else {
            throw DatabaseError(resultCode: .SQLITE_INTERNAL) // WTF SQLite?
        }
        self.sqliteSnapshot = sqliteSnapshot
    }
    
    deinit {
        sqlite3_snapshot_free(sqliteSnapshot)
    }
    
    /// Compares two WAL snapshots.
    ///
    /// `a.compare(b) < 0` iff a is older than b.
    ///
    /// See <https://www.sqlite.org/c3ref/snapshot_cmp.html>.
    func compare(_ other: WALSnapshot) -> CInt {
        sqlite3_snapshot_cmp(sqliteSnapshot, other.sqliteSnapshot)
    }
}
#endif

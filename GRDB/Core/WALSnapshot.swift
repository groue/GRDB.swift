/// An instance of WALSnapshot records the state of a WAL mode database for some
/// specific point in history.
///
/// We use `WALSnapshot` to help `ValueObservation` check for changes
/// that would happen between the initial fetch, and the start of the
/// actual observation. This class has no other purpose, and is not intended to
/// become public.
///
/// It does not work with SQLCipher, because SQLCipher does not support
/// `SQLITE_ENABLE_SNAPSHOT` correctly: we have linker errors.
/// See <https://github.com/ericsink/SQLitePCL.raw/issues/452>.
///
/// With custom SQLite builds, it only works if `SQLITE_ENABLE_SNAPSHOT`
/// is defined.
///
/// With system SQLite, it can only work when the SDK exposes the C apis and
/// their availability, which means XCode 14 (identified with Swift 5.7).
///
/// Yes, this is an awfully complex logic.
///
/// See <https://www.sqlite.org/c3ref/snapshot.html>.
final class WALSnapshot: Sendable {
    // Xcode 14 (Swift 5.7) ships with a macOS SDK that misses snapshot support.
    // Xcode 14.1 (Swift 5.7.1) ships with a macOS SDK that has snapshot support.
    // This is the meaning of (compiler(>=5.7.1) || !(os(macOS) || targetEnvironment(macCatalyst)))
    // swiftlint:disable:next line_length
#if SQLITE_ENABLE_SNAPSHOT || (!GRDBCUSTOMSQLITE && !GRDBCIPHER && (compiler(>=5.7.1) || !(os(macOS) || targetEnvironment(macCatalyst))))
    static let available = true
    
    let sqliteSnapshot: UnsafeMutablePointer<sqlite3_snapshot>
    
    init(_ db: Database) throws {
        var sqliteSnapshot: UnsafeMutablePointer<sqlite3_snapshot>?
        let code = withUnsafeMutablePointer(to: &sqliteSnapshot) {
            return sqlite3_snapshot_get(db.sqliteConnection, "main", $0)
        }
        guard code == SQLITE_OK else {
            if sqlite3_get_autocommit(db.sqliteConnection) != 0 {
                throw DatabaseError(resultCode: code, message: """
                    Can't create snapshot because database is in autocommit mode.
                    """)
            }
            if let journalMode = try? String.fetchOne(db, sql: "PRAGMA journal_mode"),
               journalMode != "wal"
            {
                throw DatabaseError(resultCode: code, message: """
                    Can't create snapshot because database is not in WAL mode.
                    """)
            }
            throw DatabaseError(resultCode: code)
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
        return sqlite3_snapshot_cmp(sqliteSnapshot, other.sqliteSnapshot)
    }
#else
    static let available = false

    init(_ db: Database) throws {
        throw DatabaseError(resultCode: .SQLITE_MISUSE, message: "snapshots are not available")
    }

    func compare(_ other: WALSnapshot) -> CInt {
        preconditionFailure("snapshots are not available")
    }
#endif
}

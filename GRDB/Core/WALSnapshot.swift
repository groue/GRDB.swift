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
final class WALSnapshot {
#if os(macOS) || targetEnvironment(macCatalyst) || GRDBCIPHER || (GRDBCUSTOMSQLITE && !SQLITE_ENABLE_SNAPSHOT) || compiler(<5.7)
    init?(_ db: Database) {
        return nil
    }
    
    func compare(_ other: WALSnapshot) -> CInt {
        preconditionFailure("snapshots are not available")
    }
#else
    private let snapshot: UnsafeMutablePointer<sqlite3_snapshot>?
    
    /// Returns nil if `SQLITE_ENABLE_SNAPSHOT` is not enabled, or if an
    /// error occurs.
    init?(_ db: Database) {
        var snapshot: UnsafeMutablePointer<sqlite3_snapshot>?
        let code: CInt = withUnsafeMutablePointer(to: &snapshot) {
#if GRDBCUSTOMSQLITE
            return sqlite3_snapshot_get(db.sqliteConnection, "main", $0)
#else
            // iOS 10.0 is always true because our minimum requirement is iOS 11.
            if #available(macOS 10.12, watchOS 3.0, tvOS 10.0, *) {
                return sqlite3_snapshot_get(db.sqliteConnection, "main", $0)
            } else {
                return SQLITE_ERROR
            }
#endif
        }
        guard code == SQLITE_OK, let s = snapshot else {
            return nil
        }
        self.snapshot = s
    }
    
    deinit {
#if GRDBCUSTOMSQLITE
        sqlite3_snapshot_free(snapshot)
#else
        // iOS 10.0 is always true because our minimum requirement is iOS 11.
        if #available(macOS 10.12, watchOS 3.0, tvOS 10.0, *) {
            sqlite3_snapshot_free(snapshot)
        }
#endif
    }
    
    /// Compares two WAL snapshots.
    ///
    /// `a.compare(b) < 0` iff a is older than b.
    ///
    /// See <https://www.sqlite.org/c3ref/snapshot_cmp.html>.
    func compare(_ other: WALSnapshot) -> CInt {
#if GRDBCUSTOMSQLITE
        return sqlite3_snapshot_cmp(snapshot, other.snapshot)
#else
        // iOS 10.0 is always true because our minimum requirement is iOS 11.
        if #available(macOS 10.12, watchOS 3.0, tvOS 10.0, *) {
            return sqlite3_snapshot_cmp(snapshot, other.snapshot)
        } else {
            preconditionFailure("snapshots are not available")
        }
#endif
    }
#endif // os(macOS) || targetEnvironment(macCatalyst) || GRDBCIPHER || (GRDBCUSTOMSQLITE && !SQLITE_ENABLE_SNAPSHOT) || compiler(<5.7)
}

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
    // Xcode 14 RC ships with a macOS SDK that misses snapshot support.
    // TODO: when Xcode ships with a macOS SDK that exposes snapshots, replace
    // the `os(macOS) || targetEnvironment(macCatalyst)` check with a compiler
    // version check.
    //
    // We can't enable snapshots for SQLCipher, since we don't know if they
    // are enabled.
#if os(macOS) || targetEnvironment(macCatalyst) || GRDBCIPHER || (GRDBCUSTOMSQLITE && !SQLITE_ENABLE_SNAPSHOT)
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
        let code = withUnsafeMutablePointer(to: &snapshot) {
            return sqlite3_snapshot_get(db.sqliteConnection, "main", $0)
        }
        guard code == SQLITE_OK, let snapshot else {
            return nil
        }
        self.snapshot = snapshot
    }
    
    deinit {
        sqlite3_snapshot_free(snapshot)
    }
    
    /// Compares two WAL snapshots.
    ///
    /// `a.compare(b) < 0` iff a is older than b.
    ///
    /// See <https://www.sqlite.org/c3ref/snapshot_cmp.html>.
    func compare(_ other: WALSnapshot) -> CInt {
        return sqlite3_snapshot_cmp(snapshot, other.snapshot)
    }
#endif // os(macOS) || targetEnvironment(macCatalyst) || GRDBCIPHER || (GRDBCUSTOMSQLITE && !SQLITE_ENABLE_SNAPSHOT)
}

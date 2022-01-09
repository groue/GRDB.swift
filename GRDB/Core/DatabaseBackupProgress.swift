/// An instance of `DatabaseBackupProgress` is passed to a callback of the
/// `DatabaseReader.backup` or `Database.backup` methods to report
/// database backup progress to the caller.
///
/// This is an advanced API for expert users. It is based directly on the SQLite
/// [online backup API](https://www.sqlite.org/c3ref/backup_finish.html).
public struct DatabaseBackupProgress {
    /// Total page count is defined by the `sqlite3_backup_remaining` function
    public let remainingPageCount: Int

    /// Total page count is defined by the `sqlite3_backup_pagecount` function
    public let totalPageCount: Int

    /// Completed page count is defined as `sqlite3_backup_pagecount() - sqlite3_backup_remaining()`
    public var completedPageCount: Int {
        totalPageCount - remainingPageCount
    }

    /// This property is true if and only if `sqlite3_backup_step()` returns
    /// `SQLITE_DONE`
    public let isCompleted: Bool
}

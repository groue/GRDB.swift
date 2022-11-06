/// Describe the progress of a database backup.
///
/// Related SQLite documentation: <https://www.sqlite.org/c3ref/backup_finish.html>
public struct DatabaseBackupProgress {
    /// The number of pages still to be backed up.
    ///
    /// It is the result of the `sqlite3_backup_remaining` function.
    public let remainingPageCount: Int
    
    /// The number of pages in the source database.
    ///
    /// It is the result of the `sqlite3_backup_pagecount` function.
    public let totalPageCount: Int
    
    /// The number of of backed up pages.
    ///
    /// It is equal to `totalPageCount - remainingPageCount`.
    public var completedPageCount: Int {
        totalPageCount - remainingPageCount
    }
    
    /// A boolean value indicating whether the backup is complete.
    ///
    /// It is true if and only if the last call the `sqlite3_backup_step` has
    /// returned `SQLITE_DONE`.
    public let isCompleted: Bool
}

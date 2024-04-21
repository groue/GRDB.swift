// Import C SQLite functions
#if SWIFT_PACKAGE
import CSQLite
#elseif GRDBCIPHER
import SQLCipher
#elseif !GRDBCUSTOMSQLITE && !GRDBCIPHER
import SQLite3
#endif

extension Database {
    /// Copies the database contents into another database.
    ///
    /// The `backup` method blocks the current thread until the destination
    /// database contains the same contents as the source database.
    ///
    /// Usage:
    ///
    /// ```swift
    /// let source: DatabaseQueue = ...
    /// let destination: DatabaseQueue = ...
    /// try source.write { sourceDb in
    ///     try destination.barrierWriteWithoutTransaction { destDb in
    ///         try sourceDb.backup(to: destDb)
    ///     }
    /// }
    /// ```
    ///
    /// When you're after progress reporting during backup, you'll want to
    /// perform the backup in several steps. Each step copies the number of
    /// _database pages_ you specify. See <https://www.sqlite.org/c3ref/backup_finish.html>
    /// for more information:
    ///
    /// ```swift
    /// // Backup with progress reporting
    /// try sourceDb.backup(to: destDb, pagesPerStep: ...) { progress in
    ///     print("Database backup progress:", progress)
    /// }
    /// ```
    ///
    /// The `progress` callback will be called at least once—when
    /// `backupProgress.isCompleted == true`. If the callback throws
    /// when `backupProgress.isCompleted == false`, the backup is aborted
    /// and the error is rethrown. If the callback throws when
    /// `backupProgress.isCompleted == true`, backup completion is
    /// unaffected and the error is silently ignored.
    ///
    /// See also ``DatabaseReader/backup(to:pagesPerStep:progress:)``.
    ///
    /// - parameters:
    ///     - destDb: The destination database.
    ///     - pagesPerStep: The number of database pages copied on each backup
    ///       step. By default, all pages are copied in one single step.
    ///     - progress: An optional function that is notified of the backup
    ///       progress.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or the
    ///   error thrown by `progress`.
    public func backup(
        to destDb: Database,
        pagesPerStep: CInt = -1,
        progress: ((DatabaseBackupProgress) throws -> Void)? = nil)
    throws
    {
        try backupInternal(
            to: destDb,
            pagesPerStep: pagesPerStep,
            afterBackupStep: progress)
    }
    
    func backupInternal(
        to destDb: Database,
        pagesPerStep: CInt = -1,
        afterBackupInit: (() -> Void)? = nil,
        afterBackupStep: ((DatabaseBackupProgress) throws -> Void)? = nil)
    throws
    {
        guard let backup = sqlite3_backup_init(destDb.sqliteConnection, "main", sqliteConnection, "main") else {
            throw DatabaseError(resultCode: destDb.lastErrorCode, message: destDb.lastErrorMessage)
        }
        guard Int(bitPattern: backup) != Int(SQLITE_ERROR) else {
            throw DatabaseError()
        }
        
        afterBackupInit?()
        
        do {
            backupLoop: while true {
                let rc = sqlite3_backup_step(backup, pagesPerStep)
                let totalPageCount = Int(sqlite3_backup_pagecount(backup))
                let remainingPageCount = Int(sqlite3_backup_remaining(backup))
                let progress = DatabaseBackupProgress(
                    remainingPageCount: remainingPageCount,
                    totalPageCount: totalPageCount,
                    isCompleted: rc == SQLITE_DONE)
                switch rc {
                case SQLITE_DONE:
                    try? afterBackupStep?(progress)
                    break backupLoop
                case SQLITE_OK:
                    try afterBackupStep?(progress)
                case let code:
                    throw DatabaseError(resultCode: code, message: destDb.lastErrorMessage)
                }
            }
        } catch {
            sqlite3_backup_finish(backup)
            throw error
        }
        
        switch sqlite3_backup_finish(backup) {
        case SQLITE_OK:
            break
        case let code:
            throw DatabaseError(resultCode: code, message: destDb.lastErrorMessage)
        }
        
        // The schema of the destination database has changed:
        destDb.clearSchemaCache()
    }
}

/// Describe the progress of a database backup.
///
/// Related SQLite documentation: <https://www.sqlite.org/c3ref/backup_finish.html>
public struct DatabaseBackupProgress: Sendable {
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

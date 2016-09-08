#if !USING_BUILTIN_SQLITE
    #if os(OSX)
        import SQLiteMacOSX
    #elseif os(iOS)
        #if (arch(i386) || arch(x86_64))
            import SQLiteiPhoneSimulator
        #else
            import SQLiteiPhoneOS
        #endif
    #elseif os(watchOS)
        #if (arch(i386) || arch(x86_64))
            import SQLiteWatchSimulator
        #else
            import SQLiteWatchOS
        #endif
    #endif
#endif

/// The protocol for all types that can fetch values from a database.
///
/// It is adopted by DatabaseQueue and DatabasePool.
///
/// The protocol comes with isolation guarantees that describe the behavior of
/// adopting types in a multithreaded application.
///
/// Types that adopt the protocol can provide in practice stronger guarantees.
/// For example, DatabaseQueue provides a stronger isolation level
/// than DatabasePool.
///
/// **Warning**: Isolation guarantees stand as long as there is no external
/// connection to the database. Should you have to cope with external
/// connections, protect yourself with transactions, and be ready to setup a
/// [busy handler](https://www.sqlite.org/c3ref/busy_handler.html).
public protocol DatabaseReader : class {
    
    // MARK: - Read From Database
    
    /// Synchronously executes a read-only block that takes a database
    /// connection, and returns its result.
    ///
    /// The *block* argument is completely isolated. Eventual concurrent
    /// database updates are *not visible* inside the block:
    ///
    ///     reader.read { db in
    ///         // Those two values are guaranteed to be equal, even if the
    ///         // `wines` table is modified between the two requests:
    ///         let count1 = Int.fetchOne(db, "SELECT COUNT(*) FROM wines")!
    ///         let count2 = Int.fetchOne(db, "SELECT COUNT(*) FROM wines")!
    ///     }
    ///
    ///     reader.read { db in
    ///         // Now this value may be different:
    ///         let count = Int.fetchOne(db, "SELECT COUNT(*) FROM wines")!
    ///     }
    ///
    /// - parameter block: A block that accesses the database.
    /// - throws: The error thrown by the block.
    func read<T>(_ block: (Database) throws -> T) rethrows -> T
    
    /// Synchronously executes a read-only block that takes a database
    /// connection, and returns its result.
    ///
    /// Individual statements executed in the *block* argument are executed
    /// in isolation from eventual concurrent updates:
    ///
    ///     reader.nonIsolatedRead { db in
    ///         // no external update can mess with this iteration:
    ///         for row in Row.fetch(db, ...) { ... }
    ///     }
    ///
    /// However, there is no guarantee that consecutive statements have the
    /// same results:
    ///
    ///     reader.nonIsolatedRead { db in
    ///         // Those two ints may be different:
    ///         let sql = "SELECT ..."
    ///         let int1 = Int.fetchOne(db, sql)
    ///         let int2 = Int.fetchOne(db, sql)
    ///     }
    func nonIsolatedRead<T>(_ block: (Database) throws -> T) rethrows -> T
    
    
    // MARK: - Functions
    
    /// Add or redefine an SQL function.
    ///
    ///     let fn = DatabaseFunction("succ", argumentCount: 1) { databaseValues in
    ///         let dbv = databaseValues.first!
    ///         guard let int = dbv.value() as Int? else {
    ///             return nil
    ///         }
    ///         return int + 1
    ///     }
    ///     reader.add(function: fn)
    ///     Int.fetchOne(reader, "SELECT succ(1)")! // 2
    func add(function: DatabaseFunction)
    
    /// Remove an SQL function.
    func remove(function: DatabaseFunction)
    
    
    // MARK: - Collations
    
    /// Add or redefine a collation.
    ///
    ///     let collation = DatabaseCollation("localized_standard") { (string1, string2) in
    ///         return (string1 as NSString).localizedStandardCompare(string2)
    ///     }
    ///     reader.add(collation: collation)
    ///     try reader.execute("SELECT * FROM files ORDER BY name COLLATE localized_standard")
    func add(collation: DatabaseCollation)
    
    /// Remove a collation.
    func remove(collation: DatabaseCollation)
}

extension DatabaseReader {
    
    // MARK: - Backup
    
    /// Copies the database contents into another database.
    ///
    /// The `backup` method blocks the current thread until the destination
    /// database contains the same contents as the source database.
    ///
    /// When the source is a DatabasePool, concurrent writes can happen during
    /// the backup. Those writes may, or may not, be reflected in the backup,
    /// but they won't trigger any error.
    public func backup(to writer: DatabaseWriter) throws {
        try backup(to: writer, afterBackupInit: nil, afterBackupStep: nil)
    }
    
    func backup(to writer: DatabaseWriter, afterBackupInit: (() -> ())?, afterBackupStep: (() -> ())?) throws {
        try read { dbFrom in
            try writer.write { dbDest in
                guard let backup = sqlite3_backup_init(dbDest.sqliteConnection, "main", dbFrom.sqliteConnection, "main") else {
                    throw DatabaseError(code: dbDest.lastErrorCode, message: dbDest.lastErrorMessage)
                }
                guard Int(bitPattern: backup) != Int(SQLITE_ERROR) else {
                    throw DatabaseError(code: SQLITE_ERROR)
                }
                
                afterBackupInit?()
                
                do {
                    backupLoop: while true {
                        switch sqlite3_backup_step(backup, -1) {
                        case SQLITE_DONE:
                            afterBackupStep?()
                            break backupLoop
                        case SQLITE_OK:
                            afterBackupStep?()
                        case let code:
                            throw DatabaseError(code: code, message: dbDest.lastErrorMessage)
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
                    throw DatabaseError(code: code, message: dbDest.lastErrorMessage)
                }
                
                dbDest.clearSchemaCache()
            }
        }
    }
}

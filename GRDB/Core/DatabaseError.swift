import Foundation

/// An SQLite result code.
///
/// See <https://www.sqlite.org/rescode.html>
public struct ResultCode: RawRepresentable, Equatable, CustomStringConvertible {
    /// The raw SQLite result code
    public let rawValue: CInt
    
    /// Creates a `ResultCode` from a raw SQLite result code.
    public init(rawValue: CInt) {
        self.rawValue = rawValue
    }
    
    /// A result code limited to the least significant 8 bits of the receiver.
    /// See <https://www.sqlite.org/rescode.html> for more information.
    ///
    ///     let resultCode = .SQLITE_CONSTRAINT_FOREIGNKEY
    ///     resultCode.primaryResultCode == .SQLITE_CONSTRAINT // true
    public var primaryResultCode: ResultCode {
        ResultCode(rawValue: rawValue & 0xFF)
    }
    
    var isPrimary: Bool { self == primaryResultCode }
    
    /// Returns true if the code on the left matches the code on the right.
    ///
    /// Primary result codes match themselves and their extended result codes,
    /// while extended result codes match only themselves:
    ///
    ///     switch error.extendedResultCode {
    ///     case .SQLITE_CONSTRAINT_FOREIGNKEY: // foreign key constraint error
    ///     case .SQLITE_CONSTRAINT:            // any other constraint error
    ///     default:                            // any other database error
    ///     }
    public static func ~= (pattern: ResultCode, code: ResultCode) -> Bool {
        if pattern.isPrimary {
            return pattern == code.primaryResultCode
        } else {
            return pattern == code
        }
    }
    
    // Primary Result codes
    // https://www.sqlite.org/rescode.html#primary_result_code_list
    
    // swiftlint:disable operator_usage_whitespace
    public static let SQLITE_OK           = ResultCode(rawValue: 0)   // Successful result
    public static let SQLITE_ERROR        = ResultCode(rawValue: 1)   // SQL error or missing database
    public static let SQLITE_INTERNAL     = ResultCode(rawValue: 2)   // Internal logic error in SQLite
    public static let SQLITE_PERM         = ResultCode(rawValue: 3)   // Access permission denied
    public static let SQLITE_ABORT        = ResultCode(rawValue: 4)   // Callback routine requested an abort
    public static let SQLITE_BUSY         = ResultCode(rawValue: 5)   // The database file is locked
    public static let SQLITE_LOCKED       = ResultCode(rawValue: 6)   // A table in the database is locked
    public static let SQLITE_NOMEM        = ResultCode(rawValue: 7)   // A malloc() failed
    public static let SQLITE_READONLY     = ResultCode(rawValue: 8)   // Attempt to write a readonly database
    public static let SQLITE_INTERRUPT    = ResultCode(rawValue: 9)   // Operation terminated by sqlite3_interrupt()
    public static let SQLITE_IOERR        = ResultCode(rawValue: 10)  // Some kind of disk I/O error occurred
    public static let SQLITE_CORRUPT      = ResultCode(rawValue: 11)  // The database disk image is malformed
    public static let SQLITE_NOTFOUND     = ResultCode(rawValue: 12)  // Unknown opcode in sqlite3_file_control()
    public static let SQLITE_FULL         = ResultCode(rawValue: 13)  // Insertion failed because database is full
    public static let SQLITE_CANTOPEN     = ResultCode(rawValue: 14)  // Unable to open the database file
    public static let SQLITE_PROTOCOL     = ResultCode(rawValue: 15)  // Database lock protocol error
    public static let SQLITE_EMPTY        = ResultCode(rawValue: 16)  // Database is empty
    public static let SQLITE_SCHEMA       = ResultCode(rawValue: 17)  // The database schema changed
    public static let SQLITE_TOOBIG       = ResultCode(rawValue: 18)  // String or BLOB exceeds size limit
    public static let SQLITE_CONSTRAINT   = ResultCode(rawValue: 19)  // Abort due to constraint violation
    public static let SQLITE_MISMATCH     = ResultCode(rawValue: 20)  // Data type mismatch
    public static let SQLITE_MISUSE       = ResultCode(rawValue: 21)  // Library used incorrectly
    public static let SQLITE_NOLFS        = ResultCode(rawValue: 22)  // Uses OS features not supported on host
    public static let SQLITE_AUTH         = ResultCode(rawValue: 23)  // Authorization denied
    public static let SQLITE_FORMAT       = ResultCode(rawValue: 24)  // Auxiliary database format error
    public static let SQLITE_RANGE        = ResultCode(rawValue: 25)  // 2nd parameter to sqlite3_bind out of range
    public static let SQLITE_NOTADB       = ResultCode(rawValue: 26)  // File opened that is not a database file
    public static let SQLITE_NOTICE       = ResultCode(rawValue: 27)  // Notifications from sqlite3_log()
    public static let SQLITE_WARNING      = ResultCode(rawValue: 28)  // Warnings from sqlite3_log()
    public static let SQLITE_ROW          = ResultCode(rawValue: 100) // sqlite3_step() has another row ready
    public static let SQLITE_DONE         = ResultCode(rawValue: 101) // sqlite3_step() has finished executing
    // swiftlint:enable operator_usage_whitespace
    
    // Extended Result Code
    // https://www.sqlite.org/rescode.html#extended_result_code_list
    
    // swiftlint:disable operator_usage_whitespace line_length
    public static let SQLITE_ERROR_MISSING_COLLSEQ   = ResultCode(rawValue: (SQLITE_ERROR.rawValue | (1<<8)))
    public static let SQLITE_ERROR_RETRY             = ResultCode(rawValue: (SQLITE_ERROR.rawValue | (2<<8)))
    public static let SQLITE_ERROR_SNAPSHOT          = ResultCode(rawValue: (SQLITE_ERROR.rawValue | (3<<8)))
    public static let SQLITE_IOERR_READ              = ResultCode(rawValue: (SQLITE_IOERR.rawValue | (1<<8)))
    public static let SQLITE_IOERR_SHORT_READ        = ResultCode(rawValue: (SQLITE_IOERR.rawValue | (2<<8)))
    public static let SQLITE_IOERR_WRITE             = ResultCode(rawValue: (SQLITE_IOERR.rawValue | (3<<8)))
    public static let SQLITE_IOERR_FSYNC             = ResultCode(rawValue: (SQLITE_IOERR.rawValue | (4<<8)))
    public static let SQLITE_IOERR_DIR_FSYNC         = ResultCode(rawValue: (SQLITE_IOERR.rawValue | (5<<8)))
    public static let SQLITE_IOERR_TRUNCATE          = ResultCode(rawValue: (SQLITE_IOERR.rawValue | (6<<8)))
    public static let SQLITE_IOERR_FSTAT             = ResultCode(rawValue: (SQLITE_IOERR.rawValue | (7<<8)))
    public static let SQLITE_IOERR_UNLOCK            = ResultCode(rawValue: (SQLITE_IOERR.rawValue | (8<<8)))
    public static let SQLITE_IOERR_RDLOCK            = ResultCode(rawValue: (SQLITE_IOERR.rawValue | (9<<8)))
    public static let SQLITE_IOERR_DELETE            = ResultCode(rawValue: (SQLITE_IOERR.rawValue | (10<<8)))
    public static let SQLITE_IOERR_BLOCKED           = ResultCode(rawValue: (SQLITE_IOERR.rawValue | (11<<8)))
    public static let SQLITE_IOERR_NOMEM             = ResultCode(rawValue: (SQLITE_IOERR.rawValue | (12<<8)))
    public static let SQLITE_IOERR_ACCESS            = ResultCode(rawValue: (SQLITE_IOERR.rawValue | (13<<8)))
    public static let SQLITE_IOERR_CHECKRESERVEDLOCK = ResultCode(rawValue: (SQLITE_IOERR.rawValue | (14<<8)))
    public static let SQLITE_IOERR_LOCK              = ResultCode(rawValue: (SQLITE_IOERR.rawValue | (15<<8)))
    public static let SQLITE_IOERR_CLOSE             = ResultCode(rawValue: (SQLITE_IOERR.rawValue | (16<<8)))
    public static let SQLITE_IOERR_DIR_CLOSE         = ResultCode(rawValue: (SQLITE_IOERR.rawValue | (17<<8)))
    public static let SQLITE_IOERR_SHMOPEN           = ResultCode(rawValue: (SQLITE_IOERR.rawValue | (18<<8)))
    public static let SQLITE_IOERR_SHMSIZE           = ResultCode(rawValue: (SQLITE_IOERR.rawValue | (19<<8)))
    public static let SQLITE_IOERR_SHMLOCK           = ResultCode(rawValue: (SQLITE_IOERR.rawValue | (20<<8)))
    public static let SQLITE_IOERR_SHMMAP            = ResultCode(rawValue: (SQLITE_IOERR.rawValue | (21<<8)))
    public static let SQLITE_IOERR_SEEK              = ResultCode(rawValue: (SQLITE_IOERR.rawValue | (22<<8)))
    public static let SQLITE_IOERR_DELETE_NOENT      = ResultCode(rawValue: (SQLITE_IOERR.rawValue | (23<<8)))
    public static let SQLITE_IOERR_MMAP              = ResultCode(rawValue: (SQLITE_IOERR.rawValue | (24<<8)))
    public static let SQLITE_IOERR_GETTEMPPATH       = ResultCode(rawValue: (SQLITE_IOERR.rawValue | (25<<8)))
    public static let SQLITE_IOERR_CONVPATH          = ResultCode(rawValue: (SQLITE_IOERR.rawValue | (26<<8)))
    public static let SQLITE_IOERR_VNODE             = ResultCode(rawValue: (SQLITE_IOERR.rawValue | (27<<8)))
    public static let SQLITE_IOERR_AUTH              = ResultCode(rawValue: (SQLITE_IOERR.rawValue | (28<<8)))
    public static let SQLITE_IOERR_BEGIN_ATOMIC      = ResultCode(rawValue: (SQLITE_IOERR.rawValue | (29<<8)))
    public static let SQLITE_IOERR_COMMIT_ATOMIC     = ResultCode(rawValue: (SQLITE_IOERR.rawValue | (30<<8)))
    public static let SQLITE_IOERR_ROLLBACK_ATOMIC   = ResultCode(rawValue: (SQLITE_IOERR.rawValue | (31<<8)))
    public static let SQLITE_LOCKED_SHAREDCACHE      = ResultCode(rawValue: (SQLITE_LOCKED.rawValue |  (1<<8)))
    public static let SQLITE_LOCKED_VTAB             = ResultCode(rawValue: (SQLITE_LOCKED.rawValue |  (2<<8)))
    public static let SQLITE_BUSY_RECOVERY           = ResultCode(rawValue: (SQLITE_BUSY.rawValue |  (1<<8)))
    public static let SQLITE_BUSY_SNAPSHOT           = ResultCode(rawValue: (SQLITE_BUSY.rawValue |  (2<<8)))
    public static let SQLITE_CANTOPEN_NOTEMPDIR      = ResultCode(rawValue: (SQLITE_CANTOPEN.rawValue | (1<<8)))
    public static let SQLITE_CANTOPEN_ISDIR          = ResultCode(rawValue: (SQLITE_CANTOPEN.rawValue | (2<<8)))
    public static let SQLITE_CANTOPEN_FULLPATH       = ResultCode(rawValue: (SQLITE_CANTOPEN.rawValue | (3<<8)))
    public static let SQLITE_CANTOPEN_CONVPATH       = ResultCode(rawValue: (SQLITE_CANTOPEN.rawValue | (4<<8)))
    public static let SQLITE_CANTOPEN_DIRTYWAL       = ResultCode(rawValue: (SQLITE_CANTOPEN.rawValue | (5<<8))) /* Not Used */
    public static let SQLITE_CORRUPT_VTAB            = ResultCode(rawValue: (SQLITE_CORRUPT.rawValue | (1<<8)))
    public static let SQLITE_CORRUPT_SEQUENCE        = ResultCode(rawValue: (SQLITE_CORRUPT.rawValue | (2<<8)))
    public static let SQLITE_READONLY_RECOVERY       = ResultCode(rawValue: (SQLITE_READONLY.rawValue | (1<<8)))
    public static let SQLITE_READONLY_CANTLOCK       = ResultCode(rawValue: (SQLITE_READONLY.rawValue | (2<<8)))
    public static let SQLITE_READONLY_ROLLBACK       = ResultCode(rawValue: (SQLITE_READONLY.rawValue | (3<<8)))
    public static let SQLITE_READONLY_DBMOVED        = ResultCode(rawValue: (SQLITE_READONLY.rawValue | (4<<8)))
    public static let SQLITE_READONLY_CANTINIT       = ResultCode(rawValue: (SQLITE_READONLY.rawValue | (5<<8)))
    public static let SQLITE_READONLY_DIRECTORY      = ResultCode(rawValue: (SQLITE_READONLY.rawValue | (6<<8)))
    public static let SQLITE_ABORT_ROLLBACK          = ResultCode(rawValue: (SQLITE_ABORT.rawValue | (2<<8)))
    public static let SQLITE_CONSTRAINT_CHECK        = ResultCode(rawValue: (SQLITE_CONSTRAINT.rawValue | (1<<8)))
    public static let SQLITE_CONSTRAINT_COMMITHOOK   = ResultCode(rawValue: (SQLITE_CONSTRAINT.rawValue | (2<<8)))
    public static let SQLITE_CONSTRAINT_FOREIGNKEY   = ResultCode(rawValue: (SQLITE_CONSTRAINT.rawValue | (3<<8)))
    public static let SQLITE_CONSTRAINT_FUNCTION     = ResultCode(rawValue: (SQLITE_CONSTRAINT.rawValue | (4<<8)))
    public static let SQLITE_CONSTRAINT_NOTNULL      = ResultCode(rawValue: (SQLITE_CONSTRAINT.rawValue | (5<<8)))
    public static let SQLITE_CONSTRAINT_PRIMARYKEY   = ResultCode(rawValue: (SQLITE_CONSTRAINT.rawValue | (6<<8)))
    public static let SQLITE_CONSTRAINT_TRIGGER      = ResultCode(rawValue: (SQLITE_CONSTRAINT.rawValue | (7<<8)))
    public static let SQLITE_CONSTRAINT_UNIQUE       = ResultCode(rawValue: (SQLITE_CONSTRAINT.rawValue | (8<<8)))
    public static let SQLITE_CONSTRAINT_VTAB         = ResultCode(rawValue: (SQLITE_CONSTRAINT.rawValue | (9<<8)))
    public static let SQLITE_CONSTRAINT_ROWID        = ResultCode(rawValue: (SQLITE_CONSTRAINT.rawValue | (10<<8)))
    public static let SQLITE_NOTICE_RECOVER_WAL      = ResultCode(rawValue: (SQLITE_NOTICE.rawValue | (1<<8)))
    public static let SQLITE_NOTICE_RECOVER_ROLLBACK = ResultCode(rawValue: (SQLITE_NOTICE.rawValue | (2<<8)))
    public static let SQLITE_WARNING_AUTOINDEX       = ResultCode(rawValue: (SQLITE_WARNING.rawValue | (1<<8)))
    public static let SQLITE_AUTH_USER               = ResultCode(rawValue: (SQLITE_AUTH.rawValue | (1<<8)))
    public static let SQLITE_OK_LOAD_PERMANENTLY     = ResultCode(rawValue: (SQLITE_OK.rawValue | (1<<8)))
    // swiftlint:enable operator_usage_whitespace line_length
}

extension ResultCode {
    /// Returns true if the code on the left matches the error on the right.
    ///
    /// Primary result codes match themselves and their extended result codes,
    /// while extended result codes match only themselves.
    ///
    ///     do {
    ///         try ...
    ///     } catch ResultCode.SQLITE_CONSTRAINT_FOREIGNKEY {
    ///         // foreign key constraint error
    ///     } catch ResultCode.SQLITE_CONSTRAINT {
    ///         // any other constraint error
    ///     } catch {
    ///         // any other database error
    ///     }
    public static func ~= (lhs: Self, rhs: Error) -> Bool {
        guard let error = rhs as? DatabaseError else { return false }
        return lhs ~= error.extendedResultCode
    }
}

// CustomStringConvertible
extension ResultCode {
    var errorString: String? {
        String(cString: sqlite3_errstr(rawValue))
    }
    
    /// :nodoc:
    public var description: String {
        if let errorString = errorString {
            return "\(rawValue) (\(errorString))"
        } else {
            return "\(rawValue)"
        }
    }
}

/// DatabaseError wraps an SQLite error.
public struct DatabaseError: Error, CustomStringConvertible, CustomNSError {
    
    /// The SQLite error code (see
    /// <https://www.sqlite.org/rescode.html#primary_result_code_list>).
    ///
    ///     do {
    ///         ...
    ///     } catch let error as DatabaseError where error.resultCode == .SQL_CONSTRAINT {
    ///         // A constraint error
    ///     }
    ///
    /// This property returns a "primary result code", that is to say the least
    /// significant 8 bits of any SQLite result code. See
    /// <https://www.sqlite.org/rescode.html> for more information.
    ///
    /// See also `extendedResultCode`.
    public var resultCode: ResultCode {
        extendedResultCode.primaryResultCode
    }
    
    /// The SQLite extended error code (see
    /// <https://www.sqlite.org/rescode.html#extended_result_code_list>).
    ///
    ///     do {
    ///         ...
    ///     } catch let error as DatabaseError where error.extendedResultCode == .SQLITE_CONSTRAINT_FOREIGNKEY {
    ///         // A foreign key constraint error
    ///     }
    ///
    /// See also `resultCode`.
    public let extendedResultCode: ResultCode
    
    /// The SQLite error message.
    public let message: String?
    
    /// The SQL query that yielded the error (if relevant).
    public let sql: String?
    
    /// The query arguments that yielded the error (if relevant).
    public let arguments: StatementArguments?
    
    /// Creates a Database Error
    public init(
        resultCode: ResultCode = .SQLITE_ERROR,
        message: String? = nil,
        sql: String? = nil,
        arguments: StatementArguments? = nil)
    {
        self.extendedResultCode = resultCode
        self.message = message ?? resultCode.errorString
        self.sql = sql
        self.arguments = arguments
    }
    
    /// Creates a Database Error with a raw CInt result code.
    ///
    /// This initializer is not public because library user is not supposed to
    /// be exposed to raw result codes.
    @usableFromInline
    init(resultCode: CInt, message: String? = nil, sql: String? = nil, arguments: StatementArguments? = nil) {
        self.init(resultCode: ResultCode(rawValue: resultCode), message: message, sql: sql, arguments: arguments)
    }
    
    static func noSuchTable(_ tableName: String) -> Self {
        DatabaseError(message: "no such table: \(tableName)")
    }
}

extension DatabaseError {
    static func connectionIsClosed() -> Self {
        DatabaseError(resultCode: .SQLITE_MISUSE, message: "Connection is closed")
    }
}

// Support for `catch DatabaseError.SQLITE_XXX`
extension DatabaseError {
    public static let SQLITE_OK = ResultCode.SQLITE_OK
    public static let SQLITE_ERROR = ResultCode.SQLITE_ERROR
    public static let SQLITE_INTERNAL = ResultCode.SQLITE_INTERNAL
    public static let SQLITE_PERM = ResultCode.SQLITE_PERM
    public static let SQLITE_ABORT = ResultCode.SQLITE_ABORT
    public static let SQLITE_BUSY = ResultCode.SQLITE_BUSY
    public static let SQLITE_LOCKED = ResultCode.SQLITE_LOCKED
    public static let SQLITE_NOMEM = ResultCode.SQLITE_NOMEM
    public static let SQLITE_READONLY = ResultCode.SQLITE_READONLY
    public static let SQLITE_INTERRUPT = ResultCode.SQLITE_INTERRUPT
    public static let SQLITE_IOERR = ResultCode.SQLITE_IOERR
    public static let SQLITE_CORRUPT = ResultCode.SQLITE_CORRUPT
    public static let SQLITE_NOTFOUND = ResultCode.SQLITE_NOTFOUND
    public static let SQLITE_FULL = ResultCode.SQLITE_FULL
    public static let SQLITE_CANTOPEN = ResultCode.SQLITE_CANTOPEN
    public static let SQLITE_PROTOCOL = ResultCode.SQLITE_PROTOCOL
    public static let SQLITE_EMPTY = ResultCode.SQLITE_EMPTY
    public static let SQLITE_SCHEMA = ResultCode.SQLITE_SCHEMA
    public static let SQLITE_TOOBIG = ResultCode.SQLITE_TOOBIG
    public static let SQLITE_CONSTRAINT = ResultCode.SQLITE_CONSTRAINT
    public static let SQLITE_MISMATCH = ResultCode.SQLITE_MISMATCH
    public static let SQLITE_MISUSE = ResultCode.SQLITE_MISUSE
    public static let SQLITE_NOLFS = ResultCode.SQLITE_NOLFS
    public static let SQLITE_AUTH = ResultCode.SQLITE_AUTH
    public static let SQLITE_FORMAT = ResultCode.SQLITE_FORMAT
    public static let SQLITE_RANGE = ResultCode.SQLITE_RANGE
    public static let SQLITE_NOTADB = ResultCode.SQLITE_NOTADB
    public static let SQLITE_NOTICE = ResultCode.SQLITE_NOTICE
    public static let SQLITE_WARNING = ResultCode.SQLITE_WARNING
    public static let SQLITE_ROW = ResultCode.SQLITE_ROW
    public static let SQLITE_DONE = ResultCode.SQLITE_DONE
    public static let SQLITE_ERROR_MISSING_COLLSEQ = ResultCode.SQLITE_ERROR_MISSING_COLLSEQ
    public static let SQLITE_ERROR_RETRY = ResultCode.SQLITE_ERROR_RETRY
    public static let SQLITE_ERROR_SNAPSHOT = ResultCode.SQLITE_ERROR_SNAPSHOT
    public static let SQLITE_IOERR_READ = ResultCode.SQLITE_IOERR_READ
    public static let SQLITE_IOERR_SHORT_READ = ResultCode.SQLITE_IOERR_SHORT_READ
    public static let SQLITE_IOERR_WRITE = ResultCode.SQLITE_IOERR_WRITE
    public static let SQLITE_IOERR_FSYNC = ResultCode.SQLITE_IOERR_FSYNC
    public static let SQLITE_IOERR_DIR_FSYNC = ResultCode.SQLITE_IOERR_DIR_FSYNC
    public static let SQLITE_IOERR_TRUNCATE = ResultCode.SQLITE_IOERR_TRUNCATE
    public static let SQLITE_IOERR_FSTAT = ResultCode.SQLITE_IOERR_FSTAT
    public static let SQLITE_IOERR_UNLOCK = ResultCode.SQLITE_IOERR_UNLOCK
    public static let SQLITE_IOERR_RDLOCK = ResultCode.SQLITE_IOERR_RDLOCK
    public static let SQLITE_IOERR_DELETE = ResultCode.SQLITE_IOERR_DELETE
    public static let SQLITE_IOERR_BLOCKED = ResultCode.SQLITE_IOERR_BLOCKED
    public static let SQLITE_IOERR_NOMEM = ResultCode.SQLITE_IOERR_NOMEM
    public static let SQLITE_IOERR_ACCESS = ResultCode.SQLITE_IOERR_ACCESS
    public static let SQLITE_IOERR_CHECKRESERVEDLOCK = ResultCode.SQLITE_IOERR_CHECKRESERVEDLOCK
    public static let SQLITE_IOERR_LOCK = ResultCode.SQLITE_IOERR_LOCK
    public static let SQLITE_IOERR_CLOSE = ResultCode.SQLITE_IOERR_CLOSE
    public static let SQLITE_IOERR_DIR_CLOSE = ResultCode.SQLITE_IOERR_DIR_CLOSE
    public static let SQLITE_IOERR_SHMOPEN = ResultCode.SQLITE_IOERR_SHMOPEN
    public static let SQLITE_IOERR_SHMSIZE = ResultCode.SQLITE_IOERR_SHMSIZE
    public static let SQLITE_IOERR_SHMLOCK = ResultCode.SQLITE_IOERR_SHMLOCK
    public static let SQLITE_IOERR_SHMMAP = ResultCode.SQLITE_IOERR_SHMMAP
    public static let SQLITE_IOERR_SEEK = ResultCode.SQLITE_IOERR_SEEK
    public static let SQLITE_IOERR_DELETE_NOENT = ResultCode.SQLITE_IOERR_DELETE_NOENT
    public static let SQLITE_IOERR_MMAP = ResultCode.SQLITE_IOERR_MMAP
    public static let SQLITE_IOERR_GETTEMPPATH = ResultCode.SQLITE_IOERR_GETTEMPPATH
    public static let SQLITE_IOERR_CONVPATH = ResultCode.SQLITE_IOERR_CONVPATH
    public static let SQLITE_IOERR_VNODE = ResultCode.SQLITE_IOERR_VNODE
    public static let SQLITE_IOERR_AUTH = ResultCode.SQLITE_IOERR_AUTH
    public static let SQLITE_IOERR_BEGIN_ATOMIC = ResultCode.SQLITE_IOERR_BEGIN_ATOMIC
    public static let SQLITE_IOERR_COMMIT_ATOMIC = ResultCode.SQLITE_IOERR_COMMIT_ATOMIC
    public static let SQLITE_IOERR_ROLLBACK_ATOMIC = ResultCode.SQLITE_IOERR_ROLLBACK_ATOMIC
    public static let SQLITE_LOCKED_SHAREDCACHE = ResultCode.SQLITE_LOCKED_SHAREDCACHE
    public static let SQLITE_LOCKED_VTAB = ResultCode.SQLITE_LOCKED_VTAB
    public static let SQLITE_BUSY_RECOVERY = ResultCode.SQLITE_BUSY_RECOVERY
    public static let SQLITE_BUSY_SNAPSHOT = ResultCode.SQLITE_BUSY_SNAPSHOT
    public static let SQLITE_CANTOPEN_NOTEMPDIR = ResultCode.SQLITE_CANTOPEN_NOTEMPDIR
    public static let SQLITE_CANTOPEN_ISDIR = ResultCode.SQLITE_CANTOPEN_ISDIR
    public static let SQLITE_CANTOPEN_FULLPATH = ResultCode.SQLITE_CANTOPEN_FULLPATH
    public static let SQLITE_CANTOPEN_CONVPATH = ResultCode.SQLITE_CANTOPEN_CONVPATH
    public static let SQLITE_CANTOPEN_DIRTYWAL = ResultCode.SQLITE_CANTOPEN_DIRTYWAL
    public static let SQLITE_CORRUPT_VTAB = ResultCode.SQLITE_CORRUPT_VTAB
    public static let SQLITE_CORRUPT_SEQUENCE = ResultCode.SQLITE_CORRUPT_SEQUENCE
    public static let SQLITE_READONLY_RECOVERY = ResultCode.SQLITE_READONLY_RECOVERY
    public static let SQLITE_READONLY_CANTLOCK = ResultCode.SQLITE_READONLY_CANTLOCK
    public static let SQLITE_READONLY_ROLLBACK = ResultCode.SQLITE_READONLY_ROLLBACK
    public static let SQLITE_READONLY_DBMOVED = ResultCode.SQLITE_READONLY_DBMOVED
    public static let SQLITE_READONLY_CANTINIT = ResultCode.SQLITE_READONLY_CANTINIT
    public static let SQLITE_READONLY_DIRECTORY = ResultCode.SQLITE_READONLY_DIRECTORY
    public static let SQLITE_ABORT_ROLLBACK = ResultCode.SQLITE_ABORT_ROLLBACK
    public static let SQLITE_CONSTRAINT_CHECK = ResultCode.SQLITE_CONSTRAINT_CHECK
    public static let SQLITE_CONSTRAINT_COMMITHOOK = ResultCode.SQLITE_CONSTRAINT_COMMITHOOK
    public static let SQLITE_CONSTRAINT_FOREIGNKEY = ResultCode.SQLITE_CONSTRAINT_FOREIGNKEY
    public static let SQLITE_CONSTRAINT_FUNCTION = ResultCode.SQLITE_CONSTRAINT_FUNCTION
    public static let SQLITE_CONSTRAINT_NOTNULL = ResultCode.SQLITE_CONSTRAINT_NOTNULL
    public static let SQLITE_CONSTRAINT_PRIMARYKEY = ResultCode.SQLITE_CONSTRAINT_PRIMARYKEY
    public static let SQLITE_CONSTRAINT_TRIGGER = ResultCode.SQLITE_CONSTRAINT_TRIGGER
    public static let SQLITE_CONSTRAINT_UNIQUE = ResultCode.SQLITE_CONSTRAINT_UNIQUE
    public static let SQLITE_CONSTRAINT_VTAB = ResultCode.SQLITE_CONSTRAINT_VTAB
    public static let SQLITE_CONSTRAINT_ROWID = ResultCode.SQLITE_CONSTRAINT_ROWID
    public static let SQLITE_NOTICE_RECOVER_WAL = ResultCode.SQLITE_NOTICE_RECOVER_WAL
    public static let SQLITE_NOTICE_RECOVER_ROLLBACK = ResultCode.SQLITE_NOTICE_RECOVER_ROLLBACK
    public static let SQLITE_WARNING_AUTOINDEX = ResultCode.SQLITE_WARNING_AUTOINDEX
    public static let SQLITE_AUTH_USER = ResultCode.SQLITE_AUTH_USER
    public static let SQLITE_OK_LOAD_PERMANENTLY = ResultCode.SQLITE_OK_LOAD_PERMANENTLY
}

extension DatabaseError {
    /// Returns true if the error has code `SQLITE_ABORT` or `SQLITE_INTERRUPT`.
    ///
    /// Such an error can be thrown when a database has been interrupted, or
    /// when the database is suspended.
    ///
    /// See `DatabaseReader.interrupt()` and `DatabaseReader.suspend()` for
    /// more information.
    public var isInterruptionError: Bool {
        switch resultCode {
        case .SQLITE_ABORT, .SQLITE_INTERRUPT:
            return true
        default:
            return false
        }
    }
}

// CustomStringConvertible
extension DatabaseError {
    /// :nodoc:
    public var description: String {
        var description = "SQLite error \(resultCode.rawValue)"
        if let message = message {
            description += ": \(message)"
        }
        if let sql = sql {
            description += " - while executing `\(sql)`"
        }
        if let arguments = arguments, !arguments.isEmpty {
            description += " with arguments \(arguments)"
        }
        return description
    }
}

// CustomNSError
extension DatabaseError {
    
    /// NSError bridging: the domain of the error.
    /// :nodoc:
    public static var errorDomain: String { "GRDB.DatabaseError" }
    
    /// NSError bridging: the error code within the given domain.
    /// :nodoc:
    public var errorCode: Int { Int(extendedResultCode.rawValue) }
    
    /// NSError bridging: the user-info dictionary.
    /// :nodoc:
    public var errorUserInfo: [String: Any] { [NSLocalizedDescriptionKey: description] }
}

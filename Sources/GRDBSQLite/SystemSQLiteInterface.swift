#if canImport(SQLite3)
import SQLite3

@available(macOS 14.2, iOS 16, *)
public enum SystemSQLiteInterface : SQLiteInterface {
    case system


    public var SQLITE_VERSION: String { SQLite3.SQLITE_VERSION }
    public var SQLITE_VERSION_NUMBER: Int32 { SQLite3.SQLITE_VERSION_NUMBER }
    public var SQLITE_SOURCE_ID: String { SQLite3.SQLITE_SOURCE_ID }
    //let sqlite3_version: <<error type>>
    public func sqlite3_libversion() -> UnsafePointer<CChar>! { SQLite3.sqlite3_libversion() }

    public func sqlite3_sourceid() -> UnsafePointer<CChar>! { SQLite3.sqlite3_sourceid() }
    public func sqlite3_libversion_number() -> Int32 { SQLite3.sqlite3_libversion_number() }

    public func sqlite3_compileoption_used(_ zOptName: UnsafePointer<CChar>!) -> Int32 { SQLite3.sqlite3_compileoption_used(zOptName) }

    public func sqlite3_compileoption_get(_ N: Int32) -> UnsafePointer<CChar>! { SQLite3.sqlite3_compileoption_get(N) }
    public func sqlite3_threadsafe() -> Int32 { SQLite3.sqlite3_threadsafe() }
    public typealias sqlite_int64 = Int64
    public typealias sqlite_uint64 = UInt64
    public typealias sqlite3_int64 = sqlite_int64
    public typealias sqlite3_uint64 = sqlite_uint64
    public func sqlite3_close(_ p0: OpaquePointer!) -> Int32 { SQLite3.sqlite3_close(p0) }

    public func sqlite3_close_v2(_ p0: OpaquePointer!) -> Int32 { SQLite3.sqlite3_close_v2(p0) }
    public typealias sqlite3_callback = @convention(c) (UnsafeMutableRawPointer?, Int32, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32
    public func sqlite3_exec(_ p0: OpaquePointer!, _ sql: UnsafePointer<CChar>!, _ callback: (@convention(c) (UnsafeMutableRawPointer?, Int32, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32)!, _ p1: UnsafeMutableRawPointer!, _ errmsg: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>!) -> Int32 { SQLite3.sqlite3_exec(p0, sql, callback, p1, errmsg) }
    public var SQLITE_OK: Int32 { SQLite3.SQLITE_OK }
    public var SQLITE_ERROR: Int32 { SQLite3.SQLITE_ERROR }
    public var SQLITE_INTERNAL: Int32 { SQLite3.SQLITE_INTERNAL }
    public var SQLITE_PERM: Int32 { SQLite3.SQLITE_PERM }
    public var SQLITE_ABORT: Int32 { SQLite3.SQLITE_ABORT }
    public var SQLITE_BUSY: Int32 { SQLite3.SQLITE_BUSY }
    public var SQLITE_LOCKED: Int32 { SQLite3.SQLITE_LOCKED }
    public var SQLITE_NOMEM: Int32 { SQLite3.SQLITE_NOMEM }
    public var SQLITE_READONLY: Int32 { SQLite3.SQLITE_READONLY }
    public var SQLITE_INTERRUPT: Int32 { SQLite3.SQLITE_INTERRUPT }
    public var SQLITE_IOERR: Int32 { SQLite3.SQLITE_IOERR }
    public var SQLITE_CORRUPT: Int32 { SQLite3.SQLITE_CORRUPT }
    public var SQLITE_NOTFOUND: Int32 { SQLite3.SQLITE_NOTFOUND }
    public var SQLITE_FULL: Int32 { SQLite3.SQLITE_FULL }
    public var SQLITE_CANTOPEN: Int32 { SQLite3.SQLITE_CANTOPEN }
    public var SQLITE_PROTOCOL: Int32 { SQLite3.SQLITE_PROTOCOL }
    public var SQLITE_EMPTY: Int32 { SQLite3.SQLITE_EMPTY }
    public var SQLITE_SCHEMA: Int32 { SQLite3.SQLITE_SCHEMA }
    public var SQLITE_TOOBIG: Int32 { SQLite3.SQLITE_TOOBIG }
    public var SQLITE_CONSTRAINT: Int32 { SQLite3.SQLITE_CONSTRAINT }
    public var SQLITE_MISMATCH: Int32 { SQLite3.SQLITE_MISMATCH }
    public var SQLITE_MISUSE: Int32 { SQLite3.SQLITE_MISUSE }
    public var SQLITE_NOLFS: Int32 { SQLite3.SQLITE_NOLFS }
    public var SQLITE_AUTH: Int32 { SQLite3.SQLITE_AUTH }
    public var SQLITE_FORMAT: Int32 { SQLite3.SQLITE_FORMAT }
    public var SQLITE_RANGE: Int32 { SQLite3.SQLITE_RANGE }
    public var SQLITE_NOTADB: Int32 { SQLite3.SQLITE_NOTADB }
    public var SQLITE_NOTICE: Int32 { SQLite3.SQLITE_NOTICE }
    public var SQLITE_WARNING: Int32 { SQLite3.SQLITE_WARNING }
    public var SQLITE_ROW: Int32 { SQLite3.SQLITE_ROW }
    public var SQLITE_DONE: Int32 { SQLite3.SQLITE_DONE }
    public var SQLITE_OPEN_READONLY: Int32 { SQLite3.SQLITE_OPEN_READONLY }
    public var SQLITE_OPEN_READWRITE: Int32 { SQLite3.SQLITE_OPEN_READWRITE }
    public var SQLITE_OPEN_CREATE: Int32 { SQLite3.SQLITE_OPEN_CREATE }
    public var SQLITE_OPEN_DELETEONCLOSE: Int32 { SQLite3.SQLITE_OPEN_DELETEONCLOSE }
    public var SQLITE_OPEN_EXCLUSIVE: Int32 { SQLite3.SQLITE_OPEN_EXCLUSIVE }
    public var SQLITE_OPEN_AUTOPROXY: Int32 { SQLite3.SQLITE_OPEN_AUTOPROXY }
    public var SQLITE_OPEN_URI: Int32 { SQLite3.SQLITE_OPEN_URI }
    public var SQLITE_OPEN_MEMORY: Int32 { SQLite3.SQLITE_OPEN_MEMORY }
    public var SQLITE_OPEN_MAIN_DB: Int32 { SQLite3.SQLITE_OPEN_MAIN_DB }
    public var SQLITE_OPEN_TEMP_DB: Int32 { SQLite3.SQLITE_OPEN_TEMP_DB }
    public var SQLITE_OPEN_TRANSIENT_DB: Int32 { SQLite3.SQLITE_OPEN_TRANSIENT_DB }
    public var SQLITE_OPEN_MAIN_JOURNAL: Int32 { SQLite3.SQLITE_OPEN_MAIN_JOURNAL }
    public var SQLITE_OPEN_TEMP_JOURNAL: Int32 { SQLite3.SQLITE_OPEN_TEMP_JOURNAL }
    public var SQLITE_OPEN_SUBJOURNAL: Int32 { SQLite3.SQLITE_OPEN_SUBJOURNAL }
    public var SQLITE_OPEN_SUPER_JOURNAL: Int32 { SQLite3.SQLITE_OPEN_SUPER_JOURNAL }
    public var SQLITE_OPEN_NOMUTEX: Int32 { SQLite3.SQLITE_OPEN_NOMUTEX }
    public var SQLITE_OPEN_FULLMUTEX: Int32 { SQLite3.SQLITE_OPEN_FULLMUTEX }
    public var SQLITE_OPEN_SHAREDCACHE: Int32 { SQLite3.SQLITE_OPEN_SHAREDCACHE }
    public var SQLITE_OPEN_PRIVATECACHE: Int32 { SQLite3.SQLITE_OPEN_PRIVATECACHE }
    public var SQLITE_OPEN_WAL: Int32 { SQLite3.SQLITE_OPEN_WAL }
    public var SQLITE_OPEN_FILEPROTECTION_COMPLETE: Int32 { SQLite3.SQLITE_OPEN_FILEPROTECTION_COMPLETE }
    public var SQLITE_OPEN_FILEPROTECTION_COMPLETEUNLESSOPEN: Int32 { SQLite3.SQLITE_OPEN_FILEPROTECTION_COMPLETEUNLESSOPEN }
    public var SQLITE_OPEN_FILEPROTECTION_COMPLETEUNTILFIRSTUSERAUTHENTICATION: Int32 { SQLite3.SQLITE_OPEN_FILEPROTECTION_COMPLETEUNTILFIRSTUSERAUTHENTICATION }
    public var SQLITE_OPEN_FILEPROTECTION_NONE: Int32 { SQLite3.SQLITE_OPEN_FILEPROTECTION_NONE }
    public var SQLITE_OPEN_FILEPROTECTION_MASK: Int32 { SQLite3.SQLITE_OPEN_FILEPROTECTION_MASK }
    public var SQLITE_OPEN_NOFOLLOW: Int32 { SQLite3.SQLITE_OPEN_NOFOLLOW }
    public var SQLITE_OPEN_EXRESCODE: Int32 { SQLite3.SQLITE_OPEN_EXRESCODE }
    public var SQLITE_OPEN_MASTER_JOURNAL: Int32 { SQLite3.SQLITE_OPEN_MASTER_JOURNAL }
    public var SQLITE_IOCAP_ATOMIC: Int32 { SQLite3.SQLITE_IOCAP_ATOMIC }
    public var SQLITE_IOCAP_ATOMIC512: Int32 { SQLite3.SQLITE_IOCAP_ATOMIC512 }
    public var SQLITE_IOCAP_ATOMIC1K: Int32 { SQLite3.SQLITE_IOCAP_ATOMIC1K }
    public var SQLITE_IOCAP_ATOMIC2K: Int32 { SQLite3.SQLITE_IOCAP_ATOMIC2K }
    public var SQLITE_IOCAP_ATOMIC4K: Int32 { SQLite3.SQLITE_IOCAP_ATOMIC4K }
    public var SQLITE_IOCAP_ATOMIC8K: Int32 { SQLite3.SQLITE_IOCAP_ATOMIC8K }
    public var SQLITE_IOCAP_ATOMIC16K: Int32 { SQLite3.SQLITE_IOCAP_ATOMIC16K }
    public var SQLITE_IOCAP_ATOMIC32K: Int32 { SQLite3.SQLITE_IOCAP_ATOMIC32K }
    public var SQLITE_IOCAP_ATOMIC64K: Int32 { SQLite3.SQLITE_IOCAP_ATOMIC64K }
    public var SQLITE_IOCAP_SAFE_APPEND: Int32 { SQLite3.SQLITE_IOCAP_SAFE_APPEND }
    public var SQLITE_IOCAP_SEQUENTIAL: Int32 { SQLite3.SQLITE_IOCAP_SEQUENTIAL }
    public var SQLITE_IOCAP_UNDELETABLE_WHEN_OPEN: Int32 { SQLite3.SQLITE_IOCAP_UNDELETABLE_WHEN_OPEN }
    public var SQLITE_IOCAP_POWERSAFE_OVERWRITE: Int32 { SQLite3.SQLITE_IOCAP_POWERSAFE_OVERWRITE }
    public var SQLITE_IOCAP_IMMUTABLE: Int32 { SQLite3.SQLITE_IOCAP_IMMUTABLE }
    public var SQLITE_IOCAP_BATCH_ATOMIC: Int32 { SQLite3.SQLITE_IOCAP_BATCH_ATOMIC }
    public var SQLITE_LOCK_NONE: Int32 { SQLite3.SQLITE_LOCK_NONE }
    public var SQLITE_LOCK_SHARED: Int32 { SQLite3.SQLITE_LOCK_SHARED }
    public var SQLITE_LOCK_RESERVED: Int32 { SQLite3.SQLITE_LOCK_RESERVED }
    public var SQLITE_LOCK_PENDING: Int32 { SQLite3.SQLITE_LOCK_PENDING }
    public var SQLITE_LOCK_EXCLUSIVE: Int32 { SQLite3.SQLITE_LOCK_EXCLUSIVE }
    public var SQLITE_SYNC_NORMAL: Int32 { SQLite3.SQLITE_SYNC_NORMAL }
    public var SQLITE_SYNC_FULL: Int32 { SQLite3.SQLITE_SYNC_FULL }
    public var SQLITE_SYNC_DATAONLY: Int32 { SQLite3.SQLITE_SYNC_DATAONLY }
    //struct sqlite3_file {
    //
    //    public init()
    //
    //    public init(pMethods: UnsafePointer<sqlite3_io_methods>!)
    //
    //    public var pMethods: UnsafePointer<sqlite3_io_methods>!
    //}
    //struct sqlite3_io_methods {
    //
    //    public init()
    //
    //    public init(iVersion: Int32, xClose: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?) -> Int32)!, xRead: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, UnsafeMutableRawPointer?, Int32, sqlite3_int64) -> Int32)!, xWrite: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, UnsafeRawPointer?, Int32, sqlite3_int64) -> Int32)!, xTruncate: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, sqlite3_int64) -> Int32)!, xSync: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, Int32) -> Int32)!, xFileSize: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, UnsafeMutablePointer<sqlite3_int64>?) -> Int32)!, xLock: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, Int32) -> Int32)!, xUnlock: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, Int32) -> Int32)!, xCheckReservedLock: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, UnsafeMutablePointer<Int32>?) -> Int32)!, xFileControl: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, Int32, UnsafeMutableRawPointer?) -> Int32)!, xSectorSize: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?) -> Int32)!, xDeviceCharacteristics: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?) -> Int32)!, xShmMap: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, Int32, Int32, Int32, UnsafeMutablePointer<UnsafeMutableRawPointer?>?) -> Int32)!, xShmLock: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, Int32, Int32, Int32) -> Int32)!, xShmBarrier: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?) -> Void)!, xShmUnmap: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, Int32) -> Int32)!, xFetch: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, sqlite3_int64, Int32, UnsafeMutablePointer<UnsafeMutableRawPointer?>?) -> Int32)!, xUnfetch: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, sqlite3_int64, UnsafeMutableRawPointer?) -> Int32)!)
    //
    //    public var iVersion: Int32
    //
    //    public var xClose: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?) -> Int32)!
    //
    //    public var xRead: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, UnsafeMutableRawPointer?, Int32, sqlite3_int64) -> Int32)!
    //
    //    public var xWrite: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, UnsafeRawPointer?, Int32, sqlite3_int64) -> Int32)!
    //
    //    public var xTruncate: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, sqlite3_int64) -> Int32)!
    //
    //    public var xSync: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, Int32) -> Int32)!
    //
    //    public var xFileSize: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, UnsafeMutablePointer<sqlite3_int64>?) -> Int32)!
    //
    //    public var xLock: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, Int32) -> Int32)!
    //
    //    public var xUnlock: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, Int32) -> Int32)!
    //
    //    public var xCheckReservedLock: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, UnsafeMutablePointer<Int32>?) -> Int32)!
    //
    //    public var xFileControl: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, Int32, UnsafeMutableRawPointer?) -> Int32)!
    //
    //    public var xSectorSize: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?) -> Int32)!
    //
    //    public var xDeviceCharacteristics: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?) -> Int32)!
    //
    //    public var xShmMap: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, Int32, Int32, Int32, UnsafeMutablePointer<UnsafeMutableRawPointer?>?) -> Int32)!
    //
    //    public var xShmLock: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, Int32, Int32, Int32) -> Int32)!
    //
    //    public var xShmBarrier: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?) -> Void)!
    //
    //    public var xShmUnmap: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, Int32) -> Int32)!
    //
    //    public var xFetch: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, sqlite3_int64, Int32, UnsafeMutablePointer<UnsafeMutableRawPointer?>?) -> Int32)!
    //
    //    public var xUnfetch: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, sqlite3_int64, UnsafeMutableRawPointer?) -> Int32)!
    //}
    public var SQLITE_FCNTL_LOCKSTATE: Int32 { SQLite3.SQLITE_FCNTL_LOCKSTATE }
    public var SQLITE_FCNTL_GET_LOCKPROXYFILE: Int32 { SQLite3.SQLITE_FCNTL_GET_LOCKPROXYFILE }
    public var SQLITE_FCNTL_SET_LOCKPROXYFILE: Int32 { SQLite3.SQLITE_FCNTL_SET_LOCKPROXYFILE }
    public var SQLITE_FCNTL_LAST_ERRNO: Int32 { SQLite3.SQLITE_FCNTL_LAST_ERRNO }
    public var SQLITE_FCNTL_SIZE_HINT: Int32 { SQLite3.SQLITE_FCNTL_SIZE_HINT }
    public var SQLITE_FCNTL_CHUNK_SIZE: Int32 { SQLite3.SQLITE_FCNTL_CHUNK_SIZE }
    public var SQLITE_FCNTL_FILE_POINTER: Int32 { SQLite3.SQLITE_FCNTL_FILE_POINTER }
    public var SQLITE_FCNTL_SYNC_OMITTED: Int32 { SQLite3.SQLITE_FCNTL_SYNC_OMITTED }
    public var SQLITE_FCNTL_WIN32_AV_RETRY: Int32 { SQLite3.SQLITE_FCNTL_WIN32_AV_RETRY }
    public var SQLITE_FCNTL_PERSIST_WAL: Int32 { SQLite3.SQLITE_FCNTL_PERSIST_WAL }
    public var SQLITE_FCNTL_OVERWRITE: Int32 { SQLite3.SQLITE_FCNTL_OVERWRITE }
    public var SQLITE_FCNTL_VFSNAME: Int32 { SQLite3.SQLITE_FCNTL_VFSNAME }
    public var SQLITE_FCNTL_POWERSAFE_OVERWRITE: Int32 { SQLite3.SQLITE_FCNTL_POWERSAFE_OVERWRITE }
    public var SQLITE_FCNTL_PRAGMA: Int32 { SQLite3.SQLITE_FCNTL_PRAGMA }
    public var SQLITE_FCNTL_BUSYHANDLER: Int32 { SQLite3.SQLITE_FCNTL_BUSYHANDLER }
    public var SQLITE_FCNTL_TEMPFILENAME: Int32 { SQLite3.SQLITE_FCNTL_TEMPFILENAME }
    public var SQLITE_FCNTL_MMAP_SIZE: Int32 { SQLite3.SQLITE_FCNTL_MMAP_SIZE }
    public var SQLITE_FCNTL_TRACE: Int32 { SQLite3.SQLITE_FCNTL_TRACE }
    public var SQLITE_FCNTL_HAS_MOVED: Int32 { SQLite3.SQLITE_FCNTL_HAS_MOVED }
    public var SQLITE_FCNTL_SYNC: Int32 { SQLite3.SQLITE_FCNTL_SYNC }
    public var SQLITE_FCNTL_COMMIT_PHASETWO: Int32 { SQLite3.SQLITE_FCNTL_COMMIT_PHASETWO }
    public var SQLITE_FCNTL_WIN32_SET_HANDLE: Int32 { SQLite3.SQLITE_FCNTL_WIN32_SET_HANDLE }
    public var SQLITE_FCNTL_WAL_BLOCK: Int32 { SQLite3.SQLITE_FCNTL_WAL_BLOCK }
    public var SQLITE_FCNTL_ZIPVFS: Int32 { SQLite3.SQLITE_FCNTL_ZIPVFS }
    public var SQLITE_FCNTL_RBU: Int32 { SQLite3.SQLITE_FCNTL_RBU }
    public var SQLITE_FCNTL_VFS_POINTER: Int32 { SQLite3.SQLITE_FCNTL_VFS_POINTER }
    public var SQLITE_FCNTL_JOURNAL_POINTER: Int32 { SQLite3.SQLITE_FCNTL_JOURNAL_POINTER }
    public var SQLITE_FCNTL_WIN32_GET_HANDLE: Int32 { SQLite3.SQLITE_FCNTL_WIN32_GET_HANDLE }
    public var SQLITE_FCNTL_PDB: Int32 { SQLite3.SQLITE_FCNTL_PDB }
    public var SQLITE_FCNTL_BEGIN_ATOMIC_WRITE: Int32 { SQLite3.SQLITE_FCNTL_BEGIN_ATOMIC_WRITE }
    public var SQLITE_FCNTL_COMMIT_ATOMIC_WRITE: Int32 { SQLite3.SQLITE_FCNTL_COMMIT_ATOMIC_WRITE }
    public var SQLITE_FCNTL_ROLLBACK_ATOMIC_WRITE: Int32 { SQLite3.SQLITE_FCNTL_ROLLBACK_ATOMIC_WRITE }
    public var SQLITE_FCNTL_LOCK_TIMEOUT: Int32 { SQLite3.SQLITE_FCNTL_LOCK_TIMEOUT }
    public var SQLITE_FCNTL_DATA_VERSION: Int32 { SQLite3.SQLITE_FCNTL_DATA_VERSION }
    public var SQLITE_FCNTL_SIZE_LIMIT: Int32 { SQLite3.SQLITE_FCNTL_SIZE_LIMIT }
    public var SQLITE_FCNTL_CKPT_DONE: Int32 { SQLite3.SQLITE_FCNTL_CKPT_DONE }
    public var SQLITE_FCNTL_RESERVE_BYTES: Int32 { SQLite3.SQLITE_FCNTL_RESERVE_BYTES }
    public var SQLITE_FCNTL_CKPT_START: Int32 { SQLite3.SQLITE_FCNTL_CKPT_START }
    public var SQLITE_FCNTL_EXTERNAL_READER: Int32 { SQLite3.SQLITE_FCNTL_EXTERNAL_READER }
    public var SQLITE_FCNTL_CKSM_FILE: Int32 { SQLite3.SQLITE_FCNTL_CKSM_FILE }
    public var SQLITE_FCNTL_RESET_CACHE: Int32 { SQLite3.SQLITE_FCNTL_RESET_CACHE }
    public var SQLITE_GET_LOCKPROXYFILE: Int32 { SQLite3.SQLITE_GET_LOCKPROXYFILE }
    public var SQLITE_SET_LOCKPROXYFILE: Int32 { SQLite3.SQLITE_SET_LOCKPROXYFILE }
    public var SQLITE_LAST_ERRNO: Int32 { SQLite3.SQLITE_LAST_ERRNO }
    public typealias sqlite3_filename = UnsafePointer<CChar>
    public typealias sqlite3_syscall_ptr = @convention(c) () -> Void
    //struct sqlite3_vfs {
    //
    //    public init()
    //
    //    public init(iVersion: Int32, szOsFile: Int32, mxPathname: Int32, pNext: UnsafeMutablePointer<sqlite3_vfs>!, zName: UnsafePointer<CChar>!, pAppData: UnsafeMutableRawPointer!, xOpen: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, sqlite3_filename?, UnsafeMutablePointer<sqlite3_file>?, Int32, UnsafeMutablePointer<Int32>?) -> Int32)!, xDelete: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, UnsafePointer<CChar>?, Int32) -> Int32)!, xAccess: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, UnsafePointer<CChar>?, Int32, UnsafeMutablePointer<Int32>?) -> Int32)!, xFullPathname: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, UnsafePointer<CChar>?, Int32, UnsafeMutablePointer<CChar>?) -> Int32)!, xDlOpen: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, UnsafePointer<CChar>?) -> UnsafeMutableRawPointer?)!, xDlError: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, Int32, UnsafeMutablePointer<CChar>?) -> Void)!, xDlSym: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, UnsafeMutableRawPointer?, UnsafePointer<CChar>?) -> (@convention(c) () -> Void)?)!, xDlClose: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, UnsafeMutableRawPointer?) -> Void)!, xRandomness: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, Int32, UnsafeMutablePointer<CChar>?) -> Int32)!, xSleep: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, Int32) -> Int32)!, xCurrentTime: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, UnsafeMutablePointer<Double>?) -> Int32)!, xGetLastError: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, Int32, UnsafeMutablePointer<CChar>?) -> Int32)!, xCurrentTimeInt64: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, UnsafeMutablePointer<sqlite3_int64>?) -> Int32)!, xSetSystemCall: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, UnsafePointer<CChar>?, sqlite3_syscall_ptr?) -> Int32)!, xGetSystemCall: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, UnsafePointer<CChar>?) -> sqlite3_syscall_ptr?)!, xNextSystemCall: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, UnsafePointer<CChar>?) -> UnsafePointer<CChar>?)!)
    //
    //    public var iVersion: Int32
    //
    //    public var szOsFile: Int32
    //
    //    public var mxPathname: Int32
    //
    //    public var pNext: UnsafeMutablePointer<sqlite3_vfs>!
    //
    //    public var zName: UnsafePointer<CChar>!
    //
    //    public var pAppData: UnsafeMutableRawPointer!
    //
    //    public var xOpen: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, sqlite3_filename?, UnsafeMutablePointer<sqlite3_file>?, Int32, UnsafeMutablePointer<Int32>?) -> Int32)!
    //
    //    public var xDelete: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, UnsafePointer<CChar>?, Int32) -> Int32)!
    //
    //    public var xAccess: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, UnsafePointer<CChar>?, Int32, UnsafeMutablePointer<Int32>?) -> Int32)!
    //
    //    public var xFullPathname: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, UnsafePointer<CChar>?, Int32, UnsafeMutablePointer<CChar>?) -> Int32)!
    //
    //    public var xDlOpen: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, UnsafePointer<CChar>?) -> UnsafeMutableRawPointer?)!
    //
    //    public var xDlError: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, Int32, UnsafeMutablePointer<CChar>?) -> Void)!
    //
    //    public var xDlSym: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, UnsafeMutableRawPointer?, UnsafePointer<CChar>?) -> (@convention(c) () -> Void)?)!
    //
    //    public var xDlClose: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, UnsafeMutableRawPointer?) -> Void)!
    //
    //    public var xRandomness: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, Int32, UnsafeMutablePointer<CChar>?) -> Int32)!
    //
    //    public var xSleep: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, Int32) -> Int32)!
    //
    //    public var xCurrentTime: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, UnsafeMutablePointer<Double>?) -> Int32)!
    //
    //    public var xGetLastError: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, Int32, UnsafeMutablePointer<CChar>?) -> Int32)!
    //
    //    public var xCurrentTimeInt64: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, UnsafeMutablePointer<sqlite3_int64>?) -> Int32)!
    //
    //    public var xSetSystemCall: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, UnsafePointer<CChar>?, sqlite3_syscall_ptr?) -> Int32)!
    //
    //    public var xGetSystemCall: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, UnsafePointer<CChar>?) -> sqlite3_syscall_ptr?)!
    //
    //    public var xNextSystemCall: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, UnsafePointer<CChar>?) -> UnsafePointer<CChar>?)!
    //}
    public var SQLITE_ACCESS_EXISTS: Int32 { SQLite3.SQLITE_ACCESS_EXISTS }
    public var SQLITE_ACCESS_READWRITE: Int32 { SQLite3.SQLITE_ACCESS_READWRITE }
    public var SQLITE_ACCESS_READ: Int32 { SQLite3.SQLITE_ACCESS_READ }
    public var SQLITE_SHM_UNLOCK: Int32 { SQLite3.SQLITE_SHM_UNLOCK }
    public var SQLITE_SHM_LOCK: Int32 { SQLite3.SQLITE_SHM_LOCK }
    public var SQLITE_SHM_SHARED: Int32 { SQLite3.SQLITE_SHM_SHARED }
    public var SQLITE_SHM_EXCLUSIVE: Int32 { SQLite3.SQLITE_SHM_EXCLUSIVE }
    public var SQLITE_SHM_NLOCK: Int32 { SQLite3.SQLITE_SHM_NLOCK }
    public func sqlite3_initialize() -> Int32 { SQLite3.sqlite3_initialize() }
    public func sqlite3_shutdown() -> Int32 { SQLite3.sqlite3_shutdown() }
    public func sqlite3_os_init() -> Int32 { SQLite3.sqlite3_os_init() }
    public func sqlite3_os_end() -> Int32 { SQLite3.sqlite3_os_end() }
    //struct sqlite3_mem_methods {
    //
    //    public init()
    //
    //    public init(xMalloc: (@convention(c) (Int32) -> UnsafeMutableRawPointer?)!, xFree: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!, xRealloc: (@convention(c) (UnsafeMutableRawPointer?, Int32) -> UnsafeMutableRawPointer?)!, xSize: (@convention(c) (UnsafeMutableRawPointer?) -> Int32)!, xRoundup: (@convention(c) (Int32) -> Int32)!, xInit: (@convention(c) (UnsafeMutableRawPointer?) -> Int32)!, xShutdown: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!, pAppData: UnsafeMutableRawPointer!)
    //
    //    public var xMalloc: (@convention(c) (Int32) -> UnsafeMutableRawPointer?)!
    //
    //    public var xFree: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!
    //
    //    public var xRealloc: (@convention(c) (UnsafeMutableRawPointer?, Int32) -> UnsafeMutableRawPointer?)!
    //
    //    public var xSize: (@convention(c) (UnsafeMutableRawPointer?) -> Int32)!
    //
    //    public var xRoundup: (@convention(c) (Int32) -> Int32)!
    //
    //    public var xInit: (@convention(c) (UnsafeMutableRawPointer?) -> Int32)!
    //
    //    public var xShutdown: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!
    //
    //    public var pAppData: UnsafeMutableRawPointer!
    //}
    public var SQLITE_CONFIG_SINGLETHREAD: Int32 { SQLite3.SQLITE_CONFIG_SINGLETHREAD }
    public var SQLITE_CONFIG_MULTITHREAD: Int32 { SQLite3.SQLITE_CONFIG_MULTITHREAD }
    public var SQLITE_CONFIG_SERIALIZED: Int32 { SQLite3.SQLITE_CONFIG_SERIALIZED }
    public var SQLITE_CONFIG_MALLOC: Int32 { SQLite3.SQLITE_CONFIG_MALLOC }
    public var SQLITE_CONFIG_GETMALLOC: Int32 { SQLite3.SQLITE_CONFIG_GETMALLOC }
    public var SQLITE_CONFIG_SCRATCH: Int32 { SQLite3.SQLITE_CONFIG_SCRATCH }
    public var SQLITE_CONFIG_PAGECACHE: Int32 { SQLite3.SQLITE_CONFIG_PAGECACHE }
    public var SQLITE_CONFIG_HEAP: Int32 { SQLite3.SQLITE_CONFIG_HEAP }
    public var SQLITE_CONFIG_MEMSTATUS: Int32 { SQLite3.SQLITE_CONFIG_MEMSTATUS }
    public var SQLITE_CONFIG_MUTEX: Int32 { SQLite3.SQLITE_CONFIG_MUTEX }
    public var SQLITE_CONFIG_GETMUTEX: Int32 { SQLite3.SQLITE_CONFIG_GETMUTEX }
    public var SQLITE_CONFIG_LOOKASIDE: Int32 { SQLite3.SQLITE_CONFIG_LOOKASIDE }
    public var SQLITE_CONFIG_PCACHE: Int32 { SQLite3.SQLITE_CONFIG_PCACHE }
    public var SQLITE_CONFIG_GETPCACHE: Int32 { SQLite3.SQLITE_CONFIG_GETPCACHE }
    public var SQLITE_CONFIG_LOG: Int32 { SQLite3.SQLITE_CONFIG_LOG }
    public var SQLITE_CONFIG_URI: Int32 { SQLite3.SQLITE_CONFIG_URI }
    public var SQLITE_CONFIG_PCACHE2: Int32 { SQLite3.SQLITE_CONFIG_PCACHE2 }
    public var SQLITE_CONFIG_GETPCACHE2: Int32 { SQLite3.SQLITE_CONFIG_GETPCACHE2 }
    public var SQLITE_CONFIG_COVERING_INDEX_SCAN: Int32 { SQLite3.SQLITE_CONFIG_COVERING_INDEX_SCAN }
    public var SQLITE_CONFIG_SQLLOG: Int32 { SQLite3.SQLITE_CONFIG_SQLLOG }
    public var SQLITE_CONFIG_MMAP_SIZE: Int32 { SQLite3.SQLITE_CONFIG_MMAP_SIZE }
    public var SQLITE_CONFIG_WIN32_HEAPSIZE: Int32 { SQLite3.SQLITE_CONFIG_WIN32_HEAPSIZE }
    public var SQLITE_CONFIG_PCACHE_HDRSZ: Int32 { SQLite3.SQLITE_CONFIG_PCACHE_HDRSZ }
    public var SQLITE_CONFIG_PMASZ: Int32 { SQLite3.SQLITE_CONFIG_PMASZ }
    public var SQLITE_CONFIG_STMTJRNL_SPILL: Int32 { SQLite3.SQLITE_CONFIG_STMTJRNL_SPILL }
    public var SQLITE_CONFIG_SMALL_MALLOC: Int32 { SQLite3.SQLITE_CONFIG_SMALL_MALLOC }
    public var SQLITE_CONFIG_SORTERREF_SIZE: Int32 { SQLite3.SQLITE_CONFIG_SORTERREF_SIZE }
    public var SQLITE_CONFIG_MEMDB_MAXSIZE: Int32 { SQLite3.SQLITE_CONFIG_MEMDB_MAXSIZE }
    public var SQLITE_DBCONFIG_MAINDBNAME: Int32 { SQLite3.SQLITE_DBCONFIG_MAINDBNAME }
    public var SQLITE_DBCONFIG_LOOKASIDE: Int32 { SQLite3.SQLITE_DBCONFIG_LOOKASIDE }
    public var SQLITE_DBCONFIG_ENABLE_FKEY: Int32 { SQLite3.SQLITE_DBCONFIG_ENABLE_FKEY }
    public var SQLITE_DBCONFIG_ENABLE_TRIGGER: Int32 { SQLite3.SQLITE_DBCONFIG_ENABLE_TRIGGER }
    public var SQLITE_DBCONFIG_ENABLE_FTS3_TOKENIZER: Int32 { SQLite3.SQLITE_DBCONFIG_ENABLE_FTS3_TOKENIZER }
    public var SQLITE_DBCONFIG_ENABLE_LOAD_EXTENSION: Int32 { SQLite3.SQLITE_DBCONFIG_ENABLE_LOAD_EXTENSION }
    public var SQLITE_DBCONFIG_NO_CKPT_ON_CLOSE: Int32 { SQLite3.SQLITE_DBCONFIG_NO_CKPT_ON_CLOSE }
    public var SQLITE_DBCONFIG_ENABLE_QPSG: Int32 { SQLite3.SQLITE_DBCONFIG_ENABLE_QPSG }
    public var SQLITE_DBCONFIG_TRIGGER_EQP: Int32 { SQLite3.SQLITE_DBCONFIG_TRIGGER_EQP }
    public var SQLITE_DBCONFIG_RESET_DATABASE: Int32 { SQLite3.SQLITE_DBCONFIG_RESET_DATABASE }
    public var SQLITE_DBCONFIG_DEFENSIVE: Int32 { SQLite3.SQLITE_DBCONFIG_DEFENSIVE }
    public var SQLITE_DBCONFIG_WRITABLE_SCHEMA: Int32 { SQLite3.SQLITE_DBCONFIG_WRITABLE_SCHEMA }
    public var SQLITE_DBCONFIG_LEGACY_ALTER_TABLE: Int32 { SQLite3.SQLITE_DBCONFIG_LEGACY_ALTER_TABLE }
    public var SQLITE_DBCONFIG_DQS_DML: Int32 { SQLite3.SQLITE_DBCONFIG_DQS_DML }
    public var SQLITE_DBCONFIG_DQS_DDL: Int32 { SQLite3.SQLITE_DBCONFIG_DQS_DDL }
    public var SQLITE_DBCONFIG_ENABLE_VIEW: Int32 { SQLite3.SQLITE_DBCONFIG_ENABLE_VIEW }
    public var SQLITE_DBCONFIG_LEGACY_FILE_FORMAT: Int32 { SQLite3.SQLITE_DBCONFIG_LEGACY_FILE_FORMAT }
    public var SQLITE_DBCONFIG_TRUSTED_SCHEMA: Int32 { SQLite3.SQLITE_DBCONFIG_TRUSTED_SCHEMA }
    public var SQLITE_DBCONFIG_STMT_SCANSTATUS: Int32 { SQLite3.SQLITE_DBCONFIG_STMT_SCANSTATUS }
    public var SQLITE_DBCONFIG_REVERSE_SCANORDER: Int32 { SQLite3.SQLITE_DBCONFIG_REVERSE_SCANORDER }
    public var SQLITE_DBCONFIG_MAX: Int32 { SQLite3.SQLITE_DBCONFIG_MAX }
    public func sqlite3_extended_result_codes(_ p0: OpaquePointer!, _ onoff: Int32) -> Int32 { SQLite3.sqlite3_extended_result_codes(p0, onoff) }
    public func sqlite3_last_insert_rowid(_ p0: OpaquePointer!) -> sqlite3_int64 { SQLite3.sqlite3_last_insert_rowid(p0) }
    public func sqlite3_set_last_insert_rowid(_ p0: OpaquePointer!, _ p1: sqlite3_int64) { SQLite3.sqlite3_set_last_insert_rowid(p0, p1) }
    public func sqlite3_changes(_ p0: OpaquePointer!) -> Int32 { SQLite3.sqlite3_changes(p0) }

    public func sqlite3_changes64(_ p0: OpaquePointer!) -> sqlite3_int64 { SQLite3.sqlite3_changes64(p0) }
    public func sqlite3_total_changes(_ p0: OpaquePointer!) -> Int32 { SQLite3.sqlite3_total_changes(p0) }

    public func sqlite3_total_changes64(_ p0: OpaquePointer!) -> sqlite3_int64 { SQLite3.sqlite3_total_changes64(p0) }
    public func sqlite3_interrupt(_ p0: OpaquePointer!) { SQLite3.sqlite3_interrupt(p0) }

    public func sqlite3_is_interrupted(_ p0: OpaquePointer!) -> Int32 { SQLite3.sqlite3_is_interrupted(p0) }
    public func sqlite3_complete(_ sql: UnsafePointer<CChar>!) -> Int32 { SQLite3.sqlite3_complete(sql) }
    public func sqlite3_complete16(_ sql: UnsafeRawPointer!) -> Int32 { SQLite3.sqlite3_complete16(sql) }
    public func sqlite3_busy_handler(_ p0: OpaquePointer!, _ p1: (@convention(c) (UnsafeMutableRawPointer?, Int32) -> Int32)!, _ p2: UnsafeMutableRawPointer!) -> Int32 { SQLite3.sqlite3_busy_handler(p0, p1, p2) }
    public func sqlite3_busy_timeout(_ p0: OpaquePointer!, _ ms: Int32) -> Int32 { SQLite3.sqlite3_busy_timeout(p0, ms) }
    public func sqlite3_get_table(_ db: OpaquePointer!, _ zSql: UnsafePointer<CChar>!, _ pazResult: UnsafeMutablePointer<UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?>!, _ pnRow: UnsafeMutablePointer<Int32>!, _ pnColumn: UnsafeMutablePointer<Int32>!, _ pzErrmsg: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>!) -> Int32 { SQLite3.sqlite3_get_table(db, zSql, pazResult, pnRow, pnColumn, pzErrmsg) }
    public func sqlite3_free_table(_ result: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>!) { SQLite3.sqlite3_free_table(result) }
    public func sqlite3_vmprintf(_ p0: UnsafePointer<CChar>!, _ p1: CVaListPointer) -> UnsafeMutablePointer<CChar>! { SQLite3.sqlite3_vmprintf(p0, p1) }

    public func sqlite3_vsnprintf(_ p0: Int32, _ p1: UnsafeMutablePointer<CChar>!, _ p2: UnsafePointer<CChar>!, _ p3: CVaListPointer) -> UnsafeMutablePointer<CChar>! { SQLite3.sqlite3_vsnprintf(p0, p1, p2, p3) }
    public func sqlite3_malloc(_ p0: Int32) -> UnsafeMutableRawPointer! { SQLite3.sqlite3_malloc(p0) }

    public func sqlite3_malloc64(_ p0: sqlite3_uint64) -> UnsafeMutableRawPointer! { SQLite3.sqlite3_malloc64(p0) }
    public func sqlite3_realloc(_ p0: UnsafeMutableRawPointer!, _ p1: Int32) -> UnsafeMutableRawPointer! { SQLite3.sqlite3_realloc(p0, p1) }

    public func sqlite3_realloc64(_ p0: UnsafeMutableRawPointer!, _ p1: sqlite3_uint64) -> UnsafeMutableRawPointer! { SQLite3.sqlite3_realloc64(p0, p1) }
    public func sqlite3_free(_ p0: UnsafeMutableRawPointer!) { SQLite3.sqlite3_free(p0) }

    public func sqlite3_msize(_ p0: UnsafeMutableRawPointer!) -> sqlite3_uint64 { SQLite3.sqlite3_msize(p0) }
    public func sqlite3_memory_used() -> sqlite3_int64 { SQLite3.sqlite3_memory_used() }
    public func sqlite3_memory_highwater(_ resetFlag: Int32) -> sqlite3_int64 { SQLite3.sqlite3_memory_highwater(resetFlag) }
    public func sqlite3_randomness(_ N: Int32, _ P: UnsafeMutableRawPointer!) { SQLite3.sqlite3_randomness(N, P) }
    public func sqlite3_set_authorizer(_ p0: OpaquePointer!, _ xAuth: (@convention(c) (UnsafeMutableRawPointer?, Int32, UnsafePointer<CChar>?, UnsafePointer<CChar>?, UnsafePointer<CChar>?, UnsafePointer<CChar>?) -> Int32)!, _ pUserData: UnsafeMutableRawPointer!) -> Int32 { SQLite3.sqlite3_set_authorizer(p0, xAuth, pUserData) }
    public var SQLITE_DENY: Int32 { SQLite3.SQLITE_DENY }
    public var SQLITE_IGNORE: Int32 { SQLite3.SQLITE_IGNORE }
    public var SQLITE_CREATE_INDEX: Int32 { SQLite3.SQLITE_CREATE_INDEX }
    public var SQLITE_CREATE_TABLE: Int32 { SQLite3.SQLITE_CREATE_TABLE }
    public var SQLITE_CREATE_TEMP_INDEX: Int32 { SQLite3.SQLITE_CREATE_TEMP_INDEX }
    public var SQLITE_CREATE_TEMP_TABLE: Int32 { SQLite3.SQLITE_CREATE_TEMP_TABLE }
    public var SQLITE_CREATE_TEMP_TRIGGER: Int32 { SQLite3.SQLITE_CREATE_TEMP_TRIGGER }
    public var SQLITE_CREATE_TEMP_VIEW: Int32 { SQLite3.SQLITE_CREATE_TEMP_VIEW }
    public var SQLITE_CREATE_TRIGGER: Int32 { SQLite3.SQLITE_CREATE_TRIGGER }
    public var SQLITE_CREATE_VIEW: Int32 { SQLite3.SQLITE_CREATE_VIEW }
    public var SQLITE_DELETE: Int32 { SQLite3.SQLITE_DELETE }
    public var SQLITE_DROP_INDEX: Int32 { SQLite3.SQLITE_DROP_INDEX }
    public var SQLITE_DROP_TABLE: Int32 { SQLite3.SQLITE_DROP_TABLE }
    public var SQLITE_DROP_TEMP_INDEX: Int32 { SQLite3.SQLITE_DROP_TEMP_INDEX }
    public var SQLITE_DROP_TEMP_TABLE: Int32 { SQLite3.SQLITE_DROP_TEMP_TABLE }
    public var SQLITE_DROP_TEMP_TRIGGER: Int32 { SQLite3.SQLITE_DROP_TEMP_TRIGGER }
    public var SQLITE_DROP_TEMP_VIEW: Int32 { SQLite3.SQLITE_DROP_TEMP_VIEW }
    public var SQLITE_DROP_TRIGGER: Int32 { SQLite3.SQLITE_DROP_TRIGGER }
    public var SQLITE_DROP_VIEW: Int32 { SQLite3.SQLITE_DROP_VIEW }
    public var SQLITE_INSERT: Int32 { SQLite3.SQLITE_INSERT }
    public var SQLITE_PRAGMA: Int32 { SQLite3.SQLITE_PRAGMA }
    public var SQLITE_READ: Int32 { SQLite3.SQLITE_READ }
    public var SQLITE_SELECT: Int32 { SQLite3.SQLITE_SELECT }
    public var SQLITE_TRANSACTION: Int32 { SQLite3.SQLITE_TRANSACTION }
    public var SQLITE_UPDATE: Int32 { SQLite3.SQLITE_UPDATE }
    public var SQLITE_ATTACH: Int32 { SQLite3.SQLITE_ATTACH }
    public var SQLITE_DETACH: Int32 { SQLite3.SQLITE_DETACH }
    public var SQLITE_ALTER_TABLE: Int32 { SQLite3.SQLITE_ALTER_TABLE }
    public var SQLITE_REINDEX: Int32 { SQLite3.SQLITE_REINDEX }
    public var SQLITE_ANALYZE: Int32 { SQLite3.SQLITE_ANALYZE }
    public var SQLITE_CREATE_VTABLE: Int32 { SQLite3.SQLITE_CREATE_VTABLE }
    public var SQLITE_DROP_VTABLE: Int32 { SQLite3.SQLITE_DROP_VTABLE }
    public var SQLITE_FUNCTION: Int32 { SQLite3.SQLITE_FUNCTION }
    public var SQLITE_SAVEPOINT: Int32 { SQLite3.SQLITE_SAVEPOINT }
    public var SQLITE_COPY: Int32 { SQLite3.SQLITE_COPY }
    public var SQLITE_RECURSIVE: Int32 { SQLite3.SQLITE_RECURSIVE }

    public func sqlite3_trace(_ p0: OpaquePointer!, _ xTrace: (@convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?) -> Void)!, _ p1: UnsafeMutableRawPointer!) -> UnsafeMutableRawPointer! { SQLite3.sqlite3_trace(p0, xTrace, p1) }

    public func sqlite3_profile(_ p0: OpaquePointer!, _ xProfile: (@convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?, sqlite3_uint64) -> Void)!, _ p1: UnsafeMutableRawPointer!) -> UnsafeMutableRawPointer! { SQLite3.sqlite3_profile(p0, xProfile, p1) }
    public var SQLITE_TRACE_STMT: Int32 { SQLite3.SQLITE_TRACE_STMT }
    public var SQLITE_TRACE_PROFILE: Int32 { SQLite3.SQLITE_TRACE_PROFILE }
    public var SQLITE_TRACE_ROW: Int32 { SQLite3.SQLITE_TRACE_ROW }
    public var SQLITE_TRACE_CLOSE: Int32 { SQLite3.SQLITE_TRACE_CLOSE }

    public func sqlite3_trace_v2(_ p0: OpaquePointer!, _ uMask: UInt32, _ xCallback: (@convention(c) (UInt32, UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Int32)!, _ pCtx: UnsafeMutableRawPointer!) -> Int32 { SQLite3.sqlite3_trace_v2(p0, uMask, xCallback, pCtx) }
    public func sqlite3_progress_handler(_ p0: OpaquePointer!, _ p1: Int32, _ p2: (@convention(c) (UnsafeMutableRawPointer?) -> Int32)!, _ p3: UnsafeMutableRawPointer!) { SQLite3.sqlite3_progress_handler(p0, p1, p2, p3) }
    public func sqlite3_open(_ filename: UnsafePointer<CChar>!, _ ppDb: UnsafeMutablePointer<OpaquePointer?>!) -> Int32 { SQLite3.sqlite3_open(filename, ppDb) }
    public func sqlite3_open16(_ filename: UnsafeRawPointer!, _ ppDb: UnsafeMutablePointer<OpaquePointer?>!) -> Int32 { SQLite3.sqlite3_open16(filename, ppDb) }
    public func sqlite3_open_v2(_ filename: UnsafePointer<CChar>!, _ ppDb: UnsafeMutablePointer<OpaquePointer?>!, _ flags: Int32, _ zVfs: UnsafePointer<CChar>!) -> Int32 { SQLite3.sqlite3_open_v2(filename, ppDb, flags, zVfs) }

    public func sqlite3_uri_parameter(_ z: sqlite3_filename!, _ zParam: UnsafePointer<CChar>!) -> UnsafePointer<CChar>! { SQLite3.sqlite3_uri_parameter(z, zParam) }

    public func sqlite3_uri_boolean(_ z: sqlite3_filename!, _ zParam: UnsafePointer<CChar>!, _ bDefault: Int32) -> Int32 { SQLite3.sqlite3_uri_boolean(z, zParam, bDefault) }

    public func sqlite3_uri_int64(_ p0: sqlite3_filename!, _ p1: UnsafePointer<CChar>!, _ p2: sqlite3_int64) -> sqlite3_int64 { SQLite3.sqlite3_uri_int64(p0, p1, p2) }

    public func sqlite3_uri_key(_ z: sqlite3_filename!, _ N: Int32) -> UnsafePointer<CChar>! { SQLite3.sqlite3_uri_key(z, N) }

    public func sqlite3_filename_database(_ p0: sqlite3_filename!) -> UnsafePointer<CChar>! { SQLite3.sqlite3_filename_database(p0) }

    public func sqlite3_filename_journal(_ p0: sqlite3_filename!) -> UnsafePointer<CChar>! { SQLite3.sqlite3_filename_journal(p0) }

    public func sqlite3_filename_wal(_ p0: sqlite3_filename!) -> UnsafePointer<CChar>! { SQLite3.sqlite3_filename_wal(p0) }

    //public func sqlite3_database_file_object(_ p0: UnsafePointer<CChar>!) -> UnsafeMutablePointer<sqlite3_file>! { SQLite3.sqlite3_database_file_object(p0) }

    public func sqlite3_create_filename(_ zDatabase: UnsafePointer<CChar>!, _ zJournal: UnsafePointer<CChar>!, _ zWal: UnsafePointer<CChar>!, _ nParam: Int32, _ azParam: UnsafeMutablePointer<UnsafePointer<CChar>?>!) -> sqlite3_filename! { SQLite3.sqlite3_create_filename(zDatabase, zJournal, zWal, nParam, azParam) }

    public func sqlite3_free_filename(_ p0: sqlite3_filename!) { SQLite3.sqlite3_free_filename(p0) }
    public func sqlite3_errcode(_ db: OpaquePointer!) -> Int32 { SQLite3.sqlite3_errcode(db) }
    public func sqlite3_extended_errcode(_ db: OpaquePointer!) -> Int32 { SQLite3.sqlite3_extended_errcode(db) }
    public func sqlite3_errmsg(_ p0: OpaquePointer!) -> UnsafePointer<CChar>! { SQLite3.sqlite3_errmsg(p0) }
    public func sqlite3_errmsg16(_ p0: OpaquePointer!) -> UnsafeRawPointer! { SQLite3.sqlite3_errmsg16(p0) }

    public func sqlite3_errstr(_ p0: Int32) -> UnsafePointer<CChar>! { SQLite3.sqlite3_errstr(p0) }

    public func sqlite3_error_offset(_ db: OpaquePointer!) -> Int32 { SQLite3.sqlite3_error_offset(db) }
    public func sqlite3_limit(_ p0: OpaquePointer!, _ id: Int32, _ newVal: Int32) -> Int32 { SQLite3.sqlite3_limit(p0, id, newVal) }
    public var SQLITE_LIMIT_LENGTH: Int32 { SQLite3.SQLITE_LIMIT_LENGTH }
    public var SQLITE_LIMIT_SQL_LENGTH: Int32 { SQLite3.SQLITE_LIMIT_SQL_LENGTH }
    public var SQLITE_LIMIT_COLUMN: Int32 { SQLite3.SQLITE_LIMIT_COLUMN }
    public var SQLITE_LIMIT_EXPR_DEPTH: Int32 { SQLite3.SQLITE_LIMIT_EXPR_DEPTH }
    public var SQLITE_LIMIT_COMPOUND_SELECT: Int32 { SQLite3.SQLITE_LIMIT_COMPOUND_SELECT }
    public var SQLITE_LIMIT_VDBE_OP: Int32 { SQLite3.SQLITE_LIMIT_VDBE_OP }
    public var SQLITE_LIMIT_FUNCTION_ARG: Int32 { SQLite3.SQLITE_LIMIT_FUNCTION_ARG }
    public var SQLITE_LIMIT_ATTACHED: Int32 { SQLite3.SQLITE_LIMIT_ATTACHED }
    public var SQLITE_LIMIT_LIKE_PATTERN_LENGTH: Int32 { SQLite3.SQLITE_LIMIT_LIKE_PATTERN_LENGTH }
    public var SQLITE_LIMIT_VARIABLE_NUMBER: Int32 { SQLite3.SQLITE_LIMIT_VARIABLE_NUMBER }
    public var SQLITE_LIMIT_TRIGGER_DEPTH: Int32 { SQLite3.SQLITE_LIMIT_TRIGGER_DEPTH }
    public var SQLITE_LIMIT_WORKER_THREADS: Int32 { SQLite3.SQLITE_LIMIT_WORKER_THREADS }
    public var SQLITE_PREPARE_PERSISTENT: Int32 { SQLite3.SQLITE_PREPARE_PERSISTENT }
    public var SQLITE_PREPARE_NORMALIZE: Int32 { SQLite3.SQLITE_PREPARE_NORMALIZE }
    public var SQLITE_PREPARE_NO_VTAB: Int32 { SQLite3.SQLITE_PREPARE_NO_VTAB }
    public func sqlite3_prepare(_ db: OpaquePointer!, _ zSql: UnsafePointer<CChar>!, _ nByte: Int32, _ ppStmt: UnsafeMutablePointer<OpaquePointer?>!, _ pzTail: UnsafeMutablePointer<UnsafePointer<CChar>?>!) -> Int32 { SQLite3.sqlite3_prepare(db, zSql, nByte, ppStmt, pzTail) }
    public func sqlite3_prepare_v2(_ db: OpaquePointer!, _ zSql: UnsafePointer<CChar>!, _ nByte: Int32, _ ppStmt: UnsafeMutablePointer<OpaquePointer?>!, _ pzTail: UnsafeMutablePointer<UnsafePointer<CChar>?>!) -> Int32 { SQLite3.sqlite3_prepare_v2(db, zSql, nByte, ppStmt, pzTail) }

    public func sqlite3_prepare_v3(_ db: OpaquePointer!, _ zSql: UnsafePointer<CChar>!, _ nByte: Int32, _ prepFlags: UInt32, _ ppStmt: UnsafeMutablePointer<OpaquePointer?>!, _ pzTail: UnsafeMutablePointer<UnsafePointer<CChar>?>!) -> Int32 { SQLite3.sqlite3_prepare_v3(db, zSql, nByte, prepFlags, ppStmt, pzTail) }
    public func sqlite3_prepare16(_ db: OpaquePointer!, _ zSql: UnsafeRawPointer!, _ nByte: Int32, _ ppStmt: UnsafeMutablePointer<OpaquePointer?>!, _ pzTail: UnsafeMutablePointer<UnsafeRawPointer?>!) -> Int32 { SQLite3.sqlite3_prepare16(db, zSql, nByte, ppStmt, pzTail) }
    public func sqlite3_prepare16_v2(_ db: OpaquePointer!, _ zSql: UnsafeRawPointer!, _ nByte: Int32, _ ppStmt: UnsafeMutablePointer<OpaquePointer?>!, _ pzTail: UnsafeMutablePointer<UnsafeRawPointer?>!) -> Int32 { SQLite3.sqlite3_prepare16_v2(db, zSql, nByte, ppStmt, pzTail) }

    public func sqlite3_prepare16_v3(_ db: OpaquePointer!, _ zSql: UnsafeRawPointer!, _ nByte: Int32, _ prepFlags: UInt32, _ ppStmt: UnsafeMutablePointer<OpaquePointer?>!, _ pzTail: UnsafeMutablePointer<UnsafeRawPointer?>!) -> Int32 { SQLite3.sqlite3_prepare16_v3(db, zSql, nByte, prepFlags, ppStmt, pzTail) }
    public func sqlite3_sql(_ pStmt: OpaquePointer!) -> UnsafePointer<CChar>! { SQLite3.sqlite3_sql(pStmt) }

    public func sqlite3_expanded_sql(_ pStmt: OpaquePointer!) -> UnsafeMutablePointer<CChar>! { SQLite3.sqlite3_expanded_sql(pStmt) }

    public func sqlite3_normalized_sql(_ pStmt: OpaquePointer!) -> UnsafePointer<CChar>! { SQLite3.sqlite3_normalized_sql(pStmt) }

    public func sqlite3_stmt_readonly(_ pStmt: OpaquePointer!) -> Int32 { SQLite3.sqlite3_stmt_readonly(pStmt) }

    public func sqlite3_stmt_isexplain(_ pStmt: OpaquePointer!) -> Int32 { SQLite3.sqlite3_stmt_isexplain(pStmt) }

    public func sqlite3_stmt_explain(_ pStmt: OpaquePointer!, _ eMode: Int32) -> Int32 { SQLite3.sqlite3_stmt_explain(pStmt, eMode) }

    public func sqlite3_stmt_busy(_ p0: OpaquePointer!) -> Int32 { SQLite3.sqlite3_stmt_busy(p0) }
    public func sqlite3_bind_blob(_ p0: OpaquePointer!, _ p1: Int32, _ p2: UnsafeRawPointer!, _ n: Int32, _ p3: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!) -> Int32 { SQLite3.sqlite3_bind_blob(p0, p1, p2, n, p3) }
    public func sqlite3_bind_blob64(_ p0: OpaquePointer!, _ p1: Int32, _ p2: UnsafeRawPointer!, _ p3: sqlite3_uint64, _ p4: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!) -> Int32 { SQLite3.sqlite3_bind_blob64(p0, p1, p2, p3, p4) }
    public func sqlite3_bind_double(_ p0: OpaquePointer!, _ p1: Int32, _ p2: Double) -> Int32 { SQLite3.sqlite3_bind_double(p0, p1, p2) }
    public func sqlite3_bind_int(_ p0: OpaquePointer!, _ p1: Int32, _ p2: Int32) -> Int32 { SQLite3.sqlite3_bind_int(p0, p1, p2) }
    public func sqlite3_bind_int64(_ p0: OpaquePointer!, _ p1: Int32, _ p2: sqlite3_int64) -> Int32 { SQLite3.sqlite3_bind_int64(p0, p1, p2) }
    public func sqlite3_bind_null(_ p0: OpaquePointer!, _ p1: Int32) -> Int32 { SQLite3.sqlite3_bind_null(p0, p1) }
    public func sqlite3_bind_text(_ p0: OpaquePointer!, _ p1: Int32, _ p2: UnsafePointer<CChar>!, _ p3: Int32, _ p4: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!) -> Int32 { SQLite3.sqlite3_bind_text(p0, p1, p2, p3, p4) }
    public func sqlite3_bind_text16(_ p0: OpaquePointer!, _ p1: Int32, _ p2: UnsafeRawPointer!, _ p3: Int32, _ p4: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!) -> Int32 { SQLite3.sqlite3_bind_text16(p0, p1, p2, p3, p4) }
    public func sqlite3_bind_text64(_ p0: OpaquePointer!, _ p1: Int32, _ p2: UnsafePointer<CChar>!, _ p3: sqlite3_uint64, _ p4: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!, _ encoding: UInt8) -> Int32 { SQLite3.sqlite3_bind_text64(p0, p1, p2, p3, p4, encoding) }
    public func sqlite3_bind_value(_ p0: OpaquePointer!, _ p1: Int32, _ p2: OpaquePointer!) -> Int32 { SQLite3.sqlite3_bind_value(p0, p1, p2) }

    public func sqlite3_bind_pointer(_ p0: OpaquePointer!, _ p1: Int32, _ p2: UnsafeMutableRawPointer!, _ p3: UnsafePointer<CChar>!, _ p4: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!) -> Int32 { SQLite3.sqlite3_bind_pointer(p0, p1, p2, p3, p4) }
    public func sqlite3_bind_zeroblob(_ p0: OpaquePointer!, _ p1: Int32, _ n: Int32) -> Int32 { SQLite3.sqlite3_bind_zeroblob(p0, p1, n) }

    public func sqlite3_bind_zeroblob64(_ p0: OpaquePointer!, _ p1: Int32, _ p2: sqlite3_uint64) -> Int32 { SQLite3.sqlite3_bind_zeroblob64(p0, p1, p2) }
    public func sqlite3_bind_parameter_count(_ p0: OpaquePointer!) -> Int32 { SQLite3.sqlite3_bind_parameter_count(p0) }
    public func sqlite3_bind_parameter_name(_ p0: OpaquePointer!, _ p1: Int32) -> UnsafePointer<CChar>! { SQLite3.sqlite3_bind_parameter_name(p0, p1) }
    public func sqlite3_bind_parameter_index(_ p0: OpaquePointer!, _ zName: UnsafePointer<CChar>!) -> Int32 { SQLite3.sqlite3_bind_parameter_index(p0, zName) }
    public func sqlite3_clear_bindings(_ p0: OpaquePointer!) -> Int32 { SQLite3.sqlite3_clear_bindings(p0) }
    public func sqlite3_column_count(_ pStmt: OpaquePointer!) -> Int32 { SQLite3.sqlite3_column_count(pStmt) }
    public func sqlite3_column_name(_ p0: OpaquePointer!, _ N: Int32) -> UnsafePointer<CChar>! { SQLite3.sqlite3_column_name(p0, N) }
    public func sqlite3_column_name16(_ p0: OpaquePointer!, _ N: Int32) -> UnsafeRawPointer! { SQLite3.sqlite3_column_name16(p0, N) }
    public func sqlite3_column_database_name(_ p0: OpaquePointer!, _ p1: Int32) -> UnsafePointer<CChar>! { SQLite3.sqlite3_column_database_name(p0, p1) }
    public func sqlite3_column_database_name16(_ p0: OpaquePointer!, _ p1: Int32) -> UnsafeRawPointer! { SQLite3.sqlite3_column_database_name16(p0, p1) }
    public func sqlite3_column_table_name(_ p0: OpaquePointer!, _ p1: Int32) -> UnsafePointer<CChar>! { SQLite3.sqlite3_column_table_name(p0, p1) }
    public func sqlite3_column_table_name16(_ p0: OpaquePointer!, _ p1: Int32) -> UnsafeRawPointer! { SQLite3.sqlite3_column_table_name16(p0, p1) }
    public func sqlite3_column_origin_name(_ p0: OpaquePointer!, _ p1: Int32) -> UnsafePointer<CChar>! { SQLite3.sqlite3_column_origin_name(p0, p1) }
    public func sqlite3_column_origin_name16(_ p0: OpaquePointer!, _ p1: Int32) -> UnsafeRawPointer! { SQLite3.sqlite3_column_origin_name16(p0, p1) }
    public func sqlite3_column_decltype(_ p0: OpaquePointer!, _ p1: Int32) -> UnsafePointer<CChar>! { SQLite3.sqlite3_column_decltype(p0, p1) }
    public func sqlite3_column_decltype16(_ p0: OpaquePointer!, _ p1: Int32) -> UnsafeRawPointer! { SQLite3.sqlite3_column_decltype16(p0, p1) }
    public func sqlite3_step(_ p0: OpaquePointer!) -> Int32 { SQLite3.sqlite3_step(p0) }
    public func sqlite3_data_count(_ pStmt: OpaquePointer!) -> Int32 { SQLite3.sqlite3_data_count(pStmt) }
    public var SQLITE_INTEGER: Int32 { SQLite3.SQLITE_INTEGER }
    public var SQLITE_FLOAT: Int32 { SQLite3.SQLITE_FLOAT }
    public var SQLITE_BLOB: Int32 { SQLite3.SQLITE_BLOB }
    public var SQLITE_NULL: Int32 { SQLite3.SQLITE_NULL }
    public var SQLITE_TEXT: Int32 { SQLite3.SQLITE_TEXT }
    public var SQLITE3_TEXT: Int32 { SQLite3.SQLITE3_TEXT }
    public func sqlite3_column_blob(_ p0: OpaquePointer!, _ iCol: Int32) -> UnsafeRawPointer! { SQLite3.sqlite3_column_blob(p0, iCol) }
    public func sqlite3_column_double(_ p0: OpaquePointer!, _ iCol: Int32) -> Double { SQLite3.sqlite3_column_double(p0, iCol) }
    public func sqlite3_column_int(_ p0: OpaquePointer!, _ iCol: Int32) -> Int32 { SQLite3.sqlite3_column_int(p0, iCol) }
    public func sqlite3_column_int64(_ p0: OpaquePointer!, _ iCol: Int32) -> sqlite3_int64 { SQLite3.sqlite3_column_int64(p0, iCol) }
    public func sqlite3_column_text(_ p0: OpaquePointer!, _ iCol: Int32) -> UnsafePointer<UInt8>! { SQLite3.sqlite3_column_text(p0, iCol) }
    public func sqlite3_column_text16(_ p0: OpaquePointer!, _ iCol: Int32) -> UnsafeRawPointer! { SQLite3.sqlite3_column_text16(p0, iCol) }
    public func sqlite3_column_value(_ p0: OpaquePointer!, _ iCol: Int32) -> OpaquePointer! { SQLite3.sqlite3_column_value(p0, iCol) }
    public func sqlite3_column_bytes(_ p0: OpaquePointer!, _ iCol: Int32) -> Int32 { SQLite3.sqlite3_column_bytes(p0, iCol) }
    public func sqlite3_column_bytes16(_ p0: OpaquePointer!, _ iCol: Int32) -> Int32 { SQLite3.sqlite3_column_bytes16(p0, iCol) }
    public func sqlite3_column_type(_ p0: OpaquePointer!, _ iCol: Int32) -> Int32 { SQLite3.sqlite3_column_type(p0, iCol) }
    public func sqlite3_finalize(_ pStmt: OpaquePointer!) -> Int32 { SQLite3.sqlite3_finalize(pStmt) }
    public func sqlite3_reset(_ pStmt: OpaquePointer!) -> Int32 { SQLite3.sqlite3_reset(pStmt) }
    public func sqlite3_create_function(_ db: OpaquePointer!, _ zFunctionName: UnsafePointer<CChar>!, _ nArg: Int32, _ eTextRep: Int32, _ pApp: UnsafeMutableRawPointer!, _ xFunc: (@convention(c) (OpaquePointer?, Int32, UnsafeMutablePointer<OpaquePointer?>?) -> Void)!, _ xStep: (@convention(c) (OpaquePointer?, Int32, UnsafeMutablePointer<OpaquePointer?>?) -> Void)!, _ xFinal: (@convention(c) (OpaquePointer?) -> Void)!) -> Int32 { SQLite3.sqlite3_create_function(db, zFunctionName, nArg, eTextRep, pApp, xFunc, xStep, xFinal) }
    public func sqlite3_create_function16(_ db: OpaquePointer!, _ zFunctionName: UnsafeRawPointer!, _ nArg: Int32, _ eTextRep: Int32, _ pApp: UnsafeMutableRawPointer!, _ xFunc: (@convention(c) (OpaquePointer?, Int32, UnsafeMutablePointer<OpaquePointer?>?) -> Void)!, _ xStep: (@convention(c) (OpaquePointer?, Int32, UnsafeMutablePointer<OpaquePointer?>?) -> Void)!, _ xFinal: (@convention(c) (OpaquePointer?) -> Void)!) -> Int32 { SQLite3.sqlite3_create_function16(db, zFunctionName, nArg, eTextRep, pApp, xFunc, xStep, xFinal) }

    public func sqlite3_create_function_v2(_ db: OpaquePointer!, _ zFunctionName: UnsafePointer<CChar>!, _ nArg: Int32, _ eTextRep: Int32, _ pApp: UnsafeMutableRawPointer!, _ xFunc: (@convention(c) (OpaquePointer?, Int32, UnsafeMutablePointer<OpaquePointer?>?) -> Void)!, _ xStep: (@convention(c) (OpaquePointer?, Int32, UnsafeMutablePointer<OpaquePointer?>?) -> Void)!, _ xFinal: (@convention(c) (OpaquePointer?) -> Void)!, _ xDestroy: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!) -> Int32 { SQLite3.sqlite3_create_function_v2(db, zFunctionName, nArg, eTextRep, pApp, xFunc, xStep, xFinal, xDestroy) }

    public func sqlite3_create_window_function(_ db: OpaquePointer!, _ zFunctionName: UnsafePointer<CChar>!, _ nArg: Int32, _ eTextRep: Int32, _ pApp: UnsafeMutableRawPointer!, _ xStep: (@convention(c) (OpaquePointer?, Int32, UnsafeMutablePointer<OpaquePointer?>?) -> Void)!, _ xFinal: (@convention(c) (OpaquePointer?) -> Void)!, _ xValue: (@convention(c) (OpaquePointer?) -> Void)!, _ xInverse: (@convention(c) (OpaquePointer?, Int32, UnsafeMutablePointer<OpaquePointer?>?) -> Void)!, _ xDestroy: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!) -> Int32 { SQLite3.sqlite3_create_window_function(db, zFunctionName, nArg, eTextRep, pApp, xStep, xFinal, xValue, xInverse, xDestroy) }
    public var SQLITE_UTF8: Int32 { SQLite3.SQLITE_UTF8 }
    public var SQLITE_UTF16LE: Int32 { SQLite3.SQLITE_UTF16LE }
    public var SQLITE_UTF16BE: Int32 { SQLite3.SQLITE_UTF16BE }
    public var SQLITE_UTF16: Int32 { SQLite3.SQLITE_UTF16 }
    public var SQLITE_ANY: Int32 { SQLite3.SQLITE_ANY }
    public var SQLITE_UTF16_ALIGNED: Int32 { SQLite3.SQLITE_UTF16_ALIGNED }
    public var SQLITE_DETERMINISTIC: Int32 { SQLite3.SQLITE_DETERMINISTIC }
    public var SQLITE_DIRECTONLY: Int32 { SQLite3.SQLITE_DIRECTONLY }
    public var SQLITE_SUBTYPE: Int32 { SQLite3.SQLITE_SUBTYPE }
    public var SQLITE_INNOCUOUS: Int32 { SQLite3.SQLITE_INNOCUOUS }
    public func sqlite3_value_blob(_ p0: OpaquePointer!) -> UnsafeRawPointer! { SQLite3.sqlite3_value_blob(p0) }
    public func sqlite3_value_double(_ p0: OpaquePointer!) -> Double { SQLite3.sqlite3_value_double(p0) }
    public func sqlite3_value_int(_ p0: OpaquePointer!) -> Int32 { SQLite3.sqlite3_value_int(p0) }
    public func sqlite3_value_int64(_ p0: OpaquePointer!) -> sqlite3_int64 { SQLite3.sqlite3_value_int64(p0) }

    public func sqlite3_value_pointer(_ p0: OpaquePointer!, _ p1: UnsafePointer<CChar>!) -> UnsafeMutableRawPointer! { SQLite3.sqlite3_value_pointer(p0, p1) }
    public func sqlite3_value_text(_ p0: OpaquePointer!) -> UnsafePointer<UInt8>! { SQLite3.sqlite3_value_text(p0) }
    public func sqlite3_value_text16(_ p0: OpaquePointer!) -> UnsafeRawPointer! { SQLite3.sqlite3_value_text16(p0) }
    public func sqlite3_value_text16le(_ p0: OpaquePointer!) -> UnsafeRawPointer! { SQLite3.sqlite3_value_text16le(p0) }
    public func sqlite3_value_text16be(_ p0: OpaquePointer!) -> UnsafeRawPointer! { SQLite3.sqlite3_value_text16be(p0) }
    public func sqlite3_value_bytes(_ p0: OpaquePointer!) -> Int32 { SQLite3.sqlite3_value_bytes(p0) }
    public func sqlite3_value_bytes16(_ p0: OpaquePointer!) -> Int32 { SQLite3.sqlite3_value_bytes16(p0) }
    public func sqlite3_value_type(_ p0: OpaquePointer!) -> Int32 { SQLite3.sqlite3_value_type(p0) }
    public func sqlite3_value_numeric_type(_ p0: OpaquePointer!) -> Int32 { SQLite3.sqlite3_value_numeric_type(p0) }

    public func sqlite3_value_nochange(_ p0: OpaquePointer!) -> Int32 { SQLite3.sqlite3_value_nochange(p0) }

    public func sqlite3_value_frombind(_ p0: OpaquePointer!) -> Int32 { SQLite3.sqlite3_value_frombind(p0) }

    public func sqlite3_value_encoding(_ p0: OpaquePointer!) -> Int32 { SQLite3.sqlite3_value_encoding(p0) }

    public func sqlite3_value_subtype(_ p0: OpaquePointer!) -> UInt32 { SQLite3.sqlite3_value_subtype(p0) }

    public func sqlite3_value_dup(_ p0: OpaquePointer!) -> OpaquePointer! { SQLite3.sqlite3_value_dup(p0) }

    public func sqlite3_value_free(_ p0: OpaquePointer!) { SQLite3.sqlite3_value_free(p0) }
    public func sqlite3_aggregate_context(_ p0: OpaquePointer!, _ nBytes: Int32) -> UnsafeMutableRawPointer! { SQLite3.sqlite3_aggregate_context(p0, nBytes) }
    public func sqlite3_user_data(_ p0: OpaquePointer!) -> UnsafeMutableRawPointer! { SQLite3.sqlite3_user_data(p0) }
    public func sqlite3_context_db_handle(_ p0: OpaquePointer!) -> OpaquePointer! { SQLite3.sqlite3_context_db_handle(p0) }
    public func sqlite3_get_auxdata(_ p0: OpaquePointer!, _ N: Int32) -> UnsafeMutableRawPointer! { SQLite3.sqlite3_get_auxdata(p0, N) }
    public func sqlite3_set_auxdata(_ p0: OpaquePointer!, _ N: Int32, _ p1: UnsafeMutableRawPointer!, _ p2: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!) { SQLite3.sqlite3_set_auxdata(p0, N, p1, p2) }
    public typealias sqlite3_destructor_type = @convention(c) (UnsafeMutableRawPointer?) -> Void
    public func sqlite3_result_blob(_ p0: OpaquePointer!, _ p1: UnsafeRawPointer!, _ p2: Int32, _ p3: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!) { SQLite3.sqlite3_result_blob(p0, p1, p2, p3) }
    public func sqlite3_result_blob64(_ p0: OpaquePointer!, _ p1: UnsafeRawPointer!, _ p2: sqlite3_uint64, _ p3: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!) { SQLite3.sqlite3_result_blob64(p0, p1, p2, p3) }
    public func sqlite3_result_double(_ p0: OpaquePointer!, _ p1: Double) { SQLite3.sqlite3_result_double(p0, p1) }
    public func sqlite3_result_error(_ p0: OpaquePointer!, _ p1: UnsafePointer<CChar>!, _ p2: Int32) { SQLite3.sqlite3_result_error(p0, p1, p2) }
    public func sqlite3_result_error16(_ p0: OpaquePointer!, _ p1: UnsafeRawPointer!, _ p2: Int32) { SQLite3.sqlite3_result_error16(p0, p1, p2) }
    public func sqlite3_result_error_toobig(_ p0: OpaquePointer!) { SQLite3.sqlite3_result_error_toobig(p0) }
    public func sqlite3_result_error_nomem(_ p0: OpaquePointer!) { SQLite3.sqlite3_result_error_nomem(p0) }
    public func sqlite3_result_error_code(_ p0: OpaquePointer!, _ p1: Int32) { SQLite3.sqlite3_result_error_code(p0, p1) }
    public func sqlite3_result_int(_ p0: OpaquePointer!, _ p1: Int32) { SQLite3.sqlite3_result_int(p0, p1) }
    public func sqlite3_result_int64(_ p0: OpaquePointer!, _ p1: sqlite3_int64) { SQLite3.sqlite3_result_int64(p0, p1) }
    public func sqlite3_result_null(_ p0: OpaquePointer!) { SQLite3.sqlite3_result_null(p0) }
    public func sqlite3_result_text(_ p0: OpaquePointer!, _ p1: UnsafePointer<CChar>!, _ p2: Int32, _ p3: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!) { SQLite3.sqlite3_result_text(p0, p1, p2, p3) }
    public func sqlite3_result_text64(_ p0: OpaquePointer!, _ p1: UnsafePointer<CChar>!, _ p2: sqlite3_uint64, _ p3: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!, _ encoding: UInt8) { SQLite3.sqlite3_result_text64(p0, p1, p2, p3, encoding) }
    public func sqlite3_result_text16(_ p0: OpaquePointer!, _ p1: UnsafeRawPointer!, _ p2: Int32, _ p3: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!) { SQLite3.sqlite3_result_text16(p0, p1, p2, p3) }
    public func sqlite3_result_text16le(_ p0: OpaquePointer!, _ p1: UnsafeRawPointer!, _ p2: Int32, _ p3: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!) { SQLite3.sqlite3_result_text16le(p0, p1, p2, p3) }
    public func sqlite3_result_text16be(_ p0: OpaquePointer!, _ p1: UnsafeRawPointer!, _ p2: Int32, _ p3: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!) { SQLite3.sqlite3_result_text16be(p0, p1, p2, p3) }
    public func sqlite3_result_value(_ p0: OpaquePointer!, _ p1: OpaquePointer!) { SQLite3.sqlite3_result_value(p0, p1) }

    public func sqlite3_result_pointer(_ p0: OpaquePointer!, _ p1: UnsafeMutableRawPointer!, _ p2: UnsafePointer<CChar>!, _ p3: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!) { SQLite3.sqlite3_result_pointer(p0, p1, p2, p3) }
    public func sqlite3_result_zeroblob(_ p0: OpaquePointer!, _ n: Int32) { SQLite3.sqlite3_result_zeroblob(p0, n) }

    public func sqlite3_result_zeroblob64(_ p0: OpaquePointer!, _ n: sqlite3_uint64) -> Int32 { SQLite3.sqlite3_result_zeroblob64(p0, n) }

    public func sqlite3_result_subtype(_ p0: OpaquePointer!, _ p1: UInt32) { SQLite3.sqlite3_result_subtype(p0, p1) }

    public func sqlite3_create_collation(_ p0: OpaquePointer!, _ zName: UnsafePointer<CChar>!, _ eTextRep: Int32, _ pArg: UnsafeMutableRawPointer!, _ xCompare: (@convention(c) (UnsafeMutableRawPointer?, Int32, UnsafeRawPointer?, Int32, UnsafeRawPointer?) -> Int32)!) -> Int32 { SQLite3.sqlite3_create_collation(p0, zName, eTextRep, pArg, xCompare) }

    public func sqlite3_create_collation_v2(_ p0: OpaquePointer!, _ zName: UnsafePointer<CChar>!, _ eTextRep: Int32, _ pArg: UnsafeMutableRawPointer!, _ xCompare: (@convention(c) (UnsafeMutableRawPointer?, Int32, UnsafeRawPointer?, Int32, UnsafeRawPointer?) -> Int32)!, _ xDestroy: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!) -> Int32 { SQLite3.sqlite3_create_collation_v2(p0, zName, eTextRep, pArg, xCompare, xDestroy) }

    public func sqlite3_create_collation16(_ p0: OpaquePointer!, _ zName: UnsafeRawPointer!, _ eTextRep: Int32, _ pArg: UnsafeMutableRawPointer!, _ xCompare: (@convention(c) (UnsafeMutableRawPointer?, Int32, UnsafeRawPointer?, Int32, UnsafeRawPointer?) -> Int32)!) -> Int32 { SQLite3.sqlite3_create_collation16(p0, zName, eTextRep, pArg, xCompare) }

    public func sqlite3_collation_needed(_ p0: OpaquePointer!, _ p1: UnsafeMutableRawPointer!, _ p2: (@convention(c) (UnsafeMutableRawPointer?, OpaquePointer?, Int32, UnsafePointer<CChar>?) -> Void)!) -> Int32 { SQLite3.sqlite3_collation_needed(p0, p1, p2) }

    public func sqlite3_collation_needed16(_ p0: OpaquePointer!, _ p1: UnsafeMutableRawPointer!, _ p2: (@convention(c) (UnsafeMutableRawPointer?, OpaquePointer?, Int32, UnsafeRawPointer?) -> Void)!) -> Int32 { SQLite3.sqlite3_collation_needed16(p0, p1, p2) }

    public func sqlite3_sleep(_ p0: Int32) -> Int32 { SQLite3.sqlite3_sleep(p0) }

    //public var sqlite3_temp_directory: UnsafeMutablePointer<CChar>!
    //
    //public var sqlite3_data_directory: UnsafeMutablePointer<CChar>!

    public func sqlite3_get_autocommit(_ p0: OpaquePointer!) -> Int32 { SQLite3.sqlite3_get_autocommit(p0) }

    public func sqlite3_db_handle(_ p0: OpaquePointer!) -> OpaquePointer! { SQLite3.sqlite3_db_handle(p0) }

    public func sqlite3_db_name(_ db: OpaquePointer!, _ N: Int32) -> UnsafePointer<CChar>! { SQLite3.sqlite3_db_name(db, N) }

    public func sqlite3_db_filename(_ db: OpaquePointer!, _ zDbName: UnsafePointer<CChar>!) -> sqlite3_filename! { SQLite3.sqlite3_db_filename(db, zDbName) }

    public func sqlite3_db_readonly(_ db: OpaquePointer!, _ zDbName: UnsafePointer<CChar>!) -> Int32 { SQLite3.sqlite3_db_readonly(db, zDbName) }

    public func sqlite3_txn_state(_ p0: OpaquePointer!, _ zSchema: UnsafePointer<CChar>!) -> Int32 { SQLite3.sqlite3_txn_state(p0, zSchema) }

    public var SQLITE_TXN_NONE: Int32 { SQLite3.SQLITE_TXN_NONE }

    public var SQLITE_TXN_READ: Int32 { SQLite3.SQLITE_TXN_READ }

    public var SQLITE_TXN_WRITE: Int32 { SQLite3.SQLITE_TXN_WRITE }

    public func sqlite3_next_stmt(_ pDb: OpaquePointer!, _ pStmt: OpaquePointer!) -> OpaquePointer! { SQLite3.sqlite3_next_stmt(pDb, pStmt) }

    public func sqlite3_commit_hook(_ p0: OpaquePointer!, _ p1: (@convention(c) (UnsafeMutableRawPointer?) -> Int32)!, _ p2: UnsafeMutableRawPointer!) -> UnsafeMutableRawPointer! { SQLite3.sqlite3_commit_hook(p0, p1, p2) }

    public func sqlite3_rollback_hook(_ p0: OpaquePointer!, _ p1: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!, _ p2: UnsafeMutableRawPointer!) -> UnsafeMutableRawPointer! { SQLite3.sqlite3_rollback_hook(p0, p1, p2) }

    public func sqlite3_autovacuum_pages(_ db: OpaquePointer!, _ p0: (@convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?, UInt32, UInt32, UInt32) -> UInt32)!, _ p1: UnsafeMutableRawPointer!, _ p2: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!) -> Int32 { SQLite3.sqlite3_autovacuum_pages(db, p0, p1, p2) }

    public func sqlite3_update_hook(_ p0: OpaquePointer!, _ p1: (@convention(c) (UnsafeMutableRawPointer?, Int32, UnsafePointer<CChar>?, UnsafePointer<CChar>?, sqlite3_int64) -> Void)!, _ p2: UnsafeMutableRawPointer!) -> UnsafeMutableRawPointer! { SQLite3.sqlite3_update_hook(p0, p1, p2) }

    public func sqlite3_release_memory(_ p0: Int32) -> Int32 { SQLite3.sqlite3_release_memory(p0) }

    public func sqlite3_db_release_memory(_ p0: OpaquePointer!) -> Int32 { SQLite3.sqlite3_db_release_memory(p0) }

    public func sqlite3_soft_heap_limit64(_ N: sqlite3_int64) -> sqlite3_int64 { SQLite3.sqlite3_soft_heap_limit64(N) }

    public func sqlite3_table_column_metadata(_ db: OpaquePointer!, _ zDbName: UnsafePointer<CChar>!, _ zTableName: UnsafePointer<CChar>!, _ zColumnName: UnsafePointer<CChar>!, _ pzDataType: UnsafeMutablePointer<UnsafePointer<CChar>?>!, _ pzCollSeq: UnsafeMutablePointer<UnsafePointer<CChar>?>!, _ pNotNull: UnsafeMutablePointer<Int32>!, _ pPrimaryKey: UnsafeMutablePointer<Int32>!, _ pAutoinc: UnsafeMutablePointer<Int32>!) -> Int32 { SQLite3.sqlite3_table_column_metadata(db, zDbName, zTableName, zColumnName, pzDataType, pzCollSeq, pNotNull, pPrimaryKey, pAutoinc) }

    public func sqlite3_auto_extension(_ xEntryPoint: (@convention(c) () -> Void)!) -> Int32 { SQLite3.sqlite3_auto_extension(xEntryPoint) }

    public func sqlite3_cancel_auto_extension(_ xEntryPoint: (@convention(c) () -> Void)!) -> Int32 { SQLite3.sqlite3_cancel_auto_extension(xEntryPoint) }

    public func sqlite3_reset_auto_extension() { SQLite3.sqlite3_reset_auto_extension() }

    //public struct sqlite3_module {
    //
    //    public init()
    //
    //    public init(iVersion: Int32, xCreate: (@convention(c) (OpaquePointer?, UnsafeMutableRawPointer?, Int32, UnsafePointer<UnsafePointer<CChar>?>?, UnsafeMutablePointer<UnsafeMutablePointer<sqlite3_vtab>?>?, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32)!, xConnect: (@convention(c) (OpaquePointer?, UnsafeMutableRawPointer?, Int32, UnsafePointer<UnsafePointer<CChar>?>?, UnsafeMutablePointer<UnsafeMutablePointer<sqlite3_vtab>?>?, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32)!, xBestIndex: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?, UnsafeMutablePointer<sqlite3_index_info>?) -> Int32)!, xDisconnect: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?) -> Int32)!, xDestroy: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?) -> Int32)!, xOpen: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?, UnsafeMutablePointer<UnsafeMutablePointer<sqlite3_vtab_cursor>?>?) -> Int32)!, xClose: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab_cursor>?) -> Int32)!, xFilter: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab_cursor>?, Int32, UnsafePointer<CChar>?, Int32, UnsafeMutablePointer<OpaquePointer?>?) -> Int32)!, xNext: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab_cursor>?) -> Int32)!, xEof: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab_cursor>?) -> Int32)!, xColumn: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab_cursor>?, OpaquePointer?, Int32) -> Int32)!, xRowid: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab_cursor>?, UnsafeMutablePointer<sqlite3_int64>?) -> Int32)!, xUpdate: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?, Int32, UnsafeMutablePointer<OpaquePointer?>?, UnsafeMutablePointer<sqlite3_int64>?) -> Int32)!, xBegin: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?) -> Int32)!, xSync: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?) -> Int32)!, xCommit: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?) -> Int32)!, xRollback: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?) -> Int32)!, xFindFunction: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?, Int32, UnsafePointer<CChar>?, UnsafeMutablePointer<(@convention(c) (OpaquePointer?, Int32, UnsafeMutablePointer<OpaquePointer?>?) -> Void)?>?, UnsafeMutablePointer<UnsafeMutableRawPointer?>?) -> Int32)!, xRename: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?, UnsafePointer<CChar>?) -> Int32)!, xSavepoint: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?, Int32) -> Int32)!, xRelease: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?, Int32) -> Int32)!, xRollbackTo: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?, Int32) -> Int32)!, xShadowName: (@convention(c) (UnsafePointer<CChar>?) -> Int32)!)
    //
    //    public var iVersion: Int32
    //
    //    public var xCreate: (@convention(c) (OpaquePointer?, UnsafeMutableRawPointer?, Int32, UnsafePointer<UnsafePointer<CChar>?>?, UnsafeMutablePointer<UnsafeMutablePointer<sqlite3_vtab>?>?, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32)!
    //
    //    public var xConnect: (@convention(c) (OpaquePointer?, UnsafeMutableRawPointer?, Int32, UnsafePointer<UnsafePointer<CChar>?>?, UnsafeMutablePointer<UnsafeMutablePointer<sqlite3_vtab>?>?, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32)!
    //
    //    public var xBestIndex: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?, UnsafeMutablePointer<sqlite3_index_info>?) -> Int32)!
    //
    //    public var xDisconnect: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?) -> Int32)!
    //
    //    public var xDestroy: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?) -> Int32)!
    //
    //    public var xOpen: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?, UnsafeMutablePointer<UnsafeMutablePointer<sqlite3_vtab_cursor>?>?) -> Int32)!
    //
    //    public var xClose: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab_cursor>?) -> Int32)!
    //
    //    public var xFilter: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab_cursor>?, Int32, UnsafePointer<CChar>?, Int32, UnsafeMutablePointer<OpaquePointer?>?) -> Int32)!
    //
    //    public var xNext: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab_cursor>?) -> Int32)!
    //
    //    public var xEof: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab_cursor>?) -> Int32)!
    //
    //    public var xColumn: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab_cursor>?, OpaquePointer?, Int32) -> Int32)!
    //
    //    public var xRowid: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab_cursor>?, UnsafeMutablePointer<sqlite3_int64>?) -> Int32)!
    //
    //    public var xUpdate: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?, Int32, UnsafeMutablePointer<OpaquePointer?>?, UnsafeMutablePointer<sqlite3_int64>?) -> Int32)!
    //
    //    public var xBegin: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?) -> Int32)!
    //
    //    public var xSync: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?) -> Int32)!
    //
    //    public var xCommit: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?) -> Int32)!
    //
    //    public var xRollback: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?) -> Int32)!
    //
    //    public var xFindFunction: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?, Int32, UnsafePointer<CChar>?, UnsafeMutablePointer<(@convention(c) (OpaquePointer?, Int32, UnsafeMutablePointer<OpaquePointer?>?) -> Void)?>?, UnsafeMutablePointer<UnsafeMutableRawPointer?>?) -> Int32)!
    //
    //    public var xRename: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?, UnsafePointer<CChar>?) -> Int32)!
    //
    //    public var xSavepoint: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?, Int32) -> Int32)!
    //
    //    public var xRelease: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?, Int32) -> Int32)!
    //
    //    public var xRollbackTo: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?, Int32) -> Int32)!
    //
    //    public var xShadowName: (@convention(c) (UnsafePointer<CChar>?) -> Int32)!
    //}

    //public struct sqlite3_index_info {
    //
    //    public init()
    //
    //    public init(nConstraint: Int32, aConstraint: UnsafeMutablePointer<sqlite3_index_constraint>!, nOrderBy: Int32, aOrderBy: UnsafeMutablePointer<sqlite3_index_orderby>!, aConstraintUsage: UnsafeMutablePointer<sqlite3_index_constraint_usage>!, idxNum: Int32, idxStr: UnsafeMutablePointer<CChar>!, needToFreeIdxStr: Int32, orderByConsumed: Int32, estimatedCost: Double, estimatedRows: sqlite3_int64, idxFlags: Int32, colUsed: sqlite3_uint64)
    //
    //    public var nConstraint: Int32
    //
    //    public var aConstraint: UnsafeMutablePointer<sqlite3_index_constraint>!
    //
    //    public var nOrderBy: Int32
    //
    //    public var aOrderBy: UnsafeMutablePointer<sqlite3_index_orderby>!
    //
    //    public var aConstraintUsage: UnsafeMutablePointer<sqlite3_index_constraint_usage>!
    //
    //    public var idxNum: Int32
    //
    //    public var idxStr: UnsafeMutablePointer<CChar>!
    //
    //    public var needToFreeIdxStr: Int32
    //
    //    public var orderByConsumed: Int32
    //
    //    public var estimatedCost: Double
    //
    //    public var estimatedRows: sqlite3_int64
    //
    //    public var idxFlags: Int32
    //
    //    public var colUsed: sqlite3_uint64
    //}

    //public struct sqlite3_index_constraint {
    //
    //    public init()
    //
    //    public init(iColumn: Int32, op: UInt8, usable: UInt8, iTermOffset: Int32)
    //
    //    public var iColumn: Int32
    //
    //    public var op: UInt8
    //
    //    public var usable: UInt8
    //
    //    public var iTermOffset: Int32
    //}

    //public struct sqlite3_index_orderby {
    //
    //    public init()
    //
    //    public init(iColumn: Int32, desc: UInt8)
    //
    //    public var iColumn: Int32
    //
    //    public var desc: UInt8
    //}

    //public struct sqlite3_index_constraint_usage {
    //
    //    public init()
    //
    //    public init(argvIndex: Int32, omit: UInt8)
    //
    //    public var argvIndex: Int32
    //
    //    public var omit: UInt8
    //}

    public var SQLITE_INDEX_SCAN_UNIQUE: Int32 { SQLite3.SQLITE_INDEX_SCAN_UNIQUE }

    public var SQLITE_INDEX_CONSTRAINT_EQ: Int32 { SQLite3.SQLITE_INDEX_CONSTRAINT_EQ }

    public var SQLITE_INDEX_CONSTRAINT_GT: Int32 { SQLite3.SQLITE_INDEX_CONSTRAINT_GT }

    public var SQLITE_INDEX_CONSTRAINT_LE: Int32 { SQLite3.SQLITE_INDEX_CONSTRAINT_LE }

    public var SQLITE_INDEX_CONSTRAINT_LT: Int32 { SQLite3.SQLITE_INDEX_CONSTRAINT_LT }

    public var SQLITE_INDEX_CONSTRAINT_GE: Int32 { SQLite3.SQLITE_INDEX_CONSTRAINT_GE }

    public var SQLITE_INDEX_CONSTRAINT_MATCH: Int32 { SQLite3.SQLITE_INDEX_CONSTRAINT_MATCH }

    public var SQLITE_INDEX_CONSTRAINT_LIKE: Int32 { SQLite3.SQLITE_INDEX_CONSTRAINT_LIKE }

    public var SQLITE_INDEX_CONSTRAINT_GLOB: Int32 { SQLite3.SQLITE_INDEX_CONSTRAINT_GLOB }

    public var SQLITE_INDEX_CONSTRAINT_REGEXP: Int32 { SQLite3.SQLITE_INDEX_CONSTRAINT_REGEXP }

    public var SQLITE_INDEX_CONSTRAINT_NE: Int32 { SQLite3.SQLITE_INDEX_CONSTRAINT_NE }

    public var SQLITE_INDEX_CONSTRAINT_ISNOT: Int32 { SQLite3.SQLITE_INDEX_CONSTRAINT_ISNOT }

    public var SQLITE_INDEX_CONSTRAINT_ISNOTNULL: Int32 { SQLite3.SQLITE_INDEX_CONSTRAINT_ISNOTNULL }

    public var SQLITE_INDEX_CONSTRAINT_ISNULL: Int32 { SQLite3.SQLITE_INDEX_CONSTRAINT_ISNULL }

    public var SQLITE_INDEX_CONSTRAINT_IS: Int32 { SQLite3.SQLITE_INDEX_CONSTRAINT_IS }

    public var SQLITE_INDEX_CONSTRAINT_LIMIT: Int32 { SQLite3.SQLITE_INDEX_CONSTRAINT_LIMIT }

    public var SQLITE_INDEX_CONSTRAINT_OFFSET: Int32 { SQLite3.SQLITE_INDEX_CONSTRAINT_OFFSET }

    public var SQLITE_INDEX_CONSTRAINT_FUNCTION: Int32 { SQLite3.SQLITE_INDEX_CONSTRAINT_FUNCTION }

    //public func sqlite3_create_module(_ db: OpaquePointer!, _ zName: UnsafePointer<CChar>!, _ p: UnsafePointer<sqlite3_module>!, _ pClientData: UnsafeMutableRawPointer!) -> Int32 { SQLite3.sqlite3_create_module(db, zName, p, pClientData) }
    //
    //public func sqlite3_create_module_v2(_ db: OpaquePointer!, _ zName: UnsafePointer<CChar>!, _ p: UnsafePointer<sqlite3_module>!, _ pClientData: UnsafeMutableRawPointer!, _ xDestroy: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!) -> Int32 { SQLite3.sqlite3_create_module_v2(db, zName, p, pClientData, xDestroy) }

    public func sqlite3_drop_modules(_ db: OpaquePointer!, _ azKeep: UnsafeMutablePointer<UnsafePointer<CChar>?>!) -> Int32 { SQLite3.sqlite3_drop_modules(db, azKeep) }

    //public struct sqlite3_vtab {
    //
    //    public init()
    //
    //    public init(pModule: UnsafePointer<sqlite3_module>!, nRef: Int32, zErrMsg: UnsafeMutablePointer<CChar>!)
    //
    //    public var pModule: UnsafePointer<sqlite3_module>!
    //
    //    public var nRef: Int32
    //
    //    public var zErrMsg: UnsafeMutablePointer<CChar>!
    //}

    //public struct sqlite3_vtab_cursor {
    //
    //    public init()
    //
    //    public init(pVtab: UnsafeMutablePointer<sqlite3_vtab>!)
    //
    //    public var pVtab: UnsafeMutablePointer<sqlite3_vtab>!
    //}

    public func sqlite3_declare_vtab(_ p0: OpaquePointer!, _ zSQL: UnsafePointer<CChar>!) -> Int32 { SQLite3.sqlite3_declare_vtab(p0, zSQL) }

    public func sqlite3_overload_function(_ p0: OpaquePointer!, _ zFuncName: UnsafePointer<CChar>!, _ nArg: Int32) -> Int32 { SQLite3.sqlite3_overload_function(p0, zFuncName, nArg) }

    public func sqlite3_blob_open(_ p0: OpaquePointer!, _ zDb: UnsafePointer<CChar>!, _ zTable: UnsafePointer<CChar>!, _ zColumn: UnsafePointer<CChar>!, _ iRow: sqlite3_int64, _ flags: Int32, _ ppBlob: UnsafeMutablePointer<OpaquePointer?>!) -> Int32 { SQLite3.sqlite3_blob_open(p0, zDb, zTable, zColumn, iRow, flags, ppBlob) }

    public func sqlite3_blob_reopen(_ p0: OpaquePointer!, _ p1: sqlite3_int64) -> Int32 { SQLite3.sqlite3_blob_reopen(p0, p1) }

    public func sqlite3_blob_close(_ p0: OpaquePointer!) -> Int32 { SQLite3.sqlite3_blob_close(p0) }

    public func sqlite3_blob_bytes(_ p0: OpaquePointer!) -> Int32 { SQLite3.sqlite3_blob_bytes(p0) }

    public func sqlite3_blob_read(_ p0: OpaquePointer!, _ Z: UnsafeMutableRawPointer!, _ N: Int32, _ iOffset: Int32) -> Int32 { SQLite3.sqlite3_blob_read(p0, Z, N, iOffset) }

    public func sqlite3_blob_write(_ p0: OpaquePointer!, _ z: UnsafeRawPointer!, _ n: Int32, _ iOffset: Int32) -> Int32 { SQLite3.sqlite3_blob_write(p0, z, n, iOffset) }

    //public func sqlite3_vfs_find(_ zVfsName: UnsafePointer<CChar>!) -> UnsafeMutablePointer<sqlite3_vfs>! { SQLite3.sqlite3_vfs_find(zVfsName) }
    //
    //public func sqlite3_vfs_register(_ p0: UnsafeMutablePointer<sqlite3_vfs>!, _ makeDflt: Int32) -> Int32 { SQLite3.sqlite3_vfs_register(p0, makeDflt) }
    //
    //public func sqlite3_vfs_unregister(_ p0: UnsafeMutablePointer<sqlite3_vfs>!) -> Int32 { SQLite3.sqlite3_vfs_unregister(p0) }

    public func sqlite3_mutex_alloc(_ p0: Int32) -> OpaquePointer! { SQLite3.sqlite3_mutex_alloc(p0) }

    public func sqlite3_mutex_free(_ p0: OpaquePointer!) { SQLite3.sqlite3_mutex_free(p0) }

    public func sqlite3_mutex_enter(_ p0: OpaquePointer!) { SQLite3.sqlite3_mutex_enter(p0) }

    public func sqlite3_mutex_try(_ p0: OpaquePointer!) -> Int32 { SQLite3.sqlite3_mutex_try(p0) }

    public func sqlite3_mutex_leave(_ p0: OpaquePointer!) { SQLite3.sqlite3_mutex_leave(p0) }

    //public struct sqlite3_mutex_methods {
    //
    //    public init()
    //
    //    public init(xMutexInit: (@convention(c) () -> Int32)!, xMutexEnd: (@convention(c) () -> Int32)!, xMutexAlloc: (@convention(c) (Int32) -> OpaquePointer?)!, xMutexFree: (@convention(c) (OpaquePointer?) -> Void)!, xMutexEnter: (@convention(c) (OpaquePointer?) -> Void)!, xMutexTry: (@convention(c) (OpaquePointer?) -> Int32)!, xMutexLeave: (@convention(c) (OpaquePointer?) -> Void)!, xMutexHeld: (@convention(c) (OpaquePointer?) -> Int32)!, xMutexNotheld: (@convention(c) (OpaquePointer?) -> Int32)!)
    //
    //    public var xMutexInit: (@convention(c) () -> Int32)!
    //
    //    public var xMutexEnd: (@convention(c) () -> Int32)!
    //
    //    public var xMutexAlloc: (@convention(c) (Int32) -> OpaquePointer?)!
    //
    //    public var xMutexFree: (@convention(c) (OpaquePointer?) -> Void)!
    //
    //    public var xMutexEnter: (@convention(c) (OpaquePointer?) -> Void)!
    //
    //    public var xMutexTry: (@convention(c) (OpaquePointer?) -> Int32)!
    //
    //    public var xMutexLeave: (@convention(c) (OpaquePointer?) -> Void)!
    //
    //    public var xMutexHeld: (@convention(c) (OpaquePointer?) -> Int32)!
    //
    //    public var xMutexNotheld: (@convention(c) (OpaquePointer?) -> Int32)!
    //}

    public var SQLITE_MUTEX_FAST: Int32 { SQLite3.SQLITE_MUTEX_FAST }

    public var SQLITE_MUTEX_RECURSIVE: Int32 { SQLite3.SQLITE_MUTEX_RECURSIVE }

    public var SQLITE_MUTEX_STATIC_MAIN: Int32 { SQLite3.SQLITE_MUTEX_STATIC_MAIN }

    public var SQLITE_MUTEX_STATIC_MEM: Int32 { SQLite3.SQLITE_MUTEX_STATIC_MEM }

    public var SQLITE_MUTEX_STATIC_MEM2: Int32 { SQLite3.SQLITE_MUTEX_STATIC_MEM2 }

    public var SQLITE_MUTEX_STATIC_OPEN: Int32 { SQLite3.SQLITE_MUTEX_STATIC_OPEN }

    public var SQLITE_MUTEX_STATIC_PRNG: Int32 { SQLite3.SQLITE_MUTEX_STATIC_PRNG }

    public var SQLITE_MUTEX_STATIC_LRU: Int32 { SQLite3.SQLITE_MUTEX_STATIC_LRU }

    public var SQLITE_MUTEX_STATIC_LRU2: Int32 { SQLite3.SQLITE_MUTEX_STATIC_LRU2 }

    public var SQLITE_MUTEX_STATIC_PMEM: Int32 { SQLite3.SQLITE_MUTEX_STATIC_PMEM }

    public var SQLITE_MUTEX_STATIC_APP1: Int32 { SQLite3.SQLITE_MUTEX_STATIC_APP1 }

    public var SQLITE_MUTEX_STATIC_APP2: Int32 { SQLite3.SQLITE_MUTEX_STATIC_APP2 }

    public var SQLITE_MUTEX_STATIC_APP3: Int32 { SQLite3.SQLITE_MUTEX_STATIC_APP3 }

    public var SQLITE_MUTEX_STATIC_VFS1: Int32 { SQLite3.SQLITE_MUTEX_STATIC_VFS1 }

    public var SQLITE_MUTEX_STATIC_VFS2: Int32 { SQLite3.SQLITE_MUTEX_STATIC_VFS2 }

    public var SQLITE_MUTEX_STATIC_VFS3: Int32 { SQLite3.SQLITE_MUTEX_STATIC_VFS3 }

    public var SQLITE_MUTEX_STATIC_MASTER: Int32 { SQLite3.SQLITE_MUTEX_STATIC_MASTER }

    public func sqlite3_db_mutex(_ p0: OpaquePointer!) -> OpaquePointer! { SQLite3.sqlite3_db_mutex(p0) }

    public func sqlite3_file_control(_ p0: OpaquePointer!, _ zDbName: UnsafePointer<CChar>!, _ op: Int32, _ p1: UnsafeMutableRawPointer!) -> Int32 { SQLite3.sqlite3_file_control(p0, zDbName, op, p1) }

    public var SQLITE_TESTCTRL_FIRST: Int32 { SQLite3.SQLITE_TESTCTRL_FIRST }

    public var SQLITE_TESTCTRL_PRNG_SAVE: Int32 { SQLite3.SQLITE_TESTCTRL_PRNG_SAVE }

    public var SQLITE_TESTCTRL_PRNG_RESTORE: Int32 { SQLite3.SQLITE_TESTCTRL_PRNG_RESTORE }

    public var SQLITE_TESTCTRL_PRNG_RESET: Int32 { SQLite3.SQLITE_TESTCTRL_PRNG_RESET }

    public var SQLITE_TESTCTRL_BITVEC_TEST: Int32 { SQLite3.SQLITE_TESTCTRL_BITVEC_TEST }

    public var SQLITE_TESTCTRL_FAULT_INSTALL: Int32 { SQLite3.SQLITE_TESTCTRL_FAULT_INSTALL }

    public var SQLITE_TESTCTRL_BENIGN_MALLOC_HOOKS: Int32 { SQLite3.SQLITE_TESTCTRL_BENIGN_MALLOC_HOOKS }

    public var SQLITE_TESTCTRL_PENDING_BYTE: Int32 { SQLite3.SQLITE_TESTCTRL_PENDING_BYTE }

    public var SQLITE_TESTCTRL_ASSERT: Int32 { SQLite3.SQLITE_TESTCTRL_ASSERT }

    public var SQLITE_TESTCTRL_ALWAYS: Int32 { SQLite3.SQLITE_TESTCTRL_ALWAYS }

    public var SQLITE_TESTCTRL_RESERVE: Int32 { SQLite3.SQLITE_TESTCTRL_RESERVE }

    public var SQLITE_TESTCTRL_OPTIMIZATIONS: Int32 { SQLite3.SQLITE_TESTCTRL_OPTIMIZATIONS }

    public var SQLITE_TESTCTRL_ISKEYWORD: Int32 { SQLite3.SQLITE_TESTCTRL_ISKEYWORD }

    public var SQLITE_TESTCTRL_SCRATCHMALLOC: Int32 { SQLite3.SQLITE_TESTCTRL_SCRATCHMALLOC }

    public var SQLITE_TESTCTRL_INTERNAL_FUNCTIONS: Int32 { SQLite3.SQLITE_TESTCTRL_INTERNAL_FUNCTIONS }

    public var SQLITE_TESTCTRL_LOCALTIME_FAULT: Int32 { SQLite3.SQLITE_TESTCTRL_LOCALTIME_FAULT }

    public var SQLITE_TESTCTRL_EXPLAIN_STMT: Int32 { SQLite3.SQLITE_TESTCTRL_EXPLAIN_STMT }

    public var SQLITE_TESTCTRL_ONCE_RESET_THRESHOLD: Int32 { SQLite3.SQLITE_TESTCTRL_ONCE_RESET_THRESHOLD }

    public var SQLITE_TESTCTRL_NEVER_CORRUPT: Int32 { SQLite3.SQLITE_TESTCTRL_NEVER_CORRUPT }

    public var SQLITE_TESTCTRL_VDBE_COVERAGE: Int32 { SQLite3.SQLITE_TESTCTRL_VDBE_COVERAGE }

    public var SQLITE_TESTCTRL_BYTEORDER: Int32 { SQLite3.SQLITE_TESTCTRL_BYTEORDER }

    public var SQLITE_TESTCTRL_ISINIT: Int32 { SQLite3.SQLITE_TESTCTRL_ISINIT }

    public var SQLITE_TESTCTRL_SORTER_MMAP: Int32 { SQLite3.SQLITE_TESTCTRL_SORTER_MMAP }

    public var SQLITE_TESTCTRL_IMPOSTER: Int32 { SQLite3.SQLITE_TESTCTRL_IMPOSTER }

    public var SQLITE_TESTCTRL_PARSER_COVERAGE: Int32 { SQLite3.SQLITE_TESTCTRL_PARSER_COVERAGE }

    public var SQLITE_TESTCTRL_RESULT_INTREAL: Int32 { SQLite3.SQLITE_TESTCTRL_RESULT_INTREAL }

    public var SQLITE_TESTCTRL_PRNG_SEED: Int32 { SQLite3.SQLITE_TESTCTRL_PRNG_SEED }

    public var SQLITE_TESTCTRL_EXTRA_SCHEMA_CHECKS: Int32 { SQLite3.SQLITE_TESTCTRL_EXTRA_SCHEMA_CHECKS }

    public var SQLITE_TESTCTRL_SEEK_COUNT: Int32 { SQLite3.SQLITE_TESTCTRL_SEEK_COUNT }

    public var SQLITE_TESTCTRL_TRACEFLAGS: Int32 { SQLite3.SQLITE_TESTCTRL_TRACEFLAGS }

    public var SQLITE_TESTCTRL_TUNE: Int32 { SQLite3.SQLITE_TESTCTRL_TUNE }

    public var SQLITE_TESTCTRL_LOGEST: Int32 { SQLite3.SQLITE_TESTCTRL_LOGEST }

    public var SQLITE_TESTCTRL_USELONGDOUBLE: Int32 { SQLite3.SQLITE_TESTCTRL_USELONGDOUBLE }

    public var SQLITE_TESTCTRL_LAST: Int32 { SQLite3.SQLITE_TESTCTRL_LAST }

    public func sqlite3_keyword_count() -> Int32 { SQLite3.sqlite3_keyword_count() }

    public func sqlite3_keyword_name(_ p0: Int32, _ p1: UnsafeMutablePointer<UnsafePointer<CChar>?>!, _ p2: UnsafeMutablePointer<Int32>!) -> Int32 { SQLite3.sqlite3_keyword_name(p0, p1, p2) }

    public func sqlite3_keyword_check(_ p0: UnsafePointer<CChar>!, _ p1: Int32) -> Int32 { SQLite3.sqlite3_keyword_check(p0, p1) }

    public func sqlite3_str_new(_ p0: OpaquePointer!) -> OpaquePointer! { SQLite3.sqlite3_str_new(p0) }

    public func sqlite3_str_finish(_ p0: OpaquePointer!) -> UnsafeMutablePointer<CChar>! { SQLite3.sqlite3_str_finish(p0) }

    public func sqlite3_str_vappendf(_ p0: OpaquePointer!, _ zFormat: UnsafePointer<CChar>!, _ p1: CVaListPointer) { SQLite3.sqlite3_str_vappendf(p0, zFormat, p1) }

    public func sqlite3_str_append(_ p0: OpaquePointer!, _ zIn: UnsafePointer<CChar>!, _ N: Int32) { SQLite3.sqlite3_str_append(p0, zIn, N) }

    public func sqlite3_str_appendall(_ p0: OpaquePointer!, _ zIn: UnsafePointer<CChar>!) { SQLite3.sqlite3_str_appendall(p0, zIn) }

    public func sqlite3_str_appendchar(_ p0: OpaquePointer!, _ N: Int32, _ C: CChar) { SQLite3.sqlite3_str_appendchar(p0, N, C) }

    public func sqlite3_str_reset(_ p0: OpaquePointer!) { SQLite3.sqlite3_str_reset(p0) }

    public func sqlite3_str_errcode(_ p0: OpaquePointer!) -> Int32 { SQLite3.sqlite3_str_errcode(p0) }

    public func sqlite3_str_length(_ p0: OpaquePointer!) -> Int32 { SQLite3.sqlite3_str_length(p0) }

    public func sqlite3_str_value(_ p0: OpaquePointer!) -> UnsafeMutablePointer<CChar>! { SQLite3.sqlite3_str_value(p0) }

    public func sqlite3_status(_ op: Int32, _ pCurrent: UnsafeMutablePointer<Int32>!, _ pHighwater: UnsafeMutablePointer<Int32>!, _ resetFlag: Int32) -> Int32 { SQLite3.sqlite3_status(op, pCurrent, pHighwater, resetFlag) }

    public func sqlite3_status64(_ op: Int32, _ pCurrent: UnsafeMutablePointer<sqlite3_int64>!, _ pHighwater: UnsafeMutablePointer<sqlite3_int64>!, _ resetFlag: Int32) -> Int32 { SQLite3.sqlite3_status64(op, pCurrent, pHighwater, resetFlag) }

    public var SQLITE_STATUS_MEMORY_USED: Int32 { SQLite3.SQLITE_STATUS_MEMORY_USED }

    public var SQLITE_STATUS_PAGECACHE_USED: Int32 { SQLite3.SQLITE_STATUS_PAGECACHE_USED }

    public var SQLITE_STATUS_PAGECACHE_OVERFLOW: Int32 { SQLite3.SQLITE_STATUS_PAGECACHE_OVERFLOW }

    public var SQLITE_STATUS_SCRATCH_USED: Int32 { SQLite3.SQLITE_STATUS_SCRATCH_USED }

    public var SQLITE_STATUS_SCRATCH_OVERFLOW: Int32 { SQLite3.SQLITE_STATUS_SCRATCH_OVERFLOW }

    public var SQLITE_STATUS_MALLOC_SIZE: Int32 { SQLite3.SQLITE_STATUS_MALLOC_SIZE }

    public var SQLITE_STATUS_PARSER_STACK: Int32 { SQLite3.SQLITE_STATUS_PARSER_STACK }

    public var SQLITE_STATUS_PAGECACHE_SIZE: Int32 { SQLite3.SQLITE_STATUS_PAGECACHE_SIZE }

    public var SQLITE_STATUS_SCRATCH_SIZE: Int32 { SQLite3.SQLITE_STATUS_SCRATCH_SIZE }

    public var SQLITE_STATUS_MALLOC_COUNT: Int32 { SQLite3.SQLITE_STATUS_MALLOC_COUNT }

    public func sqlite3_db_status(_ p0: OpaquePointer!, _ op: Int32, _ pCur: UnsafeMutablePointer<Int32>!, _ pHiwtr: UnsafeMutablePointer<Int32>!, _ resetFlg: Int32) -> Int32 { SQLite3.sqlite3_db_status(p0, op, pCur, pHiwtr, resetFlg) }

    public var SQLITE_DBSTATUS_LOOKASIDE_USED: Int32 { SQLite3.SQLITE_DBSTATUS_LOOKASIDE_USED }

    public var SQLITE_DBSTATUS_CACHE_USED: Int32 { SQLite3.SQLITE_DBSTATUS_CACHE_USED }

    public var SQLITE_DBSTATUS_SCHEMA_USED: Int32 { SQLite3.SQLITE_DBSTATUS_SCHEMA_USED }

    public var SQLITE_DBSTATUS_STMT_USED: Int32 { SQLite3.SQLITE_DBSTATUS_STMT_USED }

    public var SQLITE_DBSTATUS_LOOKASIDE_HIT: Int32 { SQLite3.SQLITE_DBSTATUS_LOOKASIDE_HIT }

    public var SQLITE_DBSTATUS_LOOKASIDE_MISS_SIZE: Int32 { SQLite3.SQLITE_DBSTATUS_LOOKASIDE_MISS_SIZE }

    public var SQLITE_DBSTATUS_LOOKASIDE_MISS_FULL: Int32 { SQLite3.SQLITE_DBSTATUS_LOOKASIDE_MISS_FULL }

    public var SQLITE_DBSTATUS_CACHE_HIT: Int32 { SQLite3.SQLITE_DBSTATUS_CACHE_HIT }

    public var SQLITE_DBSTATUS_CACHE_MISS: Int32 { SQLite3.SQLITE_DBSTATUS_CACHE_MISS }

    public var SQLITE_DBSTATUS_CACHE_WRITE: Int32 { SQLite3.SQLITE_DBSTATUS_CACHE_WRITE }

    public var SQLITE_DBSTATUS_DEFERRED_FKS: Int32 { SQLite3.SQLITE_DBSTATUS_DEFERRED_FKS }

    public var SQLITE_DBSTATUS_CACHE_USED_SHARED: Int32 { SQLite3.SQLITE_DBSTATUS_CACHE_USED_SHARED }

    public var SQLITE_DBSTATUS_CACHE_SPILL: Int32 { SQLite3.SQLITE_DBSTATUS_CACHE_SPILL }

    public var SQLITE_DBSTATUS_MAX: Int32 { SQLite3.SQLITE_DBSTATUS_MAX }

    public func sqlite3_stmt_status(_ p0: OpaquePointer!, _ op: Int32, _ resetFlg: Int32) -> Int32 { SQLite3.sqlite3_stmt_status(p0, op, resetFlg) }

    public var SQLITE_STMTSTATUS_FULLSCAN_STEP: Int32 { SQLite3.SQLITE_STMTSTATUS_FULLSCAN_STEP }

    public var SQLITE_STMTSTATUS_SORT: Int32 { SQLite3.SQLITE_STMTSTATUS_SORT }

    public var SQLITE_STMTSTATUS_AUTOINDEX: Int32 { SQLite3.SQLITE_STMTSTATUS_AUTOINDEX }

    public var SQLITE_STMTSTATUS_VM_STEP: Int32 { SQLite3.SQLITE_STMTSTATUS_VM_STEP }

    public var SQLITE_STMTSTATUS_REPREPARE: Int32 { SQLite3.SQLITE_STMTSTATUS_REPREPARE }

    public var SQLITE_STMTSTATUS_RUN: Int32 { SQLite3.SQLITE_STMTSTATUS_RUN }

    public var SQLITE_STMTSTATUS_FILTER_MISS: Int32 { SQLite3.SQLITE_STMTSTATUS_FILTER_MISS }

    public var SQLITE_STMTSTATUS_FILTER_HIT: Int32 { SQLite3.SQLITE_STMTSTATUS_FILTER_HIT }

    public var SQLITE_STMTSTATUS_MEMUSED: Int32 { SQLite3.SQLITE_STMTSTATUS_MEMUSED }

    //public struct sqlite3_pcache_page {
    //
    //    public init()
    //
    //    public init(pBuf: UnsafeMutableRawPointer!, pExtra: UnsafeMutableRawPointer!)
    //
    //    public var pBuf: UnsafeMutableRawPointer!
    //
    //    public var pExtra: UnsafeMutableRawPointer!
    //}

    //public struct sqlite3_pcache_methods2 {
    //
    //    public init()
    //
    //    public init(iVersion: Int32, pArg: UnsafeMutableRawPointer!, xInit: (@convention(c) (UnsafeMutableRawPointer?) -> Int32)!, xShutdown: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!, xCreate: (@convention(c) (Int32, Int32, Int32) -> OpaquePointer?)!, xCachesize: (@convention(c) (OpaquePointer?, Int32) -> Void)!, xPagecount: (@convention(c) (OpaquePointer?) -> Int32)!, xFetch: (@convention(c) (OpaquePointer?, UInt32, Int32) -> UnsafeMutablePointer<sqlite3_pcache_page>?)!, xUnpin: (@convention(c) (OpaquePointer?, UnsafeMutablePointer<sqlite3_pcache_page>?, Int32) -> Void)!, xRekey: (@convention(c) (OpaquePointer?, UnsafeMutablePointer<sqlite3_pcache_page>?, UInt32, UInt32) -> Void)!, xTruncate: (@convention(c) (OpaquePointer?, UInt32) -> Void)!, xDestroy: (@convention(c) (OpaquePointer?) -> Void)!, xShrink: (@convention(c) (OpaquePointer?) -> Void)!)
    //
    //    public var iVersion: Int32
    //
    //    public var pArg: UnsafeMutableRawPointer!
    //
    //    public var xInit: (@convention(c) (UnsafeMutableRawPointer?) -> Int32)!
    //
    //    public var xShutdown: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!
    //
    //    public var xCreate: (@convention(c) (Int32, Int32, Int32) -> OpaquePointer?)!
    //
    //    public var xCachesize: (@convention(c) (OpaquePointer?, Int32) -> Void)!
    //
    //    public var xPagecount: (@convention(c) (OpaquePointer?) -> Int32)!
    //
    //    public var xFetch: (@convention(c) (OpaquePointer?, UInt32, Int32) -> UnsafeMutablePointer<sqlite3_pcache_page>?)!
    //
    //    public var xUnpin: (@convention(c) (OpaquePointer?, UnsafeMutablePointer<sqlite3_pcache_page>?, Int32) -> Void)!
    //
    //    public var xRekey: (@convention(c) (OpaquePointer?, UnsafeMutablePointer<sqlite3_pcache_page>?, UInt32, UInt32) -> Void)!
    //
    //    public var xTruncate: (@convention(c) (OpaquePointer?, UInt32) -> Void)!
    //
    //    public var xDestroy: (@convention(c) (OpaquePointer?) -> Void)!
    //
    //    public var xShrink: (@convention(c) (OpaquePointer?) -> Void)!
    //}

    //public struct sqlite3_pcache_methods {
    //
    //    public init()
    //
    //    public init(pArg: UnsafeMutableRawPointer!, xInit: (@convention(c) (UnsafeMutableRawPointer?) -> Int32)!, xShutdown: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!, xCreate: (@convention(c) (Int32, Int32) -> OpaquePointer?)!, xCachesize: (@convention(c) (OpaquePointer?, Int32) -> Void)!, xPagecount: (@convention(c) (OpaquePointer?) -> Int32)!, xFetch: (@convention(c) (OpaquePointer?, UInt32, Int32) -> UnsafeMutableRawPointer?)!, xUnpin: (@convention(c) (OpaquePointer?, UnsafeMutableRawPointer?, Int32) -> Void)!, xRekey: (@convention(c) (OpaquePointer?, UnsafeMutableRawPointer?, UInt32, UInt32) -> Void)!, xTruncate: (@convention(c) (OpaquePointer?, UInt32) -> Void)!, xDestroy: (@convention(c) (OpaquePointer?) -> Void)!)
    //
    //    public var pArg: UnsafeMutableRawPointer!
    //
    //    public var xInit: (@convention(c) (UnsafeMutableRawPointer?) -> Int32)!
    //
    //    public var xShutdown: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!
    //
    //    public var xCreate: (@convention(c) (Int32, Int32) -> OpaquePointer?)!
    //
    //    public var xCachesize: (@convention(c) (OpaquePointer?, Int32) -> Void)!
    //
    //    public var xPagecount: (@convention(c) (OpaquePointer?) -> Int32)!
    //
    //    public var xFetch: (@convention(c) (OpaquePointer?, UInt32, Int32) -> UnsafeMutableRawPointer?)!
    //
    //    public var xUnpin: (@convention(c) (OpaquePointer?, UnsafeMutableRawPointer?, Int32) -> Void)!
    //
    //    public var xRekey: (@convention(c) (OpaquePointer?, UnsafeMutableRawPointer?, UInt32, UInt32) -> Void)!
    //
    //    public var xTruncate: (@convention(c) (OpaquePointer?, UInt32) -> Void)!
    //
    //    public var xDestroy: (@convention(c) (OpaquePointer?) -> Void)!
    //}

    public func sqlite3_backup_init(_ pDest: OpaquePointer!, _ zDestName: UnsafePointer<CChar>!, _ pSource: OpaquePointer!, _ zSourceName: UnsafePointer<CChar>!) -> OpaquePointer! { SQLite3.sqlite3_backup_init(pDest, zDestName, pSource, zSourceName) }

    public func sqlite3_backup_step(_ p: OpaquePointer!, _ nPage: Int32) -> Int32 { SQLite3.sqlite3_backup_step(p, nPage) }

    public func sqlite3_backup_finish(_ p: OpaquePointer!) -> Int32 { SQLite3.sqlite3_backup_finish(p) }

    public func sqlite3_backup_remaining(_ p: OpaquePointer!) -> Int32 { SQLite3.sqlite3_backup_remaining(p) }

    public func sqlite3_backup_pagecount(_ p: OpaquePointer!) -> Int32 { SQLite3.sqlite3_backup_pagecount(p) }

    public func sqlite3_stricmp(_ p0: UnsafePointer<CChar>!, _ p1: UnsafePointer<CChar>!) -> Int32 { SQLite3.sqlite3_stricmp(p0, p1) }

    public func sqlite3_strnicmp(_ p0: UnsafePointer<CChar>!, _ p1: UnsafePointer<CChar>!, _ p2: Int32) -> Int32 { SQLite3.sqlite3_strnicmp(p0, p1, p2) }

    public func sqlite3_strglob(_ zGlob: UnsafePointer<CChar>!, _ zStr: UnsafePointer<CChar>!) -> Int32 { SQLite3.sqlite3_strglob(zGlob, zStr) }

    public func sqlite3_strlike(_ zGlob: UnsafePointer<CChar>!, _ zStr: UnsafePointer<CChar>!, _ cEsc: UInt32) -> Int32 { SQLite3.sqlite3_strlike(zGlob, zStr, cEsc) }

    public func sqlite3_wal_hook(_ p0: OpaquePointer!, _ p1: (@convention(c) (UnsafeMutableRawPointer?, OpaquePointer?, UnsafePointer<CChar>?, Int32) -> Int32)!, _ p2: UnsafeMutableRawPointer!) -> UnsafeMutableRawPointer! { SQLite3.sqlite3_wal_hook(p0, p1, p2) }

    public func sqlite3_wal_autocheckpoint(_ db: OpaquePointer!, _ N: Int32) -> Int32 { SQLite3.sqlite3_wal_autocheckpoint(db, N) }

    public func sqlite3_wal_checkpoint(_ db: OpaquePointer!, _ zDb: UnsafePointer<CChar>!) -> Int32 { SQLite3.sqlite3_wal_checkpoint(db, zDb) }

    public func sqlite3_wal_checkpoint_v2(_ db: OpaquePointer!, _ zDb: UnsafePointer<CChar>!, _ eMode: Int32, _ pnLog: UnsafeMutablePointer<Int32>!, _ pnCkpt: UnsafeMutablePointer<Int32>!) -> Int32 { SQLite3.sqlite3_wal_checkpoint_v2(db, zDb, eMode, pnLog, pnCkpt) }

    public var SQLITE_CHECKPOINT_PASSIVE: Int32 { SQLite3.SQLITE_CHECKPOINT_PASSIVE }

    public var SQLITE_CHECKPOINT_FULL: Int32 { SQLite3.SQLITE_CHECKPOINT_FULL }

    public var SQLITE_CHECKPOINT_RESTART: Int32 { SQLite3.SQLITE_CHECKPOINT_RESTART }

    public var SQLITE_CHECKPOINT_TRUNCATE: Int32 { SQLite3.SQLITE_CHECKPOINT_TRUNCATE }

    public var SQLITE_VTAB_CONSTRAINT_SUPPORT: Int32 { SQLite3.SQLITE_VTAB_CONSTRAINT_SUPPORT }

    public var SQLITE_VTAB_INNOCUOUS: Int32 { SQLite3.SQLITE_VTAB_INNOCUOUS }

    public var SQLITE_VTAB_DIRECTONLY: Int32 { SQLite3.SQLITE_VTAB_DIRECTONLY }

    public var SQLITE_VTAB_USES_ALL_SCHEMAS: Int32 { SQLite3.SQLITE_VTAB_USES_ALL_SCHEMAS }

    public func sqlite3_vtab_on_conflict(_ p0: OpaquePointer!) -> Int32 { SQLite3.sqlite3_vtab_on_conflict(p0) }

    public func sqlite3_vtab_nochange(_ p0: OpaquePointer!) -> Int32 { SQLite3.sqlite3_vtab_nochange(p0) }

    //public func sqlite3_vtab_collation(_ p0: UnsafeMutablePointer<sqlite3_index_info>!, _ p1: Int32) -> UnsafePointer<CChar>! { SQLite3.sqlite3_vtab_collation(p0, p1) }
    //
    //public func sqlite3_vtab_distinct(_ p0: UnsafeMutablePointer<sqlite3_index_info>!) -> Int32 { SQLite3.sqlite3_vtab_distinct(p0) }
    //
    //public func sqlite3_vtab_in(_ p0: UnsafeMutablePointer<sqlite3_index_info>!, _ iCons: Int32, _ bHandle: Int32) -> Int32 { SQLite3.sqlite3_vtab_in(p0, iCons, bHandle) }
    //
    //public func sqlite3_vtab_in_first(_ pVal: OpaquePointer!, _ ppOut: UnsafeMutablePointer<OpaquePointer?>!) -> Int32 { SQLite3.sqlite3_vtab_in_first(pVal, ppOut) }
    //
    //public func sqlite3_vtab_in_next(_ pVal: OpaquePointer!, _ ppOut: UnsafeMutablePointer<OpaquePointer?>!) -> Int32 { SQLite3.sqlite3_vtab_in_next(pVal, ppOut) }
    //
    //public func sqlite3_vtab_rhs_value(_ p0: UnsafeMutablePointer<sqlite3_index_info>!, _ p1: Int32, _ ppVal: UnsafeMutablePointer<OpaquePointer?>!) -> Int32 { SQLite3.sqlite3_vtab_rhs_value(p0, p1, ppVal) }

    public var SQLITE_ROLLBACK: Int32 { SQLite3.SQLITE_ROLLBACK }

    public var SQLITE_FAIL: Int32 { SQLite3.SQLITE_FAIL }

    public var SQLITE_REPLACE: Int32 { SQLite3.SQLITE_REPLACE }

    public var SQLITE_SCANSTAT_NLOOP: Int32 { SQLite3.SQLITE_SCANSTAT_NLOOP }

    public var SQLITE_SCANSTAT_NVISIT: Int32 { SQLite3.SQLITE_SCANSTAT_NVISIT }

    public var SQLITE_SCANSTAT_EST: Int32 { SQLite3.SQLITE_SCANSTAT_EST }

    public var SQLITE_SCANSTAT_NAME: Int32 { SQLite3.SQLITE_SCANSTAT_NAME }

    public var SQLITE_SCANSTAT_EXPLAIN: Int32 { SQLite3.SQLITE_SCANSTAT_EXPLAIN }

    public var SQLITE_SCANSTAT_SELECTID: Int32 { SQLite3.SQLITE_SCANSTAT_SELECTID }

    public var SQLITE_SCANSTAT_PARENTID: Int32 { SQLite3.SQLITE_SCANSTAT_PARENTID }

    public var SQLITE_SCANSTAT_NCYCLE: Int32 { SQLite3.SQLITE_SCANSTAT_NCYCLE }

    public func sqlite3_stmt_scanstatus(_ pStmt: OpaquePointer!, _ idx: Int32, _ iScanStatusOp: Int32, _ pOut: UnsafeMutableRawPointer!) -> Int32 { SQLite3.sqlite3_stmt_scanstatus(pStmt, idx, iScanStatusOp, pOut) }

    public func sqlite3_stmt_scanstatus_v2(_ pStmt: OpaquePointer!, _ idx: Int32, _ iScanStatusOp: Int32, _ flags: Int32, _ pOut: UnsafeMutableRawPointer!) -> Int32 { SQLite3.sqlite3_stmt_scanstatus_v2(pStmt, idx, iScanStatusOp, flags, pOut) }

    public var SQLITE_SCANSTAT_COMPLEX: Int32 { SQLite3.SQLITE_SCANSTAT_COMPLEX }

    public func sqlite3_stmt_scanstatus_reset(_ p0: OpaquePointer!) { SQLite3.sqlite3_stmt_scanstatus_reset(p0) }

    public func sqlite3_db_cacheflush(_ p0: OpaquePointer!) -> Int32 { SQLite3.sqlite3_db_cacheflush(p0) }

    public func sqlite3_system_errno(_ p0: OpaquePointer!) -> Int32 { SQLite3.sqlite3_system_errno(p0) }

//    public struct sqlite3_snapshot {
//    //    public init()
//    //
//    //    public init(hidden: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8))
//
//        public var hidden: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)
//    }

    public func sqlite3_snapshot_get(_ db: OpaquePointer!, _ zSchema: UnsafePointer<CChar>!, _ ppSnapshot: UnsafeMutablePointer<UnsafeMutablePointer<sqlite3_snapshot>?>!) -> Int32 {
        return SQLITE_ERROR; fatalError(
            "SQLInterface FIXME: need to convert between sqlite3_snapshot"
        ) /* SQLite3.sqlite3_snapshot_get(db, zSchema, ppSnapshot) */
    }

    public func sqlite3_snapshot_open(_ db: OpaquePointer!, _ zSchema: UnsafePointer<CChar>!, _ pSnapshot: UnsafeMutablePointer<sqlite3_snapshot>!) -> Int32 { return SQLITE_ERROR; fatalError("SQLInterface FIXME: need to convert between sqlite3_snapshot") /* SQLite3.sqlite3_snapshot_open(db, zSchema, pSnapshot) */ }

    public func sqlite3_snapshot_free(_ p0: UnsafeMutablePointer<sqlite3_snapshot>!) { return; fatalError("SQLInterface FIXME: need to convert between sqlite3_snapshot") /* SQLite3.sqlite3_snapshot_free(p0) */ }

    public func sqlite3_snapshot_cmp(_ p1: UnsafeMutablePointer<sqlite3_snapshot>!, _ p2: UnsafeMutablePointer<sqlite3_snapshot>!) -> Int32 { return SQLITE_ERROR; fatalError("SQLInterface FIXME: need to convert between sqlite3_snapshot") /* SQLite3.sqlite3_snapshot_cmp(p1, p2) */ }

    public func sqlite3_snapshot_recover(_ db: OpaquePointer!, _ zDb: UnsafePointer<CChar>!) -> Int32 { SQLite3.sqlite3_snapshot_recover(db, zDb) }

    public func sqlite3_serialize(_ db: OpaquePointer!, _ zSchema: UnsafePointer<CChar>!, _ piSize: UnsafeMutablePointer<sqlite3_int64>!, _ mFlags: UInt32) -> UnsafeMutablePointer<UInt8>! { SQLite3.sqlite3_serialize(db, zSchema, piSize, mFlags) }

    public var SQLITE_SERIALIZE_NOCOPY: Int32 { SQLite3.SQLITE_SERIALIZE_NOCOPY }

    public func sqlite3_deserialize(_ db: OpaquePointer!, _ zSchema: UnsafePointer<CChar>!, _ pData: UnsafeMutablePointer<UInt8>!, _ szDb: sqlite3_int64, _ szBuf: sqlite3_int64, _ mFlags: UInt32) -> Int32 { SQLite3.sqlite3_deserialize(db, zSchema, pData, szDb, szBuf, mFlags) }

    public var SQLITE_DESERIALIZE_FREEONCLOSE: Int32 { SQLite3.SQLITE_DESERIALIZE_FREEONCLOSE }

    public var SQLITE_DESERIALIZE_RESIZEABLE: Int32 { SQLite3.SQLITE_DESERIALIZE_RESIZEABLE }

    public var SQLITE_DESERIALIZE_READONLY: Int32 { SQLite3.SQLITE_DESERIALIZE_READONLY }

    public typealias sqlite3_rtree_dbl = Double

    //public func sqlite3_rtree_geometry_callback(_ db: OpaquePointer!, _ zGeom: UnsafePointer<CChar>!, _ xGeom: (@convention(c) (UnsafeMutablePointer<sqlite3_rtree_geometry>?, Int32, UnsafeMutablePointer<sqlite3_rtree_dbl>?, UnsafeMutablePointer<Int32>?) -> Int32)!, _ pContext: UnsafeMutableRawPointer!) -> Int32 { SQLite3.sqlite3_rtree_geometry_callback(db, zGeom, xGeom) (UnsafeMutablePointer<sqlite3_rtree_geometry>?, Int32, UnsafeMutablePointer<sqlite3_rtree_dbl>?, UnsafeMutablePointer<Int32>?) -> Int32)!, pContext) }
    //
    //public struct sqlite3_rtree_geometry {
    //
    //    public init()
    //
    //    public init(pContext: UnsafeMutableRawPointer!, nParam: Int32, aParam: UnsafeMutablePointer<sqlite3_rtree_dbl>!, pUser: UnsafeMutableRawPointer!, xDelUser: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!)
    //
    //    public var pContext: UnsafeMutableRawPointer!
    //
    //    public var nParam: Int32
    //
    //    public var aParam: UnsafeMutablePointer<sqlite3_rtree_dbl>!
    //
    //    public var pUser: UnsafeMutableRawPointer!
    //
    //    public var xDelUser: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!
    //}
    //
    //public func sqlite3_rtree_query_callback(_ db: OpaquePointer!, _ zQueryFunc: UnsafePointer<CChar>!, _ xQueryFunc: (@convention(c) (UnsafeMutablePointer<sqlite3_rtree_query_info>?) -> Int32)!, _ pContext: UnsafeMutableRawPointer!, _ xDestructor: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!) -> Int32 { SQLite3.sqlite3_rtree_query_callback(db, zQueryFunc, xQueryFunc) (UnsafeMutablePointer<sqlite3_rtree_query_info>?) -> Int32)!, pContext, xDestructor) }
    //
    //public struct sqlite3_rtree_query_info {
    //
    //    public init()
    //
    //    public init(pContext: UnsafeMutableRawPointer!, nParam: Int32, aParam: UnsafeMutablePointer<sqlite3_rtree_dbl>!, pUser: UnsafeMutableRawPointer!, xDelUser: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!, aCoord: UnsafeMutablePointer<sqlite3_rtree_dbl>!, anQueue: UnsafeMutablePointer<UInt32>!, nCoord: Int32, iLevel: Int32, mxLevel: Int32, iRowid: sqlite3_int64, rParentScore: sqlite3_rtree_dbl, eParentWithin: Int32, eWithin: Int32, rScore: sqlite3_rtree_dbl, apSqlParam: UnsafeMutablePointer<OpaquePointer?>!)
    //
    //    public var pContext: UnsafeMutableRawPointer!
    //
    //    public var nParam: Int32
    //
    //    public var aParam: UnsafeMutablePointer<sqlite3_rtree_dbl>!
    //
    //    public var pUser: UnsafeMutableRawPointer!
    //
    //    public var xDelUser: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!
    //
    //    public var aCoord: UnsafeMutablePointer<sqlite3_rtree_dbl>!
    //
    //    public var anQueue: UnsafeMutablePointer<UInt32>!
    //
    //    public var nCoord: Int32
    //
    //    public var iLevel: Int32
    //
    //    public var mxLevel: Int32
    //
    //    public var iRowid: sqlite3_int64
    //
    //    public var rParentScore: sqlite3_rtree_dbl
    //
    //    public var eParentWithin: Int32
    //
    //    public var eWithin: Int32
    //
    //    public var rScore: sqlite3_rtree_dbl
    //
    //    public var apSqlParam: UnsafeMutablePointer<OpaquePointer?>!
    //}

    public var NOT_WITHIN: Int32 { SQLite3.NOT_WITHIN }

    public var PARTLY_WITHIN: Int32 { SQLite3.PARTLY_WITHIN }

    public var FULLY_WITHIN: Int32 { SQLite3.FULLY_WITHIN }

    public typealias fts5_extension_function = (UnsafePointer<Fts5ExtensionApi>?, OpaquePointer?, OpaquePointer?, Int32, UnsafeMutablePointer<OpaquePointer?>?) -> Void

    //public struct Fts5PhraseIter {
    //
    //    public init()
    //
    //    public init(a: UnsafePointer<UInt8>!, b: UnsafePointer<UInt8>!)
    //
    //    public var a: UnsafePointer<UInt8>!
    //
    //    public var b: UnsafePointer<UInt8>!
    //}

    public struct Fts5ExtensionApi {

    //    public init()

    //    public init(iVersion: Int32, xUserData: (@convention(c) (OpaquePointer?) -> UnsafeMutableRawPointer?)!, xColumnCount: (@convention(c) (OpaquePointer?) -> Int32)!, xRowCount: (@convention(c) (OpaquePointer?, UnsafeMutablePointer<sqlite3_int64>?) -> Int32)!, xColumnTotalSize: (@convention(c) (OpaquePointer?, Int32, UnsafeMutablePointer<sqlite3_int64>?) -> Int32)!, xTokenize: (@convention(c) (OpaquePointer?, UnsafePointer<CChar>?, Int32, UnsafeMutableRawPointer?, (@convention(c) (UnsafeMutableRawPointer?, Int32, UnsafePointer<CChar>?, Int32, Int32, Int32) -> Int32)?) -> Int32)!, xPhraseCount: (@convention(c) (OpaquePointer?) -> Int32)!, xPhraseSize: (@convention(c) (OpaquePointer?, Int32) -> Int32)!, xInstCount: (@convention(c) (OpaquePointer?, UnsafeMutablePointer<Int32>?) -> Int32)!, xInst: (@convention(c) (OpaquePointer?, Int32, UnsafeMutablePointer<Int32>?, UnsafeMutablePointer<Int32>?, UnsafeMutablePointer<Int32>?) -> Int32)!, xRowid: (@convention(c) (OpaquePointer?) -> sqlite3_int64)!, xColumnText: (@convention(c) (OpaquePointer?, Int32, UnsafeMutablePointer<UnsafePointer<CChar>?>?, UnsafeMutablePointer<Int32>?) -> Int32)!, xColumnSize: (@convention(c) (OpaquePointer?, Int32, UnsafeMutablePointer<Int32>?) -> Int32)!, xQueryPhrase: (@convention(c) (OpaquePointer?, Int32, UnsafeMutableRawPointer?, (@convention(c) (UnsafePointer<Fts5ExtensionApi>?, OpaquePointer?, UnsafeMutableRawPointer?) -> Int32)?) -> Int32)!, xSetAuxdata: (@convention(c) (OpaquePointer?, UnsafeMutableRawPointer?, (@convention(c) (UnsafeMutableRawPointer?) -> Void)?) -> Int32)!, xGetAuxdata: (@convention(c) (OpaquePointer?, Int32) -> UnsafeMutableRawPointer?)!, xPhraseFirst: (@convention(c) (OpaquePointer?, Int32, UnsafeMutablePointer<Fts5PhraseIter>?, UnsafeMutablePointer<Int32>?, UnsafeMutablePointer<Int32>?) -> Int32)!, xPhraseNext: (@convention(c) (OpaquePointer?, UnsafeMutablePointer<Fts5PhraseIter>?, UnsafeMutablePointer<Int32>?, UnsafeMutablePointer<Int32>?) -> Void)!, xPhraseFirstColumn: (@convention(c) (OpaquePointer?, Int32, UnsafeMutablePointer<Fts5PhraseIter>?, UnsafeMutablePointer<Int32>?) -> Int32)!, xPhraseNextColumn: (@convention(c) (OpaquePointer?, UnsafeMutablePointer<Fts5PhraseIter>?, UnsafeMutablePointer<Int32>?) -> Void)!)

    //    public var iVersion: Int32
    //
    //    public var xUserData: (@convention(c) (OpaquePointer?) -> UnsafeMutableRawPointer?)!
    //
    //    public var xColumnCount: (@convention(c) (OpaquePointer?) -> Int32)!
    //
    //    public var xRowCount: (@convention(c) (OpaquePointer?, UnsafeMutablePointer<sqlite3_int64>?) -> Int32)!
    //
    //    public var xColumnTotalSize: (@convention(c) (OpaquePointer?, Int32, UnsafeMutablePointer<sqlite3_int64>?) -> Int32)!
    //
    //    public var xTokenize: (@convention(c) (OpaquePointer?, UnsafePointer<CChar>?, Int32, UnsafeMutableRawPointer?, (@convention(c) (UnsafeMutableRawPointer?, Int32, UnsafePointer<CChar>?, Int32, Int32, Int32) -> Int32)?) -> Int32)!
    //
    //    public var xPhraseCount: (@convention(c) (OpaquePointer?) -> Int32)!
    //
    //    public var xPhraseSize: (@convention(c) (OpaquePointer?, Int32) -> Int32)!
    //
    //    public var xInstCount: (@convention(c) (OpaquePointer?, UnsafeMutablePointer<Int32>?) -> Int32)!
    //
    //    public var xInst: (@convention(c) (OpaquePointer?, Int32, UnsafeMutablePointer<Int32>?, UnsafeMutablePointer<Int32>?, UnsafeMutablePointer<Int32>?) -> Int32)!
    //
    //    public var xRowid: (@convention(c) (OpaquePointer?) -> sqlite3_int64)!
    //
    //    public var xColumnText: (@convention(c) (OpaquePointer?, Int32, UnsafeMutablePointer<UnsafePointer<CChar>?>?, UnsafeMutablePointer<Int32>?) -> Int32)!
    //
    //    public var xColumnSize: (@convention(c) (OpaquePointer?, Int32, UnsafeMutablePointer<Int32>?) -> Int32)!
    //
    //    public var xQueryPhrase: (@convention(c) (OpaquePointer?, Int32, UnsafeMutableRawPointer?, (@convention(c) (UnsafePointer<Fts5ExtensionApi>?, OpaquePointer?, UnsafeMutableRawPointer?) -> Int32)?) -> Int32)!
    //
    //    public var xSetAuxdata: (@convention(c) (OpaquePointer?, UnsafeMutableRawPointer?, (@convention(c) (UnsafeMutableRawPointer?) -> Void)?) -> Int32)!
    //
    //    public var xGetAuxdata: (@convention(c) (OpaquePointer?, Int32) -> UnsafeMutableRawPointer?)!
    //
    //    public var xPhraseFirst: (@convention(c) (OpaquePointer?, Int32, UnsafeMutablePointer<Fts5PhraseIter>?, UnsafeMutablePointer<Int32>?, UnsafeMutablePointer<Int32>?) -> Int32)!
    //
    //    public var xPhraseNext: (@convention(c) (OpaquePointer?, UnsafeMutablePointer<Fts5PhraseIter>?, UnsafeMutablePointer<Int32>?, UnsafeMutablePointer<Int32>?) -> Void)!
    //
    //    public var xPhraseFirstColumn: (@convention(c) (OpaquePointer?, Int32, UnsafeMutablePointer<Fts5PhraseIter>?, UnsafeMutablePointer<Int32>?) -> Int32)!
    //
    //    public var xPhraseNextColumn: (@convention(c) (OpaquePointer?, UnsafeMutablePointer<Fts5PhraseIter>?, UnsafeMutablePointer<Int32>?) -> Void)!
    }

    public struct fts5_tokenizer {

    //    public init()

        public init(xCreate: (@convention(c) (UnsafeMutableRawPointer?, UnsafeMutablePointer<UnsafePointer<CChar>?>?, Int32, UnsafeMutablePointer<OpaquePointer?>?) -> Int32)!, xDelete: (@convention(c) (OpaquePointer?) -> Void)!, xTokenize: (@convention(c) (OpaquePointer?, UnsafeMutableRawPointer?, Int32, UnsafePointer<CChar>?, Int32, (@convention(c) (UnsafeMutableRawPointer?, Int32, UnsafePointer<CChar>?, Int32, Int32, Int32) -> Int32)?) -> Int32)!) {

        }

        public var xCreate: (@convention(c) (UnsafeMutableRawPointer?, UnsafeMutablePointer<UnsafePointer<CChar>?>?, Int32, UnsafeMutablePointer<OpaquePointer?>?) -> Int32)!

        public var xDelete: (@convention(c) (OpaquePointer?) -> Void)!

        public var xTokenize: (@convention(c) (OpaquePointer?, UnsafeMutableRawPointer?, Int32, UnsafePointer<CChar>?, Int32, (@convention(c) (UnsafeMutableRawPointer?, Int32, UnsafePointer<CChar>?, Int32, Int32, Int32) -> Int32)?) -> Int32)!
    }

    public var FTS5_TOKENIZE_QUERY: Int32 { SQLite3.FTS5_TOKENIZE_QUERY }

    public var FTS5_TOKENIZE_PREFIX: Int32 { SQLite3.FTS5_TOKENIZE_PREFIX }

    public var FTS5_TOKENIZE_DOCUMENT: Int32 { SQLite3.FTS5_TOKENIZE_DOCUMENT }

    public var FTS5_TOKENIZE_AUX: Int32 { SQLite3.FTS5_TOKENIZE_AUX }

    public var FTS5_TOKEN_COLOCATED: Int32 { SQLite3.FTS5_TOKEN_COLOCATED }

    public struct fts5_api {

    //    public init()

    //    public init(iVersion: Int32, xCreateTokenizer: (@convention(c) (UnsafeMutablePointer<fts5_api>?, UnsafePointer<CChar>?, UnsafeMutableRawPointer?, UnsafeMutablePointer<fts5_tokenizer>?, (@convention(c) (UnsafeMutableRawPointer?) -> Void)?) -> Int32)!, xFindTokenizer: (@convention(c) (UnsafeMutablePointer<fts5_api>?, UnsafePointer<CChar>?, UnsafeMutablePointer<UnsafeMutableRawPointer?>?, UnsafeMutablePointer<fts5_tokenizer>?) -> Int32)!, xCreateFunction: (@convention(c) (UnsafeMutablePointer<fts5_api>?, UnsafePointer<CChar>?, UnsafeMutableRawPointer?, fts5_extension_function?, (@convention(c) (UnsafeMutableRawPointer?) -> Void)?) -> Int32)!)

        public var iVersion: Int32

        public var xCreateTokenizer: ((UnsafeMutablePointer<fts5_api>?, UnsafePointer<CChar>?, UnsafeMutableRawPointer?, UnsafeMutablePointer<fts5_tokenizer>?, ((UnsafeMutableRawPointer?) -> Void)?) -> Int32)!

        public var xFindTokenizer: ((UnsafeMutablePointer<fts5_api>?, UnsafePointer<CChar>?, UnsafeMutablePointer<UnsafeMutableRawPointer?>?, UnsafeMutablePointer<fts5_tokenizer>?) -> Int32)!

        public var xCreateFunction: ((UnsafeMutablePointer<fts5_api>?, UnsafePointer<CChar>?, UnsafeMutableRawPointer?, fts5_extension_function?, ((UnsafeMutableRawPointer?) -> Void)?) -> Int32)!
    }

}
#endif


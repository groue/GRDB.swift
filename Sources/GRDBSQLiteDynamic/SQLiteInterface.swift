
/// A type that has an associated `SQLI` implementation for all the `sqlite3_` functions and variables.
public protocol SQLiteAPI {
    associatedtype SQLI: SQLiteInterface
}

public protocol SQLiteInterface {
    static var SQLITE_VERSION: String { get }
    static var SQLITE_VERSION_NUMBER: Int32 { get }
    static var SQLITE_SOURCE_ID: String { get }
    //var sqlite3_version: <<error type>>
    static func sqlite3_libversion() -> UnsafePointer<CChar>!

    static func sqlite3_sourceid() -> UnsafePointer<CChar>!
    static func sqlite3_libversion_number() -> Int32

    static func sqlite3_compileoption_used(_ zOptName: UnsafePointer<CChar>!) -> Int32

    static func sqlite3_compileoption_get(_ N: Int32) -> UnsafePointer<CChar>!
    static func sqlite3_threadsafe() -> Int32
    typealias sqlite_int64 = Int64
    typealias sqlite_uint64 = UInt64
    typealias sqlite3_int64 = sqlite_int64
    typealias sqlite3_uint64 = sqlite_uint64
    static func sqlite3_close(_: OpaquePointer!) -> Int32

    static func sqlite3_close_v2(_: OpaquePointer!) -> Int32
    typealias sqlite3_callback = @convention(c) (UnsafeMutableRawPointer?, Int32, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32
    static func sqlite3_exec(_: OpaquePointer!, _ sql: UnsafePointer<CChar>!, _ callback: (@convention(c) (UnsafeMutableRawPointer?, Int32, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32)!, _: UnsafeMutableRawPointer!, _ errmsg: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>!) -> Int32
//    static var SQLITE_OK: Int32 { get }
//    static var SQLITE_ERROR: Int32 { get }
    static var SQLITE_INTERNAL: Int32 { get }
    static var SQLITE_PERM: Int32 { get }
    static var SQLITE_ABORT: Int32 { get }
    static var SQLITE_BUSY: Int32 { get }
    static var SQLITE_LOCKED: Int32 { get }
    static var SQLITE_NOMEM: Int32 { get }
    static var SQLITE_READONLY: Int32 { get }
    static var SQLITE_INTERRUPT: Int32 { get }
    static var SQLITE_IOERR: Int32 { get }
    static var SQLITE_CORRUPT: Int32 { get }
    static var SQLITE_NOTFOUND: Int32 { get }
    static var SQLITE_FULL: Int32 { get }
    static var SQLITE_CANTOPEN: Int32 { get }
    static var SQLITE_PROTOCOL: Int32 { get }
    static var SQLITE_EMPTY: Int32 { get }
    static var SQLITE_SCHEMA: Int32 { get }
    static var SQLITE_TOOBIG: Int32 { get }
    static var SQLITE_CONSTRAINT: Int32 { get }
    static var SQLITE_MISMATCH: Int32 { get }
    static var SQLITE_MISUSE: Int32 { get }
    static var SQLITE_NOLFS: Int32 { get }
    static var SQLITE_AUTH: Int32 { get }
    static var SQLITE_FORMAT: Int32 { get }
    static var SQLITE_RANGE: Int32 { get }
    static var SQLITE_NOTADB: Int32 { get }
    static var SQLITE_NOTICE: Int32 { get }
    static var SQLITE_WARNING: Int32 { get }
    static var SQLITE_ROW: Int32 { get }
    static var SQLITE_DONE: Int32 { get }
    static var SQLITE_OPEN_READONLY: Int32 { get }
    static var SQLITE_OPEN_READWRITE: Int32 { get }
    static var SQLITE_OPEN_CREATE: Int32 { get }
    static var SQLITE_OPEN_DELETEONCLOSE: Int32 { get }
    static var SQLITE_OPEN_EXCLUSIVE: Int32 { get }
    static var SQLITE_OPEN_AUTOPROXY: Int32 { get }
    static var SQLITE_OPEN_URI: Int32 { get }
    static var SQLITE_OPEN_MEMORY: Int32 { get }
    static var SQLITE_OPEN_MAIN_DB: Int32 { get }
    static var SQLITE_OPEN_TEMP_DB: Int32 { get }
    static var SQLITE_OPEN_TRANSIENT_DB: Int32 { get }
    static var SQLITE_OPEN_MAIN_JOURNAL: Int32 { get }
    static var SQLITE_OPEN_TEMP_JOURNAL: Int32 { get }
    static var SQLITE_OPEN_SUBJOURNAL: Int32 { get }
    static var SQLITE_OPEN_SUPER_JOURNAL: Int32 { get }
    static var SQLITE_OPEN_NOMUTEX: Int32 { get }
    static var SQLITE_OPEN_FULLMUTEX: Int32 { get }
    static var SQLITE_OPEN_SHAREDCACHE: Int32 { get }
    static var SQLITE_OPEN_PRIVATECACHE: Int32 { get }
    static var SQLITE_OPEN_WAL: Int32 { get }
    static var SQLITE_OPEN_FILEPROTECTION_COMPLETE: Int32 { get }
    static var SQLITE_OPEN_FILEPROTECTION_COMPLETEUNLESSOPEN: Int32 { get }
    static var SQLITE_OPEN_FILEPROTECTION_COMPLETEUNTILFIRSTUSERAUTHENTICATION: Int32 { get }
    static var SQLITE_OPEN_FILEPROTECTION_NONE: Int32 { get }
    static var SQLITE_OPEN_FILEPROTECTION_MASK: Int32 { get }
    static var SQLITE_OPEN_NOFOLLOW: Int32 { get }
    static var SQLITE_OPEN_EXRESCODE: Int32 { get }
    static var SQLITE_OPEN_MASTER_JOURNAL: Int32 { get }
    static var SQLITE_IOCAP_ATOMIC: Int32 { get }
    static var SQLITE_IOCAP_ATOMIC512: Int32 { get }
    static var SQLITE_IOCAP_ATOMIC1K: Int32 { get }
    static var SQLITE_IOCAP_ATOMIC2K: Int32 { get }
    static var SQLITE_IOCAP_ATOMIC4K: Int32 { get }
    static var SQLITE_IOCAP_ATOMIC8K: Int32 { get }
    static var SQLITE_IOCAP_ATOMIC16K: Int32 { get }
    static var SQLITE_IOCAP_ATOMIC32K: Int32 { get }
    static var SQLITE_IOCAP_ATOMIC64K: Int32 { get }
    static var SQLITE_IOCAP_SAFE_APPEND: Int32 { get }
    static var SQLITE_IOCAP_SEQUENTIAL: Int32 { get }
    static var SQLITE_IOCAP_UNDELETABLE_WHEN_OPEN: Int32 { get }
    static var SQLITE_IOCAP_POWERSAFE_OVERWRITE: Int32 { get }
    static var SQLITE_IOCAP_IMMUTABLE: Int32 { get }
    static var SQLITE_IOCAP_BATCH_ATOMIC: Int32 { get }
    static var SQLITE_LOCK_NONE: Int32 { get }
    static var SQLITE_LOCK_SHARED: Int32 { get }
    static var SQLITE_LOCK_RESERVED: Int32 { get }
    static var SQLITE_LOCK_PENDING: Int32 { get }
    static var SQLITE_LOCK_EXCLUSIVE: Int32 { get }
    static var SQLITE_SYNC_NORMAL: Int32 { get }
    static var SQLITE_SYNC_FULL: Int32 { get }
    static var SQLITE_SYNC_DATAONLY: Int32 { get }
//    struct sqlite3_file {
//
//        public init()
//
//        public init(pMethods: UnsafePointer<sqlite3_io_methods>!)
//
//        public var pMethods: UnsafePointer<sqlite3_io_methods>!
//    }
//    struct sqlite3_io_methods {
//
//        public init()
//
//        public init(iVersion: Int32, xClose: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?) -> Int32)!, xRead: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, UnsafeMutableRawPointer?, Int32, sqlite3_int64) -> Int32)!, xWrite: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, UnsafeRawPointer?, Int32, sqlite3_int64) -> Int32)!, xTruncate: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, sqlite3_int64) -> Int32)!, xSync: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, Int32) -> Int32)!, xFileSize: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, UnsafeMutablePointer<sqlite3_int64>?) -> Int32)!, xLock: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, Int32) -> Int32)!, xUnlock: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, Int32) -> Int32)!, xCheckReservedLock: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, UnsafeMutablePointer<Int32>?) -> Int32)!, xFileControl: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, Int32, UnsafeMutableRawPointer?) -> Int32)!, xSectorSize: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?) -> Int32)!, xDeviceCharacteristics: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?) -> Int32)!, xShmMap: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, Int32, Int32, Int32, UnsafeMutablePointer<UnsafeMutableRawPointer?>?) -> Int32)!, xShmLock: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, Int32, Int32, Int32) -> Int32)!, xShmBarrier: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?) -> Void)!, xShmUnmap: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, Int32) -> Int32)!, xFetch: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, sqlite3_int64, Int32, UnsafeMutablePointer<UnsafeMutableRawPointer?>?) -> Int32)!, xUnfetch: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, sqlite3_int64, UnsafeMutableRawPointer?) -> Int32)!)
//
//        public var iVersion: Int32
//
//        public var xClose: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?) -> Int32)!
//
//        public var xRead: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, UnsafeMutableRawPointer?, Int32, sqlite3_int64) -> Int32)!
//
//        public var xWrite: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, UnsafeRawPointer?, Int32, sqlite3_int64) -> Int32)!
//
//        public var xTruncate: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, sqlite3_int64) -> Int32)!
//
//        public var xSync: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, Int32) -> Int32)!
//
//        public var xFileSize: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, UnsafeMutablePointer<sqlite3_int64>?) -> Int32)!
//
//        public var xLock: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, Int32) -> Int32)!
//
//        public var xUnlock: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, Int32) -> Int32)!
//
//        public var xCheckReservedLock: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, UnsafeMutablePointer<Int32>?) -> Int32)!
//
//        public var xFileControl: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, Int32, UnsafeMutableRawPointer?) -> Int32)!
//
//        public var xSectorSize: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?) -> Int32)!
//
//        public var xDeviceCharacteristics: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?) -> Int32)!
//
//        public var xShmMap: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, Int32, Int32, Int32, UnsafeMutablePointer<UnsafeMutableRawPointer?>?) -> Int32)!
//
//        public var xShmLock: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, Int32, Int32, Int32) -> Int32)!
//
//        public var xShmBarrier: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?) -> Void)!
//
//        public var xShmUnmap: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, Int32) -> Int32)!
//
//        public var xFetch: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, sqlite3_int64, Int32, UnsafeMutablePointer<UnsafeMutableRawPointer?>?) -> Int32)!
//
//        public var xUnfetch: (@convention(c) (UnsafeMutablePointer<sqlite3_file>?, sqlite3_int64, UnsafeMutableRawPointer?) -> Int32)!
//    }
    static var SQLITE_FCNTL_LOCKSTATE: Int32 { get }
    static var SQLITE_FCNTL_GET_LOCKPROXYFILE: Int32 { get }
    static var SQLITE_FCNTL_SET_LOCKPROXYFILE: Int32 { get }
    static var SQLITE_FCNTL_LAST_ERRNO: Int32 { get }
    static var SQLITE_FCNTL_SIZE_HINT: Int32 { get }
    static var SQLITE_FCNTL_CHUNK_SIZE: Int32 { get }
    static var SQLITE_FCNTL_FILE_POINTER: Int32 { get }
    static var SQLITE_FCNTL_SYNC_OMITTED: Int32 { get }
    static var SQLITE_FCNTL_WIN32_AV_RETRY: Int32 { get }
    static var SQLITE_FCNTL_PERSIST_WAL: Int32 { get }
    static var SQLITE_FCNTL_OVERWRITE: Int32 { get }
    static var SQLITE_FCNTL_VFSNAME: Int32 { get }
    static var SQLITE_FCNTL_POWERSAFE_OVERWRITE: Int32 { get }
    static var SQLITE_FCNTL_PRAGMA: Int32 { get }
    static var SQLITE_FCNTL_BUSYHANDLER: Int32 { get }
    static var SQLITE_FCNTL_TEMPFILENAME: Int32 { get }
    static var SQLITE_FCNTL_MMAP_SIZE: Int32 { get }
    static var SQLITE_FCNTL_TRACE: Int32 { get }
    static var SQLITE_FCNTL_HAS_MOVED: Int32 { get }
    static var SQLITE_FCNTL_SYNC: Int32 { get }
    static var SQLITE_FCNTL_COMMIT_PHASETWO: Int32 { get }
    static var SQLITE_FCNTL_WIN32_SET_HANDLE: Int32 { get }
    static var SQLITE_FCNTL_WAL_BLOCK: Int32 { get }
    static var SQLITE_FCNTL_ZIPVFS: Int32 { get }
    static var SQLITE_FCNTL_RBU: Int32 { get }
    static var SQLITE_FCNTL_VFS_POINTER: Int32 { get }
    static var SQLITE_FCNTL_JOURNAL_POINTER: Int32 { get }
    static var SQLITE_FCNTL_WIN32_GET_HANDLE: Int32 { get }
    static var SQLITE_FCNTL_PDB: Int32 { get }
    static var SQLITE_FCNTL_BEGIN_ATOMIC_WRITE: Int32 { get }
    static var SQLITE_FCNTL_COMMIT_ATOMIC_WRITE: Int32 { get }
    static var SQLITE_FCNTL_ROLLBACK_ATOMIC_WRITE: Int32 { get }
    static var SQLITE_FCNTL_LOCK_TIMEOUT: Int32 { get }
    static var SQLITE_FCNTL_DATA_VERSION: Int32 { get }
    static var SQLITE_FCNTL_SIZE_LIMIT: Int32 { get }
    static var SQLITE_FCNTL_CKPT_DONE: Int32 { get }
    static var SQLITE_FCNTL_RESERVE_BYTES: Int32 { get }
    static var SQLITE_FCNTL_CKPT_START: Int32 { get }
    static var SQLITE_FCNTL_EXTERNAL_READER: Int32 { get }
    static var SQLITE_FCNTL_CKSM_FILE: Int32 { get }
    static var SQLITE_FCNTL_RESET_CACHE: Int32 { get }
    static var SQLITE_GET_LOCKPROXYFILE: Int32 { get }
    static var SQLITE_SET_LOCKPROXYFILE: Int32 { get }
    static var SQLITE_LAST_ERRNO: Int32 { get }
    typealias sqlite3_filename = UnsafePointer<CChar>
    typealias sqlite3_syscall_ptr = @convention(c) () -> Void
//    struct sqlite3_vfs {
//
//        public init()
//
//        public init(iVersion: Int32, szOsFile: Int32, mxPathname: Int32, pNext: UnsafeMutablePointer<sqlite3_vfs>!, zName: UnsafePointer<CChar>!, pAppData: UnsafeMutableRawPointer!, xOpen: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, sqlite3_filename?, UnsafeMutablePointer<sqlite3_file>?, Int32, UnsafeMutablePointer<Int32>?) -> Int32)!, xDelete: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, UnsafePointer<CChar>?, Int32) -> Int32)!, xAccess: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, UnsafePointer<CChar>?, Int32, UnsafeMutablePointer<Int32>?) -> Int32)!, xFullPathname: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, UnsafePointer<CChar>?, Int32, UnsafeMutablePointer<CChar>?) -> Int32)!, xDlOpen: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, UnsafePointer<CChar>?) -> UnsafeMutableRawPointer?)!, xDlError: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, Int32, UnsafeMutablePointer<CChar>?) -> Void)!, xDlSym: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, UnsafeMutableRawPointer?, UnsafePointer<CChar>?) -> (@convention(c) () -> Void)?)!, xDlClose: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, UnsafeMutableRawPointer?) -> Void)!, xRandomness: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, Int32, UnsafeMutablePointer<CChar>?) -> Int32)!, xSleep: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, Int32) -> Int32)!, xCurrentTime: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, UnsafeMutablePointer<Double>?) -> Int32)!, xGetLastError: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, Int32, UnsafeMutablePointer<CChar>?) -> Int32)!, xCurrentTimeInt64: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, UnsafeMutablePointer<sqlite3_int64>?) -> Int32)!, xSetSystemCall: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, UnsafePointer<CChar>?, sqlite3_syscall_ptr?) -> Int32)!, xGetSystemCall: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, UnsafePointer<CChar>?) -> sqlite3_syscall_ptr?)!, xNextSystemCall: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, UnsafePointer<CChar>?) -> UnsafePointer<CChar>?)!)
//
//        public var iVersion: Int32
//
//        public var szOsFile: Int32
//
//        public var mxPathname: Int32
//
//        public var pNext: UnsafeMutablePointer<sqlite3_vfs>!
//
//        public var zName: UnsafePointer<CChar>!
//
//        public var pAppData: UnsafeMutableRawPointer!
//
//        public var xOpen: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, sqlite3_filename?, UnsafeMutablePointer<sqlite3_file>?, Int32, UnsafeMutablePointer<Int32>?) -> Int32)!
//
//        public var xDelete: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, UnsafePointer<CChar>?, Int32) -> Int32)!
//
//        public var xAccess: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, UnsafePointer<CChar>?, Int32, UnsafeMutablePointer<Int32>?) -> Int32)!
//
//        public var xFullPathname: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, UnsafePointer<CChar>?, Int32, UnsafeMutablePointer<CChar>?) -> Int32)!
//
//        public var xDlOpen: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, UnsafePointer<CChar>?) -> UnsafeMutableRawPointer?)!
//
//        public var xDlError: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, Int32, UnsafeMutablePointer<CChar>?) -> Void)!
//
//        public var xDlSym: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, UnsafeMutableRawPointer?, UnsafePointer<CChar>?) -> (@convention(c) () -> Void)?)!
//
//        public var xDlClose: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, UnsafeMutableRawPointer?) -> Void)!
//
//        public var xRandomness: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, Int32, UnsafeMutablePointer<CChar>?) -> Int32)!
//
//        public var xSleep: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, Int32) -> Int32)!
//
//        public var xCurrentTime: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, UnsafeMutablePointer<Double>?) -> Int32)!
//
//        public var xGetLastError: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, Int32, UnsafeMutablePointer<CChar>?) -> Int32)!
//
//        public var xCurrentTimeInt64: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, UnsafeMutablePointer<sqlite3_int64>?) -> Int32)!
//
//        public var xSetSystemCall: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, UnsafePointer<CChar>?, sqlite3_syscall_ptr?) -> Int32)!
//
//        public var xGetSystemCall: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, UnsafePointer<CChar>?) -> sqlite3_syscall_ptr?)!
//
//        public var xNextSystemCall: (@convention(c) (UnsafeMutablePointer<sqlite3_vfs>?, UnsafePointer<CChar>?) -> UnsafePointer<CChar>?)!
//    }
    static var SQLITE_ACCESS_EXISTS: Int32 { get }
    static var SQLITE_ACCESS_READWRITE: Int32 { get }
    static var SQLITE_ACCESS_READ: Int32 { get }
    static var SQLITE_SHM_UNLOCK: Int32 { get }
    static var SQLITE_SHM_LOCK: Int32 { get }
    static var SQLITE_SHM_SHARED: Int32 { get }
    static var SQLITE_SHM_EXCLUSIVE: Int32 { get }
    static var SQLITE_SHM_NLOCK: Int32 { get }
    static func sqlite3_initialize() -> Int32
    static func sqlite3_shutdown() -> Int32
    static func sqlite3_os_init() -> Int32
    static func sqlite3_os_end() -> Int32
//    struct sqlite3_mem_methods {
//
//        public init()
//
//        public init(xMalloc: (@convention(c) (Int32) -> UnsafeMutableRawPointer?)!, xFree: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!, xRealloc: (@convention(c) (UnsafeMutableRawPointer?, Int32) -> UnsafeMutableRawPointer?)!, xSize: (@convention(c) (UnsafeMutableRawPointer?) -> Int32)!, xRoundup: (@convention(c) (Int32) -> Int32)!, xInit: (@convention(c) (UnsafeMutableRawPointer?) -> Int32)!, xShutdown: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!, pAppData: UnsafeMutableRawPointer!)
//
//        public var xMalloc: (@convention(c) (Int32) -> UnsafeMutableRawPointer?)!
//
//        public var xFree: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!
//
//        public var xRealloc: (@convention(c) (UnsafeMutableRawPointer?, Int32) -> UnsafeMutableRawPointer?)!
//
//        public var xSize: (@convention(c) (UnsafeMutableRawPointer?) -> Int32)!
//
//        public var xRoundup: (@convention(c) (Int32) -> Int32)!
//
//        public var xInit: (@convention(c) (UnsafeMutableRawPointer?) -> Int32)!
//
//        public var xShutdown: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!
//
//        public var pAppData: UnsafeMutableRawPointer!
//    }
    static var SQLITE_CONFIG_SINGLETHREAD: Int32 { get }
    static var SQLITE_CONFIG_MULTITHREAD: Int32 { get }
    static var SQLITE_CONFIG_SERIALIZED: Int32 { get }
    static var SQLITE_CONFIG_MALLOC: Int32 { get }
    static var SQLITE_CONFIG_GETMALLOC: Int32 { get }
    static var SQLITE_CONFIG_SCRATCH: Int32 { get }
    static var SQLITE_CONFIG_PAGECACHE: Int32 { get }
    static var SQLITE_CONFIG_HEAP: Int32 { get }
    static var SQLITE_CONFIG_MEMSTATUS: Int32 { get }
    static var SQLITE_CONFIG_MUTEX: Int32 { get }
    static var SQLITE_CONFIG_GETMUTEX: Int32 { get }
    static var SQLITE_CONFIG_LOOKASIDE: Int32 { get }
    static var SQLITE_CONFIG_PCACHE: Int32 { get }
    static var SQLITE_CONFIG_GETPCACHE: Int32 { get }
    static var SQLITE_CONFIG_LOG: Int32 { get }
    static var SQLITE_CONFIG_URI: Int32 { get }
    static var SQLITE_CONFIG_PCACHE2: Int32 { get }
    static var SQLITE_CONFIG_GETPCACHE2: Int32 { get }
    static var SQLITE_CONFIG_COVERING_INDEX_SCAN: Int32 { get }
    static var SQLITE_CONFIG_SQLLOG: Int32 { get }
    static var SQLITE_CONFIG_MMAP_SIZE: Int32 { get }
    static var SQLITE_CONFIG_WIN32_HEAPSIZE: Int32 { get }
    static var SQLITE_CONFIG_PCACHE_HDRSZ: Int32 { get }
    static var SQLITE_CONFIG_PMASZ: Int32 { get }
    static var SQLITE_CONFIG_STMTJRNL_SPILL: Int32 { get }
    static var SQLITE_CONFIG_SMALL_MALLOC: Int32 { get }
    static var SQLITE_CONFIG_SORTERREF_SIZE: Int32 { get }
    static var SQLITE_CONFIG_MEMDB_MAXSIZE: Int32 { get }
    static var SQLITE_DBCONFIG_MAINDBNAME: Int32 { get }
    static var SQLITE_DBCONFIG_LOOKASIDE: Int32 { get }
    static var SQLITE_DBCONFIG_ENABLE_FKEY: Int32 { get }
    static var SQLITE_DBCONFIG_ENABLE_TRIGGER: Int32 { get }
    static var SQLITE_DBCONFIG_ENABLE_FTS3_TOKENIZER: Int32 { get }
    static var SQLITE_DBCONFIG_ENABLE_LOAD_EXTENSION: Int32 { get }
    static var SQLITE_DBCONFIG_NO_CKPT_ON_CLOSE: Int32 { get }
    static var SQLITE_DBCONFIG_ENABLE_QPSG: Int32 { get }
    static var SQLITE_DBCONFIG_TRIGGER_EQP: Int32 { get }
    static var SQLITE_DBCONFIG_RESET_DATABASE: Int32 { get }
    static var SQLITE_DBCONFIG_DEFENSIVE: Int32 { get }
    static var SQLITE_DBCONFIG_WRITABLE_SCHEMA: Int32 { get }
    static var SQLITE_DBCONFIG_LEGACY_ALTER_TABLE: Int32 { get }
    static var SQLITE_DBCONFIG_DQS_DML: Int32 { get }
    static var SQLITE_DBCONFIG_DQS_DDL: Int32 { get }
    static var SQLITE_DBCONFIG_ENABLE_VIEW: Int32 { get }
    static var SQLITE_DBCONFIG_LEGACY_FILE_FORMAT: Int32 { get }
    static var SQLITE_DBCONFIG_TRUSTED_SCHEMA: Int32 { get }
    static var SQLITE_DBCONFIG_STMT_SCANSTATUS: Int32 { get }
    static var SQLITE_DBCONFIG_REVERSE_SCANORDER: Int32 { get }
    static var SQLITE_DBCONFIG_MAX: Int32 { get }
    static func sqlite3_extended_result_codes(_: OpaquePointer!, _ onoff: Int32) -> Int32
    static func sqlite3_last_insert_rowid(_: OpaquePointer!) -> sqlite3_int64
    static func sqlite3_set_last_insert_rowid(_: OpaquePointer!, _: sqlite3_int64)
    static func sqlite3_changes(_: OpaquePointer!) -> Int32

    @available(macOS 12.3, *) static func sqlite3_changes64(_: OpaquePointer!) -> sqlite3_int64
    static func sqlite3_total_changes(_: OpaquePointer!) -> Int32

    @available(macOS 12.3, *) static func sqlite3_total_changes64(_: OpaquePointer!) -> sqlite3_int64
    static func sqlite3_interrupt(_: OpaquePointer!)

    @available(macOS 14.2, *) static func sqlite3_is_interrupted(_: OpaquePointer!) -> Int32
    static func sqlite3_complete(_ sql: UnsafePointer<CChar>!) -> Int32
    static func sqlite3_complete16(_ sql: UnsafeRawPointer!) -> Int32
    static func sqlite3_busy_handler(_: OpaquePointer!, _: (@convention(c) (UnsafeMutableRawPointer?, Int32) -> Int32)!, _: UnsafeMutableRawPointer!) -> Int32
    static func sqlite3_busy_timeout(_: OpaquePointer!, _ ms: Int32) -> Int32
    static func sqlite3_get_table(_ db: OpaquePointer!, _ zSql: UnsafePointer<CChar>!, _ pazResult: UnsafeMutablePointer<UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?>!, _ pnRow: UnsafeMutablePointer<Int32>!, _ pnColumn: UnsafeMutablePointer<Int32>!, _ pzErrmsg: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>!) -> Int32
    static func sqlite3_free_table(_ result: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>!)
    static func sqlite3_vmprintf(_: UnsafePointer<CChar>!, _: CVaListPointer) -> UnsafeMutablePointer<CChar>!

    static func sqlite3_vsnprintf(_: Int32, _: UnsafeMutablePointer<CChar>!, _: UnsafePointer<CChar>!, _: CVaListPointer) -> UnsafeMutablePointer<CChar>!
    static func sqlite3_malloc(_: Int32) -> UnsafeMutableRawPointer!

    static func sqlite3_malloc64(_: sqlite3_uint64) -> UnsafeMutableRawPointer!
    static func sqlite3_realloc(_: UnsafeMutableRawPointer!, _: Int32) -> UnsafeMutableRawPointer!

    static func sqlite3_realloc64(_: UnsafeMutableRawPointer!, _: sqlite3_uint64) -> UnsafeMutableRawPointer!
    static func sqlite3_free(_: UnsafeMutableRawPointer!)

    static func sqlite3_msize(_: UnsafeMutableRawPointer!) -> sqlite3_uint64
    static func sqlite3_memory_used() -> sqlite3_int64
    static func sqlite3_memory_highwater(_ resetFlag: Int32) -> sqlite3_int64
    static func sqlite3_randomness(_ N: Int32, _ P: UnsafeMutableRawPointer!)
    static func sqlite3_set_authorizer(_: OpaquePointer!, _ xAuth: (@convention(c) (UnsafeMutableRawPointer?, Int32, UnsafePointer<CChar>?, UnsafePointer<CChar>?, UnsafePointer<CChar>?, UnsafePointer<CChar>?) -> Int32)!, _ pUserData: UnsafeMutableRawPointer!) -> Int32
    static var SQLITE_DENY: Int32 { get }
    static var SQLITE_IGNORE: Int32 { get }
    static var SQLITE_CREATE_INDEX: Int32 { get }
    static var SQLITE_CREATE_TABLE: Int32 { get }
    static var SQLITE_CREATE_TEMP_INDEX: Int32 { get }
    static var SQLITE_CREATE_TEMP_TABLE: Int32 { get }
    static var SQLITE_CREATE_TEMP_TRIGGER: Int32 { get }
    static var SQLITE_CREATE_TEMP_VIEW: Int32 { get }
    static var SQLITE_CREATE_TRIGGER: Int32 { get }
    static var SQLITE_CREATE_VIEW: Int32 { get }
    static var SQLITE_DELETE: Int32 { get }
    static var SQLITE_DROP_INDEX: Int32 { get }
    static var SQLITE_DROP_TABLE: Int32 { get }
    static var SQLITE_DROP_TEMP_INDEX: Int32 { get }
    static var SQLITE_DROP_TEMP_TABLE: Int32 { get }
    static var SQLITE_DROP_TEMP_TRIGGER: Int32 { get }
    static var SQLITE_DROP_TEMP_VIEW: Int32 { get }
    static var SQLITE_DROP_TRIGGER: Int32 { get }
    static var SQLITE_DROP_VIEW: Int32 { get }
    static var SQLITE_INSERT: Int32 { get }
    static var SQLITE_PRAGMA: Int32 { get }
    static var SQLITE_READ: Int32 { get }
    static var SQLITE_SELECT: Int32 { get }
    static var SQLITE_TRANSACTION: Int32 { get }
    static var SQLITE_UPDATE: Int32 { get }
    static var SQLITE_ATTACH: Int32 { get }
    static var SQLITE_DETACH: Int32 { get }
    static var SQLITE_ALTER_TABLE: Int32 { get }
    static var SQLITE_REINDEX: Int32 { get }
    static var SQLITE_ANALYZE: Int32 { get }
    static var SQLITE_CREATE_VTABLE: Int32 { get }
    static var SQLITE_DROP_VTABLE: Int32 { get }
    static var SQLITE_FUNCTION: Int32 { get }
    static var SQLITE_SAVEPOINT: Int32 { get }
    static var SQLITE_COPY: Int32 { get }
    static var SQLITE_RECURSIVE: Int32 { get }

    static func sqlite3_trace(_: OpaquePointer!, _ xTrace: (@convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?) -> Void)!, _: UnsafeMutableRawPointer!) -> UnsafeMutableRawPointer!

    static func sqlite3_profile(_: OpaquePointer!, _ xProfile: (@convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?, sqlite3_uint64) -> Void)!, _: UnsafeMutableRawPointer!) -> UnsafeMutableRawPointer!
    static var SQLITE_TRACE_STMT: Int32 { get }
    static var SQLITE_TRACE_PROFILE: Int32 { get }
    static var SQLITE_TRACE_ROW: Int32 { get }
    static var SQLITE_TRACE_CLOSE: Int32 { get }

    static func sqlite3_trace_v2(_: OpaquePointer!, _ uMask: UInt32, _ xCallback: (@convention(c) (UInt32, UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Int32)!, _ pCtx: UnsafeMutableRawPointer!) -> Int32
    static func sqlite3_progress_handler(_: OpaquePointer!, _: Int32, _: (@convention(c) (UnsafeMutableRawPointer?) -> Int32)!, _: UnsafeMutableRawPointer!)
    static func sqlite3_open(_ filename: UnsafePointer<CChar>!, _ ppDb: UnsafeMutablePointer<OpaquePointer?>!) -> Int32
    static func sqlite3_open16(_ filename: UnsafeRawPointer!, _ ppDb: UnsafeMutablePointer<OpaquePointer?>!) -> Int32
    static func sqlite3_open_v2(_ filename: UnsafePointer<CChar>!, _ ppDb: UnsafeMutablePointer<OpaquePointer?>!, _ flags: Int32, _ zVfs: UnsafePointer<CChar>!) -> Int32

    static func sqlite3_uri_parameter(_ z: sqlite3_filename!, _ zParam: UnsafePointer<CChar>!) -> UnsafePointer<CChar>!

    static func sqlite3_uri_boolean(_ z: sqlite3_filename!, _ zParam: UnsafePointer<CChar>!, _ bDefault: Int32) -> Int32

    static func sqlite3_uri_int64(_: sqlite3_filename!, _: UnsafePointer<CChar>!, _: sqlite3_int64) -> sqlite3_int64

    @available(macOS 11, *) static func sqlite3_uri_key(_ z: sqlite3_filename!, _ N: Int32) -> UnsafePointer<CChar>!

    @available(macOS 11, *) static func sqlite3_filename_database(_: sqlite3_filename!) -> UnsafePointer<CChar>!

    @available(macOS 11, *) static func sqlite3_filename_journal(_: sqlite3_filename!) -> UnsafePointer<CChar>!

    @available(macOS 11, *) static func sqlite3_filename_wal(_: sqlite3_filename!) -> UnsafePointer<CChar>!

//    func sqlite3_database_file_object(_: UnsafePointer<CChar>!) -> UnsafeMutablePointer<sqlite3_file>!

    @available(macOS 11, *) static func sqlite3_create_filename(_ zDatabase: UnsafePointer<CChar>!, _ zJournal: UnsafePointer<CChar>!, _ zWal: UnsafePointer<CChar>!, _ nParam: Int32, _ azParam: UnsafeMutablePointer<UnsafePointer<CChar>?>!) -> sqlite3_filename!

    @available(macOS 11, *) static func sqlite3_free_filename(_: sqlite3_filename!)
    static func sqlite3_errcode(_ db: OpaquePointer!) -> Int32
    static func sqlite3_extended_errcode(_ db: OpaquePointer!) -> Int32
    static func sqlite3_errmsg(_: OpaquePointer!) -> UnsafePointer<CChar>!
    static func sqlite3_errmsg16(_: OpaquePointer!) -> UnsafeRawPointer!

    static func sqlite3_errstr(_: Int32) -> UnsafePointer<CChar>!

    @available(macOS 13, *) static func sqlite3_error_offset(_ db: OpaquePointer!) -> Int32
    static func sqlite3_limit(_: OpaquePointer!, _ id: Int32, _ newVal: Int32) -> Int32
    static var SQLITE_LIMIT_LENGTH: Int32 { get }
    static var SQLITE_LIMIT_SQL_LENGTH: Int32 { get }
    static var SQLITE_LIMIT_COLUMN: Int32 { get }
    static var SQLITE_LIMIT_EXPR_DEPTH: Int32 { get }
    static var SQLITE_LIMIT_COMPOUND_SELECT: Int32 { get }
    static var SQLITE_LIMIT_VDBE_OP: Int32 { get }
    static var SQLITE_LIMIT_FUNCTION_ARG: Int32 { get }
    static var SQLITE_LIMIT_ATTACHED: Int32 { get }
    static var SQLITE_LIMIT_LIKE_PATTERN_LENGTH: Int32 { get }
    static var SQLITE_LIMIT_VARIABLE_NUMBER: Int32 { get }
    static var SQLITE_LIMIT_TRIGGER_DEPTH: Int32 { get }
    static var SQLITE_LIMIT_WORKER_THREADS: Int32 { get }
    static var SQLITE_PREPARE_PERSISTENT: Int32 { get }
    static var SQLITE_PREPARE_NORMALIZE: Int32 { get }
    static var SQLITE_PREPARE_NO_VTAB: Int32 { get }
    static func sqlite3_prepare(_ db: OpaquePointer!, _ zSql: UnsafePointer<CChar>!, _ nByte: Int32, _ ppStmt: UnsafeMutablePointer<OpaquePointer?>!, _ pzTail: UnsafeMutablePointer<UnsafePointer<CChar>?>!) -> Int32
    static func sqlite3_prepare_v2(_ db: OpaquePointer!, _ zSql: UnsafePointer<CChar>!, _ nByte: Int32, _ ppStmt: UnsafeMutablePointer<OpaquePointer?>!, _ pzTail: UnsafeMutablePointer<UnsafePointer<CChar>?>!) -> Int32

    static func sqlite3_prepare_v3(_ db: OpaquePointer!, _ zSql: UnsafePointer<CChar>!, _ nByte: Int32, _ prepFlags: UInt32, _ ppStmt: UnsafeMutablePointer<OpaquePointer?>!, _ pzTail: UnsafeMutablePointer<UnsafePointer<CChar>?>!) -> Int32
    static func sqlite3_prepare16(_ db: OpaquePointer!, _ zSql: UnsafeRawPointer!, _ nByte: Int32, _ ppStmt: UnsafeMutablePointer<OpaquePointer?>!, _ pzTail: UnsafeMutablePointer<UnsafeRawPointer?>!) -> Int32
    static func sqlite3_prepare16_v2(_ db: OpaquePointer!, _ zSql: UnsafeRawPointer!, _ nByte: Int32, _ ppStmt: UnsafeMutablePointer<OpaquePointer?>!, _ pzTail: UnsafeMutablePointer<UnsafeRawPointer?>!) -> Int32

    static func sqlite3_prepare16_v3(_ db: OpaquePointer!, _ zSql: UnsafeRawPointer!, _ nByte: Int32, _ prepFlags: UInt32, _ ppStmt: UnsafeMutablePointer<OpaquePointer?>!, _ pzTail: UnsafeMutablePointer<UnsafeRawPointer?>!) -> Int32
    static func sqlite3_sql(_ pStmt: OpaquePointer!) -> UnsafePointer<CChar>!

//    static func sqlite3_expanded_sql(_ pStmt: OpaquePointer!) -> UnsafeMutablePointer<CChar>!

    @available(macOS 12, *) static func sqlite3_normalized_sql(_ pStmt: OpaquePointer!) -> UnsafePointer<CChar>!

    static func sqlite3_stmt_readonly(_ pStmt: OpaquePointer!) -> Int32

    static func sqlite3_stmt_isexplain(_ pStmt: OpaquePointer!) -> Int32

    @available(macOS 14.2, *) static func sqlite3_stmt_explain(_ pStmt: OpaquePointer!, _ eMode: Int32) -> Int32

    static func sqlite3_stmt_busy(_: OpaquePointer!) -> Int32
    static func sqlite3_bind_blob(_: OpaquePointer!, _: Int32, _: UnsafeRawPointer!, _ n: Int32, _: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!) -> Int32
    static func sqlite3_bind_blob64(_: OpaquePointer!, _: Int32, _: UnsafeRawPointer!, _: sqlite3_uint64, _: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!) -> Int32
    static func sqlite3_bind_double(_: OpaquePointer!, _: Int32, _: Double) -> Int32
    static func sqlite3_bind_int(_: OpaquePointer!, _: Int32, _: Int32) -> Int32
    static func sqlite3_bind_int64(_: OpaquePointer!, _: Int32, _: sqlite3_int64) -> Int32
    static func sqlite3_bind_null(_: OpaquePointer!, _: Int32) -> Int32
    static func sqlite3_bind_text(_: OpaquePointer!, _: Int32, _: UnsafePointer<CChar>!, _: Int32, _: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!) -> Int32
    static func sqlite3_bind_text16(_: OpaquePointer!, _: Int32, _: UnsafeRawPointer!, _: Int32, _: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!) -> Int32
    static func sqlite3_bind_text64(_: OpaquePointer!, _: Int32, _: UnsafePointer<CChar>!, _: sqlite3_uint64, _: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!, _ encoding: UInt8) -> Int32
    static func sqlite3_bind_value(_: OpaquePointer!, _: Int32, _: OpaquePointer!) -> Int32

    static func sqlite3_bind_pointer(_: OpaquePointer!, _: Int32, _: UnsafeMutableRawPointer!, _: UnsafePointer<CChar>!, _: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!) -> Int32
    static func sqlite3_bind_zeroblob(_: OpaquePointer!, _: Int32, _ n: Int32) -> Int32

    static func sqlite3_bind_zeroblob64(_: OpaquePointer!, _: Int32, _: sqlite3_uint64) -> Int32
    static func sqlite3_bind_parameter_count(_: OpaquePointer!) -> Int32
    static func sqlite3_bind_parameter_name(_: OpaquePointer!, _: Int32) -> UnsafePointer<CChar>!
    static func sqlite3_bind_parameter_index(_: OpaquePointer!, _ zName: UnsafePointer<CChar>!) -> Int32
    static func sqlite3_clear_bindings(_: OpaquePointer!) -> Int32
    static func sqlite3_column_count(_ pStmt: OpaquePointer!) -> Int32
    static func sqlite3_column_name(_: OpaquePointer!, _ N: Int32) -> UnsafePointer<CChar>!
    static func sqlite3_column_name16(_: OpaquePointer!, _ N: Int32) -> UnsafeRawPointer!
    static func sqlite3_column_database_name(_: OpaquePointer!, _: Int32) -> UnsafePointer<CChar>!
    static func sqlite3_column_database_name16(_: OpaquePointer!, _: Int32) -> UnsafeRawPointer!
    static func sqlite3_column_table_name(_: OpaquePointer!, _: Int32) -> UnsafePointer<CChar>!
    static func sqlite3_column_table_name16(_: OpaquePointer!, _: Int32) -> UnsafeRawPointer!
    static func sqlite3_column_origin_name(_: OpaquePointer!, _: Int32) -> UnsafePointer<CChar>!
    static func sqlite3_column_origin_name16(_: OpaquePointer!, _: Int32) -> UnsafeRawPointer!
    static func sqlite3_column_decltype(_: OpaquePointer!, _: Int32) -> UnsafePointer<CChar>!
    static func sqlite3_column_decltype16(_: OpaquePointer!, _: Int32) -> UnsafeRawPointer!
    static func sqlite3_step(_: OpaquePointer!) -> Int32
    static func sqlite3_data_count(_ pStmt: OpaquePointer!) -> Int32
//    static var SQLITE_INTEGER: Int32 { get }
//    static var SQLITE_FLOAT: Int32 { get }
//    static var SQLITE_BLOB: Int32 { get }
//    static var SQLITE_NULL: Int32 { get }
//    static var SQLITE_TEXT: Int32 { get }
    static var SQLITE3_TEXT: Int32 { get }
    static func sqlite3_column_blob(_: OpaquePointer!, _ iCol: Int32) -> UnsafeRawPointer!
    static func sqlite3_column_double(_: OpaquePointer!, _ iCol: Int32) -> Double
    static func sqlite3_column_int(_: OpaquePointer!, _ iCol: Int32) -> Int32
    static func sqlite3_column_int64(_: OpaquePointer!, _ iCol: Int32) -> sqlite3_int64
    static func sqlite3_column_text(_: OpaquePointer!, _ iCol: Int32) -> UnsafePointer<UInt8>!
    static func sqlite3_column_text16(_: OpaquePointer!, _ iCol: Int32) -> UnsafeRawPointer!
    static func sqlite3_column_value(_: OpaquePointer!, _ iCol: Int32) -> OpaquePointer!
    static func sqlite3_column_bytes(_: OpaquePointer!, _ iCol: Int32) -> Int32
    static func sqlite3_column_bytes16(_: OpaquePointer!, _ iCol: Int32) -> Int32
    static func sqlite3_column_type(_: OpaquePointer!, _ iCol: Int32) -> Int32
    static func sqlite3_finalize(_ pStmt: OpaquePointer!) -> Int32
    static func sqlite3_reset(_ pStmt: OpaquePointer!) -> Int32
    static func sqlite3_create_function(_ db: OpaquePointer!, _ zFunctionName: UnsafePointer<CChar>!, _ nArg: Int32, _ eTextRep: Int32, _ pApp: UnsafeMutableRawPointer!, _ xFunc: (@convention(c) (OpaquePointer?, Int32, UnsafeMutablePointer<OpaquePointer?>?) -> Void)!, _ xStep: (@convention(c) (OpaquePointer?, Int32, UnsafeMutablePointer<OpaquePointer?>?) -> Void)!, _ xFinal: (@convention(c) (OpaquePointer?) -> Void)!) -> Int32
    static func sqlite3_create_function16(_ db: OpaquePointer!, _ zFunctionName: UnsafeRawPointer!, _ nArg: Int32, _ eTextRep: Int32, _ pApp: UnsafeMutableRawPointer!, _ xFunc: (@convention(c) (OpaquePointer?, Int32, UnsafeMutablePointer<OpaquePointer?>?) -> Void)!, _ xStep: (@convention(c) (OpaquePointer?, Int32, UnsafeMutablePointer<OpaquePointer?>?) -> Void)!, _ xFinal: (@convention(c) (OpaquePointer?) -> Void)!) -> Int32

    static func sqlite3_create_function_v2(_ db: OpaquePointer!, _ zFunctionName: UnsafePointer<CChar>!, _ nArg: Int32, _ eTextRep: Int32, _ pApp: UnsafeMutableRawPointer!, _ xFunc: (@convention(c) (OpaquePointer?, Int32, UnsafeMutablePointer<OpaquePointer?>?) -> Void)!, _ xStep: (@convention(c) (OpaquePointer?, Int32, UnsafeMutablePointer<OpaquePointer?>?) -> Void)!, _ xFinal: (@convention(c) (OpaquePointer?) -> Void)!, _ xDestroy: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!) -> Int32

    static func sqlite3_create_window_function(_ db: OpaquePointer!, _ zFunctionName: UnsafePointer<CChar>!, _ nArg: Int32, _ eTextRep: Int32, _ pApp: UnsafeMutableRawPointer!, _ xStep: (@convention(c) (OpaquePointer?, Int32, UnsafeMutablePointer<OpaquePointer?>?) -> Void)!, _ xFinal: (@convention(c) (OpaquePointer?) -> Void)!, _ xValue: (@convention(c) (OpaquePointer?) -> Void)!, _ xInverse: (@convention(c) (OpaquePointer?, Int32, UnsafeMutablePointer<OpaquePointer?>?) -> Void)!, _ xDestroy: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!) -> Int32
    static var SQLITE_UTF8: Int32 { get }
    static var SQLITE_UTF16LE: Int32 { get }
    static var SQLITE_UTF16BE: Int32 { get }
    static var SQLITE_UTF16: Int32 { get }
    static var SQLITE_ANY: Int32 { get }
    static var SQLITE_UTF16_ALIGNED: Int32 { get }
    static var SQLITE_DETERMINISTIC: Int32 { get }
    static var SQLITE_DIRECTONLY: Int32 { get }
    static var SQLITE_SUBTYPE: Int32 { get }
    static var SQLITE_INNOCUOUS: Int32 { get }
    static func sqlite3_value_blob(_: OpaquePointer!) -> UnsafeRawPointer!
    static func sqlite3_value_double(_: OpaquePointer!) -> Double
    static func sqlite3_value_int(_: OpaquePointer!) -> Int32
    static func sqlite3_value_int64(_: OpaquePointer!) -> sqlite3_int64

    static func sqlite3_value_pointer(_: OpaquePointer!, _: UnsafePointer<CChar>!) -> UnsafeMutableRawPointer!
    static func sqlite3_value_text(_: OpaquePointer!) -> UnsafePointer<UInt8>!
    static func sqlite3_value_text16(_: OpaquePointer!) -> UnsafeRawPointer!
    static func sqlite3_value_text16le(_: OpaquePointer!) -> UnsafeRawPointer!
    static func sqlite3_value_text16be(_: OpaquePointer!) -> UnsafeRawPointer!
    static func sqlite3_value_bytes(_: OpaquePointer!) -> Int32
    static func sqlite3_value_bytes16(_: OpaquePointer!) -> Int32
    static func sqlite3_value_type(_: OpaquePointer!) -> Int32
    static func sqlite3_value_numeric_type(_: OpaquePointer!) -> Int32

    static func sqlite3_value_nochange(_: OpaquePointer!) -> Int32

    static func sqlite3_value_frombind(_: OpaquePointer!) -> Int32

    @available(macOS 14.2, *) static func sqlite3_value_encoding(_: OpaquePointer!) -> Int32

    static func sqlite3_value_subtype(_: OpaquePointer!) -> UInt32

    static func sqlite3_value_dup(_: OpaquePointer!) -> OpaquePointer!

    static func sqlite3_value_free(_: OpaquePointer!)
    static func sqlite3_aggregate_context(_: OpaquePointer!, _ nBytes: Int32) -> UnsafeMutableRawPointer!
//    static func sqlite3_user_data(_: OpaquePointer!) -> UnsafeMutableRawPointer!
    static func sqlite3_context_db_handle(_: OpaquePointer!) -> OpaquePointer!
    static func sqlite3_get_auxdata(_: OpaquePointer!, _ N: Int32) -> UnsafeMutableRawPointer!
    static func sqlite3_set_auxdata(_: OpaquePointer!, _ N: Int32, _: UnsafeMutableRawPointer!, _: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!)
    typealias sqlite3_destructor_type = @convention(c) (UnsafeMutableRawPointer?) -> Void
    static func sqlite3_result_blob(_: OpaquePointer!, _: UnsafeRawPointer!, _: Int32, _: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!)
    static func sqlite3_result_blob64(_: OpaquePointer!, _: UnsafeRawPointer!, _: sqlite3_uint64, _: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!)
    static func sqlite3_result_double(_: OpaquePointer!, _: Double)
    static func sqlite3_result_error(_: OpaquePointer!, _: UnsafePointer<CChar>!, _: Int32)
    static func sqlite3_result_error16(_: OpaquePointer!, _: UnsafeRawPointer!, _: Int32)
    static func sqlite3_result_error_toobig(_: OpaquePointer!)
    static func sqlite3_result_error_nomem(_: OpaquePointer!)
    static func sqlite3_result_error_code(_: OpaquePointer!, _: Int32)
    static func sqlite3_result_int(_: OpaquePointer!, _: Int32)
    static func sqlite3_result_int64(_: OpaquePointer!, _: sqlite3_int64)
    static func sqlite3_result_null(_: OpaquePointer!)
    static func sqlite3_result_text(_: OpaquePointer!, _: UnsafePointer<CChar>!, _: Int32, _: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!)
    static func sqlite3_result_text64(_: OpaquePointer!, _: UnsafePointer<CChar>!, _: sqlite3_uint64, _: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!, _ encoding: UInt8)
    static func sqlite3_result_text16(_: OpaquePointer!, _: UnsafeRawPointer!, _: Int32, _: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!)
    static func sqlite3_result_text16le(_: OpaquePointer!, _: UnsafeRawPointer!, _: Int32, _: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!)
    static func sqlite3_result_text16be(_: OpaquePointer!, _: UnsafeRawPointer!, _: Int32, _: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!)
    static func sqlite3_result_value(_: OpaquePointer!, _: OpaquePointer!)

    static func sqlite3_result_pointer(_: OpaquePointer!, _: UnsafeMutableRawPointer!, _: UnsafePointer<CChar>!, _: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!)
    static func sqlite3_result_zeroblob(_: OpaquePointer!, _ n: Int32)

    static func sqlite3_result_zeroblob64(_: OpaquePointer!, _ n: sqlite3_uint64) -> Int32

    static func sqlite3_result_subtype(_: OpaquePointer!, _: UInt32)
    static func sqlite3_create_collation(_: OpaquePointer!, _ zName: UnsafePointer<CChar>!, _ eTextRep: Int32, _ pArg: UnsafeMutableRawPointer!, _ xCompare: (@convention(c) (UnsafeMutableRawPointer?, Int32, UnsafeRawPointer?, Int32, UnsafeRawPointer?) -> Int32)!) -> Int32
    static func sqlite3_create_collation_v2(_: OpaquePointer!, _ zName: UnsafePointer<CChar>!, _ eTextRep: Int32, _ pArg: UnsafeMutableRawPointer!, _ xCompare: (@convention(c) (UnsafeMutableRawPointer?, Int32, UnsafeRawPointer?, Int32, UnsafeRawPointer?) -> Int32)!, _ xDestroy: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!) -> Int32
    static func sqlite3_create_collation16(_: OpaquePointer!, _ zName: UnsafeRawPointer!, _ eTextRep: Int32, _ pArg: UnsafeMutableRawPointer!, _ xCompare: (@convention(c) (UnsafeMutableRawPointer?, Int32, UnsafeRawPointer?, Int32, UnsafeRawPointer?) -> Int32)!) -> Int32
    static func sqlite3_collation_needed(_: OpaquePointer!, _: UnsafeMutableRawPointer!, _: (@convention(c) (UnsafeMutableRawPointer?, OpaquePointer?, Int32, UnsafePointer<CChar>?) -> Void)!) -> Int32
    static func sqlite3_collation_needed16(_: OpaquePointer!, _: UnsafeMutableRawPointer!, _: (@convention(c) (UnsafeMutableRawPointer?, OpaquePointer?, Int32, UnsafeRawPointer?) -> Void)!) -> Int32
    static func sqlite3_sleep(_: Int32) -> Int32
//    var sqlite3_temp_directory: UnsafeMutablePointer<CChar>! { get }
//
//    var sqlite3_data_directory: UnsafeMutablePointer<CChar>! { get }
    static func sqlite3_get_autocommit(_: OpaquePointer!) -> Int32
    static func sqlite3_db_handle(_: OpaquePointer!) -> OpaquePointer!

    @available(macOS 13, *) static func sqlite3_db_name(_ db: OpaquePointer!, _ N: Int32) -> UnsafePointer<CChar>!

    static func sqlite3_db_filename(_ db: OpaquePointer!, _ zDbName: UnsafePointer<CChar>!) -> sqlite3_filename!

    static func sqlite3_db_readonly(_ db: OpaquePointer!, _ zDbName: UnsafePointer<CChar>!) -> Int32

    @available(macOS 12, *) static func sqlite3_txn_state(_: OpaquePointer!, _ zSchema: UnsafePointer<CChar>!) -> Int32
    static var SQLITE_TXN_NONE: Int32 { get }
    static var SQLITE_TXN_READ: Int32 { get }
    static var SQLITE_TXN_WRITE: Int32 { get }
    static func sqlite3_next_stmt(_ pDb: OpaquePointer!, _ pStmt: OpaquePointer!) -> OpaquePointer!
    static func sqlite3_commit_hook(_: OpaquePointer!, _: (@convention(c) (UnsafeMutableRawPointer?) -> Int32)!, _: UnsafeMutableRawPointer!) -> UnsafeMutableRawPointer!
    static func sqlite3_rollback_hook(_: OpaquePointer!, _: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!, _: UnsafeMutableRawPointer!) -> UnsafeMutableRawPointer!

    @available(macOS 12.3, *) static func sqlite3_autovacuum_pages(_ db: OpaquePointer!, _: (@convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?, UInt32, UInt32, UInt32) -> UInt32)!, _: UnsafeMutableRawPointer!, _: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!) -> Int32
    static func sqlite3_update_hook(_: OpaquePointer!, _: (@convention(c) (UnsafeMutableRawPointer?, Int32, UnsafePointer<CChar>?, UnsafePointer<CChar>?, sqlite3_int64) -> Void)!, _: UnsafeMutableRawPointer!) -> UnsafeMutableRawPointer!

    static func sqlite3_release_memory(_: Int32) -> Int32
    static func sqlite3_db_release_memory(_: OpaquePointer!) -> Int32

    static func sqlite3_soft_heap_limit64(_ N: sqlite3_int64) -> sqlite3_int64
    static func sqlite3_table_column_metadata(_ db: OpaquePointer!, _ zDbName: UnsafePointer<CChar>!, _ zTableName: UnsafePointer<CChar>!, _ zColumnName: UnsafePointer<CChar>!, _ pzDataType: UnsafeMutablePointer<UnsafePointer<CChar>?>!, _ pzCollSeq: UnsafeMutablePointer<UnsafePointer<CChar>?>!, _ pNotNull: UnsafeMutablePointer<Int32>!, _ pPrimaryKey: UnsafeMutablePointer<Int32>!, _ pAutoinc: UnsafeMutablePointer<Int32>!) -> Int32

    static func sqlite3_auto_extension(_ xEntryPoint: (@convention(c) () -> Void)!) -> Int32

    static func sqlite3_cancel_auto_extension(_ xEntryPoint: (@convention(c) () -> Void)!) -> Int32

    static func sqlite3_reset_auto_extension()
//    struct sqlite3_module {
//
//        public init()
//
//        public init(iVersion: Int32, xCreate: (@convention(c) (OpaquePointer?, UnsafeMutableRawPointer?, Int32, UnsafePointer<UnsafePointer<CChar>?>?, UnsafeMutablePointer<UnsafeMutablePointer<sqlite3_vtab>?>?, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32)!, xConnect: (@convention(c) (OpaquePointer?, UnsafeMutableRawPointer?, Int32, UnsafePointer<UnsafePointer<CChar>?>?, UnsafeMutablePointer<UnsafeMutablePointer<sqlite3_vtab>?>?, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32)!, xBestIndex: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?, UnsafeMutablePointer<sqlite3_index_info>?) -> Int32)!, xDisconnect: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?) -> Int32)!, xDestroy: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?) -> Int32)!, xOpen: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?, UnsafeMutablePointer<UnsafeMutablePointer<sqlite3_vtab_cursor>?>?) -> Int32)!, xClose: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab_cursor>?) -> Int32)!, xFilter: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab_cursor>?, Int32, UnsafePointer<CChar>?, Int32, UnsafeMutablePointer<OpaquePointer?>?) -> Int32)!, xNext: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab_cursor>?) -> Int32)!, xEof: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab_cursor>?) -> Int32)!, xColumn: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab_cursor>?, OpaquePointer?, Int32) -> Int32)!, xRowid: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab_cursor>?, UnsafeMutablePointer<sqlite3_int64>?) -> Int32)!, xUpdate: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?, Int32, UnsafeMutablePointer<OpaquePointer?>?, UnsafeMutablePointer<sqlite3_int64>?) -> Int32)!, xBegin: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?) -> Int32)!, xSync: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?) -> Int32)!, xCommit: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?) -> Int32)!, xRollback: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?) -> Int32)!, xFindFunction: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?, Int32, UnsafePointer<CChar>?, UnsafeMutablePointer<(@convention(c) (OpaquePointer?, Int32, UnsafeMutablePointer<OpaquePointer?>?) -> Void)?>?, UnsafeMutablePointer<UnsafeMutableRawPointer?>?) -> Int32)!, xRename: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?, UnsafePointer<CChar>?) -> Int32)!, xSavepoint: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?, Int32) -> Int32)!, xRelease: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?, Int32) -> Int32)!, xRollbackTo: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?, Int32) -> Int32)!, xShadowName: (@convention(c) (UnsafePointer<CChar>?) -> Int32)!)
//
//        public var iVersion: Int32
//
//        public var xCreate: (@convention(c) (OpaquePointer?, UnsafeMutableRawPointer?, Int32, UnsafePointer<UnsafePointer<CChar>?>?, UnsafeMutablePointer<UnsafeMutablePointer<sqlite3_vtab>?>?, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32)!
//
//        public var xConnect: (@convention(c) (OpaquePointer?, UnsafeMutableRawPointer?, Int32, UnsafePointer<UnsafePointer<CChar>?>?, UnsafeMutablePointer<UnsafeMutablePointer<sqlite3_vtab>?>?, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32)!
//
//        public var xBestIndex: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?, UnsafeMutablePointer<sqlite3_index_info>?) -> Int32)!
//
//        public var xDisconnect: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?) -> Int32)!
//
//        public var xDestroy: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?) -> Int32)!
//
//        public var xOpen: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?, UnsafeMutablePointer<UnsafeMutablePointer<sqlite3_vtab_cursor>?>?) -> Int32)!
//
//        public var xClose: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab_cursor>?) -> Int32)!
//
//        public var xFilter: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab_cursor>?, Int32, UnsafePointer<CChar>?, Int32, UnsafeMutablePointer<OpaquePointer?>?) -> Int32)!
//
//        public var xNext: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab_cursor>?) -> Int32)!
//
//        public var xEof: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab_cursor>?) -> Int32)!
//
//        public var xColumn: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab_cursor>?, OpaquePointer?, Int32) -> Int32)!
//
//        public var xRowid: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab_cursor>?, UnsafeMutablePointer<sqlite3_int64>?) -> Int32)!
//
//        public var xUpdate: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?, Int32, UnsafeMutablePointer<OpaquePointer?>?, UnsafeMutablePointer<sqlite3_int64>?) -> Int32)!
//
//        public var xBegin: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?) -> Int32)!
//
//        public var xSync: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?) -> Int32)!
//
//        public var xCommit: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?) -> Int32)!
//
//        public var xRollback: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?) -> Int32)!
//
//        public var xFindFunction: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?, Int32, UnsafePointer<CChar>?, UnsafeMutablePointer<(@convention(c) (OpaquePointer?, Int32, UnsafeMutablePointer<OpaquePointer?>?) -> Void)?>?, UnsafeMutablePointer<UnsafeMutableRawPointer?>?) -> Int32)!
//
//        public var xRename: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?, UnsafePointer<CChar>?) -> Int32)!
//
//        public var xSavepoint: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?, Int32) -> Int32)!
//
//        public var xRelease: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?, Int32) -> Int32)!
//
//        public var xRollbackTo: (@convention(c) (UnsafeMutablePointer<sqlite3_vtab>?, Int32) -> Int32)!
//
//        public var xShadowName: (@convention(c) (UnsafePointer<CChar>?) -> Int32)!
//    }
//    struct sqlite3_index_info {
//
//        public init()
//
//        public init(nConstraint: Int32, aConstraint: UnsafeMutablePointer<sqlite3_index_constraint>!, nOrderBy: Int32, aOrderBy: UnsafeMutablePointer<sqlite3_index_orderby>!, aConstraintUsage: UnsafeMutablePointer<sqlite3_index_constraint_usage>!, idxNum: Int32, idxStr: UnsafeMutablePointer<CChar>!, needToFreeIdxStr: Int32, orderByConsumed: Int32, estimatedCost: Double, estimatedRows: sqlite3_int64, idxFlags: Int32, colUsed: sqlite3_uint64)
//
//        public var nConstraint: Int32
//
//        public var aConstraint: UnsafeMutablePointer<sqlite3_index_constraint>!
//
//        public var nOrderBy: Int32
//
//        public var aOrderBy: UnsafeMutablePointer<sqlite3_index_orderby>!
//
//        public var aConstraintUsage: UnsafeMutablePointer<sqlite3_index_constraint_usage>!
//
//        public var idxNum: Int32
//
//        public var idxStr: UnsafeMutablePointer<CChar>!
//
//        public var needToFreeIdxStr: Int32
//
//        public var orderByConsumed: Int32
//
//        public var estimatedCost: Double
//
//        public var estimatedRows: sqlite3_int64
//
//        public var idxFlags: Int32
//
//        public var colUsed: sqlite3_uint64
//    }
//    struct sqlite3_index_constraint {
//
//        public init()
//
//        public init(iColumn: Int32, op: UInt8, usable: UInt8, iTermOffset: Int32)
//
//        public var iColumn: Int32
//
//        public var op: UInt8
//
//        public var usable: UInt8
//
//        public var iTermOffset: Int32
//    }
//    struct sqlite3_index_orderby {
//
//        public init()
//
//        public init(iColumn: Int32, desc: UInt8)
//
//        public var iColumn: Int32
//
//        public var desc: UInt8
//    }
//    struct sqlite3_index_constraint_usage {
//
//        public init()
//
//        public init(argvIndex: Int32, omit: UInt8)
//
//        public var argvIndex: Int32
//
//        public var omit: UInt8
//    }
    static var SQLITE_INDEX_SCAN_UNIQUE: Int32 { get }
    static var SQLITE_INDEX_CONSTRAINT_EQ: Int32 { get }
    static var SQLITE_INDEX_CONSTRAINT_GT: Int32 { get }
    static var SQLITE_INDEX_CONSTRAINT_LE: Int32 { get }
    static var SQLITE_INDEX_CONSTRAINT_LT: Int32 { get }
    static var SQLITE_INDEX_CONSTRAINT_GE: Int32 { get }
    static var SQLITE_INDEX_CONSTRAINT_MATCH: Int32 { get }
    static var SQLITE_INDEX_CONSTRAINT_LIKE: Int32 { get }
    static var SQLITE_INDEX_CONSTRAINT_GLOB: Int32 { get }
    static var SQLITE_INDEX_CONSTRAINT_REGEXP: Int32 { get }
    static var SQLITE_INDEX_CONSTRAINT_NE: Int32 { get }
    static var SQLITE_INDEX_CONSTRAINT_ISNOT: Int32 { get }
    static var SQLITE_INDEX_CONSTRAINT_ISNOTNULL: Int32 { get }
    static var SQLITE_INDEX_CONSTRAINT_ISNULL: Int32 { get }
    static var SQLITE_INDEX_CONSTRAINT_IS: Int32 { get }
    static var SQLITE_INDEX_CONSTRAINT_LIMIT: Int32 { get }
    static var SQLITE_INDEX_CONSTRAINT_OFFSET: Int32 { get }
    static var SQLITE_INDEX_CONSTRAINT_FUNCTION: Int32 { get }
//    func sqlite3_create_module(_ db: OpaquePointer!, _ zName: UnsafePointer<CChar>!, _ p: UnsafePointer<sqlite3_module>!, _ pClientData: UnsafeMutableRawPointer!) -> Int32
//    func sqlite3_create_module_v2(_ db: OpaquePointer!, _ zName: UnsafePointer<CChar>!, _ p: UnsafePointer<sqlite3_module>!, _ pClientData: UnsafeMutableRawPointer!, _ xDestroy: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!) -> Int32
    static func sqlite3_drop_modules(_ db: OpaquePointer!, _ azKeep: UnsafeMutablePointer<UnsafePointer<CChar>?>!) -> Int32
//    struct sqlite3_vtab {
//
//        public init()
//
//        public init(pModule: UnsafePointer<sqlite3_module>!, nRef: Int32, zErrMsg: UnsafeMutablePointer<CChar>!)
//
//        public var pModule: UnsafePointer<sqlite3_module>!
//
//        public var nRef: Int32
//
//        public var zErrMsg: UnsafeMutablePointer<CChar>!
//    }
//    struct sqlite3_vtab_cursor {
//
//        public init()
//
//        public init(pVtab: UnsafeMutablePointer<sqlite3_vtab>!)
//
//        public var pVtab: UnsafeMutablePointer<sqlite3_vtab>!
//    }
    static func sqlite3_declare_vtab(_: OpaquePointer!, _ zSQL: UnsafePointer<CChar>!) -> Int32
    static func sqlite3_overload_function(_: OpaquePointer!, _ zFuncName: UnsafePointer<CChar>!, _ nArg: Int32) -> Int32
    static func sqlite3_blob_open(_: OpaquePointer!, _ zDb: UnsafePointer<CChar>!, _ zTable: UnsafePointer<CChar>!, _ zColumn: UnsafePointer<CChar>!, _ iRow: sqlite3_int64, _ flags: Int32, _ ppBlob: UnsafeMutablePointer<OpaquePointer?>!) -> Int32

    static func sqlite3_blob_reopen(_: OpaquePointer!, _: sqlite3_int64) -> Int32
    static func sqlite3_blob_close(_: OpaquePointer!) -> Int32
    static func sqlite3_blob_bytes(_: OpaquePointer!) -> Int32
    static func sqlite3_blob_read(_: OpaquePointer!, _ Z: UnsafeMutableRawPointer!, _ N: Int32, _ iOffset: Int32) -> Int32
    static func sqlite3_blob_write(_: OpaquePointer!, _ z: UnsafeRawPointer!, _ n: Int32, _ iOffset: Int32) -> Int32
//    func sqlite3_vfs_find(_ zVfsName: UnsafePointer<CChar>!) -> UnsafeMutablePointer<sqlite3_vfs>!
//    func sqlite3_vfs_register(_: UnsafeMutablePointer<sqlite3_vfs>!, _ makeDflt: Int32) -> Int32
//    func sqlite3_vfs_unregister(_: UnsafeMutablePointer<sqlite3_vfs>!) -> Int32
    static func sqlite3_mutex_alloc(_: Int32) -> OpaquePointer!
    static func sqlite3_mutex_free(_: OpaquePointer!)
    static func sqlite3_mutex_enter(_: OpaquePointer!)
    static func sqlite3_mutex_try(_: OpaquePointer!) -> Int32
    static func sqlite3_mutex_leave(_: OpaquePointer!)
//    struct sqlite3_mutex_methods {
//
//        public init()
//
//        public init(xMutexInit: (@convention(c) () -> Int32)!, xMutexEnd: (@convention(c) () -> Int32)!, xMutexAlloc: (@convention(c) (Int32) -> OpaquePointer?)!, xMutexFree: (@convention(c) (OpaquePointer?) -> Void)!, xMutexEnter: (@convention(c) (OpaquePointer?) -> Void)!, xMutexTry: (@convention(c) (OpaquePointer?) -> Int32)!, xMutexLeave: (@convention(c) (OpaquePointer?) -> Void)!, xMutexHeld: (@convention(c) (OpaquePointer?) -> Int32)!, xMutexNotheld: (@convention(c) (OpaquePointer?) -> Int32)!)
//
//        public var xMutexInit: (@convention(c) () -> Int32)!
//
//        public var xMutexEnd: (@convention(c) () -> Int32)!
//
//        public var xMutexAlloc: (@convention(c) (Int32) -> OpaquePointer?)!
//
//        public var xMutexFree: (@convention(c) (OpaquePointer?) -> Void)!
//
//        public var xMutexEnter: (@convention(c) (OpaquePointer?) -> Void)!
//
//        public var xMutexTry: (@convention(c) (OpaquePointer?) -> Int32)!
//
//        public var xMutexLeave: (@convention(c) (OpaquePointer?) -> Void)!
//
//        public var xMutexHeld: (@convention(c) (OpaquePointer?) -> Int32)!
//
//        public var xMutexNotheld: (@convention(c) (OpaquePointer?) -> Int32)!
//    }
    static var SQLITE_MUTEX_FAST: Int32 { get }
    static var SQLITE_MUTEX_RECURSIVE: Int32 { get }
    static var SQLITE_MUTEX_STATIC_MAIN: Int32 { get }
    static var SQLITE_MUTEX_STATIC_MEM: Int32 { get }
    static var SQLITE_MUTEX_STATIC_MEM2: Int32 { get }
    static var SQLITE_MUTEX_STATIC_OPEN: Int32 { get }
    static var SQLITE_MUTEX_STATIC_PRNG: Int32 { get }
    static var SQLITE_MUTEX_STATIC_LRU: Int32 { get }
    static var SQLITE_MUTEX_STATIC_LRU2: Int32 { get }
    static var SQLITE_MUTEX_STATIC_PMEM: Int32 { get }
    static var SQLITE_MUTEX_STATIC_APP1: Int32 { get }
    static var SQLITE_MUTEX_STATIC_APP2: Int32 { get }
    static var SQLITE_MUTEX_STATIC_APP3: Int32 { get }
    static var SQLITE_MUTEX_STATIC_VFS1: Int32 { get }
    static var SQLITE_MUTEX_STATIC_VFS2: Int32 { get }
    static var SQLITE_MUTEX_STATIC_VFS3: Int32 { get }
    static var SQLITE_MUTEX_STATIC_MASTER: Int32 { get }
    static func sqlite3_db_mutex(_: OpaquePointer!) -> OpaquePointer!
    static func sqlite3_file_control(_: OpaquePointer!, _ zDbName: UnsafePointer<CChar>!, _ op: Int32, _: UnsafeMutableRawPointer!) -> Int32
    static var SQLITE_TESTCTRL_FIRST: Int32 { get }
    static var SQLITE_TESTCTRL_PRNG_SAVE: Int32 { get }
    static var SQLITE_TESTCTRL_PRNG_RESTORE: Int32 { get }
    static var SQLITE_TESTCTRL_PRNG_RESET: Int32 { get }
    static var SQLITE_TESTCTRL_BITVEC_TEST: Int32 { get }
    static var SQLITE_TESTCTRL_FAULT_INSTALL: Int32 { get }
    static var SQLITE_TESTCTRL_BENIGN_MALLOC_HOOKS: Int32 { get }
    static var SQLITE_TESTCTRL_PENDING_BYTE: Int32 { get }
    static var SQLITE_TESTCTRL_ASSERT: Int32 { get }
    static var SQLITE_TESTCTRL_ALWAYS: Int32 { get }
    static var SQLITE_TESTCTRL_RESERVE: Int32 { get }
    static var SQLITE_TESTCTRL_OPTIMIZATIONS: Int32 { get }
    static var SQLITE_TESTCTRL_ISKEYWORD: Int32 { get }
    static var SQLITE_TESTCTRL_SCRATCHMALLOC: Int32 { get }
    static var SQLITE_TESTCTRL_INTERNAL_FUNCTIONS: Int32 { get }
    static var SQLITE_TESTCTRL_LOCALTIME_FAULT: Int32 { get }
    static var SQLITE_TESTCTRL_EXPLAIN_STMT: Int32 { get }
    static var SQLITE_TESTCTRL_ONCE_RESET_THRESHOLD: Int32 { get }
    static var SQLITE_TESTCTRL_NEVER_CORRUPT: Int32 { get }
    static var SQLITE_TESTCTRL_VDBE_COVERAGE: Int32 { get }
    static var SQLITE_TESTCTRL_BYTEORDER: Int32 { get }
    static var SQLITE_TESTCTRL_ISINIT: Int32 { get }
    static var SQLITE_TESTCTRL_SORTER_MMAP: Int32 { get }
    static var SQLITE_TESTCTRL_IMPOSTER: Int32 { get }
    static var SQLITE_TESTCTRL_PARSER_COVERAGE: Int32 { get }
    static var SQLITE_TESTCTRL_RESULT_INTREAL: Int32 { get }
    static var SQLITE_TESTCTRL_PRNG_SEED: Int32 { get }
    static var SQLITE_TESTCTRL_EXTRA_SCHEMA_CHECKS: Int32 { get }
    static var SQLITE_TESTCTRL_SEEK_COUNT: Int32 { get }
    static var SQLITE_TESTCTRL_TRACEFLAGS: Int32 { get }
    static var SQLITE_TESTCTRL_TUNE: Int32 { get }
    static var SQLITE_TESTCTRL_LOGEST: Int32 { get }
    static var SQLITE_TESTCTRL_USELONGDOUBLE: Int32 { get }
    static var SQLITE_TESTCTRL_LAST: Int32 { get }

    static func sqlite3_keyword_count() -> Int32

    static func sqlite3_keyword_name(_: Int32, _: UnsafeMutablePointer<UnsafePointer<CChar>?>!, _: UnsafeMutablePointer<Int32>!) -> Int32

    static func sqlite3_keyword_check(_: UnsafePointer<CChar>!, _: Int32) -> Int32

    static func sqlite3_str_new(_: OpaquePointer!) -> OpaquePointer!

    static func sqlite3_str_finish(_: OpaquePointer!) -> UnsafeMutablePointer<CChar>!

    static func sqlite3_str_vappendf(_: OpaquePointer!, _ zFormat: UnsafePointer<CChar>!, _: CVaListPointer)

    static func sqlite3_str_append(_: OpaquePointer!, _ zIn: UnsafePointer<CChar>!, _ N: Int32)

    static func sqlite3_str_appendall(_: OpaquePointer!, _ zIn: UnsafePointer<CChar>!)

    static func sqlite3_str_appendchar(_: OpaquePointer!, _ N: Int32, _ C: CChar)

    static func sqlite3_str_reset(_: OpaquePointer!)

    static func sqlite3_str_errcode(_: OpaquePointer!) -> Int32

    static func sqlite3_str_length(_: OpaquePointer!) -> Int32

    static func sqlite3_str_value(_: OpaquePointer!) -> UnsafeMutablePointer<CChar>!
    static func sqlite3_status(_ op: Int32, _ pCurrent: UnsafeMutablePointer<Int32>!, _ pHighwater: UnsafeMutablePointer<Int32>!, _ resetFlag: Int32) -> Int32

    static func sqlite3_status64(_ op: Int32, _ pCurrent: UnsafeMutablePointer<sqlite3_int64>!, _ pHighwater: UnsafeMutablePointer<sqlite3_int64>!, _ resetFlag: Int32) -> Int32
    static var SQLITE_STATUS_MEMORY_USED: Int32 { get }
    static var SQLITE_STATUS_PAGECACHE_USED: Int32 { get }
    static var SQLITE_STATUS_PAGECACHE_OVERFLOW: Int32 { get }
    static var SQLITE_STATUS_SCRATCH_USED: Int32 { get }
    static var SQLITE_STATUS_SCRATCH_OVERFLOW: Int32 { get }
    static var SQLITE_STATUS_MALLOC_SIZE: Int32 { get }
    static var SQLITE_STATUS_PARSER_STACK: Int32 { get }
    static var SQLITE_STATUS_PAGECACHE_SIZE: Int32 { get }
    static var SQLITE_STATUS_SCRATCH_SIZE: Int32 { get }
    static var SQLITE_STATUS_MALLOC_COUNT: Int32 { get }
    static func sqlite3_db_status(_: OpaquePointer!, _ op: Int32, _ pCur: UnsafeMutablePointer<Int32>!, _ pHiwtr: UnsafeMutablePointer<Int32>!, _ resetFlg: Int32) -> Int32
    static var SQLITE_DBSTATUS_LOOKASIDE_USED: Int32 { get }
    static var SQLITE_DBSTATUS_CACHE_USED: Int32 { get }
    static var SQLITE_DBSTATUS_SCHEMA_USED: Int32 { get }
    static var SQLITE_DBSTATUS_STMT_USED: Int32 { get }
    static var SQLITE_DBSTATUS_LOOKASIDE_HIT: Int32 { get }
    static var SQLITE_DBSTATUS_LOOKASIDE_MISS_SIZE: Int32 { get }
    static var SQLITE_DBSTATUS_LOOKASIDE_MISS_FULL: Int32 { get }
    static var SQLITE_DBSTATUS_CACHE_HIT: Int32 { get }
    static var SQLITE_DBSTATUS_CACHE_MISS: Int32 { get }
    static var SQLITE_DBSTATUS_CACHE_WRITE: Int32 { get }
    static var SQLITE_DBSTATUS_DEFERRED_FKS: Int32 { get }
    static var SQLITE_DBSTATUS_CACHE_USED_SHARED: Int32 { get }
    static var SQLITE_DBSTATUS_CACHE_SPILL: Int32 { get }
    static var SQLITE_DBSTATUS_MAX: Int32 { get }
    static func sqlite3_stmt_status(_: OpaquePointer!, _ op: Int32, _ resetFlg: Int32) -> Int32
    static var SQLITE_STMTSTATUS_FULLSCAN_STEP: Int32 { get }
    static var SQLITE_STMTSTATUS_SORT: Int32 { get }
    static var SQLITE_STMTSTATUS_AUTOINDEX: Int32 { get }
    static var SQLITE_STMTSTATUS_VM_STEP: Int32 { get }
    static var SQLITE_STMTSTATUS_REPREPARE: Int32 { get }
    static var SQLITE_STMTSTATUS_RUN: Int32 { get }
    static var SQLITE_STMTSTATUS_FILTER_MISS: Int32 { get }
    static var SQLITE_STMTSTATUS_FILTER_HIT: Int32 { get }
    static var SQLITE_STMTSTATUS_MEMUSED: Int32 { get }
//    struct sqlite3_pcache_page {
//
//        public init()
//
//        public init(pBuf: UnsafeMutableRawPointer!, pExtra: UnsafeMutableRawPointer!)
//
//        public var pBuf: UnsafeMutableRawPointer!
//
//        public var pExtra: UnsafeMutableRawPointer!
//    }
//    struct sqlite3_pcache_methods2 {
//
//        public init()
//
//        public init(iVersion: Int32, pArg: UnsafeMutableRawPointer!, xInit: (@convention(c) (UnsafeMutableRawPointer?) -> Int32)!, xShutdown: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!, xCreate: (@convention(c) (Int32, Int32, Int32) -> OpaquePointer?)!, xCachesize: (@convention(c) (OpaquePointer?, Int32) -> Void)!, xPagecount: (@convention(c) (OpaquePointer?) -> Int32)!, xFetch: (@convention(c) (OpaquePointer?, UInt32, Int32) -> UnsafeMutablePointer<sqlite3_pcache_page>?)!, xUnpin: (@convention(c) (OpaquePointer?, UnsafeMutablePointer<sqlite3_pcache_page>?, Int32) -> Void)!, xRekey: (@convention(c) (OpaquePointer?, UnsafeMutablePointer<sqlite3_pcache_page>?, UInt32, UInt32) -> Void)!, xTruncate: (@convention(c) (OpaquePointer?, UInt32) -> Void)!, xDestroy: (@convention(c) (OpaquePointer?) -> Void)!, xShrink: (@convention(c) (OpaquePointer?) -> Void)!)
//
//        public var iVersion: Int32
//
//        public var pArg: UnsafeMutableRawPointer!
//
//        public var xInit: (@convention(c) (UnsafeMutableRawPointer?) -> Int32)!
//
//        public var xShutdown: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!
//
//        public var xCreate: (@convention(c) (Int32, Int32, Int32) -> OpaquePointer?)!
//
//        public var xCachesize: (@convention(c) (OpaquePointer?, Int32) -> Void)!
//
//        public var xPagecount: (@convention(c) (OpaquePointer?) -> Int32)!
//
//        public var xFetch: (@convention(c) (OpaquePointer?, UInt32, Int32) -> UnsafeMutablePointer<sqlite3_pcache_page>?)!
//
//        public var xUnpin: (@convention(c) (OpaquePointer?, UnsafeMutablePointer<sqlite3_pcache_page>?, Int32) -> Void)!
//
//        public var xRekey: (@convention(c) (OpaquePointer?, UnsafeMutablePointer<sqlite3_pcache_page>?, UInt32, UInt32) -> Void)!
//
//        public var xTruncate: (@convention(c) (OpaquePointer?, UInt32) -> Void)!
//
//        public var xDestroy: (@convention(c) (OpaquePointer?) -> Void)!
//
//        public var xShrink: (@convention(c) (OpaquePointer?) -> Void)!
//    }
//    struct sqlite3_pcache_methods {
//
//        public init()
//
//        public init(pArg: UnsafeMutableRawPointer!, xInit: (@convention(c) (UnsafeMutableRawPointer?) -> Int32)!, xShutdown: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!, xCreate: (@convention(c) (Int32, Int32) -> OpaquePointer?)!, xCachesize: (@convention(c) (OpaquePointer?, Int32) -> Void)!, xPagecount: (@convention(c) (OpaquePointer?) -> Int32)!, xFetch: (@convention(c) (OpaquePointer?, UInt32, Int32) -> UnsafeMutableRawPointer?)!, xUnpin: (@convention(c) (OpaquePointer?, UnsafeMutableRawPointer?, Int32) -> Void)!, xRekey: (@convention(c) (OpaquePointer?, UnsafeMutableRawPointer?, UInt32, UInt32) -> Void)!, xTruncate: (@convention(c) (OpaquePointer?, UInt32) -> Void)!, xDestroy: (@convention(c) (OpaquePointer?) -> Void)!)
//
//        public var pArg: UnsafeMutableRawPointer!
//
//        public var xInit: (@convention(c) (UnsafeMutableRawPointer?) -> Int32)!
//
//        public var xShutdown: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!
//
//        public var xCreate: (@convention(c) (Int32, Int32) -> OpaquePointer?)!
//
//        public var xCachesize: (@convention(c) (OpaquePointer?, Int32) -> Void)!
//
//        public var xPagecount: (@convention(c) (OpaquePointer?) -> Int32)!
//
//        public var xFetch: (@convention(c) (OpaquePointer?, UInt32, Int32) -> UnsafeMutableRawPointer?)!
//
//        public var xUnpin: (@convention(c) (OpaquePointer?, UnsafeMutableRawPointer?, Int32) -> Void)!
//
//        public var xRekey: (@convention(c) (OpaquePointer?, UnsafeMutableRawPointer?, UInt32, UInt32) -> Void)!
//
//        public var xTruncate: (@convention(c) (OpaquePointer?, UInt32) -> Void)!
//
//        public var xDestroy: (@convention(c) (OpaquePointer?) -> Void)!
//    }
    static func sqlite3_backup_init(_ pDest: OpaquePointer!, _ zDestName: UnsafePointer<CChar>!, _ pSource: OpaquePointer!, _ zSourceName: UnsafePointer<CChar>!) -> OpaquePointer!
    static func sqlite3_backup_step(_ p: OpaquePointer!, _ nPage: Int32) -> Int32
    static func sqlite3_backup_finish(_ p: OpaquePointer!) -> Int32
    static func sqlite3_backup_remaining(_ p: OpaquePointer!) -> Int32
    static func sqlite3_backup_pagecount(_ p: OpaquePointer!) -> Int32

    static func sqlite3_stricmp(_: UnsafePointer<CChar>!, _: UnsafePointer<CChar>!) -> Int32

    static func sqlite3_strnicmp(_: UnsafePointer<CChar>!, _: UnsafePointer<CChar>!, _: Int32) -> Int32

    static func sqlite3_strglob(_ zGlob: UnsafePointer<CChar>!, _ zStr: UnsafePointer<CChar>!) -> Int32

    static func sqlite3_strlike(_ zGlob: UnsafePointer<CChar>!, _ zStr: UnsafePointer<CChar>!, _ cEsc: UInt32) -> Int32

    static func sqlite3_wal_hook(_: OpaquePointer!, _: (@convention(c) (UnsafeMutableRawPointer?, OpaquePointer?, UnsafePointer<CChar>?, Int32) -> Int32)!, _: UnsafeMutableRawPointer!) -> UnsafeMutableRawPointer!

    static func sqlite3_wal_autocheckpoint(_ db: OpaquePointer!, _ N: Int32) -> Int32

    static func sqlite3_wal_checkpoint(_ db: OpaquePointer!, _ zDb: UnsafePointer<CChar>!) -> Int32

    static func sqlite3_wal_checkpoint_v2(_ db: OpaquePointer!, _ zDb: UnsafePointer<CChar>!, _ eMode: Int32, _ pnLog: UnsafeMutablePointer<Int32>!, _ pnCkpt: UnsafeMutablePointer<Int32>!) -> Int32
    static var SQLITE_CHECKPOINT_PASSIVE: Int32 { get }
    static var SQLITE_CHECKPOINT_FULL: Int32 { get }
    static var SQLITE_CHECKPOINT_RESTART: Int32 { get }
    static var SQLITE_CHECKPOINT_TRUNCATE: Int32 { get }
    static var SQLITE_VTAB_CONSTRAINT_SUPPORT: Int32 { get }
    static var SQLITE_VTAB_INNOCUOUS: Int32 { get }
    static var SQLITE_VTAB_DIRECTONLY: Int32 { get }
    static var SQLITE_VTAB_USES_ALL_SCHEMAS: Int32 { get }

    static func sqlite3_vtab_on_conflict(_: OpaquePointer!) -> Int32

    static func sqlite3_vtab_nochange(_: OpaquePointer!) -> Int32

//    func sqlite3_vtab_collation(_: UnsafeMutablePointer<sqlite3_index_info>!, _: Int32) -> UnsafePointer<CChar>!
//
//    func sqlite3_vtab_distinct(_: UnsafeMutablePointer<sqlite3_index_info>!) -> Int32
//
//    func sqlite3_vtab_in(_: UnsafeMutablePointer<sqlite3_index_info>!, _ iCons: Int32, _ bHandle: Int32) -> Int32
//
//    func sqlite3_vtab_in_first(_ pVal: OpaquePointer!, _ ppOut: UnsafeMutablePointer<OpaquePointer?>!) -> Int32
//
//    func sqlite3_vtab_in_next(_ pVal: OpaquePointer!, _ ppOut: UnsafeMutablePointer<OpaquePointer?>!) -> Int32
//
//    func sqlite3_vtab_rhs_value(_: UnsafeMutablePointer<sqlite3_index_info>!, _: Int32, _ ppVal: UnsafeMutablePointer<OpaquePointer?>!) -> Int32
    static var SQLITE_ROLLBACK: Int32 { get }
    static var SQLITE_FAIL: Int32 { get }
    static var SQLITE_REPLACE: Int32 { get }
    static var SQLITE_SCANSTAT_NLOOP: Int32 { get }
    static var SQLITE_SCANSTAT_NVISIT: Int32 { get }
    static var SQLITE_SCANSTAT_EST: Int32 { get }
    static var SQLITE_SCANSTAT_NAME: Int32 { get }
    static var SQLITE_SCANSTAT_EXPLAIN: Int32 { get }
    static var SQLITE_SCANSTAT_SELECTID: Int32 { get }
    static var SQLITE_SCANSTAT_PARENTID: Int32 { get }
    static var SQLITE_SCANSTAT_NCYCLE: Int32 { get }

    @available(macOS 11, *) static func sqlite3_stmt_scanstatus(_ pStmt: OpaquePointer!, _ idx: Int32, _ iScanStatusOp: Int32, _ pOut: UnsafeMutableRawPointer!) -> Int32

    @available(macOS 14.2, *) static func sqlite3_stmt_scanstatus_v2(_ pStmt: OpaquePointer!, _ idx: Int32, _ iScanStatusOp: Int32, _ flags: Int32, _ pOut: UnsafeMutableRawPointer!) -> Int32
    static var SQLITE_SCANSTAT_COMPLEX: Int32 { get }

    @available(macOS 11, *) static func sqlite3_stmt_scanstatus_reset(_: OpaquePointer!)

    static func sqlite3_db_cacheflush(_: OpaquePointer!) -> Int32

    static func sqlite3_system_errno(_: OpaquePointer!) -> Int32
//    struct sqlite3_snapshot {
//
//        public init()
//
//        public init(hidden: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8))
//
//        public var hidden: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)
//    }

    static func sqlite3_snapshot_get(_ db: OpaquePointer!, _ zSchema: UnsafePointer<CChar>!, _ ppSnapshot: UnsafeMutablePointer<UnsafeMutablePointer<sqlite3_snapshot>?>!) -> Int32

    static func sqlite3_snapshot_open(_ db: OpaquePointer!, _ zSchema: UnsafePointer<CChar>!, _ pSnapshot: UnsafeMutablePointer<sqlite3_snapshot>!) -> Int32

    static func sqlite3_snapshot_free(_: UnsafeMutablePointer<sqlite3_snapshot>!)

    static func sqlite3_snapshot_cmp(_ p1: UnsafeMutablePointer<sqlite3_snapshot>!, _ p2: UnsafeMutablePointer<sqlite3_snapshot>!) -> Int32

    static func sqlite3_snapshot_recover(_ db: OpaquePointer!, _ zDb: UnsafePointer<CChar>!) -> Int32

    static func sqlite3_serialize(_ db: OpaquePointer!, _ zSchema: UnsafePointer<CChar>!, _ piSize: UnsafeMutablePointer<sqlite3_int64>!, _ mFlags: UInt32) -> UnsafeMutablePointer<UInt8>!
    static var SQLITE_SERIALIZE_NOCOPY: Int32 { get }

    static func sqlite3_deserialize(_ db: OpaquePointer!, _ zSchema: UnsafePointer<CChar>!, _ pData: UnsafeMutablePointer<UInt8>!, _ szDb: sqlite3_int64, _ szBuf: sqlite3_int64, _ mFlags: UInt32) -> Int32
    static var SQLITE_DESERIALIZE_FREEONCLOSE: Int32 { get }
    static var SQLITE_DESERIALIZE_RESIZEABLE: Int32 { get }
    static var SQLITE_DESERIALIZE_READONLY: Int32 { get }
    typealias sqlite3_rtree_dbl = Double

//    func sqlite3_rtree_geometry_callback(_ db: OpaquePointer!, _ zGeom: UnsafePointer<CChar>!, _ xGeom: (@convention(c) (UnsafeMutablePointer<sqlite3_rtree_geometry>?, Int32, UnsafeMutablePointer<sqlite3_rtree_dbl>?, UnsafeMutablePointer<Int32>?) -> Int32)!, _ pContext: UnsafeMutableRawPointer!) -> Int32
//    struct sqlite3_rtree_geometry {
//
//        public init()
//
//        public init(pContext: UnsafeMutableRawPointer!, nParam: Int32, aParam: UnsafeMutablePointer<sqlite3_rtree_dbl>!, pUser: UnsafeMutableRawPointer!, xDelUser: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!)
//
//        public var pContext: UnsafeMutableRawPointer!
//
//        public var nParam: Int32
//
//        public var aParam: UnsafeMutablePointer<sqlite3_rtree_dbl>!
//
//        public var pUser: UnsafeMutableRawPointer!
//
//        public var xDelUser: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!
//    }

//    func sqlite3_rtree_query_callback(_ db: OpaquePointer!, _ zQueryFunc: UnsafePointer<CChar>!, _ xQueryFunc: (@convention(c) (UnsafeMutablePointer<sqlite3_rtree_query_info>?) -> Int32)!, _ pContext: UnsafeMutableRawPointer!, _ xDestructor: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!) -> Int32
//    struct sqlite3_rtree_query_info {
//
//        public init()
//
//        public init(pContext: UnsafeMutableRawPointer!, nParam: Int32, aParam: UnsafeMutablePointer<sqlite3_rtree_dbl>!, pUser: UnsafeMutableRawPointer!, xDelUser: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!, aCoord: UnsafeMutablePointer<sqlite3_rtree_dbl>!, anQueue: UnsafeMutablePointer<UInt32>!, nCoord: Int32, iLevel: Int32, mxLevel: Int32, iRowid: sqlite3_int64, rParentScore: sqlite3_rtree_dbl, eParentWithin: Int32, eWithin: Int32, rScore: sqlite3_rtree_dbl, apSqlParam: UnsafeMutablePointer<OpaquePointer?>!)
//
//        public var pContext: UnsafeMutableRawPointer!
//
//        public var nParam: Int32
//
//        public var aParam: UnsafeMutablePointer<sqlite3_rtree_dbl>!
//
//        public var pUser: UnsafeMutableRawPointer!
//
//        public var xDelUser: (@convention(c) (UnsafeMutableRawPointer?) -> Void)!
//
//        public var aCoord: UnsafeMutablePointer<sqlite3_rtree_dbl>!
//
//        public var anQueue: UnsafeMutablePointer<UInt32>!
//
//        public var nCoord: Int32
//
//        public var iLevel: Int32
//
//        public var mxLevel: Int32
//
//        public var iRowid: sqlite3_int64
//
//        public var rParentScore: sqlite3_rtree_dbl
//
//        public var eParentWithin: Int32
//
//        public var eWithin: Int32
//
//        public var rScore: sqlite3_rtree_dbl
//
//        public var apSqlParam: UnsafeMutablePointer<OpaquePointer?>!
//    }
    static var NOT_WITHIN: Int32 { get }
    static var PARTLY_WITHIN: Int32 { get }
    static var FULLY_WITHIN: Int32 { get }
//    typealias fts5_extension_function = @convention(c) (UnsafePointer<Fts5ExtensionApi>?, OpaquePointer?, OpaquePointer?, Int32, UnsafeMutablePointer<OpaquePointer?>?) -> Void
//    struct Fts5PhraseIter {
//
//        public init()
//
//        public init(a: UnsafePointer<UInt8>!, b: UnsafePointer<UInt8>!)
//
//        public var a: UnsafePointer<UInt8>!
//
//        public var b: UnsafePointer<UInt8>!
//    }
//    struct Fts5ExtensionApi {
//
//        public init()
//
//        public init(iVersion: Int32, xUserData: (@convention(c) (OpaquePointer?) -> UnsafeMutableRawPointer?)!, xColumnCount: (@convention(c) (OpaquePointer?) -> Int32)!, xRowCount: (@convention(c) (OpaquePointer?, UnsafeMutablePointer<sqlite3_int64>?) -> Int32)!, xColumnTotalSize: (@convention(c) (OpaquePointer?, Int32, UnsafeMutablePointer<sqlite3_int64>?) -> Int32)!, xTokenize: (@convention(c) (OpaquePointer?, UnsafePointer<CChar>?, Int32, UnsafeMutableRawPointer?, (@convention(c) (UnsafeMutableRawPointer?, Int32, UnsafePointer<CChar>?, Int32, Int32, Int32) -> Int32)?) -> Int32)!, xPhraseCount: (@convention(c) (OpaquePointer?) -> Int32)!, xPhraseSize: (@convention(c) (OpaquePointer?, Int32) -> Int32)!, xInstCount: (@convention(c) (OpaquePointer?, UnsafeMutablePointer<Int32>?) -> Int32)!, xInst: (@convention(c) (OpaquePointer?, Int32, UnsafeMutablePointer<Int32>?, UnsafeMutablePointer<Int32>?, UnsafeMutablePointer<Int32>?) -> Int32)!, xRowid: (@convention(c) (OpaquePointer?) -> sqlite3_int64)!, xColumnText: (@convention(c) (OpaquePointer?, Int32, UnsafeMutablePointer<UnsafePointer<CChar>?>?, UnsafeMutablePointer<Int32>?) -> Int32)!, xColumnSize: (@convention(c) (OpaquePointer?, Int32, UnsafeMutablePointer<Int32>?) -> Int32)!, xQueryPhrase: (@convention(c) (OpaquePointer?, Int32, UnsafeMutableRawPointer?, (@convention(c) (UnsafePointer<Fts5ExtensionApi>?, OpaquePointer?, UnsafeMutableRawPointer?) -> Int32)?) -> Int32)!, xSetAuxdata: (@convention(c) (OpaquePointer?, UnsafeMutableRawPointer?, (@convention(c) (UnsafeMutableRawPointer?) -> Void)?) -> Int32)!, xGetAuxdata: (@convention(c) (OpaquePointer?, Int32) -> UnsafeMutableRawPointer?)!, xPhraseFirst: (@convention(c) (OpaquePointer?, Int32, UnsafeMutablePointer<Fts5PhraseIter>?, UnsafeMutablePointer<Int32>?, UnsafeMutablePointer<Int32>?) -> Int32)!, xPhraseNext: (@convention(c) (OpaquePointer?, UnsafeMutablePointer<Fts5PhraseIter>?, UnsafeMutablePointer<Int32>?, UnsafeMutablePointer<Int32>?) -> Void)!, xPhraseFirstColumn: (@convention(c) (OpaquePointer?, Int32, UnsafeMutablePointer<Fts5PhraseIter>?, UnsafeMutablePointer<Int32>?) -> Int32)!, xPhraseNextColumn: (@convention(c) (OpaquePointer?, UnsafeMutablePointer<Fts5PhraseIter>?, UnsafeMutablePointer<Int32>?) -> Void)!)
//
//        public var iVersion: Int32
//
//        public var xUserData: (@convention(c) (OpaquePointer?) -> UnsafeMutableRawPointer?)!
//
//        public var xColumnCount: (@convention(c) (OpaquePointer?) -> Int32)!
//
//        public var xRowCount: (@convention(c) (OpaquePointer?, UnsafeMutablePointer<sqlite3_int64>?) -> Int32)!
//
//        public var xColumnTotalSize: (@convention(c) (OpaquePointer?, Int32, UnsafeMutablePointer<sqlite3_int64>?) -> Int32)!
//
//        public var xTokenize: (@convention(c) (OpaquePointer?, UnsafePointer<CChar>?, Int32, UnsafeMutableRawPointer?, (@convention(c) (UnsafeMutableRawPointer?, Int32, UnsafePointer<CChar>?, Int32, Int32, Int32) -> Int32)?) -> Int32)!
//
//        public var xPhraseCount: (@convention(c) (OpaquePointer?) -> Int32)!
//
//        public var xPhraseSize: (@convention(c) (OpaquePointer?, Int32) -> Int32)!
//
//        public var xInstCount: (@convention(c) (OpaquePointer?, UnsafeMutablePointer<Int32>?) -> Int32)!
//
//        public var xInst: (@convention(c) (OpaquePointer?, Int32, UnsafeMutablePointer<Int32>?, UnsafeMutablePointer<Int32>?, UnsafeMutablePointer<Int32>?) -> Int32)!
//
//        public var xRowid: (@convention(c) (OpaquePointer?) -> sqlite3_int64)!
//
//        public var xColumnText: (@convention(c) (OpaquePointer?, Int32, UnsafeMutablePointer<UnsafePointer<CChar>?>?, UnsafeMutablePointer<Int32>?) -> Int32)!
//
//        public var xColumnSize: (@convention(c) (OpaquePointer?, Int32, UnsafeMutablePointer<Int32>?) -> Int32)!
//
//        public var xQueryPhrase: (@convention(c) (OpaquePointer?, Int32, UnsafeMutableRawPointer?, (@convention(c) (UnsafePointer<Fts5ExtensionApi>?, OpaquePointer?, UnsafeMutableRawPointer?) -> Int32)?) -> Int32)!
//
//        public var xSetAuxdata: (@convention(c) (OpaquePointer?, UnsafeMutableRawPointer?, (@convention(c) (UnsafeMutableRawPointer?) -> Void)?) -> Int32)!
//
//        public var xGetAuxdata: (@convention(c) (OpaquePointer?, Int32) -> UnsafeMutableRawPointer?)!
//
//        public var xPhraseFirst: (@convention(c) (OpaquePointer?, Int32, UnsafeMutablePointer<Fts5PhraseIter>?, UnsafeMutablePointer<Int32>?, UnsafeMutablePointer<Int32>?) -> Int32)!
//
//        public var xPhraseNext: (@convention(c) (OpaquePointer?, UnsafeMutablePointer<Fts5PhraseIter>?, UnsafeMutablePointer<Int32>?, UnsafeMutablePointer<Int32>?) -> Void)!
//
//        public var xPhraseFirstColumn: (@convention(c) (OpaquePointer?, Int32, UnsafeMutablePointer<Fts5PhraseIter>?, UnsafeMutablePointer<Int32>?) -> Int32)!
//
//        public var xPhraseNextColumn: (@convention(c) (OpaquePointer?, UnsafeMutablePointer<Fts5PhraseIter>?, UnsafeMutablePointer<Int32>?) -> Void)!
//    }
//    struct fts5_tokenizer {
//
//        public init()
//
//        public init(xCreate: (@convention(c) (UnsafeMutableRawPointer?, UnsafeMutablePointer<UnsafePointer<CChar>?>?, Int32, UnsafeMutablePointer<OpaquePointer?>?) -> Int32)!, xDelete: (@convention(c) (OpaquePointer?) -> Void)!, xTokenize: (@convention(c) (OpaquePointer?, UnsafeMutableRawPointer?, Int32, UnsafePointer<CChar>?, Int32, (@convention(c) (UnsafeMutableRawPointer?, Int32, UnsafePointer<CChar>?, Int32, Int32, Int32) -> Int32)?) -> Int32)!)
//
//        public var xCreate: (@convention(c) (UnsafeMutableRawPointer?, UnsafeMutablePointer<UnsafePointer<CChar>?>?, Int32, UnsafeMutablePointer<OpaquePointer?>?) -> Int32)!
//
//        public var xDelete: (@convention(c) (OpaquePointer?) -> Void)!
//
//        public var xTokenize: (@convention(c) (OpaquePointer?, UnsafeMutableRawPointer?, Int32, UnsafePointer<CChar>?, Int32, (@convention(c) (UnsafeMutableRawPointer?, Int32, UnsafePointer<CChar>?, Int32, Int32, Int32) -> Int32)?) -> Int32)!
//    }
    static var FTS5_TOKENIZE_QUERY: Int32 { get }
    static var FTS5_TOKENIZE_PREFIX: Int32 { get }
    static var FTS5_TOKENIZE_DOCUMENT: Int32 { get }
    static var FTS5_TOKENIZE_AUX: Int32 { get }
    static var FTS5_TOKEN_COLOCATED: Int32 { get }
//    struct fts5_api {
//
//        public init()
//
//        public init(iVersion: Int32, xCreateTokenizer: (@convention(c) (UnsafeMutablePointer<fts5_api>?, UnsafePointer<CChar>?, UnsafeMutableRawPointer?, UnsafeMutablePointer<fts5_tokenizer>?, (@convention(c) (UnsafeMutableRawPointer?) -> Void)?) -> Int32)!, xFindTokenizer: (@convention(c) (UnsafeMutablePointer<fts5_api>?, UnsafePointer<CChar>?, UnsafeMutablePointer<UnsafeMutableRawPointer?>?, UnsafeMutablePointer<fts5_tokenizer>?) -> Int32)!, xCreateFunction: (@convention(c) (UnsafeMutablePointer<fts5_api>?, UnsafePointer<CChar>?, UnsafeMutableRawPointer?, fts5_extension_function?, (@convention(c) (UnsafeMutableRawPointer?) -> Void)?) -> Int32)!)
//
//        public var iVersion: Int32
//
//        public var xCreateTokenizer: (@convention(c) (UnsafeMutablePointer<fts5_api>?, UnsafePointer<CChar>?, UnsafeMutableRawPointer?, UnsafeMutablePointer<fts5_tokenizer>?, (@convention(c) (UnsafeMutableRawPointer?) -> Void)?) -> Int32)!
//
//        public var xFindTokenizer: (@convention(c) (UnsafeMutablePointer<fts5_api>?, UnsafePointer<CChar>?, UnsafeMutablePointer<UnsafeMutableRawPointer?>?, UnsafeMutablePointer<fts5_tokenizer>?) -> Int32)!
//
//        public var xCreateFunction: (@convention(c) (UnsafeMutablePointer<fts5_api>?, UnsafePointer<CChar>?, UnsafeMutableRawPointer?, fts5_extension_function?, (@convention(c) (UnsafeMutableRawPointer?) -> Void)?) -> Int32)!
//    }

}


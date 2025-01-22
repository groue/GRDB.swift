#if !GRDB_SQLITE_INLINE
// Default protocol conformances for SQLiteAPI

#if SWIFT_PACKAGE
import GRDBSQLite
public typealias DefaultSQLiteInterface = SystemSQLiteInterface
#elseif GRDBCIPHER
import SQLCipher
public typealias DefaultSQLiteInterface = SQLCipherInterface
#elseif !GRDBCUSTOMSQLITE && !GRDBCIPHER
import SQLite3
public typealias DefaultSQLiteInterface = CustomSQLiteInterface
#endif

import Foundation

// Some top-level constants and functions that would be tricky to access through retroactive SQLiteAPI conformance

public let SQLITE_OK = DefaultSQLiteInterface.SQLITE_OK
public let SQLITE_ERROR = DefaultSQLiteInterface.SQLITE_ERROR

public let SQLITE_NULL = DefaultSQLiteInterface.SQLITE_NULL
public let SQLITE_INTEGER = DefaultSQLiteInterface.SQLITE_INTEGER
public let SQLITE_FLOAT = DefaultSQLiteInterface.SQLITE_FLOAT
public let SQLITE_TEXT = DefaultSQLiteInterface.SQLITE_TEXT
public let SQLITE_BLOB = DefaultSQLiteInterface.SQLITE_BLOB

public func sqlite3_column_type(_ p0: OpaquePointer!, _ iCol: Int32) -> Int32 { DefaultSQLiteInterface.sqlite3_column_type(p0, iCol) }
public func sqlite3_value_type(_ p0: OpaquePointer!) -> Int32 { DefaultSQLiteInterface.sqlite3_value_type(p0) }
public func sqlite3_errmsg(_ ptr: OpaquePointer!) -> UnsafePointer<CChar>! { DefaultSQLiteInterface.sqlite3_errmsg(ptr) }
public func sqlite3_sql(_ pStmt: OpaquePointer!) -> UnsafePointer<CChar>! { DefaultSQLiteInterface.sqlite3_sql(pStmt) }
public func sqlite3_db_handle(_ ptr: OpaquePointer!) -> OpaquePointer! { DefaultSQLiteInterface.sqlite3_db_handle(ptr) }
public func sqlite3_prepare_v3(_ db: OpaquePointer!, _ zSql: UnsafePointer<CChar>!, _ nByte: Int32, _ prepFlags: UInt32, _ ppStmt: UnsafeMutablePointer<OpaquePointer?>!, _ pzTail: UnsafeMutablePointer<UnsafePointer<CChar>?>!) -> Int32 { DefaultSQLiteInterface.sqlite3_prepare_v3(db, zSql, nByte, prepFlags, ppStmt, pzTail) }
public func sqlite3_column_double(_ p0: OpaquePointer!, _ iCol: Int32) -> Double { DefaultSQLiteInterface.sqlite3_column_double(p0, iCol) }
public func sqlite3_expanded_sql(_ pStmt: OpaquePointer!) -> UnsafeMutablePointer<CChar>! { DefaultSQLiteInterface.sqlite3_expanded_sql(pStmt) }
public func sqlite3_user_data(_ p0: OpaquePointer!) -> UnsafeMutableRawPointer! { DefaultSQLiteInterface.sqlite3_user_data(p0) }
public func sqlite3_libversion_number() -> Int32 { DefaultSQLiteInterface.sqlite3_libversion_number() }
public func sqlite3_column_blob(_ p0: OpaquePointer!, _ iCol: Int32) -> UnsafeRawPointer! { DefaultSQLiteInterface.sqlite3_column_blob(p0, iCol) }


// Retroactive protocol conformances to cover the rest of the `sqlite3_` API usage.

extension Configuration : SQLiteAPI { public typealias SQLI = DefaultSQLiteInterface }
extension Database : SQLiteAPI { public typealias SQLI = DefaultSQLiteInterface }
extension Row : SQLiteAPI { public typealias SQLI = DefaultSQLiteInterface }
extension Statement : SQLiteAPI { public typealias SQLI = DefaultSQLiteInterface }
extension StatementRowImpl : SQLiteAPI { public typealias SQLI = DefaultSQLiteInterface }
extension StatementCopyRowImpl : SQLiteAPI { public typealias SQLI = DefaultSQLiteInterface }
extension SQLiteStatementRowImpl : SQLiteAPI { public typealias SQLI = DefaultSQLiteInterface }
extension StatementAuthorizer : SQLiteAPI { public typealias SQLI = DefaultSQLiteInterface }
extension ResultCode : SQLiteAPI { public typealias SQLI = DefaultSQLiteInterface }
extension DatabaseValue : SQLiteAPI { public typealias SQLI = DefaultSQLiteInterface }
extension DatabaseFunction : SQLiteAPI { public typealias SQLI = DefaultSQLiteInterface }
extension DatabaseFunction.Kind : SQLiteAPI { public typealias SQLI = DefaultSQLiteInterface }
extension DatabaseCollation : SQLiteAPI { public typealias SQLI = DefaultSQLiteInterface }
extension DatabaseDateComponents : SQLiteAPI { public typealias SQLI = DefaultSQLiteInterface }
extension DatabaseDataDecodingStrategy : SQLiteAPI { public typealias SQLI = DefaultSQLiteInterface }
extension LineDumpFormat : SQLiteAPI { public typealias SQLI = DefaultSQLiteInterface }
extension ListDumpFormat : SQLiteAPI { public typealias SQLI = DefaultSQLiteInterface }
extension JSONDumpFormat : SQLiteAPI { public typealias SQLI = DefaultSQLiteInterface }
extension QuoteDumpFormat : SQLiteAPI { public typealias SQLI = DefaultSQLiteInterface }
extension DebugDumpFormat : SQLiteAPI { public typealias SQLI = DefaultSQLiteInterface }
extension DatabaseObservationBroker : SQLiteAPI { public typealias SQLI = DefaultSQLiteInterface }
extension DatabaseDateDecodingStrategy : SQLiteAPI { public typealias SQLI = DefaultSQLiteInterface }
extension RowDecodingContext : SQLiteAPI { public typealias SQLI = DefaultSQLiteInterface }
extension StatementCache : SQLiteAPI { public typealias SQLI = DefaultSQLiteInterface }

extension String : SQLiteAPI { public typealias SQLI = DefaultSQLiteInterface }
extension Data : SQLiteAPI { public typealias SQLI = DefaultSQLiteInterface }
extension Date : SQLiteAPI { public typealias SQLI = DefaultSQLiteInterface }
extension UUID : SQLiteAPI { public typealias SQLI = DefaultSQLiteInterface }
extension Bool : SQLiteAPI { public typealias SQLI = DefaultSQLiteInterface }
extension Float : SQLiteAPI { public typealias SQLI = DefaultSQLiteInterface }
extension Double : SQLiteAPI { public typealias SQLI = DefaultSQLiteInterface }
extension Int : SQLiteAPI { public typealias SQLI = DefaultSQLiteInterface }
extension Int8 : SQLiteAPI { public typealias SQLI = DefaultSQLiteInterface }
extension Int16 : SQLiteAPI { public typealias SQLI = DefaultSQLiteInterface }
extension Int32 : SQLiteAPI { public typealias SQLI = DefaultSQLiteInterface }
extension Int64 : SQLiteAPI { public typealias SQLI = DefaultSQLiteInterface }
extension UInt : SQLiteAPI { public typealias SQLI = DefaultSQLiteInterface }
extension UInt8 : SQLiteAPI { public typealias SQLI = DefaultSQLiteInterface }
extension UInt16 : SQLiteAPI { public typealias SQLI = DefaultSQLiteInterface }
extension UInt32 : SQLiteAPI { public typealias SQLI = DefaultSQLiteInterface }
extension UInt64 : SQLiteAPI { public typealias SQLI = DefaultSQLiteInterface }
extension Decimal : SQLiteAPI { public typealias SQLI = DefaultSQLiteInterface }
extension Optional : SQLiteAPI { public typealias SQLI = DefaultSQLiteInterface }


//extension XXX : SQLiteAPI { public typealias SQLI = DefaultSQLiteInterface }

//extension FTS5 : SQLiteAPI { public typealias SQLI = DefaultSQLiteInterface }
//extension FTS5Tokenization : SQLiteAPI { public typealias SQLI = DefaultSQLiteInterface }
//extension FTS5TokenFlags : SQLiteAPI { public typealias SQLI = DefaultSQLiteInterface }
//extension FTS5WrapperTokenizer : SQLiteAPI { public typealias SQLI = DefaultSQLiteInterface }


#endif


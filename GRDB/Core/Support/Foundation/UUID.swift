import Foundation
#if SWIFT_PACKAGE
import CSQLite
#elseif GRDBCIPHER
import SQLCipher
#elseif !GRDBCUSTOMSQLITE && !GRDBCIPHER
import SQLite3
#endif

#if !os(Linux)
/// NSUUID adopts DatabaseValueConvertible
extension NSUUID: DatabaseValueConvertible {
    public var databaseValue: DatabaseValue {
        var uuidBytes = ContiguousArray(repeating: UInt8(0), count: 16)
        return uuidBytes.withUnsafeMutableBufferPointer { buffer in
            getBytes(buffer.baseAddress!)
            return NSData(bytes: buffer.baseAddress, length: 16).databaseValue
        }
    }
    
    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Self? {
        switch dbValue.storage {
        case .blob(let data) where data.count == 16:
            #if swift(>=5.0)
            return data.withUnsafeBytes {
                self.init(uuidBytes: $0.bindMemory(to: UInt8.self).baseAddress)
            }
            #else
            return data.withUnsafeBytes {
                self.init(uuidBytes: $0)
            }
            #endif
        case .string(let string):
            return self.init(uuidString: string)
        default:
            return nil
        }
    }
}
#endif

/// UUID adopts DatabaseValueConvertible
extension UUID: DatabaseValueConvertible {
    public var databaseValue: DatabaseValue {
        return withUnsafeBytes(of: uuid) {
            Data(bytes: $0.baseAddress!, count: $0.count).databaseValue
        }
    }
    
    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> UUID? {
        switch dbValue.storage {
        case .blob(let data) where data.count == 16:
            #if swift(>=5.0)
            return data.withUnsafeBytes {
                UUID(uuid: $0.bindMemory(to: uuid_t.self).first!)
            }
            #else
            return data.withUnsafeBytes {
                UUID(uuid: $0.pointee)
            }
            #endif
        case .string(let string):
            return UUID(uuidString: string)
        default:
            return nil
        }
    }
}

extension UUID: StatementColumnConvertible {
    @inlinable
    public init(sqliteStatement: SQLiteStatement, index: Int32) {
        switch sqlite3_column_type(sqliteStatement, index) {
        case SQLITE_TEXT:
            let string = String(cString: sqlite3_column_text(sqliteStatement, index)!)
            guard let uuid = UUID(uuidString: string) else {
                fatalConversionError(to: UUID.self, sqliteStatement: sqliteStatement, index: index)
            }
            self.init(uuid: uuid.uuid)
        case SQLITE_BLOB:
            guard sqlite3_column_bytes(sqliteStatement, index) == 16,
                let blob = sqlite3_column_blob(sqliteStatement, index) else
            {
                fatalConversionError(to: UUID.self, sqliteStatement: sqliteStatement, index: index)
            }
            self.init(uuid: blob.assumingMemoryBound(to: uuid_t.self).pointee)
        default:
            fatalConversionError(to: UUID.self, sqliteStatement: sqliteStatement, index: index)
        }
    }
}

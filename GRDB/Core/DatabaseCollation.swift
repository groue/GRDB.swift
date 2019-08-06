import Foundation
#if SWIFT_PACKAGE
import CSQLite
#elseif GRDBCIPHER
import SQLCipher
#elseif !GRDBCUSTOMSQLITE && !GRDBCIPHER
import SQLite3
#endif

/// A Collation is a string comparison function used by SQLite.
public final class DatabaseCollation {
    public let name: String
    let function: (Int32, UnsafeRawPointer?, Int32, UnsafeRawPointer?) -> ComparisonResult
    
    /// Creates a collation.
    ///
    ///     let collation = DatabaseCollation("localized_standard") { (string1, string2) in
    ///         return (string1 as NSString).localizedStandardCompare(string2)
    ///     }
    ///     db.add(collation: collation)
    ///     try db.execute(sql: "CREATE TABLE file (name TEXT COLLATE localized_standard")
    ///
    /// - parameters:
    ///     - name: The function name.
    ///     - function: A function that compares two strings.
    public init(_ name: String, function: @escaping (String, String) -> ComparisonResult) {
        self.name = name
        self.function = { (length1, buffer1, length2, buffer2) in
            // Buffers are not C strings: they do not end with \0.
            let string1 = String(
                bytesNoCopy: UnsafeMutableRawPointer(mutating: buffer1.unsafelyUnwrapped),
                length: Int(length1),
                encoding: .utf8,
                freeWhenDone: false)!
            let string2 = String(
                bytesNoCopy: UnsafeMutableRawPointer(mutating: buffer2.unsafelyUnwrapped),
                length: Int(length2),
                encoding: .utf8,
                freeWhenDone: false)!
            return function(string1, string2)
        }
    }
}

extension DatabaseCollation: Hashable {
    // Collation equality is based on the sqlite3_strnicmp SQLite function.
    // (see https://www.sqlite.org/c3ref/create_collation.html). Computing
    // a hash value that honors the Swift Hashable contract (value equality
    // implies hash equality) is thus non trivial. But it's not that
    // important, since this hashValue is only used when one adds
    // or removes a collation from a database connection.
    /// :nodoc:
    public func hash(into hasher: inout Hasher) {
        hasher.combine(0)
    }
    
    /// Two collations are equal if they share the same name (case insensitive)
    /// :nodoc:
    public static func == (lhs: DatabaseCollation, rhs: DatabaseCollation) -> Bool {
        // See https://www.sqlite.org/c3ref/create_collation.html
        return sqlite3_stricmp(lhs.name, rhs.name) == 0
    }
}

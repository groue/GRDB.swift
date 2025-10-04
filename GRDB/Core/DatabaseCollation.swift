// Import C SQLite functions
#if GRDBCIPHER // CocoaPods (SQLCipher subspec)
import SQLCipher
#elseif GRDBFRAMEWORK // GRDB.xcodeproj or CocoaPods (standard subspec)
import SQLite3
#elseif GRDBCUSTOMSQLITE // GRDBCustom Framework
// #elseif SomeTrait
// import ...
#else // Default SPM trait must be the default. It impossible to detect from Xcode.
import GRDBSQLite
#endif

import Foundation

/// `DatabaseCollation` is a custom string comparison function used by SQLite.
///
/// See also ``Database/CollationName``.
/// 
/// Related SQLite documentation: <https://www.sqlite.org/datatype3.html#collating_sequences>
///
/// ## Topics
///
/// ### Creating a Custom Collation
///
/// - ``init(_:function:)``
/// - ``name``
///
/// ### Built-in Collations
///
/// - ``caseInsensitiveCompare``
/// - ``localizedCaseInsensitiveCompare``
/// - ``localizedCompare``
/// - ``localizedStandardCompare``
/// - ``unicodeCompare``
public final class DatabaseCollation: Identifiable, Sendable {
    /// The identifier of an SQLite collation.
    ///
    /// SQLite identifies collations by their name (case insensitive).
    public struct ID: Hashable {
        var name: String
        
        // Collation equality is based on the sqlite3_strnicmp SQLite function.
        // (see https://www.sqlite.org/c3ref/create_collation.html). Computing
        // a hash value that honors the Swift Hashable contract (value equality
        // implies hash equality) is thus non trivial. But it's not that
        // important, since this hashValue is only used when one adds
        // or removes a collation from a database connection.
        public func hash(into hasher: inout Hasher) {
            hasher.combine(0)
        }
        
        /// Two collations are equal if they share the same name (case insensitive)
        public static func == (lhs: Self, rhs: Self) -> Bool {
            // See <https://www.sqlite.org/c3ref/create_collation.html>
            return sqlite3_stricmp(lhs.name, rhs.name) == 0
        }
    }
    
    /// Feeds the `xCompare` parameter of sqlite3_create_collation_v2
    /// <https://www.sqlite.org/c3ref/create_collation.html>
    typealias XCompare = @Sendable (
        _ length1: CInt,
        _ buffer1: UnsafeRawPointer,
        _ length2: CInt,
        _ buffer2: UnsafeRawPointer
    ) -> CInt
    
    /// The identifier of the collation.
    public var id: ID { ID(name: name) }
    
    /// The name of the collation.
    public let name: String
    let xCompare: XCompare
    
    /// Creates a collation.
    ///
    /// For example:
    ///
    /// ```swift
    /// let collation = DatabaseCollation("localized_standard") { (string1, string2) in
    ///     return (string1 as NSString).localizedStandardCompare(string2)
    /// }
    /// db.add(collation: collation)
    /// try db.execute(sql: "CREATE TABLE file (name TEXT COLLATE localized_standard")
    /// ```
    ///
    /// - parameters:
    ///     - name: The collation name.
    ///     - function: A function that compares two strings.
    public convenience init(_ name: String, function: @escaping @Sendable (String, String) -> ComparisonResult) {
        self.init(name, xCompare: { (length1, buffer1, length2, buffer2) in
            let string1 = String(decoding: UnsafeRawBufferPointer(start: buffer1, count: Int(length1)), as: UTF8.self)
            let string2 = String(decoding: UnsafeRawBufferPointer(start: buffer2, count: Int(length2)), as: UTF8.self)
            return CInt(function(string1, string2).rawValue)
        })
    }
    
    init(_ name: String, xCompare: @escaping XCompare) {
        self.name = name
        self.xCompare = xCompare
    }
}

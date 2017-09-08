import Foundation

// MARK: - Public

extension String {
    /// Returns the receiver, quoted for safe insertion as an identifier in an
    /// SQL query.
    ///
    ///     db.execute("SELECT * FROM \(tableName.quotedDatabaseIdentifier)")
    public var quotedDatabaseIdentifier: String {
        // See https://www.sqlite.org/lang_keywords.html
        return "\"" + self + "\""
    }
}

/// Return as many question marks separated with commas as the *count* argument.
///
///     databaseQuestionMarks(count: 3) // "?,?,?"
public func databaseQuestionMarks(count: Int) -> String {
    return Array(repeating: "?", count: count).joined(separator: ",")
}

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// This protocol is an implementation detail of GRDB. Don't use it.
public protocol _OptionalProtocol {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    associatedtype _Wrapped
}

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// This conformance is an implementation detail of GRDB. Don't rely on it.
extension Optional : _OptionalProtocol {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    public typealias _Wrapped = Wrapped
}


// MARK: - Internal

/// Reserved for GRDB: do not use.
func GRDBPrecondition(_ condition: @autoclosure() -> Bool, _ message: @autoclosure() -> String = "", file: StaticString = #file, line: UInt = #line) {
    /// Custom precondition function which aims at solving
    /// https://bugs.swift.org/browse/SR-905 and
    /// https://github.com/groue/GRDB.swift/issues/37
    if !condition() {
        fatalError(message, file: file, line: line)
    }
}

// Workaround Swift inconvenience around factory methods of non-final classes
func cast<T, U>(_ value: T) -> U? {
    return value as? U
}

extension Array {
    /// Removes the first object that matches *predicate*.
    mutating func removeFirst(_ predicate: (Element) throws -> Bool) rethrows {
        if let index = try index(where: predicate) {
            remove(at: index)
        }
    }
}


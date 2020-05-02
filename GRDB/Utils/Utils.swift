import Foundation

// MARK: - Public

extension String {
    /// Returns the receiver, quoted for safe insertion as an identifier in an
    /// SQL query.
    ///
    ///     db.execute(sql: "SELECT * FROM \(tableName.quotedDatabaseIdentifier)")
    @inlinable public var quotedDatabaseIdentifier: String {
        // See https://www.sqlite.org/lang_keywords.html
        return "\"\(self)\""
    }
}

/// Return as many question marks separated with commas as the *count* argument.
///
///     databaseQuestionMarks(count: 3) // "?,?,?"
@inlinable
public func databaseQuestionMarks(count: Int) -> String {
    repeatElement("?", count: count).joined(separator: ",")
}

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// This protocol is an implementation detail of GRDB. Don't use it.
///
/// :nodoc:
public protocol _OptionalProtocol {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    associatedtype Wrapped
}

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// This conformance is an implementation detail of GRDB. Don't rely on it.
///
/// :nodoc:
extension Optional: _OptionalProtocol { }


// MARK: - Internal

/// Reserved for GRDB: do not use.
@inlinable
func GRDBPrecondition(
    _ condition: @autoclosure() -> Bool,
    _ message: @autoclosure() -> String = "",
    file: StaticString = #file,
    line: UInt = #line)
{
    /// Custom precondition function which aims at solving
    /// https://bugs.swift.org/browse/SR-905 and
    /// https://github.com/groue/GRDB.swift/issues/37
    if !condition() {
        fatalError(message(), file: file, line: line)
    }
}

// Workaround Swift inconvenience around factory methods of non-final classes
func cast<T, U>(_ value: T) -> U? {
    value as? U
}

extension RangeReplaceableCollection {
    /// Removes the first object that matches *predicate*.
    mutating func removeFirst(where predicate: (Element) throws -> Bool) rethrows {
        if let index = try firstIndex(where: predicate) {
            remove(at: index)
        }
    }
}

extension Dictionary {
    /// Removes the first object that matches *predicate*.
    mutating func removeFirst(where predicate: (Element) throws -> Bool) rethrows {
        if let index = try firstIndex(where: predicate) {
            remove(at: index)
        }
    }
}

extension DispatchQueue {
    private static var mainKey: DispatchSpecificKey<()> = {
        let key = DispatchSpecificKey<()>()
        DispatchQueue.main.setSpecific(key: key, value: ())
        return key
    }()
    
    static var isMain: Bool {
        DispatchQueue.getSpecific(key: mainKey) != nil
    }
}

extension Sequence {
    @inlinable
    func countElements(where predicate: (Element) throws -> Bool) rethrows -> Int {
        var count = 0
        for e in self where try predicate(e) {
            count += 1
        }
        return count
    }
}

/// Makes sure the `finally` function is executed even if `execute` throws, and
/// rethrows the eventual first thrown error.
///
/// Usage:
///
///     try setup()
///     try throwingFirstError(
///         execute: work,
///         finally: cleanup)
@inline(__always)
func throwingFirstError<T>(execute: () throws -> T, finally: () throws -> Void) throws -> T {
    var result: T?
    var firstError: Error?
    do {
        result = try execute()
    } catch {
        firstError = error
    }
    do {
        try finally()
    } catch {
        if firstError == nil {
            firstError = error
        }
    }
    if let firstError = firstError {
        throw firstError
    }
    return result!
}

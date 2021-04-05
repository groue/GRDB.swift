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

/// This protocol is an implementation detail of GRDB. Don't use it.
///
/// :nodoc:
public protocol _OptionalProtocol {
    associatedtype Wrapped
}

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

@inlinable
func fatalError<E: Error>(_ error: E) -> Never {
    try! { throw error }()
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

struct PrintOutputStream: TextOutputStream {
    func write(_ string: String) {
        Swift.print(string)
    }
}

/// Concatenates two functions
func concat(_ rhs: (() -> Void)?, _ lhs: (() -> Void)?) -> (() -> Void)? {
    switch (rhs, lhs) {
    case let (rhs, nil):
        return rhs
    case let (nil, lhs):
        return lhs
    case let (rhs?, lhs?):
        return {
            rhs()
            lhs()
        }
    }
}

/// Concatenates two functions
func concat<T>(_ rhs: ((T) -> Void)?, _ lhs: ((T) -> Void)?) -> ((T) -> Void)? {
    switch (rhs, lhs) {
    case let (rhs, nil):
        return rhs
    case let (nil, lhs):
        return lhs
    case let (rhs?, lhs?):
        return {
            rhs($0)
            lhs($0)
        }
    }
}

extension NSRecursiveLock {
    @inlinable
    @inline(__always)
    func synchronized<T>(
        _ message: @autoclosure () -> String = #function,
        _ block: () throws -> T)
    rethrows -> T
    {
        lock()
        defer { unlock() }
        return try block()
    }
    
    // // Verbose version which helps understanding locking bugs
    // func synchronized<T>(_ message: @autoclosure () -> String = "", _ block: () throws -> T) rethrows -> T {
    //     let queueName = String(validatingUTF8: __dispatch_queue_get_label(nil))
    //     print("\(queueName ?? "n/d"): \(message()) acquiring \(self)")
    //     lock()
    //     print("\(queueName ?? "n/d"): \(message()) acquired \(self)")
    //     defer {
    //         print("\(queueName ?? "n/d"): \(message()) releasing \(self)")
    //         unlock()
    //         print("\(queueName ?? "n/d"): \(message()) released \(self)")
    //     }
    //     return try block()
    // }
    
    /// Performs the side effect outside of the synchronized block. This allows
    /// avoiding deadlocks, when the side effect feedbacks.
    @inlinable
    @inline(__always)
    func synchronized(
        _ message: @autoclosure () -> String = #function,
        _ block: (inout (() -> Void)?) -> Void)
    {
        var sideEffect: (() -> Void)?
        synchronized(message()) { block(&sideEffect) }
        sideEffect?()
    }
}

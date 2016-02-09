import Foundation


// MARK: - Public

extension String {
    /// Returns the receiver, quoted for safe insertion as an identifier in an
    /// SQL query.
    ///
    ///     db.execute("SELECT * FROM \(tableName.quotedDatabaseIdentifier)")
    public var quotedDatabaseIdentifier: String {
        // See https://www.sqlite.org/lang_keywords.html
        return "\"\(self)\""
    }
}

/// Return as many question marks separated with commas as the *count* argument.
///
///     databaseQuestionMarks(count: 3) // "?,?,?"
public func databaseQuestionMarks(count count: Int) -> String {
    return Array(count: count, repeatedValue: "?").joinWithSeparator(",")
}


// MARK: - Internal

let SQLITE_TRANSIENT = unsafeBitCast(COpaquePointer(bitPattern: -1), sqlite3_destructor_type.self)

/// A function declared as rethrows that synchronously executes a throwing
/// block in a dispatch_queue.
func dispatchSync<T>(queue: dispatch_queue_t, block: () throws -> T) rethrows -> T {
    func dispatchSyncImpl(queue: dispatch_queue_t, block: () throws -> T, block2: (ErrorType) throws -> Void) rethrows -> T {
        var result: T? = nil
        var blockError: ErrorType? = nil
        dispatch_sync(queue) {
            do {
                result = try block()
            } catch {
                blockError = error
            }
        }
        if let blockError = blockError {
            try block2(blockError)
        }
        return result!
    }
    return try dispatchSyncImpl(queue, block: block, block2: { throw $0 })
}

extension Array {
    /// Removes the first object that matches *predicate*.
    mutating func removeFirst(@noescape predicate: (Element) throws -> Bool) rethrows {
        if let index = try indexOf(predicate) {
            removeAtIndex(index)
        }
    }
}

extension Dictionary {
    
    /// Create a dictionary with the keys and values in the given sequence.
    init<Sequence: SequenceType where Sequence.Generator.Element == Generator.Element>(_ sequence: Sequence) {
        self.init(minimumCapacity: sequence.underestimateCount())
        for (key, value) in sequence {
            self[key] = value
        }
    }
    
    /// Create a dictionary from keys and a value builder.
    init<Sequence: SequenceType where Sequence.Generator.Element == Key>(keys: Sequence, value: Key -> Value) {
        self.init(minimumCapacity: keys.underestimateCount())
        for key in keys {
            self[key] = value(key)
        }
    }
}

extension SequenceType where Generator.Element: Equatable {
    
    /// Filter out elements contained in *removedElements*.
    func removingElementsOf<S : SequenceType where S.Generator.Element == Self.Generator.Element>(removedElements: S) -> [Self.Generator.Element] {
        return filter { element in !removedElements.contains(element) }
    }
}

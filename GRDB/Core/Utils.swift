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


// MARK: - Internal

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


extension Dictionary {
    
    /// Creates a dictionary with the keys and values in the given sequence.
    init<Sequence: SequenceType where Sequence.Generator.Element == Generator.Element>(_ sequence: Sequence) {
        self.init(minimumCapacity: sequence.underestimateCount())
        for (key, value) in sequence {
            self[key] = value
        }
    }
    
    /// Creates a dictionary from keys and a value builder.
    init<Sequence: SequenceType where Sequence.Generator.Element == Key>(keys: Sequence, value: Key -> Value) {
        self.init(minimumCapacity: keys.underestimateCount())
        for key in keys {
            self[key] = value(key)
        }
    }
}

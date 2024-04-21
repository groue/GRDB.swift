extension Row {
    /// A collection of prefetched records associated to the given
    /// association key.
    ///
    /// Prefetched rows are defined by the ``JoinableRequest/including(all:)``
    /// request method.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Author: TableRecord, FetchableRecord {
    ///     static let books = hasMany(Book.self)
    /// }
    ///
    /// struct Book: TableRecord, FetchableRecord { }
    ///
    /// let request = Author.including(all: Author.books)
    /// let authorRow = try Row.fetchOne(db, request)!
    ///
    /// let author = try Author(row: authorRow)
    /// let books: [Book] = author["books"]
    /// ```
    ///
    /// See also: ``prefetchedRows``
    ///
    /// - parameter key: An association key.
    public subscript<Records>(_ key: String)
    -> Records
    where
        Records: RangeReplaceableCollection,
        Records.Element: FetchableRecord
    {
        try! decode(Records.self, forKey: key)
    }
    
    /// A set prefetched records associated to the given association key.
    ///
    /// Prefetched rows are defined by the ``JoinableRequest/including(all:)``
    /// request method.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Author: TableRecord, FetchableRecord {
    ///     static let books = hasMany(Book.self)
    /// }
    ///
    /// struct Book: TableRecord, FetchableRecord, Hashable { }
    ///
    /// let request = Author.including(all: Author.books)
    /// let authorRow = try Row.fetchOne(db, request)!
    ///
    /// let author = try Author(row: authorRow)
    /// let books: Set<Book> = author["books"]
    /// ```
    ///
    /// See also: ``prefetchedRows``
    ///
    /// - parameter key: An association key.
    public subscript<Record: FetchableRecord & Hashable>(_ key: String) -> Set<Record> {
        try! decode(Set<Record>.self, forKey: key)
    }
}

// MARK: - Support

extension Row {
    /// Returns the records encoded in the given prefetched rows.
    ///
    /// For example:
    ///
    ///     let request = Author.including(all: Author.books)
    ///     let row = try Row.fetchOne(db, request)!
    ///
    ///     try print(Author(row: row).name)
    ///     // Prints "Herman Melville"
    ///
    ///     let books: [Book] = row["books"]
    ///     print(books[0].title)
    ///     // Prints "Moby-Dick"
    func decode<Collection>(
        _ type: Collection.Type = Collection.self,
        forKey key: String)
    throws -> Collection
    where
        Collection: RangeReplaceableCollection,
        Collection.Element: FetchableRecord
    {
        guard let rows = prefetchedRows[key] else {
            let availableKeys = prefetchedRows.keys
            if availableKeys.isEmpty {
                throw RowDecodingError.keyNotFound(
                    .prefetchKey(key),
                    RowDecodingError.Context(
                        decodingContext: RowDecodingContext(row: self),
                        debugDescription: """
                        key for prefetched rows not found: \(String(reflecting: key))
                        """))
            } else {
                throw RowDecodingError.keyNotFound(
                    .prefetchKey(key),
                    RowDecodingError.Context(
                        decodingContext: RowDecodingContext(row: self),
                        debugDescription: """
                        key for prefetched rows not found: \(String(reflecting: key)) \
                        - available keys: \(availableKeys.sorted())
                        """))
            }
        }
        
        var collection = Collection()
        collection.reserveCapacity(rows.count)
        for row in rows {
            try collection.append(Collection.Element(row: row))
        }
        return collection
    }
    
    /// Returns the set of records encoded in the given prefetched rows.
    ///
    /// For example:
    ///
    ///     let request = Author.including(all: Author.books)
    ///     let row = try Row.fetchOne(db, request)!
    ///
    ///     try print(Author(row: row).name)
    ///     // Prints "Herman Melville"
    ///
    ///     let books: Set<Book> = row["books"]
    ///     print(books.first!.title)
    ///     // Prints "Moby-Dick"
    func decode<Record: FetchableRecord & Hashable>(
        _ type: Set<Record>.Type = Set<Record>.self,
        forKey key: String)
    throws -> Set<Record>
    {
        guard let rows = prefetchedRows[key] else {
            let availableKeys = prefetchedRows.keys
            if availableKeys.isEmpty {
                throw RowDecodingError.keyNotFound(
                    .prefetchKey(key),
                    RowDecodingError.Context(
                        decodingContext: RowDecodingContext(row: self),
                        debugDescription: """
                        key for prefetched rows not found: \(String(reflecting: key))
                        """))
            } else {
                throw RowDecodingError.keyNotFound(
                    .prefetchKey(key),
                    RowDecodingError.Context(
                        decodingContext: RowDecodingContext(row: self),
                        debugDescription: """
                        key for prefetched rows not found: \(String(reflecting: key)) \
                        - available keys: \(availableKeys.sorted())
                        """))
            }
        }
        var set = Set<Record>(minimumCapacity: rows.count)
        for row in rows {
            try set.insert(Record(row: row))
        }
        return set
    }
}

// MARK: - Row.PrefetchedRowsView

extension Row {
    struct Prefetch: Equatable {
        // Nil for intermediate associations
        var rows: [Row]?
        // OrderedDictionary so that breadth-first search gives a consistent result
        // (we preserve the ordering of associations in the request)
        var prefetches: OrderedDictionary<String, Prefetch>
    }
    
    /// A view on the prefetched associated rows.
    ///
    /// See ``Row/prefetchedRows`` for more information.
    public struct PrefetchedRowsView: Equatable {
        // OrderedDictionary so that breadth-first search gives a consistent result
        // (we preserve the ordering of associations in the request)
        var prefetches: OrderedDictionary<String, Prefetch> = [:]
        
        /// A boolean value indicating if there is no prefetched
        /// associated rows.
        public var isEmpty: Bool {
            prefetches.isEmpty
        }
        
        /// The available association keys.
        ///
        /// Keys in the returned set can be used with ``subscript(_:)``.
        ///
        /// For example:
        ///
        /// ```swift
        /// struct Author: TableRecord {
        ///     static let books = hasMany(Book.self)
        /// }
        ///
        /// struct Book: TableRecord { }
        ///
        /// let request = Author.including(all: Author.books)
        /// let authorRow = try Row.fetchOne(db, request)!
        ///
        /// print(authorRow.prefetchedRows.keys)
        /// // Prints ["books"]
        ///
        /// let bookRows = authorRow.prefetchedRows["books"]!
        /// print(bookRows[0])
        /// // Prints [id:42, title:"Moby-Dick", authorId:1]
        /// print(bookRows[1])
        /// // Prints [id:57, title:"Pierre", authorId:1]
        /// ```
        public var keys: Set<String> {
            var result: Set<String> = []
            var fifo = Array(prefetches)
            while !fifo.isEmpty {
                let (prefetchKey, prefetch) = fifo.removeFirst()
                if prefetch.rows != nil {
                    result.insert(prefetchKey)
                }
                fifo.append(contentsOf: prefetch.prefetches)
            }
            return result
        }
        
        /// The prefetched rows associated with the given association key.
        ///
        /// The result is nil if the key is not available.
        ///
        /// See ``Row/prefetchedRows`` for more information.
        ///
        /// - parameter key: An association key.
        public subscript(_ key: String) -> [Row]? {
            var fifo = Array(prefetches)
            while !fifo.isEmpty {
                let (prefetchKey, prefetch) = fifo.removeFirst()
                if prefetchKey == key,
                   let rows = prefetch.rows // nil for "through" associations
                {
                    return rows
                }
                fifo.append(contentsOf: prefetch.prefetches)
            }
            return nil
        }
        
        mutating func setRows(_ rows: [Row], forKeyPath keyPath: [String]) {
            prefetches.setRows(rows, forKeyPath: keyPath)
        }
    }
}

extension OrderedDictionary<String, Row.Prefetch> {
    fileprivate mutating func setRows(_ rows: [Row], forKeyPath keyPath: [String]) {
        var keyPath = keyPath
        let key = keyPath.removeFirst()
        if keyPath.isEmpty {
            self[key, default: Row.Prefetch(rows: nil, prefetches: [:])].rows = rows
        } else {
            self[key, default: Row.Prefetch(rows: nil, prefetches: [:])].prefetches.setRows(rows, forKeyPath: keyPath)
        }
    }
}

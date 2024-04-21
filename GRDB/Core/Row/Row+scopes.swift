extension Row {
    /// A view on the scopes defined by row adapters.
    ///
    /// The returned object provides an access to all available scopes in
    /// the row.
    ///
    /// Row scopes can be defined manually, with ``ScopeAdapter``.
    /// The ``JoinableRequest/including(required:)`` and
    /// ``JoinableRequest/including(optional:)`` request methods define scopes
    /// named after the key of included associations between record types.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Book: TableRecord {
    ///     static let author = belongsTo(Author.self)
    /// }
    ///
    /// struct Author: TableRecord {
    ///     static let country = belongsTo(Country.self)
    /// }
    ///
    /// struct Country: TableRecord { }
    ///
    /// // Fetch a book, with its author, and the country of its author.
    /// let request = Book
    ///     .including(required: Book.author
    ///         .including(required: Author.country))
    /// let bookRow = try Row.fetchOne(db, request)!
    ///
    /// print(bookRow)
    /// // Prints [id:42, title:"Moby-Dick", authorId:1]
    ///
    /// let authorRow = bookRow.scopes["author"]!
    /// print(authorRow)
    /// // Prints [id:1, name:"Herman Melville", countryCode: "US"]
    ///
    /// let countryRow = authorRow.scopes["country"]!
    /// print(countryRow)
    /// // Prints [code:"US" name:"United States of America"]
    /// ```
    ///
    /// See also ``scopesTree``.
    public var scopes: ScopesView {
        impl.scopes(prefetchedRows: prefetchedRows)
    }
    
    /// A view on the scopes tree defined by row adapters.
    ///
    /// The returned object provides an access to all available scopes in
    /// the row, recursively. For any given scope identifier, a breadth-first
    /// search is performed.
    ///
    /// Row scopes can be defined manually, with ``ScopeAdapter``.
    /// The ``JoinableRequest/including(required:)`` and
    /// ``JoinableRequest/including(optional:)`` request methods define scopes
    /// named after the key of included associations between record types.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Book: TableRecord {
    ///     static let author = belongsTo(Author.self)
    /// }
    ///
    /// struct Author: TableRecord {
    ///     static let country = belongsTo(Country.self)
    /// }
    ///
    /// struct Country: TableRecord { }
    ///
    /// // Fetch a book, with its author, and the country of its author.
    /// let request = Book
    ///     .including(required: Book.author
    ///         .including(required: Author.country))
    /// let bookRow = try Row.fetchOne(db, request)!
    ///
    /// print(bookRow)
    /// // Prints [id:42, title:"Moby-Dick", authorId:1]
    ///
    /// print(bookRow.scopesTree["author"])
    /// // Prints [id:1, name:"Herman Melville", countryCode: "US"]
    ///
    /// print(bookRow.scopesTree["country"])
    /// // Prints [code:"US" name:"United States of America"]
    /// ```
    ///
    /// See also ``scopes``.
    public var scopesTree: ScopesTreeView {
        ScopesTreeView(scopes: scopes)
    }
    
    /// The row, without any scope of prefetched rows.
    ///
    /// This property is useful when testing the content of rows fetched from
    /// joined requests.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Book: TableRecord {
    ///     static let author = belongsTo(Author.self)
    ///     static let awards = hasMany(Award.self)
    /// }
    ///
    /// struct Author: TableRecord { }
    /// struct Award: TableRecord { }
    ///
    /// // Fetch a book, with its author, and its awards.
    /// let request = Book
    ///     .including(required: Book.author)
    ///     .including(all: Book.awards)
    /// let bookRow = try Row.fetchOne(db, request)!
    ///
    /// // Failure
    /// XCTAssertEqual(bookRow, ["id":42, "title":"Moby-Dick", "authorId":1])
    ///
    /// // Success
    /// XCTAssertEqual(bookRow.unscoped, ["id":42, "title":"Moby-Dick", "authorId":1])
    /// ```
    public var unscoped: Row {
        var row = impl.unscopedRow(self)
        
        // Remove prefetchedRows
        if row.prefetchedRows.isEmpty == false {
            // Make sure we build another Row instance
            row = Row(impl: row.copy().impl)
            assert(row !== self)
            assert(row.prefetchedRows.isEmpty)
        }
        return row
    }
    
    /// The raw row fetched from the database.
    ///
    /// This property is useful when debugging the content of rows fetched from
    /// joined requests.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Book: TableRecord {
    ///     static let author = belongsTo(Author.self)
    /// }
    ///
    /// struct Author: TableRecord { }
    ///
    /// // SELECT book.*, author.*
    /// // FROM book
    /// // JOIN author ON author.id = book.authorId
    /// let request = Book.including(required: Book.author)
    /// let bookRow = try Row.fetchOne(db, request)!
    ///
    /// print(bookRow)
    /// // Prints [id:42, title:"Moby-Dick", authorId:1]
    ///
    /// print(bookRow.unadapted)
    /// // Prints [id:42, title:"Moby-Dick", authorId:1, id:1, name:"Herman Melville"]
    /// ```
    public var unadapted: Row {
        impl.unadaptedRow(self)
    }
}

// MARK: - Records

extension Row {
    /// The record associated to the given scope.
    ///
    /// Row scopes can be defined manually, with ``ScopeAdapter``.
    /// The ``JoinableRequest/including(required:)`` and
    /// ``JoinableRequest/including(optional:)`` request methods define scopes
    /// named after the key of included associations between record types.
    ///
    /// A breadth-first search is performed in all available scopes in the row,
    /// recursively.
    ///
    /// A fatal error is raised if the scope is not available, or contains only
    /// `NULL` values.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Book: TableRecord, FetchableRecord {
    ///     static let author = belongsTo(Author.self)
    /// }
    ///
    /// struct Author: TableRecord, FetchableRecord {
    ///     static let country = belongsTo(Country.self)
    /// }
    ///
    /// struct Country: TableRecord, FetchableRecord { }
    ///
    /// // Fetch a book, with its author, and the country of its author.
    /// let request = Book
    ///     .including(required: Book.author
    ///         .including(required: Author.country))
    /// let bookRow = try Row.fetchOne(db, request)!
    ///
    /// let book = try Book(row: bookRow)
    /// let author: Author = bookRow["author"]
    /// let country: Country = bookRow["country"]
    /// ```
    ///
    /// See also: ``scopesTree``
    ///
    /// - parameter scope: A scope identifier.
    public subscript<Record: FetchableRecord>(_ scope: String) -> Record {
        try! decode(Record.self, forKey: scope)
    }
    
    /// The eventual record associated to the given scope.
    ///
    /// Row scopes can be defined manually, with ``ScopeAdapter``.
    /// The ``JoinableRequest/including(required:)`` and
    /// ``JoinableRequest/including(optional:)`` request methods define scopes
    /// named after the key of included associations between record types.
    ///
    /// A breadth-first search is performed in all available scopes in the row,
    /// recursively.
    ///
    /// The result is nil if the scope is not available, or contains only
    /// `NULL` values.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Book: TableRecord, FetchableRecord {
    ///     static let author = belongsTo(Author.self)
    /// }
    ///
    /// struct Author: TableRecord, FetchableRecord {
    ///     static let country = belongsTo(Country.self)
    /// }
    ///
    /// struct Country: TableRecord, FetchableRecord { }
    ///
    /// // Fetch a book, with its author, and the country of its author.
    /// let request = Book
    ///     .including(optional: Book.author
    ///         .including(optional: Author.country))
    /// let bookRow = try Row.fetchOne(db, request)!
    ///
    /// let book = try Book(row: bookRow)
    /// let author: Author? = bookRow["author"]
    /// let country: Country? = bookRow["country"]
    /// ```
    ///
    /// See also: ``scopesTree``
    ///
    /// - parameter scope: A scope identifier.
    public subscript<Record: FetchableRecord>(_ scope: String) -> Record? {
        try! decodeIfPresent(Record.self, forKey: scope)
    }
}

extension Row {
    /// Returns the eventual record associated with the given scope.
    ///
    /// For example:
    ///
    ///     let request = Book.including(optional: Book.author)
    ///     let row = try Row.fetchOne(db, request)!
    ///
    ///     try print(Book(row: row).title)
    ///     // Prints "Moby-Dick"
    ///
    ///     let author: Author? = row["author"]
    ///     print(author.name)
    ///     // Prints "Herman Melville"
    ///
    /// Associated records stored in nested associations are available, too:
    ///
    ///     let request = Book.including(optional: Book.author.including(optional: Author.country))
    ///     let row = try Row.fetchOne(db, request)!
    ///
    ///     try print(Book(row: row).title)
    ///     // Prints "Moby-Dick"
    ///
    ///     let country: Country? = row["country"]
    ///     print(country.name)
    ///     // Prints "United States"
    ///
    /// Nil is returned if the scope is not available, or contains only
    /// null values.
    ///
    /// See ``splittingRowAdapters(columnCounts:)`` for a sample code.
    func decodeIfPresent<Record: FetchableRecord>(
        _ type: Record.Type = Record.self,
        forKey scope: String)
    throws -> Record?
    {
        guard let scopedRow = scopesTree[scope], scopedRow.containsNonNullValue else {
            return nil
        }
        return try Record(row: scopedRow)
    }
    
    /// Returns the record associated with the given scope.
    ///
    /// For example:
    ///
    ///     let request = Book.including(required: Book.author)
    ///     let row = try Row.fetchOne(db, request)!
    ///
    ///     try print(Book(row: row).title)
    ///     // Prints "Moby-Dick"
    ///
    ///     let author: Author = row["author"]
    ///     print(author.name)
    ///     // Prints "Herman Melville"
    ///
    /// Associated records stored in nested associations are available, too:
    ///
    ///     let request = Book.including(required: Book.author.including(required: Author.country))
    ///     let row = try Row.fetchOne(db, request)!
    ///
    ///     try print(Book(row: row).title)
    ///     // Prints "Moby-Dick"
    ///
    ///     let country: Country = row["country"]
    ///     print(country.name)
    ///     // Prints "United States"
    ///
    /// A fatal error is raised if the scope is not available, or contains only
    /// null values.
    ///
    /// See ``splittingRowAdapters(columnCounts:)`` for a sample code.
    func decode<Record: FetchableRecord>(
        _ type: Record.Type = Record.self,
        forKey scope: String)
    throws -> Record
    {
        guard let scopedRow = scopesTree[scope] else {
            let availableScopes = scopesTree.names
            if availableScopes.isEmpty {
                throw RowDecodingError.keyNotFound(
                    .scope(scope),
                    RowDecodingError.Context(
                        decodingContext: RowDecodingContext(row: self),
                        debugDescription: """
                            scope not found: \(String(reflecting: scope))
                            """))
            } else {
                throw RowDecodingError.keyNotFound(
                    .scope(scope),
                    RowDecodingError.Context(
                        decodingContext: RowDecodingContext(row: self),
                        debugDescription: """
                            scope not found: \(String(reflecting: scope)) - \
                            available scopes: \(availableScopes.sorted())
                            """))
            }
        }
        guard scopedRow.containsNonNullValue else {
            throw RowDecodingError.valueMismatch(
                Record.self,
                RowDecodingError.Context(
                    decodingContext: RowDecodingContext(row: self, key: .scope(scope)),
                    debugDescription: """
                        scope \(String(reflecting: scope)) only contains null values
                        """))
        }
        return try Record(row: scopedRow)
    }
}

// MARK: - Row.ScopesView

extension Row {
    /// A view on the scopes defined by row adapters.
    ///
    /// `ScopesView` is a `Collection` of `(name: String, row: Row)` pairs.
    ///
    /// See ``Row/scopes`` for more information.
    public struct ScopesView {
        private let row: Row
        private let scopes: [String: any _LayoutedRowAdapter]
        private let prefetchedRows: Row.PrefetchedRowsView
        
        /// The available scopes in this row.
        public var names: Dictionary<String, any _LayoutedRowAdapter>.Keys {
            scopes.keys
        }
        
        init() {
            self.init(row: Row(), scopes: [:], prefetchedRows: Row.PrefetchedRowsView())
        }
        
        init(row: Row, scopes: [String: any _LayoutedRowAdapter], prefetchedRows: Row.PrefetchedRowsView) {
            self.row = row
            self.scopes = scopes
            self.prefetchedRows = prefetchedRows
        }
        
        /// The row associated with the given scope, or nil if the scope is
        /// not available.
        public subscript(_ name: String) -> Row? {
            scopes.index(forKey: name).map { self[$0].row }
        }
    }
}

extension Row.ScopesView: Collection {
    public typealias Index = Dictionary<String, any _LayoutedRowAdapter>.Index
    
    public var startIndex: Index {
        scopes.startIndex
    }
    
    public var endIndex: Index {
        scopes.endIndex
    }
    
    public func index(after i: Index) -> Index {
        scopes.index(after: i)
    }
    
    public subscript(position: Index) -> (name: String, row: Row) {
        let (name, adapter) = scopes[position]
        let adaptedRow = Row(base: row, adapter: adapter)
        if let prefetch = prefetchedRows.prefetches[name] {
            // Let the adapted row access its own prefetched rows.
            // Use case:
            //
            //      let request = A.including(required: A.b.including(all: B.c))
            //      let row = try Row.fetchOne(db, request)!
            //      row.prefetchedRows["cs"]              // Some array
            //      row.scopes["b"]!.prefetchedRows["cs"] // The same array
            adaptedRow.prefetchedRows = Row.PrefetchedRowsView(prefetches: prefetch.prefetches)
        }
        return (name: name, row: adaptedRow)
    }
}

// MARK: - Row.ScopesTreeView

extension Row {
    
    /// A view on the scopes tree defined by row adapters.
    ///
    /// See ``Row/scopesTree`` for more information.
    public struct ScopesTreeView {
        let scopes: ScopesView
        
        /// The scopes available on this row, recursively.
        public var names: Set<String> {
            var names = Set<String>()
            for (name, row) in scopes {
                names.insert(name)
                names.formUnion(row.scopesTree.names)
            }
            return names
        }
        
        /// The row associated with the given scope, or nil if the scope is
        /// not available.
        ///
        /// See ``Row/scopesTree`` for more information.
        ///
        /// - parameter key: An association key.
        public subscript(_ name: String) -> Row? {
            var fifo = Array(scopes)
            while !fifo.isEmpty {
                let scope = fifo.removeFirst()
                if scope.name == name {
                    return scope.row
                }
                fifo.append(contentsOf: scope.row.scopes)
            }
            return nil
        }
    }
}

extension Row {
    
    // MARK: - Fetching From QueryInterfaceRequest
    
    /// Returns an array of rows fetched from a fetch request.
    ///
    ///     let request = Player.all()
    ///     let rows = try Row.fetchAll(db, request)
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - request: A FetchRequest.
    /// - returns: An array of rows.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    @inlinable
    public static func fetchAll<T>(_ db: Database, _ request: QueryInterfaceRequest<T>) throws -> [Row] {
        if request.needsPrefetch {
            return try fetchAllWithPrefetchedRows(db, request)
        }
        let (statement, adapter) = try request.prepare(db, forSingleResult: false)
        return try fetchAll(statement, adapter: adapter)
    }
    
    /// Returns a single row fetched from a fetch request.
    ///
    ///     let request = Player.filter(key: 1)
    ///     let row = try Row.fetchOne(db, request)
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - request: A FetchRequest.
    /// - returns: An optional row.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    @inlinable
    public static func fetchOne<T>(_ db: Database, _ request: QueryInterfaceRequest<T>) throws -> Row? {
        if request.needsPrefetch {
            return try fetchOneWithPrefetchedRows(db, request)
        }
        let (statement, adapter) = try request.prepare(db, forSingleResult: true)
        return try fetchOne(statement, adapter: adapter)
    }

    @usableFromInline
    /* private */ static func fetchAllWithPrefetchedRows<T>(_ db: Database, _ request: QueryInterfaceRequest<T>) throws -> [Row] {
        // Fetch base rows
        // TODO: avoid fatal errors "column ... is not selected" by making sure
        // columns used by joins are fetched (and hidden by a row adapter if added)
        let (statement, adapter) = try request.prepare(db, forSingleResult: false)
        let rows = try fetchAll(statement, adapter: adapter)
        return try rowsWithPrefetchedRows(db, rows, with: request.query)
    }
    
    @usableFromInline
    /* private */ static func fetchOneWithPrefetchedRows<T>(_ db: Database, _ request: QueryInterfaceRequest<T>) throws -> Row? {
        // Fetch base rows
        // TODO: avoid fatal errors "column ... is not selected" by making sure
        // columns used by joins are fetched (and hidden by a row adapter if added)
        let (statement, adapter) = try request.prepare(db, forSingleResult: true)
        guard let row = try fetchOne(statement, adapter: adapter) else {
            return nil
        }
        return try rowsWithPrefetchedRows(db, [row], with: request.query)[0]
    }
    
    private static func rowsWithPrefetchedRows(_ db: Database, _ rows: [Row], with query: SQLSelectQuery) throws -> [Row] {
        if rows.isEmpty {
            return rows
        }
        
        let prefetchedAssociations = query.relation.prefetchedAssociations()
        for prefetchedAssociation in prefetchedAssociations {
            let groupingAlias = TableAlias()
            let groupingColumns = try prefetchedAssociation.pivotCondition.columnMapping(db).map { $0.right }
            let prefetchedRelation = prefetchedAssociation
                .mapPivotRelation { $0.qualified(with: groupingAlias) }
                .destinationRelation(fromOriginRows: { _ in rows })
                .annotated(with: groupingColumns.map { groupingAlias[Column($0)].aliased("grdb_\($0)") })
            let prefetchedRequest = QueryInterfaceRequest<Row>(relation: prefetchedRelation)
            let prefetchedRows = try prefetchedRequest.fetchAll(db)
            let groupedRows = group(prefetchedRows, on: groupingColumns.map { "grdb_\($0)" })
        }
        return rows
    }
    
    /// - precondition: Columns all exist in all rows. All rows have the same
    ///   columnns, in the same order.
    private static func group(_ rows: [Row], on columns: [String]) -> [[DatabaseValue]: [Row]] {
        guard let firstRow = rows.first else {
            return [:]
        }
        let indexes: [Int] = columns.map { firstRow.index(ofColumn: $0)! }
        return Dictionary(grouping: rows, by: { row in
            indexes.map { row.impl.databaseValue(atUncheckedIndex: $0) }
        })
    }
}

extension QueryInterfaceRequest where RowDecoder == Row {
    
    // MARK: Fetching Rows
    
    /// An array of fetched rows.
    ///
    ///     let request: QueryInterfaceRequest<Row> = ...
    ///     let rows = try request.fetchAll(db)
    ///
    /// - parameter db: A database connection.
    /// - returns: An array of fetched rows.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    @inlinable
    public func fetchAll(_ db: Database) throws -> [Row] {
        return try Row.fetchAll(db, self)
    }
    
    /// The first fetched row.
    ///
    ///     let request: QueryInterfaceRequest<Row> = ...
    ///     let row = try request.fetchOne(db)
    ///
    /// - parameter db: A database connection.
    /// - returns: An optional row.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    @inlinable
    public func fetchOne(_ db: Database) throws -> Row? {
        return try Row.fetchOne(db, self)
    }
}

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
        if request.query.needsPrefetch {
            return try fetchAllWithPrefetchedRows(db, request)
        }
        let (statement, adapter) = try request.prepare(db)
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
        if request.query.needsPrefetch {
            return try fetchOneWithPrefetchedRows(db, request)
        }
        let (statement, adapter) = try request.prepare(db)
        return try fetchOne(statement, adapter: adapter)
    }

    @usableFromInline
    static func fetchAllWithPrefetchedRows<T>(_ db: Database, _ request: QueryInterfaceRequest<T>) throws -> [Row] {
        // Fetch base rows
        // TODO: avoid fatal errors "column ... is not selected" by making sure
        // columns used by joins are fetched (and hidden by a row adapter if added)
        let (statement, adapter) = try request.prepare(db)
        let rows = try fetchAll(statement, adapter: adapter)
        return try rowsWithPrefetchedRows(db, rows, with: request.query)
    }

    @usableFromInline
    static func fetchOneWithPrefetchedRows<T>(_ db: Database, _ request: QueryInterfaceRequest<T>) throws -> Row? {
        // Fetch base rows
        // TODO: avoid fatal errors "column ... is not selected" by making sure
        // columns used by joins are fetched (and hidden by a row adapter if added)
        let (statement, adapter) = try request.prepare(db)
        guard let row = try fetchOne(statement, adapter: adapter) else {
            return nil
        }
        return try rowsWithPrefetchedRows(db, [row], with: request.query)[0]
    }

    private static func rowsWithPrefetchedRows(_ db: Database, _ rows: [Row], with query: SQLSelectQuery) throws -> [Row] {
        if rows.isEmpty {
            return []
        }
        
        var rows = rows
        for prefetch in query.relation.prefetches() {
//        for (key, join) in query.relation.prefetchedJoins {
            // Build query for prefetched rows
//            let association = makeAssociation(key: key, join: join)
//            let pivot = association.pivot(from: query.sourceTableName, rows: { _ in rows })
//            let query = SQLSelectQuery(relation: pivot.relation)
            let pivot = prefetch.association.pivot(from: query.relation.source.tableName, rows: { _ in rows })
            let pivotQuery = SQLSelectQuery(relation: pivot.relation)
            
            // Annotate with pivot columns, so that we can group and match with
            // base rows, below.
            //
            // Those pivot column are a required addition in the case of "through"
            // associations:
            //
            //      // SELECT country.*, passport.citizenId AS grdb_citizenId
            //      // FROM country
            //      // JOIN passport ON passport.countryCode = country.code
            //      //               AND passport.citizenId IN (1, 2, 3)
            //      Citizen.including(all: Citizen.countries)
            let pivotColumns = try pivot.condition.columns(db)
            let pivotSelection = pivotColumns.right.map { pivot.alias[Column($0)].aliased("grdb_\($0)") }
            let pivotRequest = QueryInterfaceRequest<Row>(query: pivotQuery).annotated(with: pivotSelection)
            
            // Fetch, Group, Match
            let prefetchedRows = try pivotRequest.fetchAll(db)
            let groupedRows = group(prefetchedRows, on: pivotColumns.right.map { "grdb_\($0)" })
            //rows = rowsWithPrefetchedRows(rows, with: groupedRows, on: pivotColumns.left, forKeyPath: prefetch.keyPath)
        }
        return rows
    }
    
//    private static func makeAssociation(key: String, join: SQLJoin) -> SQLAssociation {
//        var relation = join.relation
//        let prefetchedJoins = relation.prefetchedJoins
//        relation.joins = relation.directJoins
//        let association = SQLAssociation(key: key, condition: join.condition, relation: relation)
//        guard let (prefetchedKey, prefetchedJoin) = prefetchedJoins.first else {
//            return association
//        }
//        guard prefetchedJoins.count == 1 else {
//            // GRDB bug, or not implemented?
//            // Try:
//            //
//            //      Citizen
//            //          .including(all: passports) // hasMany passports
//            //          .including(all: countries) // hasMany countries through passports
//            fatalError("Can't build an association with multiple prefetched rows")
//        }
//        return makeAssociation(key: prefetchedKey, join: prefetchedJoin).appending(association)
//    }
    
    private static func group(_ rows: [Row], on columns: [String]) -> [[DatabaseValue]: [Row]] {
        guard let firstRow = rows.first else {
            return [:]
        }
        let indexes: [Int] = columns.compactMap { firstRow.index(ofColumn: $0) }
        assert(indexes.count == columns.count)
        return Dictionary(
            grouping: rows,
            by: { row in indexes.map { row.impl.databaseValue(atUncheckedIndex: $0) } })
    }
    
    private static func rowsWithPrefetchedRows(_ rows: [Row], with groupedRows: [[DatabaseValue]: [Row]], on columns: [String], forKeyPath keyPath: [String]) -> [Row] {
        guard keyPath.count == 1 else {
            fatalError("TODO")
        }
        let key = keyPath[0]
        
        guard let firstRow = rows.first else {
            return rows
        }
        let indexes: [Int] = columns.compactMap { firstRow.index(ofColumn: $0) }
        guard indexes.count == columns.count else {
            fatalError("Column \(columns.joined(separator: ", ")) is not selected")
        }
        return rows.map { row in
            let rowValue = indexes.map { row.impl.databaseValue(atUncheckedIndex: $0) }
            let prefetchedRows = groupedRows[rowValue] ?? []
            return row.withPrefetchedRows(prefetchedRows, forKey: key)
        }
    }
}

extension QueryInterfaceRequest where RowDecoder: Row {
    
    // MARK: Fetching Rows
    
    /// An array of fetched rows.
    ///
    ///     let request: ... // Some TypedRequest that fetches Row
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
    ///     let request: ... // Some TypedRequest that fetches Row
    ///     let row = try request.fetchOne(db)
    ///
    /// - parameter db: A database connection.
    /// - returns: A,n optional rows.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    @inlinable
    public func fetchOne(_ db: Database) throws -> Row? {
        return try Row.fetchOne(db, self)
    }
}

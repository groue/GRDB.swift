// MARK: - PreparedRequest

/// A PreparedRequest is a request that is ready to be executed.
public struct PreparedRequest {
    /// A prepared statement
    public var statement: SelectStatement
    
    /// An eventual adapter for rows fetched by the select statement
    public var adapter: RowAdapter?
    
    /// Support for eager loading of hasMany associations.
    var supplementaryFetch: ((Database, [Row]) throws -> Void)?
    
    init(
        statement: SelectStatement,
        adapter: RowAdapter?,
        supplementaryFetch: ((Database, [Row]) throws -> Void)? = nil)
    {
        self.statement = statement
        self.adapter = adapter
        self.supplementaryFetch = supplementaryFetch
    }
}

extension PreparedRequest: Refinable { }

extension FetchRequest {
    /// Returns a PreparedRequest that is ready to be executed.
    ///
    /// - parameter db: A database connection.
    /// - parameter singleResult: A hint that a single result row will be
    ///   consumed. Implementations can optionally use it to optimize the
    ///   prepared statement, for example by adding a `LIMIT 1` SQL clause.
    ///
    ///       // Calls makePreparedRequest(db, forSingleResult: true)
    ///       try request.fetchOne(db)
    ///
    ///       // Calls makePreparedRequest(db, forSingleResult: false)
    ///       try request.fetchAll(db)
    /// - returns: A prepared request.
    public func makePreparedRequest(_ db: Database, forSingleResult singleResult: Bool) throws -> PreparedRequest {
        var visitor = SQLPreparedRequestGenerator(db, forSingleResult: singleResult)
        try _accept(&visitor)
        return visitor.preparedRequest!
    }
    
    /// Returns the database region that the request feeds from.
    ///
    /// - parameter db: A database connection.
    public func databaseRegion(_ db: Database) throws -> DatabaseRegion {
        try makePreparedRequest(db, forSingleResult: false).statement.databaseRegion
    }
    
    /// Returns the number of rows fetched by the request.
    ///
    /// - parameter db: A database connection.
    public func fetchCount(_ db: Database) throws -> Int {
        var visitor = SQLRequestCounter(db)
        try _accept(&visitor)
        return visitor.count
    }
}

private struct SQLPreparedRequestGenerator: _FetchRequestVisitor {
    let db: Database
    let singleResult: Bool
    var preparedRequest: PreparedRequest?
    
    init(_ db: Database, forSingleResult singleResult: Bool) {
        self.db = db
        self.singleResult = singleResult
    }
    
    mutating func visit<Base: FetchRequest>(_ request: AdaptedFetchRequest<Base>) throws {
        try request.base._accept(&self)
        if let baseAdapter = preparedRequest!.adapter {
            preparedRequest!.adapter = try ChainedAdapter(first: baseAdapter, second: request.adapter(db))
        } else {
            preparedRequest!.adapter = try request.adapter(db)
        }
    }
    
    mutating func visit<RowDecoder>(_ request: QueryInterfaceRequest<RowDecoder>) throws {
        let generator = SQLQueryGenerator(query: request.query, forSingleResult: singleResult)
        var preparedRequest = try generator.makePreparedRequest(db)
        let associations = request.query.relation.prefetchedAssociations
        if associations.isEmpty == false {
            // Eager loading of prefetched associations
            preparedRequest = preparedRequest.with(\.supplementaryFetch) { db, rows in
                try prefetch(db, associations: associations, into: rows, from: request)
            }
        }
        self.preparedRequest = preparedRequest
    }
    
    mutating func visit<RowDecoder>(_ request: SQLRequest<RowDecoder>) throws {
        let context = SQLGenerationContext(db)
        let sql = try request.sqlLiteral.sql(context)
        let statement: SelectStatement
        switch request.cache {
        case .none:
            statement = try db.makeSelectStatement(sql: sql)
        case .public?:
            statement = try db.cachedSelectStatement(sql: sql)
        case .internal?:
            statement = try db.internalCachedSelectStatement(sql: sql)
        }
        try statement.setArguments(context.arguments)
        preparedRequest = PreparedRequest(statement: statement, adapter: request.adapter)
    }
}

private struct SQLRequestCounter: _FetchRequestVisitor {
    let db: Database
    var count = 0
    
    init(_ db: Database) {
        self.db = db
    }
    
    mutating func visit<Base: FetchRequest>(_ request: AdaptedFetchRequest<Base>) throws {
        try request.base._accept(&self)
    }
    
    mutating func visit<RowDecoder>(_ request: QueryInterfaceRequest<RowDecoder>) throws {
        count = try request.query.fetchCount(db)
    }
    
    mutating func visit<RowDecoder>(_ request: SQLRequest<RowDecoder>) throws {
        let countRequest: SQLRequest<Int> = "SELECT COUNT(*) FROM (\(request))"
        count = try countRequest.fetchOne(db)!
    }
}

// MARK: - Eager loading of hasMany associations

// CAUTION: Keep this code in sync with prefetchedRegion(_:_:)
/// Append rows from prefetched associations into the `baseRows` argument.
///
/// - parameter db: A database connection.
/// - parameter associations: Prefetched associations.
/// - parameter baseRows: The rows that need to be extended with prefetched rows.
/// - parameter baseRequest: The request that was used to fetch `baseRows`.
private func prefetch<RowDecoder>(
    _ db: Database,
    associations: [_SQLAssociation],
    into baseRows: [Row],
    from baseRequest: QueryInterfaceRequest<RowDecoder>) throws
{
    guard let firstBaseRow = baseRows.first else {
        // No rows -> no prefetch
        return
    }
    
    for association in associations {
        switch association.pivot.condition {
        case .expression:
            // Likely a GRDB bug: such condition only exist for CTEs, which
            // are not prefetched with including(all:)
            fatalError("Not implemented: prefetch association without any foreign key")
            
        case let .foreignKey(request: foreignKeyRequest, originIsLeft: originIsLeft):
            let pivotMapping = try foreignKeyRequest
                .fetchForeignKeyMapping(db)
                .joinMapping(originIsLeft: originIsLeft)
            let pivotColumns = pivotMapping.map(\.right)
            let leftColumns = pivotMapping.map(\.left)

            // We want to avoid the "Expression tree is too large" SQLite error
            // when the foreign key contains several columns, and there are many
            // base rows that overflow SQLITE_LIMIT_EXPR_DEPTH:
            // https://github.com/groue/GRDB.swift/issues/871
            //
            //      -- May be too complex for the SQLite engine
            //      SELECT * FROM child
            //      WHERE (a = ? AND b = ?)
            //         OR (a = ? AND b = ?)
            //         OR ...
            //
            // Instead, we do not inject any value from the base rows in
            // the prefetch request. Instead, we directly inject the base
            // request as a common table expression (CTE):
            //
            //      WITH grdb_base AS (SELECT a, b FROM parent)
            //      SELECT * FROM child
            //      WHERE (a, b) IN grdb_base
            //
            // This technique works well, but there is one precondition: row
            // values must be available (https://www.sqlite.org/rowvalue.html).
            // This is the case of almost all our target platforms.
            //
            // Otherwise, we fallback to the `(a = ? AND b = ?) OR ...`
            // condition (the one that may fail if there are too many
            // base rows).
            let usesCommonTableExpression = pivotMapping.count > 1 && _SQLRowValue.isAvailable
            
            let prefetchRequest: QueryInterfaceRequest<Row>
            if usesCommonTableExpression {
                // HasMany: Author.including(all: Author.books)
                //
                //      WITH grdb_base AS (SELECT a, b FROM author)
                //      SELECT book.*, book.authorId AS grdb_authorId
                //      FROM book
                //      WHERE (book.a, book.b) IN grdb_base
                //
                // HasManyThrough: Citizen.including(all: Citizen.countries)
                //
                //      WITH grdb_base AS (SELECT a, b FROM citizen)
                //      SELECT country.*, passport.citizenId AS grdb_citizenId
                //      FROM country
                //      JOIN passport ON passport.countryCode = country.code
                //                    AND (passport.a, passport.b) IN grdb_base
                let baseRequest = baseRequest.map(\.query.relation) { baseRelation in
                    // Ordering and including(all:) children are
                    // useless, and we only need pivoting columns:
                    baseRelation
                        .unordered()
                        .removingChildrenForPrefetchedAssociations()
                        .selectOnly(leftColumns.map(Column.init))
                }
                let baseCTE = CommonTableExpression<Void>(
                    named: "grdb_base",
                    request: baseRequest)
                let pivotRowValue = _SQLRowValue(pivotColumns.map(Column.init))
                let pivotFilter = SQLLiteral("\(pivotRowValue) IN grdb_base").sqlExpression
                
                prefetchRequest = makePrefetchRequest(
                    for: association,
                    filteringPivotWith: pivotFilter,
                    annotatedWith: pivotColumns)
                    .with(baseCTE)
            } else {
                // HasMany: Author.including(all: Author.books)
                //
                //      SELECT *, authorId AS grdb_authorId
                //      FROM book
                //      WHERE authorId IN (1, 2, 3)
                //
                // HasManyThrough: Citizen.including(all: Citizen.countries)
                //
                //      SELECT country.*, passport.citizenId AS grdb_citizenId
                //      FROM country
                //      JOIN passport ON passport.countryCode = country.code
                //                    AND passport.citizenId IN (1, 2, 3)
                let pivotFilter = pivotMapping.joinExpression(leftRows: baseRows)
                
                prefetchRequest = makePrefetchRequest(
                    for: association,
                    filteringPivotWith: pivotFilter,
                    annotatedWith: pivotColumns)
            }
            
            let prefetchedRows = try prefetchRequest.fetchAll(db)
            let prefetchedGroups = prefetchedRows.grouped(byDatabaseValuesOnColumns: pivotColumns.map { "grdb_\($0)" })
            let groupingIndexes = firstBaseRow.indexes(forColumns: leftColumns)
            
            for row in baseRows {
                let groupingKey = groupingIndexes.map { row.impl.databaseValue(atUncheckedIndex: $0) }
                let prefetchedRows = prefetchedGroups[groupingKey, default: []]
                row.prefetchedRows.setRows(prefetchedRows, forKeyPath: association.keyPath)
            }
        }
    }
}

/// Returns a request for prefetched rows.
///
/// - parameter assocciation: The prefetched association.
/// - parameter pivotFilter: The expression that filters the pivot of
///   the association.
/// - parameter pivotColumns: The pivot columns that annotate the
///   returned request.
func makePrefetchRequest(
    for association: _SQLAssociation,
    filteringPivotWith pivotFilter: SQLExpression,
    annotatedWith pivotColumns: [String])
-> QueryInterfaceRequest<Row>
{
    // We annotate prefetched rows with pivot columns, so that we can
    // group them.
    //
    // Those pivot columns are necessary when we prefetch
    // indirect associations:
    //
    //      // SELECT country.*, passport.citizenId AS grdb_citizenId
    //      // --                ^ the necessary pivot column
    //      // FROM country
    //      // JOIN passport ON passport.countryCode = country.code
    //      //               AND passport.citizenId IN (1, 2, 3)
    //      Citizen.including(all: Citizen.countries)
    //
    // Those pivot columns are redundant when we prefetch direct
    // associations (maybe we'll remove this redundancy later):
    //
    //      // SELECT *, authorId AS grdb_authorId
    //      // --        ^ the redundant pivot column
    //      // FROM book
    //      // WHERE authorId IN (1, 2, 3)
    //      Author.including(all: Author.books)
    let pivotAlias = TableAlias()
    
    let prefetchRelation = association
        .map(\.pivot.relation, { $0.qualified(with: pivotAlias).filter(pivotFilter) })
        .destinationRelation()
        .annotated(with: pivotColumns.map { pivotAlias[$0].forKey("grdb_\($0)") })
    
    return QueryInterfaceRequest<Row>(relation: prefetchRelation)
}

// CAUTION: Keep this code in sync with prefetch(_:associations:in:)
/// Returns the region of prefetched associations
func prefetchedRegion(_ db: Database, associations: [_SQLAssociation]) throws -> DatabaseRegion {
    try associations.reduce(into: DatabaseRegion()) { (region, association) in
        switch association.pivot.condition {
        case .expression:
            // Likely a GRDB bug: such condition only exist for CTEs, which
            // are not prefetched with including(all:)
            fatalError("Not implemented: prefetch association without any foreign key")
            
        case let .foreignKey(request: foreignKeyRequest, originIsLeft: originIsLeft):
            let pivotMapping = try foreignKeyRequest
                .fetchForeignKeyMapping(db)
                .joinMapping(originIsLeft: originIsLeft)
            let prefetchRegion = try prefetchedRegion(db, association: association, pivotMapping: pivotMapping)
            region.formUnion(prefetchRegion)
        }
    }
}

// CAUTION: Keep this code in sync with prefetch(_:associations:in:)
func prefetchedRegion(
    _ db: Database,
    association: _SQLAssociation,
    pivotMapping: JoinMapping)
throws -> DatabaseRegion
{
    // Filter the pivot on a `NullRow` in order to make sure all join
    // condition columns are made visible to SQLite, and present in the
    // selected region:
    //  ... JOIN right ON right.leftId IS NULL
    //                                    ^ content of the NullRow
    let pivotFilter = pivotMapping.joinExpression(leftRows: [NullRow()])
    
    let prefetchRelation = association
        .map(\.pivot.relation) { $0.filter(pivotFilter) }
        .destinationRelation()
    
    let prefetchQuery = SQLQuery(relation: prefetchRelation)
    
    return try SQLQueryGenerator(query: prefetchQuery)
        .makeSelectStatement(db)
        .databaseRegion // contains region of nested associations
}

extension Array where Element == Row {
    /// - precondition: Columns all exist in all rows. All rows have the same
    ///   columnns, in the same order.
    fileprivate func grouped(byDatabaseValuesOnColumns columns: [String]) -> [[DatabaseValue]: [Row]] {
        guard let firstRow = first else {
            return [:]
        }
        let indexes = firstRow.indexes(forColumns: columns)
        return Dictionary(grouping: self, by: { row in
            indexes.map { row.impl.databaseValue(atUncheckedIndex: $0) }
        })
    }
}

extension Row {
    /// - precondition: Columns all exist in the row.
    fileprivate func indexes(forColumns columns: [String]) -> [Int] {
        columns.map { column -> Int in
            guard let index = index(forColumn: column) else {
                fatalError("Column \(column) is not selected")
            }
            return index
        }
    }
}

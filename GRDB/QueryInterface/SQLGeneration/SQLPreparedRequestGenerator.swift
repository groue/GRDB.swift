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
                try prefetch(db, associations: associations, in: rows)
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

/// Append rows from prefetched associations into the argument rows.
private func prefetch(_ db: Database, associations: [_SQLAssociation], in rows: [Row]) throws {
    guard let firstRow = rows.first else {
        // No rows -> no prefetch
        return
    }
    
    // CAUTION: Keep this code in sync with prefetchedRegion(_:_:)
    for association in associations {
        switch association.pivot.condition {
        case let .foreignKey(request: foreignKeyRequest, originIsLeft: originIsLeft):
            // Annotate prefetched rows with pivot columns, so that we can
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
            let pivotMapping = try foreignKeyRequest
                .fetchForeignKeyMapping(db)
                .joinMapping(originIsLeft: originIsLeft)
            let pivotFilter = pivotMapping.joinExpression(leftRows: rows)
            let pivotColumns = pivotMapping.map(\.right)
            let pivotAlias = TableAlias()
            
            let prefetchedRelation = association
                .map(\.pivot.relation, { pivotRelation in
                    pivotRelation
                        .qualified(with: pivotAlias)
                        .filter { _ in pivotFilter }
                })
                .destinationRelation()
                // Annotate with the pivot columns that allow grouping
                .annotated(with: pivotColumns.map { pivotAlias[$0].forKey("grdb_\($0)") })
            
            let prefetchedGroups = try QueryInterfaceRequest<Row>(relation: prefetchedRelation)
                .fetchAll(db)
                .grouped(byDatabaseValuesOnColumns: pivotColumns.map { "grdb_\($0)" })
            // TODO: can we remove those grdb_ columns from user's sight,
            // now that grouping has been done?
            
            let groupingIndexes = firstRow.indexes(forColumns: pivotMapping.map(\.left))
            
            for row in rows {
                let groupingKey = groupingIndexes.map { row.impl.databaseValue(atUncheckedIndex: $0) }
                let prefetchedRows = prefetchedGroups[groupingKey, default: []]
                row.prefetchedRows.setRows(prefetchedRows, forKeyPath: association.keyPath)
            }
        }
    }
}

// Returns the region of prefetched associations
func prefetchedRegion(_ db: Database, associations: [_SQLAssociation]) throws -> DatabaseRegion {
    try associations.reduce(into: DatabaseRegion()) { (region, association) in
        // CAUTION: Keep this code in sync with prefetch(_:associations:in:)
        switch association.pivot.condition {
        case let .foreignKey(request: foreignKeyRequest, originIsLeft: originIsLeft):
            // Filter the pivot on a `NullRow` in order to make sure all join
            // condition columns are made visible to SQLite, and present in the
            // selected region:
            //  ... JOIN right ON right.leftId IS NULL
            //                                    ^ content of the NullRow
            let pivotFilter = try foreignKeyRequest
                .fetchForeignKeyMapping(db)
                .joinMapping(originIsLeft: originIsLeft)
                .joinExpression(leftRows: [NullRow()])
            
            let prefetchedRelation = association
                .map(\.pivot.relation, { pivotRelation in
                    pivotRelation.filter { _ in pivotFilter }
                })
                .destinationRelation()
            
            let prefetchedQuery = SQLQuery(relation: prefetchedRelation)
            
            let prefetchedRegion = try SQLQueryGenerator(query: prefetchedQuery)
                .makeSelectStatement(db)
                .databaseRegion // contains region of nested associations
            
            region.formUnion(prefetchedRegion)
        }
    }
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

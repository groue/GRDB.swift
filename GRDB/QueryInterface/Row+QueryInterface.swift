extension QueryInterfaceRequest where RowDecoder == Row {
    
    // MARK: Fetching Rows
    
    // TODO: cursor
    
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
        let (statement, adapter) = try request.prepare(db, forSingleResult: false)
        let rows = try fetchAll(statement, adapter: adapter)
        
        let associations = request.prefetchedAssociations
        if associations.isEmpty == false {
            try prefetch(db, associations: associations, in: rows)
        }
        return rows
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
        let (statement, adapter) = try request.prepare(db, forSingleResult: true)
        guard let row = try fetchOne(statement, adapter: adapter) else {
            return nil
        }
        
        let associations = request.prefetchedAssociations
        if associations.isEmpty == false {
            try prefetch(db, associations: associations, in: [row])
        }
        return row
    }
    
    @usableFromInline
    /* private */ static func prefetch(_ db: Database, associations: [SQLAssociation], in rows: [Row]) throws {
        guard let firstRow = rows.first else {
            return
        }
        
        for association in associations {
            let pivotMapping = try association.pivotCondition.columnMapping(db)
            
            let prefetchedRows: [[DatabaseValue] : [Row]]
            do {
                // Annotate prefetched rows with pivot columns, so that we can
                // group them.
                //
                // Those pivot columns are necessaary when we prefetch
                // indirect associations:
                //
                //      // SELECT country.*, passport.citizenId AS grdb_citizenId
                //      // --                ^ the necessaary pivot column
                //      // FROM country
                //      // JOIN passport ON passport.countryCode = country.code
                //      //               AND passport.citizenId IN (1, 2, 3)
                //      Citizen.including(all: Citizen.countries)
                //
                // Those pivot columns are redundant when we prefetch
                // direct associations:
                //
                //      // SELECT *, authorId AS grdb_authorId
                //      // --        ^ the redundant pivot column
                //      // FROM book
                //      // WHERE authorId IN (1, 2, 3)
                //      Author.including(all: Author.books)
                //
                // Maybe we'll remove this redundancy later.
                let pivotColumns = pivotMapping.map { $0.right }
                let pivotAlias = TableAlias()
                let prefetchedRelation = association
                    .mapPivotRelation { $0.qualified(with: pivotAlias) }
                    .destinationRelation(fromOriginRows: { _ in rows })
                    .annotated(with: pivotColumns.map { pivotAlias[Column($0)].aliased("grdb_\($0)") })
                prefetchedRows = try QueryInterfaceRequest(relation: prefetchedRelation)
                    .fetchAll(db)
                    .grouped(byDatabaseValuesOnColumns: pivotColumns.map { "grdb_\($0)" })
            }
            
            let groupingIndexes = firstRow.indexes(ofColumns: pivotMapping.map { $0.left })
            for row in rows {
                let groupingKey = groupingIndexes.map { row.impl.databaseValue(atUncheckedIndex: $0) }
                let prefetchedRows = prefetchedRows[groupingKey, default: []]
                row.prefetches.setRows(prefetchedRows, forKeyPath: association.keyPath)
            }
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
        let indexes = firstRow.indexes(ofColumns: columns)
        return Dictionary(grouping: self, by: { row in
            indexes.map { row.impl.databaseValue(atUncheckedIndex: $0) }
        })
    }
}

extension Row {
    /// - precondition: Columns all exist in the row.
    fileprivate func indexes(ofColumns columns: [String]) -> [Int] {
        return columns.map { column -> Int in
            guard let index = index(ofColumn: column) else {
                fatalError("Column \(column) is not selected")
            }
            return index
        }
    }
}

extension Dictionary where Key == String, Value == Row.Prefetch {
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

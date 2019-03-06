extension QueryInterfaceRequest where RowDecoder: TableRecord {
    // MARK: - Associations
    
    /// Creates a request that includes an association. The columns of the
    /// associated record are selected. The returned association does not
    /// require that the associated database table contains a matching row.
    public func including<A: Association>(optional association: A) -> QueryInterfaceRequest where A.OriginRowDecoder == RowDecoder {
        return mapQuery { $0.mapRelation { association._impl.joinedRelation($0, joinOperator: .optional) } }
    }
    
    /// Creates a request that includes an association. The columns of the
    /// associated record are selected. The returned association requires
    /// that the associated database table contains a matching row.
    public func including<A: Association>(required association: A) -> QueryInterfaceRequest where A.OriginRowDecoder == RowDecoder {
        return mapQuery { $0.mapRelation { association._impl.joinedRelation($0, joinOperator: .required) } }
    }
    
    /// Creates a request that includes an association. The columns of the
    /// associated record are not selected. The returned association does not
    /// require that the associated database table contains a matching row.
    public func joining<A: Association>(optional association: A) -> QueryInterfaceRequest where A.OriginRowDecoder == RowDecoder {
        return mapQuery { $0.mapRelation { association.select([])._impl.joinedRelation($0, joinOperator: .optional) } }
    }
    
    /// Creates a request that includes an association. The columns of the
    /// associated record are not selected. The returned association requires
    /// that the associated database table contains a matching row.
    public func joining<A: Association>(required association: A) -> QueryInterfaceRequest where A.OriginRowDecoder == RowDecoder {
        return mapQuery { $0.mapRelation { association.select([])._impl.joinedRelation($0, joinOperator: .required) } }
    }
    
    // MARK: - Association Aggregates
    
    private func annotated(with aggregate: AssociationAggregate<RowDecoder>) -> QueryInterfaceRequest {
        let (request, expression) = aggregate.prepare(self)
        if let alias = aggregate.alias {
            return request.annotated(with: [expression.aliased(alias)])
        } else {
            return request.annotated(with: [expression])
        }
    }
    
    /// Creates a request which appends *aggregates* to the current selection.
    ///
    ///     // SELECT player.*, COUNT(DISTINCT book.rowid) AS bookCount
    ///     // FROM player LEFT JOIN book ...
    ///     var request = Player.all()
    ///     request = request.annotated(with: Player.books.count)
    public func annotated(with aggregates: AssociationAggregate<RowDecoder>...) -> QueryInterfaceRequest {
        return annotated(with: aggregates)
    }

    /// Creates a request which appends *aggregates* to the current selection.
    ///
    ///     // SELECT player.*, COUNT(DISTINCT book.rowid) AS bookCount
    ///     // FROM player LEFT JOIN book ...
    ///     var request = Player.all()
    ///     request = request.annotated(with: [Player.books.count])
    public func annotated(with aggregates: [AssociationAggregate<RowDecoder>]) -> QueryInterfaceRequest {
        return aggregates.reduce(self) { request, aggregate in
            request.annotated(with: aggregate)
        }
    }
    
    /// Creates a request which appends the provided aggregate *predicate* to
    /// the eventual set of already applied predicates.
    ///
    ///     // SELECT player.*
    ///     // FROM player LEFT JOIN book ...
    ///     // HAVING COUNT(DISTINCT book.rowid) = 0
    ///     var request = Player.all()
    ///     request = request.having(Player.books.isEmpty)
    public func having(_ predicate: AssociationAggregate<RowDecoder>) -> QueryInterfaceRequest {
        let (request, expression) = predicate.prepare(self)
        return request.having(expression)
    }
}

extension MutablePersistableRecord {
    /// Creates a request that fetches the associated record(s).
    ///
    /// For example:
    ///
    ///     struct Team: {
    ///         static let players = hasMany(Player.self)
    ///         var players: QueryInterfaceRequest<Player> {
    ///             return request(for: Team.players)
    ///         }
    ///     }
    ///
    ///     let team: Team = ...
    ///     let players = try team.players.fetchAll(db) // [Player]
    public func request<A: Association>(for association: A) -> QueryInterfaceRequest<A.RowDecoder> where A.OriginRowDecoder == Self {
        return association.request(from: self)
    }
}

extension TableRecord {
    
    // MARK: - Associations
    
    /// Creates a request that includes an association. The columns of the
    /// associated record are selected. The returned association does not
    /// require that the associated database table contains a matching row.
    public static func including<A: Association>(optional association: A) -> QueryInterfaceRequest<Self> where A.OriginRowDecoder == Self {
        return all().including(optional: association)
    }
    
    /// Creates a request that includes an association. The columns of the
    /// associated record are selected. The returned association requires
    /// that the associated database table contains a matching row.
    public static func including<A: Association>(required association: A) -> QueryInterfaceRequest<Self> where A.OriginRowDecoder == Self {
        return all().including(required: association)
    }
    
    /// Creates a request that includes an association. The columns of the
    /// associated record are not selected. The returned association does not
    /// require that the associated database table contains a matching row.
    public static func joining<A: Association>(optional association: A) -> QueryInterfaceRequest<Self> where A.OriginRowDecoder == Self {
        return all().joining(optional: association)
    }
    
    /// Creates a request that includes an association. The columns of the
    /// associated record are not selected. The returned association requires
    /// that the associated database table contains a matching row.
    public static func joining<A: Association>(required association: A) -> QueryInterfaceRequest<Self> where A.OriginRowDecoder == Self {
        return all().joining(required: association)
    }
    
    // MARK: - Association Aggregates
    
    /// Creates a request with *aggregates* appended to the selection.
    ///
    ///     // SELECT player.*, COUNT(DISTINCT book.rowid) AS bookCount
    ///     // FROM player LEFT JOIN book ...
    ///     var request = Player.annotated(with: Player.books.count)
    public static func annotated(with aggregates: AssociationAggregate<Self>...) -> QueryInterfaceRequest<Self> {
        return all().annotated(with: aggregates)
    }
    
    /// Creates a request with *aggregates* appended to the selection.
    ///
    ///     // SELECT player.*, COUNT(DISTINCT book.rowid) AS bookCount
    ///     // FROM player LEFT JOIN book ...
    ///     var request = Player.annotated(with: [Player.books.count])
    public static func annotated(with aggregates: [AssociationAggregate<Self>]) -> QueryInterfaceRequest<Self> {
        return all().annotated(with: aggregates)
    }

    /// Creates a request with the provided aggregate *predicate*.
    ///
    ///     // SELECT player.*
    ///     // FROM player LEFT JOIN book ...
    ///     // HAVING COUNT(DISTINCT book.rowid) = 0
    ///     var request = Player.all()
    ///     request = request.having(Player.books.isEmpty)
    ///
    /// The selection defaults to all columns. This default can be changed for
    /// all requests by the `TableRecord.databaseSelection` property, or
    /// for individual requests with the `TableRecord.select` method.
    public static func having(_ predicate: AssociationAggregate<Self>) -> QueryInterfaceRequest<Self> {
        return all().having(predicate)
    }
}

extension QueryInterfaceRequest where RowDecoder: TableRecord {
    func joining<A: Association>(_ joinOperator: AssociationJoinOperator, _ association: A)
        -> QueryInterfaceRequest<RowDecoder>
        where A.LeftAssociated == RowDecoder
    {
        let join = AssociationJoin(
            joinOperator: joinOperator,
            query: association.request.query,
            key: association.key,
            joinConditionPromise: DatabasePromise(association.joinCondition))
        return QueryInterfaceRequest(query: query.joining(join))
    }
    
    // MARK: - Associations
    
    /// Creates a request that includes an association. The columns of the
    /// associated record are selected. The returned association does not
    /// require that the associated database table contains a matching row.
    public func including<A: Association>(optional association: A) -> QueryInterfaceRequest<RowDecoder> where A.LeftAssociated == RowDecoder {
        return joining(.optional, association)
    }
    
    /// Creates a request that includes an association. The columns of the
    /// associated record are selected. The returned association requires
    /// that the associated database table contains a matching row.
    public func including<A: Association>(required association: A) -> QueryInterfaceRequest<RowDecoder> where A.LeftAssociated == RowDecoder {
        return joining(.required, association)
    }
    
    /// Creates a request that includes an association. The columns of the
    /// associated record are not selected. The returned association does not
    /// require that the associated database table contains a matching row.
    public func joining<A: Association>(optional association: A) -> QueryInterfaceRequest<RowDecoder> where A.LeftAssociated == RowDecoder {
        return joining(.optional, association.select([]))
    }
    
    /// Creates a request that includes an association. The columns of the
    /// associated record are not selected. The returned association requires
    /// that the associated database table contains a matching row.
    public func joining<A: Association>(required association: A) -> QueryInterfaceRequest<RowDecoder> where A.LeftAssociated == RowDecoder {
        return joining(.required, association.select([]))
    }
}

extension MutablePersistableRecord {
    /// Creates a request that fetches the associated record(s).
    ///
    /// For example:
    ///
    ///     struct Player: TableRecord {
    ///         static let team = belongsTo(Team.self)
    ///     }
    ///
    ///     let player: Player = ...
    ///     let request = player.request(for: Player.team)
    ///     let team = try request.fetchOne(db) // Team?
    public func request<A: Association>(for association: A) -> QueryInterfaceRequest<A.RightAssociated> where A.LeftAssociated == Self {
        return association.request(from: self)
    }
}

extension TableRecord {
    
    // MARK: - Associations
    
    /// Creates a request that includes an association. The columns of the
    /// associated record are selected. The returned association does not
    /// require that the associated database table contains a matching row.
    public static func including<A: Association>(optional association: A) -> QueryInterfaceRequest<Self> where A.LeftAssociated == Self {
        return all().including(optional: association)
    }
    
    /// Creates a request that includes an association. The columns of the
    /// associated record are selected. The returned association requires
    /// that the associated database table contains a matching row.
    public static func including<A: Association>(required association: A) -> QueryInterfaceRequest<Self> where A.LeftAssociated == Self {
        return all().including(required: association)
    }
    
    /// Creates a request that includes an association. The columns of the
    /// associated record are not selected. The returned association does not
    /// require that the associated database table contains a matching row.
    public static func joining<A: Association>(optional association: A) -> QueryInterfaceRequest<Self> where A.LeftAssociated == Self {
        return all().joining(optional: association)
    }
    
    /// Creates a request that includes an association. The columns of the
    /// associated record are not selected. The returned association requires
    /// that the associated database table contains a matching row.
    public static func joining<A: Association>(required association: A) -> QueryInterfaceRequest<Self> where A.LeftAssociated == Self {
        return all().joining(required: association)
    }
}

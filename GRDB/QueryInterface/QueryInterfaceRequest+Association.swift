extension QueryInterfaceRequest where RowDecoder: TableRecord {
    func chain<A: Association>(_ chainOp: AssociationChainOperator, _ association: A)
        -> QueryInterfaceRequest<RowDecoder>
        where A.LeftAssociated == RowDecoder
    {
        let join = AssociationJoin(
            op: chainOp,
            rightQuery: association.request.query,
            key: association.key,
            associationMapping: association.associationMapping)
        return QueryInterfaceRequest(query: query.joining(join))
    }
    
    // MARK: - Associations
    
    /// Creates a request that includes an association. The columns of the
    /// associated record are selected. The returned association does not
    /// require that the associated database table contains a matching row.
    public func including<A: Association>(optional association: A)
        -> QueryInterfaceRequest<RowDecoder>
        where A.LeftAssociated == RowDecoder
    {
        return chain(.optional, association)
    }
    
    /// Creates a request that includes an association. The columns of the
    /// associated record are selected. The returned association requires
    /// that the associated database table contains a matching row.
    public func including<A: Association>(required association: A)
        -> QueryInterfaceRequest<RowDecoder>
        where A.LeftAssociated == RowDecoder
    {
        return chain(.required, association)
    }
    
    /// Creates a request that includes an association. The columns of the
    /// associated record are not selected. The returned association does not
    /// require that the associated database table contains a matching row.
    public func joining<A: Association>(optional association: A)
        -> QueryInterfaceRequest<RowDecoder>
        where A.LeftAssociated == RowDecoder
    {
        return chain(.optional, association.select([]))
    }
    
    /// Creates a request that includes an association. The columns of the
    /// associated record are not selected. The returned association requires
    /// that the associated database table contains a matching row.
    public func joining<A: Association>(required association: A)
        -> QueryInterfaceRequest<RowDecoder>
        where A.LeftAssociated == RowDecoder
    {
        return chain(.required, association.select([]))
    }
}

extension Association where LeftAssociated: MutablePersistableRecord {
    func request(from record: LeftAssociated) -> QueryInterfaceRequest<RightAssociated> {
        var query = request.query.preparedQuery // make sure query has a qualifier
        let qualifier = query.source.qualifier!
        let recordQualifier = SQLTableQualifier.init(tableName: LeftAssociated.databaseTableName)

        query = query.filter { db in
            let associationMapping = try self.associationMapping(db)
            guard let filter = associationMapping(recordQualifier, qualifier) else {
                fatalError("Can't request from record without association mapping")
            }
            let container = PersistenceContainer(record)
            return filter.resolvedExpression(inContext: [recordQualifier: container])
        }
        
        return QueryInterfaceRequest(query: QueryInterfaceQuery(query))
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
    public func request<A: Association>(for association: A)
        -> QueryInterfaceRequest<A.RightAssociated>
        where A.LeftAssociated == Self
    {
        return association.request(from: self)
    }
}

extension TableRecord {
    
    // MARK: - Associations
    
    /// Creates a request that includes an association. The columns of the
    /// associated record are selected. The returned association does not
    /// require that the associated database table contains a matching row.
    public static func including<A: Association>(optional association: A)
        -> QueryInterfaceRequest<Self>
        where A.LeftAssociated == Self
    {
        return all().including(optional: association)
    }
    
    /// Creates a request that includes an association. The columns of the
    /// associated record are selected. The returned association requires
    /// that the associated database table contains a matching row.
    public static func including<A: Association>(required association: A)
        -> QueryInterfaceRequest<Self>
        where A.LeftAssociated == Self
    {
        return all().including(required: association)
    }
    
    /// Creates a request that includes an association. The columns of the
    /// associated record are not selected. The returned association does not
    /// require that the associated database table contains a matching row.
    public static func joining<A: Association>(optional association: A)
        -> QueryInterfaceRequest<Self>
        where A.LeftAssociated == Self
    {
        return all().joining(optional: association)
    }
    
    /// Creates a request that includes an association. The columns of the
    /// associated record are not selected. The returned association requires
    /// that the associated database table contains a matching row.
    public static func joining<A: Association>(required association: A)
        -> QueryInterfaceRequest<Self>
        where A.LeftAssociated == Self
    {
        return all().joining(required: association)
    }
}

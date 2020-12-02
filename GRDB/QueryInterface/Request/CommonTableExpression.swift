#warning("TODO: doc")
public struct CommonTableExpression<RowDecoder> {
    #warning("TODO: doc")
    public var tableName: String
    
    #warning("TODO: doc")
    public var columns: [Column]?
    
    var request: _FetchRequest
    
    #warning("TODO: doc")
    public init<Request: FetchRequest>(
        named tableName: String,
        columns: [Column]? = nil,
        request: Request)
    {
        self.tableName = tableName
        self.columns = columns
        self.request = request
    }
    
    #warning("TODO: doc")
    public init(
        named tableName: String,
        columns: [Column]? = nil,
        sql: String,
        arguments: StatementArguments = StatementArguments())
    {
        self.init(
            named: tableName,
            columns: columns,
            request: SQLRequest<Void>(sql: sql, arguments: arguments))
    }
    
    #warning("TODO: doc")
    public init(
        named tableName: String,
        columns: [Column]? = nil,
        literal: SQLLiteral)
    {
        self.init(
            named: tableName,
            columns: columns,
            request: SQLRequest<Void>(literal: literal))
    }
}

extension CommonTableExpression {
    var relationForAll: SQLRelation {
        SQLRelation(
            source: .table(tableName: tableName, alias: nil),
            selectionPromise: DatabasePromise(value: [_AllCTEColumns(columns: columns, request: request, alias: nil)]))
    }
    
    #warning("TODO: doc")
    public func all() -> QueryInterfaceRequest<Void> {
        QueryInterfaceRequest(relation: relationForAll)
    }
}

extension TableRecord {
    #warning("TODO: doc")
    public static func association<Destination>(
        to cte: CommonTableExpression<Destination>,
        on condition: @escaping (TableAlias, TableAlias) -> SQLExpressible)
    -> JoinAssociation<Self, Destination>
    {
        JoinAssociation(
            key: .inflected(cte.tableName),
            condition: .expression(condition),
            relation: cte.relationForAll)
    }
    
    #warning("TODO: doc")
    public static func association<Destination>(
        to cte: CommonTableExpression<Destination>,
        using columns: [Column] = [])
    -> JoinAssociation<Self, Destination>
    {
        JoinAssociation(
            key: .inflected(cte.tableName),
            condition: .using(columns),
            relation: cte.relationForAll)
    }
}

extension CommonTableExpression {
    #warning("TODO: doc")
    public func association<Destination>(
        to cte: CommonTableExpression<Destination>,
        on condition: @escaping (TableAlias, TableAlias) -> SQLExpressible)
    -> JoinAssociation<RowDecoder, Destination>
    {
        JoinAssociation(
            key: .inflected(cte.tableName),
            condition: .expression(condition),
            relation: cte.relationForAll)
    }
    
    #warning("TODO: doc")
    public func association<Destination>(
        to cte: CommonTableExpression<Destination>,
        using columns: [Column] = [])
    -> JoinAssociation<RowDecoder, Destination>
    {
        JoinAssociation(
            key: .inflected(cte.tableName),
            condition: .using(columns),
            relation: cte.relationForAll)
    }
    
    #warning("TODO: doc")
    public func association<Destination>(
        to destination: Destination.Type,
        on condition: @escaping (TableAlias, TableAlias) -> SQLExpressible)
    -> JoinAssociation<RowDecoder, Destination>
    where Destination: TableRecord
    {
        JoinAssociation(
            key: .inflected(Destination.databaseTableName),
            condition: .expression(condition),
            relation: Destination.relationForAll)
    }
    
    #warning("TODO: doc")
    public func association<Destination>(
        to destination: Destination.Type,
        using columns: [Column] = [])
    -> JoinAssociation<RowDecoder, Destination>
    where Destination: TableRecord
    {
        JoinAssociation(
            key: .inflected(Destination.databaseTableName),
            condition: .using(columns),
            relation: Destination.relationForAll)
    }
}

// MARK: - QueryInterfaceRequest

extension QueryInterfaceRequest {
    #warning("TODO: Accept an array of ctes by discarding their RowDecoder type. This would look better when there are several recursive CTEs.")
    
    #warning("TODO: doc")
    public func with<RowDecoder>(_ cte: CommonTableExpression<RowDecoder>) -> Self {
        with(\.query.ctes[cte.tableName], (columns: cte.columns, request: cte.request))
    }
    
    #warning("TODO: doc")
    public func with<RowDecoder>(recursive cte: CommonTableExpression<RowDecoder>) -> Self {
        fatalError("TODO")
    }
}

// MARK: - _AllCTEColumns

/// :nodoc:
public struct _AllCTEColumns {
    var columns: [Column]?
    var request: _FetchRequest
    var alias: TableAlias?
}

extension _AllCTEColumns: SQLSelectable, Refinable {
    /// :nodoc:
    public func _count(distinct: Bool) -> _SQLCount? {
        // SELECT DISTINCT * FROM tableName ...
        if distinct {
            // Can't count
            return nil
        }
        
        // SELECT * FROM tableName ...
        // ->
        // SELECT COUNT(*) FROM tableName ...
        return .all
    }
    
    /// :nodoc:
    public func _qualifiedSelectable(with alias: TableAlias) -> SQLSelectable {
        // Never requalify
        if self.alias != nil {
            return self
        }
        return with(\.alias, alias)
    }
    
    /// :nodoc:
    public func _columnCount(_ db: Database) throws -> Int {
        if let columns = columns {
            return columns.count
        }
        
        // Compile request
        #warning("TODO: do we need to cache this CTE columnCount?")
        let context = SQLGenerationContext(db)
        let sql = try request.requestSQL(context, forSingleResult: false)
        let statement = try db.makeSelectStatement(sql: sql)
        return statement.columnCount
    }
    
    /// :nodoc:
    public func _accept<Visitor: _SQLSelectableVisitor>(_ visitor: inout Visitor) throws {
        if let alias = alias {
            return try _SQLQualifiedAllColumns(alias: alias)._accept(&visitor)
        } else {
            return try AllColumns()._accept(&visitor)
        }
    }
}

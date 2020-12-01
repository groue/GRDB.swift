#warning("TODO: doc")
public struct CommonTableExpression {
    var tableName: String
    var request: _FetchRequest
}

extension CommonTableExpression {
    var relationForAll: SQLRelation {
        SQLRelation(
            source: .table(tableName: tableName, alias: nil),
            selectionPromise: DatabasePromise(value: [_AllCTEColumns(request: request, alias: nil)]))
    }
    
    #warning("TODO: doc")
    public func all() -> QueryInterfaceRequest<Void> {
        QueryInterfaceRequest(relation: relationForAll)
    }
}

extension CommonTableExpression {
    #warning("TODO: Do we need to be able to provide a foreign key? A USING clause?")
    #warning("TODO: doc")
    public func association<T>(from: T.Type = T.self, on condition: @escaping (TableAlias, TableAlias) -> SQLExpressible)
    -> JoinAssociation<T, Void>
    {
        JoinAssociation(
            key: .inflected(tableName),
            condition: .promise(condition),
            relation: relationForAll)
    }
    
    #warning("TODO: doc")
    public func association<T>(from: T.Type = T.self, using columns: Column...)
    -> JoinAssociation<T, Void>
    {
        association(from: T.self, on: { (left, right) -> SQLExpressible in
            columns.map { left[$0] == right[$0] }.joined(operator: .and)
        })
    }
    
    #warning("TODO: Do we need to be able to provide a foreign key? A USING clause?")
    #warning("TODO: doc")
    public func association(
        to cte: CommonTableExpression,
        on condition: @escaping (TableAlias, TableAlias) -> SQLExpressible)
    -> JoinAssociation<Void, Void>
    {
        JoinAssociation(
            key: .inflected(cte.tableName),
            condition: .promise(condition),
            relation: cte.relationForAll)
    }
    
    #warning("TODO: Do we need to be able to provide a foreign key? A USING clause?")
    #warning("TODO: doc")
    public func association<Destination>(
        to destination: Destination.Type,
        on condition: @escaping (TableAlias, TableAlias) -> SQLExpressible)
    -> JoinAssociation<Void, Destination>
    where Destination: TableRecord
    {
        JoinAssociation(
            key: .inflected(Destination.databaseTableName),
            condition: .promise(condition),
            relation: Destination.relationForAll)
    }
}

extension _FetchRequest {
    #warning("TODO: doc")
    public func commonTableExpression(tableName: String) -> CommonTableExpression {
        CommonTableExpression(
            tableName: tableName,
            request: self)
    }
}

// MARK: - _AllCTEColumns

/// :nodoc:
public struct _AllCTEColumns {
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

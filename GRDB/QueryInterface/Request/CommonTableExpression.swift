#warning("TODO: doc")
public struct CommonTableExpression {
    enum Request {
        case query(SQLQuery)
        case literal(SQLLiteral)
    }
    
    var key: String
    var alias: TableAlias
    var request: Request
}

extension CommonTableExpression: Refinable {
    #warning("TODO: doc")
    public func forKey(_ key: String) -> Self {
        with(\.key, key)
    }
    
    #warning("TODO: doc")
    public func aliased(_ alias: TableAlias) -> Self {
        alias.becomeProxy(of: self.alias)
        return self
    }
}

extension CommonTableExpression {
    /// Returns a qualified value that is able to resolve ambiguities in
    /// joined queries.
    public subscript(_ selectable: SQLSelectable) -> SQLSelectable {
        selectable._qualifiedSelectable(with: alias)
    }
    
    /// Returns a qualified expression that is able to resolve ambiguities in
    /// joined queries.
    public subscript(_ expression: SQLExpression) -> SQLExpression {
        expression._qualifiedExpression(with: alias)
    }
    
    /// Returns a qualified ordering that is able to resolve ambiguities in
    /// joined queries.
    public subscript(_ ordering: SQLOrderingTerm) -> SQLOrderingTerm {
        ordering._qualifiedOrdering(with: alias)
    }
    
    /// Returns a qualified columnn that is able to resolve ambiguities in
    /// joined queries.
    public subscript(_ column: String) -> SQLExpression {
        Column(column)._qualifiedExpression(with: alias)
    }
}

extension QueryInterfaceRequest {
    #warning("TODO: doc")
    public func commonTableExpression() -> CommonTableExpression {
        CommonTableExpression(
            key: databaseTableName,
            alias: TableAlias(tableName: databaseTableName), // Confusing. Should be a "baseName"
            request: .query(query))
    }
}

extension SQLRequest {
    #warning("TODO: doc")
    public func commonTableExpression(key: String) -> CommonTableExpression {
        CommonTableExpression(
            key: key,
            alias: TableAlias(tableName: key), // Confusing. Should be a "baseName"
            request: .literal(sqlLiteral))
    }
}

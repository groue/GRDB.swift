extension QueryInterfaceRequest {
    
    // MARK: Full Text Search
    
    /// Creates a request with a full-text predicate added to the eventual
    /// set of already applied predicates.
    ///
    ///     // SELECT * FROM book WHERE book MATCH '...'
    ///     var request = Book.all()
    ///     request = request.matching(pattern)
    ///
    /// If the search pattern is nil, the request does not match any
    /// database row.
    public func matching(_ pattern: FTS3Pattern?) -> QueryInterfaceRequest<T> {
        guard let pattern = pattern else {
            return none()
        }
        let alias = TableAlias()
        let qualifiedQuery = query.qualified(with: alias)
        let matchExpression = TableMatchExpression(alias: alias, pattern: pattern.databaseValue)
        return QueryInterfaceRequest(query: qualifiedQuery).filter(matchExpression)
    }
}

extension TableRecord {
    
    // MARK: Full Text Search
    
    /// Returns a QueryInterfaceRequest with a matching predicate.
    ///
    ///     // SELECT * FROM book WHERE book MATCH '...'
    ///     var request = Book.matching(pattern)
    ///
    /// If the search pattern is nil, the request does not match any
    /// database row.
    ///
    /// The selection defaults to all columns. This default can be changed for
    /// all requests by the `TableRecord.databaseSelection` property, or
    /// for individual requests with the `TableRecord.select` method.
    public static func matching(_ pattern: FTS3Pattern?) -> QueryInterfaceRequest<Self> {
        return all().matching(pattern)
    }
}

extension ColumnExpression {
    /// A matching SQL expression with the `MATCH` SQL operator.
    ///
    ///     // content MATCH '...'
    ///     Column("content").match(pattern)
    ///
    /// If the search pattern is nil, SQLite will evaluate the expression
    /// to false.
    public func match(_ pattern: FTS3Pattern?) -> SQLExpression {
        return SQLExpressionBinary(.match, self, pattern ?? DatabaseValue.null)
    }
}

extension QueryInterfaceRequest {
    
    // MARK: Full Text Search
    
    /// Returns a new QueryInterfaceRequest with a matching predicate added
    /// to the eventual set of already applied predicates.
    ///
    ///     // SELECT * FROM books WHERE books MATCH '...'
    ///     var request = Book.all()
    ///     request = request.matching(pattern)
    ///
    /// If the search pattern is nil, the request does not match any
    /// database row.
    public func matching(_ pattern: FTS3Pattern?) -> QueryInterfaceRequest<T> {
        switch query.source {
        case .table(let name, let alias)?:
            return filter(SQLExpressionBinary(.match, Column(alias ?? name), pattern ?? DatabaseValue.null))
        default:
            // Programmer error
            fatalError("fts3 match requires a table")
        }
    }
}

extension TableMapping {
    
    // MARK: Full Text Search
    
    /// Returns a QueryInterfaceRequest with a matching predicate.
    ///
    ///     // SELECT * FROM books WHERE books MATCH '...'
    ///     var request = Book.matching(pattern)
    ///
    /// If the search pattern is nil, the request does not match any
    /// database row.
    ///
    /// The selection defaults to all columns. This default can be changed for
    /// all requests by the `TableMapping.databaseSelection` property, or
    /// for individual requests with the `TableMapping.select` method.
    public static func matching(_ pattern: FTS3Pattern?) -> QueryInterfaceRequest<Self> {
        return all().matching(pattern)
    }
}

extension Column {
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

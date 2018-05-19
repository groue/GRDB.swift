#if SQLITE_ENABLE_FTS5
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
        ///
        /// The selection defaults to all columns. This default can be changed for
        /// all requests by the `TableRecord.databaseSelection` property, or
        /// for individual requests with the `TableRecord.select` method.
        public func matching(_ pattern: FTS5Pattern?) -> QueryInterfaceRequest<T> {
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
        public static func matching(_ pattern: FTS5Pattern?) -> QueryInterfaceRequest<Self> {
            return all().matching(pattern)
        }
    }
#endif

extension TableRequest where Self: FilteredRequest {
    
    // MARK: Full Text Search
    
    /// Filters rows that match an ``FTS3`` full-text pattern.
    ///
    /// For example:
    ///
    /// ```swift
    /// // SELECT * FROM book WHERE book MATCH 'sqlite OR database'
    /// let pattern = FTS3Pattern(matchingAnyTokenIn: "SQLite Database")
    /// let request = Book.all().matching(pattern)
    /// ```
    ///
    /// If `pattern` is nil, the returned request fetches no row.
    ///
    /// - parameter pattern: An ``FTS3Pattern``.
    public func matching(_ pattern: FTS3Pattern?) -> Self {
        guard let pattern else {
            return none()
        }
        let alias = TableAlias()
        let matchExpression = SQLExpression.tableMatch(alias, pattern.sqlExpression)
        return self.aliased(alias).filter(matchExpression)
    }
}

extension TableRecord {
    
    // MARK: Full Text Search
    
    /// Returns a request filtered on records that match an ``FTS3``
    /// full-text pattern.
    ///
    /// For example:
    ///
    /// ```swift
    /// // SELECT * FROM book WHERE book MATCH 'sqlite OR database'
    /// let pattern = FTS3Pattern(matchingAnyTokenIn: "SQLite Database")
    /// let request = Book.matching(pattern)
    /// ```
    ///
    /// If `pattern` is nil, the returned request fetches no row.
    ///
    /// - parameter pattern: An ``FTS3Pattern``.
    public static func matching(_ pattern: FTS3Pattern?) -> QueryInterfaceRequest<Self> {
        all().matching(pattern)
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
        .binary(.match, sqlExpression, pattern?.sqlExpression ?? .null)
    }
}

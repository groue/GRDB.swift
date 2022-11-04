#if SQLITE_ENABLE_FTS5
extension TableRequest where Self: FilteredRequest {
    
    // MARK: Full Text Search
    
    /// Filters rows that match an ``FTS5`` full-text pattern.
    ///
    /// For example:
    ///
    /// ```swift
    /// // SELECT * FROM book WHERE book MATCH 'sqlite OR database'
    /// let pattern = FTS5Pattern(matchingAnyTokenIn: "SQLite Database")
    /// let request = Book.all().matching(pattern)
    /// ```
    ///
    /// If `pattern` is nil, the returned request fetches no row.
    ///
    /// - parameter pattern: An ``FTS5Pattern``.
    public func matching(_ pattern: FTS5Pattern?) -> Self {
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
    
    /// Returns a request filtered on records that match an ``FTS5``
    /// full-text pattern.
    ///
    /// For example:
    ///
    /// ```swift
    /// // SELECT * FROM book WHERE book MATCH 'sqlite OR database'
    /// let pattern = FTS5Pattern(matchingAnyTokenIn: "SQLite Database")
    /// let request = Book.matching(pattern)
    /// ```
    ///
    /// If `pattern` is nil, the returned request fetches no row.
    ///
    /// - parameter pattern: An ``FTS5Pattern``.
    public static func matching(_ pattern: FTS5Pattern?) -> QueryInterfaceRequest<Self> {
        all().matching(pattern)
    }
}

extension ColumnExpression {
    
    /// A matching SQL expression with the `MATCH` SQL operator.
    ///
    ///     // content MATCH '...'
    ///     Column("content").match(pattern)
    public func match(_ pattern: FTS5Pattern) -> SQLExpression {
        .binary(.match, sqlExpression, pattern.sqlExpression)
    }
}
#endif

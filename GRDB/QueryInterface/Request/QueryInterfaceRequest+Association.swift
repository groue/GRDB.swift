extension QueryInterfaceRequest where RowDecoder: TableRecord {
    
    // MARK: - Association Aggregates
    
    private func annotated(with aggregate: AssociationAggregate<RowDecoder>) -> QueryInterfaceRequest {
        let (request, expression) = aggregate.prepare(self)
        if let key = aggregate.key {
            return request.annotated(with: [expression.forKey(key)])
        } else {
            return request.annotated(with: [expression])
        }
    }
    
    /// Creates a request which appends *aggregates* to the current selection.
    ///
    ///     // SELECT player.*, COUNT(DISTINCT book.rowid) AS bookCount
    ///     // FROM player LEFT JOIN book ...
    ///     var request = Player.all()
    ///     request = request.annotated(with: Player.books.count)
    public func annotated(with aggregates: AssociationAggregate<RowDecoder>...) -> QueryInterfaceRequest {
        return annotated(with: aggregates)
    }
    
    /// Creates a request which appends *aggregates* to the current selection.
    ///
    ///     // SELECT player.*, COUNT(DISTINCT book.rowid) AS bookCount
    ///     // FROM player LEFT JOIN book ...
    ///     var request = Player.all()
    ///     request = request.annotated(with: [Player.books.count])
    public func annotated(with aggregates: [AssociationAggregate<RowDecoder>]) -> QueryInterfaceRequest {
        return aggregates.reduce(self) { request, aggregate in
            request.annotated(with: aggregate)
        }
    }
    
    /// Creates a request which appends the provided aggregate *predicate* to
    /// the eventual set of already applied predicates.
    ///
    ///     // SELECT player.*
    ///     // FROM player LEFT JOIN book ...
    ///     // HAVING COUNT(DISTINCT book.rowid) = 0
    ///     var request = Player.all()
    ///     request = request.having(Player.books.isEmpty)
    public func having(_ predicate: AssociationAggregate<RowDecoder>) -> QueryInterfaceRequest {
        let (request, expression) = predicate.prepare(self)
        return request.having(expression)
    }
}

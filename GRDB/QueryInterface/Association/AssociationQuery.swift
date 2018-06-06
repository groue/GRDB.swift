struct AssociationQuery {
    var source: SQLSource
    var selection: [SQLSelectable]
    var filterPromise: DatabasePromise<SQLExpression?>
    var ordering: QueryOrdering
    var joins: [AssociationJoin]
    
    var alias: TableAlias? {
        return source.alias
    }
}

extension AssociationQuery {
    init(_ query: QueryInterfaceQuery) {
        GRDBPrecondition(!query.isDistinct, "Not implemented: join distinct queries")
        GRDBPrecondition(query.groupByExpressions.isEmpty, "Can't join aggregated queries")
        GRDBPrecondition(query.havingExpression == nil, "Can't join aggregated queries")
        GRDBPrecondition(query.limit == nil, "Can't join limited queries")
        
        self.init(
            source: query.source,
            selection: query.selection,
            filterPromise: query.filterPromise,
            ordering: query.ordering,
            joins: query.joins)
    }
}

extension AssociationQuery {
    func select(_ selection: [SQLSelectable]) -> AssociationQuery {
        var query = self
        query.selection = selection
        return query
    }
    
    func filter(_ predicate: @escaping (Database) throws -> SQLExpressible) -> AssociationQuery {
        var query = self
        query.filterPromise = query.filterPromise.map { (db, filter) in
            if let filter = filter {
                return try filter && predicate(db)
            } else {
                return try predicate(db).sqlExpression
            }
        }
        return query
    }
    
    func order(_ orderings: @escaping (Database) throws -> [SQLOrderingTerm]) -> AssociationQuery {
        return order(QueryOrdering(orderings: orderings))
    }
    
    func reversed() -> AssociationQuery {
        return order(ordering.reversed)
    }
    
    private func order(_ ordering: QueryOrdering) -> AssociationQuery {
        var query = self
        query.ordering = ordering
        return query
    }
    
    func joining(_ join: AssociationJoin) -> AssociationQuery {
        var query = self
        query.joins.append(join)
        return query
    }
    
    func qualified(with alias: TableAlias) -> AssociationQuery {
        var query = self
        query.source = source.qualified(with: alias)
        return query
    }
}

extension AssociationQuery {
    /// A finalized query is ready for SQL generation
    var finalizedQuery: AssociationQuery {
        var query = self
        
        let alias = TableAlias()
        query.source = source.qualified(with: alias)
        query.selection = selection.map { $0.qualifiedSelectable(with: alias) }
        query.filterPromise = filterPromise.map { [alias] (_, expr) in expr?.qualifiedExpression(with: alias) }
        query.ordering = ordering.qualified(with: alias)
        query.joins = joins.map { $0.finalizedJoin }
        
        return query
    }
    
    /// precondition: self is the result of finalizedQuery
    var finalizedAliases: [TableAlias] {
        var aliases: [TableAlias] = []
        if let alias = alias {
            aliases.append(alias)
        }
        return joins.reduce(into: aliases) {
            $0.append(contentsOf: $1.finalizedAliases)
        }
    }
    
    /// precondition: self is the result of finalizedQuery
    var finalizedSelection: [SQLSelectable] {
        return joins.reduce(into: selection) {
            $0.append(contentsOf: $1.finalizedSelection)
        }
    }
    
    /// precondition: self is the result of finalizedQuery
    var finalizedOrdering: QueryOrdering {
        return joins.reduce(ordering) {
            $0.appending($1.finalizedOrdering)
        }
    }
    
    /// precondition: self is the result of finalizedQuery
    func finalizedRowAdapter(_ db: Database, fromIndex startIndex: Int, forKeyPath keyPath: [String]) throws -> (adapter: RowAdapter, endIndex: Int)? {
        let selectionWidth = try selection
            .map { try $0.columnCount(db) }
            .reduce(0, +)
        
        var endIndex = startIndex + selectionWidth
        var scopes: [String: RowAdapter] = [:]
        for join in joins {
            if let (joinAdapter, joinEndIndex) = try join.finalizedRowAdapter(db, fromIndex: endIndex, forKeyPath: keyPath + [join.key]) {
                GRDBPrecondition(scopes[join.key] == nil, "The association key \"\((keyPath + [join.key]).joined(separator: "."))\" is ambiguous. Use the Association.forKey(_:) method is order to disambiguate.")
                scopes[join.key] = joinAdapter
                endIndex = joinEndIndex
            }
        }
        
        if selectionWidth == 0 && scopes.isEmpty {
            return nil
        }
        
        let adapter = RangeRowAdapter(startIndex ..< (startIndex + selectionWidth))
        return (adapter: adapter.addingScopes(scopes), endIndex: endIndex)
    }
}

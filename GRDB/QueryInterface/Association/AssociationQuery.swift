struct AssociationQuery {
    var source: SQLSource
    var selection: [SQLSelectable]
    var filterPromise: DatabasePromise<SQLExpression?>
    var ordering: QueryOrdering
    var joins: [AssociationJoin]
    
    var qualifiedQuery: AssociationQuery {
        var qualifier = SQLTableQualifier(tableName: source.tableName!)
        
        var query = self
        query.source = source.qualified(with: &qualifier)
        query.selection = selection.map { $0.qualifiedSelectable(with: qualifier) }
        query.filterPromise = filterPromise.map { [qualifier] (_, expr) in expr?.qualifiedExpression(with: qualifier) }
        query.ordering = ordering.qualified(with: qualifier)
        query.joins = joins.map { $0.qualifiedJoin }
        return query
    }
    
    var qualifier: SQLTableQualifier? {
        return source.qualifier
    }
    
    var allQualifiers: [SQLTableQualifier] {
        var qualifiers: [SQLTableQualifier] = []
        if let qualifier = qualifier {
            qualifiers.append(qualifier)
        }
        return joins.reduce(into: qualifiers) {
            $0.append(contentsOf: $1.allQualifiers)
        }
    }
    
    var completeSelection: [SQLSelectable] {
        return joins.reduce(into: selection) {
            $0.append(contentsOf: $1.completeSelection)
        }
    }
    
    var completeOrdering: QueryOrdering {
        return joins.reduce(ordering) {
            $0.appending($1.completeOrdering)
        }
    }
    
    func rowAdapter(_ db: Database, fromIndex startIndex: Int, forKeyPath keyPath: [String]) throws -> (adapter: RowAdapter, endIndex: Int)? {
        let selectionWidth = try selection
            .map { try $0.columnCount(db) }
            .reduce(0, +)
        
        var endIndex = startIndex + selectionWidth
        var scopes: [String: RowAdapter] = [:]
        for join in joins {
            if let (joinAdapter, joinEndIndex) = try join.rowAdapter(db, fromIndex: endIndex, forKeyPath: keyPath + [join.key]) {
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
    
    func order(_ orderings: [SQLOrderingTerm]) -> AssociationQuery {
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
    
    func qualified(with qualifier: inout SQLTableQualifier) -> AssociationQuery {
        var query = self
        query.source = source.qualified(with: &qualifier)
        return query
    }
}

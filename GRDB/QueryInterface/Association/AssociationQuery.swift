struct AssociationQuery {
    var source: SQLSource
    var selection: [SQLSelectable]
    var filterPromise: DatabasePromise<SQLExpression?>
    var ordering: QueryOrdering
    var joins: OrderedDictionary<String, AssociationJoin>
    
    var alias: TableAlias? {
        return source.alias
    }
}

extension AssociationQuery {
    init(_ query: QueryInterfaceQuery) {
        GRDBPrecondition(!query.isDistinct, "Not implemented: join distinct queries")
        GRDBPrecondition(query.groupPromise == nil, "Can't join aggregated queries")
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
    
    func appendingJoin(_ join: AssociationJoin, forKey key: String) -> AssociationQuery {
        var query = self
        if let existingJoin = query.joins.removeValue(forKey: key) {
            guard let mergedJoin = existingJoin.merged(with: join) else {
                // can't merge
                fatalError("The association key \"\(key)\" is ambiguous. Use the Association.forKey(_:) method is order to disambiguate.")
            }
            query.joins.append(value: mergedJoin, forKey: key)
        } else {
            query.joins.append(value: join, forKey: key)
        }
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
        query.joins = joins.mapValues { $0.finalizedJoin }
        
        return query
    }
    
    /// precondition: self is the result of finalizedQuery
    var finalizedAliases: [TableAlias] {
        var aliases: [TableAlias] = []
        if let alias = alias {
            aliases.append(alias)
        }
        return joins.reduce(into: aliases) {
            $0.append(contentsOf: $1.value.finalizedAliases)
        }
    }
    
    /// precondition: self is the result of finalizedQuery
    var finalizedSelection: [SQLSelectable] {
        return joins.reduce(into: selection) {
            $0.append(contentsOf: $1.value.finalizedSelection)
        }
    }
    
    /// precondition: self is the result of finalizedQuery
    var finalizedOrdering: QueryOrdering {
        return joins.reduce(ordering) {
            $0.appending($1.value.finalizedOrdering)
        }
    }
    
    /// precondition: self is the result of finalizedQuery
    func finalizedRowAdapter(_ db: Database, fromIndex startIndex: Int, forKeyPath keyPath: [String]) throws -> (adapter: RowAdapter, endIndex: Int)? {
        let selectionWidth = try selection
            .map { try $0.columnCount(db) }
            .reduce(0, +)
        
        var endIndex = startIndex + selectionWidth
        var scopes: [String: RowAdapter] = [:]
        for (key, join) in joins {
            if let (joinAdapter, joinEndIndex) = try join.finalizedRowAdapter(db, fromIndex: endIndex, forKeyPath: keyPath + [key]) {
                scopes[key] = joinAdapter
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
    /// Returns nil if queries can't be merged (conflict in source, joins...)
    func merged(with other: AssociationQuery) -> AssociationQuery? {
        guard let mergedSource = source.merged(with: other.source) else {
            // can't merge
            return nil
        }
        
        let mergedFilterPromise = filterPromise.map { (db, expression) in
            let otherExpression = try other.filterPromise.resolve(db)
            let expressions = [expression, otherExpression].compactMap { $0 }
            if expressions.isEmpty {
                return nil
            }
            return expressions.joined(operator: .and)
        }
        
        var mergedJoins: OrderedDictionary<String, AssociationJoin> = [:]
        for (key, join) in joins {
            if let otherJoin = other.joins[key] {
                guard let mergedJoin = join.merged(with: otherJoin) else {
                    // can't merge
                    return nil
                }
                mergedJoins.append(value: mergedJoin, forKey: key)
            } else {
                mergedJoins.append(value: join, forKey: key)
            }
        }
        for (key, join) in other.joins where mergedJoins[key] == nil {
            mergedJoins.append(value: join, forKey: key)
        }
        
        // replace selection unless empty
        let mergedSelection = other.selection.isEmpty ? selection : other.selection
        
        // replace ordering unless empty
        let mergedOrdering = other.ordering.isEmpty ? ordering : other.ordering
        
        return AssociationQuery(
            source: mergedSource,
            selection: mergedSelection,
            filterPromise: mergedFilterPromise,
            ordering: mergedOrdering,
            joins: mergedJoins)
    }
}

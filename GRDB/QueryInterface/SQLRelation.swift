/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// A "relation" as defined by the [relational terminology](https://en.wikipedia.org/wiki/Relational_database#Terminology):
///
/// > A set of tuples sharing the same attributes; a set of columns and rows.
///
/// :nodoc:
public /* TODO: make internal when possible */ struct SQLRelation {
    var source: SQLSource
    var selection: [SQLSelectable]
    var filterPromise: DatabasePromise<SQLExpression?>
    var ordering: QueryOrdering
    var joins: OrderedDictionary<String, Join>
    
    var alias: TableAlias? {
        return source.alias
    }
    
    init(
        source: SQLSource,
        selection: [SQLSelectable] = [],
        filterPromise: DatabasePromise<SQLExpression?> = DatabasePromise(value: nil),
        ordering: QueryOrdering = QueryOrdering(),
        joins: OrderedDictionary<String, Join> = [:])
    {
        self.source = source
        self.selection = selection
        self.filterPromise = filterPromise
        self.ordering = ordering
        self.joins = joins
    }
}

extension SQLRelation {
    func select(_ selection: [SQLSelectable]) -> SQLRelation {
        var relation = self
        relation.selection = selection
        return relation
    }
    
    func filter(_ predicate: @escaping (Database) throws -> SQLExpressible) -> SQLRelation {
        var relation = self
        relation.filterPromise = relation.filterPromise.map { (db, filter) in
            if let filter = filter {
                return try filter && predicate(db)
            } else {
                return try predicate(db).sqlExpression
            }
        }
        return relation
    }
    
    func order(_ orderings: @escaping (Database) throws -> [SQLOrderingTerm]) -> SQLRelation {
        return order(QueryOrdering(orderings: orderings))
    }
    
    func reversed() -> SQLRelation {
        return order(ordering.reversed)
    }
    
    private func order(_ ordering: QueryOrdering) -> SQLRelation {
        var relation = self
        relation.ordering = ordering
        return relation
    }
    
    func unordered() -> SQLRelation {
        return order(QueryOrdering())
    }
    
    func appendingJoin(_ join: Join, forKey key: String) -> SQLRelation {
        var relation = self
        if let existingJoin = relation.joins.removeValue(forKey: key) {
            guard let mergedJoin = existingJoin.merged(with: join) else {
                // can't merge
                fatalError("The association key \"\(key)\" is ambiguous. Use the Association.forKey(_:) method is order to disambiguate.")
            }
            relation.joins.append(value: mergedJoin, forKey: key)
        } else {
            relation.joins.append(value: join, forKey: key)
        }
        return relation
    }
    
    func qualified(with alias: TableAlias) -> SQLRelation {
        var relation = self
        relation.source = source.qualified(with: alias)
        return relation
    }
}

extension SQLRelation {
    /// A finalized relation is ready for SQL generation
    var finalizedRelation: SQLRelation {
        var relation = self
        
        let alias = TableAlias()
        relation.source = source.qualified(with: alias)
        relation.selection = selection.map { $0.qualifiedSelectable(with: alias) }
        relation.filterPromise = filterPromise.map { [alias] (_, expr) in expr?.qualifiedExpression(with: alias) }
        relation.ordering = ordering.qualified(with: alias)
        relation.joins = joins.mapValues { $0.finalizedJoin }
        
        return relation
    }
    
    /// - precondition: self is the result of finalizedRelation
    var finalizedAliases: [TableAlias] {
        var aliases: [TableAlias] = []
        if let alias = alias {
            aliases.append(alias)
        }
        return joins.reduce(into: aliases) {
            $0.append(contentsOf: $1.value.finalizedAliases)
        }
    }
    
    /// - precondition: self is the result of finalizedRelation
    var finalizedSelection: [SQLSelectable] {
        return joins.reduce(into: selection) {
            $0.append(contentsOf: $1.value.finalizedSelection)
        }
    }
    
    /// - precondition: self is the result of finalizedRelation
    var finalizedOrdering: QueryOrdering {
        return joins.reduce(ordering) {
            $0.appending($1.value.finalizedOrdering)
        }
    }
    
    /// - precondition: self is the result of finalizedRelation
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

extension SQLRelation {
    /// Returns nil if queries can't be merged (conflict in source, joins...)
    func merged(with other: SQLRelation) -> SQLRelation? {
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
        
        var mergedJoins: OrderedDictionary<String, Join> = [:]
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
        
        return SQLRelation(
            source: mergedSource,
            selection: mergedSelection,
            filterPromise: mergedFilterPromise,
            ordering: mergedOrdering,
            joins: mergedJoins)
    }
}

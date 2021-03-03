/// SQLQuery is a representation of an SQL query.
///
/// See SQLQueryGenerator for actual SQL generation.
struct SQLQuery {
    var relation: SQLRelation
    var isDistinct: Bool = false
    var groupPromise: DatabasePromise<[SQLExpression]>?
    var havingExpressionPromise: DatabasePromise<SQLExpression?> = DatabasePromise(value: nil)
    var limit: SQLLimit?
    var ctes: OrderedDictionary<String, SQLCTE> = [:]
}

extension SQLQuery: Refinable {
    func distinct() -> Self {
        with(\.isDistinct, true)
    }
    
    func limit(_ limit: Int, offset: Int? = nil) -> Self {
        with(\.limit, SQLLimit(limit: limit, offset: offset))
    }
    
    func aliased(_ alias: TableAlias) -> Self {
        map(\.relation) { $0.aliased(alias) }
    }
}

extension SQLQuery {
    func select(_ selection: @escaping (Database) throws -> [SQLSelection]) -> Self {
        map(\.relation) { $0.select(selection) }
    }
    
    // Convenience
    func select(_ expressions: SQLExpression...) -> Self {
        select { _ in expressions.map { .expression($0) } }
    }
    
    func annotated(with selection: @escaping (Database) throws -> [SQLSelection]) -> Self {
        map(\.relation) { $0.annotated(with: selection) }
    }
}

extension SQLQuery {
    func filter(_ predicate: @escaping (Database) throws -> SQLExpression) -> Self {
        map(\.relation) { $0.filter(predicate) }
    }
}

extension SQLQuery {
    func order(_ orderings: @escaping (Database) throws -> [SQLOrdering]) -> Self {
        map(\.relation) { $0.order(orderings) }
    }
    
    func reversed() -> Self {
        map(\.relation) { $0.reversed() }
    }
    
    func unordered() -> Self {
        map(\.relation) { $0.unordered() }
    }
}

extension SQLQuery {
    func group(_ expressions: @escaping (Database) throws -> [SQLExpression]) -> Self {
        with(\.groupPromise, DatabasePromise(expressions))
    }
    
    func having(_ predicate: @escaping (Database) throws -> SQLExpression) -> Self {
        map(\.havingExpressionPromise) { promise in
            DatabasePromise { db in
                if let filter = try promise.resolve(db) {
                    return try filter && predicate(db)
                } else {
                    return try predicate(db)
                }
            }
        }
    }
}

extension SQLQuery{
    func _including(all association: _SQLAssociation) -> Self {
        map(\.relation) { $0._including(all: association) }
    }
    
    func _including(optional association: _SQLAssociation) -> Self {
        map(\.relation) { $0._including(optional: association) }
    }
    
    func _including(required association: _SQLAssociation) -> Self {
        map(\.relation) { $0._including(required: association) }
    }
    
    func _joining(optional association: _SQLAssociation) -> Self {
        map(\.relation) { $0._joining(optional: association) }
    }
    
    func _joining(required association: _SQLAssociation) -> Self {
        map(\.relation) { $0._joining(required: association) }
    }
}

extension SQLQuery {
    func fetchCount(_ db: Database) throws -> Int {
        guard groupPromise == nil && limit == nil && ctes.isEmpty else {
            // SELECT ... GROUP BY ...
            // SELECT ... LIMIT ...
            // WITH ... SELECT ...
            return try fetchTrivialCount(db)
        }
        
        if relation.children.contains(where: { $0.value.impactsParentCount }) { // TODO: not tested
            // SELECT ... FROM ... JOIN ...
            return try fetchTrivialCount(db)
        }
        
        let selection = try relation.selectionPromise.resolve(db)
        GRDBPrecondition(!selection.isEmpty, "Can't generate SQL with empty selection")
        if selection.count == 1 {
            guard let count = selection[0].count(distinct: isDistinct) else {
                return try fetchTrivialCount(db)
            }
            var countQuery = self.unordered()
            countQuery.isDistinct = false
            switch count {
            case .all:
                countQuery = countQuery.select(.count(.allColumns))
            case .distinct(let expression):
                countQuery = countQuery.select(.countDistinct(expression))
            }
            return try QueryInterfaceRequest(query: countQuery).fetchOne(db)!
        } else {
            // SELECT [DISTINCT] expr1, expr2, ... FROM tableName ...
            
            guard !isDistinct else {
                return try fetchTrivialCount(db)
            }
            
            // SELECT expr1, expr2, ... FROM tableName ...
            // ->
            // SELECT COUNT(*) FROM tableName ...
            let countQuery = unordered().select(SQLExpression.count(.allColumns))
            return try QueryInterfaceRequest(query: countQuery).fetchOne(db)!
        }
    }
    
    // SELECT COUNT(*) FROM (self)
    func fetchTrivialCount(_ db: Database) throws -> Int {
        let countRequest: SQLRequest<Int> = "SELECT COUNT(*) FROM (\(SQLSubquery.query(unordered())))"
        return try countRequest.fetchOne(db)!
    }
}

struct SQLLimit {
    let limit: Int
    let offset: Int?
    
    var sql: String {
        if let offset = offset {
            return "\(limit) OFFSET \(offset)"
        } else {
            return "\(limit)"
        }
    }
}

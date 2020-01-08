/// SQLQuery is a representation of an SQL query.
///
/// See SQLQueryGenerator for actual SQL generation.
struct SQLQuery {
    var relation: SQLRelation
    var isDistinct: Bool
    var expectsSingleResult: Bool
    var groupPromise: DatabasePromise<[SQLExpression]>?
    // Having clause is an array of expressions that we'll join with
    // the AND operator. This gives nicer output in generated SQL:
    // `(a AND b AND c)` instead of `((a AND b) AND c)`.
    var havingExpressions: [SQLExpression]
    var limit: SQLLimit?
    
    init(
        relation: SQLRelation,
        isDistinct: Bool = false,
        expectsSingleResult: Bool = false,
        groupPromise: DatabasePromise<[SQLExpression]>? = nil,
        havingExpressions: [SQLExpression] = [],
        limit: SQLLimit? = nil)
    {
        self.relation = relation
        self.isDistinct = isDistinct
        self.expectsSingleResult = expectsSingleResult
        self.groupPromise = groupPromise
        self.havingExpressions = havingExpressions
        self.limit = limit
    }
}

extension SQLQuery {
    /// Returns a query whose relation is transformed by the given closure.
    func mapRelation(_ transform: (SQLRelation) -> SQLRelation) -> SQLQuery {
        var query = self
        query.relation = transform(relation)
        return query
    }
    
    func distinct() -> SQLQuery {
        var query = self
        query.isDistinct = true
        return query
    }
    
    func expectingSingleResult() -> SQLQuery {
        var query = self
        query.expectsSingleResult = true
        return query
    }
    
    func limit(_ limit: Int, offset: Int? = nil) -> SQLQuery {
        var query = self
        query.limit = SQLLimit(limit: limit, offset: offset)
        return query
    }
    
    func qualified(with alias: TableAlias) -> SQLQuery {
        // We do not need to qualify group and having clauses. They will be
        // in SQLQueryGenerator.init()
        return mapRelation { $0.qualified(with: alias) }
    }
}

extension SQLQuery: SelectionRequest {
    func select(_ selection: [SQLSelectable]) -> SQLQuery {
        return mapRelation { $0.select(selection) }
    }
    
    func annotated(with selection: [SQLSelectable]) -> SQLQuery {
        return mapRelation { $0.annotated(with: selection) }
    }
}

extension SQLQuery: FilteredRequest {
    func filter(_ predicate: @escaping (Database) throws -> SQLExpressible) -> SQLQuery {
        return mapRelation { $0.filter(predicate) }
    }
}

extension SQLQuery: OrderedRequest {
    func order(_ orderings: @escaping (Database) throws -> [SQLOrderingTerm]) -> SQLQuery {
        return mapRelation { $0.order(orderings) }
    }
    
    func reversed() -> SQLQuery {
        return mapRelation { $0.reversed() }
    }
    
    func unordered() -> SQLQuery {
        return mapRelation { $0.unordered() }
    }
}

extension SQLQuery: AggregatingRequest {
    func group(_ expressions: @escaping (Database) throws -> [SQLExpressible]) -> SQLQuery {
        var query = self
        query.groupPromise = DatabasePromise { db in try expressions(db).map { $0.sqlExpression } }
        return query
    }
    
    func having(_ predicate: SQLExpressible) -> SQLQuery {
        var query = self
        query.havingExpressions.append(predicate.sqlExpression)
        return query
    }
}

extension SQLQuery: _JoinableRequest {
    func _including(all association: SQLAssociation) -> SQLQuery {
        return mapRelation { $0._including(all: association) }
    }
    
    func _including(optional association: SQLAssociation) -> SQLQuery {
        return mapRelation { $0._including(optional: association) }
    }
    
    func _including(required association: SQLAssociation) -> SQLQuery {
        return mapRelation { $0._including(required: association) }
    }
    
    func _joining(optional association: SQLAssociation) -> SQLQuery {
        return mapRelation { $0._joining(optional: association) }
    }
    
    func _joining(required association: SQLAssociation) -> SQLQuery {
        return mapRelation { $0._joining(required: association) }
    }
}

extension SQLQuery {
    func fetchCount(_ db: Database) throws -> Int {
        let (statement, adapter) = try SQLQueryGenerator(countQuery).prepare(db)
        return try Int.fetchOne(statement, adapter: adapter)!
    }
    
    private var countQuery: SQLQuery {
        guard groupPromise == nil && limit == nil else {
            // SELECT ... GROUP BY ...
            // SELECT ... LIMIT ...
            return trivialCountQuery
        }
        
        if relation.children.contains(where: { $0.value.impactsParentCount }) { // TODO: not tested
            // SELECT ... FROM ... JOIN ...
            return trivialCountQuery
        }
        
        guard case .table = relation.source else {
            // SELECT ... FROM (something which is not a plain table)
            return trivialCountQuery
        }
        
        GRDBPrecondition(!relation.selection.isEmpty, "Can't generate SQL with empty selection")
        if relation.selection.count == 1 {
            guard let count = relation.selection[0].count(distinct: isDistinct) else {
                return trivialCountQuery
            }
            var countQuery = self.unordered()
            countQuery.isDistinct = false
            switch count {
            case .all:
                countQuery = countQuery.select(SQLExpressionCount(AllColumns()))
            case .distinct(let expression):
                countQuery = countQuery.select(SQLExpressionCountDistinct(expression))
            }
            return countQuery
        } else {
            // SELECT [DISTINCT] expr1, expr2, ... FROM tableName ...
            
            guard !isDistinct else {
                return trivialCountQuery
            }
            
            // SELECT expr1, expr2, ... FROM tableName ...
            // ->
            // SELECT COUNT(*) FROM tableName ...
            return self.unordered().select(SQLExpressionCount(AllColumns()))
        }
    }
    
    // SELECT COUNT(*) FROM (self)
    private var trivialCountQuery: SQLQuery {
        let relation = SQLRelation(
            source: .query(unordered()),
            selection: [SQLExpressionCount(AllColumns())])
        return SQLQuery(relation: relation)
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

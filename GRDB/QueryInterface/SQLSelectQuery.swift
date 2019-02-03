/// SQLSelectQuery is a representation of an SQL SELECT query.
///
/// See SQLSelectQueryGenerator for actual SQL generation.
struct SQLSelectQuery {
    var relation: SQLRelation
    var isDistinct: Bool
    var groupPromise: DatabasePromise<[SQLExpression]>?
    var havingExpression: SQLExpression?
    var limit: SQLLimit?
    
    init(
        relation: SQLRelation,
        isDistinct: Bool = false,
        groupPromise: DatabasePromise<[SQLExpression]>? = nil,
        havingExpression: SQLExpression? = nil,
        limit: SQLLimit? = nil)
    {
        self.relation = relation
        self.isDistinct = isDistinct
        self.groupPromise = groupPromise
        self.havingExpression = havingExpression
        self.limit = limit
    }
    
    var alias: TableAlias? {
        return relation.alias
    }
}

extension SQLSelectQuery: SelectionRequest, FilteredRequest, OrderedRequest {
    func select(_ selection: [SQLSelectable]) -> SQLSelectQuery {
        return mapRelation { $0.select(selection) }
    }
    
    func annotated(with selection: [SQLSelectable]) -> SQLSelectQuery {
        return mapRelation { $0.annotated(with: selection) }
    }
    
    func distinct() -> SQLSelectQuery {
        var query = self
        query.isDistinct = true
        return query
    }
    
    func filter(_ predicate: @escaping (Database) throws -> SQLExpressible) -> SQLSelectQuery {
        return mapRelation { $0.filter(predicate) }
    }
    
    func group(_ expressions: @escaping (Database) throws -> [SQLExpressible]) -> SQLSelectQuery {
        var query = self
        query.groupPromise = DatabasePromise { db in try expressions(db).map { $0.sqlExpression } }
        return query
    }
    
    func having(_ predicate: SQLExpressible) -> SQLSelectQuery {
        var query = self
        if let havingExpression = query.havingExpression {
            query.havingExpression = (havingExpression && predicate).sqlExpression
        } else {
            query.havingExpression = predicate.sqlExpression
        }
        return query
    }

    func order(_ orderings: @escaping (Database) throws -> [SQLOrderingTerm]) -> SQLSelectQuery {
        return mapRelation { $0.order(orderings) }
    }
    
    func reversed() -> SQLSelectQuery {
        return mapRelation { $0.reversed() }
    }
    
    func unordered() -> SQLSelectQuery {
        return mapRelation { $0.unordered() }
    }

    func limit(_ limit: Int, offset: Int? = nil) -> SQLSelectQuery {
        var query = self
        query.limit = SQLLimit(limit: limit, offset: offset)
        return query
    }
    
    func qualified(with alias: TableAlias) -> SQLSelectQuery {
        return mapRelation { $0.qualified(with: alias) }
    }
    
    /// Returns a query whose relation is transformed by the given closure.
    func mapRelation(_ transform: (SQLRelation) -> SQLRelation) -> SQLSelectQuery {
        var query = self
        query.relation = transform(relation)
        return query
    }
}

extension SQLSelectQuery {
    func fetchCount(_ db: Database) throws -> Int {
        let (statement, adapter) = try SQLSelectQueryGenerator(countQuery).prepare(db)
        return try Int.fetchOne(statement, adapter: adapter)!
    }
    
    private var countQuery: SQLSelectQuery {
        guard groupPromise == nil && limit == nil else {
            // SELECT ... GROUP BY ...
            // SELECT ... LIMIT ...
            return trivialCountQuery
        }
        
        guard relation.joins.isEmpty, case .table = relation.source else {
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
    private var trivialCountQuery: SQLSelectQuery {
        let relation = SQLRelation(
            source: .query(unordered()),
            selection: [SQLExpressionCount(AllColumns())])
        return SQLSelectQuery(relation: relation)
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

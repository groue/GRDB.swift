// MARK: - SQLSelectQueryDefinition

/// This type is an implementation detail of the query interface.
/// Do not use it directly.
///
/// See https://github.com/groue/GRDB.swift/#the-query-interface
public struct SQLSelectQueryDefinition {
    var mainSelection: (Database, SQLSource?) throws -> [SQLSelectable] // does not include selections from joins
    var distinct: Bool
    var source: SQLSourceDefinition?
    var wherePredicate: ((Database, SQLSource?) throws -> _SQLExpression)?
    var groupByExpressions: ((Database, SQLSource?) throws -> [_SQLExpression])?
    var orderings: ((Database, SQLSource?) throws -> [_SQLOrdering])?
    var reversed: Bool
    var havingPredicate: ((Database, SQLSource?) throws -> _SQLExpression)?
    var limit: SQLLimit?
    
    init(
        select selection: (Database, SQLSource?) -> [SQLSelectable],
        distinct: Bool = false,
        from source: SQLSourceDefinition? = nil,
        filter wherePredicate: ((Database, SQLSource?) throws -> _SQLExpression)? = nil,
        groupBy groupByExpressions: ((Database, SQLSource?) throws -> [_SQLExpression])? = nil,
        orderBy orderings: ((Database, SQLSource?) throws -> [_SQLOrdering])? = nil,
        reversed: Bool = false,
        having havingPredicate: ((Database, SQLSource?) throws -> _SQLExpression)? = nil,
        limit: SQLLimit? = nil)
    {
        self.mainSelection = selection
        self.distinct = distinct
        self.source = source
        self.wherePredicate = wherePredicate
        self.groupByExpressions = groupByExpressions
        self.orderings = orderings
        self.reversed = reversed
        self.havingPredicate = havingPredicate
        self.limit = limit
    }
    
    func makeSelectQuery(db: Database) throws -> SQLSelectQuery {
        let source = try self.source?.makeSource(db)
        
        var selection = try mainSelection(db, source)
        if let source = source {
            selection = selection + source.includedSelection
        }
        
        return try SQLSelectQuery(
            selection: selection,
            distinct: distinct,
            source: source,
            whereExpression: wherePredicate?(db, source).sqlExpression,
            groupByExpressions: groupByExpressions?(db, source) ?? [],
            orderings: orderings?(db, source) ?? [],
            reversed: reversed,
            havingPredicate: havingPredicate?(db, source),
            limit: limit)
    }
}


// MARK: - SQLSourceDefinition

/// TODO
protocol SQLSourceDefinition {
    func makeSource(db: Database) throws -> SQLSource
    func joining(join: SQLJoinable) -> SQLSourceDefinition
}

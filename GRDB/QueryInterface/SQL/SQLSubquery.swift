/// The type that can be embedded as a subquery.
public struct SQLSubquery {
    private var impl: Impl
    
    private enum Impl {
        /// A literal SQL query
        case literal(SQLLiteral)
        
        /// A query interface query
        case query(SQLQuery)
    }
    
    static func literal(_ sqlLiteral: SQLLiteral) -> Self {
        self.init(impl: .literal(sqlLiteral))
    }
    
    static func query(_ query: SQLQuery) -> Self {
        self.init(impl: .query(query))
    }
}

extension SQLSubquery {
    /// The number of columns selected by the subquery.
    ///
    /// This method makes it possible to find the columns of a CTE in a request
    /// that includes a CTE association:
    ///
    ///     // WITH cte AS (SELECT 1 AS a, 2 AS b)
    ///     // SELECT player.*, cte.*
    ///     // FROM player
    ///     // JOIN cte
    ///     let cte = CommonTableExpression<Void>(named: "cte", sql: "SELECT 1 AS a, 2 AS b")
    ///     let request = Player
    ///         .with(cte)
    ///         .including(required: Player.association(to: cte))
    ///     let row = try Row.fetchOne(db, request)!
    ///
    ///     // We know that "SELECT 1 AS a, 2 AS b" selects two columns,
    ///     // so we can find cte columns in the row:
    ///     row.scopes["cte"] // [a:1, b:2]
    func columnsCount(_ db: Database) throws -> Int {
        switch impl {
        case let .literal(sqlLiteral):
            // Compile request. We can freely use the statement cache because we
            // do not execute the statement or modify its arguments.
            let context = SQLGenerationContext(db)
            let sql = try sqlLiteral.sql(context)
            let statement = try db.cachedSelectStatement(sql: sql)
            return statement.columnCount
            
        case let .query(query):
            return try SQLQueryGenerator(query: query).columnsCount(db)
        }
    }
}

extension SQLSubquery {
    /// Returns the subquery SQL.
    ///
    /// For example:
    ///
    ///     // SELECT *
    ///     // FROM "player"
    ///     // WHERE "score" = (SELECT MAX("score") FROM "player")
    ///     let maxScore = Player.select(max(Column("score")))
    ///     let players = try Player
    ///         .filter(Column("score") == maxScore)
    ///         .fetchAll(db)
    ///
    /// - parameter context: An SQL generation context.
    /// - parameter singleResult: A hint that a single result row will be
    ///   consumed. Implementations can optionally use it to optimize the
    ///   generated SQL, for example by adding a `LIMIT 1` SQL clause.
    /// - returns: An SQL string.
    func sql(_ context: SQLGenerationContext) throws -> String {
        switch impl {
        case let .literal(sqlLiteral):
            return try sqlLiteral.sql(context)
            
        case let .query(query):
            return try SQLQueryGenerator(query: query, forSingleResult: false).requestSQL(context)
        }
    }
}

// MARK: - SQLSubqueryable

/// The protocol for types that can be embedded as a subquery.
public protocol SQLSubqueryable: SQLSpecificExpressible {
    var sqlSubquery: SQLSubquery { get }
}

extension SQLSubquery: SQLSubqueryable {
    // Not a real deprecation, just a usage warning
    @available(*, deprecated, message: "Already SQLSubquery")
    public var sqlSubquery: SQLSubquery { self }
}

extension SQLSubqueryable {
    /// Returns a subquery expression.
    public var sqlExpression: SQLExpression {
        .subquery(sqlSubquery)
    }
}

extension SQLSubqueryable {
    /// Returns an expression that checks the inclusion of the expression in
    /// the subquery.
    ///
    ///     // 1000 IN (SELECT score FROM player)
    ///     let request = Player.select(Column("score"), as: Int.self)
    ///     let condition = request.contains(1000)
    public func contains(_ value: SQLExpressible) -> SQLExpression {
        SQLCollection.subquery(sqlSubquery).contains(value.sqlExpression)
    }
}

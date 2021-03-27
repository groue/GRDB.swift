/// The type that can be embedded as a subquery.
public struct SQLSubquery {
    private var impl: Impl
    
    private enum Impl {
        /// A literal SQL query
        case literal(SQL)
        
        /// A query interface relation
        case relation(SQLRelation)
    }
    
    static func literal(_ sqlLiteral: SQL) -> Self {
        self.init(impl: .literal(sqlLiteral))
    }
    
    static func relation(_ relation: SQLRelation) -> Self {
        self.init(impl: .relation(relation))
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
    ///     let cte = CommonTableExpression(named: "cte", sql: "SELECT 1 AS a, 2 AS b")
    ///     let request = Player
    ///         .with(cte)
    ///         .including(required: Player.association(to: cte))
    ///     let row = try Row.fetchOne(db, request)!
    ///
    ///     // We know that "SELECT 1 AS a, 2 AS b" selects two columns,
    ///     // so we can find cte columns in the row:
    ///     row.scopes["cte"] // [a:1, b:2]
    func columnCount(_ db: Database) throws -> Int {
        switch impl {
        case let .literal(sqlLiteral):
            // Compile request. We can freely use the statement cache because we
            // do not execute the statement or modify its arguments.
            let context = SQLGenerationContext(db)
            let sql = try sqlLiteral.sql(context)
            let statement = try db.cachedSelectStatement(sql: sql)
            return statement.columnCount
            
        case let .relation(relation):
            return try SQLQueryGenerator(relation: relation).columnCount(db)
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
            
        case let .relation(relation):
            return try SQLQueryGenerator(relation: relation).requestSQL(context)
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
    public func contains(_ element: SQLExpressible) -> SQLExpression {
        SQLCollection.subquery(sqlSubquery).contains(element.sqlExpression)
    }
    
    /// Returns an expression that is true if and only if the subquery would
    /// return one or more rows.
    ///
    ///     // EXISTS (SELECT * FROM player WHERE name = 'Arthur')
    ///     let request = Player.filter(Column("name") == "Arthur")
    ///     let condition = request.exists()
    public func exists() -> SQLExpression {
        .exists(sqlSubquery)
    }
}

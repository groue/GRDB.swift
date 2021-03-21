/// A [common table expression](https://sqlite.org/lang_with.html) that can be
/// used with the GRDB query interface.
public struct CommonTableExpression<RowDecoder> {
    /// The table name of the common table expression.
    ///
    /// For example:
    ///
    ///     // WITH answer AS (SELECT 42) ...
    ///     let answer = CommonTableExpression(
    ///         named: "answer",
    ///         sql: "SELECT 42")
    ///     answer.tableName // "answer"
    public var tableName: String
    
    var cte: SQLCTE
    
    /// Creates a common table expression from a request.
    ///
    /// For example:
    ///
    ///     // WITH p AS (SELECT * FROM player) ...
    ///     let p = CommonTableExpression<Void>(
    ///         named: "p",
    ///         request: Player.all())
    ///
    ///     // WITH p AS (SELECT * FROM player) ...
    ///     let p = CommonTableExpression<Void>(
    ///         named: "p",
    ///         request: SQLRequest<Player>(sql: "SELECT * FROM player"))
    ///
    /// - parameter recursive: Whether this common table expression needs a
    ///   `WITH RECURSIVE` sql clause.
    /// - parameter tableName: The table name of the common table expression.
    /// - parameter columns: The columns of the common table expression. If nil,
    ///   the columns are the columns of the request.
    /// - parameter request: A request.
    private init<Request: SQLSubqueryable>(
        recursive: Bool = false,
        named tableName: String,
        columns: [String]? = nil,
        request: Request,
        type: RowDecoder.Type)
    {
        self.tableName = tableName
        self.cte = SQLCTE(
            columns: columns,
            sqlSubquery: request.sqlSubquery,
            isRecursive: recursive)
    }
}

extension CommonTableExpression {
    /// Creates a common table expression from a request.
    ///
    /// For example:
    ///
    ///     // WITH p AS (SELECT * FROM player) ...
    ///     let p = CommonTableExpression<Void>(
    ///         named: "p",
    ///         request: Player.all())
    ///
    ///     // WITH p AS (SELECT * FROM player) ...
    ///     let p = CommonTableExpression<Void>(
    ///         named: "p",
    ///         request: SQLRequest<Player>(sql: "SELECT * FROM player"))
    ///
    /// - parameter recursive: Whether this common table expression needs a
    ///   `WITH RECURSIVE` sql clause.
    /// - parameter tableName: The table name of the common table expression.
    /// - parameter columns: The columns of the common table expression. If nil,
    ///   the columns are the columns of the request.
    /// - parameter request: A request.
    public init<Request: SQLSubqueryable>(
        recursive: Bool = false,
        named tableName: String,
        columns: [String]? = nil,
        request: Request)
    {
        self.init(
            recursive: recursive,
            named: tableName,
            columns: columns,
            request: request,
            type: RowDecoder.self)
    }
    
    /// Creates a common table expression from an SQL string and
    /// optional arguments.
    ///
    /// For example:
    ///
    ///     // WITH p AS (SELECT * FROM player WHERE name = 'O''Brien') ...
    ///     let p = CommonTableExpression<Void>(
    ///         named: "p",
    ///         sql: "SELECT * FROM player WHERE name = ?",
    ///         arguments: ["O'Brien"])
    ///
    /// - parameter recursive: Whether this common table expression needs a
    ///   `WITH RECURSIVE` sql clause.
    /// - parameter tableName: The table name of the common table expression.
    /// - parameter columns: The columns of the common table expression. If nil,
    ///   the columns are the columns of the request.
    /// - parameter sql: An SQL query.
    /// - parameter arguments: Statement arguments.
    public init(
        recursive: Bool = false,
        named tableName: String,
        columns: [String]? = nil,
        sql: String,
        arguments: StatementArguments = StatementArguments())
    {
        self.init(
            recursive: recursive,
            named: tableName,
            columns: columns,
            request: SQLRequest<Void>(sql: sql, arguments: arguments),
            type: RowDecoder.self)
    }
    
    /// Creates a common table expression from an SQL *literal*.
    ///
    /// Literals allow you to safely embed raw values in your SQL, without any
    /// risk of syntax errors or SQL injection:
    ///
    ///     // WITH p AS (SELECT * FROM player WHERE name = 'O''Brien') ...
    ///     let name = "O'Brien"
    ///     let p = CommonTableExpression<Void>(
    ///         named: "p",
    ///         literal: "SELECT * FROM player WHERE name = \(name)")
    ///
    /// - parameter recursive: Whether this common table expression needs a
    ///   `WITH RECURSIVE` sql clause.
    /// - parameter tableName: The table name of the common table expression.
    /// - parameter columns: The columns of the common table expression. If nil,
    ///   the columns are the columns of the request.
    /// - parameter sqlLiteral: An `SQL` literal.
    public init(
        recursive: Bool = false,
        named tableName: String,
        columns: [String]? = nil,
        literal sqlLiteral: SQL)
    {
        self.init(
            recursive: recursive,
            named: tableName,
            columns: columns,
            request: SQLRequest<Void>(literal: sqlLiteral),
            type: RowDecoder.self)
    }
}

extension CommonTableExpression where RowDecoder == Row {
    /// Creates a common table expression from a request.
    ///
    /// For example:
    ///
    ///     // WITH p AS (SELECT * FROM player) ...
    ///     let p = CommonTableExpression(
    ///         named: "p",
    ///         request: Player.all())
    ///
    ///     // WITH p AS (SELECT * FROM player) ...
    ///     let p = CommonTableExpression(
    ///         named: "p",
    ///         request: SQLRequest<Player>(sql: "SELECT * FROM player"))
    ///
    /// - parameter recursive: Whether this common table expression needs a
    ///   `WITH RECURSIVE` sql clause.
    /// - parameter tableName: The table name of the common table expression.
    /// - parameter columns: The columns of the common table expression. If nil,
    ///   the columns are the columns of the request.
    /// - parameter request: A request.
    public init<Request: SQLSubqueryable>(
        recursive: Bool = false,
        named tableName: String,
        columns: [String]? = nil,
        request: Request)
    {
        self.init(
            recursive: recursive,
            named: tableName,
            columns: columns,
            request: request,
            type: Row.self)
    }
    
    /// Creates a common table expression from an SQL string and
    /// optional arguments.
    ///
    /// For example:
    ///
    ///     // WITH p AS (SELECT * FROM player WHERE name = 'O''Brien') ...
    ///     let p = CommonTableExpression(
    ///         named: "p",
    ///         sql: "SELECT * FROM player WHERE name = ?",
    ///         arguments: ["O'Brien"])
    ///
    /// - parameter recursive: Whether this common table expression needs a
    ///   `WITH RECURSIVE` sql clause.
    /// - parameter tableName: The table name of the common table expression.
    /// - parameter columns: The columns of the common table expression. If nil,
    ///   the columns are the columns of the request.
    /// - parameter sql: An SQL query.
    /// - parameter arguments: Statement arguments.
    public init(
        recursive: Bool = false,
        named tableName: String,
        columns: [String]? = nil,
        sql: String,
        arguments: StatementArguments = StatementArguments())
    {
        self.init(
            recursive: recursive,
            named: tableName,
            columns: columns,
            request: SQLRequest<Void>(sql: sql, arguments: arguments),
            type: Row.self)
    }
    
    /// Creates a common table expression from an SQL *literal*.
    ///
    /// Literals allow you to safely embed raw values in your SQL, without any
    /// risk of syntax errors or SQL injection:
    ///
    ///     // WITH p AS (SELECT * FROM player WHERE name = 'O''Brien') ...
    ///     let name = "O'Brien"
    ///     let p = CommonTableExpression(
    ///         named: "p",
    ///         literal: "SELECT * FROM player WHERE name = \(name)")
    ///
    /// - parameter recursive: Whether this common table expression needs a
    ///   `WITH RECURSIVE` sql clause.
    /// - parameter tableName: The table name of the common table expression.
    /// - parameter columns: The columns of the common table expression. If nil,
    ///   the columns are the columns of the request.
    /// - parameter sqlLiteral: An `SQL` literal.
    public init(
        recursive: Bool = false,
        named tableName: String,
        columns: [String]? = nil,
        literal sqlLiteral: SQL)
    {
        self.init(
            recursive: recursive,
            named: tableName,
            columns: columns,
            request: SQLRequest<Void>(literal: sqlLiteral),
            type: Row.self)
    }
}

extension CommonTableExpression {
    var relationForAll: SQLRelation {
        .all(fromTable: tableName)
    }
    
    /// Creates a request for all rows of the common table expression.
    ///
    /// You can fetch from this request:
    ///
    ///     // WITH answer AS (SELECT 42 AS value)
    ///     // SELECT * FROM answer
    ///     struct Answer: Decodable, FetchableRecord {
    ///         var value: Int
    ///     }
    ///     let cte = CommonTableExpression<Answer>(
    ///         named: "answer",
    ///         sql: "SELECT 42 AS value")
    ///     let answer = try cte.all().with(cte).fetchOne(db)!
    ///     print(answer.value) // prints 42
    ///
    /// You can embed this request as a subquery:
    ///
    ///     // WITH answer AS (SELECT 42 AS value)
    ///     // SELECT * FROM player
    ///     // WHERE score = (SELECT * FROM answer)
    ///     let answer = CommonTableExpression(
    ///         named: "answer",
    ///         sql: "SELECT 42 AS value")
    ///     let players = try Player
    ///         .filter(Column("score") == answer.all())
    ///         .with(answer)
    ///         .fetchAll(db)
    public func all() -> QueryInterfaceRequest<RowDecoder> {
        QueryInterfaceRequest(relation: relationForAll)
    }
    
    /// An SQL expression that checks the inclusion of an expression in a
    /// common table expression.
    ///
    ///     let playerNameCTE = CommonTableExpression(
    ///         named: "playerName",
    ///         request: Player.select(Column("name"))
    ///
    ///     // name IN playerName
    ///     playerNameCTE.contains(Column("name"))
    public func contains(_ element: SQLExpressible) -> SQLExpression {
        SQLCollection.table(tableName).contains(element.sqlExpression)
    }
}

/// A low-level common table expression
struct SQLCTE {
    /// The columns of the common table expression.
    ///
    /// When nil, the CTE selects the columns of the request:
    ///
    ///     -- Columns a, b
    ///     WITH t AS (SELECT 1 AS a, 2 AS b) ...
    ///
    /// When not nil, `columns` provides the columns of the CTE:
    ///
    ///     -- Column id
    ///     WITH t(id) AS (SELECT 1) ...
    ///            ~~
    var columns: [String]?
    
    /// The common table expression subquery.
    ///
    ///     WITH t AS (SELECT ...)
    ///                ~~~~~~~~~~
    var sqlSubquery: SQLSubquery
    
    /// Whether this common table expression needs a `WITH RECURSIVE`
    /// sql clause.
    var isRecursive: Bool
    
    /// The number of columns in the common table expression.
    func columnCount(_ db: Database) throws -> Int {
        if let columns = columns {
            // No need to hit the database
            return columns.count
        }
        
        return try sqlSubquery.columnCount(db)
    }
}

extension CommonTableExpression {
    /// Creates an association to a common table expression that you can join
    /// or include in another request.
    ///
    /// The key of the returned association is the table name of the common
    /// table expression.
    ///
    /// - parameter cte: A common table expression.
    /// - parameter condition: A function that returns the joining clause.
    /// - parameter left: A `TableAlias` for the left table.
    /// - parameter right: A `TableAlias` for the right table.
    /// - returns: An association to the common table expression.
    public func association<Destination>(
        to cte: CommonTableExpression<Destination>,
        on condition: @escaping (_ left: TableAlias, _ right: TableAlias) -> SQLExpressible)
    -> JoinAssociation<RowDecoder, Destination>
    {
        JoinAssociation(
            to: cte.relationForAll,
            condition: .expression { condition($0, $1).sqlExpression })
    }
    
    /// Creates an association to a common table expression that you can join
    /// or include in another request.
    ///
    /// The key of the returned association is the table name of the common
    /// table expression.
    ///
    /// - parameter cte: A common table expression.
    /// - returns: An association to the common table expression.
    public func association<Destination>(
        to cte: CommonTableExpression<Destination>)
    -> JoinAssociation<RowDecoder, Destination>
    {
        JoinAssociation(to: cte.relationForAll, condition: .none)
    }
    
    /// Creates an association to a table record that you can join
    /// or include in another request.
    ///
    /// The key of the returned association is the table name of `Destination`.
    ///
    /// - parameter cte: A common table expression.
    /// - parameter condition: A function that returns the joining clause.
    /// - parameter left: A `TableAlias` for the left table.
    /// - parameter right: A `TableAlias` for the right table.
    /// - returns: An association to the common table expression.
    public func association<Destination>(
        to destination: Destination.Type,
        on condition: @escaping (_ left: TableAlias, _ right: TableAlias) -> SQLExpressible)
    -> JoinAssociation<RowDecoder, Destination>
    where Destination: TableRecord
    {
        JoinAssociation(
            to: Destination.relationForAll,
            condition: .expression { condition($0, $1).sqlExpression })
    }
    
    /// Creates an association to a table record that you can join
    /// or include in another request.
    ///
    /// The key of the returned association is the table name of `Destination`.
    ///
    /// - parameter cte: A common table expression.
    /// - returns: An association to the common table expression.
    public func association<Destination>(
        to destination: Destination.Type)
    -> JoinAssociation<RowDecoder, Destination>
    where Destination: TableRecord
    {
        JoinAssociation(to: Destination.relationForAll, condition: .none)
    }
}

/// A [common table expression](https://sqlite.org/lang_with.html) that can be
/// used with the GRDB query interface.
///
/// For more information, see
/// [Common Table Expressions](https://github.com/groue/GRDB.swift/blob/master/Documentation/CommonTableExpressions.md>).
///
/// - note: [**🔥 EXPERIMENTAL**](https://github.com/groue/GRDB.swift/blob/master/README.md#what-are-experimental-features)
///
/// ## Topics
///
/// ### Creating a Common Table Expression
///
/// - ``init(recursive:named:columns:request:)-69rlb``
/// - ``init(recursive:named:columns:request:)-35myd``
/// - ``init(recursive:named:columns:literal:)-7vimx``
/// - ``init(recursive:named:columns:literal:)-4nr63``
/// - ``init(recursive:named:columns:sql:arguments:)-8hnp2``
/// - ``init(recursive:named:columns:sql:arguments:)-1ft4x``
///
/// ### Building Requests from a Common Table Expression
///
/// - ``all()``
///
/// ### Building Expressions from a Common Table Expression
///
/// - ``contains(_:)``
///
/// ### Building Associations from a Common Table Expression
///
/// - ``association(to:)-8ymm1``
/// - ``association(to:)-6p49n``
/// - ``association(to:)-lpqk``
/// - ``association(to:on:)-1gy8c``
/// - ``association(to:on:)-3fns2``
/// - ``association(to:on:)-3pqt9``
public struct CommonTableExpression<RowDecoder> {
    /// The table name of the common table expression.
    ///
    /// For example:
    ///
    /// ```swift
    /// // WITH answer AS (SELECT 42) ...
    /// let answer = CommonTableExpression(
    ///     named: "answer",
    ///     request: SQLRequest("SELECT 42"))
    /// answer.tableName // "answer"
    /// ```
    public var tableName: String {
        cte.tableName
    }
    
    var cte: SQLCTE
    
    /// Creates a common table expression from a request.
    ///
    /// For example:
    ///
    /// ```swift
    /// // WITH p AS (SELECT * FROM player) ...
    /// let p = CommonTableExpression(
    ///     named: "p",
    ///     request: Player.all(),
    ///     type: Void.self)
    ///
    /// // WITH p AS (SELECT * FROM player) ...
    /// let p = CommonTableExpression(
    ///     named: "p",
    ///     request: SQLRequest<Player>(sql: "SELECT * FROM player"),
    ///     type: Void.self)
    /// ```
    ///
    /// - parameter recursive: Whether this common table expression needs a
    ///   `WITH RECURSIVE` sql clause.
    /// - parameter tableName: The table name of the common table expression.
    /// - parameter columns: The columns of the common table expression. If nil,
    ///   the columns are the columns of the request.
    /// - parameter request: A request.
    private init(
        recursive: Bool = false,
        named tableName: String,
        columns: [String]? = nil,
        request: some SQLSubqueryable,
        type: RowDecoder.Type)
    {
        self.cte = SQLCTE(
            tableName: tableName,
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
    /// ```swift
    /// // WITH p AS (SELECT * FROM player) ...
    /// let p = CommonTableExpression<Void>(
    ///     named: "p",
    ///     request: Player.all())
    ///
    /// // WITH p AS (SELECT * FROM player) ...
    /// let p = CommonTableExpression<Void>(
    ///     named: "p",
    ///     request: SQLRequest<Player>(sql: "SELECT * FROM player"))
    /// ```
    ///
    /// - parameter recursive: Whether this common table expression needs a
    ///   `WITH RECURSIVE` sql clause.
    /// - parameter tableName: The table name of the common table expression.
    /// - parameter columns: The columns of the common table expression. If nil,
    ///   the columns are the columns of the request.
    /// - parameter request: A request.
    public init(
        recursive: Bool = false,
        named tableName: String,
        columns: [String]? = nil,
        request: some SQLSubqueryable)
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
    /// ```swift
    /// // WITH p AS (SELECT * FROM player WHERE name = 'O''Brien') ...
    /// let p = CommonTableExpression<Void>(
    ///     named: "p",
    ///     sql: "SELECT * FROM player WHERE name = ?",
    ///     arguments: ["O'Brien"])
    /// ```
    ///
    /// **This method is deprecated.** Use
    /// ``init(recursive:named:columns:request:)-69rlb`` instead. For example:
    ///
    /// ```swift
    /// // WITH p AS (SELECT * FROM player WHERE name = 'O''Brien') ...
    /// let name = "O'Brien"
    /// let p = CommonTableExpression<Void>(
    ///     named: "p",
    ///     request: SQLRequest(
    ///         sql: "SELECT * FROM player WHERE name = ?",
    ///         arguments: ["O'Brien"]))
    /// ```
    ///
    /// - parameter recursive: Whether this common table expression needs a
    ///   `WITH RECURSIVE` sql clause.
    /// - parameter tableName: The table name of the common table expression.
    /// - parameter columns: The columns of the common table expression. If nil,
    ///   the columns are the columns of the request.
    /// - parameter sql: An SQL string.
    /// - parameter arguments: Statement arguments.
    @available(*, deprecated, message: "Use init(recursive:named:columns:request:) instead.")
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
            request: SQLRequest(sql: sql, arguments: arguments),
            type: RowDecoder.self)
    }
    
    /// Creates a common table expression from an SQL *literal*.
    ///
    /// ``SQL`` literals allow you to safely embed raw values in your SQL,
    /// without any risk of syntax errors or SQL injection:
    ///
    /// ```swift
    /// // WITH p AS (SELECT * FROM player WHERE name = 'O''Brien') ...
    /// let name = "O'Brien"
    /// let p = CommonTableExpression<Void>(
    ///     named: "p",
    ///     literal: "SELECT * FROM player WHERE name = \(name)")
    /// ```
    ///
    /// **This method is deprecated.** Use
    /// ``init(recursive:named:columns:request:)-69rlb`` instead. For example:
    ///
    /// ```swift
    /// // WITH p AS (SELECT * FROM player WHERE name = 'O''Brien') ...
    /// let name = "O'Brien"
    /// let p = CommonTableExpression(
    ///     named: "p",
    ///     request: SQLRequest<Void>("""
    ///         SELECT * FROM player WHERE name = \(name)
    ///         """))
    /// ```
    ///
    /// - parameter recursive: Whether this common table expression needs a
    ///   `WITH RECURSIVE` sql clause.
    /// - parameter tableName: The table name of the common table expression.
    /// - parameter columns: The columns of the common table expression. If nil,
    ///   the columns are the columns of the request.
    /// - parameter sqlLiteral: An ``SQL`` literal.
    @available(*, deprecated, message: "Use init(recursive:named:columns:request:) instead.")
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
            request: SQLRequest(literal: sqlLiteral),
            type: RowDecoder.self)
    }
}

extension CommonTableExpression<Row> {
    /// Creates a common table expression from a request.
    ///
    /// For example:
    ///
    /// ```swift
    /// // WITH p AS (SELECT * FROM player) ...
    /// let p = CommonTableExpression(
    ///     named: "p",
    ///     request: Player.all())
    ///
    /// // WITH p AS (SELECT * FROM player) ...
    /// let p = CommonTableExpression(
    ///     named: "p",
    ///     request: SQLRequest<Player>(sql: "SELECT * FROM player"))
    /// ```
    ///
    /// - parameter recursive: Whether this common table expression needs a
    ///   `WITH RECURSIVE` sql clause.
    /// - parameter tableName: The table name of the common table expression.
    /// - parameter columns: The columns of the common table expression. If nil,
    ///   the columns are the columns of the request.
    /// - parameter request: A request.
    public init(
        recursive: Bool = false,
        named tableName: String,
        columns: [String]? = nil,
        request: some SQLSubqueryable)
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
    /// ```swift
    /// // WITH p AS (SELECT * FROM player WHERE name = 'O''Brien') ...
    /// let p = CommonTableExpression(
    ///     named: "p",
    ///     sql: "SELECT * FROM player WHERE name = ?",
    ///     arguments: ["O'Brien"])
    /// ```
    ///
    /// **This method is deprecated.** Use
    /// ``init(recursive:named:columns:request:)-35myd`` instead. For example:
    ///
    /// ```swift
    /// // WITH p AS (SELECT * FROM player WHERE name = 'O''Brien') ...
    /// let name = "O'Brien"
    /// let p = CommonTableExpression(
    ///     named: "p",
    ///     request: SQLRequest(
    ///         sql: "SELECT * FROM player WHERE name = ?",
    ///         arguments: ["O'Brien"]))
    /// ```
    ///
    /// - parameter recursive: Whether this common table expression needs a
    ///   `WITH RECURSIVE` sql clause.
    /// - parameter tableName: The table name of the common table expression.
    /// - parameter columns: The columns of the common table expression. If nil,
    ///   the columns are the columns of the request.
    /// - parameter sql: An SQL string.
    /// - parameter arguments: Statement arguments.
    @available(*, deprecated, message: "Use init(recursive:named:columns:request:) instead.")
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
            request: SQLRequest(sql: sql, arguments: arguments),
            type: Row.self)
    }
    
    /// Creates a common table expression from an SQL *literal*.
    ///
    /// ``SQL`` literals allow you to safely embed raw values in your SQL,
    /// without any risk of syntax errors or SQL injection:
    ///
    /// ```swift
    /// // WITH p AS (SELECT * FROM player WHERE name = 'O''Brien') ...
    /// let name = "O'Brien"
    /// let p = CommonTableExpression(
    ///     named: "p",
    ///     literal: "SELECT * FROM player WHERE name = \(name)")
    /// ```
    ///
    /// **This method is deprecated.** Use
    /// ``init(recursive:named:columns:request:)-35myd`` instead. For example:
    ///
    /// ```swift
    /// // WITH p AS (SELECT * FROM player WHERE name = 'O''Brien') ...
    /// let name = "O'Brien"
    /// let p = CommonTableExpression(
    ///     named: "p",
    ///     request: SQLRequest("SELECT * FROM player WHERE name = \(name)"))
    /// ```
    ///
    /// - parameter recursive: Whether this common table expression needs a
    ///   `WITH RECURSIVE` sql clause.
    /// - parameter tableName: The table name of the common table expression.
    /// - parameter columns: The columns of the common table expression. If nil,
    ///   the columns are the columns of the request.
    /// - parameter sqlLiteral: An ``SQL`` literal.
    @available(*, deprecated, message: "Use init(recursive:named:columns:request:) instead.")
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
            request: SQLRequest(literal: sqlLiteral),
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
    /// ```swift
    /// // WITH answer AS (SELECT 42 AS value)
    /// // SELECT * FROM answer
    /// struct Answer: Decodable, FetchableRecord {
    ///     var value: Int
    /// }
    /// let cte = CommonTableExpression<Answer>(
    ///     named: "answer",
    ///     sql: "SELECT 42 AS value")
    /// let answer = try cte.all().with(cte).fetchOne(db)!
    /// print(answer.value) // prints 42
    /// ```
    ///
    /// You can embed this request as a subquery:
    ///
    /// ```
    /// // WITH answer AS (SELECT 42 AS value)
    /// // SELECT * FROM player
    /// // WHERE score = (SELECT * FROM answer)
    /// let answer = CommonTableExpression(
    ///     named: "answer",
    ///     sql: "SELECT 42 AS value")
    /// let players = try Player
    ///     .filter(Column("score") == answer.all())
    ///     .with(answer)
    ///     .fetchAll(db)
    /// ```
    public func all() -> QueryInterfaceRequest<RowDecoder> {
        QueryInterfaceRequest(relation: relationForAll)
    }
    
    /// An SQL expression that checks the inclusion of an expression in a
    /// common table expression.
    ///
    /// ```swift
    /// let playerNameCTE = CommonTableExpression(
    ///     named: "playerName",
    ///     request: Player.select(Column("name"))
    ///
    /// // name IN playerName
    /// playerNameCTE.contains(Column("name"))
    /// ```
    public func contains(_ element: some SQLExpressible) -> SQLExpression {
        SQLCollection.table(tableName).contains(element.sqlExpression)
    }
}

/// A low-level common table expression
struct SQLCTE {
    /// The table name of the common table expression.
    var tableName: String
    
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
        if let columns {
            // No need to hit the database
            return columns.count
        }
        
        do {
            return try sqlSubquery.columnCount(db)
        } catch let error as DatabaseError where error.resultCode == .SQLITE_ERROR {
            // Maybe the CTE refers to other CTEs: https://github.com/groue/GRDB.swift/issues/1275
            // We can't modify the CTE request by creating or extending the
            // WITH clause with other CTEs, because we'd need to parse SQL.
            // So let's rewrite the error message, and guide the user towards
            // a more precise CTE definition:
            let message = [
                [
                    """
                    Can't compute the number of columns in the \
                    \(String(reflecting: tableName)) common table expression
                    """,
                    error.message,
                ].compactMap { $0 }.joined(separator: ": "),
                """
                Check the syntax of the SQL definition, or provide the \
                explicit list of selected columns with the `columns` parameter \
                in the CommonTableExpression initializer.
                """,
            ].joined(separator: ". ")
            throw DatabaseError(
                resultCode: error.extendedResultCode,
                message: message,
                sql: error.sql,
                arguments: error.arguments,
                publicStatementArguments: error.publicStatementArguments)
        }
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
        on condition: @escaping (_ left: TableAlias, _ right: TableAlias) -> any SQLExpressible)
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
    /// - parameter destination: The record type at the other side of
    ///   the association.
    /// - parameter condition: A function that returns the joining clause.
    /// - parameter left: A `TableAlias` for the left table.
    /// - parameter right: A `TableAlias` for the right table.
    /// - returns: An association to the common table expression.
    public func association<Destination>(
        to destination: Destination.Type,
        on condition: @escaping (_ left: TableAlias, _ right: TableAlias) -> any SQLExpressible)
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
    /// - parameter destination: The record type at the other side of
    ///   the association.
    /// - returns: An association to the common table expression.
    public func association<Destination>(
        to destination: Destination.Type)
    -> JoinAssociation<RowDecoder, Destination>
    where Destination: TableRecord
    {
        JoinAssociation(to: Destination.relationForAll, condition: .none)
    }
    
    /// Creates an association to a table that you can join
    /// or include in another request.
    ///
    /// The key of the returned association is the table name of `Destination`.
    ///
    /// - parameter destination: The table at the other side of the association.
    /// - parameter condition: A function that returns the joining clause.
    /// - parameter left: A `TableAlias` for the left table.
    /// - parameter right: A `TableAlias` for the right table.
    /// - returns: An association to the common table expression.
    public func association<Destination>(
        to destination: Table<Destination>,
        on condition: @escaping (_ left: TableAlias, _ right: TableAlias) -> any SQLExpressible)
    -> JoinAssociation<RowDecoder, Destination>
    {
        JoinAssociation(
            to: destination.relationForAll,
            condition: .expression { condition($0, $1).sqlExpression })
    }
    
    /// Creates an association to a table that you can join
    /// or include in another request.
    ///
    /// The key of the returned association is the table name of `Destination`.
    ///
    /// - parameter destination: The table at the other side of the association.
    /// - returns: An association to the common table expression.
    public func association<Destination>(
        to destination: Table<Destination>)
    -> JoinAssociation<RowDecoder, Destination>
    {
        JoinAssociation(to: destination.relationForAll, condition: .none)
    }
}

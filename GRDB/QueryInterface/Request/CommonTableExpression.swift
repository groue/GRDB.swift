#warning("TODO: Document the RowDecoder type")
/// A [common table expression](https://sqlite.org/lang_with.html) that can be
/// used with the GRDB query interface.
public struct CommonTableExpression<RowDecoder> {
    /// The table name of the common table expression.
    ///
    /// For example:
    ///
    ///     // WITH answer AS (SELECT 42) ...
    ///     let answer = CommonTableExpression<Void>(
    ///         named: "answer",
    ///         sql: "SELECT 42")
    ///     answer.tableName // "answer"
    public var tableName: String
    
    /// Whether this common table expression needs a `WITH RECURSIVE`
    /// sql clause.
    public var isRecursive: Bool
    
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
    public init<Request: FetchRequest>(
        recursive: Bool = false,
        named tableName: String,
        columns: [String]? = nil,
        request: Request)
    {
        self.isRecursive = recursive
        self.tableName = tableName
        self.cte = SQLCTE(columns: columns, request: request)
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
            request: SQLRequest<Void>(sql: sql, arguments: arguments))
    }
    
    /// Creates a common table expression from an `SQLLiteral`.
    ///
    /// For example:
    ///
    ///     // WITH p AS (SELECT * FROM player WHERE name = 'O''Brien') ...
    ///     let p = CommonTableExpression<Void>(
    ///         named: "p",
    ///         literal: "SELECT * FROM player WHERE name = \("O'Brien")")
    ///
    /// - parameter recursive: Whether this common table expression needs a
    ///   `WITH RECURSIVE` sql clause.
    /// - parameter tableName: The table name of the common table expression.
    /// - parameter columns: The columns of the common table expression. If nil,
    ///   the columns are the columns of the request.
    /// - parameter sqlLiteral: An SQLLiteral.
    public init(
        recursive: Bool = false,
        named tableName: String,
        columns: [String]? = nil,
        literal sqlLiteral: SQLLiteral)
    {
        self.init(
            recursive: recursive,
            named: tableName,
            columns: columns,
            request: SQLRequest<Void>(literal: sqlLiteral))
    }
}

extension CommonTableExpression {
    var relationForAll: SQLRelation {
        SQLRelation(
            source: .table(tableName: tableName, alias: nil),
            selectionPromise: DatabasePromise(value: [_AllCTEColumns(cte: cte, alias: nil)]))
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
    ///     let answer = CommonTableExpression<Void>(
    ///         named: "answer",
    ///         sql: "SELECT 42 AS value")
    ///     let players = try Player
    ///         .filter(Column("score") == answer.all())
    ///         .with(answer)
    ///         .fetchAll(db)
    public func all() -> QueryInterfaceRequest<RowDecoder> {
        QueryInterfaceRequest(relation: relationForAll)
    }
}

extension TableRecord {
    /// Creates an association to a common table expression that you can join
    /// or include in another request.
    ///
    /// For example, you can build a request that fetches all chats with their
    /// latest post:
    ///
    ///     // WITH latestPost AS (SELECT *, MAX(date) FROM post GROUP BY chatID)
    ///     // SELECT chat.*, latestPost.*
    ///     // FROM chat
    ///     // LEFT JOIN latestPost ON chat.id = latestPost.chatID
    ///     let latestPostCTE = CommonTableExpression<Void>(
    ///         named: "latestPost",
    ///         request: Post
    ///             .annotated(with: max(Column("date")))
    ///             .group(Column("chatID")))
    ///     let latestPost = Chat.association(to: latestPostCTE, on: { chat, latestPost in
    ///         chat[Column("id")] == latestPost[Column("chatID")]
    ///     })
    ///     let request = Chat.all()
    ///         .with(latestPostCTE)
    ///         .including(optional: latestPost)
    ///
    /// - parameter cte: A common table expression.
    /// - parameter condition: A function that returns the joining clause.
    /// - parameter left: A `TableAlias` for the left table.
    /// - parameter right: A `TableAlias` for the right table.
    /// - returns: An association to the common table expression.
    public static func association<Destination>(
        to cte: CommonTableExpression<Destination>,
        on condition: @escaping (_ left: TableAlias, _ right: TableAlias) -> SQLExpressible)
    -> JoinAssociation<Self, Destination>
    {
        JoinAssociation(
            key: .inflected(cte.tableName),
            condition: .expression(condition),
            relation: cte.relationForAll)
    }

    /// Creates an association to a common table expression that you can join
    /// or include in another request.
    ///
    /// - parameter cte: A common table expression.
    /// - returns: An association to the common table expression.
    public static func association<Destination>(
        to cte: CommonTableExpression<Destination>)
    -> JoinAssociation<Self, Destination>
    {
        JoinAssociation(
            key: .inflected(cte.tableName),
            condition: .none,
            relation: cte.relationForAll)
    }
}

extension CommonTableExpression {
    /// Creates an association to a common table expression that you can join
    /// or include in another request.
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
            key: .inflected(cte.tableName),
            condition: .expression(condition),
            relation: cte.relationForAll)
    }
    
    /// Creates an association to a common table expression that you can join
    /// or include in another request.
    ///
    /// - parameter cte: A common table expression.
    /// - returns: An association to the common table expression.
    public func association<Destination>(
        to cte: CommonTableExpression<Destination>)
    -> JoinAssociation<RowDecoder, Destination>
    {
        JoinAssociation(
            key: .inflected(cte.tableName),
            condition: .none,
            relation: cte.relationForAll)
    }
    
    /// Creates an association to a table record that you can join
    /// or include in another request.
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
            key: .inflected(Destination.databaseTableName),
            condition: .expression(condition),
            relation: Destination.relationForAll)
    }
    
    /// Creates an association to a table record that you can join
    /// or include in another request.
    ///
    /// - parameter cte: A common table expression.
    /// - returns: An association to the common table expression.
    public func association<Destination>(
        to destination: Destination.Type)
    -> JoinAssociation<RowDecoder, Destination>
    where Destination: TableRecord
    {
        JoinAssociation(
            key: .inflected(Destination.databaseTableName),
            condition: .none,
            relation: Destination.relationForAll)
    }
}

// MARK: - QueryInterfaceRequest

extension QueryInterfaceRequest {
    #warning("TODO: Accept an array of ctes by discarding their RowDecoder type. This would look better when there are several recursive CTEs.")
    
    /// Returns a request which embeds the common table expressions.
    ///
    /// For example, you can build a request that fetches all chats with their
    /// latest post:
    ///
    ///     // WITH latestPost AS (SELECT *, MAX(date) FROM post GROUP BY chatID)
    ///     // SELECT chat.*, latestPost.*
    ///     // FROM chat
    ///     // LEFT JOIN latestPost ON chat.id = latestPost.chatID
    ///     let latestPostCTE = CommonTableExpression<Void>(
    ///         named: "latestPost",
    ///         request: Post
    ///             .annotated(with: max(Column("date")))
    ///             .group(Column("chatID")))
    ///     let latestPost = Chat.association(to: latestPostCTE, on: { chat, latestPost in
    ///         chat[Column("id")] == latestPost[Column("chatID")]
    ///     })
    ///     let request = Chat.all()
    ///         .with(latestPostCTE)
    ///         .including(optional: latestPost)
    ///
    /// - parameter cte: A common table expression.
    /// - returns: A request.
    public func with<RowDecoder>(_ cte: CommonTableExpression<RowDecoder>) -> Self {
        mapInto(\.query.ctes) { ctes in
            if cte.isRecursive {
                ctes.isRecursive = true
            }
            ctes.ctes[cte.tableName] = cte.cte
        }
    }
}

extension TableRecord {
    /// Returns a request which embeds the common table expressions.
    ///
    /// For example, you can build a request that fetches all chats with their
    /// latest post:
    ///
    ///     // WITH latestPost AS (SELECT *, MAX(date) FROM post GROUP BY chatID)
    ///     // SELECT chat.*, latestPost.*
    ///     // FROM chat
    ///     // LEFT JOIN latestPost ON chat.id = latestPost.chatID
    ///     let latestPostCTE = CommonTableExpression<Void>(
    ///         named: "latestPost",
    ///         request: Post
    ///             .annotated(with: max(Column("date")))
    ///             .group(Column("chatID")))
    ///     let latestPost = Chat.association(to: latestPostCTE, on: { chat, latestPost in
    ///         chat[Column("id")] == latestPost[Column("chatID")]
    ///     })
    ///     let request = Chat
    ///         .with(latestPostCTE)
    ///         .including(optional: latestPost)
    ///
    /// - parameter cte: A common table expression.
    /// - returns: A request.
    public static func with<RowDecoder>(_ cte: CommonTableExpression<RowDecoder>) -> QueryInterfaceRequest<Self> {
        all().with(cte)
    }
}

// MARK: - _AllCTEColumns

/// :nodoc:
public struct _AllCTEColumns {
    var cte: SQLCTE
    var alias: TableAlias?
}

extension _AllCTEColumns: SQLSelectable, Refinable {
    /// :nodoc:
    public func _count(distinct: Bool) -> _SQLCount? {
        if let alias = alias {
            return _SQLQualifiedAllColumns(alias: alias)._count(distinct: distinct)
        } else {
            return AllColumns()._count(distinct: distinct)
        }
    }
    
    /// :nodoc:
    public func _qualifiedSelectable(with alias: TableAlias) -> SQLSelectable {
        // Never requalify
        if self.alias != nil {
            return self
        }
        return with(\.alias, alias)
    }
    
    /// :nodoc:
    public func _columnCount(_ db: Database) throws -> Int {
        if let columns = cte.columns {
            return columns.count
        }
        
        // Compile request. We can freely use the statement cache because we
        // do not execute the statement or modify its arguments.
        let context = SQLGenerationContext(db)
        let sql = try cte.request.requestSQL(context, forSingleResult: false)
        let statement = try db.cachedSelectStatement(sql: sql)
        return statement.columnCount
    }
    
    /// :nodoc:
    public func _accept<Visitor: _SQLSelectableVisitor>(_ visitor: inout Visitor) throws {
        if let alias = alias {
            return try _SQLQualifiedAllColumns(alias: alias)._accept(&visitor)
        } else {
            return try AllColumns()._accept(&visitor)
        }
    }
}

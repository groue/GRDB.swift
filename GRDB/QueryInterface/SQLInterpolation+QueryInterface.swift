#if swift(>=5.0)
/// :nodoc:
extension SQLInterpolation {
    /// Appends the table name of the record type.
    ///
    ///     // SELECT * FROM player
    ///     let request: SQLRequest<Player> = "SELECT * FROM \(Player.self)"
    public mutating func appendInterpolation<T: TableRecord>(_ table: T.Type) {
        appendLiteral(table.databaseTableName.quotedDatabaseIdentifier)
    }
    
    /// Appends the table name of the record.
    ///
    ///     // INSERT INTO player ...
    ///     let player: Player = ...
    ///     let request: SQLRequest<Player> = "INSERT INTO \(tableOf: player) ..."
    public mutating func appendInterpolation<T: TableRecord>(tableOf record: T) {
        appendInterpolation(type(of: record))
    }
    
    /// Appends the selectable SQL.
    ///
    ///     // SELECT * FROM player
    ///     let request: SQLRequest<Player> = """
    ///         SELECT \(AllColumns()) FROM player
    ///         """
    public mutating func appendInterpolation(_ selection: SQLSelectable) {
        elements.append(.selectable(selection))
    }
    
    /// Appends the expression SQL.
    ///
    ///     // SELECT name FROM player
    ///     let request: SQLRequest<String> = """
    ///         SELECT \(Column("name")) FROM player
    ///         """
    public mutating func appendInterpolation(_ expressible: SQLExpressible & SQLSelectable & SQLOrderingTerm) {
        elements.append(.expression(expressible.sqlExpression))
    }
    
    /// Appends the name of the coding key.
    ///
    ///     // SELECT name FROM player
    ///     let request: SQLRequest<String> = "
    ///         SELECT \(CodingKey.name) FROM player
    ///         """
    public mutating func appendInterpolation(
        _ codingKey: SQLExpressible & SQLSelectable & SQLOrderingTerm & CodingKey)
    {
        elements.append(.expression(codingKey.sqlExpression))
    }
    
    /// Appends the expression SQL, or NULL if it is nil.
    ///
    ///     // SELECT score + ? FROM player
    ///     let bonus = 1000
    ///     let request: SQLRequest<Int> = """
    ///         SELECT score + \(bonus) FROM player
    ///         """
    ///
    /// You can also derive literal expressions from other expressions:
    ///
    ///     func date(_ value: SQLExpressible) -> SQLExpression {
    ///         SQLLiteral("DATE(\(value))").sqlExpression
    ///     }
    ///
    ///     // SELECT * FROM player WHERE DATE(createdAt) = '2020-02-25'
    ///     let request = Player.filter(date(Column("createdAt")) == "2020-02-25")
    public mutating func appendInterpolation(_ expressible: SQLExpressible?) {
        if let expressible = expressible {
            elements.append(.expression(expressible.sqlExpression))
        } else {
            appendLiteral("NULL")
        }
    }
    
    /// Appends the name of the coding key.
    ///
    ///     // SELECT name FROM player
    ///     let request: SQLRequest<String> = """
    ///         SELECT \(CodingKey.name) FROM player
    ///         """
    public mutating func appendInterpolation(_ codingKey: CodingKey) {
        appendInterpolation(Column(codingKey.stringValue))
    }
    
    // When a value is both an expression and a sequence of expressions,
    // favor the expression side. Use case: Foundation.Data interpolation.
    /// :nodoc:
    public mutating func appendInterpolation<T>(_ expressible: T)
        where T: Sequence, T.Element: SQLExpressible, T: SQLExpressible
    {
        elements.append(.expression(expressible.sqlExpression))
    }

    /// Appends a sequence of expressions, wrapped in parentheses.
    ///
    ///     // SELECT * FROM player WHERE id IN (?,?,?)
    ///     let ids = [1, 2, 3]
    ///     let request: SQLRequest<Player> = """
    ///         SELECT * FROM player WHERE id IN \(ids)
    ///         """
    ///
    /// If the sequence is empty, an empty subquery is appended:
    ///
    ///     // SELECT * FROM player WHERE id IN (SELECT NULL WHERE NULL)
    ///     let ids: [Int] = []
    ///     let request: SQLRequest<Player> = """
    ///         SELECT * FROM player WHERE id IN \(ids)
    ///         """
    public mutating func appendInterpolation<S>(_ sequence: S) where S: Sequence, S.Element: SQLExpressible {
        appendInterpolation(sequence.lazy.map { $0.sqlExpression })
    }
    
    /// Appends a sequence of expressions, wrapped in parentheses.
    ///
    ///     // SELECT * FROM player WHERE a IN (b, c + 2)
    ///     let expressions = [Column("b"), Column("c") + 2]
    ///     let request: SQLRequest<Player> = """
    ///         SELECT * FROM player WHERE a IN \(expressions)
    ///         """
    ///
    /// If the sequence is empty, an empty subquery is appended:
    ///
    ///     // SELECT * FROM player WHERE a IN (SELECT NULL WHERE NULL)
    ///     let expressions: [SQLExpression] = []
    ///     let request: SQLRequest<Player> = """
    ///         SELECT * FROM player WHERE a IN \(expressions)
    ///         """
    public mutating func appendInterpolation<S>(_ sequence: S) where S: Sequence, S.Element == SQLExpression {
        let e: [SQLLiteral.Element] = sequence.map { .expression($0.sqlExpression) }
        if e.isEmpty {
            appendLiteral("(SELECT NULL WHERE NULL)")
        } else {
            appendLiteral("(")
            elements.append(contentsOf: e.map(CollectionOfOne.init(_:)).joined(separator: CollectionOfOne(.sql(","))))
            appendLiteral(")")
        }
    }
    
    /// Appends the ordering SQL.
    ///
    ///     // SELECT name FROM player ORDER BY name DESC
    ///     let request: SQLRequest<Player> = """
    ///         SELECT * FROM player ORDER BY \(Column("name").desc)
    ///         """
    public mutating func appendInterpolation(_ ordering: SQLOrderingTerm) {
        elements.append(.orderingTerm(ordering))
    }
    
    /// Appends the request SQL, wrapped in parentheses
    ///
    ///     // SELECT name FROM player WHERE score = (SELECT MAX(score) FROM player)
    ///     let subQuery: SQLRequest<Int> = "SELECT MAX(score) FROM player"
    ///     let request: SQLRequest<Player> = """
    ///         SELECT * FROM player WHERE score = \(subQuery)
    ///         """
    public mutating func appendInterpolation<T>(_ request: SQLRequest<T>) {
        elements.append(.subQuery(request.sqlLiteral))
    }
}
#endif
